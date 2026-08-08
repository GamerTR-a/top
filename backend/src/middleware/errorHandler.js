const { validationResult } = require('express-validator');

function handleValidation(req, res, next) {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return res.status(422).json({
      success: false,
      error: {
        code: 'VALIDATION_ERROR',
        message: 'Geçersiz istek verisi.',
        details: errors.array().map(e => ({ field: e.path, message: e.msg })),
      },
    });
  }
  next();
}

function notFound(req, res) {
  res.status(404).json({ success: false, error: { code: 'NOT_FOUND', message: `${req.originalUrl} bulunamadı.` } });
}

function serverError(err, req, res, _next) {
  if (process.env.NODE_ENV === 'production') {
    console.error('[error]', err.message);
  } else {
    console.error('[error]', err);
  }
  res.status(500).json({ success: false, error: { code: 'SERVER_ERROR', message: 'Sunucu hatası.' } });
}

module.exports = { handleValidation, notFound, serverError };
