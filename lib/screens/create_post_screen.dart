import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/auth_user_model.dart';
import '../models/topluluk.dart';
import '../services/supabase_data_service.dart';
import '../utils/file_validator.dart';

import '../theme/app_theme.dart';

class CreatePostScreen extends StatefulWidget {
  final AuthUser? user;

  const CreatePostScreen({super.key, this.user});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _contentCtrl = TextEditingController();
  final _imageUrlCtrl = TextEditingController();
  final _dataService = SupabaseDataService();
  final _picker = ImagePicker();

  List<Topluluk> _topluluklar = [];
  Topluluk? _selectedTopluluk;
  XFile? _pickedImage;
  bool _loading = false;
  bool _loadingCommunities = true;
  bool _uploadingImage = false;
  String? _errorMsg;

  bool get _isAdmin => widget.user?.isAdmin == true;

  bool _isEvent = false;

  // Geri tuşuna/kapat'a basınca yazılan içerik yanlışlıkla kaybolmasın (bkz.
  // kontrol.md Bölüm 23.7). Başarılı gönderim sonrası bu onay atlanmalı —
  // resmi Flutter PopScope örneğindeki gibi (pop_scope.0.dart): engellenen
  // ilk pop → onay/atla → tekrar pop çağır; bu ikinci çağrı canPop'un anlık
  // değerinden bağımsız başarılı olur. _pendingPopResult, caller'a
  // döndürülecek değeri taşır (setState sonrası hemen pop çağırmak PopScope'un
  // henüz yeniden build olmamış canPop'unu kullanabileceğinden GÜVENİLMEZ).
  bool _skipUnsavedConfirmation = false;
  Object? _pendingPopResult;
  bool get _hasUnsavedChanges =>
      !_skipUnsavedConfirmation &&
      (_contentCtrl.text.trim().isNotEmpty ||
          _imageUrlCtrl.text.trim().isNotEmpty ||
          _pickedImage != null);

