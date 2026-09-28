import 'package:http/http.dart' as http;

/// Supabase SDK'nın (Postgrest/Auth/Storage) hiçbir çağrısında açık bir
/// timeout yoktu (bkz. kontrol.md Bölüm 16.5/24 — zayıf/kopan ağda istekler
/// süresiz beklemede kalabiliyordu). `Supabase.initialize`'a bu client
/// verilerek tüm REST tabanlı çağrılara tek noktadan zaman aşımı eklenir.
/// Realtime (WebSocket) bağlantıları bu client'ı kullanmaz, etkilenmez.
class TimeoutHttpClient extends http.BaseClient {
  TimeoutHttpClient(this._inner, this._timeout);

  final http.Client _inner;
  final Duration _timeout;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _inner.send(request).timeout(_timeout);
  }

  @override
  void close() => _inner.close();
}
