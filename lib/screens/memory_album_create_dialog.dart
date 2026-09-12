import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class MemoryAlbumCreateDialog extends StatefulWidget {
  const MemoryAlbumCreateDialog({super.key});

  @override
  State<MemoryAlbumCreateDialog> createState() => _MemoryAlbumCreateDialogState();
}

class _MemoryAlbumCreateDialogState extends State<MemoryAlbumCreateDialog> {
  final _ctrl = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = themeNotifier.value;

    return AlertDialog(
      backgroundColor: theme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Icon(Icons.photo_album_outlined, color: theme.primary, size: 24),
          const SizedBox(width: 8),
          Text('Yeni Albüm', style: TextStyle(color: theme.primary, fontWeight: FontWeight.bold)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _ctrl,
            style: TextStyle(color: theme.textColor),
            decoration: InputDecoration(
              labelText: 'Albüm Adı',
              labelStyle: TextStyle(color: theme.textMuted),
              hintText: 'Örn: Üniversite Hayatım, Staj Günleri...',
              hintStyle: TextStyle(color: theme.textMuted.withValues(alpha: 0.5)),
              filled: true,
              fillColor: theme.surface.withValues(alpha: 0.5),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: theme.primary.withValues(alpha: 0.3)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: theme.primary, width: 2),
              ),
            ),
            autofocus: true,
            maxLength: 50,
            onChanged: (v) => setState(() => _error = v.trim().isEmpty ? 'Albüm adı boş olamaz' : null),
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: TextStyle(color: theme.error, fontSize: 12)),
          ],
          const SizedBox(height: 8),
          Text(
            'Albüm adı en az 1, en fazla 50 karakter olmalıdır.',
            style: TextStyle(color: theme.textMuted, fontSize: 11),
            textAlign: TextAlign.center,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('İptal', style: TextStyle(color: theme.textMuted)),
        ),
        ElevatedButton(
          onPressed: _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text('Oluştur', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  void _submit() {
    final name = _ctrl.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Albüm adı boş olamaz');
      return;
    }
    if (name.length > 50) {
      setState(() => _error = 'Albüm adı en fazla 50 karakter olabilir');
      return;
    }
    Navigator.pop(context, name);
  }
}