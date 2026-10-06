import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../models/campus_poi.dart';
import 'supabase_data_service.dart';

/// Kampüs Cepte verisi: uygulamayla gelen OpenStreetMap kürasyonu
/// (`assets/data/campus_poi.json`, `tool/build_campus_poi.py` ile üretilir)
/// + admin panelinden eklenen noktalar (`campus_pois` tablosu).
class CampusPoiData {
  CampusPoiData._();

  static List<CampusPoi>? _bundled;

  static Future<List<CampusPoi>> _loadBundled() async {
    if (_bundled != null) return _bundled!;
    final raw = await rootBundle.loadString('assets/data/campus_poi.json');
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final pois = <CampusPoi>[];
    for (final key in const ['pois', 'routes']) {
      for (final e in (json[key] as List? ?? [])) {
        final map = e as Map<String, dynamic>;
        if (PoiCategory.tryParse(map['category'] as String? ?? '') == null) {
          continue;
        }
        pois.add(CampusPoi.fromJson(map));
      }
    }
    return _bundled ??= pois;
  }

  /// Admin'in eklediği noktalar. Ağ yoksa / tablo henüz yoksa boş döner —
  /// harita gömülü veriyle çalışmaya devam eder.
  static Future<List<CampusPoi>> _loadRemote() async {
    try {
      final rows = await SupabaseDataService()
          .getRemoteCampusPois()
          .timeout(const Duration(seconds: 8));
      return [
        for (final r in rows)
          if (PoiCategory.tryParse(r['category'] as String? ?? '') != null)
            CampusPoi.fromJson({...r, 'id': 'ek-${r['id']}'}),
      ];
    } catch (e) {
      debugPrint('[CampusPoiData] Ek noktalar alınamadı: $e');
      return const [];
    }
  }

  static Future<List<CampusPoi>> load() async {
    final results = await Future.wait([_loadBundled(), _loadRemote()]);
    return [...results[1], ...results[0]];
  }
}
