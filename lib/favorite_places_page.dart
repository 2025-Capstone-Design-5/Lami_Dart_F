import 'package:flutter/material.dart';
import 'search_history_service.dart';

class FavoritePlacesPage extends StatefulWidget {
  const FavoritePlacesPage({Key? key}) : super(key: key);

  @override
  State<FavoritePlacesPage> createState() => _FavoritePlacesPageState();
}

class _FavoritePlacesPageState extends State<FavoritePlacesPage> {
  // 검색 기록 서비스
  final SearchHistoryService _searchHistoryService = SearchHistoryService();
  
  // 자주 검색한 장소 목록
  List<Map<String, dynamic>> frequentPlaces = [];
  
  // 선택된 교통수단 필터 (null: 모든 교통수단, 0: 지하철, 1: 버스, 2: 승용차)
  int? _selectedTransportationFilter;
  
  @override
  void initState() {
    super.initState();
    // 데이터 로드
    _loadData();
    
    // 검색 기록 변경 시 UI 업데이트
    _searchHistoryService.addListener(_loadData);
  }
  
  @override
  void dispose() {
    _searchHistoryService.removeListener(_loadData);
    super.dispose();
  }
  
  // 데이터 로드
  void _loadData() {
    setState(() {
      frequentPlaces = _searchHistoryService.getMostSearchedPlaces(
        limit: 10, 
        transportationType: _selectedTransportationFilter
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('즐겨찾는 장소'),
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
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 교통수단 필터 UI
            Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // 전체 항목
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedTransportationFilter = null;
                        _loadData();
                      });
                    },
                    child: Column(
                      children: [
                        Icon(
                          Icons.all_inclusive,
                          size: 36,
                          color: _selectedTransportationFilter == null
                              ? Colors.purple
                              : Colors.grey,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '전체',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: _selectedTransportationFilter == null
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // 지하철 항목
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedTransportationFilter = 0;
                        _loadData();
                      });
                    },
                    child: Column(
                      children: [
                        Icon(
                          Icons.train,
                          size: 36,
                          color: _selectedTransportationFilter == 0
                              ? Colors.blue
                              : Colors.grey,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '지하철',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: _selectedTransportationFilter == 0
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
                        _selectedTransportationFilter = 1;
                        _loadData();
                      });
                    },
                    child: Column(
                      children: [
                        Icon(
                          Icons.directions_bus,
                          size: 36,
                          color: _selectedTransportationFilter == 1
                              ? Colors.green
                              : Colors.grey,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '버스',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: _selectedTransportationFilter == 1
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
                        _selectedTransportationFilter = 2;
                        _loadData();
                      });
                    },
                    child: Column(
                      children: [
                        Icon(
                          Icons.directions_car,
                          size: 36,
                          color: _selectedTransportationFilter == 2
                              ? Colors.orange
                              : Colors.grey,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '승용차',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: _selectedTransportationFilter == 2
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
            
            const Text(
              '자주 검색한 장소',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: frequentPlaces.isEmpty
                  ? Center(
                      child: Text(
                        _selectedTransportationFilter == null
                            ? '검색 기록이 없습니다.'
                            : '${_getTransportationName(_selectedTransportationFilter!)} 검색 기록이 없습니다.',
                        style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                      ),
                    )
                  : ListView.builder(
                      itemCount: frequentPlaces.length,
                      itemBuilder: (context, index) {
                        final place = frequentPlaces[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListTile(
                            leading: Icon(
                              _getTransportationIcon(place['transportationType'] ?? 0),
                              color: _getTransportationColor(place['transportationType'] ?? 0),
                              size: 32,
                            ),
                            title: Text(
                              place['name'],
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Text(place['address']),
                                const SizedBox(height: 4),
                                Text(
                                  '방문 횟수: ${place['count']}회',
                                  style: TextStyle(color: Colors.blue.shade700),
                                ),
                                Text(
                                  '교통수단: ${_getTransportationName(place['transportationType'] ?? 0)}',
                                  style: TextStyle(
                                    color: _getTransportationColor(place['transportationType'] ?? 0),
                                  ),
                                ),
                              ],
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.map, color: Colors.blue),
                              onPressed: () {
                                // 지도 페이지로 이동하는 기능 구현
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('${place['name']} 지도 보기')),
                                );
                              },
                            ),
                            isThreeLine: true,
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
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