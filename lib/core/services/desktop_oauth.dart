/// OAuth de Google para escritorio (Linux), donde no hay flutter_appauth:
/// flujo "loopback" con PKCE. Abre el navegador del sistema, recoge el código
/// en un servidor HTTP efímero en 127.0.0.1 y lo canjea por tokens.
/// Requiere un OAuth client de tipo **Desktop app** (lleva un client secret
/// que Google no considera confidencial en apps instaladas).
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

const _authEndpoint = 'https://accounts.google.com/o/oauth2/v2/auth';
const _tokenEndpoint = 'https://oauth2.googleapis.com/token';

class OAuthTokens {
  final String accessToken;
  final DateTime? expiresAt;
  final String? refreshToken;
  final String? idToken;
  const OAuthTokens(
      this.accessToken, this.expiresAt, this.refreshToken, this.idToken);

  factory OAuthTokens.fromJson(Map<String, dynamic> j) => OAuthTokens(
        j['access_token'] as String,
        j['expires_in'] is num
            ? DateTime.now().add(Duration(seconds: (j['expires_in'] as num).toInt()))
            : null,
        j['refresh_token'] as String?,
        j['id_token'] as String?,
      );
}

class DesktopOAuth {
  final String clientId;
  final String clientSecret;
  const DesktopOAuth(this.clientId, this.clientSecret);

  /// Consentimiento interactivo en el navegador. [doneText] se muestra en la
  /// pestaña al volver. Lanza si se cancela, falla o pasan 5 minutos.
  Future<OAuthTokens> authorize(List<String> scopes, {String doneText = ''}) async {
    final verifier = _random(64);
    final challenge = base64Url
        .encode(sha256.convert(ascii.encode(verifier)).bytes)
        .replaceAll('=', '');
    final state = _random(24);
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final redirect = 'http://127.0.0.1:${server.port}';
    try {
      final url = Uri.parse(_authEndpoint).replace(queryParameters: {
        'client_id': clientId,
        'redirect_uri': redirect,
        'response_type': 'code',
        'scope': scopes.join(' '),
        'code_challenge': challenge,
        'code_challenge_method': 'S256',
        'state': state,
        'access_type': 'offline',
        'prompt': 'consent',
      });
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        throw StateError('No se pudo abrir el navegador');
      }
      final code = await _awaitCode(server, state, doneText)
          .timeout(const Duration(minutes: 5));
      return await _token({
        'grant_type': 'authorization_code',
        'code': code,
        'redirect_uri': redirect,
        'code_verifier': verifier,
      });
    } finally {
      await server.close(force: true);
    }
  }

  /// Access token nuevo a partir del refresh token (HTTP puro, sin UI).
  Future<OAuthTokens> refresh(String refreshToken) => _token({
        'grant_type': 'refresh_token',
        'refresh_token': refreshToken,
      });

  // Espera la redirección de Google (ignora otras peticiones, p.ej. favicon).
  Future<String> _awaitCode(HttpServer server, String state, String doneText) async {
    await for (final req in server) {
      final q = req.uri.queryParameters;
      if (!q.containsKey('code') && !q.containsKey('error')) {
        req.response.statusCode = HttpStatus.notFound;
        await req.response.close();
        continue;
      }
      req.response.headers.contentType = ContentType.html;
      req.response.write('<!doctype html><meta charset="utf-8">'
          '<body style="font-family:sans-serif;text-align:center;padding-top:4em">'
          '<h2>Pandive</h2><p>${htmlEscape.convert(doneText)}</p></body>');
      await req.response.close();
      if (q['error'] != null) throw StateError('OAuth: ${q['error']}');
      if (q['state'] != state) throw StateError('OAuth: state no coincide');
      return q['code']!;
    }
    throw StateError('OAuth: servidor cerrado');
  }

  Future<OAuthTokens> _token(Map<String, String> params) async {
    final res = await http.post(Uri.parse(_tokenEndpoint), body: {
      ...params,
      'client_id': clientId,
      'client_secret': clientSecret,
    });
    if (res.statusCode != 200) {
      throw StateError('OAuth token ${res.statusCode}: ${res.body}');
    }
    return OAuthTokens.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  static String _random(int n) {
    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~';
    final r = Random.secure();
    return List.generate(n, (_) => chars[r.nextInt(chars.length)]).join();
  }
}
