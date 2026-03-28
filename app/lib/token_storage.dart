import 'dart:html' as html;

// Token storage using web localStorage for persistence
class TokenStorage {
  static String? _token;
  static const String _storageKey = 'zenvoyage_auth_token';

  static Future<void> saveToken(String token) async {
    _token = token;
    try {
      html.window.localStorage[_storageKey] = token;
    } catch (_) {}
  }

  static Future<String?> getToken() async {
    if (_token != null) return _token;
    try {
      _token = html.window.localStorage[_storageKey];
    } catch (_) {}
    return _token;
  }

  static Future<void> clearToken() async {
    _token = null;
    try {
      html.window.localStorage.remove(_storageKey);
    } catch (_) {}
  }
}
