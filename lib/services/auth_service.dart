import 'dart:convert';
import 'dart:math';
import 'dart:io' show Platform;
import 'package:crypto/crypto.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../config/server_config.dart';

/// Service for handling authentication flows (Google OAuth & guest) via backend.
class AuthResult {
  final String name;
  final String email;
  AuthResult({required this.name, required this.email});
}

class AuthService {
  String _genVerifier() {
    final rand = Random.secure();
    final bytes = List<int>.generate(64, (_) => rand.nextInt(256));
    return base64UrlEncode(bytes).replaceAll('=', '');
  }

  String _genChallenge(String v) {
    final digest = sha256.convert(utf8.encode(v)).bytes;
    return base64UrlEncode(digest).replaceAll('=', '');
  }

  String _genState() {
    final rand = Random.secure();
    final bytes = List<int>.generate(16, (_) => rand.nextInt(256));
    return base64UrlEncode(bytes).replaceAll('=', '');
  }

  /// Performs Google OAuth login and exchanges code with backend.
  Future<AuthResult> loginWithGoogle() async {
    final verifier = _genVerifier();
    final challenge = _genChallenge(verifier);
    final state = _genState();

    final androidId = dotenv.env['ANDROID_CLIENT_ID'];
    if (androidId == null) {
      throw Exception('ENV: ANDROID_CLIENT_ID not set');
    }
    final iosId = dotenv.env['IOS_CLIENT_ID'];
    if (iosId == null) {
      throw Exception('ENV: IOS_CLIENT_ID not set');
    }
    final clientId = Platform.isAndroid ? androidId : iosId;
    final redirectUri = dotenv.env['REDIRECT_URI'];
    if (redirectUri == null) {
      throw Exception('ENV: REDIRECT_URI not set');
    }
    final callbackScheme = redirectUri.split(':').first;

    final authUrl = Uri.https(
      'accounts.google.com',
      '/o/oauth2/v2/auth',
      {
        'response_type': 'code',
        'client_id': clientId,
        'redirect_uri': redirectUri,
        'scope': 'openid email profile https://www.googleapis.com/auth/calendar',
        'state': state,
        'code_challenge': challenge,
        'code_challenge_method': 'S256',
        'access_type': 'offline',
        'prompt': 'consent',
      },
    ).toString();

    final result = await FlutterWebAuth2.authenticate(
      url: authUrl,
      callbackUrlScheme: callbackScheme,
    );
    final uri = Uri.parse(result);
    if (uri.queryParameters['state'] != state) {
      throw Exception('Invalid state');
    }
    final code = uri.queryParameters['code']!;

    final resp = await http.post(
      Uri.parse('${getServerBaseUrl()}/auth/google/code'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'code': code,
        'codeVerifier': verifier,
        'platform': Platform.isAndroid ? 'android' : 'ios',
      }),
    );
    if (resp.statusCode != 200) {
      throw Exception('Token exchange failed: ${resp.body}');
    }
    final data = jsonDecode(resp.body)['data'];
    final payload = data['idToken'] as Map<String, dynamic>;
    final name = payload['name'] as String;
    final email = payload['email'] as String;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('googleId', payload['sub'] as String);
    return AuthResult(name: name, email: email);
  }

  /// Performs guest login via backend.
  Future<AuthResult> loginAsGuest() async {
    // Generate a random guest ID and name locally
    final rand = Random.secure();
    final guestId = List<int>.generate(8, (_) => rand.nextInt(256)).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    final name = '게스트';
    final email = 'guest_$guestId@local';
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('googleId', guestId);
    return AuthResult(name: name, email: email);
  }
} 