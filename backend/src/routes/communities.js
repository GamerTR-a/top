const router = require('express').Router();
const { body, query } = require('express-validator');
const { dbRun, dbGet, dbAll } = require('../config/database');
const { requireAuth, requireAdmin, optionalAuth } = require('../middleware/auth');
const { handleValidation } = require('../middleware/errorHandler');
const { getIo } = require('../config/socket');

// GET /v1/communities
router.get('/',
  optionalAuth,
  query('search').optional().trim(),
  query('category').optional().trim(),
  query('sort').optional().isIn(['score', 'member_count', 'name']),
  query('order').optional().isIn(['asc', 'desc']),
  query('page').optional().isInt({ min: 1 }),
  query('limit').optional().isInt({ min: 1, max: 100 }),
  handleValidation,
  async (req, res, next) => {
    try {
      const search = req.query.search || '';
      const category = req.query.category || '';
      const sort = ['score', 'member_count', 'name'].includes(req.query.sort) ? req.query.sort : 'score';
      const order = req.query.order === 'asc' ? 'ASC' : 'DESC';
      const page = parseInt(req.query.page) || 1;
      const limit = parseInt(req.query.limit) || 20;
      const offset = (page - 1) * limit;

      let where = '1=1';
      const params = [];
      if (search) { where += ' AND (name LIKE ? OR category LIKE ?)'; params.push(`%${search}%`, `%${search}%`); }
      if (category) { where += ' AND category = ?'; params.push(category); }

      const totalRow = await dbGet(`SELECT COUNT(*) as c FROM communities WHERE ${where}`, params);
      const communities = await dbAll(
        `SELECT id, name, logo_path, category, score, member_count, description, chairman_name, created_at
         FROM communities WHERE ${where} ORDER BY ${sort} ${order} LIMIT ? OFFSET ?`,
        [...params, limit, offset]
      );

      if (req.user && communities.length > 0) {
        const memberRows = await dbAll(
          'SELECT community_id FROM community_members WHERE user_id = ?',
          [req.user.id]
        );
        const memberSet = new Set(memberRows.map(r => r.community_id));
        communities.forEach(c => { c.isMember = memberSet.has(c.id); });
      }

      res.json({ success: true, data: { communities, pagination: { page, limit, total: totalRow.c, pages: Math.ceil(totalRow.c / limit) } } });
    } catch (err) { next(err); }
  }
);

// GET /v1/communities/:id
router.get('/:id', optionalAuth, async (req, res, next) => {
  try {
    const community = await dbGet('SELECT * FROM communities WHERE id = ?', [req.params.id]);
    if (!community) return res.status(404).json({ success: false, error: { code: 'NOT_FOUND', message: 'Topluluk bulunamadı.' } });
    if (req.user) {
      const mem = await dbGet(
        'SELECT 1 FROM community_members WHERE user_id = ? AND community_id = ?',
        [req.user.id, req.params.id]
      );
      community.isMember = !!mem;
    }
    res.json({ success: true, data: { community } });
  } catch (err) { next(err); }
});

// POST /v1/communities  (admin only)
router.post('/',
  requireAuth, requireAdmin,
  body('name').trim().notEmpty(),
  body('category').trim().notEmpty(),
  body('description').optional().trim(),
  body('chairman_name').optional().trim(),
  body('logo_path').optional().trim(),
  handleValidation,
  async (req, res, next) => {
    try {
      const { name, category, description, chairman_name, logo_path } = req.body;
      const result = await dbRun(
        'INSERT INTO communities (name, logo_path, category, description, chairman_name) VALUES (?, ?, ?, ?, ?)',
        [name, logo_path || null, category, description || null, chairman_name || 'Belirtilmedi']
      );
      const community = await dbGet('SELECT * FROM communities WHERE id = ?', [result.lastID]);
      res.status(201).json({ success: true, data: { community } });
    } catch (err) { next(err); }
  }
);

// PATCH /v1/communities/:id
router.patch('/:id',
  requireAuth, requireAdmin,
  body('name').optional().trim().notEmpty(),
  body('category').optional().trim(),
  body('description').optional().trim(),
  body('chairman_name').optional().trim(),
  body('logo_path').optional().trim(),
  handleValidation,
  async (req, res, next) => {
    try {
      const community = await dbGet('SELECT * FROM communities WHERE id = ?', [req.params.id]);
      if (!community) return res.status(404).json({ success: false, error: { code: 'NOT_FOUND', message: 'Topluluk bulunamadı.' } });
      const fields = ['name', 'category', 'description', 'chairman_name', 'logo_path'];
      const updates = []; const vals = [];
      for (const f of fields) {
        if (req.body[f] !== undefined) { updates.push(`${f} = ?`); vals.push(req.body[f]); }
      }
      if (updates.length === 0) return res.status(400).json({ success: false, error: { code: 'NO_FIELDS', message: 'Güncellenecek alan yok.' } });
      vals.push(req.params.id);
      await dbRun(`UPDATE communities SET ${updates.join(', ')} WHERE id = ?`, vals);
      const updated = await dbGet('SELECT * FROM communities WHERE id = ?', [req.params.id]);
      res.json({ success: true, data: { community: updated } });
    } catch (err) { next(err); }
  }
);

