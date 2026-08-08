import 'package:flutter/material.dart';

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

  int get unreadCount => notifications.value.where((n) => !n.isRead).length;

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
}

final notificationService = NotificationService();
