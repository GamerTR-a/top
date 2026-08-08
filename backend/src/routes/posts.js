const router = require('express').Router();
const { body, query } = require('express-validator');
const { dbRun, dbGet, dbAll } = require('../config/database');
const { requireAuth, requireAdmin, requireBaskan, optionalAuth } = require('../middleware/auth');
const { handleValidation } = require('../middleware/errorHandler');
const { getIo } = require('../config/socket');

function currentWeekYear() {
  const now = new Date();
  const start = new Date(now.getFullYear(), 0, 1);
  const week = Math.ceil(((now - start) / 86400000 + start.getDay() + 1) / 7);
  return { week, year: now.getFullYear() };
}

// GET /v1/posts/support/status  — /:id den ÖNCE tanımlanmalı
router.get('/support/status', requireAuth, async (req, res, next) => {
  try {
    const { week, year } = currentWeekYear();
    const weeklyRow = await dbGet(
      'SELECT COUNT(*) as c FROM post_supports WHERE user_id = ? AND week_number = ? AND year = ?',
      [req.user.id, week, year]
    );
    const supportedRows = await dbAll(
      'SELECT post_id FROM post_supports WHERE user_id = ?',
      [req.user.id]
    );
    res.json({ success: true, data: { weeklyUsed: weeklyRow.c, weeklyLimit: 2, supportedPostIds: supportedRows.map(r => r.post_id) } });
  } catch (err) { next(err); }
});

// GET /v1/posts
router.get('/',
  optionalAuth,
  query('page').optional().isInt({ min: 1 }),
  query('limit').optional().isInt({ min: 1, max: 50 }),
  query('community_id').optional().isInt(),
  handleValidation,
  async (req, res, next) => {
    try {
      const page = parseInt(req.query.page) || 1;
      const limit = parseInt(req.query.limit) || 15;
      const offset = (page - 1) * limit;
      const communityId = req.query.community_id;
      const isAdmin = req.user && req.user.role === 'admin';

      let where = '1=1';
      const params = [];
      if (communityId) { where += ' AND community_id = ?'; params.push(communityId); }
      if (!isAdmin) { where += " AND status = 'published'"; }

      const totalRow = await dbGet(`SELECT COUNT(*) as c FROM posts WHERE ${where}`, params);
      const posts = await dbAll(
        `SELECT id, community_id, community_name, community_logo, content, image_url, event_image,
                support_count, quality_score, rating_avg, rating_count, status, created_at
         FROM posts WHERE ${where} ORDER BY created_at DESC LIMIT ? OFFSET ?`,
        [...params, limit, offset]
      );

      if (req.user && posts.length > 0) {
        const supportedRows = await dbAll(
          'SELECT post_id FROM post_supports WHERE user_id = ?',
          [req.user.id]
        );
        const supportedSet = new Set(supportedRows.map(r => r.post_id));
        const ratedRows = await dbAll(
          `SELECT post_id, rating FROM post_ratings WHERE user_id = ? AND post_id IN (${posts.map(() => '?').join(',')})`,
          [req.user.id, ...posts.map(p => p.id)]
        );
        const ratedMap = new Map(ratedRows.map(r => [r.post_id, r.rating]));
        posts.forEach(p => {
          p.isSupported = supportedSet.has(p.id);
          p.isRated = ratedMap.get(p.id) ?? null;
        });
      }

      res.json({ success: true, data: { posts, pagination: { page, limit, total: totalRow.c, pages: Math.ceil(totalRow.c / limit) } } });
    } catch (err) { next(err); }
  }
);

