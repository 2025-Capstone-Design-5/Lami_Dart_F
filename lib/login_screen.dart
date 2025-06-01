import 'package:flutter/material.dart';
import 'package:flutter_web_auth/flutter_web_auth.dart';
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'main.dart'; // MainScreen으로 이동하기 위한 import
import 'signup_screen.dart'; // 회원가입 화면으로 이동하기 위한 import
import 'mypage.dart'; // MyPage import 추가
import 'package:flutter/foundation.dart';  // for kIsWeb
import 'dart:io' show Platform;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class LoginScreen extends StatefulWidget {
  // 회원가입 정보를 저장할 변수 추가
  final String? registeredName;
  final String? registeredEmail;
  final String? registeredId;

  const LoginScreen({
    Key? key,
    this.registeredName,
    this.registeredEmail,
    this.registeredId,
  }) : super(key: key);

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _idController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _rememberMe = false;

  @override
  void dispose() {
    _idController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _login() {
    if (_formKey.currentState!.validate()) {
      // 여기에 실제 로그인 처리 로직 구현
      // API 연동, 사용자 인증 등의 코드 추가

      // 로그인 성공 시 메인 화면으로 이동하면서 사용자 정보 전달
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => MainScreen(
            userName: widget.registeredName ?? '홍길동', // 회원가입에서 전달받은 이름 사용
            userEmail: widget.registeredEmail ?? 'myemail@email.com', // 회원가입에서 전달받은 이메일 사용
            initialIndex: 0, // 홈 화면부터 시작
          ),
        ),
      );
    }
  }

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
    final result = await FlutterWebAuth.authenticate(
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3EFEE), // 기존 앱의 배경색 사용
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 30),
            child: Form(
              key: _formKey,
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
                  const SizedBox(height: 40),

                  // 환영 메시지
                  const Text(
                    '환영합니다!',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '로그인하여 서비스를 이용하세요',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 40),

                  // 아이디 입력 필드
                  TextFormField(
                    controller: _idController,
                    decoration: InputDecoration(
                      labelText: '아이디',
                      hintText: '아이디를 입력하세요',
                      prefixIcon: const Icon(Icons.person),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '아이디를 입력해주세요';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // 비밀번호 입력 필드
                  TextFormField(
                    controller: _passwordController,
                    obscureText: !_isPasswordVisible,
                    decoration: InputDecoration(
                      labelText: '비밀번호',
                      hintText: '비밀번호를 입력하세요',
                      prefixIcon: const Icon(Icons.lock),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                        ),
                        onPressed: () {
                          setState(() {
                            _isPasswordVisible = !_isPasswordVisible;
                          });
                        },
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '비밀번호를 입력해주세요';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // 자동 로그인 및 비밀번호 찾기
                  Row(
                    children: [
                      // 자동 로그인 체크박스
                      Checkbox(
                        value: _rememberMe,
                        onChanged: (value) {
                          setState(() {
                            _rememberMe = value!;
                          });
                        },
                        activeColor: Colors.blue,
                      ),
                      const Text(
                        '자동 로그인',
                        style: TextStyle(fontFamily: 'Inter'),
                      ),
                      const Spacer(),
                      // 비밀번호 찾기 버튼
                      TextButton(
                        onPressed: () {
                          // 비밀번호 찾기 화면으로 이동 또는 다이얼로그 표시
                        },
                        child: const Text(
                          '비밀번호 찾기',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            color: Colors.blue,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),

                  // 로그인 버튼
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10.0),
                        ),
                      ),
                      child: const Text(
                        '로그인',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 구글 로그인 버튼 (오버플로우 방지 위해 Row + Flexible 사용)
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _authenticateWithGoogle,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.login,
                            size: 24,
                            color: Colors.red,
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Google로 로그인',
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // pubspec.yaml에 assets 수정 후에는 전체 재시작(Hot Restart 또는 flutter run) 필요
                  const SizedBox(height: 20),

                  // 회원가입 링크
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        '계정이 없으신가요?',
                        style: TextStyle(fontFamily: 'Inter'),
                      ),
                      TextButton(
                        onPressed: () {
                          // 회원가입 화면으로 이동
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const SignupScreen()),
                          );
                        },
                        child: const Text(
                          '회원가입',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}