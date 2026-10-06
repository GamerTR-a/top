import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthUser;
import '../models/auth_user_model.dart';
import '../models/topluluk.dart';
import '../models/post_model.dart';
import '../models/discount_model.dart';
import '../models/user_profile_model.dart';
import '../models/leaderboard_model.dart';
import '../models/ticket_model.dart';
import '../models/news_model.dart';
import '../models/quiz_question.dart';
import '../models/job_listing_model.dart';
import '../utils/file_validator.dart';
import '../utils/image_sanitizer.dart';
import 'local_storage_service.dart';


class SupabaseDataService {
  static final _db = Supabase.instance.client;

  // ── Liste önbelleği anahtarları (LocalStorageService ile eşleşir) ────────
  static const String _keyPosts = 'offline_cached_posts';
  static const String _keyKuponlar = LocalStorageService.keyCachedKuponlar;
  static const String _keyEtkinlikler = LocalStorageService.keyCachedEtkinlikler;
  static const String _keyTopluluklar = LocalStorageService.keyCachedTopluluklar;
  static const String _keyNews = LocalStorageService.keyCachedNews;
  static const String _keyJobListings = LocalStorageService.keyCachedJobListings;
  static const String _keyMenuItems = LocalStorageService.keyCachedMenuItems;

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
  // Public (isim alttizgisiz) — birim testinden çağrılabilmesi için (bkz.
  // kontrol.md Bölüm 30.1). Not: sunucu artık bu değeri kendi hesaplayıp
  // istemcinin gönderdiğini yok sayıyor (Bölüm 8.8) — bu fonksiyon yalnızca
  // istemci tarafı anlık gösterim için kullanılıyor.
  static int isoWeek(DateTime d) {
    final jan4 = DateTime(d.year, 1, 4);
    final startOfWeek1 = jan4.subtract(Duration(days: jan4.weekday - 1));
    if (d.isBefore(startOfWeek1)) return isoWeek(DateTime(d.year - 1, 12, 28));
    return ((d.difference(startOfWeek1).inDays) ~/ 7) + 1;
  }

  // ── Topluluklar ──────────────────────────────────────────────────────────────

  Future<List<Topluluk>> getTopluluklar({
    String? search,
    String? category,
    String sort = 'score',
    int page = 1,
    // PostgREST'in varsayılan max-rows sınırı; topluluk listesi ekranları
    // sayfalama yapmadığı için tümü tek seferde gelmeli.
    int limit = 1000,
  }) async {
    // Not: hata BİLEREK yutulup sahte/demo topluluk listesi döndürülmüyor —
    // önceki sürüm bir ağ hatasında (ya da gerçekten 0 sonuç dönse bile)
    // kullanıcıya bunun gerçek veri olduğuna dair hiçbir işaret vermeden
    // uydurma içerik gösteriyordu (bkz. kontrol.md Bölüm 14.9 / 16.3).
    // Hata durumunda çağıran taraf zaten yerel önbelleği (getCachedTopluluklar)
    // gösterip arka planda bunu deniyor; başarısız olursa mevcut/boş hata
    // durumunu koruyor.
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
    // Yalnızca varsayılan (filtresiz) liste önbelleğe alınır.
    if (list.isNotEmpty &&
        (search == null || search.isEmpty) &&
        (category == null || category.isEmpty) &&
        page == 1) {
      unawaited(_cacheList(_keyTopluluklar, res));
    }
    return list;
  }

  /// Yerel önbellekteki toplulukları anında döndürür (ağ beklemez).
  List<Topluluk> getCachedTopluluklar() =>
      _readCache(_keyTopluluklar).map(Topluluk.fromApiJson).toList();