  Future<bool> _confirmDiscardChanges() async {
    if (!_hasUnsavedChanges) return true;
    final theme = themeNotifier.value;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.surface,
        title:
            Text('Gönderiden çık?', style: TextStyle(color: theme.textColor)),
        content: Text(
          'Yazdıkların kaydedilmeden kaybolacak. Çıkmak istediğine emin misin?',
          style: TextStyle(color: theme.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: theme.error),
            child: const Text('Çık'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _closeIfConfirmed() async {
    if (await _confirmDiscardChanges() && mounted) {
      Navigator.pop(context, _pendingPopResult);
    }
  }

  /// Başarılı gönderi oluşturma sonrası çağrılır — onayı atlayarak [result]
  /// değeriyle ekrandan çıkar.
  void _popWithSuccess(Object? result) {
    _pendingPopResult = result;
    _skipUnsavedConfirmation = true;
    Navigator.pop(context, result);
  }

  @override
  void initState() {
    super.initState();
    _loadCommunities();
  }

  @override
  void dispose() {
    _contentCtrl.dispose();
    _imageUrlCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCommunities() async {
    try {
      // Admin tüm toplulukları görür; başkan yalnızca kendi topluluklarını.
      final list = _isAdmin
          ? await _dataService.getTopluluklar()
          : await _dataService.getBaskanCommunities();
      if (!mounted) return;
      setState(() {
        _topluluklar = list;
        _loadingCommunities = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingCommunities = false);
    }
  }

  Future<void> _pickImage() async {
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
      );
      if (picked == null) return;

      final validation = await FileValidator.validateXFile(picked);
      if (!validation.isValid) {
        if (!mounted) return;
        setState(() => _errorMsg = validation.errorMessage);
        return;
      }

      setState(() {
        _pickedImage = picked;
        _errorMsg = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(
        () => _errorMsg = 'Görsel seçilemedi. Galeri izni gerekebilir.',
      );
    }
  }

  static bool _isValidHttpUrl(String url) {
    final uri = Uri.tryParse(url);
    return uri != null &&
        (uri.scheme == 'https' || uri.scheme == 'http') &&
        uri.host.isNotEmpty;
  }

  Future<void> _submit() async {
    final content = _contentCtrl.text.trim();
    if (_selectedTopluluk == null) {
      setState(() => _errorMsg = 'Lütfen bir topluluk seçin.');
      return;
    }
    if (content.isEmpty) {
      setState(() => _errorMsg = 'Gönderi içeriği boş olamaz.');
      return;
    }
    if (content.length > 5000) {
      setState(
        () => _errorMsg = 'Gönderi içeriği en fazla 5000 karakter olabilir.',
      );
      return;
    }
    final rawUrl = _imageUrlCtrl.text.trim();
    if (_pickedImage == null && rawUrl.isNotEmpty && !_isValidHttpUrl(rawUrl)) {
      setState(() => _errorMsg = 'Geçerli bir görsel URL girin (https://...).');
      return;
    }

    setState(() {
      _loading = true;
      _errorMsg = null;
    });
    try {
      String? imageUrl;
      if (_pickedImage != null) {
        setState(() => _uploadingImage = true);
        imageUrl = await _dataService.uploadPostImage(File(_pickedImage!.path));
        if (!mounted) return;
        setState(() => _uploadingImage = false);
      } else {
        imageUrl = rawUrl.isEmpty ? null : rawUrl;
      }

      await _dataService.createPost(
        communityId: _selectedTopluluk!.id,
        content: content,
        imageUrl: imageUrl,
        isEvent: _isEvent,
      );
      if (!mounted) return;
      _popWithSuccess(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _uploadingImage = false;
          _errorMsg = 'Gönderi oluşturulamadı: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppTheme>(
      valueListenable: themeNotifier,
      builder: (context, theme, _) {
        return PopScope(
          canPop: !_hasUnsavedChanges,
          onPopInvokedWithResult: (didPop, result) async {
            if (didPop) return;
            await _closeIfConfirmed();
          },
          child: Scaffold(
            backgroundColor: theme.background,
            appBar: AppBar(
              backgroundColor: theme.surface,
              elevation: 0,
              title: Text(
                'Yeni Gönderi',
                style: TextStyle(
                  color: theme.textColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              leading: IconButton(
                icon: Icon(Icons.close, color: theme.textMuted),
                onPressed: _closeIfConfirmed,
                tooltip: 'Kapat',
              ),
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 12, top: 8, bottom: 8),
                  child: ElevatedButton(
                    onPressed: _loading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                    ),
                    child: _loading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Paylaş',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
              ],
            ),
            body: _loadingCommunities
                ? Center(child: CircularProgressIndicator(color: theme.primary))
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Topluluk seçimi
                        Text(
                          'Topluluk',
                          style: TextStyle(
                            color: theme.textMuted,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          decoration: BoxDecoration(
                            color: theme.surface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: theme.primary.withValues(alpha: 0.3),
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<Topluluk>(
                              isExpanded: true,
                              value: _selectedTopluluk,
                              hint: Text(
                                _topluluklar.isEmpty
                                    ? 'Başkanı olduğun topluluk yok'
                                    : 'Topluluk seç...',
                                style: TextStyle(color: theme.textMuted),
                              ),
                              dropdownColor: theme.surface,
                              style: TextStyle(
                                color: theme.textColor,
                                fontSize: 14,
                              ),
                              icon: Icon(
                                Icons.arrow_drop_down,
                                color: theme.textMuted,
                              ),
                              items: _topluluklar
                                  .map(
                                    (t) => DropdownMenuItem(
                                      value: t,
                                      child: Text(
                                        t.ad,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (t) => setState(() {
                                _selectedTopluluk = t;
                                _errorMsg = null;
                              }),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // İçerik
                        Text(
                          'İçerik',
                          style: TextStyle(
                            color: theme.textMuted,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _contentCtrl,
                          maxLines: 6,
                          maxLength: 5000,
                          buildCounter: (
                            _, {
                            required currentLength,
                            required isFocused,
                            maxLength,
                          }) =>
                              currentLength > 4800
                                  ? Text(
                                      '$currentLength/5000',
                                      style: TextStyle(
                                        color: currentLength > 4900
                                            ? Colors.red
                                            : Colors.grey,
                                        fontSize: 11,
                                      ),
                                    )
                                  : null,
                          style: TextStyle(
                            color: theme.textColor,
                            fontSize: 15,
                          ),
                          decoration: InputDecoration(
                            hintText:
                                'Topluluğunla paylaşmak istediğin bir şey var mı?',
                            hintStyle: TextStyle(
                              color: theme.textMuted,
                              fontSize: 14,
                            ),
                            filled: true,
                            fillColor: theme.surface,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(
                                color: theme.primary.withValues(alpha: 0.3),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(
                                color: theme.primary.withValues(alpha: 0.3),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(
                                color: theme.primary,
                                width: 1.5,
                              ),
                            ),
                            contentPadding: const EdgeInsets.all(16),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Görsel — galeriden seç veya URL
                        Text(
                          'Görsel',
                          style: TextStyle(
                            color: theme.textMuted,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (_pickedImage != null)
                          Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: Image.file(
                                  File(_pickedImage!.path),
                                  width: double.infinity,
                                  height: 180,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      Container(
                                    height: 180,
                                    color: theme.surface,
                                    child: Icon(
                                      Icons.broken_image,
                                      color: theme.textMuted,
                                      size: 40,
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 8,
                                right: 8,
                                child: GestureDetector(
                                  onTap: () => setState(() {
                                    _pickedImage = null;
                                  }),
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color:
                                          Colors.black.withValues(alpha: 0.6),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.close,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          )
                        else
                          OutlinedButton.icon(
                            onPressed: _uploadingImage ? null : _pickImage,
                            icon: _uploadingImage
                                ? SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: theme.primary,
                                    ),
                                  )
                                : Icon(
                                    Icons.add_photo_alternate_outlined,
                                    color: theme.primary,
                                  ),
                            label: Text(
                              _uploadingImage
                                  ? 'Yükleniyor...'
                                  : 'Galeriden Görsel Seç',
                              style: TextStyle(color: theme.primary),
                            ),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(48),
                              side: BorderSide(
                                color: theme.primary.withValues(alpha: 0.4),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _imageUrlCtrl,
                          style: TextStyle(
                            color: theme.textColor,
                            fontSize: 14,
                          ),
                          keyboardType: TextInputType.url,
                          decoration: InputDecoration(
                            hintText: 'veya görsel URL (https://...)',
                            hintStyle: TextStyle(color: theme.textMuted),
                            prefixIcon: Icon(
                              Icons.link,
                              color: theme.textMuted,
                              size: 20,
                            ),
                            filled: true,
                            fillColor: theme.surface,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(
                                color: theme.primary.withValues(alpha: 0.3),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(
                                color: theme.primary.withValues(alpha: 0.3),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(
                                color: theme.primary,
                                width: 1.5,
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Etkinlik Katılım Butonu Ekleme Switch Card
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: theme.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: _isEvent
                                  ? theme.primary
                                  : theme.primary.withValues(alpha: 0.2),
                              width: _isEvent ? 1.5 : 1,
                            ),
                          ),
                          child: SwitchListTile(
                            value: _isEvent,
                            onChanged: (val) => setState(() => _isEvent = val),
                            activeThumbColor: theme.primary,
                            contentPadding: EdgeInsets.zero,
                            title: Row(
                              children: [
                                Icon(Icons.event_available,
                                    color: theme.primary, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  'Etkinlik Katılım Butonu Ekle',
                                  style: TextStyle(
                                    color: theme.textColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                            subtitle: Text(
                              'Öğrencilerin bu gönderi üzerinden etkinliğinize katılmasına izin verin',
                              style: TextStyle(
                                  color: theme.textMuted, fontSize: 11),
                            ),
                          ),
                        ),

                        if (_errorMsg != null) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: theme.error.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: theme.error.withValues(alpha: 0.4),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  color: theme.error,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _errorMsg!,
                                    style: TextStyle(
                                      color: theme.error,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
          ),
        );
      },
    );
  }
}
