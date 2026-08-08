const router = require('express').Router();
const { body } = require('express-validator');
const { dbRun, dbGet, dbAll } = require('../config/database');
const { requireAuth, requireAdmin } = require('../middleware/auth');
const { handleValidation } = require('../middleware/errorHandler');

// GET /v1/discounts
router.get('/', async (req, res, next) => {
  try {
    const discounts = await dbAll('SELECT * FROM discounts ORDER BY id');
    res.json({ success: true, data: { discounts } });
  } catch (err) { next(err); }
});

// POST /v1/discounts  (admin)
router.post('/',
  requireAuth, requireAdmin,
  body('company_name').trim().notEmpty(),
  body('coupon_name').trim().notEmpty(),
  body('discount_rate').trim().notEmpty(),
  handleValidation,
  async (req, res, next) => {
    try {
      const { company_name, coupon_name, discount_rate, logo_path, color } = req.body;
      const result = await dbRun(
        'INSERT INTO discounts (company_name, coupon_name, discount_rate, logo_path, color) VALUES (?, ?, ?, ?, ?)',
        [company_name, coupon_name, discount_rate, logo_path || null, color || null]
      );
      const discount = await dbGet('SELECT * FROM discounts WHERE id = ?', [result.lastID]);
      res.status(201).json({ success: true, data: { discount } });
    } catch (err) { next(err); }
  }
);

// PATCH /v1/discounts/:id
router.patch('/:id', requireAuth, requireAdmin,
  body('company_name').optional().trim().notEmpty(),
  handleValidation,
  async (req, res, next) => {
    try {
      const fields = ['company_name', 'coupon_name', 'discount_rate', 'logo_path', 'color'];
      const updates = []; const vals = [];
      for (const f of fields) {
        if (req.body[f] !== undefined) { updates.push(`${f} = ?`); vals.push(req.body[f]); }
      }
      if (updates.length === 0) return res.status(400).json({ success: false, error: { code: 'NO_FIELDS' } });
      vals.push(req.params.id);
      await dbRun(`UPDATE discounts SET ${updates.join(', ')} WHERE id = ?`, vals);
      const discount = await dbGet('SELECT * FROM discounts WHERE id = ?', [req.params.id]);
      res.json({ success: true, data: { discount } });
    } catch (err) { next(err); }
  }
);

// DELETE /v1/discounts/:id
router.delete('/:id', requireAuth, requireAdmin, async (req, res, next) => {
  try {
    await dbRun('DELETE FROM discounts WHERE id = ?', [req.params.id]);
    res.status(204).end();
  } catch (err) { next(err); }
});

module.exports = router;
