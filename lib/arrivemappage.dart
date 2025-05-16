import 'package:flutter/material.dart';
import 'main.dart';

class ArriveMapPage extends StatefulWidget {
  const ArriveMapPage({Key? key}) : super(key: key);

  @override
  State<ArriveMapPage> createState() => _ArriveMapPageState();
}

class _ArriveMapPageState extends State<ArriveMapPage> {
  final TextEditingController _searchController = TextEditingController();
  String? searchedDestination;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3EFEE),
      appBar: AppBar(
        title: const Text('출발, 도착지 검색'),
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
      body: SafeArea(
        child: Column(
          children: [
            // 검색 입력창
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFFCFAF8),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.25),
                      blurRadius: 4,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: const InputDecoration(
                          hintText: '도착지 검색',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        ),
                        style: const TextStyle(fontSize: 18),
                        onSubmitted: (value) {
                          setState(() {
                            searchedDestination = value;
                          });
                        },
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.search, color: Color(0xFF334066)),
                      onPressed: () {
                        setState(() {
                          searchedDestination = _searchController.text;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
            // 지도 영역 (예시: 구글맵 위젯 자리)
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: searchedDestination == null || searchedDestination!.isEmpty
                      ? const Text('도착지를 검색하세요.', style: TextStyle(fontSize: 18, color: Colors.black54))
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.location_on, color: Colors.red, size: 48),
                            const SizedBox(height: 8),
                            Text(
                              '도착지: $searchedDestination',
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 12),
                            const Text('여기에 실제 지도가 표시됩니다.'),
                          ],
                        ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
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
          BottomNavigationBarItem(icon: Icon(Icons.search), label: '검색'),
          BottomNavigationBarItem(icon: Icon(Icons.calendar_month), label: '달력'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: '내정보'),
        ],
      ),
    );
  }
}
