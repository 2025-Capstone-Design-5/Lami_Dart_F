import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'pages/home/home_page.dart';
import 'pages/calendar/calendar_page.dart';
import 'pages/assistant/assistant_page.dart';
import 'pages/my/mypage.dart';
import 'pages/auth/splash_screen.dart'; // 스플래시 화면 import 추가
import 'dart:io';
import 'package:provider/provider.dart';
import 'providers/auth_state.dart';

/// 앱 시작 전에 환경변수를 로드합니다
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = MyHttpOverrides();
  try {
    await dotenv.load(fileName: ".env");
    debugPrint("[dotenv] loaded variables: ${dotenv.env}");
  } catch (e) {
    debugPrint("[dotenv] failed to load .env: $e");
  }
  await initializeDateFormatting('ko');
  runApp(
    ChangeNotifierProvider(
      create: (_) => AuthState(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthState>(
      builder: (context, authState, _) {
        return MaterialApp(
          title: '메인화면',
          theme: ThemeData(
            fontFamily: 'Inter',
            scaffoldBackgroundColor: const Color(0xFFF3EFEE),
          ),
          home: authState.loggedIn ? const SplashScreen() : const SplashScreen(),
          debugShowCheckedModeBanner: false,
          routes: {},
        );
      },
    );
  }
}

class MainScreen extends StatefulWidget {
  // 사용자 정보를 저장할 변수 추가
  final String userName;
  final String userEmail;
  // initialIndex 속성 추가
  final int initialIndex;

  const MainScreen({
    Key? key,
    this.userName = '홍길동',
    this.userEmail = 'myemail@email.com',
    this.initialIndex = 0, // 기본값 설정
  }) : super(key: key);

  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  late int selectedNavIndex;

  @override
  void initState() {
    super.initState();
    selectedNavIndex = widget.initialIndex;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: selectedNavIndex,
        children: [
          const HomePage(),
          const CalendarPage(),
          const AssistantPage(),
          // MyPage에 사용자 정보 전달
          MyPage(
            userName: widget.userName,
            userEmail: widget.userEmail,
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: selectedNavIndex,
        onTap: (index) {
          setState(() {
            selectedNavIndex = index;
          });
        },
        backgroundColor: const Color(0xFFF8F2F7),
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w400),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: '홈'),
          BottomNavigationBarItem(icon: Icon(Icons.calendar_month), label: '달력'),
          BottomNavigationBarItem(icon: Icon(Icons.headset), label: '라미'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: '내 정보'),
        ],
      ),
    );
  }
}

// 인증서 검증 우회를 위한 HttpOverrides
class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);
    client.badCertificateCallback = (X509Certificate cert, String host, int port) => true;
    return client;
  }
}