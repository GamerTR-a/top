import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/campus_poi.dart';
import '../services/location_service.dart';
import '../services/supabase_data_service.dart';
import '../theme/app_theme.dart';
import '../widgets/animated_theme_background.dart';

/// Admin: Kampüs Cepte haritasına nokta ekler/siler (`campus_pois` tablosu).
/// Uygulamayla gelen OpenStreetMap verisinde olmayan yurt, durak vb. buradan
/// tamamlanır. Yazma yetkisi sunucuda zorlanır (yalnızca role='admin').
class CampusPoiAdminScreen extends StatefulWidget {
  const CampusPoiAdminScreen({super.key});

  @override
  State<CampusPoiAdminScreen> createState() => _CampusPoiAdminScreenState();
}

class _CampusPoiAdminScreenState extends State<CampusPoiAdminScreen> {
  final _api = SupabaseDataService();
  List<Map<String, dynamic>> _rows = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await _api.getRemoteCampusPois();
      if (!mounted) return;
      setState(() {
        _rows = rows;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Noktalar alınamadı. `campus_pois` tablosu için migration '
            'çalıştırıldı mı?\n$e';
      });
    }
  }

  Future<void> _add() async {
    final added = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const _CampusPoiEditorScreen()),
    );
    if (added == true) _load();
  }

  Future<void> _delete(Map<String, dynamic> row) async {
    final theme = themeNotifier.value;
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.surface,
        title: Text('Noktayı Sil', style: TextStyle(color: theme.textColor)),
        content: Text(
          '"${row['name']}" haritadan kaldırılsın mı?',
          style: TextStyle(color: theme.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Vazgeç'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: theme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sil', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _api.deleteCampusPoi((row['id'] as num).toInt());
      _load();
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Silinemedi: $e'), backgroundColor: theme.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppTheme>(
      valueListenable: themeNotifier,
      builder: (context, theme, _) {
        Widget body;
        if (_loading) {
          body = Center(child: CircularProgressIndicator(color: theme.primary));
        } else if (_error != null) {
          body = Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: theme.textMuted),
              ),
            ),
          );
        } else if (_rows.isEmpty) {
          body = Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Henüz eklenmiş nokta yok. Haritada eksik olan yurt, durak '
                'veya mekânları sağ alttaki düğmeyle ekleyebilirsiniz.',
                textAlign: TextAlign.center,
                style: TextStyle(color: theme.textMuted, height: 1.5),
              ),
            ),
          );
        } else {
          body = ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            itemCount: _rows.length,
            separatorBuilder: (_, i) => const SizedBox(height: 8),
            itemBuilder: (ctx, i) {
              final row = _rows[i];
              final cat = PoiCategory.tryParse(row['category'] as String? ?? '');
              final desc = row['description'] as String? ?? '';
              return ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                tileColor: theme.surface.withValues(alpha: 0.6),
                title: Text(
                  row['name'] as String? ?? '',
                  style: TextStyle(
                    color: theme.textColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                subtitle: Text(
                  [cat?.label ?? row['category'], if (desc.isNotEmpty) desc]
                      .join(' · '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: theme.textMuted, fontSize: 12),
                ),
                trailing: IconButton(
                  icon: Icon(Icons.delete_outline, color: theme.error),
                  tooltip: 'Sil',
                  onPressed: () => _delete(row),
                ),
              );
            },
          );
        }

        return Scaffold(
          backgroundColor: theme.background,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_ios_new, color: theme.primary),
              onPressed: () => Navigator.pop(context),
              tooltip: 'Geri',
            ),
            title: Text(
              'Kampüs Cepte Noktaları',
              style: TextStyle(
                color: theme.textColor,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
          floatingActionButton: _error != null
              ? null
              : FloatingActionButton.extended(
                  backgroundColor: theme.primary,
                  onPressed: _add,
                  icon: const Icon(Icons.add_location_alt, color: Colors.white),
                  label: const Text(
                    'Nokta Ekle',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
          body: SafeArea(child: AnimatedThemeBackground(child: body)),
        );
      },
    );
  }
}

class _CampusPoiEditorScreen extends StatefulWidget {
  const _CampusPoiEditorScreen();

