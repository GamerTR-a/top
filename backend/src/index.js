const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '../.env') });

const http = require('http');
const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');
const { Server } = require('socket.io');

const { migrate } = require('./db/migrate');
const { notFound, serverError } = require('./middleware/errorHandler');
const { setIo } = require('./config/socket');

// Routes
const authRoutes = require('./routes/auth');
const userRoutes = require('./routes/users');
const communityRoutes = require('./routes/communities');
const postRoutes = require('./routes/posts');
const eventRoutes = require('./routes/events');
const leaderboardRoutes = require('./routes/leaderboard');
const notificationRoutes = require('./routes/notifications');
const discountRoutes = require('./routes/discounts');
const adminRoutes = require('./routes/admin');

const app = express();
const server = http.createServer(app);

// Güven ayarı (proxy arkasında)
app.set('trust proxy', 1);

// Güvenlik başlıkları
app.use(helmet({
  crossOriginResourcePolicy: { policy: 'same-site' },
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'none'"],
      imgSrc: ["'self'", 'data:'],
    },
  },
}));

// CORS — izin verilen originler .env'den gelir
const ALLOWED_ORIGINS = (process.env.ALLOWED_ORIGINS || 'http://localhost:3000,http://localhost:8080')
  .split(',')
  .map(o => o.trim())
  .filter(Boolean);

app.use(cors({
  origin: (origin, cb) => {
    if (!origin || ALLOWED_ORIGINS.includes(origin) || origin.startsWith('http://localhost:') || origin.startsWith('http://127.0.0.1:')) return cb(null, true);
    cb(new Error('CORS politikası ihlali'));
  },
  credentials: true,
}));

// Body parsers
app.use(express.json({ limit: '5mb' }));
app.use(express.urlencoded({ extended: true }));

// Statik upload dosyaları
app.use('/uploads', (req, res, next) => {
  res.setHeader('X-Content-Type-Options', 'nosniff');
  res.setHeader('Content-Disposition', 'inline');
  res.setHeader('Content-Security-Policy', "default-src 'none'; img-src 'self'");
  next();
}, express.static(path.join(__dirname, '../uploads'), { dotfiles: 'deny' }));

// Rate limiting
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 200,
  standardHeaders: true,
  legacyHeaders: false,
  message: { success: false, error: { code: 'RATE_LIMIT', message: 'Çok fazla istek. Lütfen bekleyin.' } },
});
const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 20,
  message: { success: false, error: { code: 'RATE_LIMIT', message: 'Çok fazla giriş denemesi. 15 dakika bekleyin.' } },
});
const uploadLimiter = rateLimit({
  windowMs: 60 * 60 * 1000,
  max: 10,
  message: { success: false, error: { code: 'RATE_LIMIT', message: 'Çok fazla dosya yükleme denemesi. 1 saat bekleyin.' } },
});

app.use('/v1', limiter);

// Routes
app.use('/v1/auth', authLimiter, authRoutes);
app.use('/v1/users', userRoutes);
app.use('/v1/users/:id/avatar', uploadLimiter);
app.use('/v1/communities', communityRoutes);
app.use('/v1/posts', postRoutes);
app.use('/v1/events', eventRoutes);
app.use('/v1/leaderboard', leaderboardRoutes);
app.use('/v1/notifications', notificationRoutes);
app.use('/v1/discounts', discountRoutes);
app.use('/v1/admin', adminRoutes);

// Health check
app.get('/health', (req, res) => {
  res.json({ status: 'ok', version: '1.0.0', uptime: Math.floor(process.uptime()), timestamp: new Date().toISOString() });
});

// 404 & hata işleyici
app.use(notFound);
app.use(serverError);

// Socket.io başlat
const io = new Server(server, {
  cors: {
    origin: (origin, cb) => {
      if (!origin || ALLOWED_ORIGINS.includes(origin) || origin.startsWith('http://localhost:') || origin.startsWith('http://127.0.0.1:')) return cb(null, true);
      cb(new Error('CORS politikası ihlali'));
    },
    credentials: true,
  },
});

setIo(io);

io.on('connection', (socket) => {
  // İstemci bir topluluk odasına katılır (sohbet için)
  socket.on('join:community', ({ communityId }) => {
    if (communityId) socket.join(`community:${communityId}`);
  });

  // İstemci topluluk odasından ayrılır
  socket.on('leave:community', ({ communityId }) => {
    if (communityId) socket.leave(`community:${communityId}`);
  });
});

// Sunucuyu başlat
const PORT = process.env.PORT || 8000;

async function startServer() {
  await migrate();
  server.listen(PORT, () => {
    console.log(`[NevGenç API] http://localhost:${PORT}`);
    console.log(`[NevGenç API] WebSocket: ws://localhost:${PORT}`);
    console.log(`[NevGenç API] Health: http://localhost:${PORT}/health`);
  });
}

startServer().catch((err) => {
  console.error('[NevGenç API] Başlatma hatası:', err);
  process.exit(1);
});

module.exports = app;
