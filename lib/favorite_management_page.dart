import 'package:flutter/material.dart';
import 'favorite_service.dart';
import 'arrivemappage.dart';

class FavoriteManagementPage extends StatefulWidget {
  const FavoriteManagementPage({Key? key}) : super(key: key);

  @override
  State<FavoriteManagementPage> createState() => _FavoriteManagementPageState();
}

class _FavoriteManagementPageState extends State<FavoriteManagementPage> {
  final FavoriteService _favoriteService = FavoriteService();
  List<Map<String, dynamic>> favoriteList = [];

  @override
  void initState() {
    super.initState();
    _loadData();
    _favoriteService.addListener(_loadData);
  }

  @override
  void dispose() {
    _favoriteService.removeListener(_loadData);
    super.dispose();
  }

  void _loadData() {
    favoriteList = _favoriteService.getFavoriteList();
    setState(() {});
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
              child: favoriteList.isEmpty
                  ? _buildEmptyState()
                  : ReorderableListView.builder(
                      itemCount: favoriteList.length,
                      onReorder: (oldIndex, newIndex) {
                        _favoriteService.reorderFavorites(oldIndex, newIndex);
                      },
                      itemBuilder: (context, index) {
                        final favorite = favoriteList[index];
                        return _buildFavoriteCard(favorite, index);
                      },
                    ),
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

  Widget _buildFavoriteCard(Map<String, dynamic> favorite, int index) {
    return Card(
      key: ValueKey(favorite['name']),
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getIconColor(favorite['icon']),
          child: Icon(
            _getIconData(favorite['icon']),
            color: Colors.white,
            size: 20,
          ),
        ),
        title: Text(
          favorite['name'],
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        subtitle: Text(
          favorite['address'].isEmpty ? '주소 미설정' : favorite['address'],
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 14,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.blue),
              onPressed: () => _showEditFavoriteDialog(favorite),
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => _showDeleteConfirmDialog(favorite['name']),
            ),
            const Icon(Icons.drag_handle, color: Colors.grey),
          ],
        ),
        onTap: () => _selectFavoriteAsDestination(favorite),
      ),
    );
  }

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'home':
        return Icons.home;
      case 'work':
        return Icons.work;
      case 'school':
        return Icons.school;
      case 'restaurant':
        return Icons.restaurant;
      case 'shopping':
        return Icons.shopping_cart;
      case 'hospital':
        return Icons.local_hospital;
      case 'gas_station':
        return Icons.local_gas_station;
      default:
        return Icons.place;
    }
  }

  Color _getIconColor(String iconName) {
    switch (iconName) {
      case 'home':
        return Colors.green;
      case 'work':
        return Colors.blue;
      case 'school':
        return Colors.orange;
      case 'restaurant':
        return Colors.red;
      case 'shopping':
        return Colors.purple;
      case 'hospital':
        return Colors.pink;
      case 'gas_station':
        return Colors.brown;
      default:
        return Colors.grey;
    }
  }

  void _showAddFavoriteDialog() {
    _showFavoriteDialog();
  }

  void _showEditFavoriteDialog(Map<String, dynamic> favorite) {
    _showFavoriteDialog(
      isEdit: true,
      initialName: favorite['name'],
      initialAddress: favorite['address'],
      initialIcon: favorite['icon'],
    );
  }

  void _showFavoriteDialog({
    bool isEdit = false,
    String? initialName,
    String? initialAddress,
    String? initialIcon,
  }) {
    final nameController = TextEditingController(text: initialName ?? '');
    final addressController = TextEditingController(text: initialAddress ?? '');
    String selectedIcon = initialIcon ?? 'place';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isEdit ? '즐겨찾기 수정' : '즐겨찾기 추가'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: '장소 이름',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: addressController,
                decoration: InputDecoration(
                  labelText: '주소',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.search),
                    onPressed: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ArriveMapPage(),
                        ),
                      );
                      if (result != null) {
                        addressController.text = result['address'] ?? '';
                        if (nameController.text.isEmpty) {
                          nameController.text = result['name'] ?? '';
                        }
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text('아이콘 선택'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  'home', 'work', 'school', 'restaurant', 'shopping', 
                  'hospital', 'gas_station', 'place'
                ].map((icon) => GestureDetector(
                  onTap: () {
                    setDialogState(() {
                      selectedIcon = icon;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: selectedIcon == icon 
                          ? _getIconColor(icon).withOpacity(0.3)
                          : Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                      border: selectedIcon == icon
                          ? Border.all(color: _getIconColor(icon), width: 2)
                          : null,
                    ),
                    child: Icon(
                      _getIconData(icon),
                      color: _getIconColor(icon),
                    ),
                  ),
                )).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.isNotEmpty) {
                  if (isEdit) {
                    await _favoriteService.updateFavorite(
                      oldName: initialName!,
                      newName: nameController.text,
                      newAddress: addressController.text,
                      newIcon: selectedIcon,
                    );
                  } else {
                    await _favoriteService.addFavorite(
                      name: nameController.text,
                      address: addressController.text,
                      icon: selectedIcon,
                    );
                  }
                  Navigator.pop(context);
                }
              },
              child: Text(isEdit ? '수정' : '추가'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmDialog(String name) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('즐겨찾기 삭제'),
        content: Text('"$name"을(를) 즐겨찾기에서 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () {
              _favoriteService.removeFavorite(name);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('삭제', style: TextStyle(color: Colors.white)),
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
          initialDestination: favorite['name'],
          initialDestinationAddress: favorite['address'],
        ),
      ),
    );
  }
}