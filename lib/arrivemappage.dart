import 'package:flutter/material.dart';
import 'dart:async';
import 'main.dart';
import 'search_history_service.dart';
import 'time_setting_page.dart';
import 'tmap_service.dart';

class ArriveMapPage extends StatefulWidget {
  final String? initialDeparture;
  final String? initialDepartureAddress;
  final String? initialDestination;
  final String? initialDestinationAddress;
  
  const ArriveMapPage({
    Key? key,
    this.initialDeparture,
    this.initialDepartureAddress,
    this.initialDestination,
    this.initialDestinationAddress,
  }) : super(key: key);

  @override
  State<ArriveMapPage> createState() => _ArriveMapPageState();
}

class _ArriveMapPageState extends State<ArriveMapPage> {
  final TextEditingController _departureController = TextEditingController();
  final TextEditingController _destinationController = TextEditingController();
  final SearchHistoryService _searchHistoryService = SearchHistoryService();

  String? searchedDeparture;
  String? searchedDepartureAddress;
  String? searchedDestination;
  String? searchedDestinationAddress;
  bool showSearchResults = false;
  bool showSearchHistory = true;
  bool showMap = false;
  bool isDepartureSearch = true;
  
  // TMAP API 관련 변수들 추가
  List<TmapPlace> tmapSearchResults = [];
  Timer? _debounceTimer;
  bool _isSearching = false;
  
  List<Map<String, String>> allLocations = [
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
    TmapService.initialize();
    _loadData();
    _searchHistoryService.addListener(_updateUI);
    
    // 초기값 설정
    if (widget.initialDeparture != null) {
      searchedDeparture = widget.initialDeparture;
      searchedDepartureAddress = widget.initialDepartureAddress;
      _departureController.text = widget.initialDeparture!;
    }
    
    if (widget.initialDestination != null) {
      searchedDestination = widget.initialDestination;
      searchedDestinationAddress = widget.initialDestinationAddress;
      _destinationController.text = widget.initialDestination!;
    }
    
    // 출발지와 도착지가 모두 설정되었으면 지도 표시
    if (searchedDeparture != null && searchedDestination != null) {
      showMap = true;
    }
  }

