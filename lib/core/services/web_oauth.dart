/// Google OAuth in the browser (Google Identity Services, token model): a
/// popup gives a short-lived (~1 h) access token, no refresh token. Native
/// platforms get a stub that throws.
library;

export 'web_oauth_stub.dart' if (dart.library.js_interop) 'web_oauth_web.dart';
