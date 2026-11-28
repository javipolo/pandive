/// Native stub of the browser OAuth (never called off the web).
library;

/// Access token from the browser popup.
class WebToken {
  final String accessToken;
  final DateTime expiresAt;
  const WebToken(this.accessToken, this.expiresAt);
}

Future<void> initWebOAuth() async {}

Future<WebToken> requestWebToken(String clientId, List<String> scopes,
        {String? loginHint}) =>
    throw UnsupportedError('requestWebToken is web only');

void revokeWebToken(String accessToken) {}
