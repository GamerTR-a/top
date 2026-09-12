const router = require('express').Router();
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const { v4: uuidv4 } = require('uuid');
const crypto = require('crypto');
const { body } = require('express-validator');
const { dbRun, dbGet } = require('../config/database');
const { requireAuth } = require('../middleware/auth');
const { handleValidation } = require('../middleware/errorHandler');

// Rate limiters are created in index.js and passed via app locals
// We'll create simple inline limiters here for specific endpoints
const rateLimit = require('express-rate-limit');

const forgotPasswordLimiter = rateLimit({
  windowMs: 60 * 60 * 1000, // 1 saat
  max: 3,
  standardHeaders: true,
  legacyHeaders: false,
  message: { success: false, error: { code: 'RATE_LIMIT', message: 'Çok fazla şifre sıfırlama isteği. 1 saat bekleyin.' } },
});

const resetPasswordLimiter = rateLimit({
  windowMs: 60 * 60 * 1000, // 1 saat
  max: 5,
  standardHeaders: true,
  legacyHeaders: false,
  message: { success: false, error: { code: 'RATE_LIMIT', message: 'Çok fazla şifre sıfırlama denemesi. 1 saat bekleyin.' } },
});

const refreshLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 dakika
  max: 30,
  standardHeaders: true,
  legacyHeaders: false,
  message: { success: false, error: { code: 'RATE_LIMIT', message: 'Çok fazla token yenileme denemesi. 15 dakika bekleyin.' } },
});

async function makeTokens(userId) {
  const accessToken = jwt.sign({ sub: userId }, process.env.JWT_SECRET, {
    expiresIn: process.env.JWT_ACCESS_EXPIRES || '1h',
  });
  const rawRefresh = uuidv4();
  const refreshHash = crypto.createHash('sha256').update(rawRefresh).digest('hex');
  const expiresAt = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString();
  await dbRun(
    'INSERT INTO refresh_tokens (id, user_id, token_hash, expires_at) VALUES (?, ?, ?, ?)',
    [uuidv4(), userId, refreshHash, expiresAt]
  );
  return { accessToken, refreshToken: rawRefresh, expiresIn: 3600 };
}

// POST /v1/auth/register
router.post('/register',
  body('name').trim().notEmpty().withMessage('İsim boş olamaz.'),
  body('email').isEmail().normalizeEmail().withMessage('Geçerli e-posta girin.'),
  body('password')
    .isLength({ min: 8 }).withMessage('Şifre en az 8 karakter olmalı.')
    .matches(/[A-Z]/).withMessage('Şifre en az bir büyük harf içermeli.')
    .matches(/[0-9]/).withMessage('Şifre en az bir rakam içermeli.'),
  body('department').optional().trim(),
  body('grade').optional().trim(),
  handleValidation,
  async (req, res, next) => {
    try {
      const { name, email, password, department, grade } = req.body;

      // Öğrenci e-posta doğrulaması: .edu veya .edu.tr ile bitmeli
      const normalizedEmail = email.toLowerCase();
      if (!normalizedEmail.endsWith('.edu') && !normalizedEmail.endsWith('.edu.tr')) {
        return res.status(400).json({
          success: false,
          error: {
            code: 'INVALID_EMAIL_DOMAIN',
            message: 'Kayıt için sadece .edu veya .edu.tr uzantılı öğrenci e-postası kullanılabilir.',
          },
        });
      }
      const adminEmail = (process.env.ADMIN_EMAIL || 'admin@newgenc.com').toLowerCase();
      if (email.toLowerCase() === adminEmail) {
        return res.status(409).json({ success: false, error: { code: 'EMAIL_RESERVED', message: 'Bu e-posta kullanılamaz.' } });
      }
      const existing = await dbGet('SELECT id FROM users WHERE email = ?', [email.toLowerCase()]);
      if (existing) {
        return res.status(409).json({ success: false, error: { code: 'EMAIL_EXISTS', message: 'Bu e-posta zaten kayıtlı.' } });
      }
      const id = uuidv4();
      const passwordHash = bcrypt.hashSync(password, 10);
      await dbRun(
        `INSERT INTO users (id, name, email, password_hash, role, department, grade)
         VALUES (?, ?, ?, ?, 'student', ?, ?)`,
        [id, name, email.toLowerCase(), passwordHash, department || null, grade || null]
      );
      const badge = await dbGet("SELECT id FROM badges WHERE name = 'İlk Adım'");
      if (badge) {
        await dbRun('INSERT OR IGNORE INTO user_badges (user_id, badge_id) VALUES (?, ?)', [id, badge.id]);
      }
      const tokens = await makeTokens(id);
      const user = await dbGet('SELECT id, name, email, role, xp, department, grade FROM users WHERE id = ?', [id]);
      res.status(201).json({ success: true, data: { user, tokens } });
    } catch (err) { next(err); }
  }
);

