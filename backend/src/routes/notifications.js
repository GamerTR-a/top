const router = require('express').Router();
const { v4: uuidv4 } = require('uuid');
const { body } = require('express-validator');
const { dbRun, dbGet, dbAll } = require('../config/database');
const { requireAuth } = require('../middleware/auth');
const { handleValidation } = require('../middleware/errorHandler');

// GET /v1/notifications
router.get('/', requireAuth, async (req, res, next) => {
  try {
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 20;
    const offset = (page - 1) * limit;
    const notifications = await dbAll(
      'SELECT * FROM notifications WHERE user_id = ? ORDER BY created_at DESC LIMIT ? OFFSET ?',
      [req.user.id, limit, offset]
    );
    const unreadRow = await dbGet(
      'SELECT COUNT(*) as c FROM notifications WHERE user_id = ? AND is_read = 0',
      [req.user.id]
    );
    res.json({ success: true, data: { notifications, unreadCount: unreadRow.c } });
  } catch (err) { next(err); }
});

// PATCH /v1/notifications/:id/read
router.patch('/:id/read', requireAuth, async (req, res, next) => {
  try {
    await dbRun('UPDATE notifications SET is_read = 1 WHERE id = ? AND user_id = ?', [req.params.id, req.user.id]);
    res.json({ success: true, data: null });
  } catch (err) { next(err); }
});

// POST /v1/notifications/read-all
router.post('/read-all', requireAuth, async (req, res, next) => {
  try {
    await dbRun('UPDATE notifications SET is_read = 1 WHERE user_id = ?', [req.user.id]);
    res.json({ success: true, data: null });
  } catch (err) { next(err); }
});

// DELETE /v1/notifications/:id
router.delete('/:id', requireAuth, async (req, res, next) => {
  try {
    await dbRun('DELETE FROM notifications WHERE id = ? AND user_id = ?', [req.params.id, req.user.id]);
    res.status(204).end();
  } catch (err) { next(err); }
});

// POST /v1/notifications/tokens  (FCM token kayıt)
router.post('/tokens',
  requireAuth,
  body('token').notEmpty().withMessage('FCM token gerekli.'),
  body('platform').optional().isIn(['android', 'ios', 'web']),
  handleValidation,
  async (req, res, next) => {
    try {
      const { token, platform } = req.body;
      await dbRun(
        `INSERT INTO fcm_tokens (user_id, token, platform, updated_at)
         VALUES (?, ?, ?, datetime('now'))
         ON CONFLICT(user_id, platform) DO UPDATE SET token = excluded.token, updated_at = excluded.updated_at`,
        [req.user.id, token, platform || 'android']
      );
      res.json({ success: true, data: null });
    } catch (err) { next(err); }
  }
);

// Yardımcı fonksiyon: kullanıcıya bildirim gönder (iç kullanım)
async function sendNotification(userId, title, body, type = 'info') {
  await dbRun(
    'INSERT INTO notifications (id, user_id, title, body, type) VALUES (?, ?, ?, ?, ?)',
    [uuidv4(), userId, title, body, type]
  );
}

module.exports = router;
module.exports.sendNotification = sendNotification;
