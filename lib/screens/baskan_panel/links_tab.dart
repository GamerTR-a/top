import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Başkan Paneli — "Sosyal Bağlantılar ve Ayarlar" sekmesi.
/// bkz. `members_tab.dart` başındaki not — aynı çıkarma deseni.
class LinksTab extends StatelessWidget {
  final AppTheme theme;
  final TextEditingController whatsappController;
  final TextEditingController telegramController;
  final TextEditingController instagramController;
  final bool saving;
  final VoidCallback onSave;

  const LinksTab({
    super.key,
    required this.theme,
    required this.whatsappController,
    required this.telegramController,
    required this.instagramController,
    required this.saving,
    required this.onSave,
  });

  Widget _buildLinkField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required String hint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: theme.textColor, fontWeight: FontWeight.bold, fontSize: 13),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          style: TextStyle(color: theme.textColor, fontSize: 13),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: theme.textMuted, fontSize: 13),
            prefixIcon: Icon(icon, color: theme.primary, size: 20),
            filled: true,
            fillColor: theme.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: theme.primary.withValues(alpha: 0.2)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: theme.primary.withValues(alpha: 0.2)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: theme.primary),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Topluluk İletişim Bağlantıları',
            style: TextStyle(
              color: theme.primary,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Üyelerinize sunulacak sosyal medya ve iletişim gruplarının linklerini güncelleyin.',
            style: TextStyle(color: theme.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 20),
          _buildLinkField(
            controller: whatsappController,
            label: 'WhatsApp Grubu Linki',
            icon: Icons.chat_bubble_outline,
            hint: 'https://chat.whatsapp.com/...',
          ),
          const SizedBox(height: 14),
          _buildLinkField(
            controller: telegramController,
            label: 'Telegram Grubu Linki',
            icon: Icons.send_outlined,
            hint: 'https://t.me/...',
          ),
          const SizedBox(height: 14),
          _buildLinkField(
            controller: instagramController,
            label: 'Instagram Sayfası Linki',
            icon: Icons.camera_alt_outlined,
            hint: 'https://instagram.com/...',
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: saving ? null : onSave,
              icon: saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.save, color: Colors.white),
              label: const Text(
                'Bağlantıları Kaydet',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
