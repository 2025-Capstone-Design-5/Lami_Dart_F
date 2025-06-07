import 'package:flutter/material.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'main.dart'; // MainScreen으로 이동하기 위한 import
import 'mypage.dart'; // MyPage import 추가
import 'package:flutter/foundation.dart';  // for kIsWeb
import 'dart:io' show Platform;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // 1) PKCE code_verifier 생성
  String _genVerifier() {
    final rand = Random.secure();
    final bytes = List<int>.generate(64, (_) => rand.nextInt(256));
    return base64UrlEncode(bytes).replaceAll('=', '');
  }

  // 2) code_challenge 생성
  String _genChallenge(String verifier) {
    final digest = sha256.convert(utf8.encode(verifier)).bytes;
    return base64UrlEncode(digest).replaceAll('=', '');
  }

  // 3) CSRF state 생성
  String _genState() {
    final rand = Random.secure();
    final bytes = List<int>.generate(16, (_) => rand.nextInt(256));
    return base64UrlEncode(bytes).replaceAll('=', '');
  }

  Future<void> _authenticateWithGoogle() async {
    final codeVerifier = _genVerifier();
    final codeChallenge = _genChallenge(codeVerifier);
    final state = _genState();

    // 4) 플랫폼별 Client ID 설정 (Android, iOS용 별도 관리)
    final androidClientId = dotenv.env['ANDROID_CLIENT_ID']!;
    final iosClientId = dotenv.env['IOS_CLIENT_ID']!;
    final clientId = Platform.isAndroid ? androidClientId : iosClientId;
    final redirectUri = dotenv.env['REDIRECT_URI']!;
    final callbackScheme = redirectUri.split(':').first;

    // 6) 인증 URL 생성
    final authUrl = Uri.https(
      'accounts.google.com',
      '/o/oauth2/v2/auth',
      {
        'response_type': 'code',
        'client_id': clientId,
        'redirect_uri': redirectUri,
        'scope': 'openid email profile https://www.googleapis.com/auth/calendar',
        'state': state,
        'code_challenge': codeChallenge,
        'code_challenge_method': 'S256',
        'access_type': 'offline',
        'prompt': 'consent',
      },
    ).toString();

    // 7) 외부 브라우저에서 인증 → deep link 수신
    final result = await FlutterWebAuth2.authenticate(
      url: authUrl,
      callbackUrlScheme: callbackScheme,
    );
    final uri = Uri.parse(result);
    // CSRF 검증
    if (uri.queryParameters['state'] != state) {
      throw Exception('Invalid state');
    }
    final code = uri.queryParameters['code']!;
    
    // 8) 서버로 code+codeVerifier 전송
    final serverBaseUrl = dotenv.env['SERVER_BASE_URL']!;
    final resp = await http.post(
      Uri.parse('$serverBaseUrl/auth/google/code'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'code': code,
        'codeVerifier': codeVerifier,
        'platform': Platform.isAndroid ? 'android' : 'ios',
      }),
    );
    if (resp.statusCode != 200) {
      throw Exception('Token exchange failed: ${resp.body}');
    }
    final data = jsonDecode(resp.body)['data'];
    // TODO: 받은 data['access_token'], data['refresh_token'], data['id_token'] 저장 및 사용자 처리

    // 로그인 성공 후 홈 화면으로 이동 (이전 스택 제거)
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => MainScreen(
          userName: data['idToken']['name'] ?? '',
          userEmail: data['idToken']['email'] ?? '',
          initialIndex: 0,
        ),
      ),
      (route) => false,
    );
  }

  // 게스트로 로그인하는 함수 추가
  void _continueAsGuest() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => const MainScreen(
          userName: '게스트',
          userEmail: 'guest@example.com',
          initialIndex: 0,
        ),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3EFEE), // 기존 앱의 배경색 사용
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 30),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 앱 로고
                Image.asset(
                  'assets/images/Lami.png',
                  height: 120,
                  // 로고 파일이 없는 경우 아래 코드 사용
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 120,
                      width: 120,
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(
                        Icons.anchor,
                        size: 60,
                        color: Colors.white,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 60),

                // 환영 메시지
                const Text(
                  '환영합니다!',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Google 계정으로 간편하게 로그인하세요',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 80),

                // 구글 로그인 버튼 (메인 버튼)
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _authenticateWithGoogle,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF1F1F1F),
                      elevation: 2,
                      shadowColor: Colors.black26,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: const BorderSide(
                          color: Color(0xFFDADCE0),
                          width: 1,
                        ),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Google 공식 로고
                        Container(
                          width: 20,
                          height: 20,
                          margin: const EdgeInsets.only(right: 12),
                          child: Image.asset(
                            'assets/images/google_logo.png',
                            width: 20,
                            height: 20,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(2),
                                  border: Border.all(color: Colors.grey.shade300),
                                ),
                                child: const Icon(
                                  Icons.login,
                                  size: 16,
                                  color: Color(0xFF4285F4),
                                ),
                              );
                            },
                          ),
                        ),
                        const Text(
                          'Google로 로그인',
                          style: TextStyle(
                            fontFamily: 'Roboto',
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF1F1F1F),
                            letterSpacing: 0.25,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // 게스트로 계속하기 버튼 추가
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: OutlinedButton(
                    onPressed: _continueAsGuest,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF1F1F1F),
                      side: const BorderSide(
                        color: Color(0xFFDADCE0),
                        width: 1,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      '게스트로 계속하기',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF1F1F1F),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 40),

                // 안내 텍스트
                const Text(
                  'Google 계정이 없으시다면\nGoogle에서 계정을 생성해주세요',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}