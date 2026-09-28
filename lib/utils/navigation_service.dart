import 'package:flutter/material.dart';

/// Uygulama genelinde `BuildContext`'e ihtiyaç duymadan (ör. FCM callback'leri
/// gibi widget ağacı dışındaki servislerden) sayfa yönlendirmesi yapabilmek
/// için `MaterialApp`'e bağlanan global anahtar.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
