import 'package:flutter/material.dart';
import 'shortest_route_page.dart';
import 'time_setting_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int selectedIconIndex = 0;
  TextEditingController searchController = TextEditingController();

  void _goToShortestRoutePage() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ShortestRoutePage()),
    );
  }

  void _goToTimeSettingPage() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const TimeSettingPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    double verticalGap = 24;
    return Scaffold(
      backgroundColor: const Color(0xFFF3EFEE),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 검색창
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.black26, width: 1),
                ),
                child: TextField(
                  controller: searchController,
                  decoration: const InputDecoration(
                    hintText: '출발, 도착지 검색',
                    prefixIcon: Icon(Icons.search, color: Colors.black54),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 14),
                  ),
                  style: const TextStyle(fontSize: 16),
                ),
              ),
              SizedBox(height: verticalGap),
              // 남은 준비 시간 카드
              GestureDetector(
                onTap: _goToTimeSettingPage,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 2,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Column(
                    children: const [
                      Text(
                        '남은 준비 시간',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.black87,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        '00:00:00',
                        style: TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                          letterSpacing: 2,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '+00:15',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.green,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: verticalGap),
              // 교통수단 아이콘 3개
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildSelectIcon(
                    icon: Icons.train,
                    label: '지하철',
                    selected: selectedIconIndex == 0,
                    onTap: () {
                      setState(() => selectedIconIndex = 0);
                      _goToShortestRoutePage();
                    },
                  ),
                  _buildSelectIcon(
                    icon: Icons.directions_bus,
                    label: '버스',
                    selected: selectedIconIndex == 1,
                    onTap: () {
                      setState(() => selectedIconIndex = 1);
                      _goToShortestRoutePage();
                    },
                  ),
                  _buildSelectIcon(
                    icon: Icons.directions_car,
                    label: '승용차',
                    selected: selectedIconIndex == 2,
                    onTap: () {
                      setState(() => selectedIconIndex = 2);
                      _goToShortestRoutePage();
                    },
                  ),
                ],
              ),
              SizedBox(height: verticalGap),
              // MM/DD 요일 + 오늘 일정 요약 카드
              Container(
                padding: const EdgeInsets.symmetric(vertical: 32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.black12, width: 1),
                ),
                child: Column(
                  children: const [
                    Text(
                      'MM/DD 요일',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    SizedBox(height: 12),
                    Text(
                      '오늘 일정 요약',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 8),
                    Text(
                      '캘린더 탭에서 간단하게 확인하세요',
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.black54,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              SizedBox(height: verticalGap),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSelectIcon({
    required IconData icon,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Icon(
            icon,
            size: 38,
            color: selected ? Colors.blue : Colors.grey.withOpacity(0.3),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: selected ? Colors.blue : Colors.grey.withOpacity(0.3),
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}