const router = require('express').Router();
const { body } = require('express-validator');
const multer = require('multer');
const path = require('path');
const fs = require('fs');
const { v4: uuidv4 } = require('uuid');
const { fileTypeFromBuffer } = require('file-type');
const { dbRun, dbGet, dbAll } = require('../config/database');
const { requireAuth, requireOwnerOrAdmin } = require('../middleware/auth');
const { handleValidation } = require('../middleware/errorHandler');

const ALLOWED_MIME = { 'image/jpeg': '.jpg', 'image/png': '.png', 'image/webp': '.webp' };
const ALLOWED_EXT = new Set(['.jpg', '.jpeg', '.png', '.webp']);

const avatarStorage = multer.diskStorage({
  destination: path.join(__dirname, '../../uploads/avatars'),
  filename: (req, file, cb) => {
    const ext = ALLOWED_MIME[file.mimetype] || '.bin';
    cb(null, `${uuidv4()}${ext}`);
  },
});

const upload = multer({
  storage: avatarStorage,
  limits: { fileSize: 2 * 1024 * 1024 },
  fileFilter: (req, file, cb) => {
    const ext = path.extname(file.originalname).toLowerCase();
    if (ALLOWED_MIME[file.mimetype] && ALLOWED_EXT.has(ext)) {
      cb(null, true);
    } else {
      cb(Object.assign(new Error('Sadece JPEG, PNG ve WebP kabul edilir.'), { code: 'INVALID_FILE_TYPE' }));
    }
  },
});

// Magic bytes doğrulaması - dosya içeriği MIME tipiyle eşleşmeli
async function validateFileMagicBytes(filePath, expectedMime) {
  try {
    const buffer = fs.readFileSync(filePath).subarray(0, 32);
    const type = await fileTypeFromBuffer(buffer);
    if (!type) return false;
    return type.mime === expectedMime;
  } catch {
    return false;
  }
}

// GET /v1/users/:id
router.get('/:id', requireAuth, async (req, res, next) => {
  try {
    const user = await dbGet(
      'SELECT id, name, email, role, xp, department, grade, profile_photo, created_at FROM users WHERE id = ?',
      [req.params.id]
    );
    if (!user) return res.status(404).json({ success: false, error: { code: 'NOT_FOUND', message: 'Kullanıcı bulunamadı.' } });
    res.json({ success: true, data: { user } });
  } catch (err) { next(err); }
});

// PATCH /v1/users/:id
router.patch('/:id',
  requireAuth,
  requireOwnerOrAdmin('id'),
  body('name').optional().trim().notEmpty().withMessage('İsim boş olamaz.'),
  body('department').optional().trim(),
  body('grade').optional().trim(),
  handleValidation,
  async (req, res, next) => {
    try {
      const { name, department, grade } = req.body;
      const updates = []; const vals = [];
      if (name !== undefined) { updates.push('name = ?'); vals.push(name); }
      if (department !== undefined) { updates.push('department = ?'); vals.push(department); }
      if (grade !== undefined) { updates.push('grade = ?'); vals.push(grade); }
      if (updates.length === 0) return res.status(400).json({ success: false, error: { code: 'NO_FIELDS', message: 'Güncellenecek alan yok.' } });
      vals.push(req.params.id);
      await dbRun(`UPDATE users SET ${updates.join(', ')} WHERE id = ?`, vals);
      const user = await dbGet(
        'SELECT id, name, email, role, xp, department, grade, profile_photo FROM users WHERE id = ?',
        [req.params.id]
      );
      res.json({ success: true, data: { user } });
    } catch (err) { next(err); }
  }
);

// DELETE /v1/users/:id
router.delete('/:id', requireAuth, requireOwnerOrAdmin('id'), async (req, res, next) => {
  try {
    await dbRun('DELETE FROM users WHERE id = ?', [req.params.id]);
    res.status(204).end();
  } catch (err) { next(err); }
});