  @override
  State<_CampusPoiEditorScreen> createState() => _CampusPoiEditorScreenState();
}

class _CampusPoiEditorScreenState extends State<_CampusPoiEditorScreen> {
  final _api = SupabaseDataService();
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  PoiCategory _category = PoiCategory.dormitory;
  LatLng? _point;
  bool _saving = false;

  static final _categories =
      PoiCategory.values.where((c) => !c.isRouteCategory).toList();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final theme = themeNotifier.value;
    final messenger = ScaffoldMessenger.of(context);
    if (!_formKey.currentState!.validate()) return;
    if (_point == null) {
      messenger.showSnackBar(
        SnackBar(
          content: const Text('Haritaya dokunarak noktanın yerini seçin.'),
          backgroundColor: theme.error,
        ),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await _api.addCampusPoi(
        name: _nameCtrl.text.trim(),
        category: _category.name,
        lat: double.parse(_point!.latitude.toStringAsFixed(5)),
        lng: double.parse(_point!.longitude.toStringAsFixed(5)),
        description: _descCtrl.text.trim(),
        address: _addressCtrl.text.trim(),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(
        SnackBar(content: Text('Eklenemedi: $e'), backgroundColor: theme.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = themeNotifier.value;
    OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c, width: w),
        );
    InputDecoration deco(String label) => InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: theme.textMuted, fontSize: 13),
          filled: true,
          fillColor: theme.surface,
          border: border(theme.primary.withValues(alpha: 0.2)),
          enabledBorder: border(theme.primary.withValues(alpha: 0.2)),
          focusedBorder: border(theme.primary, 1.5),
          errorBorder: border(theme.error),
          focusedErrorBorder: border(theme.error, 1.5),
        );

    return Scaffold(
      backgroundColor: theme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: theme.primary),
          onPressed: () => Navigator.pop(context),
          tooltip: 'Kapat',
        ),
        title: Text(
          'Nokta Ekle',
          style: TextStyle(
            color: theme.textColor,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                _point == null
                    ? 'Haritaya dokunarak yeri işaretleyin'
                    : 'Konum seçildi — değiştirmek için tekrar dokunun',
                style: TextStyle(color: theme.textMuted, fontSize: 12),
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SizedBox(
                  height: 260,
                  child: FlutterMap(
                    options: MapOptions(
                      initialCenter: LocationService.campusCenter,
                      initialZoom: 15,
                      minZoom: 11,
                      maxZoom: 19,
                      onTap: (_, point) => setState(() => _point = point),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.Nevgenc',
                      ),
                      if (_point != null)
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: _point!,
                              width: 40,
                              height: 40,
                              alignment: Alignment.topCenter,
                              child: Icon(
                                Icons.location_on,
                                color: theme.error,
                                size: 40,
                              ),
                            ),
                          ],
                        ),
                      const RichAttributionWidget(
                        attributions: [
                          TextSourceAttribution('OpenStreetMap contributors'),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameCtrl,
                maxLength: 120,
                textCapitalization: TextCapitalization.words,
                style: TextStyle(color: theme.textColor),
                decoration: deco('Ad'),
                validator: (v) => (v == null || v.trim().length < 2)
                    ? 'Ad en az 2 karakter olmalı'
                    : null,
              ),
              const SizedBox(height: 4),
              DropdownButtonFormField<PoiCategory>(
                initialValue: _category,
                dropdownColor: theme.surface,
                style: TextStyle(color: theme.textColor, fontSize: 14),
                decoration: deco('Kategori'),
                items: [
                  for (final c in _categories)
                    DropdownMenuItem(value: c, child: Text(c.label)),
                ],
                onChanged: (c) => setState(() => _category = c ?? _category),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descCtrl,
                maxLength: 300,
                maxLines: 2,
                textCapitalization: TextCapitalization.sentences,
                style: TextStyle(color: theme.textColor),
                decoration: deco('Açıklama (isteğe bağlı)'),
              ),
              const SizedBox(height: 4),
              TextFormField(
                controller: _addressCtrl,
                maxLength: 200,
                style: TextStyle(color: theme.textColor),
                decoration: deco('Adres (isteğe bağlı)'),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Kaydet',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
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
}
