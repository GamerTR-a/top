import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/topluluk.dart';

/// Kullanıcının "Katıl" butonuyla katıldığı toplulukları **yerel olarak**
/// (shared_preferences) tutan servis.
///
/// Üyelik durumu küçük ve cihaza özel bir veri olduğundan sunucuya
/// yazılmaz — anında açılır, çevrimdışı da çalışır. Her katıl/ayrıl
/// işleminde [revision] sayacı artar; profil ekranı (IndexedStack içinde
/// canlı kalan tab) bu sayacı dinleyerek listesini tazeler.
class JoinedCommunitiesService {
  JoinedCommunitiesService._();
  static final JoinedCommunitiesService instance =
      JoinedCommunitiesService._();

  static const _key = 'joined_communities_v1';

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
  Future<bool> toggle(Topluluk t) async {
    final prefs = await _ensure();
    final list = await getJoinedCommunities();
    final already = list.any((x) => x.id == t.id);
    if (already) {
      list.removeWhere((x) => x.id == t.id);
    } else {
      list.insert(0, t);
    }
    await _save(prefs, list);
    return !already;
  }

  /// "Topluluktan Ayrıl" — profil ekranındaki listeden çıkarır.
  Future<void> leave(int id) async {
    final prefs = await _ensure();
    final list = await getJoinedCommunities();
    final before = list.length;
    list.removeWhere((x) => x.id == id);
    if (list.length != before) await _save(prefs, list);
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
