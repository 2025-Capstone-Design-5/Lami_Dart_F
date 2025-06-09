import 'package:flutter/material.dart';
import '../../main.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({Key? key}) : super(key: key);

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool prepTimeEnabled = true;
  bool soundEnabled = true;
  int assistantSound = 1;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('설정'),
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
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 준비시간 기능 박스
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                    child: Row(
                      children: [
                        const Icon(Icons.settings, color: Color(0xFF334066), size: 32),
                        const SizedBox(width: 16),
                        const Text(
                          '준비시간 기능',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w400,
                            fontSize: 24,
                            color: Colors.black,
                          ),
                        ),
                        const Spacer(),
                        Switch(
                          value: prepTimeEnabled,
                          onChanged: (val) {
                            setState(() {
                              prepTimeEnabled = val;
                            });
                          },
                          activeColor: Colors.blue,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // 소리 박스
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                    child: Row(
                      children: [
                        const Icon(Icons.volume_up, color: Color(0xFF334066), size: 32),
                        const SizedBox(width: 16),
                        const Text(
                          '소리',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w400,
                            fontSize: 24,
                            color: Color(0xFF334066),
                          ),
                        ),
                        const Spacer(),
                        Switch(
                          value: soundEnabled,
                          onChanged: (val) {
                            setState(() {
                              soundEnabled = val;
                            });
                          },
                          activeColor: Colors.blue,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // 어시스턴트 소리 설정
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.person, color: Color(0xFF334066), size: 32),
                        const SizedBox(width: 16),
                        const Text(
                          '어시스턴트 소리 설정',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w400,
                            fontSize: 24,
                            color: Color(0xFF334066),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      decoration: BoxDecoration(
                        color: Color(0xFFF3EFEE),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              const Text(
                                '어시스턴트 소리 1',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontWeight: FontWeight.w400,
                                  fontSize: 20,
                                  color: Color(0xFF334066),
                                ),
                              ),
                              const Spacer(),
                              Radio<int>(
                                value: 1,
                                groupValue: assistantSound,
                                onChanged: (val) {
                                  setState(() {
                                    assistantSound = val!;
                                  });
                                },
                                activeColor: Colors.blue,
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              const Text(
                                '어시스턴트 소리 2',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontWeight: FontWeight.w400,
                                  fontSize: 20,
                                  color: Color(0xFF334066),
                                ),
                              ),
                              const Spacer(),
                              Radio<int>(
                                value: 2,
                                groupValue: assistantSound,
                                onChanged: (val) {
                                  setState(() {
                                    assistantSound = val!;
                                  });
                                },
                                activeColor: Colors.blue,
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              const Text(
                                '어시스턴트 소리 3',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontWeight: FontWeight.w400,
                                  fontSize: 20,
                                  color: Color(0xFF334066),
                                ),
                              ),
                              const Spacer(),
                              Radio<int>(
                                value: 3,
                                groupValue: assistantSound,
                                onChanged: (val) {
                                  setState(() {
                                    assistantSound = val!;
                                  });
                                },
                                activeColor: Colors.blue,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
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
                BottomNavigationBarItem(icon: Icon(Icons.person), label: '내 정보'),
              ],
            ),
          ],
        ),
      ),
    );
  }
} 