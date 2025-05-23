import 'package:flutter/material.dart';
import 'settingspage.dart';
import 'updatepage.dart';
import 'favorite_places_page.dart';
import 'login_screen.dart'; // 로그인 화면으로 이동하기 위한 import 추가
import 'search_history_service.dart';

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
  // 선택된 교통수단을 추적하는 변수 (0: 지하철, 1: 버스, 2: 승용차)
  int _selectedTransportation = 0;
  
  // 검색 기록 서비스
  final SearchHistoryService _searchHistoryService = SearchHistoryService();

  @override
  void initState() {
    super.initState();
    // 데이터 로드
    _loadMostUsedTransportation();
    
    // 검색 기록 변경 시 UI 업데이트
    _searchHistoryService.addListener(_loadMostUsedTransportation);
  }
  
  @override
  void dispose() {
    _searchHistoryService.removeListener(_loadMostUsedTransportation);
    super.dispose();
  }
  
  // 가장 많이 사용한 교통수단 로드
  void _loadMostUsedTransportation() {
    setState(() {
      _selectedTransportation = _searchHistoryService.getMostUsedTransportation();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('마이페이지'),
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
              widget.userName, // 하드코딩된 값 대신 전달받은 이름 사용
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              widget.userEmail, // 하드코딩된 값 대신 전달받은 이메일 사용
              style: const TextStyle(fontSize: 16, color: Colors.black54),
            ),
            const SizedBox(height: 32),
            // 교통수단 항목 - 선택 기능 추가
            // 교통수단 항목 - 자동 선택으로 변경 (클릭 기능 제거)
            Column(
              children: [
                Text(
                  '가장 많이 사용한 교통수단',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // 지하철 항목
                    Column(
                      children: [
                        Icon(
                          Icons.train,
                          size: 36,
                          color: _selectedTransportation == 0
                              ? Colors.blue
                              : Colors.grey,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '지하철',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: _selectedTransportation == 0
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                    // 버스 항목
                    Column(
                      children: [
                        Icon(
                          Icons.directions_bus,
                          size: 36,
                          color: _selectedTransportation == 1
                              ? Colors.green
                              : Colors.grey,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '버스',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: _selectedTransportation == 1
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                    // 승용차 항목
                    Column(
                      children: [
                        Icon(
                          Icons.directions_car,
                          size: 36,
                          color: _selectedTransportation == 2
                              ? Colors.orange
                              : Colors.grey,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '승용차',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: _selectedTransportation == 2
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
            ),
            const SizedBox(height: 24),
            // 즐겨찾는 장소 항목
            ListTile(
              leading: Icon(Icons.star, color: Colors.amber),
              title: Text('즐겨찾는 장소'),
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
            // ... 추가 메뉴
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
                Navigator.of(context).pop(); // 다이얼로그 닫기
              },
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // 다이얼로그 닫기
                _logout(context); // 로그아웃 처리
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
    // 여기에 실제 로그아웃 처리 로직 추가 (토큰 삭제, 사용자 정보 삭제 등)

    // 로그인 화면으로 이동 (이전 화면 스택 모두 제거)
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false, // 모든 이전 화면 제거
    );
  }
  
  // 교통수단 아이콘 가져오기
  IconData _getTransportationIcon(int type) {
    switch (type) {
      case 0:
        return Icons.train;
      case 1:
        return Icons.directions_bus;
      case 2:
        return Icons.directions_car;
      default:
        return Icons.train;
    }
  }
  
  // 교통수단 색상 가져오기
  Color _getTransportationColor(int type) {
    switch (type) {
      case 0:
        return Colors.blue;
      case 1:
        return Colors.green;
      case 2:
        return Colors.orange;
      default:
        return Colors.blue;
    }
  }
}