import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../models/campus_poi.dart';

/// Bundled kampüs POI verisini yükler (`assets/data/campus_poi.json`).
///
/// Veri OpenStreetMap Overpass API'den çekilip kürasyonlanmıştır
/// (`curate_overpass.py` ile yeniden üretilebilir).
class CampusPoiData {
  CampusPoiData._();

  static List<CampusPoi>? _cache;

  static Future<List<CampusPoi>> load() async {
    if (_cache != null) return _cache!;
    final raw = await rootBundle.loadString('assets/data/campus_poi.json');
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final pois = <CampusPoi>[];
    for (final e in (json['pois'] as List? ?? [])) {
      pois.add(CampusPoi.fromJson(e as Map<String, dynamic>));
    }
    for (final e in (json['routes'] as List? ?? [])) {
      pois.add(CampusPoi.fromJson(e as Map<String, dynamic>));
    }
    return _cache ??= pois;
  }
}
