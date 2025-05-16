import 'package:flutter/material.dart';
import 'home_page.dart';
import 'calendar_page.dart';
import 'assistant_page.dart';
import 'mypage.dart';
import 'splash_screen.dart'; // 스플래시 화면 import 추가

void main() {
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
  const MainScreen({Key? key}) : super(key: key);

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int selectedNavIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: selectedNavIndex,
        children: const [
          HomePage(),
          CalendarPage(),
          AssistantPage(),
          MyPage(),
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
          BottomNavigationBarItem(icon: Icon(Icons.headset), label: '어시스턴트'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: '내 정보'),
        ],
      ),
    );
  }
}