// GET /v1/posts/:id
router.get('/:id', optionalAuth, async (req, res, next) => {
  try {
    const post = await dbGet('SELECT * FROM posts WHERE id = ?', [req.params.id]);
    if (!post) return res.status(404).json({ success: false, error: { code: 'NOT_FOUND', message: 'Gönderi bulunamadı.' } });
    const isAdmin = req.user && req.user.role === 'admin';
    if (post.status === 'hidden' && !isAdmin) {
      return res.status(404).json({ success: false, error: { code: 'NOT_FOUND', message: 'Gönderi bulunamadı.' } });
    }
    if (req.user) {
      const sup = await dbGet(
        'SELECT 1 FROM post_supports WHERE user_id = ? AND post_id = ?',
        [req.user.id, req.params.id]
      );
      post.isSupported = !!sup;
      const rate = await dbGet(
        'SELECT rating FROM post_ratings WHERE user_id = ? AND post_id = ?',
        [req.user.id, req.params.id]
      );
      post.isRated = rate ? rate.rating : null;
    }
    res.json({ success: true, data: { post } });
  } catch (err) { next(err); }
});

// POST /v1/posts  (başkan veya admin)
router.post('/',
  requireAuth, requireBaskan,
  body('community_id').optional().isInt(),
  body('community_name').optional().trim(),
  body('community_logo').optional().trim(),
  body('content').trim().notEmpty().withMessage('İçerik boş olamaz.'),
  body('image_url').optional().trim(),
  body('event_image').optional().trim(),
  handleValidation,
  async (req, res, next) => {
    try {
      let { community_id, community_name, community_logo, content, image_url, event_image } = req.body;
      const isAdmin = req.user.role === 'admin';

      // Başkan yalnızca kendi topluluğuna gönderi atabilir
      if (!isAdmin) {
        if (!community_id) {
          return res.status(403).json({ success: false, error: { code: 'COMMUNITY_REQUIRED', message: 'Başkanlar gönderi için topluluk seçmek zorundadır.' } });
        }
        const community = await dbGet(
          'SELECT id, name, logo_path, chairman_id FROM communities WHERE id = ?',
          [community_id]
        );
        if (!community) {
          return res.status(404).json({ success: false, error: { code: 'NOT_FOUND', message: 'Topluluk bulunamadı.' } });
        }
        if (community.chairman_id !== req.user.id) {
          return res.status(403).json({ success: false, error: { code: 'NOT_YOUR_COMMUNITY', message: 'Yalnızca kendi topluluğunuza gönderi atabilirsiniz.' } });
        }
        community_name = community.name;
        community_logo = community.logo_path;
      } else {
        if (!community_name || !community_name.trim()) {
          return res.status(400).json({ success: false, error: { code: 'COMMUNITY_NAME_REQUIRED', message: 'Topluluk adı gerekli.' } });
        }
      }

      const result = await dbRun(
        `INSERT INTO posts (community_id, community_name, community_logo, content, image_url, event_image, author_id, status)
         VALUES (?, ?, ?, ?, ?, ?, ?, 'published')`,
        [community_id || null, community_name, community_logo || null, content, image_url || null, event_image || null, req.user.id]
      );
      const post = await dbGet('SELECT * FROM posts WHERE id = ?', [result.lastID]);
      res.status(201).json({ success: true, data: { post } });
    } catch (err) { next(err); }
  }
);

// PATCH /v1/posts/:id
router.patch('/:id',
  requireAuth, requireAdmin,
  body('content').optional().trim().notEmpty(),
  body('quality_score').optional().isFloat({ min: 0, max: 5 }),
  handleValidation,
  async (req, res, next) => {
    try {
      const post = await dbGet('SELECT * FROM posts WHERE id = ?', [req.params.id]);
      if (!post) return res.status(404).json({ success: false, error: { code: 'NOT_FOUND', message: 'Gönderi bulunamadı.' } });
      const fields = ['content', 'image_url', 'event_image', 'quality_score'];
      const updates = []; const vals = [];
      for (const f of fields) {
        if (req.body[f] !== undefined) { updates.push(`${f} = ?`); vals.push(req.body[f]); }
      }
      if (updates.length === 0) return res.status(400).json({ success: false, error: { code: 'NO_FIELDS' } });
      vals.push(req.params.id);
      await dbRun(`UPDATE posts SET ${updates.join(', ')} WHERE id = ?`, vals);
      const updated = await dbGet('SELECT * FROM posts WHERE id = ?', [req.params.id]);
      res.json({ success: true, data: { post: updated } });
    } catch (err) { next(err); }
  }
);

