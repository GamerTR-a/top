import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/topluluk.dart';
import 'supabase_data_service.dart';

/// Kullanıcının "Katıl" butonuyla katıldığı toplulukları tutan servis.
///
/// Yerel (shared_preferences) kopya anında açılır/çevrimdışı çalışır ama
/// artık tek gerçek kaynak değil: her katıl/ayrıl işlemi sunucudaki
/// `community_members` tablosuna da yazılır (bkz. [SupabaseDataService]
/// `joinCommunity`/`leaveCommunity`) — başkan panelindeki üye listesinin
/// ve bildirim özelliğinin güvenilir çalışabilmesi için bu gereklidir.
/// Sunucu çağrısı başarısız olursa yerel değişiklik geri alınır (rollback).
/// Her katıl/ayrıl işleminde [revision] sayacı artar; profil ekranı
/// (IndexedStack içinde canlı kalan tab) bu sayacı dinleyerek listesini
/// tazeler.
class JoinedCommunitiesService {
  JoinedCommunitiesService._();
  static final JoinedCommunitiesService instance =
      JoinedCommunitiesService._();

  static const _key = 'joined_communities_v1';
  final SupabaseDataService _api = SupabaseDataService();

  /// Her katıl/ayrıl işleminde artan sayaç — UI'ı bilgilendirmek için.
  final ValueNotifier<int> revision = ValueNotifier<int>(0);

  SharedPreferences? _prefs;

  Future<SharedPreferences> _ensure() async =>
      _prefs ??= await SharedPreferences.getInstance();

  /// Kayıtlı toplulukların tam anlık görüntüsü (görsel için id/ad/logo yeterli,
  /// ama tam [Topluluk] saklanır ki profil kartı sunucusuz çizilebilsin).
  Future<List<Topluluk>> getJoinedCommunities() async {
    final prefs = await _ensure();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => Topluluk.fromApiJson((e as Map).cast<String, dynamic>()))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<bool> isJoined(int id) async {
    final list = await getJoinedCommunities();
    return list.any((t) => t.id == id);
  }

  /// Katıl/ayrıl. Dönen değer yeni durum: `true` = katıldı, `false` = ayrıldı.
  /// Önce yerel liste anında güncellenir (optimistic), ardından sunucuya
  /// (`community_members`) yazılır. Sunucu çağrısı başarısız olursa yerel
  /// değişiklik geri alınır ve hata çağırana fırlatılır.
  Future<bool> toggle(Topluluk t) async {
    final prefs = await _ensure();
    final list = await getJoinedCommunities();
    final already = list.any((x) => x.id == t.id);
    final newList = List<Topluluk>.from(list);
    if (already) {
      newList.removeWhere((x) => x.id == t.id);
    } else {
      newList.insert(0, t);
    }
    await _save(prefs, newList);
    final joined = !already;
    try {
      if (joined) {
        await _api.joinCommunity(t.id);
      } else {
        await _api.leaveCommunity(t.id);
      }
    } catch (e) {
      // Sunucu başarısız oldu — yerel değişikliği geri al.
      await _save(prefs, list);
      rethrow;
    }
    return joined;
  }

  /// "Topluluktan Ayrıl" — profil ekranındaki listeden çıkarır ve
  /// sunucudaki üyeliği de siler. Sunucu çağrısı başarısız olursa yerel
  /// değişiklik geri alınır ve hata çağırana fırlatılır.
  Future<void> leave(int id) async {
    final prefs = await _ensure();
    final list = await getJoinedCommunities();
    final before = list.length;
    final newList = List<Topluluk>.from(list)..removeWhere((x) => x.id == id);
    if (newList.length == before) return;
    await _save(prefs, newList);
    try {
      await _api.leaveCommunity(id);
    } catch (e) {
      await _save(prefs, list);
      rethrow;
    }
  }

  /// Tek seferlik geçiş: eski sürümlerde sadece yerelde tutulan
  /// üyelikleri sunucuya yazar (sunucuda hiç olmayanlar). Giriş
  /// sonrası best-effort çağrılır — hataları yutar, UI'ı bloklamaz.
  Future<void> syncWithServer() async {
    try {
      final local = await getJoinedCommunities();
      if (local.isEmpty) return;
      final serverIds = await _api.getMyCommunityIds();
      final missing = local.where((t) => !serverIds.contains(t.id));
      for (final t in missing) {
        try {
          await _api.joinCommunity(t.id);
        } catch (_) {}
      }
    } catch (_) {}
  }

  Future<void> _save(SharedPreferences prefs, List<Topluluk> list) async {
    final json = jsonEncode(
      list
          .map((t) => {
                'id': t.id,
                'name': t.ad,
                'logo_path': t.logoPath,
                'category': t.kategori,
                'score': t.puan,
                'member_count': t.uyeSayisi,
                'description': t.aciklama,
                'chairman_name': t.baskanAdi,
                'chairman_id': t.baskanId,
              })
          .toList(),
    );
    await prefs.setString(_key, json);
    revision.value++;
  }
}
