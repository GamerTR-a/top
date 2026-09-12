import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthUser;
import '../models/auth_user_model.dart';
import '../models/topluluk.dart';
import '../models/post_model.dart';
import '../models/discount_model.dart';
import '../models/user_profile_model.dart';
import '../models/leaderboard_model.dart';
import '../models/ticket_model.dart';
import '../utils/file_validator.dart';
import 'local_storage_service.dart';
import 'location_service.dart';


class SupabaseDataService {
  static final _db = Supabase.instance.client;

  // ── Liste önbelleği anahtarları (LocalStorageService ile eşleşir) ────────
  static const String _keyPosts = 'offline_cached_posts';
  static const String _keyKuponlar = LocalStorageService.keyCachedKuponlar;
  static const String _keyEtkinlikler = LocalStorageService.keyCachedEtkinlikler;
  static const String _keyTopluluklar = LocalStorageService.keyCachedTopluluklar;

  /// Başarılı ağ yanıtını arka planda yerel önbelleğe yazar (asla bloklamaz).
  Future<void> _cacheList(String key, List<dynamic> rows) async {
    try {
      final store = await LocalStorageService.getInstance();
      await store.cacheJsonList(
        key,
        rows.map((e) => Map<String, dynamic>.from(e as Map)).toList(),
      );
    } catch (e) {
      debugPrint('[SupabaseDataService] cache write failed ($key): $e');
    }
  }

  /// Önbellekteki satırları okur (ağ beklemez); yoksa boş liste.
  List<Map<String, dynamic>> _readCache(String key) {
    return LocalStorageService.instance?.getCachedJsonList(key) ?? const [];
  }

  String get _uid {
    final uid = _db.auth.currentUser?.id;
    if (uid == null) {
      throw StateError('Oturum süresi doldu. Lütfen tekrar giriş yapın.');
    }
    return uid;
  }

  // ── Yardımcı: ISO haftası ────────────────────────────────────────────────────
  static int _isoWeek(DateTime d) {
    final jan4 = DateTime(d.year, 1, 4);
    final startOfWeek1 = jan4.subtract(Duration(days: jan4.weekday - 1));
    if (d.isBefore(startOfWeek1)) return _isoWeek(DateTime(d.year - 1, 12, 28));
    return ((d.difference(startOfWeek1).inDays) ~/ 7) + 1;
  }

  // ── Topluluklar ──────────────────────────────────────────────────────────────

  Future<List<Topluluk>> getTopluluklar({
    String? search,
    String? category,
    String sort = 'score',
    int page = 1,
    int limit = 50,
  }) async {
    try {
      var query = _db.from('communities').select();
      if (search != null && search.isNotEmpty) {
        query = query.ilike('name', '%$search%');
      }
      if (category != null && category.isNotEmpty) {
        query = query.eq('category', category);
      }
      final res = await query
          .order(sort, ascending: false)
          .range((page - 1) * limit, page * limit - 1);
      final list = (res as List)
          .map((j) => Topluluk.fromApiJson(j as Map<String, dynamic>))
          .toList();
      if (list.isNotEmpty) {
        // Yalnızca varsayılan (filtresiz) liste önbelleğe alınır.
        if ((search == null || search.isEmpty) &&
            (category == null || category.isEmpty) &&
            page == 1) {
          unawaited(_cacheList(_keyTopluluklar, res));
        }
        return list;
      }
    } catch (e) {
      debugPrint('[SupabaseDataService] getTopluluklar fallback triggered: $e');
    }
    return _demoTopluluklar.where((t) {
      if (search != null && search.isNotEmpty && !t.ad.toLowerCase().contains(search.toLowerCase())) {
        return false;
      }
      if (category != null && category.isNotEmpty && t.kategori != category) {
        return false;
      }
      return true;
    }).toList();
  }

  /// Yerel önbellekteki toplulukları anında döndürür (ağ beklemez).
  List<Topluluk> getCachedTopluluklar() =>
      _readCache(_keyTopluluklar).map(Topluluk.fromApiJson).toList();

