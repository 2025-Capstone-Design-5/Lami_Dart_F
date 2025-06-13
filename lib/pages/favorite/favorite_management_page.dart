import 'package:flutter/material.dart';
import '../../favorite_service.dart';
import '../../models/favorite_route_model.dart';
import '../search/search_page.dart';

class FavoriteManagementPage extends StatefulWidget {
  const FavoriteManagementPage({Key? key}) : super(key: key);

  @override
  State<FavoriteManagementPage> createState() => _FavoriteManagementPageState();
}

class _FavoriteManagementPageState extends State<FavoriteManagementPage> {
  final FavoriteService _favoriteService = FavoriteService();
  List<FavoriteRouteModel> _favorites = [];
  String _selectedCategory = 'all'; // 기본값은 '전체'

  @override
  void initState() {
    super.initState();
    _favoriteService.loadData();
    _loadFavorites();
    _favoriteService.addListener(_loadFavorites);
  }

  @override
  void dispose() {
    _favoriteService.removeListener(_loadFavorites);
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
      ),
      backgroundColor: const Color(0xFFF3EFEE),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const SearchPage(),
            ),
          ).then((_) {
            _favoriteService.loadData();
            _loadFavorites();
          });
        },
        backgroundColor: Colors.blue,
        child: const Icon(Icons.add),
      ),
      body: Column(
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
    );
  }

  Widget _buildCategoryTabs() {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(vertical: 8),
      color: Colors.white,
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
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SearchPage(),
                ),
              ).then((_) {
                _favoriteService.loadData();
                _loadFavorites();
              });
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
      case 'shopping': return Icons.shopping_cart;
      case 'hospital': return Icons.local_hospital;
      case 'gas_station': return Icons.local_gas_station;
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
      case 'shopping': return Colors.purple;
      case 'hospital': return Colors.pink;
      case 'gas_station': return Colors.brown;
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