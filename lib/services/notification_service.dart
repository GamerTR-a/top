import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AppNotification {
  final String id;
  final String title;
  final String body;
  final IconData icon;
  final Color color;
  final DateTime createdAt;
  bool isRead;

  AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.icon,
    required this.color,
    required this.createdAt,
    this.isRead = false,
  });
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final ValueNotifier<List<AppNotification>> notifications = ValueNotifier([]);

  // Push notification settings (persisted locally)
  bool _pushEnabled = true;
  bool _memberJoinEnabled = true;
  bool _eventEnabled = true;
  bool _reportEnabled = true;
  bool _badgeEnabled = true;
  bool _announcementEnabled = true;
  bool _realtimeEnabled = true;

  bool get pushEnabled => _pushEnabled;
  bool get memberJoinEnabled => _memberJoinEnabled;
  bool get eventEnabled => _eventEnabled;
  bool get reportEnabled => _reportEnabled;
  bool get badgeEnabled => _badgeEnabled;
  bool get announcementEnabled => _announcementEnabled;
  bool get realtimeEnabled => _realtimeEnabled;

  int get unreadCount => notifications.value.where((n) => !n.isRead).length;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _pushEnabled = prefs.getBool('notif_push') ?? true;
    _memberJoinEnabled = prefs.getBool('notif_member_join') ?? true;
    _eventEnabled = prefs.getBool('notif_event') ?? true;
    _reportEnabled = prefs.getBool('notif_report') ?? true;
    _badgeEnabled = prefs.getBool('notif_badge') ?? true;
    _announcementEnabled = prefs.getBool('notif_announcement') ?? true;
    _realtimeEnabled = prefs.getBool('notif_realtime') ?? true;
  }

  void add({
    required String title,
    required String body,
    IconData icon = Icons.notifications_outlined,
    Color color = const Color(0xFFBB86FC),
  }) {
    final newList = List<AppNotification>.from(notifications.value);
    newList.insert(
      0,
      AppNotification(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: title,
        body: body,
        icon: icon,
        color: color,
        createdAt: DateTime.now(),
      ),
    );
    // En fazla 50 bildirim tut
    if (newList.length > 50) newList.removeRange(50, newList.length);
    notifications.value = newList;
  }

  void markAllRead() {
    final updated = notifications.value.map((n) {
      n.isRead = true;
      return n;
    }).toList();
    notifications.value = List<AppNotification>.from(updated);
  }

  void markRead(String id) {
    final updated = notifications.value.map((n) {
      if (n.id == id) n.isRead = true;
      return n;
    }).toList();
    notifications.value = List<AppNotification>.from(updated);
  }

  void delete(String id) {
    notifications.value = notifications.value.where((n) => n.id != id).toList();
  }

  void clear() {
    notifications.value = [];
  }

  Future<void> setPushEnabled(bool v) async {
    _pushEnabled = v;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notif_push', v);
  }

  Future<void> setMemberJoinEnabled(bool v) async {
    _memberJoinEnabled = v;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notif_member_join', v);
  }

  Future<void> setEventEnabled(bool v) async {
    _eventEnabled = v;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notif_event', v);
  }

  Future<void> setReportEnabled(bool v) async {
    _reportEnabled = v;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notif_report', v);
  }

  Future<void> setBadgeEnabled(bool v) async {
    _badgeEnabled = v;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notif_badge', v);
  }

  Future<void> setAnnouncementEnabled(bool v) async {
    _announcementEnabled = v;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notif_announcement', v);
  }

  Future<void> setRealtimeEnabled(bool v) async {
    _realtimeEnabled = v;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notif_realtime', v);
  }

  /// FCM token isteği ve kaydetme
  Future<void> requestPermission() async {
    if (!_pushEnabled) return;
    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(data: {'notification_permission': 'granted'}),
      );
    } catch (_) {}
  }

  Future<void> saveFcmTokenToServer() async {
    if (!_pushEnabled) return;
    // FCM token kaydı için edge function çağrılabilir
    // Bu implementasyon için placeholder
  }
}

final notificationService = NotificationService();