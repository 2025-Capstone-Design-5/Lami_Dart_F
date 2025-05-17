import 'package:flutter/material.dart';
import 'main.dart';
import 'update_detail_page.dart';

class UpdatePage extends StatelessWidget {
  const UpdatePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // 화면 크기에 따라 폰트 크기를 조정하기 위한 변수
    final screenWidth = MediaQuery.of(context).size.width;
    final titleFontSize = screenWidth < 360 ? 18.0 : 22.0;
    final contentFontSize = screenWidth < 360 ? 16.0 : 18.0;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('업데이트'),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0.5,
        titleTextStyle: const TextStyle(
          color: Color(0xFF334066),
          fontWeight: FontWeight.w700,
          fontSize: 20,
        ),
        iconTheme: const IconThemeData(color: Color(0xFF334066)),
      ),
      backgroundColor: const Color(0xFFF3EFEE),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 16),
            // 업데이트 내역 카드
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFFCFAF8),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.25),
                      blurRadius: 4,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '업데이트 내역',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w600,
                          fontSize: titleFontSize,
                          color: Color(0xFF334066),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Icon(Icons.notifications, size: 24, color: Color(0xFF334066)),
                          const SizedBox(width: 16),
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const UpdateDetailPage(
                                      title: '24.04.15 업데이트 내역',
                                      date: '2024-04-15',
                                    ),
                                  ),
                                );
                              },
                              child: Text(
                                '24.04.15 업데이트 내역',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontWeight: FontWeight.w400,
                                  fontSize: contentFontSize,
                                  color: Colors.black,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Icon(Icons.notifications, size: 24, color: Color(0xFF334066)),
                          const SizedBox(width: 16),
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const UpdateDetailPage(
                                      title: '24.04.16 업데이트 내역',
                                      date: '2024-04-16',
                                    ),
                                  ),
                                );
                              },
                              child: Text(
                                '24.04.16 업데이트 내역',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontWeight: FontWeight.w400,
                                  fontSize: contentFontSize,
                                  color: Colors.black,
                                ),
                                overflow: TextOverflow.ellipsis,
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
            const Spacer(),
            // 하단 네비게이션 바
            BottomNavigationBar(
              currentIndex: 3,
              onTap: (index) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => MainScreen(initialIndex: index)),
                  (route) => false,
                );
              },
              backgroundColor: const Color(0xFFFCFAF8),
              selectedItemColor: Colors.blue,
              unselectedItemColor: Colors.grey,
              type: BottomNavigationBarType.fixed,
              selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w400),
              items: const [
                BottomNavigationBarItem(icon: Icon(Icons.home), label: '홈'),
                BottomNavigationBarItem(icon: Icon(Icons.calendar_month), label: '달력'),
                BottomNavigationBarItem(icon: Icon(Icons.headset), label: '헤드셋'),
                BottomNavigationBarItem(icon: Icon(Icons.person), label: '내정보'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}