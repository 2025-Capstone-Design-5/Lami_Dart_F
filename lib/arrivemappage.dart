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
  String? searchedAddress;
  bool showSearchResults = false;
  bool showMap = false;

  // 검색 결과 예시 데이터
  final List<Map<String, String>> searchResults = [
    {'name': '천안역', 'address': '충청남도 천안시 동남구 태조산길 103'},
    {'name': '아산역', 'address': '충청남도 아산시 배방읍 희망로 100'},
    {'name': '용산역', 'address': '서울특별시 용산구 한강대로 23길'},
  ];

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
                        onTap: () {
                          setState(() {
                            showSearchResults = true;
                            showMap = false;
                          });
                        },
                        onSubmitted: (value) {
                          setState(() {
                            showSearchResults = true;
                            showMap = false;
                          });
                        },
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.search, color: Color(0xFF334066)),
                      onPressed: () {
                        setState(() {
                          showSearchResults = true;
                          showMap = false;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
            // 검색 결과 또는 지도 표시
            Expanded(
              child: showMap
                  ? _buildMapView()
                  : showSearchResults
                      ? _buildSearchResults()
                      : _buildInitialView(),
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

  // 초기 화면 (검색 전)
  Widget _buildInitialView() {
    return Container(
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
      child: const Center(
        child: Text('도착지를 검색하세요.', style: TextStyle(fontSize: 18, color: Colors.black54)),
      ),
    );
  }

  // 검색 결과 화면
  Widget _buildSearchResults() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFFCFAF8),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: searchResults.length,
        separatorBuilder: (context, index) => const Divider(height: 16),
        itemBuilder: (context, index) {
          return GestureDetector(
            onTap: () {
              setState(() {
                searchedDestination = searchResults[index]['name'];
                searchedAddress = searchResults[index]['address'];
                showMap = true;
                showSearchResults = false;
              });
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      searchResults[index]['name'] ?? '',
                      style: const TextStyle(
                        fontWeight: FontWeight.w400,
                        fontSize: 25,
                        color: Color(0xFF334066),
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios, size: 16, color: Color(0xFF334066)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  searchResults[index]['address'] ?? '',
                  style: const TextStyle(
                    fontWeight: FontWeight.w400,
                    fontSize: 11,
                    color: Color(0xFF334066),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // 지도 화면
  Widget _buildMapView() {
    return Container(
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
      child: Column(
        children: [
          // 선택된 장소 정보
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFCFAF8),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  searchedDestination ?? '',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF334066),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  searchedAddress ?? '',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF334066),
                  ),
                ),
              ],
            ),
          ),
          // 지도 영역
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.location_on, color: Colors.red, size: 48),
                  const SizedBox(height: 16),
                  const Text(
                    '여기에 실제 지도가 표시됩니다.',
                    style: TextStyle(fontSize: 16, color: Colors.black54),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