  void _updateUI() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _departureController.dispose();
    _destinationController.dispose();
    _searchHistoryService.removeListener(_updateUI);
    _debounceTimer?.cancel();
    super.dispose();
  }
  
  void _loadData() async {
    await _searchHistoryService.loadData();
    if (mounted) {
      setState(() {
        searchHistory = _searchHistoryService.getAllSearchHistory();
        searchHistory.sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));
        if (searchHistory.length > 5) {
          searchHistory = searchHistory.sublist(0, 5);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3EFEE),
      appBar: AppBar(
        title: const Text('출발지/도착지 검색'),
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
          // 검색창 컨테이너
          Container(
            margin: const EdgeInsets.all(16.0),
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                // 출발지 검색창
                _buildSearchField(
                  controller: _departureController,
                  hintText: '출발지를 입력하세요',
                  icon: Icons.my_location,
                  iconColor: Colors.blue,
                  isDeparture: true,
                ),
                
                // 교환 버튼
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    children: [
                      Expanded(child: Container()),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: IconButton(
                          onPressed: _swapLocations,
                          icon: const Icon(Icons.swap_vert, color: Colors.grey),
                          tooltip: '출발지/도착지 교환',
                        ),
                      ),
                      Expanded(child: Container()),
                    ],
                  ),
                ),
                
                // 목적지 검색창
                _buildSearchField(
                  controller: _destinationController,
                  hintText: '도착지를 입력하세요',
                  icon: Icons.location_on,
                  iconColor: Colors.red,
                  isDeparture: false,
                ),
              ],
            ),
          ),
          
          // 검색 결과 또는 검색 기록 표시
          Expanded(
            child: showSearchResults && searchResults.isNotEmpty
                ? _buildSearchResults()
                : _buildSearchHistory(),
          ),
          
          // 경로 정보 표시
          if (showMap && searchedDeparture != null && searchedDestination != null) ...[
            _buildRouteInfo(),
            const SizedBox(height: 16),
            Center(
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => TimeSettingPage(
                        departureName: searchedDeparture,
                        departureAddress: searchedDepartureAddress,
                        destinationName: searchedDestination,
                        destinationAddress: searchedDestinationAddress,
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
                child: const Text('확인'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSearchField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    required Color iconColor,
    required bool isDeparture,
  }) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: TextField(
        controller: controller,
        onChanged: _onSearchChanged, // 매개변수 수정됨
        onTap: () => _onFieldTapped(isDeparture),
        decoration: InputDecoration(
          hintText: hintText,
          prefixIcon: Icon(icon, color: iconColor),
          suffixIcon: controller.text.isNotEmpty
              ? IconButton(
                  onPressed: () => _clearField(controller, isDeparture),
                  icon: const Icon(Icons.clear, color: Colors.grey),
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildSearchResults() {
    // TMAP 검색 결과가 있으면 TMAP 결과 표시, 없으면 로컬 결과 표시
    if (tmapSearchResults.isNotEmpty || _isSearching) {
      return _buildTmapSearchResults();
    } else {
      return _buildLocalSearchResults(); // 기존 로컬 검색 결과
    }
  }

  Widget _buildSearchHistory() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '최근 검색',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                if (searchHistory.isNotEmpty)
                  TextButton(
                    onPressed: _clearAllHistory,
                    child: const Text('전체 삭제'),
                  ),
              ],
            ),
          ),
          Expanded(
            child: searchHistory.isNotEmpty
                ? ListView.builder(
                    itemCount: searchHistory.length,
                    itemBuilder: (context, index) {
                      final place = searchHistory[index];
                      return ListTile(
                        leading: const Icon(
                          Icons.history,
                          color: Colors.grey,
                        ),
                        title: Text(
                          place['name'],
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        subtitle: Text(
                          place['address'],
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.close, size: 18, color: Colors.grey),
                          onPressed: () => _removeHistoryItem(place),
                        ),
                        onTap: () => _selectHistoryItem(place),
                      );
                    },
                  )
                : Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.history,
                            size: 48,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            '검색 기록이 없습니다',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildRouteInfo() {
    return Container(
      margin: const EdgeInsets.all(16.0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(
                Icons.route,
                size: 24,
                color: Colors.green,
              ),
              const SizedBox(width: 8),
              const Text(
                '경로 정보',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildRouteItem(
            icon: Icons.my_location,
            iconColor: Colors.blue,
            title: '출발지',
            name: searchedDeparture ?? '미선택',
            address: searchedDepartureAddress ?? '',
          ),
          const SizedBox(height: 12),
          _buildRouteItem(
            icon: Icons.location_on,
            iconColor: Colors.red,
            title: '도착지',
            name: searchedDestination ?? '미선택',
            address: searchedDestinationAddress ?? '',
          ),
        ],
      ),
    );
  }

  Widget _buildRouteItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String name,
    required String address,
  }) {
    return Row(
      children: [
        Icon(icon, color: iconColor, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$title: $name',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (address.isNotEmpty)
                Text(
                  address,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  void _swapLocations() {
    setState(() {
      final tempDeparture = searchedDeparture;
      final tempDepartureAddress = searchedDepartureAddress;
      final tempDepartureText = _departureController.text;
      
      searchedDeparture = searchedDestination;
      searchedDepartureAddress = searchedDestinationAddress;
      _departureController.text = _destinationController.text;
      
      searchedDestination = tempDeparture;
      searchedDestinationAddress = tempDepartureAddress;
      _destinationController.text = tempDepartureText;
    });
  }

  void _onFieldTapped(bool isDeparture) {
    setState(() {
      this.isDepartureSearch = isDeparture;
      showSearchHistory = true;
      showSearchResults = false;
    });
  }

  void _clearField(TextEditingController controller, bool isDeparture) {
    setState(() {
      controller.clear();
      if (isDeparture) {
        searchedDeparture = null;
        searchedDepartureAddress = null;
      } else {
        searchedDestination = null;
        searchedDestinationAddress = null;
      }
      showSearchResults = false;
      showSearchHistory = true;
      showMap = false;
    });
  }

  // 수정된 _onSearchChanged 메서드 (매개변수 수정)
  void _onSearchChanged(String value) {
    if (value.isEmpty) {
      setState(() {
        showSearchResults = false;
        showSearchHistory = true;
        tmapSearchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      showSearchResults = true;
      showSearchHistory = false;
    });

    _debounceTimer?.cancel();
    
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _searchWithTmap(value);
    });
  }

  // TMAP API를 통한 검색
  Future<void> _searchWithTmap(String query) async {
    if (!mounted) return;
    
    try {
      setState(() {
        _isSearching = true;
      });
      
      // POI와 주소 검색을 동시에 실행
      final results = await Future.wait([
        TmapService.searchPlaces(query),
        TmapService.searchAddress(query),
      ]);
      
      final poiResults = results[0];
      final addressResults = results[1];
      
      // 결과 합치기
      final allResults = <TmapPlace>[];
      allResults.addAll(poiResults);
      allResults.addAll(addressResults);
      
      // 중복 제거 (이름과 주소가 같은 경우)
      final uniqueResults = <TmapPlace>[];
      final seen = <String>{};
      for (final result in allResults) {
        final key = '${result.name}_${result.address}';
        if (!seen.contains(key)) {
          seen.add(key);
          uniqueResults.add(result);
        }
      }
      
      setState(() {
        tmapSearchResults = uniqueResults.take(10).toList(); // 최대 10개 결과
        _isSearching = false;
        // 기존 searchResults도 업데이트 (호환성을 위해)
        searchResults = tmapSearchResults.map((place) => place.toMap()).toList();
      });
    } catch (e) {
      print('TMAP search error: $e');
      setState(() {
        _isSearching = false;
        // 오류 발생 시 로컬 데이터로 폴백
        _searchLocal(query);
      });
    }
  }

  void _searchLocal(String query) {
    final results = allLocations.where((location) {
      final name = location['name']!.toLowerCase();
      final address = location['address']!.toLowerCase();
      final searchQuery = query.toLowerCase();
      return name.contains(searchQuery) || address.contains(searchQuery);
    }).toList();

    setState(() {
      tmapSearchResults = [];
      searchResults = results;
    });
  }

  // TMAP 검색 결과 위젯
  Widget _buildTmapSearchResults() {
    if (_isSearching) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20.0),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (tmapSearchResults.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20.0),
          child: Text('검색 결과가 없습니다.'),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListView.separated(
        shrinkWrap: true,
        itemCount: tmapSearchResults.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final place = tmapSearchResults[index];
          return ListTile(
            leading: Icon(
              Icons.location_on,
              color: isDepartureSearch ? Colors.blue : Colors.red,
            ),
            title: Text(
              place.name,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  place.address,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
                if (place.category != null && place.category!.isNotEmpty)
                  Text(
                    place.category!,
                    style: TextStyle(
                      color: Colors.blue[600],
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
            onTap: () => _selectTmapPlace(place),
          );
        },
      ),
    );
  }

  void _selectTmapPlace(TmapPlace place) {
    setState(() {
      if (isDepartureSearch) {
        searchedDeparture = place.name;
        searchedDepartureAddress = place.address;
        _departureController.text = place.name;
      } else {
        searchedDestination = place.name;
        searchedDestinationAddress = place.address;
        _destinationController.text = place.name;
      }
      showSearchResults = false;
      showSearchHistory = false;
    });

    // 검색 기록에 저장
    _searchHistoryService.addSearchHistory(place.name, place.address);
    _loadData();
    _updateMapVisibility();
    _showSelectionSnackBar(place.name);
  }

  Widget _buildLocalSearchResults() {
    if (searchResults.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20.0),
          child: Text('검색 결과가 없습니다.'),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListView.separated(
        shrinkWrap: true,
        itemCount: searchResults.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final location = searchResults[index];
          return ListTile(
            leading: Icon(
              Icons.location_on,
              color: isDepartureSearch ? Colors.blue : Colors.red,
            ),
            title: Text(
              location['name']!,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            subtitle: Text(
              location['address']!,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
            onTap: () => _selectLocation(location),
          );
        },
      ),
    );
  }

  void _selectLocation(Map<String, String> location) {
    setState(() {
      if (isDepartureSearch) {
        searchedDeparture = location['name'];
        searchedDepartureAddress = location['address'];
        _departureController.text = location['name']!;
      } else {
        searchedDestination = location['name'];
        searchedDestinationAddress = location['address'];
        _destinationController.text = location['name']!;
      }
      showSearchResults = false;
      showSearchHistory = false;
    });

    // 검색 기록에 저장
    _searchHistoryService.addSearchHistory(location['name']!, location['address']!);
    _loadData();
    _updateMapVisibility();
    _showSelectionSnackBar(location['name']!);
  }

  // 중복 메서드 제거 - 하나만 유지
  void _showSelectionSnackBar(String placeName) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$placeName이(가) 선택되었습니다.'),
        duration: const Duration(seconds: 2),
        backgroundColor: Colors.green,
      ),
    );
  }

  // 중복 메서드 제거 - 하나만 유지
  void _updateMapVisibility() {
    if (searchedDeparture != null && searchedDestination != null) {
      setState(() {
        showMap = true;
      });
      // 경로 기록에 저장 추가
      _searchHistoryService.addRouteHistory(
        departureName: searchedDeparture!,
        departureAddress: searchedDepartureAddress ?? searchedDeparture!,
        destinationName: searchedDestination!,
        destinationAddress: searchedDestinationAddress ?? searchedDestination!,
      );
    }
  }

  void _saveRouteHistory(String name, String address) {
    _searchHistoryService.addSearchHistory(name, address);
  }

  void _selectHistoryItem(Map<String, dynamic> place) {
    final String addr = place['address'] == '사용자 입력' ? place['name'] : place['address'];
    setState(() {
      if (isDepartureSearch) {
        searchedDeparture = place['name'];
        searchedDepartureAddress = addr;
        _departureController.text = searchedDeparture!;
      } else {
        searchedDestination = place['name'];
        searchedDestinationAddress = addr;
        _destinationController.text = searchedDestination!;
      }
      
      _searchHistoryService.addSearchHistory(
        place['name'],
        addr,
      );
      _loadData();
      _updateMapVisibility();
    });
  }

  void _removeHistoryItem(Map<String, dynamic> place) {
    _searchHistoryService.removeSearchHistory(place['name']);
    setState(() {
      searchHistory.removeWhere((item) => item['name'] == place['name']);
    });
  }

  void _clearAllHistory() {
    _searchHistoryService.clearAllSearchHistory();
    setState(() {
      searchHistory = [];
    });
  }

  void _handleSearchSubmission(String value, bool isDeparture) {
    if (value.isEmpty) return;
    
    if (searchResults.isNotEmpty) {
      _selectLocation(searchResults.first);
    } else {
      setState(() {
        if (isDeparture) {
          searchedDeparture = value;
          searchedDepartureAddress = value;
        } else {
          searchedDestination = value;
          searchedDestinationAddress = value;
        }
        showSearchResults = false;
        showSearchHistory = true;
        
        _searchHistoryService.addSearchHistory(value, value);
        _loadData();
        _updateMapVisibility();
      });
      
      _showSelectionSnackBar(value);
    }
  }
}