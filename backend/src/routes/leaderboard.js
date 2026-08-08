const router = require('express').Router();
const { dbGet, dbAll } = require('../config/database');

// GET /v1/leaderboard/communities
router.get('/communities', async (req, res, next) => {
  try {
    const communities = await dbAll(`
      SELECT id, name, logo_path, category, score, member_count,
             RANK() OVER (ORDER BY score DESC) as siralama
      FROM communities ORDER BY score DESC LIMIT 20
    `);
    res.json({ success: true, data: { communities } });
  } catch (err) { next(err); }
});

// GET /v1/leaderboard/students
router.get('/students', async (req, res, next) => {
  try {
    const students = await dbAll(`
      SELECT id, name, profile_photo, xp,
             RANK() OVER (ORDER BY xp DESC) as siralama,
             (SELECT COUNT(*) FROM user_badges WHERE user_id = users.id) as rozet_sayisi
      FROM users WHERE role = 'student' ORDER BY xp DESC LIMIT 20
    `);
    res.json({ success: true, data: { students } });
  } catch (err) { next(err); }
});

// GET /v1/leaderboard/weekly
router.get('/weekly', async (req, res, next) => {
  try {
    const now = new Date();
    const start = new Date(now.getFullYear(), 0, 1);
    const week = Math.ceil(((now - start) / 86400000 + start.getDay() + 1) / 7);
    const year = now.getFullYear();

    const posts = await dbAll(`
      SELECT p.id, p.community_name, p.community_logo, p.content,
             COUNT(ps.post_id) as haftalik_destek
      FROM posts p
      LEFT JOIN post_supports ps ON ps.post_id = p.id AND ps.week_number = ? AND ps.year = ?
      GROUP BY p.id ORDER BY haftalik_destek DESC LIMIT 10
    `, [week, year]);

    res.json({ success: true, data: { posts, week, year } });
  } catch (err) { next(err); }
});

module.exports = router;
