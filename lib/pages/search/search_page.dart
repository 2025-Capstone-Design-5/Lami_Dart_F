import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:ui';
import '../../main.dart';
import '../../search_history_service.dart';
import '../time_setting/time_setting_page.dart';
import '../../services/tmap_service.dart';
import '../../favorite_service.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../../config/server_config.dart';
import '../../models/summary_response.dart';
import '../route/route_results_page.dart';
import '../route/route_lookup_page.dart';

class SearchPage extends StatefulWidget {
  final String? initialDeparture;
  final String? initialDepartureAddress;
  final String? initialDestination;
  final String? initialDestinationAddress;
  
  const SearchPage({
    Key? key,
    this.initialDeparture,
    this.initialDepartureAddress,
    this.initialDestination,
    this.initialDestinationAddress,
  }) : super(key: key);

  @override
  State<SearchPage> createState() => _SearchPageState();
}

// 즐겨찾기 추가 다이얼로그 위젯
class AddFavoriteDialog extends StatefulWidget {
  final bool isDeparture;
  final String initialName;
  final String address;
  final Future<void> Function(String name, String category, String iconName) onSave;

  const AddFavoriteDialog({
    Key? key,
    required this.isDeparture,
    required this.initialName,
    required this.address,
    required this.onSave,
  }) : super(key: key);

  @override
  _AddFavoriteDialogState createState() => _AddFavoriteDialogState();
}

class _AddFavoriteDialogState extends State<AddFavoriteDialog> {
  late TextEditingController nameController;
  String selectedCategory = 'general';
  String selectedIcon = 'place';
  
  // 카테고리에 따른 아이콘 이름 매핑
  final Map<String, String> categoryToIconMap = {
    'general': 'place',
    'home': 'home',
    'work': 'work',
    'school': 'school',
    'restaurant': 'restaurant',
    'shopping': 'shopping_cart',
    'hospital': 'local_hospital',
    'gas_station': 'local_gas_station',
  };
  
  // 카테고리에 따른 아이콘 데이터 매핑
  final Map<String, IconData> categoryToIconData = {
    'general': Icons.place,
    'home': Icons.home,
    'work': Icons.work,
    'school': Icons.school,
    'restaurant': Icons.restaurant,
    'shopping': Icons.shopping_cart,
    'hospital': Icons.local_hospital,
    'gas_station': Icons.local_gas_station,
  };

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    nameController.dispose();
    super.dispose();
  }

  Widget _buildCategoryChip(String value, String label, IconData icon, Color color) {
    final isSelected = selectedCategory == value;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          selectedCategory = value;
          // 카테고리에 맞는 아이콘 이름 설정
          selectedIcon = categoryToIconMap[value] ?? 'place';
          print('카테고리 선택: $value, 아이콘: ${selectedIcon}');
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.2) : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(20),
          border: isSelected ? Border.all(color: color, width: 1.5) : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? color : Colors.grey.shade600,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? color : Colors.grey.shade700,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.isDeparture ? '출발지 즐겨찾기 추가' : '목적지 즐겨찾기 추가'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: '이름',
                hintText: '즐겨찾기 이름을 입력하세요',
              ),
            ),
            const SizedBox(height: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(bottom: 8.0),
                  child: Text(
                    '카테고리',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.black54,
                    ),
                  ),
                ),
                Wrap(
                  spacing: 8.0,
                  runSpacing: 8.0,
                  children: [
                    _buildCategoryChip('general', '일반', categoryToIconData['general']!, Colors.grey),
                    _buildCategoryChip('home', '집', categoryToIconData['home']!, Colors.green),
                    _buildCategoryChip('work', '직장', categoryToIconData['work']!, Colors.blue),
                    _buildCategoryChip('school', '학교', categoryToIconData['school']!, Colors.orange),
                    _buildCategoryChip('restaurant', '식당', categoryToIconData['restaurant']!, Colors.red),
                    _buildCategoryChip('shopping', '쇼핑', categoryToIconData['shopping']!, Colors.purple),
                    _buildCategoryChip('hospital', '병원', categoryToIconData['hospital']!, Colors.pink),
                    _buildCategoryChip('gas_station', '주유소', categoryToIconData['gas_station']!, Colors.brown),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        TextButton(
          onPressed: () async {
            final name = nameController.text.trim();
            if (name.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('이름을 입력해주세요')),
              );
              return;
            }
            print('저장: $name, 카테고리: $selectedCategory, 아이콘: $selectedIcon');
            try {
              // 다이얼로그를 먼저 닫고 저장 작업 수행
              Navigator.pop(context);
              await widget.onSave(name, selectedCategory, selectedIcon);
            } catch (e) {
              print('즐겨찾기 저장 에러: $e');
              // 이미 다이얼로그가 닫혔으므로 context가 유효한지 확인
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('즐겨찾기 저장 실패: $e')),
                );
              }
            }
          },
          child: const Text('추가'),
        ),
      ],
    );
  }
}

