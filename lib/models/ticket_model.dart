import 'package:flutter/material.dart';

class UserTicket {
  final String id;
  final String userId;
  final String type; // 'complaint' | 'request' | 'suggestion'
  final String subject;
  final String description;
  final String status; // 'open' | 'in_progress' | 'resolved' | 'closed'
  final String? adminNotes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const UserTicket({
    required this.id,
    required this.userId,
    required this.type,
    required this.subject,
    required this.description,
    required this.status,
    this.adminNotes,
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserTicket.fromJson(Map<String, dynamic> json) {
    return UserTicket(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      type: json['type'] as String,
      subject: json['subject'] as String,
      description: json['description'] as String,
      status: json['status'] as String,
      adminNotes: json['admin_notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'type': type,
        'subject': subject,
        'description': description,
        'status': status,
        'admin_notes': adminNotes,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  // Type display names (Turkish)
  String get typeDisplayName {
    switch (type) {
      case 'complaint':
        return 'Şikayet';
      case 'request':
        return 'Talep';
      case 'suggestion':
        return 'Öneri';
      default:
        return type;
    }
  }

  // Status display names (Turkish)
  String get statusDisplayName {
    switch (status) {
      case 'open':
        return 'Açık';
      case 'in_progress':
        return 'İşlemde';
      case 'resolved':
        return 'Çözüldü';
      case 'closed':
        return 'Kapalı';
      default:
        return status;
    }
  }

  // Status colors
  static const Map<String, Color> _statusColors = {
    'open': Color(0xFF2196F3),       // Blue
    'in_progress': Color(0xFFFF9800), // Orange
    'resolved': Color(0xFF4CAF50),    // Green
    'closed': Color(0xFF9E9E9E),      // Grey
  };

  Color get statusColor => _statusColors[status] ?? const Color(0xFF2196F3);

  // Type icons
  static const Map<String, IconData> _typeIcons = {
    'complaint': Icons.report_problem_outlined,
    'request': Icons.assignment_outlined,
    'suggestion': Icons.lightbulb_outlined,
  };

  IconData get typeIcon => _typeIcons[type] ?? Icons.help_outline;

  UserTicket copyWith({
    String? id,
    String? userId,
    String? type,
    String? subject,
    String? description,
    String? status,
    String? adminNotes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserTicket(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      subject: subject ?? this.subject,
      description: description ?? this.description,
      status: status ?? this.status,
      adminNotes: adminNotes ?? this.adminNotes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static const List<String> validTypes = ['complaint', 'request', 'suggestion'];
  static const List<String> validStatuses = ['open', 'in_progress', 'resolved', 'closed'];
}