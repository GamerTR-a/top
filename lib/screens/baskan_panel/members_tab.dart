import 'package:flutter/material.dart';
import '../../models/auth_user_model.dart' show departmentText;
import '../../theme/app_theme.dart';
import '../../utils/turkish_text.dart';
import '../../widgets/app_network_image.dart';

/// Başkan Paneli — "Üyeler" sekmesi.
///
/// `baskan_panel_screen.dart`'tan çıkarıldı (bkz. kontrol.md Bölüm 14.2 —
/// dosya ~1480 satırdı). Davranış birebir korunuyor: bu widget kendi state'ini
/// tutmuyor, tüm veri/aksiyonlar üst ekrandan (hâlâ orada yaşayan
/// `_BaskanPanelScreenState`) constructor parametreleriyle geliyor.
class MembersTab extends StatelessWidget {
  final AppTheme theme;
  final bool loading;
  final List<Map<String, dynamic>> members;
  final String searchQuery;
  final ValueChanged<String> onSearchChanged;
  final void Function(List<Map<String, dynamic>> filteredMembers) onCopyAllEmails;
  final void Function(String userId, String name) onRemoveMember;
  final void Function(String text, String label) onCopyToClipboard;

  const MembersTab({
    super.key,
    required this.theme,
    required this.loading,
    required this.members,
    required this.searchQuery,
    required this.onSearchChanged,
    required this.onCopyAllEmails,
    required this.onRemoveMember,
    required this.onCopyToClipboard,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Center(child: CircularProgressIndicator(color: theme.primary));
    }

    final query = turkishToLower(searchQuery.trim());
    final filtered = members.where((m) {
      final profile = m['profiles'] as Map<String, dynamic>?;
      if (profile == null) return false;
      final name = turkishToLower(profile['name'] as String? ?? '');
      final email = (profile['email'] as String? ?? '').toLowerCase();
      final dept = turkishToLower(departmentText(profile['department']) ?? '');
      return query.isEmpty ||
          name.contains(query) ||
          email.contains(query) ||
          dept.contains(query);
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Arama çubuğu ve Tüm Mailleri Kopyala Butonu
          Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: onSearchChanged,
                  style: TextStyle(color: theme.textColor, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Üye adı, e-posta veya bölüm ara...',
                    hintStyle: TextStyle(color: theme.textMuted, fontSize: 13),
                    prefixIcon: Icon(Icons.search, color: theme.primary, size: 20),
                    isDense: true,
                    filled: true,
                    fillColor: theme.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: theme.primary.withValues(alpha: 0.2)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: theme.primary.withValues(alpha: 0.2)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: () => onCopyAllEmails(filtered),
                icon: const Icon(Icons.copy, size: 16, color: Colors.white),
                label: const Text(
                  'Tüm Mailler',
                  style: TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Toplam Üye Sayacı
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Topluluk Üyeleri (${filtered.length} Kişi)',
                style: TextStyle(
                  color: theme.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              Text(
                'E-Postaları kopyalamak için tıklayın',
                style: TextStyle(color: theme.textMuted, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Üye Kartları Listesi
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Text(
                      'Üye bulunamadı.',
                      style: TextStyle(color: theme.textMuted),
                    ),
                  )
                : ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (ctx, index) {
                      final item = filtered[index];
                      final profile = item['profiles'] as Map<String, dynamic>? ?? {};
                      final userId = profile['id'] as String? ?? item['user_id'] as String;
                      final name = profile['name'] as String? ?? 'İsimsiz Üye';
                      final email = profile['email'] as String? ?? 'E-posta Yok';
                      final photo = profile['profile_photo'] as String?;
                      final dept = departmentText(profile['department']);
                      final role = profile['role'] as String? ?? 'student';
                      final joinedAtRaw = item['joined_at'] as String?;

                      String joinedDateStr = '';
                      if (joinedAtRaw != null) {
                        try {
                          final dt = DateTime.parse(joinedAtRaw);
                          joinedDateStr = '${dt.day}.${dt.month}.${dt.year}';
                        } catch (_) {}
                      }

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: theme.primary.withValues(alpha: 0.15),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 20,
                                  backgroundColor: theme.primary.withValues(alpha: 0.2),
                                  child: photo != null && photo.isNotEmpty
                                      ? ClipOval(
                                          child: AppNetworkImage(
                                            path: photo,
                                            fit: BoxFit.cover,
                                            fallback: () => Icon(
                                              Icons.person,
                                              color: theme.primary,
                                              size: 20,
                                            ),
                                          ),
                                        )
                                      : Icon(Icons.person, color: theme.primary, size: 20),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              name,
                                              style: TextStyle(
                                                color: theme.textColor,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          if (role == 'baskan' || role == 'admin')
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 6,
                                                vertical: 2,
                                              ),
                                              decoration: BoxDecoration(
                                                color: theme.secondary.withValues(alpha: 0.2),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                role == 'admin' ? 'Admin' : 'Başkan',
                                                style: TextStyle(
                                                  color: theme.secondary,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      if (dept != null && dept.isNotEmpty) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          dept,
                                          style: TextStyle(
                                            color: theme.textMuted,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(Icons.person_remove_outlined, color: theme.error, size: 20),
                                  tooltip: 'Üyeyi Çıkar',
                                  onPressed: () => onRemoveMember(userId, name),
                                ),
                              ],
                            ),
                            const Divider(height: 14),
                            // E-Posta Alanı (Vurgulu ve Kopyala Butonlu)
                            InkWell(
                              onTap: () => onCopyToClipboard(email, 'E-posta'),
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: theme.primary.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: theme.primary.withValues(alpha: 0.15),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.email_outlined, size: 16, color: theme.primary),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        email,
                                        style: TextStyle(
                                          color: theme.textColor,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    Icon(Icons.copy, size: 14, color: theme.primary),
                                  ],
                                ),
                              ),
                            ),
                            if (joinedDateStr.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Padding(
                                padding: const EdgeInsets.only(left: 4),
                                child: Text(
                                  'Katılım Tarihi: $joinedDateStr',
                                  style: TextStyle(color: theme.textMuted, fontSize: 10),
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
