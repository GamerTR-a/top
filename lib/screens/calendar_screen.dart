import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_calendar/table_calendar.dart';
import '../services/local_notification_service.dart';
import '../widgets/category_button.dart';
import '../widgets/animated_theme_background.dart';
import '../theme/app_theme.dart';

class TaskItem {
  final String id;
  final String title;
  final String description;
  final DateTime reminderAt;
  final IconData icon;
  final Color accentColor;
  bool isCompleted;

  TaskItem({
    required this.id,
    required this.title,
    required this.description,
    required this.reminderAt,
    required this.icon,
    required this.accentColor,
    this.isCompleted = false,
  });

  /// Bu görevin hatırlatıcı bildirimi için kararlı bildirim ID'si.
  int get notificationId => LocalNotificationService.idFromString(id);

  static const List<String> _months = [
    'Oca', 'Şub', 'Mar', 'Nis', 'May', 'Haz',
    'Tem', 'Ağu', 'Eyl', 'Eki', 'Kas', 'Ara',
  ];

  /// Kart üzerinde gösterilen tarih + saat etiketi (örn. "12 Eki, 14:30").
  String get timeLabel {
    final d = reminderAt;
    final h = d.hour.toString().padLeft(2, '0');
    final m = d.minute.toString().padLeft(2, '0');
    return '${d.day} ${_months[d.month - 1]}, $h:$m';
  }

  /// Task ikonları — ağaç sallama (icon tree-shaking) release derlemeyi kırdığı
  /// için `IconData(...)` çalışma anında ÜRETİLMEZ; bilinen 4 ikon const bir
  /// sözlükte tutulur, kod noktası/key üzerinden geri çözülür.
  static const Map<String, IconData> _iconsByKey = {
    'assignment': Icons.assignment_rounded,
    'book': Icons.menu_book_rounded,
    'groups': Icons.groups_rounded,
    'event': Icons.event_note_rounded,
  };

  static String _keyForIcon(IconData icon) {
    for (final e in _iconsByKey.entries) {
      if (e.value.codePoint == icon.codePoint &&
          e.value.fontFamily == icon.fontFamily) {
        return e.key;
      }
    }
    return 'event';
  }

  static IconData _iconFromJson(Map<String, dynamic> json) {
    final key = json['iconKey'] as String?;
    if (key != null && _iconsByKey.containsKey(key)) return _iconsByKey[key]!;
    // Eski kayıtlar: kod noktası (int) olarak saklanmıştı — bilinenlerle eşleştir.
    final codePoint = json['icon'] as int?;
    if (codePoint != null) {
      for (final i in _iconsByKey.values) {
        if (i.codePoint == codePoint) return i;
      }
    }
    return Icons.event_note_rounded;
  }

