import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'home_page.dart';
import 'calendar_page.dart';
import 'assistant_page.dart';
import 'mypage.dart';
import 'splash_screen.dart'; // 스플래시 화면 import 추가

/// 앱 시작 전에 환경변수를 로드합니다
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: ".env");
    debugPrint("[dotenv] loaded variables: ${dotenv.env}");
  } catch (e) {
    debugPrint("[dotenv] failed to load .env: $e");
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '메인화면',
      theme: ThemeData(
        fontFamily: 'Inter',
        scaffoldBackgroundColor: const Color(0xFFF3EFEE),
      ),
      home: const SplashScreen(), // 시작점을 스플래시 화면으로 변경
      debugShowCheckedModeBanner: false,
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
          BottomNavigationBarItem(icon: Icon(Icons.person), label: '내정보'),
        ],
      ),
    );
  }
  
  // 사용하지 않는 _buildPage 메서드 제거 또는 아래와 같이 수정
  // 필요한 경우에만 사용하세요
  /*
  Widget _buildPage(int index) {
    switch (index) {
      case 0:
        return const HomePage();
      case 1:
        return const CalendarPage();
      case 2:
        return const AssistantPage();
      case 3: // 마이페이지
        return MyPage(
          userName: widget.userName,
          userEmail: widget.userEmail,
        );
      default:
        return Container();
    }
  }
  */
}