import 'package:flutter/material.dart';
import 'dart:io';
import '../models/memory_gallery_model.dart';
import '../services/local_storage_service.dart';
import '../theme/app_theme.dart';
import 'memory_album_detail_screen.dart';
import 'memory_album_create_dialog.dart';

class MemoryGalleryScreen extends StatefulWidget {
  const MemoryGalleryScreen({super.key});

  @override
  State<MemoryGalleryScreen> createState() => _MemoryGalleryScreenState();
}

class _MemoryGalleryScreenState extends State<MemoryGalleryScreen> {
  final _storage = LocalStorageService.instance;
  List<MemoryAlbum> _albums = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadAlbums();
  }

  Future<void> _loadAlbums() async {
    setState(() => _loading = true);
    try {
      final albums = await _storage?.getMemoryAlbums() ?? [];
      if (mounted) {
        setState(() {
          _albums = albums;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _createAlbum() async {
    if (_storage == null) return;
    final result = await showDialog<MemoryAlbum>(
      context: context,
      builder: (_) => const MemoryAlbumCreateDialog(),
    );
    if (result != null && mounted) {
      _loadAlbums();
    }
  }

  Future<void> _deleteAlbum(MemoryAlbum album) async {
    final theme = themeNotifier.value;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Albümü Sil', style: TextStyle(color: theme.error, fontWeight: FontWeight.bold)),
        content: Text('"${album.name}" albümünü ve içindeki fotoğrafları silmek istediğinizden emin misiniz?', style: TextStyle(color: theme.textMuted)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('İptal', style: TextStyle(color: theme.textMuted))),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: theme.error),
            child: const Text('Sil', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _storage?.deleteAlbum(album.id);
      _loadAlbums();
    }
  }

  Future<void> _renameAlbum(MemoryAlbum album) async {
    final theme = themeNotifier.value;
    final ctrl = TextEditingController(text: album.name);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Albümü Yeniden Adlandır', style: TextStyle(color: theme.primary, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: ctrl,
          style: TextStyle(color: theme.textColor),
          decoration: InputDecoration(
            hintText: 'Yeni albüm adı',
            hintStyle: TextStyle(color: theme.textMuted),
            filled: true,
            fillColor: theme.surface.withValues(alpha: 0.5),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('İptal', style: TextStyle(color: theme.textMuted))),
          TextButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: Text('Kaydet', style: TextStyle(color: theme.primary, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (result != null && result.isNotEmpty && mounted) {
      await _storage?.renameAlbum(album.id, result);
      _loadAlbums();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = themeNotifier.value;

    return Scaffold(
      backgroundColor: theme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: theme.primary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Hatıra Galerisi 🔭',
          style: TextStyle(color: theme.textColor, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: theme.primary),
            onPressed: _loadAlbums,
          ),
        ],
      ),
      body: _buildBody(theme),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createAlbum,
        backgroundColor: theme.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_photo_alternate_outlined),
        label: const Text('Yeni Albüm'),
      ),
    );
  }

  Widget _buildBody(AppTheme theme) {
    if (_loading) {
      return Center(child: CircularProgressIndicator(color: theme.primary));
    }

    if (_albums.isEmpty) {
      return _buildEmptyState(theme);
    }

    return RefreshIndicator(
      onRefresh: _loadAlbums,
      color: theme.primary,
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.85,
        ),
        itemCount: _albums.length,
        itemBuilder: (context, index) {
          final album = _albums[index];
          return _buildAlbumCard(album, theme);
        },
      ),
    );
  }

  Widget _buildEmptyState(AppTheme theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.photo_library_outlined,
              size: 80,
              color: theme.textMuted.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'Henüz albüm oluşturulmamış',
              style: TextStyle(
                color: theme.textMuted,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Aşağıdaki butondan ilk albümünüzü oluşturun ve anılarınızı saklayın.',
              style: TextStyle(color: theme.textMuted, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _createAlbum,
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: const Text('İlk Albümü Oluştur'),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlbumCard(MemoryAlbum album, AppTheme theme) {
    return GestureDetector(
      onTap: () async {
        final updated = await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => MemoryAlbumDetailScreen(album: album)),
        );
        if (updated == true && mounted) {
          _loadAlbums();
        }
      },
      onLongPress: () => _showAlbumOptions(album, theme),
      child: Container(
        decoration: BoxDecoration(
          color: theme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.primary.withValues(alpha: 0.1)),
          boxShadow: [
            BoxShadow(
              color: theme.primary.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Cover photo or placeholder
            Expanded(
              flex: 3,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: _buildCoverImage(album, theme),
              ),
            ),
            // Album info
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      album.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${album.photoCount} fotoğraf',
                      style: TextStyle(color: theme.textMuted, fontSize: 12),
                    ),
                    const Spacer(),
                    Text(
                      _formatDate(album.updatedAt),
                      style: TextStyle(color: theme.textMuted, fontSize: 10),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCoverImage(MemoryAlbum album, AppTheme theme) {
    if (album.coverPhotoPath != null) {
      final file = File(album.coverPhotoPath!);
      if (file.existsSync()) {
        return Image.file(
          file,
          fit: BoxFit.cover,
          width: double.infinity,
          errorBuilder: (context, error, stackTrace) => _buildPlaceholder(theme),
        );
      }
    }
    return _buildPlaceholder(theme);
  }

  Widget _buildPlaceholder(AppTheme theme) {
    return Container(
      color: theme.surface.withValues(alpha: 0.5),
      child: Center(
        child: Icon(
          Icons.photo_library_outlined,
          size: 48,
          color: theme.textMuted.withValues(alpha: 0.5),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays > 0) return '${diff.inDays} gün önce';
    if (diff.inHours > 0) return '${diff.inHours} saat önce';
    if (diff.inMinutes > 0) return '${diff.inMinutes} dakika önce';
    return 'Az önce';
  }

  void _showAlbumOptions(MemoryAlbum album, AppTheme theme) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: theme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: theme.textMuted.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(album.name, style: TextStyle(color: theme.textColor, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            _buildOptionTile(
              icon: Icons.edit_outlined,
              label: 'Yeniden Adlandır',
              color: theme.primary,
              onTap: () {
                Navigator.pop(ctx);
                _renameAlbum(album);
              },
            ),
            _buildOptionTile(
              icon: Icons.delete_outline,
              label: 'Albümü Sil',
              color: theme.error,
              onTap: () {
                Navigator.pop(ctx);
                _deleteAlbum(album);
              },
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    final theme = themeNotifier.value;
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.2),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color, size: 22),
      ),
      title: Text(label, style: TextStyle(color: theme.textColor, fontWeight: FontWeight.w600, fontSize: 16)),
      onTap: onTap,
    );
  }
}