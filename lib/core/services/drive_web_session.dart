/// Google Drive session in the browser: the access token (~1 h) and the
/// account email live in memory only, shared by every DriveBackupService
/// instance. Nothing is stored: each visit (or after expiry) the user taps
/// Connect again, usually one click when signed in to Google.
library;

import 'dart:convert';

import 'package:http/http.dart' as http;

import 'web_oauth.dart';

/// OAuth client of type **Web application** (same Google Cloud project as the
/// native clients, so drive.file sees the same files). Not secret.
const webClientId = String.fromEnvironment('GDRIVE_WEB_CLIENT_ID');

class DriveWebSession {
  DriveWebSession._();

  static String? _token;
  static DateTime? _expiresAt;
  static String? _email; // kept after expiry as the login hint

  static String? get email => _email;

  /// Valid token (with a 2-minute margin), or null if absent/expired.
  static String? get token {
    final exp = _expiresAt;
    if (_token == null || exp == null) return null;
    return exp.isAfter(DateTime.now().add(const Duration(minutes: 2)))
        ? _token
        : null;
  }

  static bool get active => token != null;

  /// Popup sign-in (needs a user action). Throws on failure/cancel.
  static Future<void> signIn(List<String> scopes) async {
    final t = await requestWebToken(webClientId, scopes, loginHint: _email);
    _token = t.accessToken;
    _expiresAt = t.expiresAt;
    _email = await _fetchEmail(t.accessToken) ?? _email;
  }

  static void signOut() {
    final t = _token;
    if (t != null) revokeWebToken(t);
    _token = _expiresAt = _email = null;
  }

  static Future<String?> _fetchEmail(String token) async {
    try {
      final r = await http.get(
          Uri.parse('https://www.googleapis.com/oauth2/v3/userinfo'),
          headers: {'Authorization': 'Bearer $token'});
      if (r.statusCode != 200) return null;
      return (jsonDecode(r.body) as Map<String, dynamic>)['email'] as String?;
    } catch (_) {
      return null;
    }
  }
}
