import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/post_model.dart';

/// Kullanıcının engellediği toplulukları ve gönderi sahiplerini tutar
/// (App Store Kural 1.2 — kullanıcı içeriğinde engelleme zorunlu).
///
/// Liste cihazda, oturum açan kullanıcıya özel anahtarla saklanır; engellenen
/// topluluğun/kişinin gönderileri akışta anında gizlenir.
class BlockService {
  BlockService._();
  static final BlockService instance = BlockService._();

  final ValueNotifier<int> changes = ValueNotifier(0);

  Set<int> _communityIds = {};
  Set<String> _userIds = {};
  String? _loadedFor;

  String get _uid => Supabase.instance.client.auth.currentUser?.id ?? 'anon';
  String get _communityKey => 'blocked_communities_$_uid';
  String get _userKey => 'blocked_users_$_uid';

  bool get hasBlocks => _communityIds.isNotEmpty || _userIds.isNotEmpty;

  Future<void> _ensureLoaded() async {
    if (_loadedFor == _uid) return;
    final prefs = await SharedPreferences.getInstance();
    _communityIds = (prefs.getStringList(_communityKey) ?? const [])
        .map(int.tryParse)
        .whereType<int>()
        .toSet();
    _userIds = (prefs.getStringList(_userKey) ?? const []).toSet();
    _loadedFor = _uid;
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _communityKey,
      _communityIds.map((e) => e.toString()).toList(),
    );
    await prefs.setStringList(_userKey, _userIds.toList());
    changes.value++;
  }

  /// Gönderinin topluluğunu ve (varsa) yazarını engeller.
  Future<void> blockPostSource(PostModel post) async {
    await _ensureLoaded();
    if (post.communityId != null) _communityIds.add(post.communityId!);
    if (post.userId != null) _userIds.add(post.userId!);
    await _persist();
  }

  Future<void> clearAll() async {
    await _ensureLoaded();
    _communityIds.clear();
    _userIds.clear();
    await _persist();
  }

  /// Engellenen kaynaklardan gelen gönderileri çıkarır.
  Future<List<PostModel>> filter(List<PostModel> posts) async {
    await _ensureLoaded();
    if (!hasBlocks) return posts;
    return posts.where((p) => !isBlocked(p)).toList();
  }

  bool isBlocked(PostModel p) =>
      (p.communityId != null && _communityIds.contains(p.communityId)) ||
      (p.userId != null && _userIds.contains(p.userId));
}
