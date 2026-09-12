const path = require('path');
const fs = require('fs');
const bcrypt = require('bcryptjs');
const crypto = require('crypto');
const { v4: uuidv4 } = require('uuid');
require('dotenv').config({ path: path.join(__dirname, '../../.env') });
const { dbRun, dbGet, dbAll, dbTransaction } = require('../config/database');
const { migrate } = require('./migrate');

const dataDir = path.join(__dirname, '../../../assets/data');
const homeData = JSON.parse(fs.readFileSync(path.join(dataDir, 'home_data.json'), 'utf8'));
const newgencData = JSON.parse(fs.readFileSync(path.join(dataDir, 'newgenc_data.json'), 'utf8'));
const leaderData = JSON.parse(fs.readFileSync(path.join(dataDir, 'leaderboard_data.json'), 'utf8'));

async function seed() {
  await migrate();

  await dbTransaction(async () => {
    // Admin kullanıcı — güvenli şifre zorunlu
    const adminEmail = process.env.ADMIN_EMAIL || 'admin@newgenc.com';
    let adminPassword = process.env.ADMIN_PASSWORD;

    if (!adminPassword) {
      if (process.env.NODE_ENV === 'production') {
        throw new Error('[seed] HATA: ADMIN_PASSWORD env değişkeni production ortamında zorunludur!');
      }
      adminPassword = crypto.randomBytes(14).toString('base64url');
      // GÜVENLİK: Geçici şifre sadece .admin_credentials dosyasına yazılır (console.log DEĞİL)
      const credPath = path.join(__dirname, '../../.admin_credentials');
      fs.writeFileSync(credPath, `ADMIN_EMAIL=${adminEmail}\nADMIN_PASSWORD=${adminPassword}\n`, { mode: 0o600 });
      console.warn('\n⚠️  UYARI: ADMIN_PASSWORD ayarlanmamış!');
      console.warn(`   Geçici şifre üretildi ve .admin_credentials dosyasına kaydedildi.`);
      console.warn('   Bu dosyayı güvenli bir yere taşıyın ve içindeki değeri .env dosyanıza ekleyin.\n');
    }

    const adminExists = await dbGet('SELECT id FROM users WHERE email = ?', [adminEmail]);
    if (!adminExists) {
      const adminId = 'admin-001';
      await dbRun(
        `INSERT INTO users (id, name, email, password_hash, role, created_at)
         VALUES (?, 'Admin', ?, ?, 'admin', datetime('now'))`,
        [adminId, adminEmail, bcrypt.hashSync(adminPassword, 10)]
      );
      console.log('[seed] Admin kullanıcı oluşturuldu:', adminEmail);
    }

    // Demo öğrenci kullanıcıları
    const demoStudents = [
      { name: 'Abdurrahman', email: 'abdurrahman@sakarya.edu.tr' },
      { name: 'Zeynep',      email: 'zeynep@sakarya.edu.tr' },
      { name: 'Mehmet',      email: 'mehmet@sakarya.edu.tr' },
      { name: 'Elif',        email: 'elif@sakarya.edu.tr' },
      { name: 'Mert',        email: 'mert@sakarya.edu.tr' },
      { name: 'Selin',       email: 'selin@sakarya.edu.tr' },
    ];
    const defaultPass = bcrypt.hashSync('Demo123!', 10);
    for (const s of demoStudents) {
      const ex = await dbGet('SELECT id FROM users WHERE email = ?', [s.email]);
      if (!ex) {
        await dbRun(
          `INSERT INTO users (id, name, email, password_hash, role, department, grade)
           VALUES (?, ?, ?, ?, 'student', 'Bilgisayar Mühendisliği', '3. Sınıf')`,
          [uuidv4(), s.name, s.email, defaultPass]
        );
      }
    }
    console.log('[seed] Demo öğrenciler oluşturuldu.');

    // Topluluklar
    const { c: comCount } = await dbGet('SELECT COUNT(*) as c FROM communities');
    if (comCount === 0) {
      for (const t of newgencData.topluluklar) {
        await dbRun(
          `INSERT INTO communities (name, logo_path, category, score, member_count, description, chairman_name)
           VALUES (?, ?, ?, ?, ?, ?, ?)`,
          [t.ad, t.logo_path, t.kategori, t.puan, t.uye_sayisi, t.aciklama || '', t.baskan_adi || 'Belirtilmedi']
        );
      }
      console.log(`[seed] ${newgencData.topluluklar.length} topluluk oluşturuldu.`);
    }

    // İndirimler / kuponlar
    const { c: discountCount } = await dbGet('SELECT COUNT(*) as c FROM discounts');
    if (discountCount === 0) {
      for (const k of homeData.kuponlar) {
        await dbRun(
          `INSERT INTO discounts (company_name, coupon_name, discount_rate, logo_path, color)
           VALUES (?, ?, ?, ?, ?)`,
          [k.sirketAd, k.kuponAdi, k.indirimOrani, k.logoPath, k.renk]
        );
      }
      console.log(`[seed] ${homeData.kuponlar.length} kupon oluşturuldu.`);
    }

    // Gönderiler
    const { c: postCount } = await dbGet('SELECT COUNT(*) as c FROM posts');
    if (postCount === 0) {
      for (let i = 0; i < homeData.gonderiler.length; i++) {
        const g = homeData.gonderiler[i];
        await dbRun(
          `INSERT INTO posts (community_name, community_logo, content, image_url, event_image, support_count, quality_score, created_at)
           VALUES (?, ?, ?, ?, ?, ?, ?, datetime('now', '-' || ? || ' hours'))`,
          [
            g.toplulukAdi,
            g.topluluk_logo || g.toplulukLogo || '',
            g.metin,
            g.resimUrl || null,
            g.etkinlik_gorseli || null,
            g.destekPuani,
            g.kalitePuani,
            i * 3,
          ]
        );
      }
      console.log(`[seed] ${homeData.gonderiler.length} gönderi oluşturuldu.`);
    }

    // Rozetler
    const { c: badgeCount } = await dbGet('SELECT COUNT(*) as c FROM badges');
    if (badgeCount === 0) {
      const badges = [
        { name: 'İlk Adım',         icon: '🚀', description: 'İlk kez platforma katıldı' },
        { name: 'Sosyal Kelebek',   icon: '🦋', description: '5 topluluğa katıldı' },
        { name: 'Destek Kahramanı', icon: '⭐', description: '50 destek verdi' },
        { name: 'Etkinlik Delisi',  icon: '🎯', description: '10 etkinliğe katıldı' },
        { name: 'Astronot',         icon: '👨‍🚀', description: 'En yüksek XP puanı' },
        { name: 'Topluluk Öncüsü', icon: '🏆', description: 'Bir topluluğun başkanı' },
      ];
      for (const b of badges) {
        await dbRun('INSERT INTO badges (name, icon, description) VALUES (?, ?, ?)', [b.name, b.icon, b.description]);
      }
      console.log(`[seed] ${badges.length} rozet tanımı oluşturuldu.`);
    }

    // Liderlik tablosu için XP güncelleme
    const leaderStudents = leaderData.liderlik_tablosu.haftanin_uyeler || [];
    const leaderComs = leaderData.liderlik_tablosu.haftanin_topluluklari || [];

    for (const s of leaderStudents) {
      await dbRun('UPDATE users SET xp = ? WHERE name = ?', [s.puan, s.ad]);
    }
    for (const c of leaderComs) {
      await dbRun('UPDATE communities SET score = ? WHERE name LIKE ?', [c.puan, `%${c.ad}%`]);
    }

    console.log('[seed] Liderlik tablosu verileri güncellendi.');
    console.log('[seed] Seed tamamlandı ✓');
  });
}

seed().catch((err) => {
  console.error('[seed] Hata:', err.message);
  process.exit(1);
});
