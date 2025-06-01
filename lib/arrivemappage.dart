import 'package:flutter/material.dart';
import 'main.dart';
import 'search_history_service.dart';

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
  String? searchedDeparture;
  String? searchedDestination;
  String? searchedDepartureAddress;
  String? searchedDestinationAddress;
  bool showSearchResults = false;
  bool showSearchHistory = true; // 기본적으로 검색 기록 표시
  bool showMap = false;
  bool isDepartureSearch = true;
  
  final SearchHistoryService _searchHistoryService = SearchHistoryService();

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
          if (showMap && searchedDeparture != null && searchedDestination != null)
            _buildRouteInfo(),
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
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        hintText: hintText,
        prefixIcon: Icon(icon, color: iconColor),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: iconColor, width: 2),
        ),
        filled: true,
        fillColor: Colors.grey[50],
        suffixIcon: controller.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear, color: Colors.grey),
                onPressed: () => _clearField(isDeparture),
              )
            : null,
      ),
      onChanged: (value) => _onSearchChanged(value, isDeparture),
      onSubmitted: (value) => _handleSearchSubmission(value, isDeparture),
      onTap: () => _onFieldTapped(isDeparture),
    );
  }

  Widget _buildSearchResults() {
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
            child: Text(
              '검색 결과',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: searchResults.length,
              itemBuilder: (context, index) {
                final location = searchResults[index];
                return ListTile(
                  leading: Icon(
                    Icons.location_on,
                    color: isDepartureSearch ? Colors.blue : Colors.red,
                  ),
                  title: Text(
                    location['name']!,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  subtitle: Text(
                    location['address']!,
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  onTap: () => _selectLocation(location),
                );
              },
            ),
          ),
        ],
      ),
    );
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

  void _onSearchChanged(String value, bool isDeparture) {
    setState(() {
      isDepartureSearch = isDeparture;
      if (value.isEmpty) {
        showSearchResults = false;
        showSearchHistory = true;
        searchResults = [];
      } else {
        showSearchResults = true;
        showSearchHistory = false;
        searchResults = allLocations
            .where((location) =>
                location['name']!.toLowerCase().contains(value.toLowerCase()) ||
                location['address']!.toLowerCase().contains(value.toLowerCase()))
            .toList();
      }
    });
  }

  void _onFieldTapped(bool isDeparture) {
    setState(() {
      isDepartureSearch = isDeparture;
      if (!showSearchResults) {
        showSearchHistory = true;
        _loadData();
      }
    });
  }

  void _clearField(bool isDeparture) {
    setState(() {
      if (isDeparture) {
        _departureController.clear();
        searchedDeparture = null;
        searchedDepartureAddress = null;
      } else {
        _destinationController.clear();
        searchedDestination = null;
        searchedDestinationAddress = null;
      }
      showSearchResults = false;
      showSearchHistory = true;
      searchResults = [];
      _updateMapVisibility();
    });
  }

  void _swapLocations() {
    setState(() {
      final tempController = _departureController.text;
      final tempDestination = searchedDeparture;
      final tempAddress = searchedDepartureAddress;
      
      _departureController.text = _destinationController.text;
      searchedDeparture = searchedDestination;
      searchedDepartureAddress = searchedDestinationAddress;
      
      _destinationController.text = tempController;
      searchedDestination = tempDestination;
      searchedDestinationAddress = tempAddress;
      
      _updateMapVisibility();
    });
  }

  void _selectLocation(Map<String, String> location) {
    setState(() {
      if (isDepartureSearch) {
        searchedDeparture = location['name'];
        searchedDepartureAddress = location['address'];
        _departureController.text = searchedDeparture!;
      } else {
        searchedDestination = location['name'];
        searchedDestinationAddress = location['address'];
        _destinationController.text = searchedDestination!;
      }
      showSearchResults = false;
      showSearchHistory = true;
      
      _searchHistoryService.addSearchHistory(
        location['name']!,
        location['address']!
      );
      _loadData();
      _updateMapVisibility();
      
      // 출발지와 도착지가 모두 설정되었으면 경로 기록 저장
      if (searchedDeparture != null && searchedDestination != null) {
        _saveRouteHistory();
      }
    });
    
    _showSelectionSnackBar(location['name']!);
  }

  // 경로 기록 저장 메서드 추가
  void _saveRouteHistory() {
    if (searchedDeparture != null && 
        searchedDestination != null && 
        searchedDepartureAddress != null && 
        searchedDestinationAddress != null) {
      _searchHistoryService.addRouteHistory(
        departureName: searchedDeparture!,
        departureAddress: searchedDepartureAddress!,
        destinationName: searchedDestination!,
        destinationAddress: searchedDestinationAddress!,
      );
    }
  }

  void _selectHistoryItem(Map<String, dynamic> place) {
    setState(() {
      if (isDepartureSearch) {
        searchedDeparture = place['name'];
        searchedDepartureAddress = place['address'];
        _departureController.text = searchedDeparture!;
      } else {
        searchedDestination = place['name'];
        searchedDestinationAddress = place['address'];
        _destinationController.text = searchedDestination!;
      }
      
      _searchHistoryService.addSearchHistory(
        place['name'],
        place['address']
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

  void _updateMapVisibility() {
    showMap = searchedDeparture != null && searchedDestination != null;
  }

  void _showSelectionSnackBar(String locationName) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${isDepartureSearch ? "출발지" : "도착지"}: $locationName 선택 완료',
        ),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _handleSearchSubmission(String value, bool isDeparture) {
    if (value.isEmpty) return;
    
    if (searchResults.isNotEmpty) {
      _selectLocation(searchResults.first);
    } else {
      // 직접 입력된 경우
      setState(() {
        if (isDeparture) {
          searchedDeparture = value;
          searchedDepartureAddress = '사용자 입력';
        } else {
          searchedDestination = value;
          searchedDestinationAddress = '사용자 입력';
        }
        showSearchResults = false;
        showSearchHistory = true;
        
        _searchHistoryService.addSearchHistory(value, '사용자 입력');
        _loadData();
        _updateMapVisibility();
      });
      
      _showSelectionSnackBar(value);
    }
  }
}