// DELETE /v1/communities/:id
router.delete('/:id', requireAuth, requireAdmin, async (req, res, next) => {
  try {
    const community = await dbGet('SELECT id FROM communities WHERE id = ?', [req.params.id]);
    if (!community) return res.status(404).json({ success: false, error: { code: 'NOT_FOUND', message: 'Topluluk bulunamadı.' } });
    await dbRun('DELETE FROM communities WHERE id = ?', [req.params.id]);
    res.status(204).end();
  } catch (err) { next(err); }
});

// POST /v1/communities/:id/join
router.post('/:id/join', requireAuth, async (req, res, next) => {
  try {
    const community = await dbGet('SELECT * FROM communities WHERE id = ?', [req.params.id]);
    if (!community) return res.status(404).json({ success: false, error: { code: 'NOT_FOUND', message: 'Topluluk bulunamadı.' } });
    await dbRun('INSERT OR IGNORE INTO community_members (user_id, community_id) VALUES (?, ?)', [req.user.id, req.params.id]);
    await dbRun(
      'UPDATE communities SET member_count = (SELECT COUNT(*) FROM community_members WHERE community_id = ?) WHERE id = ?',
      [req.params.id, req.params.id]
    );
    res.json({ success: true, data: null });
  } catch (err) { next(err); }
});

// DELETE /v1/communities/:id/leave
router.delete('/:id/leave', requireAuth, async (req, res, next) => {
  try {
    await dbRun('DELETE FROM community_members WHERE user_id = ? AND community_id = ?', [req.user.id, req.params.id]);
    await dbRun(
      'UPDATE communities SET member_count = (SELECT COUNT(*) FROM community_members WHERE community_id = ?) WHERE id = ?',
      [req.params.id, req.params.id]
    );
    res.json({ success: true, data: null });
  } catch (err) { next(err); }
});

// GET /v1/communities/:id/activities
router.get('/:id/activities', async (req, res, next) => {
  try {
    const posts = await dbAll(
      'SELECT id, content, image_url, support_count, quality_score, created_at FROM posts WHERE community_id = ? ORDER BY created_at DESC LIMIT 20',
      [req.params.id]
    );
    const events = await dbAll(
      'SELECT id, title, description, event_date, location, image_url, created_at FROM events WHERE community_id = ? ORDER BY created_at DESC LIMIT 10',
      [req.params.id]
    );
    res.json({ success: true, data: { posts, events } });
  } catch (err) { next(err); }
});

// GET /v1/communities/:id/messages
router.get('/:id/messages', requireAuth, async (req, res, next) => {
  try {
    const type = req.query.type === 'management' ? 'management' : 'general';
    let messages;
    if (type === 'management') {
      const community = await dbGet('SELECT chairman_id FROM communities WHERE id = ?', [req.params.id]);
      const isManagement = ['admin', 'baskan'].includes(req.user.role) || req.user.id === community?.chairman_id;
      messages = isManagement
        ? await dbAll(
            "SELECT * FROM community_messages WHERE community_id = ? AND type = 'management' ORDER BY created_at ASC LIMIT 200",
            [req.params.id]
          )
        : await dbAll(
            "SELECT * FROM community_messages WHERE community_id = ? AND type = 'management' AND user_id = ? ORDER BY created_at ASC LIMIT 200",
            [req.params.id, req.user.id]
          );
    } else {
      messages = await dbAll(
        "SELECT * FROM community_messages WHERE community_id = ? AND type = 'general' ORDER BY created_at ASC LIMIT 200",
        [req.params.id]
      );
    }
    res.json({ success: true, data: { messages } });
  } catch (err) { next(err); }
});

// POST /v1/communities/:id/messages
router.post('/:id/messages',
  requireAuth,
  body('content').trim().notEmpty(),
  body('type').optional().isIn(['general', 'management']),
  handleValidation,
  async (req, res, next) => {
    try {
      const community = await dbGet('SELECT id FROM communities WHERE id = ?', [req.params.id]);
      if (!community) return res.status(404).json({ success: false, error: { code: 'NOT_FOUND', message: 'Topluluk bulunamadı.' } });
      const { content, type = 'general' } = req.body;
      const result = await dbRun(
        'INSERT INTO community_messages (community_id, user_id, user_name, content, type) VALUES (?, ?, ?, ?, ?)',
        [req.params.id, req.user.id, req.user.name, content, type]
      );
      const message = await dbGet('SELECT * FROM community_messages WHERE id = ?', [result.lastID]);

      // Gerçek zamanlı broadcast: topluluk odasına yeni mesajı gönder
      const io = getIo();
      if (io) {
        io.to(`community:${req.params.id}`).emit('message:new', { message });
      }

      res.status(201).json({ success: true, data: { message } });
    } catch (err) { next(err); }
  }
);

// GET /v1/communities/:id/members
router.get('/:id/members', requireAuth, async (req, res, next) => {
  try {
    const members = await dbAll(`
      SELECT u.id, u.name, u.profile_photo, u.xp, cm.joined_at
      FROM community_members cm JOIN users u ON u.id = cm.user_id
      WHERE cm.community_id = ? ORDER BY cm.joined_at DESC
    `, [req.params.id]);
    res.json({ success: true, data: { members } });
  } catch (err) { next(err); }
});

module.exports = router;
