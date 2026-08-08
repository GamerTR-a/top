const { dbExec, getDb } = require('../config/database');

async function migrate() {
  const isPostgres = process.env.DB_TYPE === 'postgres';

  if (isPostgres) {
    await dbExec(`
      -- Kullanıcılar
      CREATE TABLE IF NOT EXISTS users (
        id          TEXT PRIMARY KEY,
        name        TEXT NOT NULL,
        email       TEXT UNIQUE NOT NULL,
        password_hash TEXT NOT NULL,
        role        TEXT NOT NULL DEFAULT 'student',
        department  TEXT,
        grade       TEXT,
        xp          INTEGER NOT NULL DEFAULT 0,
        profile_photo TEXT,
        created_at  TEXT NOT NULL DEFAULT TO_CHAR(CURRENT_TIMESTAMP, 'YYYY-MM-DD HH24:MI:SS')
      );

      -- Refresh token'ları
      CREATE TABLE IF NOT EXISTS refresh_tokens (
        id          TEXT PRIMARY KEY,
        user_id     TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        token_hash  TEXT NOT NULL UNIQUE,
        expires_at  TEXT NOT NULL,
        created_at  TEXT NOT NULL DEFAULT TO_CHAR(CURRENT_TIMESTAMP, 'YYYY-MM-DD HH24:MI:SS')
      );

      -- Topluluklar
      CREATE TABLE IF NOT EXISTS communities (
        id          SERIAL PRIMARY KEY,
        name        TEXT NOT NULL,
        logo_path   TEXT,
        category    TEXT NOT NULL,
        score       REAL NOT NULL DEFAULT 0,
        member_count INTEGER NOT NULL DEFAULT 0,
        description TEXT,
        chairman_name TEXT,
        chairman_id TEXT REFERENCES users(id) ON DELETE SET NULL,
        created_at  TEXT NOT NULL DEFAULT TO_CHAR(CURRENT_TIMESTAMP, 'YYYY-MM-DD HH24:MI:SS')
      );

      -- Topluluk üyelikleri
      CREATE TABLE IF NOT EXISTS community_members (
        user_id       TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        community_id  INTEGER NOT NULL REFERENCES communities(id) ON DELETE CASCADE,
        joined_at     TEXT NOT NULL DEFAULT TO_CHAR(CURRENT_TIMESTAMP, 'YYYY-MM-DD HH24:MI:SS'),
        PRIMARY KEY (user_id, community_id)
      );

      -- Gönderiler
      CREATE TABLE IF NOT EXISTS posts (
        id              SERIAL PRIMARY KEY,
        community_id    INTEGER REFERENCES communities(id) ON DELETE CASCADE,
        community_name  TEXT NOT NULL,
        community_logo  TEXT,
        content         TEXT NOT NULL,
        image_url       TEXT,
        event_image     TEXT,
        support_count   INTEGER NOT NULL DEFAULT 0,
        quality_score   REAL NOT NULL DEFAULT 0.0,
        rating_avg      REAL NOT NULL DEFAULT 0.0,
        rating_count    INTEGER NOT NULL DEFAULT 0,
        author_id       TEXT REFERENCES users(id) ON DELETE SET NULL,
        status          TEXT NOT NULL DEFAULT 'published',
        created_at      TEXT NOT NULL DEFAULT TO_CHAR(CURRENT_TIMESTAMP, 'YYYY-MM-DD HH24:MI:SS')
      );

      -- Destek oyları (haftalık limit için)
      CREATE TABLE IF NOT EXISTS post_supports (
        user_id     TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        post_id     INTEGER NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
        week_number INTEGER NOT NULL,
        year        INTEGER NOT NULL,
        created_at  TEXT NOT NULL DEFAULT TO_CHAR(CURRENT_TIMESTAMP, 'YYYY-MM-DD HH24:MI:SS'),
        PRIMARY KEY (user_id, post_id)
      );

      -- Kullanıcı puanları (1-5 yıldız, tek kullanıcı tek puan)
      CREATE TABLE IF NOT EXISTS post_ratings (
        user_id     TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        post_id     INTEGER NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
        rating      INTEGER NOT NULL CHECK (rating BETWEEN 1 AND 5),
        created_at  TEXT NOT NULL DEFAULT TO_CHAR(CURRENT_TIMESTAMP, 'YYYY-MM-DD HH24:MI:SS'),
        PRIMARY KEY (user_id, post_id)
      );

      -- Uygunsuz içerik bildirimleri (UGC moderasyon)
      CREATE TABLE IF NOT EXISTS post_reports (
        id          SERIAL PRIMARY KEY,
        post_id     INTEGER NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
        user_id     TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        reason      TEXT,
        status      TEXT NOT NULL DEFAULT 'open',
        created_at  TEXT NOT NULL DEFAULT TO_CHAR(CURRENT_TIMESTAMP, 'YYYY-MM-DD HH24:MI:SS'),
        UNIQUE (post_id, user_id)
      );

      -- Etkinlikler
      CREATE TABLE IF NOT EXISTS events (
        id            SERIAL PRIMARY KEY,
        community_id  INTEGER REFERENCES communities(id) ON DELETE CASCADE,
        title         TEXT NOT NULL,
        description   TEXT,
        event_date    TEXT NOT NULL,
        image_url     TEXT,
        location      TEXT,
        created_at    TEXT NOT NULL DEFAULT TO_CHAR(CURRENT_TIMESTAMP, 'YYYY-MM-DD HH24:MI:SS')
      );

      -- Etkinlik kayıtları
      CREATE TABLE IF NOT EXISTS event_registrations (
        user_id     TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        event_id    INTEGER NOT NULL REFERENCES events(id) ON DELETE CASCADE,
        registered_at TEXT NOT NULL DEFAULT TO_CHAR(CURRENT_TIMESTAMP, 'YYYY-MM-DD HH24:MI:SS'),
        PRIMARY KEY (user_id, event_id)
      );

      -- Rozetler (tanımlar)
      CREATE TABLE IF NOT EXISTS badges (
        id          SERIAL PRIMARY KEY,
        name        TEXT NOT NULL,
        icon        TEXT NOT NULL,
        description TEXT
      );

      -- Kullanıcı rozetleri
      CREATE TABLE IF NOT EXISTS user_badges (
        user_id   TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        badge_id  INTEGER NOT NULL REFERENCES badges(id) ON DELETE CASCADE,
        earned_at TEXT NOT NULL DEFAULT TO_CHAR(CURRENT_TIMESTAMP, 'YYYY-MM-DD HH24:MI:SS'),
        PRIMARY KEY (user_id, badge_id)
      );

      -- Bildirimler
      CREATE TABLE IF NOT EXISTS notifications (
        id          TEXT PRIMARY KEY,
        user_id     TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        title       TEXT NOT NULL,
        body        TEXT NOT NULL,
        type        TEXT NOT NULL DEFAULT 'info',
        is_read     INTEGER NOT NULL DEFAULT 0,
        created_at  TEXT NOT NULL DEFAULT TO_CHAR(CURRENT_TIMESTAMP, 'YYYY-MM-DD HH24:MI:SS')
      );

      -- FCM token'ları (push bildirim)
      CREATE TABLE IF NOT EXISTS fcm_tokens (
        user_id   TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        token     TEXT NOT NULL,
        platform  TEXT NOT NULL DEFAULT 'android',
        updated_at TEXT NOT NULL DEFAULT TO_CHAR(CURRENT_TIMESTAMP, 'YYYY-MM-DD HH24:MI:SS'),
        PRIMARY KEY (user_id, platform)
      );

      -- İndirim/kuponlar
      CREATE TABLE IF NOT EXISTS discounts (
        id            SERIAL PRIMARY KEY,
        company_name  TEXT NOT NULL,
        coupon_name   TEXT NOT NULL,
        discount_rate TEXT NOT NULL,
        logo_path     TEXT,
        color         TEXT
      );

      -- Takvim notları (kullanıcıya özel)
      CREATE TABLE IF NOT EXISTS calendar_notes (
        id        SERIAL PRIMARY KEY,
        user_id   TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        date      TEXT NOT NULL,
        note      TEXT NOT NULL,
        created_at TEXT NOT NULL DEFAULT TO_CHAR(CURRENT_TIMESTAMP, 'YYYY-MM-DD HH24:MI:SS')
      );

      -- Topluluk sohbet mesajları
      CREATE TABLE IF NOT EXISTS community_messages (
        id           SERIAL PRIMARY KEY,
        community_id INTEGER NOT NULL REFERENCES communities(id) ON DELETE CASCADE,
        user_id      TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        user_name    TEXT NOT NULL,
        content      TEXT NOT NULL,
        type         TEXT NOT NULL DEFAULT 'general',
        created_at   TEXT NOT NULL DEFAULT TO_CHAR(CURRENT_TIMESTAMP, 'YYYY-MM-DD HH24:MI:SS')
      );

      -- Şifre sıfırlama token'ları
      CREATE TABLE IF NOT EXISTS password_reset_tokens (
        id         TEXT PRIMARY KEY,
        user_id    TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        token_hash TEXT NOT NULL UNIQUE,
        expires_at TEXT NOT NULL,
        used       INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL DEFAULT TO_CHAR(CURRENT_TIMESTAMP, 'YYYY-MM-DD HH24:MI:SS')
      );

      -- İndeksler
      CREATE INDEX IF NOT EXISTS idx_posts_community ON posts(community_id);
      CREATE INDEX IF NOT EXISTS idx_community_messages ON community_messages(community_id, type, created_at);
      CREATE INDEX IF NOT EXISTS idx_posts_created ON posts(created_at DESC);
      CREATE INDEX IF NOT EXISTS idx_post_supports_user_week ON post_supports(user_id, year, week_number);
      CREATE INDEX IF NOT EXISTS idx_notifications_user ON notifications(user_id, is_read, created_at DESC);
      CREATE INDEX IF NOT EXISTS idx_events_date ON events(event_date);
      CREATE INDEX IF NOT EXISTS idx_communities_category ON communities(category);
      CREATE INDEX IF NOT EXISTS idx_calendar_notes_user_date ON calendar_notes(user_id, date);
      CREATE INDEX IF NOT EXISTS idx_post_ratings_post ON post_ratings(post_id);
      CREATE INDEX IF NOT EXISTS idx_post_reports_status ON post_reports(status);
    `);
  } else {
    await dbExec(`
      -- Kullanıcılar
      CREATE TABLE IF NOT EXISTS users (
        id          TEXT PRIMARY KEY,
        name        TEXT NOT NULL,
        email       TEXT UNIQUE NOT NULL,
        password_hash TEXT NOT NULL,
        role        TEXT NOT NULL DEFAULT 'student',
        department  TEXT,
        grade       TEXT,
        xp          INTEGER NOT NULL DEFAULT 0,
        profile_photo TEXT,
        created_at  TEXT NOT NULL DEFAULT (datetime('now'))
      );

      -- Refresh token'ları
      CREATE TABLE IF NOT EXISTS refresh_tokens (
        id          TEXT PRIMARY KEY,
        user_id     TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        token_hash  TEXT NOT NULL UNIQUE,
        expires_at  TEXT NOT NULL,
        created_at  TEXT NOT NULL DEFAULT (datetime('now'))
      );

      -- Topluluklar
      CREATE TABLE IF NOT EXISTS communities (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        name        TEXT NOT NULL,
        logo_path   TEXT,
        category    TEXT NOT NULL,
        score       REAL NOT NULL DEFAULT 0,
        member_count INTEGER NOT NULL DEFAULT 0,
        description TEXT,
        chairman_name TEXT,
        chairman_id TEXT REFERENCES users(id) ON DELETE SET NULL,
        created_at  TEXT NOT NULL DEFAULT (datetime('now'))
      );

      -- Topluluk üyelikleri
      CREATE TABLE IF NOT EXISTS community_members (
        user_id       TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        community_id  INTEGER NOT NULL REFERENCES communities(id) ON DELETE CASCADE,
        joined_at     TEXT NOT NULL DEFAULT (datetime('now')),
        PRIMARY KEY (user_id, community_id)
      );

      -- Gönderiler
      CREATE TABLE IF NOT EXISTS posts (
        id              INTEGER PRIMARY KEY AUTOINCREMENT,
        community_id    INTEGER REFERENCES communities(id) ON DELETE CASCADE,
        community_name  TEXT NOT NULL,
        community_logo  TEXT,
        content         TEXT NOT NULL,
        image_url       TEXT,
        event_image     TEXT,
        support_count   INTEGER NOT NULL DEFAULT 0,
        quality_score   REAL NOT NULL DEFAULT 0.0,
        rating_avg      REAL NOT NULL DEFAULT 0.0,
        rating_count    INTEGER NOT NULL DEFAULT 0,
        author_id       TEXT REFERENCES users(id) ON DELETE SET NULL,
        status          TEXT NOT NULL DEFAULT 'published',
        created_at      TEXT NOT NULL DEFAULT (datetime('now'))
      );

      -- Destek oyları (haftalık limit için)
      CREATE TABLE IF NOT EXISTS post_supports (
        user_id     TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        post_id     INTEGER NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
        week_number INTEGER NOT NULL,
        year        INTEGER NOT NULL,
        created_at  TEXT NOT NULL DEFAULT (datetime('now')),
        PRIMARY KEY (user_id, post_id)
      );

      -- Kullanıcı puanları (1-5 yıldız, tek kullanıcı tek puan)
      CREATE TABLE IF NOT EXISTS post_ratings (
        user_id     TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        post_id     INTEGER NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
        rating      INTEGER NOT NULL CHECK (rating BETWEEN 1 AND 5),
        created_at  TEXT NOT NULL DEFAULT (datetime('now')),
        PRIMARY KEY (user_id, post_id)
      );

      -- Uygunsuz içerik bildirimleri (UGC moderasyon)
      CREATE TABLE IF NOT EXISTS post_reports (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        post_id     INTEGER NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
        user_id     TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        reason      TEXT,
        status      TEXT NOT NULL DEFAULT 'open',
        created_at  TEXT NOT NULL DEFAULT (datetime('now')),
        UNIQUE (post_id, user_id)
      );

      -- Etkinlikler
      CREATE TABLE IF NOT EXISTS events (
        id            INTEGER PRIMARY KEY AUTOINCREMENT,
        community_id  INTEGER REFERENCES communities(id) ON DELETE CASCADE,
        title         TEXT NOT NULL,
        description   TEXT,
        event_date    TEXT NOT NULL,
        image_url     TEXT,
        location      TEXT,
        created_at    TEXT NOT NULL DEFAULT (datetime('now'))
      );

      -- Etkinlik kayıtları
      CREATE TABLE IF NOT EXISTS event_registrations (
        user_id     TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        event_id    INTEGER NOT NULL REFERENCES events(id) ON DELETE CASCADE,
        registered_at TEXT NOT NULL DEFAULT (datetime('now')),
        PRIMARY KEY (user_id, event_id)
      );

      -- Rozetler (tanımlar)
      CREATE TABLE IF NOT EXISTS badges (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        name        TEXT NOT NULL,
        icon        TEXT NOT NULL,
        description TEXT
      );

      -- Kullanıcı rozetleri
      CREATE TABLE IF NOT EXISTS user_badges (
        user_id   TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        badge_id  INTEGER NOT NULL REFERENCES badges(id) ON DELETE CASCADE,
        earned_at TEXT NOT NULL DEFAULT (datetime('now')),
        PRIMARY KEY (user_id, badge_id)
      );

      -- Bildirimler
      CREATE TABLE IF NOT EXISTS notifications (
        id          TEXT PRIMARY KEY,
        user_id     TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        title       TEXT NOT NULL,
        body        TEXT NOT NULL,
        type        TEXT NOT NULL DEFAULT 'info',
        is_read     INTEGER NOT NULL DEFAULT 0,
        created_at  TEXT NOT NULL DEFAULT (datetime('now'))
      );

      -- FCM token'ları (push bildirim)
      CREATE TABLE IF NOT EXISTS fcm_tokens (
        user_id   TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        token     TEXT NOT NULL,
        platform  TEXT NOT NULL DEFAULT 'android',
        updated_at TEXT NOT NULL DEFAULT (datetime('now')),
        PRIMARY KEY (user_id, platform)
      );

      -- İndirim/kuponlar
      CREATE TABLE IF NOT EXISTS discounts (
        id            INTEGER PRIMARY KEY AUTOINCREMENT,
        company_name  TEXT NOT NULL,
        coupon_name   TEXT NOT NULL,
        discount_rate TEXT NOT NULL,
        logo_path     TEXT,
        color         TEXT
      );

      -- Takvim notları (kullanıcıya özel)
      CREATE TABLE IF NOT EXISTS calendar_notes (
        id        INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id   TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        date      TEXT NOT NULL,
        note      TEXT NOT NULL,
        created_at TEXT NOT NULL DEFAULT (datetime('now'))
      );

      -- Topluluk sohbet mesajları
      CREATE TABLE IF NOT EXISTS community_messages (
        id           INTEGER PRIMARY KEY AUTOINCREMENT,
        community_id INTEGER NOT NULL REFERENCES communities(id) ON DELETE CASCADE,
        user_id      TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        user_name    TEXT NOT NULL,
        content      TEXT NOT NULL,
        type         TEXT NOT NULL DEFAULT 'general',
        created_at   TEXT NOT NULL DEFAULT (datetime('now'))
      );

      -- Şifre sıfırlama token'ları
      CREATE TABLE IF NOT EXISTS password_reset_tokens (
        id         TEXT PRIMARY KEY,
        user_id    TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        token_hash TEXT NOT NULL UNIQUE,
        expires_at TEXT NOT NULL,
        used       INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL DEFAULT (datetime('now'))
      );

      -- İndeksler
      CREATE INDEX IF NOT EXISTS idx_posts_community ON posts(community_id);
      CREATE INDEX IF NOT EXISTS idx_community_messages ON community_messages(community_id, type, created_at);
      CREATE INDEX IF NOT EXISTS idx_posts_created ON posts(created_at DESC);
      CREATE INDEX IF NOT EXISTS idx_post_supports_user_week ON post_supports(user_id, year, week_number);
      CREATE INDEX IF NOT EXISTS idx_notifications_user ON notifications(user_id, is_read, created_at DESC);
      CREATE INDEX IF NOT EXISTS idx_events_date ON events(event_date);
      CREATE INDEX IF NOT EXISTS idx_communities_category ON communities(category);
      CREATE INDEX IF NOT EXISTS idx_calendar_notes_user_date ON calendar_notes(user_id, date);
      CREATE INDEX IF NOT EXISTS idx_post_ratings_post ON post_ratings(post_id);
      CREATE INDEX IF NOT EXISTS idx_post_reports_status ON post_reports(status);
    `);
  }

  // ---- posts tablosu yeni kolonları (mevcut veritabanları için) ----
  if (isPostgres) {
    await dbExec(`
      DO $$
      BEGIN
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'posts' AND column_name = 'author_id') THEN
          ALTER TABLE posts ADD COLUMN author_id TEXT REFERENCES users(id) ON DELETE SET NULL;
        END IF;
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'posts' AND column_name = 'status') THEN
          ALTER TABLE posts ADD COLUMN status TEXT NOT NULL DEFAULT 'published';
        END IF;
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'posts' AND column_name = 'rating_avg') THEN
          ALTER TABLE posts ADD COLUMN rating_avg REAL NOT NULL DEFAULT 0.0;
        END IF;
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'posts' AND column_name = 'rating_count') THEN
          ALTER TABLE posts ADD COLUMN rating_count INTEGER NOT NULL DEFAULT 0;
        END IF;
      END $$;
    `);
  } else {
    const postCols = await new Promise((resolve, reject) => {
      getDb().all('PRAGMA table_info(posts)', (err, rows) => err ? reject(err) : resolve(rows));
    });
    const hasCol = (name) => postCols.some(c => c.name === name);
    if (!hasCol('author_id')) await dbExec('ALTER TABLE posts ADD COLUMN author_id TEXT REFERENCES users(id) ON DELETE SET NULL');
    if (!hasCol('status')) await dbExec("ALTER TABLE posts ADD COLUMN status TEXT NOT NULL DEFAULT 'published'");
    if (!hasCol('rating_avg')) await dbExec('ALTER TABLE posts ADD COLUMN rating_avg REAL NOT NULL DEFAULT 0.0');
    if (!hasCol('rating_count')) await dbExec('ALTER TABLE posts ADD COLUMN rating_count INTEGER NOT NULL DEFAULT 0');
  }

  console.log('[migrate] Tablo şeması oluşturuldu.');
}

if (require.main === module) {
  migrate().catch(console.error);
}

module.exports = { migrate };
