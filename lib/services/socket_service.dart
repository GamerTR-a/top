import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase Realtime ile gerçek zamanlı bağlantıyı yönetir.
/// Eski Socket.IO arayüzü korundu — ekranlar değişmeden çalışır.
class SocketService {
  static final SocketService _instance = SocketService._();
  factory SocketService() => _instance;
  SocketService._();

  final _db = Supabase.instance.client;

  final _postSupportedController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _newMessageController =
      StreamController<Map<String, dynamic>>.broadcast();

  RealtimeChannel? _postsChannel;
  final Map<int, RealtimeChannel> _communityChannels = {};

  Stream<Map<String, dynamic>> get onPostSupported =>
      _postSupportedController.stream;

  Stream<Map<String, dynamic>> get onNewMessage => _newMessageController.stream;

  bool get isConnected => _postsChannel != null;

  void connect() {
    if (isConnected) return;
    _subscribeToPostUpdates();
    debugPrint('[Realtime] Bağlandı.');
  }

  void _subscribeToPostUpdates() {
    _postsChannel = _db
        .channel('public:posts')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'posts',
          callback: (payload) {
            try {
              final newRow = payload.newRecord;
              _postSupportedController.add({
                'postId': newRow['id'],
                'supportCount': newRow['support_count'],
              });
            } catch (e) {
              debugPrint('[Realtime] posts callback error: $e');
            }
          },
        )
        .subscribe();
  }

  void joinCommunity(int communityId) {
    if (_communityChannels.containsKey(communityId)) return;
    final channel = _db
        .channel('community_messages:$communityId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'community_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'community_id',
            value: communityId,
          ),
          callback: (payload) {
            try {
              _newMessageController.add({'message': payload.newRecord});
            } catch (e) {
              debugPrint('[Realtime] messages callback error: $e');
            }
          },
        )
        .subscribe();
    _communityChannels[communityId] = channel;
    debugPrint('[Realtime] Topluluk $communityId kanalına katıldı.');
  }

  void leaveCommunity(int communityId) {
    final channel = _communityChannels.remove(communityId);
    if (channel != null) {
      _db.removeChannel(channel);
      debugPrint('[Realtime] Topluluk $communityId kanalından ayrıldı.');
    }
  }

  void disconnect() {
    if (_postsChannel != null) {
      _db.removeChannel(_postsChannel!);
      _postsChannel = null;
    }
    for (final ch in _communityChannels.values) {
      _db.removeChannel(ch);
    }
    _communityChannels.clear();
    debugPrint('[Realtime] Bağlantı kapatıldı.');
  }

  void dispose() {
    _postSupportedController.close();
    _newMessageController.close();
    disconnect();
  }
}

final socketService = SocketService();