// POST /v1/auth/login
router.post('/login',
  body('email').isEmail().normalizeEmail().withMessage('Geçerli e-posta girin.'),
  body('password').notEmpty().withMessage('Şifre gerekli.'),
  handleValidation,
  async (req, res, next) => {
    try {
      const { email, password } = req.body;
      const normalizedEmail = email.toLowerCase();
      // Öğrenci e-posta doğrulaması: .edu veya .edu.tr ile bitmeli
      if (!normalizedEmail.endsWith('.edu') && !normalizedEmail.endsWith('.edu.tr')) {
        return res.status(401).json({
          success: false,
          error: { code: 'INVALID_EMAIL_DOMAIN', message: 'Giriş için sadece .edu veya .edu.tr uzantılı öğrenci e-postası kullanılabilir.' },
        });
      }
      const user = await dbGet('SELECT * FROM users WHERE email = ?', [normalizedEmail]);
      if (!user || !bcrypt.compareSync(password, user.password_hash)) {
        return res.status(401).json({ success: false, error: { code: 'INVALID_CREDENTIALS', message: 'E-posta veya şifre hatalı.' } });
      }
      const tokens = await makeTokens(user.id);
      const { password_hash, ...safeUser } = user;
      res.json({ success: true, data: { user: safeUser, tokens } });
    } catch (err) { next(err); }
  }
);

// POST /v1/auth/refresh
router.post('/refresh',
  refreshLimiter,
  body('refreshToken').notEmpty().withMessage('Refresh token gerekli.'),
  handleValidation,
  async (req, res, next) => {
    try {
      const { refreshToken } = req.body;
      const hash = crypto.createHash('sha256').update(refreshToken).digest('hex');
      const record = await dbGet('SELECT * FROM refresh_tokens WHERE token_hash = ?', [hash]);
      if (!record || new Date(record.expires_at) < new Date()) {
        if (record) await dbRun('DELETE FROM refresh_tokens WHERE id = ?', [record.id]);
        return res.status(401).json({ success: false, error: { code: 'INVALID_REFRESH_TOKEN', message: 'Geçersiz veya süresi dolmuş refresh token.' } });
      }
      await dbRun('DELETE FROM refresh_tokens WHERE id = ?', [record.id]);
      const tokens = await makeTokens(record.user_id);
      res.json({ success: true, data: { tokens } });
    } catch (err) { next(err); }
  }
);

// POST /v1/auth/logout
router.post('/logout', requireAuth, async (req, res, next) => {
  try {
    await dbRun('DELETE FROM refresh_tokens WHERE user_id = ?', [req.user.id]);
    res.json({ success: true, data: null });
  } catch (err) { next(err); }
});

// GET /v1/auth/me
router.get('/me', requireAuth, async (req, res, next) => {
  try {
    const user = await dbGet(
      'SELECT id, name, email, role, xp, department, grade, profile_photo, created_at FROM users WHERE id = ?',
      [req.user.id]
    );
    res.json({ success: true, data: { user } });
  } catch (err) { next(err); }
});

