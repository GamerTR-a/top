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

  RealtimeChannel? _postsChannel;

  Stream<Map<String, dynamic>> get onPostSupported =>
      _postSupportedController.stream;

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

  void disconnect() {
    if (_postsChannel != null) {
      _db.removeChannel(_postsChannel!);
      _postsChannel = null;
    }
    debugPrint('[Realtime] Bağlantı kapatıldı.');
  }

  void dispose() {
    _postSupportedController.close();
    disconnect();
  }
}

final socketService = SocketService();