// POST /v1/users/:id/avatar
router.post('/:id/avatar', requireAuth, requireOwnerOrAdmin('id'), (req, res, next) => {
  upload.single('avatar')(req, res, async (err) => {
    if (err) {
      const code = err.code === 'LIMIT_FILE_SIZE' ? 'FILE_TOO_LARGE' : 'INVALID_FILE';
      const message = err.code === 'LIMIT_FILE_SIZE' ? 'Dosya 2 MB\'dan büyük olamaz.' : err.message;
      return res.status(400).json({ success: false, error: { code, message } });
    }
    if (!req.file) return res.status(400).json({ success: false, error: { code: 'NO_FILE', message: 'Dosya gerekli.' } });
    try {
      // Magic bytes doğrulaması - yüklenen dosya gerçekten resim mi?
      const isValid = await validateFileMagicBytes(req.file.path, req.file.mimetype);
      if (!isValid) {
        fs.unlinkSync(req.file.path); // Geçersiz dosyayı sil
        return res.status(400).json({ success: false, error: { code: 'INVALID_FILE_CONTENT', message: 'Dosya içeriği MIME tipiyle eşleşmiyor.' } });
      }
      const url = `/uploads/avatars/${req.file.filename}`;
      await dbRun('UPDATE users SET profile_photo = ? WHERE id = ?', [url, req.params.id]);
      res.json({ success: true, data: { avatarUrl: url } });
    } catch (e) { next(e); }
  });
});

// GET /v1/users/:id/badges
router.get('/:id/badges', requireAuth, async (req, res, next) => {
  try {
    const badges = await dbAll(`
      SELECT b.id, b.name, b.icon, b.description, ub.earned_at
      FROM user_badges ub JOIN badges b ON b.id = ub.badge_id
      WHERE ub.user_id = ? ORDER BY ub.earned_at DESC
    `, [req.params.id]);
    res.json({ success: true, data: { badges } });
  } catch (err) { next(err); }
});

// GET /v1/users/:id/events
router.get('/:id/events', requireAuth, async (req, res, next) => {
  try {
    const events = await dbAll(`
      SELECT e.id, e.title, e.event_date, e.image_url, e.location, er.registered_at
      FROM event_registrations er JOIN events e ON e.id = er.event_id
      WHERE er.user_id = ? ORDER BY e.event_date DESC
    `, [req.params.id]);
    res.json({ success: true, data: { events } });
  } catch (err) { next(err); }
});

// GET /v1/users/:id/communities
router.get('/:id/communities', requireAuth, async (req, res, next) => {
  try {
    const communities = await dbAll(`
      SELECT c.id, c.name, c.logo_path, c.category, cm.joined_at
      FROM community_members cm JOIN communities c ON c.id = cm.community_id
      WHERE cm.user_id = ?
    `, [req.params.id]);
    res.json({ success: true, data: { communities } });
  } catch (err) { next(err); }
});

// GET /v1/users/:id/calendar-notes
router.get('/:id/calendar-notes', requireAuth, requireOwnerOrAdmin('id'), async (req, res, next) => {
  try {
    const notes = await dbAll('SELECT * FROM calendar_notes WHERE user_id = ? ORDER BY date', [req.params.id]);
    res.json({ success: true, data: { notes } });
  } catch (err) { next(err); }
});

// POST /v1/users/:id/calendar-notes
router.post('/:id/calendar-notes',
  requireAuth,
  requireOwnerOrAdmin('id'),
  body('date').notEmpty().withMessage('Tarih gerekli.'),
  body('note').trim().notEmpty().withMessage('Not boş olamaz.'),
  handleValidation,
  async (req, res, next) => {
    try {
      const { date, note } = req.body;
      await dbRun('DELETE FROM calendar_notes WHERE user_id = ? AND date = ?', [req.params.id, date]);
      const result = await dbRun(
        'INSERT INTO calendar_notes (user_id, date, note) VALUES (?, ?, ?)',
        [req.params.id, date, note]
      );
      const created = await dbGet('SELECT * FROM calendar_notes WHERE id = ?', [result.lastID]);
      res.status(201).json({ success: true, data: { note: created } });
    } catch (err) { next(err); }
  }
);

// DELETE /v1/users/:id/calendar-notes/:noteId
router.delete('/:id/calendar-notes/:noteId', requireAuth, requireOwnerOrAdmin('id'), async (req, res, next) => {
  try {
    await dbRun('DELETE FROM calendar_notes WHERE id = ? AND user_id = ?', [req.params.noteId, req.params.id]);
    res.status(204).end();
  } catch (err) { next(err); }
});

module.exports = router;
