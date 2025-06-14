import 'package:flutter/material.dart';
import 'dart:async';
import '../../favorite_service.dart';
import '../../models/favorite_route_model.dart';
import '../../services/tmap_service.dart';
import '../search/search_page.dart';

class FavoriteManagementPage extends StatefulWidget {
  const FavoriteManagementPage({Key? key}) : super(key: key);

  @override
  State<FavoriteManagementPage> createState() => _FavoriteManagementPageState();
}

class _FavoriteManagementPageState extends State<FavoriteManagementPage> with SingleTickerProviderStateMixin {
  final FavoriteService _favoriteService = FavoriteService();
  List<FavoriteRouteModel> _favorites = [];
  String _selectedCategory = 'all'; // 기본값은 '전체'
  
  // 탭 컨트롤러 추가
  late TabController _tabController;
  
  // 출발지/목적지 추가 관련 변수
  final TextEditingController _placeNameController = TextEditingController();
  final TextEditingController _placeAddressController = TextEditingController();
  String _selectedAddCategory = 'general';
  String _selectedAddIconName = 'place';

  // TMAP 검색 관련 변수
  List<TmapPlace> _tmapSearchResults = [];
  bool _isSearching = false;
  bool _showSearchResults = false;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _favoriteService.loadData();
    _loadFavorites();
    _favoriteService.addListener(_loadFavorites);
    
    // 탭 컨트롤러 초기화
    _tabController = TabController(length: 3, vsync: this);
    
