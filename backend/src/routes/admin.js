const router = require('express').Router();
const { body } = require('express-validator');
const { v4: uuidv4 } = require('uuid');
const { dbRun, dbGet, dbAll, dbTransaction } = require('../config/database');
const { requireAuth, requireAdmin } = require('../middleware/auth');
const { handleValidation } = require('../middleware/errorHandler');
const { sendNotification } = require('./notifications');
const rateLimit = require('express-rate-limit');

// Admin broadcast için limiter (index.js'te de tanımlı, burada da kullanıyoruz)
const adminBroadcastLimiter = rateLimit({
  windowMs: 60 * 60 * 1000, // 1 saat
  max: 10,
  standardHeaders: true,
  legacyHeaders: false,
  message: { success: false, error: { code: 'RATE_LIMIT', message: 'Çok fazla broadcast gönderimi. 1 saat bekleyin.' } },
});

// GET /v1/admin/users
router.get('/users', requireAuth, requireAdmin, async (req, res, next) => {
  try {
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 30;
    const offset = (page - 1) * limit;
    const search = req.query.search || '';
    const where = search ? 'WHERE name LIKE ? OR email LIKE ?' : '';
    const params = search ? [`%${search}%`, `%${search}%`] : [];
    const totalRow = await dbGet(`SELECT COUNT(*) as c FROM users ${where}`, params);
    const users = await dbAll(
      `SELECT id, name, email, role, xp, department, grade, profile_photo, created_at
       FROM users ${where} ORDER BY created_at DESC LIMIT ? OFFSET ?`,
      [...params, limit, offset]
    );
    res.json({ success: true, data: { users, pagination: { page, limit, total: totalRow.c } } });
  } catch (err) { next(err); }
});

// PATCH /v1/admin/users/:id/role
router.patch('/users/:id/role',
  requireAuth, requireAdmin,
  body('role').isIn(['student', 'admin', 'baskan']).withMessage('Geçersiz rol.'),
  handleValidation,
  async (req, res, next) => {
    try {
      const user = await dbGet('SELECT id FROM users WHERE id = ?', [req.params.id]);
      if (!user) return res.status(404).json({ success: false, error: { code: 'NOT_FOUND', message: 'Kullanıcı bulunamadı.' } });
      await dbRun('UPDATE users SET role = ? WHERE id = ?', [req.body.role, req.params.id]);
      res.json({ success: true, data: null });
    } catch (err) { next(err); }
  }
);

// DELETE /v1/admin/users/:id
router.delete('/users/:id', requireAuth, requireAdmin, async (req, res, next) => {
  try {
    if (req.params.id === req.user.id) {
      return res.status(400).json({ success: false, error: { code: 'SELF_DELETE', message: 'Kendinizi silemezsiniz.' } });
    }
    await dbRun('DELETE FROM users WHERE id = ?', [req.params.id]);
    res.status(204).end();
  } catch (err) { next(err); }
});

// GET /v1/admin/stats
router.get('/stats', requireAuth, requireAdmin, async (req, res, next) => {
  try {
    const [users, communities, posts, events, supports, newUsers] = await Promise.all([
      dbGet("SELECT COUNT(*) as c FROM users WHERE role != 'admin'"),
      dbGet('SELECT COUNT(*) as c FROM communities'),
      dbGet('SELECT COUNT(*) as c FROM posts'),
      dbGet('SELECT COUNT(*) as c FROM events'),
      dbGet('SELECT COUNT(*) as c FROM post_supports'),
      dbGet("SELECT COUNT(*) as c FROM users WHERE created_at >= datetime('now', '-7 days')"),
    ]);
    res.json({
      success: true,
      data: {
        stats: {
          totalUsers: users.c,
          totalCommunities: communities.c,
          totalPosts: posts.c,
          totalEvents: events.c,
          totalSupports: supports.c,
          newUsersThisWeek: newUsers.c,
        },
      },
    });
  } catch (err) { next(err); }
});

// POST /v1/admin/broadcast
router.post('/broadcast',
  requireAuth, requireAdmin, adminBroadcastLimiter,
  body('title').trim().notEmpty().withMessage('Başlık gerekli.'),
  body('body').trim().notEmpty().withMessage('Mesaj gerekli.'),
  body('type').optional().isIn(['info', 'event', 'badge', 'system']),
  handleValidation,
  async (req, res, next) => {
    try {
      const { title, body: msgBody, type } = req.body;
      const users = await dbAll("SELECT id FROM users WHERE role != 'admin'");
      await dbTransaction(async () => {
        for (const u of users) {
          await dbRun(
            'INSERT INTO notifications (id, user_id, title, body, type) VALUES (?, ?, ?, ?, ?)',
            [uuidv4(), u.id, title, msgBody, type || 'system']
          );
        }
      });
      res.json({ success: true, data: { sentTo: users.length } });
    } catch (err) { next(err); }
  }
);

// POST /v1/admin/award-badge
router.post('/award-badge',
  requireAuth, requireAdmin,
  body('user_id').notEmpty(),
  body('badge_id').isInt(),
  handleValidation,
  async (req, res, next) => {
    try {
      const { user_id, badge_id } = req.body;
      const user = await dbGet('SELECT id, name FROM users WHERE id = ?', [user_id]);
      if (!user) return res.status(404).json({ success: false, error: { code: 'NOT_FOUND', message: 'Kullanıcı bulunamadı.' } });
      const badge = await dbGet('SELECT * FROM badges WHERE id = ?', [badge_id]);
      if (!badge) return res.status(404).json({ success: false, error: { code: 'NOT_FOUND', message: 'Rozet bulunamadı.' } });
      await dbRun('INSERT OR IGNORE INTO user_badges (user_id, badge_id) VALUES (?, ?)', [user_id, badge_id]);
      await sendNotification(user_id, `Yeni Rozet: ${badge.name}`, `${badge.icon} Tebrikler! "${badge.name}" rozetini kazandınız.`, 'badge');
      res.json({ success: true, data: null });
    } catch (err) { next(err); }
  }
);

// GET /v1/admin/badges
router.get('/badges', requireAuth, requireAdmin, async (req, res, next) => {
  try {
    const badges = await dbAll('SELECT * FROM badges');
    res.json({ success: true, data: { badges } });
  } catch (err) { next(err); }
});

// GET /v1/admin/reports  — açık (bekleyen) içerik bildirimleri
router.get('/reports', requireAuth, requireAdmin, async (req, res, next) => {
  try {
    const reports = await dbAll(`
      SELECT r.id, r.post_id, r.reason, r.status, r.created_at,
             r.user_id AS reporter_id, p.content, p.community_name, p.status AS post_status
      FROM post_reports r JOIN posts p ON p.id = r.post_id
      WHERE r.status = 'open'
      ORDER BY r.created_at DESC
    `);
    res.json({ success: true, data: { reports } });
  } catch (err) { next(err); }
});

// PATCH /v1/admin/reports/:id  — bildirimi işaretle
router.patch('/reports/:id',
  requireAuth, requireAdmin,
  body('status').isIn(['open', 'reviewed', 'dismissed']).withMessage('Geçersiz durum.'),
  handleValidation,
  async (req, res, next) => {
    try {
      const report = await dbGet('SELECT id FROM post_reports WHERE id = ?', [req.params.id]);
      if (!report) return res.status(404).json({ success: false, error: { code: 'NOT_FOUND', message: 'Bildirim bulunamadı.' } });
      await dbRun('UPDATE post_reports SET status = ? WHERE id = ?', [req.body.status, req.params.id]);
      res.json({ success: true, data: null });
    } catch (err) { next(err); }
  }
);

module.exports = router;
