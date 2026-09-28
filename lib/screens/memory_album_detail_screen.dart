import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../models/memory_gallery_model.dart';
import '../services/local_storage_service.dart';
import '../utils/file_validator.dart';
import '../theme/app_theme.dart';

class MemoryAlbumDetailScreen extends StatefulWidget {
  final MemoryAlbum album;

  const MemoryAlbumDetailScreen({super.key, required this.album});

  @override
  State<MemoryAlbumDetailScreen> createState() => _MemoryAlbumDetailScreenState();
}

class _MemoryAlbumDetailScreenState extends State<MemoryAlbumDetailScreen> {
  final _storage = LocalStorageService.instance;
  late MemoryAlbum _album;
  final _picker = ImagePicker();
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _album = widget.album;
  }

  Future<void> _pickAndSaveImage(ImageSource source) async {
    final storage = _storage;
    if (storage == null) return;

    setState(() => _loading = true);
    try {
      final picked = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1920,
        maxHeight: 1920,
      );

      if (picked == null) {
        setState(() => _loading = false);
        return;
      }

      final validation = await FileValidator.validateXFile(picked);
      if (!validation.isValid) {
        setState(() => _loading = false);
        _showSnack(validation.errorMessage!, isError: true);
        return;
      }

      // Copy to app documents directory
      final appDir = await getApplicationDocumentsDirectory();
      final photosDir = Directory('${appDir.path}/memory_gallery/${_album.id}');
      if (!await photosDir.exists()) {
        await photosDir.create(recursive: true);
      }

      final fileName = 'img_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final savedFile = await File(picked.path).copy('${photosDir.path}/$fileName');

      // Update album
      final success = await storage.addPhotoToAlbum(_album.id, savedFile.path);
      if (success) {
        _album = _album.addPhoto(savedFile.path);
        if (mounted) setState(() {});
        _showSnack('Fotoğraf eklendi! 📸', isError: false);
      } else {
        _showSnack('Fotoğraf eklenemedi', isError: true);
      }
    } catch (e) {
      debugPrint('[MemoryAlbumDetail] Error adding photo: $e');
      _showSnack('Hata: $e', isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _deletePhoto(String photoPath) async {
    final theme = themeNotifier.value;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Fotoğrafı Sil', style: TextStyle(color: theme.error, fontWeight: FontWeight.bold)),
        content: Text('Bu fotoğraf albümden silinecek. Devam etmek istiyor musunuz?', style: TextStyle(color: theme.textMuted)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('İptal', style: TextStyle(color: theme.textMuted))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), style: TextButton.styleFrom(foregroundColor: theme.error), child: const Text('Sil', style: TextStyle(fontWeight: FontWeight.bold))),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _loading = true);
    try {
      final success = await _storage?.removePhotoFromAlbum(_album.id, photoPath) ?? false;
      if (success) {
        _album = _album.removePhoto(photoPath);
        // Also delete the physical file
        final file = File(photoPath);
        if (await file.exists()) {
          await file.delete();
        }
        if (mounted) setState(() {});
        _showSnack('Fotoğraf silindi', isError: false);
      } else {
        _showSnack('Fotoğraf silinemedi', isError: true);
      }
    } catch (e) {
      debugPrint('[MemoryAlbumDetail] Error deleting photo: $e');
      _showSnack('Hata: $e', isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showSnack(String msg, {required bool isError}) {
    final theme = themeNotifier.value;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w500)),
        backgroundColor: isError ? theme.error : theme.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  Future<void> _showImageFullscreen(String imagePath, int index) async {
    final theme = themeNotifier.value;
    final file = File(imagePath);
    if (!await file.exists()) {
      _showSnack('Fotoğraf bulunamadı', isError: true);
      return;
    }

    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            GestureDetector(
              onTap: () => Navigator.pop(ctx),
              child: Container(
                color: Colors.black.withValues(alpha: 0.95),
                width: double.infinity,
                height: double.infinity,
                child: InteractiveViewer(
                  panEnabled: true,
                  minScale: 0.5,
                  maxScale: 4,
                  child: Center(
                    child: Image.file(file, fit: BoxFit.contain, errorBuilder: (ctx, err, stack) => Icon(Icons.broken_image, color: theme.textMuted, size: 64)),
                  ),
                ),
              ),
            ),
            Positioned(
              top: MediaQuery.of(ctx).padding.top + 16,
              right: 16,
              child: IconButton(
                onPressed: () => Navigator.pop(ctx),
                icon: Icon(Icons.close, color: Colors.white, size: 28),
                tooltip: 'Kapat',
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black.withValues(alpha: 0.5),
                  padding: const EdgeInsets.all(12),
                ),
              ),
            ),
            if (index > 0)
              Positioned(
                left: 16,
                top: 0,
                bottom: 0,
                child: Center(
                  child: IconButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _showImageFullscreen(_album.photoPaths[index - 1], index - 1);
                    },
                    tooltip: 'Önceki Fotoğraf',
                    icon: Icon(Icons.chevron_left, color: Colors.white, size: 40),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black.withValues(alpha: 0.5),
                      padding: const EdgeInsets.all(16),
                    ),
                  ),
                ),
              ),
            if (index < _album.photoPaths.length - 1)
              Positioned(
                right: 16,
                top: 0,
                bottom: 0,
                child: Center(
                  child: IconButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _showImageFullscreen(_album.photoPaths[index + 1], index + 1);
                    },
                    tooltip: 'Sonraki Fotoğraf',
                    icon: Icon(Icons.chevron_right, color: Colors.white, size: 40),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black.withValues(alpha: 0.5),
                      padding: const EdgeInsets.all(16),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
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
          onPressed: () => Navigator.pop(context, true),
          tooltip: 'Geri',
        ),
        title: Text(
          _album.name,
          style: TextStyle(color: theme.textColor, fontWeight: FontWeight.bold),
        ),
        actions: [
          if (_album.photoCount > 0)
            IconButton(
              icon: Icon(Icons.delete_sweep_outlined, color: theme.error),
              onPressed: _album.isEmpty ? null : _clearAlbum,
              tooltip: 'Tümünü Temizle',
            ),
        ],
      ),
      body: _buildBody(theme),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _loading ? null : () => _showImageSourceDialog(),
        backgroundColor: _loading ? theme.textMuted : theme.primary,
        foregroundColor: Colors.white,
        icon: _loading
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : const Icon(Icons.add_a_photo_outlined),
        label: _loading ? const Text('Yükleniyor...') : const Text('Fotoğraf Ekle'),
      ),
    );
  }

  Widget _buildBody(AppTheme theme) {
    if (_album.isEmpty) {
      return _buildEmptyState(theme);
    }

    return RefreshIndicator(
      onRefresh: _refreshAlbum,
      color: theme.primary,
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: _album.photoPaths.length,
        itemBuilder: (context, index) {
          final photoPath = _album.photoPaths[index];
          return _buildPhotoTile(photoPath, index, theme);
        },
      ),
    );
  }

  Future<void> _refreshAlbum() async {
    final updated = await _storage?.getMemoryAlbums() ?? [];
    final found = updated.where((a) => a.id == _album.id).firstOrNull;
    if (found != null && mounted) {
      setState(() => _album = found);
    }
  }

  Widget _buildEmptyState(AppTheme theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_photo_alternate_outlined, size: 80, color: theme.textMuted.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text('Bu albümde henüz fotoğraf yok', style: TextStyle(color: theme.textMuted, fontSize: 16, fontWeight: FontWeight.w500), textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text('Fotoğraf eklemek için aşağıdaki butonu kullanın.', style: TextStyle(color: theme.textMuted, fontSize: 13), textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _showImageSourceDialog,
              icon: const Icon(Icons.add_a_photo_outlined),
              label: const Text('İlk Fotoğrafı Ekle'),
              style: ElevatedButton.styleFrom(backgroundColor: theme.primary, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoTile(String photoPath, int index, AppTheme theme) {
    final file = File(photoPath);
    return GestureDetector(
      onTap: () => _showImageFullscreen(photoPath, index),
      onLongPress: () => _showPhotoOptions(photoPath, index, theme),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.primary.withValues(alpha: 0.1)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            fit: StackFit.expand,
            children: [
              file.existsSync()
                  ? Image.file(file, fit: BoxFit.cover, errorBuilder: (ctx, err, stack) => _buildErrorPlaceholder(theme))
                  : _buildErrorPlaceholder(theme),
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.6), shape: BoxShape.circle),
                  child: IconButton(
                    icon: Icon(Icons.delete_outline, color: Colors.white, size: 18),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    onPressed: () => _deletePhoto(photoPath),
                    tooltip: 'Sil',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorPlaceholder(AppTheme theme) {
    return Container(
      color: theme.surface.withValues(alpha: 0.5),
      child: Center(child: Icon(Icons.broken_image_outlined, color: theme.textMuted, size: 32)),
    );
  }

  void _showPhotoOptions(String photoPath, int index, AppTheme theme) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(color: theme.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 20), decoration: BoxDecoration(color: theme.textMuted.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2))),
            Text('Fotoğraf #${index + 1}', style: TextStyle(color: theme.textColor, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            _buildOptionTile(icon: Icons.delete_outline, label: 'Fotoğrafı Sil', color: theme.error, onTap: () { Navigator.pop(ctx); _deletePhoto(photoPath); }),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionTile({required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    final theme = themeNotifier.value;
    return ListTile(
      leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withValues(alpha: 0.2), shape: BoxShape.circle), child: Icon(icon, color: color, size: 22)),
      title: Text(label, style: TextStyle(color: theme.textColor, fontWeight: FontWeight.w600, fontSize: 16)),
      onTap: onTap,
    );
  }

  void _showImageSourceDialog() {
    final theme = themeNotifier.value;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(color: theme.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 20), decoration: BoxDecoration(color: theme.textMuted.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2))),
            Text('Fotoğraf Ekle', style: TextStyle(color: theme.textColor, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            _buildOptionTile(
              icon: Icons.camera_alt_outlined,
              label: 'Kameradan Çek',
              color: theme.primary,
              onTap: () { Navigator.pop(ctx); _pickAndSaveImage(ImageSource.camera); },
            ),
            _buildOptionTile(
              icon: Icons.photo_library_outlined,
              label: 'Galeriden Seç',
              color: theme.secondary,
              onTap: () { Navigator.pop(ctx); _pickAndSaveImage(ImageSource.gallery); },
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Future<void> _clearAlbum() async {
    final storage = _storage;
    if (storage == null) return;

    final theme = themeNotifier.value;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Albümü Temizle', style: TextStyle(color: theme.error, fontWeight: FontWeight.bold)),
        content: Text('"${_album.name}" albümündeki TÜM fotoğraflar silinecek. Bu işlem geri alınamaz.', style: TextStyle(color: theme.textMuted)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('İptal', style: TextStyle(color: theme.textMuted))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), style: TextButton.styleFrom(foregroundColor: theme.error), child: const Text('Tümünü Sil', style: TextStyle(fontWeight: FontWeight.bold))),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _loading = true);
    try {
      // Delete all photo files
      for (final path in _album.photoPaths) {
        final file = File(path);
        if (await file.exists()) {
          await file.delete();
        }
      }
      // Clear album in storage
      _album = _album.copyWith(photoPaths: [], coverPhotoPath: null, updatedAt: DateTime.now());
      await storage.saveMemoryAlbums((await storage.getMemoryAlbums()).map((a) => a.id == _album.id ? _album : a).toList());
      if (mounted) setState(() {});
      _showSnack('Albüm temizlendi', isError: false);
    } catch (e) {
      debugPrint('[MemoryAlbumDetail] Error clearing album: $e');
      _showSnack('Hata: $e', isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}