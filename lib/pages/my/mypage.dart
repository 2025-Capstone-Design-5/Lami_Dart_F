import 'package:flutter/material.dart';
import 'dart:ui';
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
      backgroundColor: const Color(0xFF0A0E27),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('내 정보'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 20,
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          // Gradient background
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF0A0E27),
                  const Color(0xFF1A1E3A),
                  const Color(0xFF0A0E27),
                ],
              ),
            ),
          ),
          // Gradient orbs
          Positioned(
            top: -100,
            right: -50,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF6366F1).withOpacity(0.3),
                    const Color(0xFF8B5CF6).withOpacity(0.1),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -150,
            left: -100,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF10B981).withOpacity(0.3),
                    const Color(0xFF34D399).withOpacity(0.1),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // Main content
          SafeArea(
            child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 32),
                  // Profile avatar with glass effect
                  ClipRRect(
                    borderRadius: BorderRadius.circular(50),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(50),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.2),
                            width: 2,
                          ),
                        ),
                        child: const Icon(Icons.person, size: 50, color: Colors.white),
                      ),
                    ),
            ),
            const SizedBox(height: 16),
            Text(
              widget.userName,
                    style: const TextStyle(
                      fontSize: 22, 
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.userEmail,
                    style: TextStyle(
                      fontSize: 16, 
                      color: Colors.white.withOpacity(0.7),
                    ),
            ),
            const SizedBox(height: 32),
                  // Menu items with glass effect
                  _buildGlassMenuItem(
                    icon: Icons.star,
                    iconColor: Colors.amber,
                    title: '자주 사용한 경로',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const FavoritePlacesPage()),
                );
              },
            ),
                  const SizedBox(height: 12),
                  _buildGlassMenuItem(
                    icon: Icons.notifications,
                    iconColor: Colors.blue,
                    title: '업데이트',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const UpdatePage()),
                );
              },
            ),
                  const SizedBox(height: 12),
                  _buildGlassMenuItem(
                    icon: Icons.settings,
                    iconColor: Colors.purple,
                    title: '설정',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SettingsPage()),
                );
              },
            ),
                  const SizedBox(height: 12),
                  _buildGlassMenuItem(
                    icon: Icons.logout,
                    iconColor: Colors.orange,
                    title: '로그아웃',
              onTap: () {
                _showLogoutConfirmationDialog(context);
              },
            ),
                  const SizedBox(height: 24),
                  _buildGlassMenuItem(
                    icon: Icons.delete_sweep,
                    iconColor: Colors.red,
                    title: '캐시 지우기',
              onTap: () {
                _clearCache();
              },
            ),
                  const SizedBox(height: 12),
                  _buildGlassMenuItem(
                    icon: Icons.notifications_active,
                    iconColor: Colors.green,
                    title: '푸시 알림 테스트',
              onTap: () {
                _testNotification();
              },
            ),
          ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassMenuItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required VoidCallback onTap,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withOpacity(0.2),
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: iconColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icon, color: iconColor, size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: Colors.white.withOpacity(0.5),
                    ),
                  ],
                ),
              ),
            ),
          ),
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