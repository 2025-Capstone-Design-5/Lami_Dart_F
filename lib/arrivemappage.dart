import 'package:flutter/material.dart';
import 'dart:async';
import 'main.dart';
import 'search_history_service.dart';
import 'time_setting_page.dart';
import 'tmap_service.dart';
import 'favorite_service.dart';

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
  final FavoriteService _favoriteService = FavoriteService();

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
    _favoriteService.loadData();
    
    // 초기값 설정
    if (widget.initialDeparture != null) {
      searchedDeparture = widget.initialDeparture;
      searchedDepartureAddress = widget.initialDepartureAddress ?? widget.initialDeparture!;
      _departureController.text = widget.initialDeparture!;
    }
    if (widget.initialDestination != null) {
      searchedDestination = widget.initialDestination;
      searchedDestinationAddress = widget.initialDestinationAddress ?? widget.initialDestination!;
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
          
          // Tmap suggestions disabled: skip directly to confirm
          const SizedBox.shrink(),
          
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
        border: Border.all(color: Colors.grey[300]! ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: TextField(
        controller: controller,
        // Tmap search disabled: capture raw input only
        onChanged: (value) {
          setState(() {
            if (isDeparture) {
              searchedDeparture = value;
              searchedDepartureAddress = value;
            } else {
              searchedDestination = value;
              searchedDestinationAddress = value;
            }
            // Show map and confirm button when both inputs are non-null
            showMap = searchedDeparture != null && searchedDestination != null;
          });
        },
        // onTap disabled (previously opened search history or Tmap suggestions)
        // onTap: () => _onFieldTapped(isDeparture),
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
}