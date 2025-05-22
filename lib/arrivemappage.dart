import 'package:flutter/material.dart';
import 'main.dart';
import 'search_history_service.dart';

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
  bool showSearchHistory = false;
  bool showMap = false;
  
  // 검색 기록 서비스
  final SearchHistoryService _searchHistoryService = SearchHistoryService();
  
  // 선택된 교통수단 (0: 지하철, 1: 버스, 2: 승용차)
  int _selectedTransportation = 0;

  // 검색 결과 예시 데이터
  final List<Map<String, String>> allLocations = [
    {'name': '천안역', 'address': '충청남도 천안시 동남구 태조산길 103'},
    {'name': '아산역', 'address': '충청남도 아산시 배방읍 희망로 100'},
    {'name': '용산역', 'address': '서울특별시 용산구 한강대로 23길'},
    {'name': '서울역', 'address': '서울특별시 중구 통일로 1'},
    {'name': '부산역', 'address': '부산광역시 동구 중앙대로 206'},
    {'name': '대전역', 'address': '대전광역시 동구 중앙로 215'},
    {'name': '광주역', 'address': '광주광역시 북구 무등로 235'},
    {'name': '대구역', 'address': '대구광역시 북구 태평로 161'},
  ];
  
  List<Map<String, String>> searchResults = [];
  List<Map<String, dynamic>> searchHistory = [];
  
  @override
  void initState() {
    super.initState();
    // 데이터 로드 (최초 1회만)
    _loadData();
    // 검색 기록 변경 시 UI만 갱신
    _searchHistoryService.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _searchHistoryService.removeListener(() {
      if (mounted) setState(() {});
    });
    super.dispose();
  }
  
  // 데이터 로드
  void _loadData() async {
    await _searchHistoryService.loadData();
    if (mounted) {
      setState(() {
        // 검색 기록을 가져와서 최신순으로 정렬
        searchHistory = _searchHistoryService.getAllSearchHistory();
        // 검색 횟수(count)를 기준으로 내림차순 정렬
        searchHistory.sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));
        print('검색 기록 로드됨: ${searchHistory.length}개 항목');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3EFEE),
      appBar: AppBar(
        title: const Text('도착지 검색'),
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
      body: Column(
        children: [
          // 교통수단 선택 UI
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // 지하철 항목
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedTransportation = 0;
                    });
                  },
                  child: Column(
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
                ),
                // 버스 항목
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedTransportation = 1;
                    });
                  },
                  child: Column(
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
                ),
                // 승용차 항목
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedTransportation = 2;
                    });
                  },
                  child: Column(
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
                ),
              ],
            ),
          ),
          
          // 검색창
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '도착지를 검색하세요',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                filled: true,
                fillColor: Colors.white,
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            _searchController.clear();
                            showSearchResults = false;
                            searchResults = [];
                          });
                        },
                      )
                    : null,
              ),
              onChanged: (value) {
                setState(() {
                  if (value.isEmpty) {
                    showSearchResults = false;
                    searchResults = [];
                  } else {
                    showSearchResults = true;
                    searchResults = allLocations
                        .where((location) =>
                            location['name']!.contains(value) ||
                            location['address']!.contains(value))
                        .toList();
                  }
                });
              },
              onSubmitted: (value) {
                // 검색어 제출 시 검색 기록에 추가
                if (value.isNotEmpty && searchResults.isNotEmpty) {
                  final selectedLocation = searchResults.first;
                  setState(() {
                    searchedDestination = selectedLocation['name'];
                    searchedAddress = selectedLocation['address'];
                    showMap = true;
                    showSearchResults = false;
                    
                    // 검색 기록 저장
                    _searchHistoryService.addSearchHistory(
                      searchedDestination!,
                      searchedAddress!,
                      _selectedTransportation
                    );
                    
                    // 검색 기록 다시 로드
                    _loadData();
                  });
                  
                  // 검색 완료 메시지
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('$searchedDestination 검색 완료 (${_getTransportationName(_selectedTransportation)})'),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                } else if (value.isNotEmpty) {
                  // 검색 결과가 없을 경우 직접 입력한 검색어를 기록
                  setState(() {
                    searchedDestination = value;
                    searchedAddress = '사용자 입력';
                    showMap = true;
                    showSearchResults = false;
                    
                    // 검색 기록 저장
                    _searchHistoryService.addSearchHistory(
                      searchedDestination!,
                      searchedAddress!,
                      _selectedTransportation
                    );
                    
                    // 검색 기록 다시 로드
                    _loadData();
                  });
                }
              },
              onTap: () {
                // 검색창을 탭했을 때 검색 기록 표시
                setState(() {
                  showSearchHistory = true;
                  // 검색 기록 다시 로드
                  _loadData();
                });
              },
            ),
          ),
          
          // 검색 결과와 검색 기록을 함께 표시하는 영역
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 검색 결과 표시 (검색어가 있을 때만)
                if (showSearchResults && searchResults.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      '검색 결과',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  
                if (showSearchResults)
                  Expanded(
                    child: ListView.builder(
                      itemCount: searchResults.length,
                      itemBuilder: (context, index) {
                        return ListTile(
                          title: Text(searchResults[index]['name']!),
                          subtitle: Text(searchResults[index]['address']!),
                          onTap: () {
                            setState(() {
                              searchedDestination = searchResults[index]['name'];
                              searchedAddress = searchResults[index]['address'];
                              showMap = true;
                              showSearchResults = false;
                              _searchController.text = searchedDestination!;
                              
                              // 검색 기록 저장
                              _searchHistoryService.addSearchHistory(
                                searchedDestination!,
                                searchedAddress!,
                                _selectedTransportation
                              );
                              
                              // 검색 기록 다시 로드
                              _loadData();
                            });
                            
                            // 검색 완료 메시지
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('$searchedDestination 검색 완료 (${_getTransportationName(_selectedTransportation)})'),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                
                // 검색 기록 표시 (항상 표시)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '최근 검색 기록',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (searchHistory.isNotEmpty)
                        TextButton(
                          onPressed: () {
                            _searchHistoryService.clearAllSearchHistory();
                            setState(() {
                              searchHistory = [];
                            });
                          },
                          child: const Text('전체 삭제'),
                        ),
                    ],
                  ),
                ),
                
                // 검색 기록 목록
                Expanded(
                  flex: 2,
                  child: searchHistory.isNotEmpty
                    ? ListView.builder(
                        itemCount: searchHistory.length,
                        itemBuilder: (context, index) {
                          final place = searchHistory[index];
                          return ListTile(
                            leading: Icon(
                              _getTransportationIcon(place['transportationType'] ?? 0),
                              color: _getTransportationColor(place['transportationType'] ?? 0),
                            ),
                            title: Text(place['name']),
                            subtitle: Text(place['address']),
                            // 검색 기록 삭제 부분만 수정 (약 350줄 근처)
                            trailing: IconButton(
                              icon: const Icon(Icons.close, size: 18),
                              onPressed: () {
                                // 교통수단 정보를 포함하여 삭제
                                _searchHistoryService.removeSearchHistory(
                                  place['name'],
                                  transportationType: place['transportationType']
                                );
                                setState(() {
                                  searchHistory.removeWhere((item) => 
                                    item['name'] == place['name'] && 
                                    item['transportationType'] == place['transportationType']
                                  );
                                });
                              },
                            ),
                            onTap: () {
                              setState(() {
                                searchedDestination = place['name'];
                                searchedAddress = place['address'];
                                _selectedTransportation = place['transportationType'] ?? 0;
                                showMap = true;
                                _searchController.text = searchedDestination!;
                                
                                // 검색 기록 업데이트
                                _searchHistoryService.addSearchHistory(
                                  searchedDestination!,
                                  searchedAddress!,
                                  _selectedTransportation
                                );
                              });
                            },
                          );
                        },
                      )
                    : Center(
                        child: Text(
                          '검색 기록이 없습니다.',
                          style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                        ),
                      ),
                ),
                
                // 지도 표시 (선택된 장소가 있을 때)
                if (showMap && searchedDestination != null)
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Container(
                      padding: const EdgeInsets.all(16.0),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.3),
                            spreadRadius: 1,
                            blurRadius: 5,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Icon(
                                _getTransportationIcon(_selectedTransportation),
                                size: 24,
                                color: _getTransportationColor(_selectedTransportation),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${_getTransportationName(_selectedTransportation)} 경로',
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '도착지: $searchedDestination',
                            style: const TextStyle(fontSize: 18),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '주소: $searchedAddress',
                            style: const TextStyle(fontSize: 14, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
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
  
  // 교통수단 이름 가져오기
  String _getTransportationName(int type) {
    switch (type) {
      case 0:
        return '지하철';
      case 1:
        return '버스';
      case 2:
        return '승용차';
      default:
        return '지하철';
    }
  }
}