  /// Yerel saklama için serileştirme.
  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'reminderAt': reminderAt.toIso8601String(),
        'isCompleted': isCompleted,
        'iconKey': _keyForIcon(icon),
        'icon': icon.codePoint, // eski sürümler için geriye dönük uyumluluk
        'color': accentColor.toARGB32(),
      };

  factory TaskItem.fromJson(Map<String, dynamic> json) {
    DateTime reminderAt;
    final rawReminder = json['reminderAt'] as String?;
    if (rawReminder != null) {
      reminderAt = DateTime.tryParse(rawReminder) ?? DateTime.now();
    } else {
      // v1 şemasından (yalnızca serbest metin 'time') geçiş — tarih hiç
      // saklanmamıştı, bugüne varsayılan bir saat atanır.
      reminderAt = DateTime.now();
    }
    return TaskItem(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      reminderAt: reminderAt,
      icon: _iconFromJson(json),
      accentColor: Color(json['color'] as int? ?? 0xFF00ACC1),
      isCompleted: json['isCompleted'] as bool? ?? false,
    );
  }
}

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  final List<String> _categories = [
    'Günlük',
    'Ajanda',
    'Not',
    'Plan',
    'Yazarlığım',
  ];
  String _selectedCategory = 'Günlük';

  final Map<DateTime, Map<String, String>> _notes = {};
  final TextEditingController _noteController = TextEditingController();
  static const _prefsKey = 'calendar_notes_v1';
  static const _prefsTasksKey = 'calendar_tasks_v1';

  bool _isCollapsed = false;

  static DateTime _tomorrowAt(int hour, int minute) {
    final now = DateTime.now();
    final tomorrow = now.add(const Duration(days: 1));
    return DateTime(tomorrow.year, tomorrow.month, tomorrow.day, hour, minute);
  }

  late final List<TaskItem> _tasks = [
    TaskItem(
      id: '1',
      title: 'Yazılım Projesi Teslimi',
      description: 'Bilişim Sistemleri Mühendisliği 3. Sınıf proje raporu teslim edilecek.',
      reminderAt: _tomorrowAt(14, 0),
      icon: Icons.assignment_rounded,
      accentColor: const Color(0xFF00ACC1),
    ),
    TaskItem(
      id: '2',
      title: 'Kütüphane Kitap İadesi',
      description: 'Merkez Kütüphane 7/24 salonuna ödünç kitap teslimi yapılacak.',
      reminderAt: _tomorrowAt(16, 30),
      icon: Icons.menu_book_rounded,
      accentColor: const Color(0xFFFFD700),
    ),
    TaskItem(
      id: '3',
      title: 'Topluluk Buluşması',
      description: 'Yazılım ve Bilişim Topluluğu yönetim ekibi haftalık toplantısı.',
      reminderAt: _tomorrowAt(19, 0),
      icon: Icons.groups_rounded,
      accentColor: const Color(0xFF9D4EDD),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _loadNotes();
    _loadTasks();
  }

  DateTime _getStartOfWeek(DateTime date) {
    // Monday is weekday 1
    return date.subtract(Duration(days: date.weekday - 1));
  }

  Widget _buildCollapsedWeekBar(AppTheme theme) {
    final startOfWeek = _getStartOfWeek(_focusedDay);
    final weekDays = List.generate(
      7,
      (i) => DateTime(
        startOfWeek.year,
        startOfWeek.month,
        startOfWeek.day + i,
      ),
    );

    const dayLabels = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: theme.isDark
            ? theme.surface.withValues(alpha: 0.85)
            : theme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: theme.isDark
              ? theme.primary.withValues(alpha: 0.35)
              : const Color(0xFFE2E8F0),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: theme.isDark
                ? theme.primary.withValues(alpha: 0.1)
                : Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Sol Ok (Önceki Hafta)
          IconButton(
            onPressed: () {
              setState(() {
                _focusedDay = _focusedDay.subtract(const Duration(days: 7));
              });
            },
            tooltip: 'Önceki Hafta',
            icon: Icon(
              Icons.chevron_left_rounded,
              color: theme.textColor,
              size: 22,
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),

          // 7 Günlük Liste
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(7, (index) {
                final day = weekDays[index];
                final isSelected = isSameDay(_selectedDay, day);

                return GestureDetector(
                  onTap: () => _onDaySelected(day, day),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: isSelected ? 44 : 36,
                    height: isSelected ? 72 : 60,
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      gradient: isSelected
                          ? LinearGradient(
                              colors: [
                                theme.primary,
                                theme.primary.withValues(alpha: 0.8),
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            )
                          : null,
                      color: isSelected ? null : Colors.transparent,
                      borderRadius: BorderRadius.circular(isSelected ? 18 : 12),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: theme.primary.withValues(alpha: 0.35),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ]
                          : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          dayLabels[index],
                          style: TextStyle(
                            color: isSelected
                                ? Colors.white.withValues(alpha: 0.9)
                                : theme.textMuted,
                            fontSize: 11,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${day.day}',
                          style: TextStyle(
                            color: isSelected ? Colors.white : theme.textColor,
                            fontSize: isSelected ? 17 : 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (isSelected) ...[
                          const SizedBox(height: 4),
                          Container(
                            width: 5,
                            height: 5,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),

          // Sağ Ok (Sonraki Hafta)
          IconButton(
            onPressed: () {
              setState(() {
                _focusedDay = _focusedDay.add(const Duration(days: 7));
              });
            },
            tooltip: 'Sonraki Hafta',
            icon: Icon(
              Icons.chevron_right_rounded,
              color: theme.textColor,
              size: 22,
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskCard(BuildContext context, AppTheme theme, TaskItem task) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.isDark
            ? theme.surface.withValues(alpha: 0.8)
            : theme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.isDark
              ? theme.primary.withValues(alpha: 0.3)
              : const Color(0xFFE2E8F0),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: theme.isDark
                ? Colors.black.withValues(alpha: 0.2)
                : Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Sol Görsel / İkon Bölümü (Referans Görseldeki Sol Kare Kutucuk)
          Container(
            width: 85,
            height: 85,
            decoration: BoxDecoration(
              color: task.accentColor.withValues(alpha: 0.15),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                bottomLeft: Radius.circular(18),
              ),
              border: Border(
                right: BorderSide(
                  color: task.accentColor.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
            ),
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: task.accentColor.withValues(alpha: 0.25),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  task.icon,
                  color: task.accentColor,
                  size: 26,
                ),
              ),
            ),
          ),

          // Sağ Detay Bölümü
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          task.title,
                          style: TextStyle(
                            color: task.isCompleted
                                ? theme.textMuted
                                : theme.textColor,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            decoration: task.isCompleted
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (task.isCompleted) ...[
                        const SizedBox(width: 6),
                        const Icon(
                          Icons.check_circle_rounded,
                          color: Color(0xFF4CAF50),
                          size: 16,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    task.description,
                    style: TextStyle(
                      color: theme.textMuted,
                      fontSize: 12,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      // Referans Görseldeki Gri "Read Details" Buton Formatı
                      InkWell(
                        onTap: () => _showTaskDetails(context, theme, task),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: theme.isDark
                                ? const Color(0xFF334155)
                                : const Color(0xFF94A3B8),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.info_outline_rounded,
                                size: 13,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Detayları Gör',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          Icon(
                            Icons.access_time_rounded,
                            size: 13,
                            color: theme.textMuted,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            task.timeLabel,
                            style: TextStyle(
                              color: theme.textMuted,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 6),
                          InkWell(
                            onTap: () => _showAddTaskDialog(context, theme, existing: task),
                            borderRadius: BorderRadius.circular(6),
                            child: const Padding(
                              padding: EdgeInsets.all(4.0),
                              child: Icon(
                                Icons.edit_outlined,
                                size: 16,
                                color: Colors.blueGrey,
                              ),
                            ),
                          ),
                          InkWell(
                            onTap: () {
                              localNotificationService.cancel(task.notificationId);
                              setState(() {
                                _tasks.removeWhere((t) => t.id == task.id);
                              });
                              _persistTasks();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('"${task.title}" silindi.'),
                                  backgroundColor: theme.error,
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            },
                            borderRadius: BorderRadius.circular(6),
                            child: const Padding(
                              padding: EdgeInsets.all(4.0),
                              child: Icon(
                                Icons.delete_outline_rounded,
                                size: 16,
                                color: Colors.redAccent,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Görev detayını alt sayfada gösterir; "Görevi Tamamla" ile işaretler.
  void _showTaskDetails(BuildContext context, AppTheme theme, TaskItem task) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        decoration: BoxDecoration(
          color: theme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(color: theme.primary.withValues(alpha: 0.3)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Tutamaç çubuğu
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.textMuted.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: task.accentColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: task.accentColor.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Icon(task.icon, color: task.accentColor, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task.title,
                          style: TextStyle(
                            color: theme.textColor,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: task.isCompleted
                                ? const Color(0xFF4CAF50).withValues(alpha: 0.2)
                                : theme.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                task.isCompleted
                                    ? Icons.check_circle_rounded
                                    : Icons.schedule_rounded,
                                size: 14,
                                color: task.isCompleted
                                    ? const Color(0xFF4CAF50)
                                    : theme.primary,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                task.isCompleted ? 'Tamamlandı' : 'Aktif',
                                style: TextStyle(
                                  color: task.isCompleted
                                      ? const Color(0xFF4CAF50)
                                      : theme.primary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(ctx),
                    child: Icon(
                      Icons.close_rounded,
                      color: theme.textMuted,
                      size: 22,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                'Açıklama',
                style: TextStyle(
                  color: theme.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                task.description,
                style: TextStyle(
                  color: theme.textColor.withValues(alpha: 0.9),
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(
                    Icons.access_time_rounded,
                    size: 15,
                    color: theme.textMuted,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    task.timeLabel,
                    style: TextStyle(
                      color: theme.textMuted,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      task.isCompleted = !task.isCompleted;
                    });
                    if (task.isCompleted) {
                      localNotificationService.cancel(task.notificationId);
                    } else {
                      localNotificationService.scheduleAt(
                        id: task.notificationId,
                        title: task.title,
                        body: task.description,
                        dateTime: task.reminderAt,
                      );
                    }
                    _persistTasks();
                    Navigator.pop(ctx);
                    final themeNow = themeNotifier.value;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          task.isCompleted
                              ? '"${task.title}" tamamlandı! ✅'
                              : '"${task.title}" aktif duruma alındı.',
                        ),
                        backgroundColor: task.isCompleted
                            ? const Color(0xFF4CAF50)
                            : themeNow.secondary,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                  icon: Icon(
                    task.isCompleted
                        ? Icons.undo_rounded
                        : Icons.check_circle_rounded,
                    size: 18,
                  ),
                  label: Text(
                    task.isCompleted ? 'Aktife Al' : 'Görevi Tamamla',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: task.isCompleted
                        ? theme.textMuted
                        : const Color(0xFF4CAF50),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Yeni hatırlatıcı ekler veya [existing] verilirse düzenler.
  /// Tarih ve saat seçimi zorunludur; geçmiş bir zaman seçilemez. Kaydedilen
  /// hatırlatıcı, seçilen tarih/saatte tetiklenecek şekilde
  /// [localNotificationService] ile zamanlanır (uygulama kapalıyken de çalışır).
  void _showAddTaskDialog(BuildContext context, AppTheme theme, {TaskItem? existing}) {
    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    final descCtrl = TextEditingController(text: existing?.description ?? '');
    DateTime? pickedDate = existing != null
        ? DateTime(existing.reminderAt.year, existing.reminderAt.month, existing.reminderAt.day)
        : null;
    TimeOfDay? pickedTime = existing != null
        ? TimeOfDay(hour: existing.reminderAt.hour, minute: existing.reminderAt.minute)
        : null;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          void pickError(String msg) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(msg), backgroundColor: theme.error),
            );
          }

          return AlertDialog(
            backgroundColor: theme.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(
              existing == null ? 'Yeni Görev / Hatırlatıcı ⏰' : 'Hatırlatıcıyı Düzenle ⏰',
              style: TextStyle(
                color: theme.textColor,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleCtrl,
                    style: TextStyle(color: theme.textColor),
                    decoration: InputDecoration(
                      labelText: 'Görev Başlığı *',
                      labelStyle: TextStyle(color: theme.textMuted),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descCtrl,
                    style: TextStyle(color: theme.textColor),
                    decoration: InputDecoration(
                      labelText: 'Açıklama veya Detay',
                      labelStyle: TextStyle(color: theme.textMuted),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final now = DateTime.now();
                            final res = await showDatePicker(
                              context: ctx,
                              initialDate: pickedDate ?? now,
                              firstDate: now,
                              lastDate: now.add(const Duration(days: 730)),
                            );
                            if (res != null) setDialogState(() => pickedDate = res);
                          },
                          icon: Icon(Icons.calendar_today_rounded, size: 15, color: theme.primary),
                          label: Text(
                            pickedDate == null
                                ? 'Tarih *'
                                : '${pickedDate!.day}.${pickedDate!.month}.${pickedDate!.year}',
                            style: TextStyle(color: theme.textColor, fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: theme.primary.withValues(alpha: 0.4)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final res = await showTimePicker(
                              context: ctx,
                              initialTime: pickedTime ?? TimeOfDay.now(),
                            );
                            if (res != null) setDialogState(() => pickedTime = res);
                          },
                          icon: Icon(Icons.access_time_rounded, size: 15, color: theme.primary),
                          label: Text(
                            pickedTime == null ? 'Saat *' : pickedTime!.format(ctx),
                            style: TextStyle(color: theme.textColor, fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: theme.primary.withValues(alpha: 0.4)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('İptal', style: TextStyle(color: theme.textMuted)),
              ),
              ElevatedButton(
                onPressed: () {
                  final title = titleCtrl.text.trim();
                  if (title.isEmpty) {
                    pickError('Görev başlığı zorunludur.');
                    return;
                  }
                  if (pickedDate == null || pickedTime == null) {
                    pickError('Tarih ve saat seçimi zorunludur.');
                    return;
                  }
                  final combined = DateTime(
                    pickedDate!.year,
                    pickedDate!.month,
                    pickedDate!.day,
                    pickedTime!.hour,
                    pickedTime!.minute,
                  );
                  if (combined.isBefore(DateTime.now())) {
                    pickError('Geçmiş bir tarih/saat seçemezsiniz.');
                    return;
                  }

                  final task = TaskItem(
                    id: existing?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
                    title: title,
                    description: descCtrl.text.trim().isEmpty
                        ? 'Detay belirtilmedi.'
                        : descCtrl.text.trim(),
                    reminderAt: combined,
                    icon: existing?.icon ?? Icons.event_note_rounded,
                    accentColor: existing?.accentColor ?? theme.primary,
                    isCompleted: existing?.isCompleted ?? false,
                  );

                  setState(() {
                    if (existing != null) {
                      final idx = _tasks.indexWhere((t) => t.id == existing.id);
                      if (idx != -1) {
                        _tasks[idx] = task;
                      } else {
                        _tasks.insert(0, task);
                      }
                    } else {
                      _tasks.insert(0, task);
                    }
                  });
                  _persistTasks();
                  localNotificationService.scheduleAt(
                    id: task.notificationId,
                    title: task.title,
                    body: task.description,
                    dateTime: task.reminderAt,
                  );
                  Navigator.pop(ctx);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.primary,
                  foregroundColor: Colors.white,
                ),
                child: Text(existing == null ? 'Ekle' : 'Kaydet'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  String _dateKey(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  Future<void> _loadNotes() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null) return;
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final loaded = <DateTime, Map<String, String>>{};
      for (final entry in decoded.entries) {
        final parts = entry.key.split('-');
        final dt = DateTime(
          int.parse(parts[0]),
          int.parse(parts[1]),
          int.parse(parts[2]),
        );
        loaded[dt] = Map<String, String>.from(entry.value as Map);
      }
      if (mounted) {
        setState(() {
          _notes.addAll(loaded);
          _loadNoteForCurrentSelection();
        });
      }
    } catch (e) {
      debugPrint('[Calendar] Notes parse error: $e');
    }
  }

  Future<void> _persistNotes() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(
      Map.fromEntries(
        _notes.entries.map((e) => MapEntry(_dateKey(e.key), e.value)),
      ),
    );
    await prefs.setString(_prefsKey, encoded);
  }

  /// Görevleri cihazdan yükler; ilk çalıştırmada varsayılanları kaydeder.
  Future<void> _loadTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsTasksKey);
    if (raw == null) {
      await _persistTasks();
      return;
    }
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      final tasks = decoded
          .map((e) => TaskItem.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      if (mounted) {
        setState(() => _tasks..clear()..addAll(tasks));
      }
    } catch (e) {
      debugPrint('[Calendar] Tasks parse error: $e');
    }
  }

  /// Görevleri cihaza kaydeder — her mutasyondan sonra çağrılır.
  Future<void> _persistTasks() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _prefsTasksKey,
      jsonEncode(_tasks.map((t) => t.toJson()).toList()),
    );
  }

  void _onCategorySelected(String category) {
    setState(() {
      _selectedCategory = category;
      _loadNoteForCurrentSelection();
    });
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    setState(() {
      _selectedDay = selectedDay;
      _focusedDay = focusedDay;
      _loadNoteForCurrentSelection();
    });
  }

  void _loadNoteForCurrentSelection() {
    if (_selectedDay != null && _notes[_selectedDay!] != null) {
      _noteController.text = _notes[_selectedDay!]![_selectedCategory] ?? '';
    } else {
      _noteController.text = '';
    }
  }

  String _todayLabel() {
    final now = DateTime.now();
    const months = [
      'Oca',
      'Şub',
      'Mar',
      'Nis',
      'May',
      'Haz',
      'Tem',
      'Ağu',
      'Eyl',
      'Eki',
      'Kas',
      'Ara',
    ];
    return '${now.day} ${months[now.month - 1]}';
  }

  void _saveNote() {
    if (_selectedDay == null) return;
    _notes.putIfAbsent(_selectedDay!, () => {});
    _notes[_selectedDay!]![_selectedCategory] = _noteController.text;
    _persistNotes();

    final theme = themeNotifier.value;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Not başarıyla kaydedildi! 📌'),
        backgroundColor: theme.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  void _deleteNote() {
    if (_selectedDay == null) return;
    final hasNote =
        _notes[_selectedDay!]?[_selectedCategory]?.isNotEmpty == true;
    if (!hasNote) return;

    final theme = themeNotifier.value;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Notu Sil',
          style: TextStyle(color: theme.error, fontWeight: FontWeight.bold),
        ),
        content: Text(
          '"$_selectedCategory" kategorisindeki notu silmek istiyor musun?',
          style: TextStyle(color: theme.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('İptal', style: TextStyle(color: theme.textMuted)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _notes[_selectedDay!]?.remove(_selectedCategory);
                if (_notes[_selectedDay!]?.isEmpty == true) {
                  _notes.remove(_selectedDay!);
                }
                _noteController.clear();
              });
              _persistNotes();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Not silindi.'),
                  backgroundColor: theme.error,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppTheme>(
      valueListenable: themeNotifier,
      builder: (context, theme, _) {
        return AnimatedThemeBackground(
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: theme.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: theme.primary.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Icon(
                          Icons.edit_calendar_rounded,
                          color: theme.primary,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Planlayıcım',
                            style: TextStyle(
                              color: theme.textMuted,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Notlar & Takvim',
                            style: TextStyle(
                              color: theme.textColor,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      InkWell(
                        onTap: () =>
                            setState(() => _isCollapsed = !_isCollapsed),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: theme.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: theme.primary.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _isCollapsed
                                    ? Icons.unfold_more_rounded
                                    : Icons.unfold_less_rounded,
                                color: theme.primary,
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _isCollapsed ? 'Genişlet' : 'Küçült',
                                style: TextStyle(
                                  color: theme.primary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: theme.secondary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: theme.secondary.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          _todayLabel(),
                          style: TextStyle(
                            color: theme.secondary,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Column(
                        children: [
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            child: _isCollapsed
                                ? KeyedSubtree(
                                    key: const ValueKey('collapsed_calendar'),
                                    child: _buildCollapsedWeekBar(theme),
                                  )
                                : KeyedSubtree(
                                    key: const ValueKey('full_calendar'),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: theme.surface
                                            .withValues(alpha: 0.55),
                                        borderRadius:
                                            BorderRadius.circular(24),
                                        border: Border.all(
                                          color: theme.primary
                                              .withValues(alpha: 0.3),
                                          width: 1.5,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: theme.primary
                                                .withValues(alpha: 0.08),
                                            blurRadius: 20,
                                            spreadRadius: 0,
                                          ),
                                        ],
                                      ),
                                      child: ClipRRect(
                                        borderRadius:
                                            BorderRadius.circular(24),
                                        child: TableCalendar(
                                          firstDay: DateTime.utc(2020, 1, 1),
                                          lastDay: DateTime.utc(2030, 12, 31),
                                          focusedDay: _focusedDay,
                                          selectedDayPredicate: (day) =>
                                              isSameDay(_selectedDay, day),
                                          onDaySelected: _onDaySelected,
                                          headerStyle: HeaderStyle(
                                            formatButtonVisible: false,
                                            titleTextStyle: TextStyle(
                                              color: theme.textColor,
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                            ),
                                            leftChevronIcon: Icon(
                                              Icons.chevron_left,
                                              color: theme.primary,
                                            ),
                                            rightChevronIcon: Icon(
                                              Icons.chevron_right,
                                              color: theme.primary,
                                            ),
                                          ),
                                          daysOfWeekStyle: DaysOfWeekStyle(
                                            weekdayStyle: TextStyle(
                                              color: theme.textMuted,
                                            ),
                                            weekendStyle: TextStyle(
                                              color: theme.error,
                                            ),
                                          ),
                                          calendarStyle: CalendarStyle(
                                            defaultTextStyle: TextStyle(
                                              color: theme.textColor,
                                            ),
                                            weekendTextStyle: TextStyle(
                                              color: theme.error,
                                            ),
                                            outsideTextStyle: TextStyle(
                                              color: theme.textMuted
                                                  .withValues(alpha: 0.6),
                                            ),
                                            selectedDecoration: BoxDecoration(
                                              color: theme.primary,
                                              shape: BoxShape.circle,
                                            ),
                                            todayDecoration: BoxDecoration(
                                              color: theme.secondary
                                                  .withValues(alpha: 0.5),
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                          ),

                          const SizedBox(height: 20),

                          // Görevler & Hatırlatıcılar Başlığı
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.alarm_on_rounded,
                                    color: theme.primary,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Görevler & Hatırlatıcılar',
                                    style: TextStyle(
                                      color: theme.textColor,
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  if (_tasks.any((t) => t.isCompleted))
                                    TextButton.icon(
                                      onPressed: () {
                                        setState(() {
                                          _tasks.removeWhere((t) => t.isCompleted);
                                        });
                                        _persistTasks();
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: const Text('Tamamlanan tüm görevler temizlendi! 🧹'),
                                            backgroundColor: theme.primary,
                                            duration: const Duration(seconds: 2),
                                          ),
                                        );
                                      },
                                      icon: const Icon(
                                        Icons.cleaning_services_rounded,
                                        size: 15,
                                        color: Colors.redAccent,
                                      ),
                                      label: const Text(
                                        'Tamamlananları Sil',
                                        style: TextStyle(
                                          color: Colors.redAccent,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  TextButton.icon(
                                    onPressed: () => _showAddTaskDialog(context, theme),
                                    icon: Icon(
                                      Icons.add_rounded,
                                      size: 16,
                                      color: theme.primary,
                                    ),
                                    label: Text(
                                      'Yeni Ekle',
                                      style: TextStyle(
                                        color: theme.primary,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),

                          const SizedBox(height: 10),

                          // Görev Kartları Listesi (Görsel Formatı)
                          ..._tasks.map((task) => _buildTaskCard(context, theme, task)),

                          const SizedBox(height: 24),

                          // Notlar Kategorileri ve Metin Kutusu Başlığı
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Notlar & Günlük',
                              style: TextStyle(
                                color: theme.textColor,
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),

                          const SizedBox(height: 12),

                          SizedBox(
                            height: 40,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: _categories.length,
                              itemBuilder: (context, index) {
                                final category = _categories[index];
                                return CategoryButton(
                                  title: category,
                                  isSelected: _selectedCategory == category,
                                  onTap: () => _onCategorySelected(category),
                                );
                              },
                            ),
                          ),

                          const SizedBox(height: 16),

                          Container(
                            decoration: BoxDecoration(
                              color: theme.surface.withValues(alpha: 0.65),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: theme.primary.withValues(alpha: 0.3),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: theme.primary.withValues(alpha: 0.06),
                                  blurRadius: 16,
                                  spreadRadius: 0,
                                ),
                              ],
                            ),
                            child: TextField(
                                  controller: _noteController,
                                  maxLines: 6,
                                  style: TextStyle(
                                    color: theme.textColor,
                                    fontSize: 15,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: 'Düşüncelerini buraya yaz...',
                                    hintStyle: TextStyle(
                                      color: theme.textMuted.withValues(
                                        alpha: 0.7,
                                      ),
                                    ),
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.all(16),
                                  ),
                                ),
                            ),

                          const SizedBox(height: 16),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Builder(
                                builder: (ctx) {
                                  final hasNote =
                                      _notes[_selectedDay]?[_selectedCategory]
                                          ?.isNotEmpty ==
                                      true;
                                  return hasNote
                                      ? IconButton(
                                          onPressed: _deleteNote,
                                          icon: Icon(
                                            Icons.delete_outline,
                                            color: theme.error,
                                          ),
                                          tooltip: 'Notu sil',
                                        )
                                      : const SizedBox.shrink();
                                },
                              ),
                              ElevatedButton.icon(
                                onPressed: _saveNote,
                                icon: const Icon(
                                  Icons.bookmark_add_rounded,
                                  size: 18,
                                ),
                                label: const Text(
                                  'Kaydet',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: theme.primary,
                                  foregroundColor: theme.background,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
