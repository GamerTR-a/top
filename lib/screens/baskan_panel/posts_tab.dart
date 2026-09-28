import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_network_image.dart';

/// Başkan Paneli — "Gönderiler ve Moderasyon" sekmesi.
/// bkz. `members_tab.dart` başındaki not — aynı çıkarma deseni.
class PostsTab extends StatelessWidget {
  final AppTheme theme;
  final bool loading;
  final List<Map<String, dynamic>> posts;
  final void Function(int postId) onDeletePost;
  final void Function(int postId, String content) onShowEventParticipants;

  const PostsTab({
    super.key,
    required this.theme,
    required this.loading,
    required this.posts,
    required this.onDeletePost,
    required this.onShowEventParticipants,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Center(child: CircularProgressIndicator(color: theme.primary));
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Topluluk Akış Gönderileri (${posts.length})',
            style: TextStyle(
              color: theme.primary,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: posts.isEmpty
                ? Center(
                    child: Text(
                      'Bu topluluğa henüz gönderi paylaşılmamış.',
                      style: TextStyle(color: theme.textMuted),
                    ),
                  )
                : ListView.builder(
                    itemCount: posts.length,
                    itemBuilder: (ctx, index) {
                      final p = posts[index];
                      final postId = (p['id'] as num).toInt();
                      final content = p['content'] as String? ?? '';
                      final createdAt = p['created_at'] as String? ?? '';
                      final imageUrl = p['image_url'] as String?;
                      final isEvent = p['is_event'] as bool? ?? false;

                      return Card(
                        color: theme.surface,
                        margin: const EdgeInsets.only(bottom: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(color: theme.primary.withValues(alpha: 0.15)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (imageUrl != null && imageUrl.isNotEmpty) ...[
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: SizedBox(
                                        width: 50,
                                        height: 50,
                                        child: AppNetworkImage(
                                          path: imageUrl,
                                          fit: BoxFit.cover,
                                          fallback: () => Container(
                                            width: 50,
                                            height: 50,
                                            color: theme.primary.withValues(alpha: 0.1),
                                            child: Icon(Icons.image, color: theme.primary),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                  ],
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          content,
                                          maxLines: 3,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: theme.textColor,
                                            fontSize: 13,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          createdAt,
                                          style: TextStyle(
                                            color: theme.textMuted,
                                            fontSize: 10,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.delete_outline, color: theme.error, size: 20),
                                    onPressed: () => onDeletePost(postId),
                                    tooltip: 'Gönderiyi Sil',
                                  ),
                                ],
                              ),
                              if (isEvent) ...[
                                const Divider(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    onPressed: () => onShowEventParticipants(postId, content),
                                    icon: Icon(Icons.people_outline, color: theme.primary, size: 18),
                                    label: Text(
                                      'Etkinlik Katılımcıları & Mailleri 📋',
                                      style: TextStyle(color: theme.primary, fontSize: 12, fontWeight: FontWeight.bold),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      side: BorderSide(color: theme.primary.withValues(alpha: 0.4)),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
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