  static final List<Topluluk> _demoTopluluklar = [
    Topluluk(
      id: 1,
      ad: 'Girişimci Mühendisler Topluluğu',
      kategori: 'Mühendislik',
      aciklama: 'SUBÜ ve SAÜ ortak girişimcilik ve inovasyon topluluğu.',
      logoPath: 'assets/gem.png',
      uyeSayisi: 420,
      puan: 95.0,
      baskanAdi: 'Ahmet Safa Zengin',
    ),
    Topluluk(
      id: 2,
      ad: 'Bilişim Sistemleri Mühendisliği Topluluğu',
      kategori: 'Teknoloji',
      aciklama: 'Yazılım, yapay zeka ve siber güvenlik projeleri geliştiriyoruz.',
      logoPath: 'assets/gem.png',
      uyeSayisi: 310,
      puan: 88.0,
      baskanAdi: 'Melik Mirza Çelik',
    ),
    Topluluk(
      id: 3,
      ad: 'Tarih Öğrenci Topluluğu',
      kategori: 'Sosyal',
      aciklama: 'Tarih, kültür gezileri ve akademik söyleşiler.',
      logoPath: 'assets/gem.png',
      uyeSayisi: 215,
      puan: 82.0,
      baskanAdi: 'İbrahim Gece',
    ),
    Topluluk(
      id: 4,
      ad: 'Damla Öğrenci Topluluğu',
      kategori: 'Sosyal Sorumluluk',
      aciklama: 'Gönüllülük faaliyetleri ve iyilik projeleri.',
      logoPath: 'assets/gem.png',
      uyeSayisi: 180,
      puan: 79.0,
      baskanAdi: 'Aygül Aladı',
    ),
    Topluluk(
      id: 5,
      ad: 'Yazılım ve Yapay Zeka Topluluğu',
      kategori: 'Teknoloji',
      aciklama: 'Python, makine öğrenmesi ve açık kaynak kod projeleri geliştiriyoruz.',
      logoPath: 'assets/gem.png',
      uyeSayisi: 530,
      puan: 92.5,
      baskanAdi: 'Zeynep Yılmaz',
    ),
    Topluluk(
      id: 6,
      ad: 'Siber Güvenlik ve Hacking Kulübü',
      kategori: 'Teknoloji',
      aciklama: 'CTF yarışmaları, sızma testleri ve ağ güvenliği atölyeleri.',
      logoPath: 'assets/gem.png',
      uyeSayisi: 380,
      puan: 91.0,
      baskanAdi: 'Emre Kaya',
    ),
    Topluluk(
      id: 7,
      ad: 'IEEE Student Branch Sakarya',
      kategori: 'Mühendislik',
      aciklama: 'Otonom araçlar, robotiğin temelleri ve uluslararası teknik konferanslar.',
      logoPath: 'assets/gem.png',
      uyeSayisi: 620,
      puan: 96.0,
      baskanAdi: 'Elif Demir',
    ),
    Topluluk(
      id: 8,
      ad: 'Siber & E-Spor Topluluğu',
      kategori: 'Spor',
      aciklama: 'Valorant, LoL ve CS2 üniversiteler arası lig turnuvaları.',
      logoPath: 'assets/gem.png',
      uyeSayisi: 490,
      puan: 89.0,
      baskanAdi: 'Oğuzhan Bulut',
    ),
    Topluluk(
      id: 9,
      ad: 'Doğa Sporları ve Dağcılık Kulübü (SAÜDAK)',
      kategori: 'Doğa & Gezi',
      aciklama: 'Trekking, kampçılık, kaya tırmanışı ve zirve tırmanış etkinlikleri.',
      logoPath: 'assets/gem.png',
      uyeSayisi: 340,
      puan: 87.5,
      baskanAdi: 'Burak Arslan',
    ),
    Topluluk(
      id: 10,
      ad: 'Müzik ve Enstrüman Topluluğu',
      kategori: 'Sanat & Müzik',
      aciklama: 'Kampüs konserleri, jam sessionlar ve akustik grup performansları.',
      logoPath: 'assets/gem.png',
      uyeSayisi: 290,
      puan: 85.0,
      baskanAdi: 'Selin Avcı',
    ),
    Topluluk(
      id: 11,
      ad: 'Tiyatro ve Sahne Sanatları Kulübü',
      kategori: 'Sanat & Müzik',
      aciklama: 'Oyun gösterimleri, pandomim ve beden dili drama eğitimi.',
      logoPath: 'assets/gem.png',
      uyeSayisi: 210,
      puan: 83.5,
      baskanAdi: 'Kaan Öztürk',
    ),
    Topluluk(
      id: 12,
      ad: 'Fotoğrafçılık ve Sinema Topluluğu',
      kategori: 'Kültür',
      aciklama: 'Foto safari turları, kısa film çekimleri ve senaryo atölyesi.',
      logoPath: 'assets/gem.png',
      uyeSayisi: 265,
      puan: 86.0,
      baskanAdi: 'Deniz Yıldız',
    ),
    Topluluk(
      id: 13,
      ad: 'Gökbilim ve Uzay Teknolojileri',
      kategori: 'Bilim',
      aciklama: 'Teleskopla gökyüzü gözlemleri, model roket ve uydu projeleri.',
      logoPath: 'assets/gem.png',
      uyeSayisi: 310,
      puan: 90.0,
      baskanAdi: 'Mert Şahin',
    ),
    Topluluk(
      id: 14,
      ad: 'Genç Kızılay ve Arama Kurtarma Topluluğu',
      kategori: 'Sosyal Sorumluluk',
      aciklama: 'Kan bağışı kampanyaları, ilk yardım eğitimi ve afet hazırlığı.',
      logoPath: 'assets/gem.png',
      uyeSayisi: 450,
      puan: 94.0,
      baskanAdi: 'Fatma Yücel',
    ),
    Topluluk(
      id: 15,
      ad: 'Kariyer ve Finans Kulübü',
      kategori: 'Kariyer',
      aciklama: 'CEO söyleşileri, CV hazırlama teknikleri ve borsa analizi.',
      logoPath: 'assets/gem.png',
      uyeSayisi: 370,
      puan: 88.5,
      baskanAdi: 'Caner Güneş',
    ),
    Topluluk(
      id: 16,
      ad: 'Felsefe ve Düşünce Topluluğu',
      kategori: 'Kültür',
      aciklama: 'Kitap analizleri, etik tartışmaları ve açık oturum panelleri.',
      logoPath: 'assets/gem.png',
      uyeSayisi: 175,
      puan: 81.0,
      baskanAdi: 'Ecem Özkan',
    ),
    Topluluk(
      id: 17,
      ad: 'Biyomedikal ve Biyoteknoloji Topluluğu',
      kategori: 'Mühendislik',
      aciklama: 'Tıbbi cihaz tasarımı, genetik mühendisliği ve protez Ar-Ge.',
      logoPath: 'assets/gem.png',
      uyeSayisi: 230,
      puan: 89.5,
      baskanAdi: 'Tarkan Aksoy',
    ),
    Topluluk(
      id: 18,
      ad: 'Satranç ve Zeka Oyunları Kulübü',
      kategori: 'Spor',
      aciklama: 'Haftalık satranç turnuvaları, Go ve zeka oyunları ligi.',
      logoPath: 'assets/gem.png',
      uyeSayisi: 195,
      puan: 84.0,
      baskanAdi: 'Barış Erdem',
    ),
  ];

  Future<Map<String, dynamic>> getCommunityActivities(int communityId) async {
    try {
      final posts = await _db
          .from('posts')
          .select()
          .eq('community_id', communityId)
          .order('created_at', ascending: false)
          .limit(10);
      final events = await _db
          .from('events')
          .select()
          .eq('community_id', communityId)
          .order('event_date', ascending: true);
      return {'posts': posts, 'events': events};
    } catch (_) {
      return {'posts': [], 'events': []};
    }
  }

  // ── Topluluk harici sohbet bağlantıları (Telegram / Discord) ────────────────

  /// Topluluğun harici sohbet bağlantılarını döndürür: {platform: url}
  Future<Map<String, String>> getCommunityLinks(int communityId) async {
    try {
      final res = await _db
          .from('community_links')
          .select('platform, url')
          .eq('community_id', communityId);
      return {
        for (final r in (res as List))
          (r as Map)['platform'] as String: r['url'] as String,
      };
    } catch (e) {
      debugPrint('[SupabaseDataService] getCommunityLinks failed: $e');
      return {};
    }
  }

  /// Başkan/admin: topluluk için bir platform bağlantısı ekler veya günceller.
  /// Platform: 'telegram' | 'discord' | 'whatsapp' | 'instagram'
  Future<void> setCommunityLink(
    int communityId,
    String platform,
    String url,
  ) async {
    final trimmed = url.trim();
    final uri = Uri.tryParse(trimmed);
    if (trimmed.isEmpty ||
        !trimmed.startsWith('https://') ||
        uri == null ||
        !uri.hasAuthority) {
      throw StateError('Geçerli bir https bağlantısı girin.');
    }
    await _db.from('community_links').upsert(
      {'community_id': communityId, 'platform': platform, 'url': trimmed},
      onConflict: 'community_id,platform',
    );
  }

  /// Başkan/admin: topluluk için harici platform bağlantılarını topluca günceller.
  Future<void> updateCommunityLinks(
    int communityId,
    Map<String, String> links,
  ) async {
    for (final entry in links.entries) {
      final platform = entry.key;
      final url = entry.value.trim();
      if (url.isNotEmpty) {
        await setCommunityLink(communityId, platform, url);
      }
    }
  }


  /// Başkan/admin: bir platform bağlantısını kaldırır.
  Future<void> removeCommunityLink(int communityId, String platform) async {
    await _db
        .from('community_links')
        .delete()
        .eq('community_id', communityId)
        .eq('platform', platform);
  }

  // ── Başkan/Admin: Topluluk detay güncelleme / silme ────────────────────────────

  /// Topluluk detaylarını günceller (admin veya başkan RPC ile).
  /// Not: RLS politikası admin yazmasına izin verir; başkan için RPC gerekir.
  Future<void> updateCommunityDetails({
    required int communityId,
    required String name,
    required String description,
    required String category,
    String? logoPath,
  }) async {
    final updates = <String, dynamic>{
      'name': name,
      'description': description,
      'category': category,
    };
    if (logoPath != null && logoPath.isNotEmpty) {
      updates['logo_path'] = logoPath;
    }
    await _db.from('communities').update(updates).eq('id', communityId);
  }

  /// Topluluğu siler (sadece admin).
  Future<void> deleteCommunity(int communityId) async {
    await _db.from('communities').delete().eq('id', communityId);
  }

  // ── Başkan: Topluluk üye / gönderi yönetimi ────────────────────────────────────

  /// Topluluğun üyelerini döndürür (profil ve e-posta bilgileriyle birlikte).
  Future<List<Map<String, dynamic>>> getCommunityMembers(int communityId) async {
    try {
      final res = await _db
          .from('community_members')
          .select('user_id, joined_at, profiles(id, name, email, profile_photo, xp, role, department)')
          .eq('community_id', communityId)
          .order('joined_at', ascending: true);
      return List<Map<String, dynamic>>.from(res as List);
    } catch (e) {
      debugPrint('[SupabaseDataService] getCommunityMembers failed: $e');
      return [];
    }
  }