    // TMAP 초기화
    TmapService.initialize();
  }

  @override
  void dispose() {
    _favoriteService.removeListener(_loadFavorites);
    _placeNameController.dispose();
    _placeAddressController.dispose();
    _tabController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _loadFavorites() {
    setState(() {
      _favorites = _favoriteService.favoriteList;
    });
  }

  // 카테고리별 즐겨찾기 필터링
  List<FavoriteRouteModel> _getFilteredFavorites() {
    if (_selectedCategory == 'all') {
      return _favorites;
    } else {
      return _favorites.where((favorite) => favorite.category == _selectedCategory).toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredFavorites = _getFilteredFavorites();

    return Scaffold(
      appBar: AppBar(
        title: const Text('즐겨찾기 관리'),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0.5,
        titleTextStyle: const TextStyle(
          color: Colors.black,
          fontWeight: FontWeight.w600,
          fontSize: 20,
        ),
        iconTheme: const IconThemeData(color: Colors.black),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '즐겨찾기 목록'),
            Tab(text: '출발지 추가'),
            Tab(text: '목적지 추가'),
          ],
          labelColor: Colors.blue,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.blue,
        ),
      ),
      backgroundColor: const Color(0xFFF3EFEE),
      body: TabBarView(
        controller: _tabController,
        children: [
          // 첫 번째 탭: 즐겨찾기 목록
          Column(
            children: [
              // 카테고리 필터 탭
              _buildCategoryTabs(),
              
              // 즐겨찾기 목록
              Expanded(
                child: filteredFavorites.isEmpty
                    ? _buildEmptyState()
                    : _buildFavoritesList(filteredFavorites),
              ),
            ],
          ),
          
          // 두 번째 탭: 출발지 추가
          _buildAddFavoriteTab(true),
          
          // 세 번째 탭: 목적지 추가
          _buildAddFavoriteTab(false),
        ],
      ),
    );
  }

  // 즐겨찾기 추가 탭 위젯
  Widget _buildAddFavoriteTab(bool isDeparture) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    isDeparture ? '출발지 즐겨찾기 추가' : '목적지 즐겨찾기 추가',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _placeNameController,
                    decoration: InputDecoration(
                      labelText: '장소 이름',
                      hintText: '장소 이름을 입력하세요',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      prefixIcon: Icon(
                        isDeparture ? Icons.my_location : Icons.location_on,
                        color: isDeparture ? Colors.blue : Colors.red,
                      ),
                      suffixIcon: _placeNameController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                setState(() {
                                  _placeNameController.clear();
                                  _showSearchResults = false;
                                  _tmapSearchResults = [];
                                });
                              },
                            )
                          : null,
                    ),
                    onChanged: _onSearchChanged,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _placeAddressController,
                    decoration: InputDecoration(
                      labelText: '주소',
                      hintText: '주소를 입력하세요',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      prefixIcon: const Icon(Icons.home, color: Colors.grey),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    '카테고리',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8.0,
                    runSpacing: 8.0,
                    children: [
                      _buildAddCategoryChip('general', '일반', Icons.place, Colors.grey),
                      _buildAddCategoryChip('home', '집', Icons.home, Colors.green),
                      _buildAddCategoryChip('work', '직장', Icons.work, Colors.blue),
                      _buildAddCategoryChip('school', '학교', Icons.school, Colors.orange),
                      _buildAddCategoryChip('restaurant', '식당', Icons.restaurant, Colors.red),
                      _buildAddCategoryChip('shopping', '쇼핑', Icons.shopping_cart, Colors.purple),
                      _buildAddCategoryChip('hospital', '병원', Icons.local_hospital, Colors.pink),
                      _buildAddCategoryChip('gas_station', '주유소', Icons.local_gas_station, Colors.brown),
                    ],
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: () => _addFavorite(isDeparture),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDeparture ? Colors.blue : Colors.red,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: Text(
                      isDeparture ? '출발지 즐겨찾기 추가' : '목적지 즐겨찾기 추가',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // TMAP 검색 결과 표시
          if (_showSearchResults && _tmapSearchResults.isNotEmpty)
            Card(
              margin: const EdgeInsets.only(top: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 2,
              child: Container(
                constraints: const BoxConstraints(maxHeight: 300),
                child: _buildTmapSearchResults(isDeparture),
              ),
            ),
          
          // 검색 중 로딩 표시
          if (_isSearching)
            const Padding(
              padding: EdgeInsets.only(top: 16.0),
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  // TMAP 검색 결과 위젯
  Widget _buildTmapSearchResults(bool isDeparture) {
    return ListView.builder(
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      itemCount: _tmapSearchResults.length,
      itemBuilder: (context, index) {
        final place = _tmapSearchResults[index];
        return ListTile(
          leading: Icon(
            place.category?.contains('주소') == true ? Icons.location_on : Icons.place,
            color: isDeparture ? Colors.blue : Colors.red,
          ),
          title: Text(
            place.name,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          subtitle: Text(
            place.address,
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          onTap: () => _selectTmapPlace(place, isDeparture),
        );
      },
    );
  }

  // TMAP 장소 선택 처리
  void _selectTmapPlace(TmapPlace place, bool isDeparture) {
    setState(() {
      _placeNameController.text = place.name;
      _placeAddressController.text = place.address;
      _showSearchResults = false;
    });
  }

  // 검색어 변경 처리
  void _onSearchChanged(String value) {
    if (value.isEmpty) {
      setState(() {
        _showSearchResults = false;
        _tmapSearchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _showSearchResults = true;
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
        _tmapSearchResults = uniqueResults.take(10).toList(); // 최대 10개 결과
        _isSearching = false;
      });
    } catch (e) {
      print('TMAP search error: $e');
      setState(() {
        _isSearching = false;
        _tmapSearchResults = [];
      });
    }
  }

  // 즐겨찾기 추가 카테고리 칩 위젯
  Widget _buildAddCategoryChip(String value, String label, IconData icon, Color color) {
    final isSelected = _selectedAddCategory == value;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedAddCategory = value;
          _selectedAddIconName = _getCategoryIconName(value);
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

  // 카테고리에 따른 아이콘 이름 반환
  String _getCategoryIconName(String category) {
    switch (category) {
      case 'home': return 'home';
      case 'work': return 'work';
      case 'school': return 'school';
      case 'restaurant': return 'restaurant';
      case 'shopping': return 'shopping_cart';
      case 'hospital': return 'local_hospital';
      case 'gas_station': return 'local_gas_station';
      default: return 'place';
    }
  }

  // 즐겨찾기 추가 기능
  void _addFavorite(bool isDeparture) async {
    final name = _placeNameController.text.trim();
    final address = _placeAddressController.text.trim();
    
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('장소 이름을 입력해주세요')),
      );
      return;
    }
    
    try {
      if (isDeparture) {
        await _favoriteService.addDepartureFavorite(
          place: name,
          category: _selectedAddCategory,
          address: address.isEmpty ? name : address,
          iconName: _selectedAddIconName,
        );
      } else {
        await _favoriteService.addDestinationFavorite(
          place: name,
          category: _selectedAddCategory,
          address: address.isEmpty ? name : address,
          iconName: _selectedAddIconName,
        );
      }
      
      // 입력 필드 초기화
      _placeNameController.clear();
      _placeAddressController.clear();
      setState(() {
        _selectedAddCategory = 'general';
        _selectedAddIconName = 'place';
        _showSearchResults = false;
        _tmapSearchResults = [];
      });
      
      // 성공 메시지 표시
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${isDeparture ? '출발지' : '목적지'} 즐겨찾기가 추가되었습니다')),
      );
      
      // 즐겨찾기 목록 탭으로 이동
      _tabController.animateTo(0);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('즐겨찾기 추가 실패: $e')),
      );
    }
  }

  Widget _buildCategoryTabs() {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(vertical: 8),
      color: Colors.white,
      child: Row(
        children: [
          // 카테고리 탭 목록
          Expanded(
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _buildCategoryTab('all', '전체'),
                _buildCategoryTab('general', '일반'),
                _buildCategoryTab('home', '집'),
                _buildCategoryTab('work', '직장'),
                _buildCategoryTab('school', '학교'),
                _buildCategoryTab('restaurant', '식당'),
                _buildCategoryTab('shopping', '쇼핑'),
                _buildCategoryTab('hospital', '병원'),
                _buildCategoryTab('gas_station', '주유소'),
              ],
            ),
          ),
          
          // 전체 삭제 버튼
          if (_favorites.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: ElevatedButton.icon(
                onPressed: () => _showDeleteAllConfirmDialog(),
                icon: const Icon(Icons.delete_sweep, color: Colors.white),
                label: const Text('전체 삭제', style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                ),
              ),
            ),
        ],
      ),
    );
  }
  
  // 전체 삭제 확인 다이얼로그
  void _showDeleteAllConfirmDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('즐겨찾기 전체 삭제'),
        content: const Text('모든 즐겨찾기를 삭제하시겠습니까?\n이 작업은 되돌릴 수 없습니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              // 로딩 표시
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => const Center(
                  child: CircularProgressIndicator(),
                ),
              );
              
              try {
                await _favoriteService.removeAllFavorites();
                // 로딩 다이얼로그 닫기
                Navigator.pop(context);
                
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('모든 즐겨찾기가 삭제되었습니다')),
                );
              } catch (e) {
                // 로딩 다이얼로그 닫기
                Navigator.pop(context);
                
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('즐겨찾기 전체 삭제 실패: $e')),
                );
              }
            },
            child: const Text('삭제', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryTab(String category, String label) {
    final isSelected = _selectedCategory == category;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedCategory = category;
        });
      },
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black87,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildFavoritesList(List<FavoriteRouteModel> favorites) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: favorites.length,
      itemBuilder: (context, index) {
        final favorite = favorites[index];
        return _buildFavoriteCard(favorite);
      },
    );
  }

  Widget _buildFavoriteCard(FavoriteRouteModel favorite) {
    final iconData = _getFavoriteIconData(favorite.iconName.isNotEmpty ? favorite.iconName : favorite.category);
    final iconColor = _getFavoriteIconColor(favorite.iconName.isNotEmpty ? favorite.iconName : favorite.category);
    final categoryLabel = _getCategoryLabel(favorite.category);
    
    // 표시할 장소 이름 결정
    String placeName = favorite.isDeparture ? favorite.origin : favorite.destination;
    String placeAddress = favorite.isDeparture ? favorite.originAddress : favorite.destinationAddress;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: iconColor,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Center(
            child: Icon(
              iconData,
              color: Colors.white,
              size: 24,
            ),
          ),
        ),
        title: Text(
          placeName,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              placeAddress,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    categoryLabel,
                    style: TextStyle(
                      color: iconColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: favorite.isDeparture ? Colors.blue.withOpacity(0.2) : Colors.red.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    favorite.isDeparture ? '출발지' : '목적지',
                    style: TextStyle(
                      color: favorite.isDeparture ? Colors.blue : Colors.red,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete, color: Colors.red),
          onPressed: () => _showDeleteConfirmDialog(favorite),
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SearchPage(
                initialDeparture: favorite.isDeparture ? favorite.origin : null,
                initialDepartureAddress: favorite.isDeparture ? favorite.originAddress : null,
                initialDestination: !favorite.isDeparture ? favorite.destination : null,
                initialDestinationAddress: !favorite.isDeparture ? favorite.destinationAddress : null,
              ),
            ),
          ).then((_) {
            _favoriteService.loadData();
            _loadFavorites();
          });
        },
      ),
    );
  }

  void _showDeleteConfirmDialog(FavoriteRouteModel favorite) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('즐겨찾기 삭제'),
        content: Text('${favorite.isDeparture ? favorite.origin : favorite.destination}을(를) 즐겨찾기에서 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () async {
              await _favoriteService.removeFavorite(favorite.id);
              await _favoriteService.loadData();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('즐겨찾기가 삭제되었습니다')),
              );
            },
            child: const Text('삭제', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.star_border,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            _selectedCategory == 'all' 
                ? '즐겨찾기가 없습니다'
                : '${_getCategoryLabel(_selectedCategory)} 카테고리에 즐겨찾기가 없습니다',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              // 출발지 추가 탭으로 이동
              _tabController.animateTo(1);
            },
            icon: const Icon(Icons.add),
            label: const Text('즐겨찾기 추가하기'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  // 즐겨찾기 아이콘 데이터
  IconData _getFavoriteIconData(String iconName) {
    switch (iconName) {
      case 'home': return Icons.home;
      case 'work': return Icons.work;
      case 'school': return Icons.school;
      case 'restaurant': return Icons.restaurant;
      case 'shopping_cart': return Icons.shopping_cart;
      case 'local_hospital': return Icons.local_hospital;
      case 'local_gas_station': return Icons.local_gas_station;
      default: return Icons.place;
    }
  }

  // 즐겨찾기 아이콘 색상
  Color _getFavoriteIconColor(String iconName) {
    switch (iconName) {
      case 'home': return Colors.green;
      case 'work': return Colors.blue;
      case 'school': return Colors.orange;
      case 'restaurant': return Colors.red;
      case 'shopping_cart': return Colors.purple;
      case 'local_hospital': return Colors.pink;
      case 'local_gas_station': return Colors.brown;
      default: return Colors.grey;
    }
  }

  // 즐겨찾기 카테고리 레이블 (한글)
  String _getCategoryLabel(String category) {
    switch (category) {
      case 'general': return '일반';
      case 'home': return '집';
      case 'work': return '직장';
      case 'school': return '학교';
      case 'restaurant': return '식당';
      case 'shopping': return '쇼핑';
      case 'hospital': return '병원';
      case 'gas_station': return '주유소';
      default: return category;
    }
  }
}