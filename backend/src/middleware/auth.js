const jwt = require('jsonwebtoken');
const { dbGet } = require('../config/database');

async function requireAuth(req, res, next) {
  const header = req.headers.authorization;
  if (!header || !header.startsWith('Bearer ')) {
    return res.status(401).json({ success: false, error: { code: 'UNAUTHORIZED', message: 'Token gerekli.' } });
  }
  const token = header.slice(7);
  let payload;
  try {
    payload = jwt.verify(token, process.env.JWT_SECRET);
  } catch {
    return res.status(401).json({ success: false, error: { code: 'INVALID_TOKEN', message: 'Geçersiz veya süresi dolmuş token.' } });
  }
  try {
    const user = await dbGet(
      'SELECT id, name, email, role, xp, department, grade, profile_photo FROM users WHERE id = ?',
      [payload.sub]
    );
    if (!user) {
      return res.status(401).json({ success: false, error: { code: 'USER_NOT_FOUND', message: 'Kullanıcı bulunamadı.' } });
    }
    req.user = user;
    next();
  } catch (err) {
    next(err);
  }
}

function requireAdmin(req, res, next) {
  if (!req.user || req.user.role !== 'admin') {
    return res.status(403).json({ success: false, error: { code: 'FORBIDDEN', message: 'Admin yetkisi gerekli.' } });
  }
  next();
}

function requireBaskan(req, res, next) {
  if (!req.user || !['admin', 'baskan'].includes(req.user.role)) {
    return res.status(403).json({ success: false, error: { code: 'FORBIDDEN', message: 'Başkan veya admin yetkisi gerekli.' } });
  }
  next();
}

function requireOwnerOrAdmin(paramKey = 'id') {
  return (req, res, next) => {
    if (req.user.role === 'admin' || req.user.id === req.params[paramKey]) {
      return next();
    }
    return res.status(403).json({ success: false, error: { code: 'FORBIDDEN', message: 'Yetkiniz yok.' } });
  };
}

async function optionalAuth(req, res, next) {
  const header = req.headers.authorization;
  if (!header || !header.startsWith('Bearer ')) return next();
  const token = header.slice(7);
  try {
    const payload = jwt.verify(token, process.env.JWT_SECRET);
    const user = await dbGet('SELECT id, name, email, role, xp FROM users WHERE id = ?', [payload.sub]);
    if (user) req.user = user;
  } catch {
    // Geçersiz token — sessizce devam et
  }
  next();
}

module.exports = { requireAuth, requireAdmin, requireBaskan, requireOwnerOrAdmin, optionalAuth };