// DELETE /v1/posts/:id
router.delete('/:id', requireAuth, requireAdmin, async (req, res, next) => {
  try {
    const post = await dbGet('SELECT id FROM posts WHERE id = ?', [req.params.id]);
    if (!post) return res.status(404).json({ success: false, error: { code: 'NOT_FOUND', message: 'Gönderi bulunamadı.' } });
    await dbRun('DELETE FROM posts WHERE id = ?', [req.params.id]);
    res.status(204).end();
  } catch (err) { next(err); }
});

// POST /v1/posts/:id/support
router.post('/:id/support', requireAuth, async (req, res, next) => {
  try {
    const post = await dbGet('SELECT * FROM posts WHERE id = ?', [req.params.id]);
    if (!post) return res.status(404).json({ success: false, error: { code: 'NOT_FOUND', message: 'Gönderi bulunamadı.' } });

    const alreadySupported = await dbGet(
      'SELECT 1 FROM post_supports WHERE user_id = ? AND post_id = ?',
      [req.user.id, req.params.id]
    );
    if (alreadySupported) {
      return res.status(409).json({ success: false, error: { code: 'ALREADY_SUPPORTED', message: 'Bu gönderiye zaten destek verdiniz.' } });
    }

    const { week, year } = currentWeekYear();
    const weeklyRow = await dbGet(
      'SELECT COUNT(*) as c FROM post_supports WHERE user_id = ? AND week_number = ? AND year = ?',
      [req.user.id, week, year]
    );

    if (weeklyRow.c >= 2) {
      const resetsAt = new Date();
      resetsAt.setDate(resetsAt.getDate() + (7 - resetsAt.getDay()));
      resetsAt.setHours(0, 0, 0, 0);
      return res.status(429).json({
        success: false,
        error: {
          code: 'WEEKLY_SUPPORT_LIMIT_EXCEEDED',
          message: 'Bu hafta maksimum 2 destek hakkınızı kullandınız.',
          details: { limit: 2, used: weeklyRow.c, resetsAt: resetsAt.toISOString() },
        },
      });
    }

    await dbRun(
      'INSERT INTO post_supports (user_id, post_id, week_number, year) VALUES (?, ?, ?, ?)',
      [req.user.id, req.params.id, week, year]
    );
    await dbRun('UPDATE posts SET support_count = support_count + 1 WHERE id = ?', [req.params.id]);
    await dbRun('UPDATE users SET xp = xp + 5 WHERE id = ?', [req.user.id]);

    const updated = await dbGet('SELECT support_count FROM posts WHERE id = ?', [req.params.id]);

    // Gerçek zamanlı broadcast: tüm bağlı istemcilere destek güncellemesini yayınla
    const io = getIo();
    if (io) {
      io.emit('post:supported', {
        postId: parseInt(req.params.id),
        supportCount: updated.support_count,
      });
    }

    res.json({ success: true, data: { supportCount: updated.support_count, weeklyUsed: weeklyRow.c + 1 } });
  } catch (err) { next(err); }
});

