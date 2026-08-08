import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:newgenc/main.dart';

void main() {
  setUpAll(() async {
    // Test ortamında platform plugin'i olmadığı için shared_preferences'ı
    // bellek içi sahte değerlerle taklit et (Supabase.initialize buna ihtiyaç duyar).
    SharedPreferences.setMockInitialValues({});
    // Supabase'i test ortamı için sahte URL ve anahtar ile başlat.
    // Gerçek ağ çağrısı yapılmaz; bu yalnızca instance'ın hazır olması için gereklidir.
    await Supabase.initialize(
      url: 'https://placeholder.supabase.co',
      anonKey: 'placeholder-anon-key',
    );
  });

  testWidgets('NevGenç app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const NevGencApp());
    await tester.pump();
    expect(find.byType(NevGencApp), findsOneWidget);
  });
}