  Future<Map<String, dynamic>> getCommunityActivities(int communityId) async {
    try {
      final posts = await _db
          .from('posts')
          .select()
          .eq('community_id', communityId)
          .or(_visiblePostFilter)
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

  /// Tek bir topluluğun güncel kaydını döndürür.
  Future<Topluluk?> getCommunityById(int communityId) async {
    try {
      final res = await _db
          .from('communities')
          .select()
          .eq('id', communityId)
          .maybeSingle();
      return res == null ? null : Topluluk.fromApiJson(res);
    } catch (e) {
      debugPrint('[SupabaseDataService] getCommunityById failed: $e');
      return null;
    }
  }

  /// Başkan/admin: topluluğun tanıtım ve iletişim bilgilerini günceller.
  /// Yetki sunucuda zorlanır (RLS: yalnızca o topluluğun başkanı veya admin);
  /// puan, üye sayısı, kategori ve başkan ataması başkan tarafından değişmez.
  Future<void> updateCommunityProfile({
    required int communityId,
    required String name,
    required String shortName,
    required String description,
    required String chairmanName,
    required String contactEmail,
    required String contactPhone,
    String? logoPath,
  }) async {
    if (name.length < 2 || name.length > 120) {
      throw StateError('Topluluk adı 2-120 karakter olmalıdır.');
    }
    if (shortName.length > 20) {
      throw StateError('Kısaltma en fazla 20 karakter olabilir.');
    }
    if (description.length > 1000) {
      throw StateError('Tanıtım en fazla 1000 karakter olabilir.');
    }
    if (chairmanName.length > 80) {
      throw StateError('Başkan adı en fazla 80 karakter olabilir.');
    }
    if (contactEmail.isNotEmpty &&
        !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(contactEmail)) {
      throw StateError('Geçerli bir e-posta adresi girin.');
    }
    if (contactPhone.isNotEmpty &&
        !RegExp(r'^\+?[0-9 ()-]{7,30}$').hasMatch(contactPhone)) {
      throw StateError('Geçerli bir telefon numarası girin.');
    }
    final updated = await _db
        .from('communities')
        .update({
          'name': name,
          'short_name': shortName.isEmpty ? null : shortName,
          'description': description,
          'chairman_name': chairmanName.isEmpty ? null : chairmanName,
          'contact_email': contactEmail.isEmpty ? null : contactEmail,
          'contact_phone': contactPhone.isEmpty ? null : contactPhone,
          if (logoPath != null && logoPath.isNotEmpty) 'logo_path': logoPath,
        })
        .eq('id', communityId)
        .select('id');
    // RLS reddi hata fırlatmaz, 0 satır günceller.
    if ((updated as List).isEmpty) {
      throw StateError('Bu topluluğu düzenleme yetkiniz yok.');
    }
  }

  /// Başkan/admin: bağlantıları topluca kaydeder; boş bırakılan platformun
  /// kaydı silinir.
  Future<void> saveCommunityLinks(
    int communityId,
    Map<String, String> links,
  ) async {
    for (final entry in links.entries) {
      final url = entry.value.trim();
      if (url.isEmpty) {
        await removeCommunityLink(communityId, entry.key);
      } else {
        await setCommunityLink(communityId, entry.key, url);
      }
    }
  }

  // ── Uygulama ayarları (app_settings: herkes okur, admin yazar) ───────────────

  Future<Map<String, String>> getAppSettings(List<String> keys) async {
    final rows = await _db
        .from('app_settings')
        .select('key, value')
        .inFilter('key', keys);
    return {
      for (final r in (rows as List))
        (r as Map)['key'] as String: r['value'] as String? ?? '',
    };
  }

  Future<void> setAppSettings(Map<String, String> values) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final saved = await _db
        .from('app_settings')
        .upsert(
          [
            for (final e in values.entries)
              {'key': e.key, 'value': e.value, 'updated_at': now},
          ],
          onConflict: 'key',
        )
        .select('key');
    if ((saved as List).length != values.length) {
      throw StateError('Ayarlar kaydedilemedi (admin yetkisi gerekir).');
    }
  }

  // ── Kampüs Cepte: admin'in eklediği noktalar ────────────────────────────────

  Future<List<Map<String, dynamic>>> getRemoteCampusPois() async {
    final res = await _db
        .from('campus_pois')
        .select('id, name, category, lat, lng, description, address')
        .order('name');
    return List<Map<String, dynamic>>.from(res as List);
  }

  Future<void> addCampusPoi({
    required String name,
    required String category,
    required double lat,
    required double lng,
    String description = '',
    String address = '',
  }) async {
    await _db.from('campus_pois').insert({
      'name': name,
      'category': category,
      'lat': lat,
      'lng': lng,
      'description': description,
      'address': address,
      'created_by': _uid,
    });
  }

  Future<void> deleteCampusPoi(int id) async {
    await _db.from('campus_pois').delete().eq('id', id);
  }

  // ── Kampüs Bilgi Yarışması: admin'in eklediği sorular ───────────────────────

  Future<List<QuizQuestion>> getRemoteQuizQuestions() async {
    final res = await _db
        .from('quiz_questions')
        .select('id, question, options, correct_index, category')
        .order('id', ascending: false);
    return (res as List)
        .map((r) => QuizQuestion.tryFromApiJson(r as Map<String, dynamic>))
        .whereType<QuizQuestion>()
        .toList();
  }

  Future<void> addQuizQuestion(QuizQuestion q) async {
    await _db.from('quiz_questions').insert({
      'question': q.question,
      'options': q.options,
      'correct_index': q.correctIndex,
      'category': q.category,
      'created_by': _uid,
    });
  }

  Future<void> deleteQuizQuestion(int id) async {
    await _db.from('quiz_questions').delete().eq('id', id);
  }

  /// Topluluğu siler (sadece admin).
  Future<void> deleteCommunity(int communityId) async {
    await _db.from('communities').delete().eq('id', communityId);
  }

  // ── Başkan: Topluluk üye / gönderi yönetimi ────────────────────────────────────

  /// Topluluğun üyelerini döndürür (profil ve e-posta bilgileriyle birlikte).
  ///
  /// E-posta `profiles`'ta değil `auth.users`'ta durduğu için yetki kontrollü
  /// `get_community_members_detailed` RPC'si kullanılır (yalnızca o topluluğun
  /// başkanı/admin). RPC yoksa e-postasız profil join'ine düşülür.
  /// Dönen her satır: {user_id, joined_at, name, profiles: {id, name, email,
  /// profile_photo, xp, role, department(String)}}.
  Future<List<Map<String, dynamic>>> getCommunityMembers(int communityId) async {
    try {
      final res = await _db.rpc(
        'get_community_members_detailed',
        params: {'p_community_id': communityId},
      );
      return _normalizePersonRows(res, dateKey: 'joined_at');
    } catch (e) {
      debugPrint('[SupabaseDataService] get_community_members_detailed failed: $e');
    }
    try {
      final res = await _db
          .from('community_members')
          .select('user_id, joined_at, profiles(id, name, profile_photo, xp, role, department)')
          .eq('community_id', communityId)
          .order('joined_at', ascending: true);
      return _normalizePersonRows(res, dateKey: 'joined_at');
    } catch (e) {
      debugPrint('[SupabaseDataService] getCommunityMembers failed: $e');
      return [];
    }
  }

  /// RPC (düz satır) ve PostgREST embed (`profiles: {...}`) çıktılarını tek
  /// biçime getirir. `department` TEXT[] olduğundan metne çevrilir.
  static List<Map<String, dynamic>> _normalizePersonRows(
    dynamic res, {
    required String dateKey,
  }) {
    if (res is! List) return [];
    return res.map((raw) {
      final row = Map<String, dynamic>.from(raw as Map);
      final profile = row['profiles'] is Map
          ? Map<String, dynamic>.from(row['profiles'] as Map)
          : <String, dynamic>{
              'id': row['user_id'],
              'name': row['name'],
              'email': row['email'],
              'profile_photo': row['profile_photo'],
              'xp': row['xp'],
              'role': row['role'],
              'department': row['department'],
            };
      final dept = profile['department'];
      profile['department'] = dept is List
          ? dept.whereType<String>().where((d) => d.isNotEmpty).join(', ')
          : dept?.toString();
      profile['id'] ??= row['user_id'];
      return <String, dynamic>{
        'user_id': row['user_id'] ?? profile['id'],
        dateKey: row[dateKey],
        'name': profile['name'],
        'profiles': profile,
      };
    }).toList();
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

  /// Kullanıcının sunucuda üye olduğu tüm topluluk id'lerini döndürür.
  /// Çoklu cihaz tutarlılığı için yerel (SharedPreferences) listeyle
  /// birlikte kullanılır — bkz. [JoinedCommunitiesService].
  Future<Set<int>> getMyCommunityIds() async {
    try {
      final res = await _db
          .from('community_members')
          .select('community_id')
          .eq('user_id', _uid);
      return (res as List)
          .map((e) => (e as Map)['community_id'] as int)
          .toSet();
    } catch (e) {
      debugPrint('[SupabaseDataService] getMyCommunityIds failed: $e');
      return {};
    }
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

  /// Üyeliği sunucuda kaydeder. Asıl üyelik satırı yazılamazsa hatayı
  /// yukarı fırlatır (çağıran taraf — bkz. [JoinedCommunitiesService] —
  /// bunu yerel optimistic güncellemeyi geri almak için kullanır). Üye
  /// sayacı RPC'si best-effort'tur, başarısız olsa da üyelik geçerlidir.
  Future<void> joinCommunity(int communityId) async {
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
  }

  /// Üyeliği sunucudan kaldırır. Asıl silme işlemi başarısız olursa
  /// hatayı yukarı fırlatır — bkz. [joinCommunity] açıklaması.
  Future<void> leaveCommunity(int communityId) async {
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
  }

  // ── Gönderiler ───────────────────────────────────────────────────────────────

  // Not: hata BİLEREK yutulup sahte/demo gönderi listesi döndürülmüyor (bkz.
  // kontrol.md Bölüm 14.9 / 16.3) — çağıran taraf yerel önbelleği gösterip
  // arka planda bunu dener, başarısız olursa kendi hata durumunu yönetir.
  /// [limit]'ten AZ sayıda sonuç dönmesi, çağıran tarafın sonraki sayfa
  /// olmadığını anlaması için kullanılabilir (bkz. home_screen.dart sonsuz
  /// kaydırma — kontrol.md Bölüm 16.13).
  /// Admin'in gizlediği (status='hidden') gönderiler akışta gösterilmez.
  static const _visiblePostFilter = 'status.is.null,status.neq.hidden';

  Future<List<PostModel>> getGonderiler({int page = 1, int limit = 15}) async {
    final res = await _db
        .from('posts')
        .select('*, communities(category)')
        .or(_visiblePostFilter)
        .order('created_at', ascending: false)
        .range((page - 1) * limit, page * limit - 1);
    final list = (res as List)
        .map((j) => PostModel.fromApiJson(j as Map<String, dynamic>))
        .toList();
    // Yalnızca ilk sayfa (varsayılan) önbelleğe alınır.
    if (list.isNotEmpty && page == 1) unawaited(_cacheList(_keyPosts, res));
    return list;
  }

  /// Yerel önbellekteki gönderileri anında döndürür (ağ beklemez).
  List<PostModel> getCachedGonderiler() =>
      _readCache(_keyPosts).map(PostModel.fromApiJson).toList();

  Future<Map<String, dynamic>> getSupportStatus() async {
    try {
      final now = DateTime.now();
      final week = isoWeek(now);
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
      final week = isoWeek(now);
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
    // Not: hata BİLEREK yutulmuyor — home_screen.dart._handleSupportTap()
    // bu çağrıyı zaten try/catch ile sarıp başarısız olursa optimistic UI
    // güncellemesini geri alıyor; hata burada yutulursa o rollback hiç
    // tetiklenmiyordu (bkz. kontrol.md Bölüm 14.8).
    await _db
        .from('post_supports')
        .delete()
        .eq('user_id', _uid)
        .eq('post_id', postId);
    await _db.rpc('decrement_post_support', params: {'post_id': postId});
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
  /// Biçim ve e-posta kaynağı için bkz. [getCommunityMembers].
  Future<List<Map<String, dynamic>>> getEventParticipants(int postId) async {
    try {
      final res = await _db.rpc(
        'get_event_participants_detailed',
        params: {'p_post_id': postId},
      );
      return _normalizePersonRows(res, dateKey: 'created_at');
    } catch (e) {
      debugPrint('[SupabaseDataService] get_event_participants_detailed failed: $e');
    }
    try {
      final res = await _db
          .from('event_participants')
          .select('user_id, created_at, profiles(id, name, department, profile_photo, role)')
          .eq('post_id', postId)
          .order('created_at', ascending: true);
      return _normalizePersonRows(res, dateKey: 'created_at');
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

  /// Görseli (MIME/boyut sınırı kontrollü) Supabase Storage'a yükler.
  ///
  /// Yalnızca kendi depolamamız kullanılır: üçüncü parti barındırmadaki
  /// görseller hesap silindiğinde kaldırılamaz. Yüklemeden önce EXIF meta
  /// verisi (özellikle GPS konumu) temizlenir ve görsel küçültülür.
  Future<String> uploadPostImage(File file) async {
    final validation = await FileValidator.validateFile(file);
    if (!validation.isValid) {
      throw ArgumentError(validation.errorMessage);
    }

    final sanitized = await ImageSanitizer.stripExifAndReencode(file);
    return _uploadPostImageToSupabase(sanitized);
  }

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

  // Not: hata BİLEREK yutulup sahte/demo kupon listesi döndürülmüyor (bkz.
  // kontrol.md Bölüm 14.9 / 16.3) — çağıran taraf yerel önbelleği gösterip
  // arka planda bunu dener, başarısız olursa kendi hata durumunu yönetir.
  Future<List<DiscountModel>> getKuponlar() async {
    final res =
        await _db.from('discounts').select().order('id', ascending: false);
    final list = (res as List)
        .map((j) => DiscountModel.fromApiJson(j as Map<String, dynamic>))
        .toList();
    if (list.isNotEmpty) unawaited(_cacheList(_keyKuponlar, res));
    return list;
  }

  /// Konum tabanlı, atomic kupon hak etme işlemi (RPC claim_coupon).
  /// Mesafe/geofence kontrolü ve kod üretimi tamamen sunucuda (RPC içinde)
  /// yapılır — istemci yalnızca ham konumu gönderir.
  Future<Map<String, dynamic>> claimCoupon({
    required int discountId,
    required double userLat,
    required double userLng,
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
      return {
        'success': false,
        'error': 'unexpected_response',
        'message': 'Sunucudan beklenmeyen bir yanıt geldi. Tekrar deneyin.',
      };
    } catch (e) {
      // Not: burada BİLEREK sahte bir "başarı" simülasyonu üretilmiyor.
      // Önceki sürüm, RPC çağrısı herhangi bir sebeple (ağ hatası, sunucu
      // hatası) başarısız olduğunda istemci tarafında mesafeyi hesaplayıp
      // kendi kupon kodunu üretiyordu — bu kod veritabanına hiç kaydedilmediği
      // için işletme tarafından geçersiz sayılıyordu VE sahte GPS ile
      // (mesafe kontrolü de istemci tarafında olduğundan) sınırsız kupon
      // kodu üretilmesine izin veriyordu (bkz. kontrol.md Bölüm 10 notu).
      // Kupon hakkı yalnızca sunucu tarafında (RPC) belirlenmeli.
      debugPrint('[SupabaseDataService] claimCoupon RPC hatası: $e');
      return {
        'success': false,
        'error': 'network_or_server_error',
        'message':
            'Kupon açılamadı. İnternet bağlantınızı kontrol edip tekrar deneyin.',
      };
    }
  }


  /// Yerel önbellekteki kuponları anında döndürür (ağ beklemez).
  List<DiscountModel> getCachedKuponlar() =>
      _readCache(_keyKuponlar).map(DiscountModel.fromApiJson).toList();

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

      final adSoyad = p['name'] as String? ?? '';
      final email = _db.auth.currentUser?.id == userId
          ? (_db.auth.currentUser?.email ?? '')
          : '';
      // Doğum tarihi profiles'ta tutulmaz (tablo diğer kullanıcılara açık);
      // yalnızca sahibinin okuyabildiği auth user_metadata'dan gelir.
      final ownMeta = _db.auth.currentUser?.id == userId
          ? _db.auth.currentUser?.userMetadata
          : null;
      final birthDate = ownMeta?['birth_date'] as String? ?? '';
      final bolum = departmentText(p['department']) ?? '';
      final qrString = "NEVGENC KİMLİĞİ\nAd Soyad: $adSoyad\nE-posta: $email\nDoğum Tarihi: $birthDate\nBölüm: $bolum";

      return UserProfileModel(
        adSoyad: adSoyad,
        email: email,
        birthDate: birthDate,
        bolum: bolum,
        sinif: p['grade'] as String? ?? '',
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
    // Not: hata BİLEREK yutulmuyor — çağıran taraf (profile_screen.dart)
    // yerel state'i iyimser (optimistic) güncelliyor, bu yüzden sunucu
    // yazması başarısız olursa kullanıcıya haber verip geri alabilmesi
    // gerekiyor (bkz. kontrol.md Bölüm 14.8).
    await _db.from('profiles').update(updates).eq('id', userId);
  }

  // ── Veri görüntüleme / dışa aktarma (KVKK/GDPR) ─────────────────────────────
  // kontrol.md Bölüm 12.5: hesap silme sağlamdı ama kullanıcının kendi verisini
  // uygulama içinden görüntüleme/dışa aktarma özelliği yoktu, yalnızca e-posta
  // talep süreci vardı. Bu, kullanıcının SADECE kendi (auth.uid()) verisini
  // toplar — RLS zaten başkasının verisine erişimi engelliyor.

  /// Kullanıcının kendi gönderilerini döndürür (profil/veri dışa aktarma için).
  Future<List<Map<String, dynamic>>> getMyPosts() async {
    final res = await _db
        .from('posts')
        .select('id, content, created_at, support_count, community_name')
        .eq('user_id', _uid)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(res as List);
  }

  /// Kullanıcının profilini, gönderilerini, taleplerini ve rozetlerini tek bir
  /// JSON'da toplar — "Verilerimi Görüntüle" ekranında gösterilir/kopyalanır.
  Future<Map<String, dynamic>> exportMyData() async {
    final uid = _uid;
    final profile = await getUserProfile(uid);
    final posts = await getMyPosts().catchError((_) => <Map<String, dynamic>>[]);
    final tickets = await getMyTickets().catchError((_) => <UserTicket>[]);
    final communityIds = await getMyCommunityIds().catchError((_) => <int>{});

    return {
      'exported_at': DateTime.now().toUtc().toIso8601String(),
      'profile': profile == null
          ? null
          : {
              'id': uid,
              'name': profile.adSoyad,
              'email': profile.email,
              'department': profile.bolum,
              'grade': profile.sinif,
              'birth_date': profile.birthDate,
              'badges': profile.rozetler.map((r) => r.rozetAd).toList(),
            },
      'joined_community_count': communityIds.length,
      'posts': posts
          .map(
            (p) => {
              'id': p['id'],
              'content': p['content'],
              'created_at': p['created_at'],
              'support_count': p['support_count'],
              'community_name': p['community_name'],
            },
          )
          .toList(),
      'tickets': tickets
          .map(
            (t) => {
              'id': t.id,
              'subject': t.subject,
              'status': t.status,
              'created_at': t.createdAt.toIso8601String(),
            },
          )
          .toList(),
    };
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

      return LeaderboardData(topluluklar: comList, uyeler: stuList);
    } catch (e) {
      // Sahte/demo sıralama gösterilmez — ekran kendi hata durumunu gösterir.
      debugPrint('[SupabaseDataService] getLeaderboardData failed: $e');
      rethrow;
    }
  }

  Future<void> registerFcmToken(
    String token, {
    String platform = 'android',
  }) async {
    await _db.from('fcm_tokens').upsert({
      'user_id': _uid,
      'token': token,
      'platform': platform,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
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
      'updated_at': DateTime.now().toUtc().toIso8601String(),
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
    final cutoff = DateTime.now().toUtc().subtract(const Duration(days: 30)).toIso8601String();
    await _db
        .from('notifications')
        .delete()
        .eq('user_id', userId)
        .eq('is_read', true)
        .lt('created_at', cutoff);
  }

  /// Okunmamış bildirim sayısı (anasayfa/zil rozeti için — hafif count sorgusu).
  Future<int> getUnreadNotificationCount(String userId) async {
    try {
      final res = await _db
          .from('notifications')
          .select()
          .eq('user_id', userId)
          .eq('is_read', false)
          .count(CountOption.exact);
      return res.count;
    } catch (e) {
      debugPrint('[SupabaseDataService] getUnreadNotificationCount failed: $e');
      return 0;
    }
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
      final q6 = _db.from('posts').select('user_id').eq('community_id', communityId).gte('created_at', DateTime.now().toUtc().subtract(const Duration(days: 30)).toIso8601String());
      final q7 = _db.from('post_supports').select('user_id').eq('community_id', communityId).gte('created_at', DateTime.now().toUtc().subtract(const Duration(days: 30)).toIso8601String());

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
      final thirtyDaysAgo = now.toUtc().subtract(const Duration(days: 30)).toIso8601String();

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
      final sevenDaysAgo = now.toUtc().subtract(const Duration(days: 7)).toIso8601String();

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
  /// Önce `send-community-notification` (audience=all) denenir: uygulama içi
  /// kayıt + gerçek FCM push. Fonksiyon deploy edilmemişse (404) yalnızca
  /// uygulama içi kayıt doğrudan eklenir.
  Future<void> sendUpdateAnnouncement({
    required String title,
    required String message,
    String? version,
    String? storeUrl,
  }) async {
    try {
      await _db.functions.invoke(
        'send-community-notification',
        body: {
          'audience': 'all',
          'title': title,
          'body': message,
          'data': {
            'version': version,
            'store_url': storeUrl,
            'is_update': true,
          },
        },
      );
      return;
    } on FunctionException catch (e) {
      if (e.status != 404) {
        final details = e.details;
        final msg = details is Map ? details['error'] as String? : null;
        throw Exception(msg ?? 'Duyuru gönderilemedi (HTTP ${e.status}).');
      }
      debugPrint('[SupabaseDataService] send-community-notification yok, doğrudan kayda düşülüyor.');
    }
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
          'created_at': DateTime.now().toUtc().toIso8601String(),
        }).toList();

        await _db.from('notifications').insert(rows);
      }
    } catch (e) {
      debugPrint('[SupabaseDataService] sendUpdateAnnouncement hatası: $e');
      rethrow;
    }
  }

  // ── Haberler (Anasayfa Bülteni) ─────────────────────────────────────────────
  // RLS: herkes okuyabilir, sadece admin yazabilir (bkz. migration).

  Future<List<NewsModel>> getNews({int limit = 20}) async {
    try {
      final res = await _db
          .from('news_bulletins')
          .select()
          .order('published_at', ascending: false)
          .limit(limit);
      final list = (res as List)
          .map((j) => NewsModel.fromApiJson(j as Map<String, dynamic>))
          .toList();
      unawaited(_cacheList(_keyNews, res));
      return list;
    } catch (e) {
      debugPrint('[SupabaseDataService] getNews failed: $e');
      return [];
    }
  }

  List<NewsModel> getCachedNews() =>
      _readCache(_keyNews).map(NewsModel.fromApiJson).toList();

  /// Admin: yeni haber ekler. Sunucu tarafı yetki kontrolü RLS ile yapılır.
  Future<void> createNews({
    required String title,
    required String summary,
    required String content,
    String? imageUrl,
    DateTime? publishedAt,
  }) async {
    await _db.from('news_bulletins').insert({
      'title': title,
      'summary': summary,
      'content': content,
      if (imageUrl != null && imageUrl.isNotEmpty) 'image_url': imageUrl,
      'published_at': (publishedAt ?? DateTime.now()).toUtc().toIso8601String(),
      'created_by': _uid,
    });
  }

  Future<void> updateNews(
    int id, {
    required String title,
    required String summary,
    required String content,
    String? imageUrl,
  }) async {
    await _db.from('news_bulletins').update({
      'title': title,
      'summary': summary,
      'content': content,
      'image_url': (imageUrl != null && imageUrl.isNotEmpty) ? imageUrl : null,
    }).eq('id', id);
  }

  Future<void> deleteNews(int id) async {
    await _db.from('news_bulletins').delete().eq('id', id);
  }

  // ── İş İlanları (Nev Plus) ──────────────────────────────────────────────────
  // RLS: herkes okuyabilir, sadece admin yazabilir (bkz. migration).

  Future<List<JobListingModel>> getJobListings({int limit = 50}) async {
    try {
      final res = await _db
          .from('job_listings')
          .select()
          .order('published_at', ascending: false)
          .limit(limit);
      final list = (res as List)
          .map((j) => JobListingModel.fromApiJson(j as Map<String, dynamic>))
          .toList();
      unawaited(_cacheList(_keyJobListings, res));
      return list;
    } catch (e) {
      debugPrint('[SupabaseDataService] getJobListings failed: $e');
      return [];
    }
  }

  List<JobListingModel> getCachedJobListings() =>
      _readCache(_keyJobListings).map(JobListingModel.fromApiJson).toList();

  /// Admin: yeni iş ilanı ekler. Sunucu tarafı yetki kontrolü RLS ile yapılır.
  Future<void> createJobListing({
    required String title,
    required String description,
    DateTime? publishedAt,
  }) async {
    await _db.from('job_listings').insert({
      'title': title,
      'description': description,
      'published_at': (publishedAt ?? DateTime.now()).toUtc().toIso8601String(),
      'created_by': _uid,
    });
  }

  Future<void> updateJobListing(
    int id, {
    required String title,
    required String description,
  }) async {
    await _db.from('job_listings').update({
      'title': title,
      'description': description,
    }).eq('id', id);
  }

  Future<void> deleteJobListing(int id) async {
    await _db.from('job_listings').delete().eq('id', id);
  }

  // ── Menüde Ne Var? (Nev Plus) ───────────────────────────────────────────────
  // İş ilanlarıyla aynı yapı (title/description) ve aynı RLS: herkes okur,
  // yalnızca admin yazar. Model olarak JobListingModel yeniden kullanılır.

  Future<List<JobListingModel>> getMenuItems({int limit = 50}) async {
    try {
      final res = await _db
          .from('menu_items')
          .select()
          .order('published_at', ascending: false)
          .limit(limit);
      final list = (res as List)
          .map((j) => JobListingModel.fromApiJson(j as Map<String, dynamic>))
          .toList();
      unawaited(_cacheList(_keyMenuItems, res));
      return list;
    } catch (e) {
      debugPrint('[SupabaseDataService] getMenuItems failed: $e');
      return [];
    }
  }

  List<JobListingModel> getCachedMenuItems() =>
      _readCache(_keyMenuItems).map(JobListingModel.fromApiJson).toList();

  Future<void> createMenuItem({
    required String title,
    required String description,
  }) async {
    await _db.from('menu_items').insert({
      'title': title,
      'description': description,
      'published_at': DateTime.now().toUtc().toIso8601String(),
      'created_by': _uid,
    });
  }

  Future<void> updateMenuItem(
    int id, {
    required String title,
    required String description,
  }) async {
    await _db.from('menu_items').update({
      'title': title,
      'description': description,
    }).eq('id', id);
  }

  Future<void> deleteMenuItem(int id) async {
    await _db.from('menu_items').delete().eq('id', id);
  }

  // ── Başkan: Üyelere Bildirim Gönderme ───────────────────────────────────────
  // Edge Function üzerinden gönderilir: yetki (rol + kendi topluluğu) sunucu
  // tarafında (Deno) tekrar doğrulanır — istemci kontrolü tek başına güvenilmez.

  /// Başkanın kendi topluluğundaki üyelere bildirim gönderir.
  /// [recipientIds] boşsa topluluğun tüm üyelerine gönderilir.
  Future<Map<String, dynamic>> sendCommunityNotification({
    required int communityId,
    required String title,
    required String body,
    List<String>? recipientIds,
  }) async {
    try {
      final res = await _db.functions.invoke(
        'send-community-notification',
        body: {
          'community_id': communityId,
          'title': title,
          'body': body,
          if (recipientIds != null) 'recipient_ids': recipientIds,
        },
      );
      return Map<String, dynamic>.from(res.data as Map);
    } on FunctionException catch (e) {
      // invoke() 2xx dışı yanıtlarda FunctionException fırlatır (FunctionResponse
      // asla hata durumunu taşımaz) — sunucunun döndürdüğü okunabilir mesajı
      // (details.error) çıkarıp kullanıcıya onu gösteriyoruz.
      final details = e.details;
      final message = details is Map ? details['error'] as String? : null;
      throw Exception(message ?? 'Bildirim gönderilemedi (HTTP ${e.status}).');
    }
  }
}