class _SearchPageState extends State<SearchPage> {
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
    _favoriteService.addListener(_updateUI);
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
    _favoriteService.removeListener(_updateUI);
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
      backgroundColor: const Color(0xFF0A0E27),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('출발지/도착지 검색'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 20,
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          // Gradient background
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF0A0E27),
                  const Color(0xFF1A1E3A),
                  const Color(0xFF0A0E27),
                ],
              ),
            ),
          ),
          // Gradient orbs
          Positioned(
            top: -100,
            right: -50,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF6366F1).withOpacity(0.3),
                    const Color(0xFF8B5CF6).withOpacity(0.1),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -150,
            left: -100,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF3B82F6).withOpacity(0.3),
                    const Color(0xFF06B6D4).withOpacity(0.1),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // Main content
          SafeArea(
            child: Column(
        children: [
          // 검색창 컨테이너
          Container(
            margin: const EdgeInsets.all(16.0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                      child: Container(
                        padding: const EdgeInsets.all(20.0),
            decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.2),
                            width: 1.5,
                ),
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
                              padding: const EdgeInsets.symmetric(vertical: 12.0),
                  child: Row(
                    children: [
                      Expanded(child: Container()),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(20),
                                    child: BackdropFilter(
                                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                                      child: Container(
                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                                          border: Border.all(
                                            color: Colors.white.withOpacity(0.2),
                                          ),
                        ),
                        child: IconButton(
                          onPressed: _swapLocations,
                                          icon: const Icon(Icons.swap_vert, color: Colors.white),
                          tooltip: '출발지/도착지 교환',
                                        ),
                                      ),
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
                    ),
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
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.blue.withOpacity(0.5),
                              width: 1.5,
                            ),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {
                  // Navigate to lookup page with loading indicator
                  final from = searchedDepartureAddress ?? searchedDeparture!;
                  final to = searchedDestinationAddress ?? searchedDestination!;
                  final now = DateTime.now();
                  final dateStr = DateFormat('yyyy-MM-dd').format(now);
                  final timeStr = DateFormat('HH:mm:ss').format(now);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => RouteLookupPage(
                        from: from,
                        to: to,
                        date: dateStr,
                        time: timeStr,
                      ),
                    ),
                  );
                },
                              borderRadius: BorderRadius.circular(20),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                child: Text(
                                  '확인',
                                  style: TextStyle(
                                    color: Colors.blue,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                ),
                      ),
              ),
            ),
          ],
              ],
            ),
          ),
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
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: _onSearchChanged, // 매개변수 수정됨
              onTap: () => _onFieldTapped(isDeparture),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                prefixIcon: Icon(icon, color: iconColor),
                suffixIcon: controller.text.isNotEmpty
                    ? IconButton(
                        onPressed: () => _clearField(controller, isDeparture),
                        icon: Icon(Icons.clear, color: Colors.white.withOpacity(0.7)),
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
          ),
          if ((isDeparture && searchedDeparture != null) || (!isDeparture && searchedDestination != null))
            IconButton(
              icon: const Icon(Icons.star_border, color: Colors.amber),
              onPressed: () {
                _showAddFavoriteDialog(isDeparture);
              },
            ),
        ],
      ),
    );
  }
  
  // 즐겨찾기 추가 다이얼로그
  void _showAddFavoriteDialog(bool isDeparture, {BuildContext? dialogContext, String? customPlace, String? customAddress}) {
    final String place = customPlace ?? (isDeparture 
        ? searchedDeparture ?? ''
        : searchedDestination ?? '');
    final String address = customAddress ?? (isDeparture 
        ? searchedDepartureAddress ?? ''
        : searchedDestinationAddress ?? '');
    final BuildContext ctx = dialogContext ?? context;
    
    showDialog(
      context: ctx,
      builder: (context) => AddFavoriteDialog(
        isDeparture: isDeparture,
        initialName: place,
        address: address,
        onSave: (name, category, iconName) async {
          print('onSave 호출: 이름=$name, 카테고리=$category, 아이콘=$iconName, 주소=$address');
          try {
            if (isDeparture) {
              print('출발지 즐겨찾기 추가 시도');
              await _favoriteService.addDepartureFavorite(
                place: name,
                category: category,
                address: address,
                iconName: iconName,
              );
            } else {
              print('목적지 즐겨찾기 추가 시도');
              await _favoriteService.addDestinationFavorite(
                place: name,
                category: category,
                address: address,
                iconName: iconName,
              );
            }
            print('즐겨찾기 추가 성공');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('즐겨찾기에 추가되었습니다')),
              );
            }
            return;
          } catch (e) {
            print('즐겨찾기 추가 에러: $e');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('즐겨찾기 추가 실패: $e')),
              );
            }
            // 에러를 다시 던져서 호출자가 처리할 수 있도록 함
            rethrow;
          }
        },
      ),
    );
  }

  // 이 메서드는 첫 번째 _showAddFavoriteDialog 메서드와 통합되었습니다.

  Widget _buildCategoryChip(String value, String label, IconData icon, Color color, StateSetter setState, String selectedValue, Function(String) onSelected) {
    final isSelected = selectedValue == value;
    
    return GestureDetector(
      onTap: () => onSelected(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.2) : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(20),
          border: isSelected ? Border.all(color: color, width: 1.5) : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? color : Colors.grey.shade600,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? color : Colors.grey.shade700,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 13,
              ),
            ),
          ],
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
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
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
                        color: Colors.white.withOpacity(0.9),
                  ),
                ),
                if (searchHistory.isNotEmpty)
                  TextButton(
                    onPressed: _clearAllHistory,
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red[300],
                        ),
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
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                          Icons.history,
                                color: Colors.white.withOpacity(0.7),
                                size: 20,
                              ),
                        ),
                        title: Text(
                          place['name'],
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                                color: Colors.white,
                              ),
                        ),
                        subtitle: Text(
                          place['address'],
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.6),
                              ),
                        ),
                        trailing: IconButton(
                              icon: Icon(
                                Icons.close,
                                size: 18,
                                color: Colors.white.withOpacity(0.5),
                              ),
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
                                color: Colors.white.withOpacity(0.3),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            '검색 기록이 없습니다',
                            style: TextStyle(
                              fontSize: 16,
                                  color: Colors.white.withOpacity(0.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
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
          child: CircularProgressIndicator(
            color: Colors.white,
          ),
        ),
      );
    }

    if (tmapSearchResults.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Text(
            '검색 결과가 없습니다.',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 16,
            ),
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
      child: ListView.separated(
        shrinkWrap: true,
        itemCount: tmapSearchResults.length,
            separatorBuilder: (context, index) => Divider(
              height: 1,
              color: Colors.white.withOpacity(0.2),
            ),
        itemBuilder: (context, index) {
          final place = tmapSearchResults[index];
          return ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: (isDepartureSearch ? Colors.blue : Colors.red).withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
              Icons.location_on,
              color: isDepartureSearch ? Colors.blue : Colors.red,
                    size: 20,
                  ),
            ),
            title: Text(
              place.name,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
                    color: Colors.white,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  place.address,
                  style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                    fontSize: 14,
                  ),
                ),
                if (place.category != null && place.category!.isNotEmpty)
                  Text(
                    place.category!,
                    style: TextStyle(
                          color: Colors.blue[300],
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
            onTap: () => _selectTmapPlace(place),
          );
        },
          ),
        ),
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
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Text(
            '검색 결과가 없습니다.',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 16,
            ),
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
      child: ListView.separated(
        shrinkWrap: true,
        itemCount: searchResults.length,
            separatorBuilder: (context, index) => Divider(
              height: 1,
              color: Colors.white.withOpacity(0.2),
            ),
        itemBuilder: (context, index) {
          final location = searchResults[index];
          return ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: (isDepartureSearch ? Colors.blue : Colors.red).withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
              Icons.location_on,
              color: isDepartureSearch ? Colors.blue : Colors.red,
                    size: 20,
                  ),
            ),
            title: Text(
              location['name']!,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
                    color: Colors.white,
              ),
            ),
            subtitle: Text(
              location['address']!,
              style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                fontSize: 14,
              ),
            ),
            onTap: () => _selectLocation(location),
          );
        },
          ),
        ),
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