  /// Başkanın yönettiği topluluk(lar)ı döndürür.
  Future<List<Topluluk>> getCommunitiesForBaskan(String userId) async {
    try {
      final res = await _db
          .from('communities')
          .select()
          .eq('chairman_id', userId);
      return (res as List)
          .map((item) => Topluluk.fromApiJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[SupabaseDataService] getCommunitiesForBaskan failed: $e');
      return [];
    }
  }


  /// Topluluğun gönderilerini döndürür (moderation için).
  Future<List<Map<String, dynamic>>> getCommunityPosts(int communityId) async {
    try {
      final res = await _db
          .from('posts')
          .select()
          .eq('community_id', communityId)
          .order('created_at', ascending: false)
          .limit(100);
      return List<Map<String, dynamic>>.from(res as List);
    } catch (e) {
      debugPrint('[SupabaseDataService] getCommunityPosts failed: $e');
      return [];
    }
  }

  /// Başkan/admin: topluluktan üye çıkarır.
  Future<void> removeCommunityMember(int communityId, String userId) async {
    await _db
        .from('community_members')
        .delete()
        .eq('community_id', communityId)
        .eq('user_id', userId);
    // Sayacı azalt (best-effort)
    await _db
        .rpc('decrement_community_member', params: {'community_id': communityId})
        .catchError((_) {});
  }

  /// Başkan/admin: gönderiyi siler.
  Future<void> deletePost(int postId) async {
    await _db.from('posts').delete().eq('id', postId);
  }

  Future<bool> isMember(int communityId) async {
    try {
      final res = await _db
          .from('community_members')
          .select('user_id')
          .eq('user_id', _uid)
          .eq('community_id', communityId)
          .maybeSingle();
      return res != null;
    } catch (_) {
      return false;
    }
  }

  Future<void> joinCommunity(int communityId) async {
    try {
      await _db.from('community_members').upsert({
        'user_id': _uid,
        'community_id': communityId,
      });
      await _db
          .rpc(
            'increment_community_member',
            params: {'community_id': communityId},
          )
          .catchError((_) {});
    } catch (_) {}
  }

  Future<void> leaveCommunity(int communityId) async {
    try {
      await _db
          .from('community_members')
          .delete()
          .eq('user_id', _uid)
          .eq('community_id', communityId);
      await _db
          .rpc(
            'decrement_community_member',
            params: {'community_id': communityId},
          )
          .catchError((_) {});
    } catch (_) {}
  }

  // ── Gönderiler ───────────────────────────────────────────────────────────────

  Future<List<PostModel>> getGonderiler({int page = 1, int limit = 15}) async {
    try {
      final res = await _db
          .from('posts')
          .select()
          .order('created_at', ascending: false)
          .range((page - 1) * limit, page * limit - 1);
      final list = (res as List)
          .map((j) => PostModel.fromApiJson(j as Map<String, dynamic>))
          .toList();
      if (list.isNotEmpty) {
        // Yalnızca ilk sayfa (varsayılan) önbelleğe alınır.
        if (page == 1) unawaited(_cacheList(_keyPosts, res));
        return list;
      }
    } catch (e) {
      debugPrint('[SupabaseDataService] getGonderiler fallback triggered: $e');
    }
    return _demoGonderiler;
  }

  /// Yerel önbellekteki gönderileri anında döndürür (ağ beklemez).
  List<PostModel> getCachedGonderiler() =>
      _readCache(_keyPosts).map(PostModel.fromApiJson).toList();

  static final List<PostModel> _demoGonderiler = [
    PostModel(
      id: 1,
      toplulukAdi: 'Girişimci Mühendisler Topluluğu',
      toplulukLogo: 'assets/gem.png',
      metin: 'Girişimcilik ve İnovasyon Zirvesi \'26 başvuruları başladı! SUBÜ ve SAÜ öğrencilerinin geliştirdiği projeler jüri karşısına çıkıyor.',
      tarih: '3 saat önce',
      destekPuani: 142,
      kalitePuani: 4.9,
    ),
    PostModel(
      id: 2,
      toplulukAdi: 'Bilişim Sistemleri Mühendisliği Topluluğu',
      toplulukLogo: 'assets/gem.png',
      metin: 'Yapay Zeka & Derin Öğrenme Atölyesi bu Perşembe kampüs kütüphane seminer salonunda! Katılım ücretsizdir.',
      tarih: '7 saat önce',
      destekPuani: 98,
      kalitePuani: 4.8,
    ),
    PostModel(
      id: 3,
      toplulukAdi: 'Tarih Öğrenci Topluluğu',
      toplulukLogo: 'assets/gem.png',
      metin: 'Hafta sonu Taraklı - Göynük Kültür Gezimiz gerçekleştirildi. Katılan tüm üyelerimize teşekkür ederiz!',
      tarih: '1 gün önce',
      destekPuani: 67,
      kalitePuani: 4.7,
    ),
  ];

  Future<Map<String, dynamic>> getSupportStatus() async {
    try {
      final now = DateTime.now();
      final week = _isoWeek(now);
      final year = now.year;
      final res = await _db
          .from('post_supports')
          .select('post_id')
          .eq('user_id', _uid)
          .eq('year', year)
          .eq('week_number', week);
      final ids = (res as List).map((r) => (r as Map)['post_id']).toList();
      return {'weeklyUsed': ids.length, 'supportedPostIds': ids};
    } catch (_) {
      return {'weeklyUsed': 0, 'supportedPostIds': []};
    }
  }

  Future<Map<String, dynamic>> supportPost(int postId) async {
    try {
      final now = DateTime.now();
      final week = _isoWeek(now);
      final year = now.year;
      await _db.from('post_supports').insert({
        'user_id': _uid,
        'post_id': postId,
        'week_number': week,
        'year': year,
      });
      await _db.rpc('increment_post_support', params: {'post_id': postId});
      final status = await getSupportStatus();
      final post = await _db
          .from('posts')
          .select('support_count')
          .eq('id', postId)
          .single();
      return {
        'supportCount': post['support_count'],
        'weeklyUsed': status['weeklyUsed'],
      };
    } catch (_) {
      return {'supportCount': 100, 'weeklyUsed': 1};
    }
  }

  Future<void> unsupportPost(int postId) async {
    try {
      await _db
          .from('post_supports')
          .delete()
          .eq('user_id', _uid)
          .eq('post_id', postId);
      await _db.rpc('decrement_post_support', params: {'post_id': postId});
    } catch (_) {}
  }

  Future<PostModel> createPost({
    required int communityId,
    required String content,
    String? imageUrl,
    bool isEvent = false,
  }) async {
    if (content.isEmpty || content.length > 5000) {
      throw StateError('Gönderi içeriği 1-5000 karakter arasında olmalıdır.');
    }
    final comm = await _db
        .from('communities')
        .select('name, logo_path')
        .eq('id', communityId)
        .single();
    final res = await _db
        .from('posts')
        .insert({
          'community_id': communityId,
          'community_name': comm['name'] as String,
          'community_logo': comm['logo_path'],
          'user_id': _uid,
          'content': content,
          'status': 'published',
          'is_event': isEvent,
          if (imageUrl != null && imageUrl.isNotEmpty) 'image_url': imageUrl,
        })
        .select()
        .single();
    return PostModel.fromApiJson(res);
  }

  /// Etkinliğe katıl
  Future<void> joinEvent(int postId) async {
    try {
      await _db.from('event_participants').upsert(
        {'post_id': postId, 'user_id': _uid},
        onConflict: 'post_id,user_id',
      );
    } catch (e) {
      debugPrint('[SupabaseDataService] joinEvent failed: $e');
    }
  }

  /// Etkinlikten ayrıl
  Future<void> leaveEvent(int postId) async {
    try {
      await _db
          .from('event_participants')
          .delete()
          .eq('post_id', postId)
          .eq('user_id', _uid);
    } catch (e) {
      debugPrint('[SupabaseDataService] leaveEvent failed: $e');
    }
  }

  /// Etkinliğe katılan öğrencilerin listesi (Başkan Paneli için profil ve e-posta bilgileriyle)
  Future<List<Map<String, dynamic>>> getEventParticipants(int postId) async {
    try {
      final res = await _db
          .from('event_participants')
          .select('user_id, created_at, profiles(id, name, email, department, profile_photo, role)')
          .eq('post_id', postId)
          .order('created_at', ascending: true);
      return List<Map<String, dynamic>>.from(res as List);
    } catch (e) {
      debugPrint('[SupabaseDataService] getEventParticipants failed: $e');
      return [];
    }
  }


  // ── Başkan toplulukları (gönderi oluştururken yalnızca kendi toplulukları) ──

  Future<List<Topluluk>> getBaskanCommunities() async {
    try {
      final res = await _db
          .from('communities')
          .select()
          .eq('chairman_id', _uid)
          .order('score', ascending: false);
      return (res as List)
          .map((j) => Topluluk.fromApiJson(j as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[SupabaseDataService] getBaskanCommunities failed: $e');
      return [];
    }
  }

  // ── Puanlama (1-5 yıldız, kişi başı tek puan, upsert ile güncellenebilir) ──

  Future<Map<String, dynamic>> ratePost(int postId, int rating) async {
    if (rating < 1 || rating > 5) {
      throw StateError('Puan 1-5 arasında olmalıdır.');
    }
    final res = await _db.rpc('upsert_post_rating', params: {
      'p_post_id': postId,
      'p_rating': rating,
    });
    return (res as Map?)?.cast<String, dynamic>() ?? {};
  }

  /// Kullanıcının verilen gönderilere verdiği puanları döndürür: {postId: rating}
  Future<Map<int, int>> getMyRatings(List<int> postIds) async {
    if (postIds.isEmpty) return {};
    try {
      final res = await _db
          .from('post_ratings')
          .select('post_id, rating')
          .eq('user_id', _uid)
          .inFilter('post_id', postIds);
      return {
        for (final r in (res as List))
          (r as Map)['post_id'] as int: (r['rating'] as num).toInt(),
      };
    } catch (e) {
      debugPrint('[SupabaseDataService] getMyRatings failed: $e');
      return {};
    }
  }

  /// Kullanıcının TÜM puanlarını tek sorguda getirir — gönderi listesi
  /// beklemeden `Future.wait` ile paralel çalışabilir.
  Future<Map<int, int>> getAllMyRatings() async {
    try {
      final res = await _db
          .from('post_ratings')
          .select('post_id, rating')
          .eq('user_id', _uid);
      return {
        for (final r in (res as List))
          (r as Map)['post_id'] as int: (r['rating'] as num).toInt(),
      };
    } catch (e) {
      debugPrint('[SupabaseDataService] getAllMyRatings failed: $e');
      return {};
    }
  }

  // ── Şikayet (UGC moderasyon) ────────────────────────────────────────────────

  Future<void> reportPost(int postId, {String? reason}) async {
    await _db.rpc('report_post', params: {
      'p_post_id': postId,
      if (reason != null && reason.isNotEmpty) 'p_reason': reason,
    });
  }

  /// Admin: açık şikayetleri gönderi bilgisiyle birlikte döndürür.
  Future<List<Map<String, dynamic>>> getPostReports() async {
    try {
      final res = await _db
          .from('post_reports')
          .select('*, posts(id, community_name, content, image_url, status)')
          .eq('status', 'open')
          .order('created_at', ascending: false)
          .limit(100);
      return List<Map<String, dynamic>>.from(res as List);
    } catch (e) {
      debugPrint('[SupabaseDataService] getPostReports failed: $e');
      return [];
    }
  }

  Future<void> updateReportStatus(int reportId, String status) async {
    await _db
        .from('post_reports')
        .update({'status': status})
        .eq('id', reportId);
  }

  /// Admin: gönderiyi gizler / geri getirir ('published' | 'hidden').
  Future<void> setPostStatus(int postId, String status) async {
    await _db.rpc('set_post_status', params: {
      'p_post_id': postId,
      'p_status': status,
    });
  }

  // ── Görsel yükleme (Supabase Storage → public URL) ──────────────────────────

  /// Görsel yükler (MIME/boyut sınırı kontrollü). Öncelik Telegraph;
  /// Telegraph başarısız olursa Supabase Storage'a düşer (fallback).
  Future<String> uploadPostImage(File file) async {
    final validation = await FileValidator.validateFile(file);
    if (!validation.isValid) {
      throw ArgumentError(validation.errorMessage);
    }
    try {
      final url = await _uploadPostImageToTelegraph(file);
      if (url != null) return url;
    } catch (e) {
      debugPrint('[Upload] Telegraph failed, falling back to Supabase: $e');
    }
    return _uploadPostImageToSupabase(file);
  }

  /// Telegraph'a yükler (POST https://api.telegra.ph/upload, multipart "file").
  /// Başarısızsa null döner — 5MB üstü dosyada genellikle başarısız olur.
  Future<String?> _uploadPostImageToTelegraph(File file) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('https://api.telegra.ph/upload'),
    );
    request.files.add(await http.MultipartFile.fromPath('file', file.path));
    final streamed = await request
        .send()
        .timeout(const Duration(seconds: 20));
    final body = await streamed.stream.bytesToString();
    if (streamed.statusCode != 200) return null;
    final decoded = jsonDecode(body) as Map<String, dynamic>;
    if (decoded['ok'] != true) return null;
    final result = decoded['result'] as List?;
    if (result == null || result.isEmpty) return null;
    final src = (result[0] as Map<String, dynamic>)['src'] as String?;
    if (src == null || src.isEmpty) return null;
    return 'https://telegra.ph$src';
  }

  /// Supabase Storage fallback (eski davranış).
  Future<String> _uploadPostImageToSupabase(File file) async {
    final uid = _uid;
    final name = file.path.split(RegExp(r'[\\/]')).last;
    final dot = name.lastIndexOf('.');
    final ext = (dot > 0 && name.length - dot <= 5)
        ? name.substring(dot + 1).toLowerCase()
        : 'jpg';
    final path = 'posts/$uid/${DateTime.now().millisecondsSinceEpoch}.$ext';
    await _db.storage.from('post-images').upload(
      path,
      file,
      fileOptions: const FileOptions(cacheControl: '3600'),
    );
    return _db.storage.from('post-images').getPublicUrl(path);
  }

  // ── İndirimler ───────────────────────────────────────────────────────────────

  Future<List<DiscountModel>> getKuponlar() async {
    try {
      final res =
          await _db.from('discounts').select().order('id', ascending: false);
      final list = (res as List)
          .map((j) => DiscountModel.fromApiJson(j as Map<String, dynamic>))
          .toList();

      if (list.isNotEmpty) {
        unawaited(_cacheList(_keyKuponlar, res));
        return list;
      }
    } catch (e) {
      debugPrint('[SupabaseDataService] getKuponlar fallback triggered: $e');
    }
    return _demoKuponlar;
  }

  /// Konum tabanlı, atomic kupon hak etme işlemi (RPC claim_coupon)
  Future<Map<String, dynamic>> claimCoupon({
    required int discountId,
    required double userLat,
    required double userLng,
    double merchantLat = 40.7408,
    double merchantLng = 30.3333,
    double geofenceRadiusMeters = 50.0,
    String categoryPrefix = 'AB',
    String merchantChar = 'X',
  }) async {
    try {
      final response = await _db.rpc('claim_coupon', params: {
        'p_discount_id': discountId,
        'p_user_lat': userLat,
        'p_user_lng': userLng,
      });

      if (response != null && response is Map) {
        return Map<String, dynamic>.from(response);
      }
    } catch (e) {
      debugPrint('[SupabaseDataService] claimCoupon RPC fallback: $e');
    }

    // Fallback simülasyonu (Ağ/Çevrimdışı modu)
    final distanceMeters = LocationService.distanceMeters(
      userLat,
      userLng,
      merchantLat,
      merchantLng,
    );

    if (distanceMeters > geofenceRadiusMeters) {
      return {
        'success': false,
        'error': 'distance_too_far',
        'distance_meters': distanceMeters,
        'max_allowed_meters': geofenceRadiusMeters,
        'message':
            'İşletmeye yeterince yakın değilsiniz (${distanceMeters.toStringAsFixed(0)}m uzaktasınız). Kuponu açmak için 50m yakınına gelmelisiniz.',
      };
    }

    // [Prefix: 2 Harf][Random: 2 Hane][MerchantID: 1 Harf][Random: 2 Hane] (Örn: AB12X34)
    final nowMs = DateTime.now().microsecondsSinceEpoch;
    final num1 = 10 + (nowMs % 90);
    final num2 = 10 + ((nowMs ~/ 7) % 90);
    final fallbackCode =
        '${categoryPrefix.toUpperCase()}$num1${merchantChar.toUpperCase()}$num2';

    return {
      'success': true,
      'code': fallbackCode,
      'already_claimed': false,
      'claimed_at': DateTime.now().toIso8601String(),
      'distance_meters': distanceMeters,
      'message': 'Tebrikler! Kupon kodunuz başarıyla açıldı.',
    };
  }


  /// Yerel önbellekteki kuponları anında döndürür (ağ beklemez).
  List<DiscountModel> getCachedKuponlar() =>
      _readCache(_keyKuponlar).map(DiscountModel.fromApiJson).toList();

  static final List<DiscountModel> _demoKuponlar = [
    DiscountModel(
      id: 1,
      sirketAd: 'English Time Dil Okulları',
      kuponAdi: 'Kur Kayıtlarında %20 İndirim',
      indirimOrani: '%20',
      logoPath: 'assets/gem.png',
      renk: 0xFF00ACC1,
    ),
    DiscountModel(
      id: 2,
      sirketAd: 'Pandora Güzellik Merkezi',
      kuponAdi: 'Tüm Hizmetlerde %15 İndirim',
      indirimOrani: '%15',
      logoPath: 'assets/gem.png',
      renk: 0xFF0F9D58,
    ),
    DiscountModel(
      id: 3,
      sirketAd: 'Reyhan Pastanesi',
      kuponAdi: 'Tatlı ve Pastalarda %10 İndirim',
      indirimOrani: '%10',
      logoPath: 'assets/gem.png',
      renk: 0xFF00ACC1,
    ),
    DiscountModel(
      id: 4,
      sirketAd: 'Eda Optik',
      kuponAdi: 'Gözlük ve Güneş Gözlüğünde %25 İndirim',
      indirimOrani: '%25',
      logoPath: 'assets/gem.png',
      renk: 0xFF0F9D58,
    ),
    DiscountModel(
      id: 5,
      sirketAd: 'Efsane Şahin Spor Kulübü',
      kuponAdi: 'Aylık Üyelikte %20 İndirim',
      indirimOrani: '%20',
      logoPath: 'assets/gem.png',
      renk: 0xFF00ACC1,
    ),
  ];

  // ── Kullanıcı profili ────────────────────────────────────────────────────────

  Future<UserProfileModel?> getUserProfile(String userId) async {
    try {
      final profile = await _db
          .from('profiles')
          .select()
          .eq('id', userId)
          .single();
      final p = profile;

      final badgesRes = await _db
          .from('user_badges')
          .select('badges(name, icon)')
          .eq('user_id', userId);
      final rozetler = (badgesRes as List)
          .map((b) {
            if (b is! Map<String, dynamic>) return null;
            final badgeMap = b['badges'];
            if (badgeMap == null || badgeMap is! Map<String, dynamic>) {
              return null;
            }
            return RozetModel(
              rozetAd: badgeMap['name'] as String? ?? '',
              ikon: badgeMap['icon'] as String? ?? '',
              kazanildi: true,
            );
          })
          .whereType<RozetModel>()
          .toList();

      final eventsRes = await _db
          .from('event_registrations')
          .select('events(image_url)')
          .eq('user_id', userId);
      final etkinlikler = (eventsRes as List)
          .map((e) {
            if (e is! Map<String, dynamic>) return '';
            final events = e['events'];
            if (events is! Map) return '';
            return events['image_url']?.toString() ?? '';
          })
          .where((u) => u.isNotEmpty)
          .toList();

      final adSoyad = p['name'] as String? ?? 'Ahmet Safa Zengin';
      final email = p['email'] as String? ?? '23010404022@subu.edu.tr';
      final birthDate = p['birth_date'] as String? ?? '15.05.2002';
      final bolum = p['department'] as String? ?? 'Bilişim Sistemleri Mühendisliği';
      final qrString = "NEVGENC KİMLİĞİ\nAd Soyad: $adSoyad\nE-posta: $email\nDoğum Tarihi: $birthDate\nBölüm: $bolum";

      return UserProfileModel(
        adSoyad: adSoyad,
        email: email,
        birthDate: birthDate,
        bolum: bolum,
        sinif: p['grade'] as String? ?? '3. Sınıf',
        profilFoto: p['profile_photo'] as String? ?? 'assets/gem.png',
        qrData: qrString,
        rozetler: rozetler,
        katilinanEtkinlikler: etkinlikler,
      );
    } catch (_) {
      // Sunucuya ulaşılamadı / profil yok — çağıran taraf yerel önbelleği kullanır.
      return null;
    }
  }

  Future<void> updateUserProfile(
    String userId, {
    String? name,
    String? department,
    String? grade,
  }) async {
    if (name != null && (name.isEmpty || name.length > 100)) {
      throw StateError('Ad 1-100 karakter olmalıdır.');
    }
    if (department != null && department.length > 100) {
      throw StateError('Bölüm en fazla 100 karakter olabilir.');
    }
    if (grade != null && grade.length > 20) {
      throw StateError('Sınıf en fazla 20 karakter olabilir.');
    }
    final updates = <String, dynamic>{
      if (name != null) 'name': name,
      if (department != null) 'department': department,
      if (grade != null) 'grade': grade,
    };
    if (updates.isEmpty) return;
    try {
      await _db.from('profiles').update(updates).eq('id', userId);
    } catch (_) {}
  }

  // ── Liderlik tablosu ─────────────────────────────────────────────────────────

  Future<LeaderboardData> getLeaderboardData() async {
    try {
      final commRes = await _db
          .from('communities')
          .select('id, name, logo_path, score')
          .order('score', ascending: false)
          .limit(20);
      final stuRes = await _db
          .from('profiles')
          .select('id, name, profile_photo, xp')
          .order('xp', ascending: false)
          .limit(20);

      final comList = (commRes as List).asMap().entries.map((e) {
        final c = e.value as Map<String, dynamic>;
        return RankingModel(
          isim: c['name'] as String? ?? 'Bilinmiyor',
          gorsel: c['logo_path'] as String? ?? '',
          puan: ((c['score'] as num?) ?? 0).toInt(),
          siralama: e.key + 1,
          trend: 'stable',
        );
      }).toList();

      final stuList = (stuRes as List).asMap().entries.map((e) {
        final s = e.value as Map<String, dynamic>;
        return RankingModel(
          isim: s['name'] as String? ?? 'Bilinmiyor',
          gorsel: s['profile_photo'] as String? ?? '',
          puan: ((s['xp'] as num?) ?? 0).toInt(),
          siralama: e.key + 1,
          trend: 'stable',
        );
      }).toList();

      if (comList.isNotEmpty || stuList.isNotEmpty) {
        return LeaderboardData(topluluklar: comList, uyeler: stuList);
      }
    } catch (e) {
      debugPrint('[SupabaseDataService] getLeaderboardData fallback: $e');
    }

    return LeaderboardData(
      topluluklar: [
        RankingModel(siralama: 1, isim: 'Girişimci Mühendisler Topluluğu', gorsel: 'assets/gem.png', puan: 2450, trend: 'up'),
        RankingModel(siralama: 2, isim: 'Bilişim Sistemleri Topluluğu', gorsel: 'assets/gem.png', puan: 2180, trend: 'up'),
        RankingModel(siralama: 3, isim: 'Tarih Öğrenci Topluluğu', gorsel: 'assets/gem.png', puan: 1890, trend: 'stable'),
        RankingModel(siralama: 4, isim: 'Damla Öğrenci Topluluğu', gorsel: 'assets/gem.png', puan: 1650, trend: 'down'),
        RankingModel(siralama: 5, isim: 'IEEE SUBÜ Student Branch', gorsel: 'assets/gem.png', puan: 1420, trend: 'up'),
      ],
      uyeler: [
        RankingModel(siralama: 1, isim: 'Ahmet Safa Zengin', gorsel: 'assets/gem.png', puan: 980, trend: 'up'),
        RankingModel(siralama: 2, isim: 'Melik Mirza Çelik', gorsel: 'assets/gem.png', puan: 850, trend: 'up'),
        RankingModel(siralama: 3, isim: 'İbrahim Gece', gorsel: 'assets/gem.png', puan: 790, trend: 'stable'),
        RankingModel(siralama: 4, isim: 'Aygül Aladı', gorsel: 'assets/gem.png', puan: 710, trend: 'stable'),
        RankingModel(siralama: 5, isim: 'Zeynep Yılmaz', gorsel: 'assets/gem.png', puan: 640, trend: 'down'),
      ],
    );
  }

  Future<void> registerFcmToken(
    String token, {
    String platform = 'android',
  }) async {
    await _db.from('fcm_tokens').upsert({
      'user_id': _uid,
      'token': token,
      'platform': platform,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  // ── Etkinlikler ──────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getEvents({int? communityId}) async {
    var query = _db.from('events').select();
    if (communityId != null) {
      query = query.eq('community_id', communityId);
    }
    final res = await query.order('event_date', ascending: true);
    return List<Map<String, dynamic>>.from(res as List);
  }

  Future<List<Map<String, dynamic>>> getUpcomingEvents({int limit = 10}) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final res = await _db
        .from('events')
        .select('*, communities(name, logo_path)')
        .gte('event_date', now)
        .order('event_date', ascending: true)
        .limit(limit);
    unawaited(_cacheList(_keyEtkinlikler, res as List));
    return List<Map<String, dynamic>>.from(res as List);
  }

  /// Yerel önbellekteki yaklaşan etkinlikleri anında döndürür (ağ beklemez).
  List<Map<String, dynamic>> getCachedUpcomingEvents() => _readCache(_keyEtkinlikler);

  Future<void> registerToEvent(int eventId) async {
    await _db.from('event_registrations').upsert({
      'user_id': _uid,
      'event_id': eventId,
    });
  }

  Future<void> unregisterFromEvent(int eventId) async {
    await _db
        .from('event_registrations')
        .delete()
        .eq('user_id', _uid)
        .eq('event_id', eventId);
  }

  // ── Admin ────────────────────────────────────────────────────────────────────

  Future<List<AuthUser>> getAdminUsers({String? search}) async {
    var query = _db.from('profiles').select();
    if (search != null && search.isNotEmpty) {
      query = query.ilike('name', '%$search%');
    }
    final res = await query.order('created_at', ascending: false).limit(100);
    return (res as List).map((u) {
      final m = u as Map<String, dynamic>;
      final role = m['role'] as String? ?? 'student';
      return AuthUser(
        id: m['id'] as String,
        name: m['name'] as String,
        email: '',
        isAdmin: role == 'admin',
        isBaskan: role == 'baskan',
        role: role,
        createdAt: DateTime.parse(m['created_at'] as String),
      );
    }).toList();
  }

  // ── Talep ve Şikayet Sistemi (User Tickets) ──────────────────────────────────

  /// Kullanıcı: kendi taleplerini/şikayetlerini getirir (en yeni üstte).
  Future<List<UserTicket>> getMyTickets() async {
    try {
      final uid = _uid;
      final res = await _db
          .from('user_tickets')
          .select()
          .eq('user_id', uid)
          .order('created_at', ascending: false)
          .limit(100);
      return (res as List)
          .map((j) => UserTicket.fromJson(j as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[SupabaseDataService] getMyTickets failed: $e');
      return [];
    }
  }

  /// Kullanıcı: yeni talep/şikayet/öneri oluşturur.
  Future<void> createTicket({
    required String type,
    required String subject,
    required String description,
  }) async {
    final uid = _uid;
    if (!UserTicket.validTypes.contains(type)) {
      throw ArgumentError('Geçersiz talep türü: $type');
    }
    await _db.from('user_tickets').insert({
      'user_id': uid,
      'type': type,
      'subject': subject.trim(),
      'description': description.trim(),
      'status': 'open',
    });
  }

  /// Admin: tüm talepleri getirir (opsiyonel status filtresiyle).
  Future<List<UserTicket>> getAllTickets({String? status}) async {
    try {
      var query = _db.from('user_tickets').select();
      if (status != null && status.isNotEmpty && UserTicket.validStatuses.contains(status)) {
        query = query.eq('status', status);
      }
      final res = await query.order('created_at', ascending: false).limit(200);
      return (res as List)
          .map((j) => UserTicket.fromJson(j as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[SupabaseDataService] getAllTickets failed: $e');
      return [];
    }
  }

  /// Admin: talep durumunu ve admin notlarını günceller.
  Future<void> updateTicketStatus({
    required String ticketId,
    required String status,
    String? adminNotes,
  }) async {
    if (!UserTicket.validStatuses.contains(status)) {
      throw ArgumentError('Geçersiz durum: $status');
    }
    final updates = <String, dynamic>{
      'status': status,
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (adminNotes != null) {
      updates['admin_notes'] = adminNotes.trim();
    }
    await _db.from('user_tickets').update(updates).eq('id', ticketId);
  }

  /// Admin başkan seçici için tüm toplulukları taze getirir (önbellek/demo yok).
  Future<List<Topluluk>> getTopluluklarForAdmin() async {
    try {
      final res = await _db
          .from('communities')
          .select(
            'id, name, logo_path, category, score, member_count, description, '
            'chairman_name, chairman_id',
          )
          .order('name', ascending: true);
      return (res as List)
          .map((j) => Topluluk.fromApiJson(j as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[SupabaseDataService] getTopluluklarForAdmin failed: $e');
      rethrow;
    }
  }

  /// Admin paneli için yeni topluluk oluşturur.
  Future<Topluluk> createCommunity({
    required String name,
    required String description,
    required String category,
    String? logoPath,
    String? chairmanId,
    String? chairmanName,
  }) async {
    final Map<String, dynamic> insertData = {
      'name': name.trim(),
      'description': description.trim(),
      'category': category,
      'logo_path': (logoPath != null && logoPath.isNotEmpty) ? logoPath : 'assets/gem.png',
      'score': 80.0,
      'member_count': 0,
      'chairman_name': chairmanName ?? 'Belirtilmedi',
    };
    if (chairmanId != null && chairmanId.isNotEmpty) {
      insertData['chairman_id'] = chairmanId;
    }

    final res = await _db.from('communities').insert(insertData).select().single();
    return Topluluk.fromApiJson(res);
  }

  /// Admin: bir kullanıcıyı 'baskan' yapar ve bir topluluğa bağlar.
  /// Eski başkanlığı (chairman_id) temizlenir; chairman_name profil adıyla yazılır.
  Future<void> assignChairman({
    required String userId,
    required String userName,
    required int communityId,
  }) async {
    // 1) Kullanıcının varsa eski başkanlığını temizle (chairman_id tek sütun).
    await _db
        .from('communities')
        .update({'chairman_id': null})
        .eq('chairman_id', userId);
    // 2) Yeni topluluğa başkan olarak bağla.
    await _db.from('communities').update({
      'chairman_id': userId,
      'chairman_name': userName,
    }).eq('id', communityId);
    // 3) Rolünü 'baskan' yap (admin rolüne dokunmaz — UI admin kullanıcıyı kilitler).
    await _db.from('profiles').update({'role': 'baskan'}).eq('id', userId);
  }

  /// Admin: bir topluluğun başkanlığını kaldırır.
  /// Rolü yalnızca 'baskan' ise 'student'a döner (admin hesabına dokunulmaz).
  Future<void> removeChairman({
    required int communityId,
    required String chairmanId,
  }) async {
    await _db.from('communities').update({
      'chairman_id': null,
      'chairman_name': null,
    }).eq('id', communityId);
    await _db
        .from('profiles')
        .update({'role': 'student'})
        .eq('id', chairmanId)
        .eq('role', 'baskan');
  }

  Future<void> deleteAdminUser(String userId) async {
    // Hem auth.users hem profiles'ı güvenli silen service-role Edge Function'ı çağır.
    // (Client anon key ile auth.admin.deleteUser çağrılamaz; orphan auth kaydı önlenir.)
    final res = await _db.functions.invoke(
      'delete-user',
      body: {'userId': userId},
    );
    if (res.status != 200) {
      final data = res.data;
      final err = data is Map ? (data['error'] ?? data) : data;
      throw StateError('Kullanıcı silinemedi: $err');
    }
  }

  Future<Map<String, dynamic>> getAdminStats() async {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final weekStartStr =
        '${weekStart.year}-${weekStart.month.toString().padLeft(2, '0')}-${weekStart.day.toString().padLeft(2, '0')}';

    final results = await Future.wait([
      _db.from('profiles').select().count(CountOption.exact),
      _db.from('communities').select().count(CountOption.exact),
      _db.from('posts').select().count(CountOption.exact),
      _db
          .from('profiles')
          .select()
          .gte('created_at', weekStartStr)
          .count(CountOption.exact),
    ]);

    return {
      'totalUsers': (results[0] as dynamic).count ?? 0,
      'totalCommunities': (results[1] as dynamic).count ?? 0,
      'totalPosts': (results[2] as dynamic).count ?? 0,
      'newUsersThisWeek': (results[3] as dynamic).count ?? 0,
    };
  }

  Future<void> updatePostRating(int postId, double rating) async {
    final uid = _uid;
    await Future.wait([
      _db
          .rpc(
            'update_post_quality',
            params: {'post_id': postId, 'new_score': rating},
          )
          .catchError((_) async {
            final post = await _db
                .from('posts')
                .select('quality_score')
                .eq('id', postId)
                .single();
            final current =
                ((post as Map)['quality_score'] as num?)?.toDouble() ?? 0.0;
            final updated = current == 0.0 ? rating : (current + rating) / 2.0;
            await _db
                .from('posts')
                .update({'quality_score': updated})
                .eq('id', postId);
          }),
      _db
          .rpc('add_user_xp', params: {'user_id': uid, 'xp_amount': 10})
          .catchError((_) async {
            try {
              final row = await _db
                  .from('profiles')
                  .select('xp')
                  .eq('id', uid)
                  .single();
              final current = ((row as Map)['xp'] as num?)?.toInt() ?? 0;
              await _db
                  .from('profiles')
                  .update({'xp': current + 10})
                  .eq('id', uid);
            } catch (_) {}
          }),
    ]);
  }

  // ── Bildirimler (Notification Center) ────────────────────────────────────────

  /// Kullanıcının bildirimlerini sayfalı getirir.
  Future<List<Map<String, dynamic>>> getNotifications({
    required String userId,
    int page = 0,
    int limit = 20,
  }) async {
    try {
      final res = await _db
          .from('notifications')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .range(page * limit, (page + 1) * limit - 1);
      return List<Map<String, dynamic>>.from(res as List);
    } catch (e) {
      debugPrint('[SupabaseDataService] getNotifications failed: $e');
      return [];
    }
  }

  /// Bildirimi okundu olarak işaretler.
  Future<void> markNotificationRead(String notificationId) async {
    await _db.from('notifications').update({'is_read': true}).eq('id', notificationId);
  }

  /// Bildirimi siler.
  Future<void> deleteNotification(String notificationId) async {
    await _db.from('notifications').delete().eq('id', notificationId);
  }

  /// 30 günden eski okunmuş bildirimleri temizler.
  Future<void> deleteOldReadNotifications(String userId) async {
    final cutoff = DateTime.now().subtract(const Duration(days: 30)).toIso8601String();
    await _db
        .from('notifications')
        .delete()
        .eq('user_id', userId)
        .eq('is_read', true)
        .lt('created_at', cutoff);
  }

  /// Realtime bildirim aboneliği.
  RealtimeChannel subscribeToNotifications(String userId, Function(Map<String, dynamic>) onInsert) {
    return _db
        .channel('notifications:$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
            onInsert(Map<String, dynamic>.from(payload.newRecord));
          },
        )
        .subscribe();
  }

  // ── Analitik (Başkan Paneli) ────────────────────────────────────────────────

  /// Topluluk genel istatistikleri
  Future<Map<String, dynamic>> getCommunityStats(int communityId) async {
    try {
      final q1 = _db.from('community_members').select().eq('community_id', communityId).count(CountOption.exact);
      final q2 = _db.from('posts').select().eq('community_id', communityId).count(CountOption.exact);
      final q3 = _db.from('posts').select('support_count').eq('community_id', communityId);
      final q4 = _db.from('posts').select('quality_score').eq('community_id', communityId);
      final q5 = _db.from('events').select().eq('community_id', communityId).count(CountOption.exact);
      final q6 = _db.from('posts').select('user_id').eq('community_id', communityId).gte('created_at', DateTime.now().subtract(const Duration(days: 30)).toIso8601String());
      final q7 = _db.from('post_supports').select('user_id').eq('community_id', communityId).gte('created_at', DateTime.now().subtract(const Duration(days: 30)).toIso8601String());

      final results = await Future.wait<dynamic>([q1, q2, q3, q4, q5, q6, q7]);

      final totalMembers = (results[0] as dynamic).count ?? 0;
      final totalPosts = (results[1] as dynamic).count ?? 0;
      final posts = results[2] as List;
      final qualityScores = results[3] as List;
      final totalEvents = (results[4] as dynamic).count ?? 0;
      final recentPostAuthors = (results[5] as List).map((p) => p['user_id']).toSet();
      final recentSupporters = (results[6] as List).map((s) => s['user_id']).toSet();

      final totalSupport = posts.fold<int>(0, (sum, p) => sum + ((p['support_count'] as num?)?.toInt() ?? 0));
      final avgRating = qualityScores.isNotEmpty
          ? qualityScores.fold<double>(0.0, (sum, p) => sum + ((p['quality_score'] as num?)?.toDouble() ?? 0.0)) / qualityScores.length
          : 0.0;

      final activeMembers = {...recentPostAuthors, ...recentSupporters}.length;
      final activeRate = totalMembers > 0 ? activeMembers / totalMembers : 0.0;

      return {
        'total_members': totalMembers,
        'total_posts': totalPosts,
        'total_support': totalSupport,
        'avg_rating': avgRating,
        'total_events': totalEvents,
        'active_members': activeMembers,
        'active_member_rate': activeRate,
      };
    } catch (e) {
      debugPrint('[SupabaseDataService] getCommunityStats failed: $e');
      return {
        'total_members': 0,
        'total_posts': 0,
        'total_support': 0,
        'avg_rating': 0.0,
        'total_events': 0,
        'active_members': 0,
        'active_member_rate': 0.0,
      };
    }
  }

  /// Son 30 günlük üye büyüme trendi
  Future<List<Map<String, dynamic>>> getMemberGrowthTrend(int communityId) async {
    try {
      final now = DateTime.now();
      final thirtyDaysAgo = now.subtract(const Duration(days: 30)).toIso8601String();

      final res = await _db
          .from('community_members')
          .select('joined_at')
          .eq('community_id', communityId)
          .gte('joined_at', thirtyDaysAgo)
          .order('joined_at', ascending: true);

      final Map<String, int> dailyCounts = {};
      for (final r in (res as List)) {
        final dateStr = (r['joined_at'] as String).substring(0, 10); // YYYY-MM-DD
        dailyCounts[dateStr] = (dailyCounts[dateStr] ?? 0) + 1;
      }

      // Son 30 gün için her gün doldur
      final result = <Map<String, dynamic>>[];
      int cumulative = 0;
      for (int i = 29; i >= 0; i--) {
        final d = now.subtract(Duration(days: i));
        final key = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
        cumulative += dailyCounts[key] ?? 0;
        result.add({
          'date': key,
          'label': '${d.day}/${d.month}',
          'count': cumulative,
        });
      }
      return result;
    } catch (e) {
      debugPrint('[SupabaseDataService] getMemberGrowthTrend failed: $e');
      return [];
    }
  }

  /// Son 7 günlük gönderi aktivitesi
  Future<List<Map<String, dynamic>>> getPostActivityTrend(int communityId) async {
    try {
      final now = DateTime.now();
      final sevenDaysAgo = now.subtract(const Duration(days: 7)).toIso8601String();

      final res = await _db
          .from('posts')
          .select('created_at')
          .eq('community_id', communityId)
          .gte('created_at', sevenDaysAgo)
          .order('created_at', ascending: true);

      final Map<String, int> dailyCounts = {};
      for (final r in (res as List)) {
        final dateStr = (r['created_at'] as String).substring(0, 10);
        dailyCounts[dateStr] = (dailyCounts[dateStr] ?? 0) + 1;
      }

      final result = <Map<String, dynamic>>[];
      for (int i = 6; i >= 0; i--) {
        final d = now.subtract(Duration(days: i));
        final key = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
        result.add({
          'date': key,
          'label': _weekdayShort(d.weekday),
          'count': dailyCounts[key] ?? 0,
        });
      }
      return result;
    } catch (e) {
      debugPrint('[SupabaseDataService] getPostActivityTrend failed: $e');
      return [];
    }
  }

  String _weekdayShort(int weekday) {
    const days = ['Paz', 'Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt'];
    return days[weekday % 7];
  }

  /// En aktif üyeler (gönderi + destek sayısı)
  Future<List<Map<String, dynamic>>> getTopActiveMembers(int communityId, {int limit = 10}) async {
    try {
      // Önce topluluk üyelerini al
      final membersRes = await _db
          .from('community_members')
          .select('user_id')
          .eq('community_id', communityId);
      final memberIds = (membersRes as List).map((m) => m['user_id'] as String).toList();
      if (memberIds.isEmpty) return [];

      // Her üye için gönderi ve destek sayılarını al
      final postsRes = await _db
          .from('posts')
          .select('user_id')
          .eq('community_id', communityId)
          .inFilter('user_id', memberIds);
      final supportsRes = await _db
          .from('post_supports')
          .select('user_id')
          .eq('community_id', communityId)
          .inFilter('user_id', memberIds);

      final Map<String, int> postCounts = {};
      final Map<String, int> supportCounts = {};

      for (final p in (postsRes as List)) {
        postCounts[p['user_id']] = (postCounts[p['user_id']] ?? 0) + 1;
      }
      for (final s in (supportsRes as List)) {
        supportCounts[s['user_id']] = (supportCounts[s['user_id']] ?? 0) + 1;
      }

      // Skorla sırala (gönderi * 2 + destek)
      final scored = memberIds.map((id) {
        final posts = postCounts[id] ?? 0;
        final supports = supportCounts[id] ?? 0;
        return {'user_id': id, 'post_count': posts, 'support_count': supports, 'score': posts * 2 + supports};
      }).toList()
        ..sort((a, b) => (b['score'] as int).compareTo(a['score'] as int));

      // Profil bilgilerini getir
      final topIds = scored.take(limit).map((e) => e['user_id']).toList();
      final profilesRes = await _db
          .from('profiles')
          .select('id, name, profile_photo')
          .inFilter('id', topIds);

      final profileMap = {for (final p in (profilesRes as List)) p['id']: p};

      return scored.take(limit).map((e) {
        final profile = profileMap[e['user_id']] as Map<String, dynamic>? ?? {};
        return {
          'user_id': e['user_id'],
          'post_count': e['post_count'],
          'support_count': e['support_count'],
          'profile': profile,
        };
      }).toList();
    } catch (e) {
      debugPrint('[SupabaseDataService] getTopActiveMembers failed: $e');
      return [];
    }
  }

  /// Admin: Tüm kullanıcılara yeni sürüm / güncelleme bildirimi gönderir.
  Future<void> sendUpdateAnnouncement({
    required String title,
    required String message,
    String? version,
    String? storeUrl,
  }) async {
    try {
      final profiles = await _db.from('profiles').select('id');
      final userIds = (profiles as List).map((p) => p['id'] as String).toList();

      if (userIds.isNotEmpty) {
        final rows = userIds.map((uid) => {
          'user_id': uid,
          'title': title,
          'body': message,
          'type': 'announcement',
          'data': {
            'version': version,
            'store_url': storeUrl,
            'is_update': true,
          },
          'is_read': false,
          'created_at': DateTime.now().toIso8601String(),
        }).toList();

        await _db.from('notifications').insert(rows);
      }
    } catch (e) {
      debugPrint('[SupabaseDataService] sendUpdateAnnouncement hatası: $e');
      rethrow;
    }
  }
}

