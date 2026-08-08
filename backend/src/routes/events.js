const router = require('express').Router();
const { body } = require('express-validator');
const { dbRun, dbGet, dbAll } = require('../config/database');
const { requireAuth, requireAdmin, optionalAuth } = require('../middleware/auth');
const { handleValidation } = require('../middleware/errorHandler');

// GET /v1/events
router.get('/', optionalAuth, async (req, res, next) => {
  try {
    const communityId = req.query.community_id;
    const filter = req.query.filter === 'past' ? 'past' : 'upcoming';
    let where = filter === 'past'
      ? "e.event_date < datetime('now')"
      : "e.event_date >= datetime('now')";
    const params = [];
    if (communityId) { where += ' AND e.community_id = ?'; params.push(communityId); }
    const order = filter === 'past' ? 'DESC' : 'ASC';

    const events = await dbAll(`
      SELECT e.*, c.name as community_name, c.logo_path as community_logo
      FROM events e LEFT JOIN communities c ON c.id = e.community_id
      WHERE ${where} ORDER BY e.event_date ${order}
    `, params);

    if (req.user && events.length > 0) {
      const registered = await dbAll(
        'SELECT event_id FROM event_registrations WHERE user_id = ?',
        [req.user.id]
      );
      const registeredSet = new Set(registered.map(r => r.event_id));
      events.forEach(e => { e.isRegistered = registeredSet.has(e.id); });
    }

    res.json({ success: true, data: { events } });
  } catch (err) { next(err); }
});

// GET /v1/events/:id
router.get('/:id', optionalAuth, async (req, res, next) => {
  try {
    const event = await dbGet(`
      SELECT e.*, c.name as community_name FROM events e
      LEFT JOIN communities c ON c.id = e.community_id WHERE e.id = ?
    `, [req.params.id]);
    if (!event) return res.status(404).json({ success: false, error: { code: 'NOT_FOUND', message: 'Etkinlik bulunamadı.' } });
    if (req.user) {
      const reg = await dbGet(
        'SELECT 1 FROM event_registrations WHERE user_id = ? AND event_id = ?',
        [req.user.id, req.params.id]
      );
      event.isRegistered = !!reg;
    }
    res.json({ success: true, data: { event } });
  } catch (err) { next(err); }
});

// POST /v1/events  (admin)
router.post('/',
  requireAuth, requireAdmin,
  body('title').trim().notEmpty().withMessage('Başlık gerekli.'),
  body('event_date').notEmpty().withMessage('Tarih gerekli.'),
  body('community_id').optional().isInt(),
  body('description').optional().trim(),
  body('location').optional().trim(),
  body('image_url').optional().trim(),
  handleValidation,
  async (req, res, next) => {
    try {
      const { title, event_date, community_id, description, location, image_url } = req.body;
      const result = await dbRun(
        'INSERT INTO events (title, event_date, community_id, description, location, image_url) VALUES (?, ?, ?, ?, ?, ?)',
        [title, event_date, community_id || null, description || null, location || null, image_url || null]
      );
      const event = await dbGet('SELECT * FROM events WHERE id = ?', [result.lastID]);
      res.status(201).json({ success: true, data: { event } });
    } catch (err) { next(err); }
  }
);

// PATCH /v1/events/:id
router.patch('/:id', requireAuth, requireAdmin,
  body('title').optional().trim().notEmpty(),
  body('event_date').optional().notEmpty(),
  handleValidation,
  async (req, res, next) => {
    try {
      const event = await dbGet('SELECT id FROM events WHERE id = ?', [req.params.id]);
      if (!event) return res.status(404).json({ success: false, error: { code: 'NOT_FOUND' } });
      const fields = ['title', 'event_date', 'description', 'location', 'image_url'];
      const updates = []; const vals = [];
      for (const f of fields) {
        if (req.body[f] !== undefined) { updates.push(`${f} = ?`); vals.push(req.body[f]); }
      }
      if (updates.length === 0) return res.status(400).json({ success: false, error: { code: 'NO_FIELDS' } });
      vals.push(req.params.id);
      await dbRun(`UPDATE events SET ${updates.join(', ')} WHERE id = ?`, vals);
      const updated = await dbGet('SELECT * FROM events WHERE id = ?', [req.params.id]);
      res.json({ success: true, data: { event: updated } });
    } catch (err) { next(err); }
  }
);

// DELETE /v1/events/:id
router.delete('/:id', requireAuth, requireAdmin, async (req, res, next) => {
  try {
    await dbRun('DELETE FROM events WHERE id = ?', [req.params.id]);
    res.status(204).end();
  } catch (err) { next(err); }
});

// POST /v1/events/:id/register
router.post('/:id/register', requireAuth, async (req, res, next) => {
  try {
    const event = await dbGet('SELECT id FROM events WHERE id = ?', [req.params.id]);
    if (!event) return res.status(404).json({ success: false, error: { code: 'NOT_FOUND', message: 'Etkinlik bulunamadı.' } });
    const result = await dbRun(
      'INSERT OR IGNORE INTO event_registrations (user_id, event_id) VALUES (?, ?)',
      [req.user.id, req.params.id]
    );
    if (result.changes > 0) {
      await dbRun('UPDATE users SET xp = xp + 20 WHERE id = ?', [req.user.id]);
    }
    res.json({ success: true, data: null });
  } catch (err) { next(err); }
});

// DELETE /v1/events/:id/register
router.delete('/:id/register', requireAuth, async (req, res, next) => {
  try {
    const result = await dbRun(
      'DELETE FROM event_registrations WHERE user_id = ? AND event_id = ?',
      [req.user.id, req.params.id]
    );
    if (result.changes > 0) {
      await dbRun('UPDATE users SET xp = MAX(0, xp - 20) WHERE id = ?', [req.user.id]);
    }
    res.json({ success: true, data: null });
  } catch (err) { next(err); }
});

// GET /v1/events/:id/attendees  (admin)
router.get('/:id/attendees', requireAuth, requireAdmin, async (req, res, next) => {
  try {
    const attendees = await dbAll(`
      SELECT u.id, u.name, u.email, u.profile_photo, er.registered_at
      FROM event_registrations er JOIN users u ON u.id = er.user_id
      WHERE er.event_id = ? ORDER BY er.registered_at
    `, [req.params.id]);
    res.json({ success: true, data: { attendees } });
  } catch (err) { next(err); }
});

module.exports = router;
