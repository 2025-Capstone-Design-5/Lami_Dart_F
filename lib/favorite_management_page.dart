import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/favorite_api_service.dart';
import 'models/favorite_route_model.dart';
import 'arrivemappage.dart';

class FavoriteManagementPage extends StatefulWidget {
  const FavoriteManagementPage({Key? key}) : super(key: key);

  @override
  State<FavoriteManagementPage> createState() => _FavoriteManagementPageState();
}

class _FavoriteManagementPageState extends State<FavoriteManagementPage> {
  late final FavoriteApiService _apiService;
  List<FavoriteRouteModel> favoriteList = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _initFavorites();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _initFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final googleId = prefs.getString('googleId') ?? '';
    _apiService = FavoriteApiService(googleId: googleId);
    await _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    setState(() { _loading = true; });
    try {
      final list = await _apiService.getFavorites();
      setState(() { favoriteList = list; });
    } catch (e) {
      print('즐겨찾기 불러오기 오류: $e');
    } finally {
      setState(() { _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
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
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showAddFavoriteDialog,
            tooltip: '즐겨찾기 추가',
          ),
        ],
      ),
      backgroundColor: const Color(0xFFF3EFEE),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.favorite, color: Colors.red, size: 24),
                const SizedBox(width: 8),
                const Text(
                  '즐겨찾는 장소',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '자주 가는 장소를 즐겨찾기에 추가하여 빠르게 검색하세요',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _loading
                ? const Center(child: CircularProgressIndicator())
                : (favoriteList.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        itemCount: favoriteList.length,
                        itemBuilder: (context, index) {
                          final fav = favoriteList[index];
                          return _buildFavoriteCard(fav, index);
                        },
                      )),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.favorite_border,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            '즐겨찾는 장소가 없습니다',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '자주 가는 장소를 추가해보세요',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _showAddFavoriteDialog,
            icon: const Icon(Icons.add),
            label: const Text('즐겨찾기 추가'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFavoriteCard(FavoriteRouteModel favorite, int index) {
    return Card(
      key: ValueKey(favorite.id),
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: CircleAvatar(
          child: Icon(Icons.place, color: Colors.white),
          backgroundColor: Colors.blue,
        ),
        title: Text(
          '${favorite.origin} → ${favorite.destination}',
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        subtitle: Text(
          '카테고리: ${favorite.category}',
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 14,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () async {
                await _apiService.removeFavorite(favorite.id);
                await _loadFavorites();
              },
            ),
            const Icon(Icons.drag_handle, color: Colors.grey),
          ],
        ),
        onTap: () => _selectFavoriteAsDestination({
          'origin': favorite.origin,
          'destination': favorite.destination,
        }),
      ),
    );
  }

  void _showAddFavoriteDialog() {
    String origin = '';
    String destination = '';
    String category = 'general';
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('즐겨찾기 추가'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: const InputDecoration(labelText: '출발지'),
              onChanged: (v) => origin = v,
            ),
            TextField(
              decoration: const InputDecoration(labelText: '목적지'),
              onChanged: (v) => destination = v,
            ),
            const SizedBox(height: 8),
            DropdownButton<String>(
              value: category,
              items: const [
                DropdownMenuItem(value: 'general', child: Text('General')),
                DropdownMenuItem(value: 'home', child: Text('집')),
                DropdownMenuItem(value: 'work', child: Text('직장')),
                DropdownMenuItem(value: 'school', child: Text('학교')),
              ],
              onChanged: (v) => category = v!,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _apiService.addFavorite(
                origin: origin,
                destination: destination,
                category: category,
              );
              await _loadFavorites();
            },
            child: const Text('추가'),
          ),
        ],
      ),
    );
  }

  void _selectFavoriteAsDestination(Map<String, dynamic> favorite) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ArriveMapPage(
          initialDestination: favorite['destination'],
          initialDestinationAddress: favorite['destination'],
        ),
      ),
    );
  }
}