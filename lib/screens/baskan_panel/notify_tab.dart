import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Başkan Paneli — "Üyelere Bildirim Gönder" sekmesi.
/// bkz. `members_tab.dart` başındaki not — aynı çıkarma deseni.
///
/// `selectedRecipientIds`, üst ekranda (`_BaskanPanelScreenState`) yaşayan
/// mutable bir `Set<String>` referansı olarak geliyor — bu widget onu
/// doğrudan değiştirmiyor, seçim değiştiğinde `onToggleRecipient`/
/// `onToggleSelectAll` üst ekrana haber veriyor (o da kendi `setState`'ini
/// çağırıp Set'i güncelliyor). Böylece state sahipliği hiç değişmedi.
class NotifyTab extends StatelessWidget {
  final AppTheme theme;
  final bool loadingMembers;
  final List<Map<String, dynamic>> members;
  final String? selectedCommunityName;
  final Set<String> selectedRecipientIds;
  final void Function(String userId, bool selected) onToggleRecipient;
  final VoidCallback onToggleSelectAll;
  final TextEditingController titleController;
  final TextEditingController bodyController;
  final bool sending;
  final VoidCallback onSend;

  const NotifyTab({
    super.key,
    required this.theme,
    required this.loadingMembers,
    required this.members,
    required this.selectedCommunityName,
    required this.selectedRecipientIds,
    required this.onToggleRecipient,
    required this.onToggleSelectAll,
    required this.titleController,
    required this.bodyController,
    required this.sending,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    if (loadingMembers) {
      return Center(child: CircularProgressIndicator(color: theme.primary));
    }
    if (members.isEmpty) {
      return Center(
        child: Text(
          'Bu topluluğun henüz üyesi yok.',
          style: TextStyle(color: theme.textMuted),
        ),
      );
    }

    final allIds = members
        .map((m) {
          final profile = m['profiles'] as Map<String, dynamic>?;
          return profile?['id'] as String? ?? m['user_id'] as String?;
        })
        .whereType<String>()
        .toSet();
    final allSelected =
        allIds.isNotEmpty && selectedRecipientIds.length == allIds.length;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.primary.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: theme.primary, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Yalnızca "${selectedCommunityName ?? ''}" topluluğuna katılmış üyelere bildirim gönderebilirsin.',
                  style: TextStyle(color: theme.textColor, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Alıcılar (${selectedRecipientIds.length}/${allIds.length})',
              style: TextStyle(
                color: theme.primary,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            TextButton.icon(
              onPressed: onToggleSelectAll,
              icon: Icon(
                allSelected ? Icons.deselect : Icons.select_all,
                size: 16,
                color: theme.primary,
              ),
              label: Text(
                allSelected ? 'Seçimi Kaldır' : 'Tümünü Seç',
                style: TextStyle(color: theme.primary, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          constraints: const BoxConstraints(maxHeight: 280),
          decoration: BoxDecoration(
            color: theme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: theme.primary.withValues(alpha: 0.15)),
          ),
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 4),
            itemCount: members.length,
            separatorBuilder: (_, __) => Divider(
              height: 1,
              color: theme.primary.withValues(alpha: 0.08),
            ),
            itemBuilder: (ctx, index) {
              final item = members[index];
              final profile = item['profiles'] as Map<String, dynamic>? ?? {};
              final userId = profile['id'] as String? ?? item['user_id'] as String;
              final name = profile['name'] as String? ?? 'İsimsiz Üye';
              final email = profile['email'] as String? ?? '';
              final selected = selectedRecipientIds.contains(userId);
              return CheckboxListTile(
                dense: true,
                value: selected,
                activeColor: theme.primary,
                onChanged: (v) => onToggleRecipient(userId, v == true),
                title: Text(
                  name,
                  style: TextStyle(color: theme.textColor, fontSize: 13, fontWeight: FontWeight.w600),
                ),
                subtitle: email.isNotEmpty
                    ? Text(email, style: TextStyle(color: theme.textMuted, fontSize: 11))
                    : null,
              );
            },
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Bildirim İçeriği',
          style: TextStyle(color: theme.primary, fontWeight: FontWeight.bold, fontSize: 14),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: titleController,
          style: TextStyle(color: theme.textColor),
          maxLength: 80,
          decoration: InputDecoration(
            labelText: 'Bildirim Başlığı *',
            filled: true,
            fillColor: theme.surface,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        TextField(
          controller: bodyController,
          style: TextStyle(color: theme.textColor),
          maxLines: 4,
          maxLength: 500,
          decoration: InputDecoration(
            labelText: 'Mesaj *',
            filled: true,
            fillColor: theme.surface,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: sending ? null : onSend,
            icon: sending
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : const Icon(Icons.send_rounded, color: Colors.white),
            label: Text(
              sending ? 'Gönderiliyor...' : 'Bildirimi Gönder',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}
