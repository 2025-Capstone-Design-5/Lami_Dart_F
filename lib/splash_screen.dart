import 'package:flutter/material.dart';
import 'dart:async';
import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // 스플래시 화면이 보이는 시간 설정 (3초)
    Timer(const Duration(seconds: 3), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3EFEE), // 기존 앱의 배경색 사용
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 앱 로고 (assets/logo.png 파일이 필요합니다)
            Image.asset(
              'assets/images/Lami.png',
              height: 150,
              // 로고 파일이 없는 경우 아래 코드 사용
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  height: 150,
                  width: 150,
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.anchor,
                    size: 80,
                    color: Colors.white,
                  ),
                );
              },
            ),
            const SizedBox(height: 30),
            // 앱 이름 또는 환영 메시지
            const Text(
              '로딩중( or 어플리케이션 문구 같은 것?  )',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
            const SizedBox(height: 50),
            // 로딩 인디케이터
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
            ),
          ],
        ),
      ),
    );
  }
}