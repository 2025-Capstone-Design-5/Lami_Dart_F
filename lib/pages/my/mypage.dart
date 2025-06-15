import 'package:flutter/material.dart';
import 'favorite_places_page.dart';
import 'update_page.dart';
import 'settings_page.dart';
import '../auth/login_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/notification_service.dart';

// StatelessWidget에서 StatefulWidget으로 변경
class MyPage extends StatefulWidget {
  // 회원 정보를 저장할 변수 추가
  final String userName;
  final String userEmail;

  // 생성자 수정 - 회원 정보를 매개변수로 받음
  const MyPage({
    Key? key,
    this.userName = '홍길동', // 기본값 설정
    this.userEmail = 'myemail@email.com', // 기본값 설정
  }) : super(key: key);

  @override
  State<MyPage> createState() => _MyPageState();
}

class _MyPageState extends State<MyPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('내 정보'),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0.5,
        titleTextStyle: const TextStyle(
          color: Colors.black,
          fontWeight: FontWeight.w600,
          fontSize: 20,
        ),
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      backgroundColor: const Color(0xFFF3EFEE),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 32),
            const CircleAvatar(
              radius: 40,
              backgroundColor: Colors.blue,
              child: Icon(Icons.person, size: 50, color: Colors.white),
            ),
            const SizedBox(height: 16),
            Text(
              widget.userName,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              widget.userEmail,
              style: const TextStyle(fontSize: 16, color: Colors.black54),
            ),
            const SizedBox(height: 32),
            // 즐겨찾는 장소 항목
            ListTile(
              leading: Icon(Icons.star, color: Colors.amber),
              title: Text('자주 사용한 경로'),
              trailing: Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const FavoritePlacesPage()),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.notifications),
              title: Text('업데이트'),
              trailing: Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const UpdatePage()),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.settings),
              title: Text('설정'),
              trailing: Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SettingsPage()),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.logout),
              title: Text('로그아웃'),
              trailing: Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                // 로그아웃 처리 및 로그인 화면으로 이동
                _showLogoutConfirmationDialog(context);
              },
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: Icon(Icons.delete_sweep, color: Colors.red),
              title: Text('캐시 지우기'),
              onTap: () {
                _clearCache();
              },
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: Icon(Icons.notifications_active, color: Colors.blue),
              title: Text('푸시 알림 테스트'),
              onTap: () {
                _testNotification();
              },
            ),
          ],
        ),
      ),
    );
  }
  
  // 로그아웃 확인 다이얼로그
  void _showLogoutConfirmationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('로그아웃'),
          content: const Text('정말 로그아웃 하시겠습니까?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _logout(context);
              },
              child: const Text('확인'),
            ),
          ],
        );
      },
    );
  }

  // 로그아웃 처리 함수
  void _logout(BuildContext context) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
    );
  }

  // 캐시 정리 함수
  Future<void> _clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('캐시가 삭제되었습니다')),
    );
  }

  // 푸시 알림 테스트 함수
  Future<void> _testNotification() async {
    final id = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final scheduledDate = DateTime.now().add(const Duration(seconds: 5));
    await NotificationService.scheduleNotification(
      id: id,
      title: '테스트 알림',
      body: '푸시 알림이 작동합니다!',
      scheduledDate: scheduledDate,
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('5초 후에 알림이 도착합니다!')),
    );
  }
}