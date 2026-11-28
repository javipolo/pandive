/// Browser OAuth with Google Identity Services. The SDK is loaded at startup
/// ([initWebOAuth]) so the popup opens straight from the user's click.
library;

import 'dart:async';

import 'package:google_identity_services_web/loader.dart';
import 'package:google_identity_services_web/oauth2.dart';

/// Access token from the browser popup.
class WebToken {
  final String accessToken;
  final DateTime expiresAt;
  const WebToken(this.accessToken, this.expiresAt);
}

Future<void>? _sdk;

/// Starts loading the Google script (idempotent).
Future<void> initWebOAuth() => _sdk ??= loadWebSdk();

/// Opens Google's popup (account choice / consent) and returns a token.
/// Call it from a user action, or the browser blocks the popup.
Future<WebToken> requestWebToken(String clientId, List<String> scopes,
    {String? loginHint}) async {
  await initWebOAuth();
  final done = Completer<WebToken>();
  void fail(String msg) {
    if (!done.isCompleted) done.completeError(StateError(msg));
  }

  final client = oauth2.initTokenClient(TokenClientConfig(
    client_id: clientId,
    scope: scopes,
    login_hint: loginHint,
    callback: (r) {
      final token = r.access_token;
      if (r.error != null || token == null) {
        return fail(r.error_description ?? r.error ?? 'no access token');
      }
      if (!done.isCompleted) {
        done.complete(WebToken(token,
            DateTime.now().add(Duration(seconds: r.expires_in ?? 3600))));
      }
    },
    error_callback: (e) => fail(e?.message ?? e?.type.name ?? 'oauth error'),
  ));
  client.requestAccessToken();
  return done.future;
}

/// Revokes the app's access (on disconnect).
void revokeWebToken(String accessToken) => oauth2.revoke(accessToken);