// DELETE /v1/posts/:id/support
router.delete('/:id/support', requireAuth, async (req, res, next) => {
  try {
    const support = await dbGet(
      'SELECT * FROM post_supports WHERE user_id = ? AND post_id = ?',
      [req.user.id, req.params.id]
    );
    if (!support) return res.status(404).json({ success: false, error: { code: 'NOT_FOUND', message: 'Destek kaydı bulunamadı.' } });
    await dbRun('DELETE FROM post_supports WHERE user_id = ? AND post_id = ?', [req.user.id, req.params.id]);
    await dbRun('UPDATE posts SET support_count = MAX(0, support_count - 1) WHERE id = ?', [req.params.id]);
    await dbRun('UPDATE users SET xp = MAX(0, xp - 5) WHERE id = ?', [req.user.id]);
    const updated = await dbGet('SELECT support_count FROM posts WHERE id = ?', [req.params.id]);

    const io = getIo();
    if (io) {
      io.emit('post:supported', {
        postId: parseInt(req.params.id),
        supportCount: updated.support_count,
      });
    }

    res.json({ success: true, data: { supportCount: updated.support_count } });
  } catch (err) { next(err); }
});

// POST /v1/posts/:id/rate  (1-5 puanlama, tekrar puanlanırsa güncellenir)
router.post('/:id/rate',
  requireAuth,
  body('rating').isInt({ min: 1, max: 5 }).withMessage('Puan 1-5 arasında olmalı.'),
  handleValidation,
  async (req, res, next) => {
    try {
      const post = await dbGet('SELECT id FROM posts WHERE id = ?', [req.params.id]);
      if (!post) return res.status(404).json({ success: false, error: { code: 'NOT_FOUND', message: 'Gönderi bulunamadı.' } });
      const rating = req.body.rating;
      await dbRun(
        `INSERT INTO post_ratings (user_id, post_id, rating) VALUES (?, ?, ?)
         ON CONFLICT (user_id, post_id) DO UPDATE SET rating = excluded.rating`,
        [req.user.id, req.params.id, rating]
      );
      const agg = await dbGet(
        'SELECT AVG(rating) as avg, COUNT(*) as cnt FROM post_ratings WHERE post_id = ?',
        [req.params.id]
      );
      const ratingAvg = Math.round((agg.avg || 0) * 100) / 100;
      const ratingCount = agg.cnt || 0;
      await dbRun('UPDATE posts SET rating_avg = ?, rating_count = ? WHERE id = ?', [ratingAvg, ratingCount, req.params.id]);

      // Gerçek zamanlı broadcast: puan güncellemesini yayınla
      const io = getIo();
      if (io) {
        io.emit('post:rated', { postId: parseInt(req.params.id), ratingAvg, ratingCount });
      }

      res.json({ success: true, data: { ratingAvg, ratingCount, rating } });
    } catch (err) { next(err); }
  }
);

// POST /v1/posts/:id/report  (UGC bildir)
router.post('/:id/report',
  requireAuth,
  body('reason').optional().trim().isLength({ max: 300 }).withMessage('Gerekçe en fazla 300 karakter olabilir.'),
  handleValidation,
  async (req, res, next) => {
    try {
      const post = await dbGet('SELECT id FROM posts WHERE id = ?', [req.params.id]);
      if (!post) return res.status(404).json({ success: false, error: { code: 'NOT_FOUND', message: 'Gönderi bulunamadı.' } });
      await dbRun(
        'INSERT OR IGNORE INTO post_reports (post_id, user_id, reason) VALUES (?, ?, ?)',
        [req.params.id, req.user.id, req.body.reason || null]
      );
      res.status(201).json({ success: true, data: null });
    } catch (err) { next(err); }
  }
);

// PATCH /v1/posts/:id/status  (admin: gizle / geri getir)
router.patch('/:id/status',
  requireAuth, requireAdmin,
  body('status').isIn(['published', 'hidden']).withMessage('Geçersiz durum.'),
  handleValidation,
  async (req, res, next) => {
    try {
      const post = await dbGet('SELECT id FROM posts WHERE id = ?', [req.params.id]);
      if (!post) return res.status(404).json({ success: false, error: { code: 'NOT_FOUND', message: 'Gönderi bulunamadı.' } });
      await dbRun('UPDATE posts SET status = ? WHERE id = ?', [req.body.status, req.params.id]);
      res.json({ success: true, data: null });
    } catch (err) { next(err); }
  }
);

module.exports = router;