// POST /v1/auth/forgot-password
router.post('/forgot-password',
  forgotPasswordLimiter,
  body('email').isEmail().normalizeEmail().withMessage('Geçerli e-posta girin.'),
  handleValidation,
  async (req, res, next) => {
    try {
      const { email } = req.body;
      const normalizedEmail = email.toLowerCase();
      // Öğrenci e-posta doğrulaması: .edu veya .edu.tr ile bitmeli
      if (!normalizedEmail.endsWith('.edu') && !normalizedEmail.endsWith('.edu.tr')) {
        return res.status(400).json({
          success: false,
          error: { code: 'INVALID_EMAIL_DOMAIN', message: 'Şifre sıfırlama için sadece .edu veya .edu.tr uzantılı öğrenci e-postası kullanılabilir.' },
        });
      }
      const user = await dbGet('SELECT id FROM users WHERE email = ?', [normalizedEmail]);
      if (user) {
        const rawToken = uuidv4();
        const tokenHash = crypto.createHash('sha256').update(rawToken).digest('hex');
        const expiresAt = new Date(Date.now() + 60 * 60 * 1000).toISOString();
        await dbRun('DELETE FROM password_reset_tokens WHERE user_id = ?', [user.id]);
        await dbRun(
          'INSERT INTO password_reset_tokens (id, user_id, token_hash, expires_at) VALUES (?, ?, ?, ?)',
          [uuidv4(), user.id, tokenHash, expiresAt]
        );
        // GÜVENLİK: Reset token asla loglanmamalı - geliştirme bile olsa
        // E-posta gönderimi implement edileceğinde token doğrudan e-postada yer alacak
      }
      res.json({ success: true, data: { message: 'Şifre sıfırlama bağlantısı e-posta adresinize gönderildi.' } });
    } catch (err) { next(err); }
  }
);

// POST /v1/auth/reset-password
router.post('/reset-password',
  resetPasswordLimiter,
  body('token').notEmpty().withMessage('Token gerekli.'),
  body('newPassword')
    .isLength({ min: 8 }).withMessage('Şifre en az 8 karakter olmalı.')
    .matches(/[A-Z]/).withMessage('Şifre en az bir büyük harf içermeli.')
    .matches(/[0-9]/).withMessage('Şifre en az bir rakam içermeli.'),
  handleValidation,
  async (req, res, next) => {
    try {
      const { token, newPassword } = req.body;
      const tokenHash = crypto.createHash('sha256').update(token).digest('hex');
      const record = await dbGet('SELECT * FROM password_reset_tokens WHERE token_hash = ?', [tokenHash]);
      if (!record || record.used || new Date(record.expires_at) < new Date()) {
        if (record && !record.used) {
          await dbRun('DELETE FROM password_reset_tokens WHERE id = ?', [record.id]);
        }
        return res.status(400).json({ success: false, error: { code: 'INVALID_RESET_TOKEN', message: 'Geçersiz veya süresi dolmuş token.' } });
      }
      await dbRun('UPDATE users SET password_hash = ? WHERE id = ?', [bcrypt.hashSync(newPassword, 10), record.user_id]);
      await dbRun('UPDATE password_reset_tokens SET used = 1 WHERE id = ?', [record.id]);
      await dbRun('DELETE FROM refresh_tokens WHERE user_id = ?', [record.user_id]);
      res.json({ success: true, data: { message: 'Şifreniz başarıyla güncellendi. Lütfen tekrar giriş yapın.' } });
    } catch (err) { next(err); }
  }
);

// POST /v1/auth/change-password
router.post('/change-password',
  requireAuth,
  body('currentPassword').notEmpty().withMessage('Mevcut şifre gerekli.'),
  body('newPassword')
    .isLength({ min: 8 }).withMessage('Yeni şifre en az 8 karakter olmalı.')
    .matches(/[A-Z]/).withMessage('Şifre en az bir büyük harf içermeli.')
    .matches(/[0-9]/).withMessage('Şifre en az bir rakam içermeli.'),
  handleValidation,
  async (req, res, next) => {
    try {
      const { currentPassword, newPassword } = req.body;
      const user = await dbGet('SELECT * FROM users WHERE id = ?', [req.user.id]);
      if (!bcrypt.compareSync(currentPassword, user.password_hash)) {
        return res.status(400).json({ success: false, error: { code: 'WRONG_PASSWORD', message: 'Mevcut şifre hatalı.' } });
      }
      await dbRun('UPDATE users SET password_hash = ? WHERE id = ?', [bcrypt.hashSync(newPassword, 10), user.id]);
      res.json({ success: true, data: null });
    } catch (err) { next(err); }
  }
);

module.exports = router;
