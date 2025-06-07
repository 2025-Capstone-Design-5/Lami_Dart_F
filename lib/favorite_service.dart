import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FavoriteService extends ChangeNotifier {
  // 싱글톤 패턴 구현
  static final FavoriteService _instance = FavoriteService._internal();
  factory FavoriteService() => _instance;
  FavoriteService._internal();

  // 즐겨찾기 장소 목록
  List<Map<String, dynamic>> _favoriteList = [];
  bool _isLoaded = false;

  // 기본 즐겨찾기 항목
  final List<Map<String, String>> _defaultFavorites = [
    {'name': '집', 'address': '', 'icon': 'home'},
    {'name': '직장', 'address': '', 'icon': 'work'},
    {'name': '학교', 'address': '', 'icon': 'school'},
  ];

  // 즐겨찾기 목록 가져오기
  List<Map<String, dynamic>> getFavoriteList() {
    return List.from(_favoriteList);
  }

  // 상위 3개 즐겨찾기 가져오기 (메인 페이지용)
  List<Map<String, dynamic>> getTopFavorites() {
    return _favoriteList.take(3).toList();
  }

  // 즐겨찾기 추가
  Future<void> addFavorite({
    required String name,
    required String address,
    String icon = 'place',
  }) async {
    // 중복 체크
    final existingIndex = _favoriteList.indexWhere((item) => item['name'] == name);
    
    if (existingIndex == -1) {
      _favoriteList.add({
        'name': name,
        'address': address,
        'icon': icon,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
      });
      
      await _saveFavorites();
      notifyListeners();
    }
  }

  // 즐겨찾기 수정
  Future<void> updateFavorite({
    required String oldName,
    required String newName,
    required String newAddress,
    String? newIcon,
  }) async {
    final index = _favoriteList.indexWhere((item) => item['name'] == oldName);
    
    if (index != -1) {
      _favoriteList[index]['name'] = newName;
      _favoriteList[index]['address'] = newAddress;
      if (newIcon != null) {
        _favoriteList[index]['icon'] = newIcon;
      }
      
      await _saveFavorites();
      notifyListeners();
    }
  }

  // 즐겨찾기 삭제
  Future<void> removeFavorite(String name) async {
    _favoriteList.removeWhere((item) => item['name'] == name);
    await _saveFavorites();
    notifyListeners();
  }

  // 즐겨찾기 순서 변경
  Future<void> reorderFavorites(int oldIndex, int newIndex) async {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final item = _favoriteList.removeAt(oldIndex);
    _favoriteList.insert(newIndex, item);
    
    await _saveFavorites();
    notifyListeners();
  }

  // 즐겨찾기 저장
  Future<void> _saveFavorites() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String favoritesJson = jsonEncode(_favoriteList);
      await prefs.setString('favorite_places', favoritesJson);
      print('즐겨찾기 저장 성공');
    } catch (e) {
      print('즐겨찾기 저장 오류: $e');
    }
  }

  // 즐겨찾기 로드
  Future<void> _loadFavorites() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? favoritesJson = prefs.getString('favorite_places');
      
      if (favoritesJson != null) {
        final List<dynamic> favoritesList = jsonDecode(favoritesJson);
        _favoriteList.clear();
        _favoriteList.addAll(favoritesList.cast<Map<String, dynamic>>());
        print('즐겨찾기 로드 성공: ${_favoriteList.length}개 항목');
      } else {
        // 처음 실행 시 기본 즐겨찾기 추가
        await _initializeDefaultFavorites();
      }
    } catch (e) {
      print('즐겨찾기 로드 오류: $e');
      // 오류 시 기본 즐겨찾기 초기화
      await _initializeDefaultFavorites();
    }
  }

  // 기본 즐겨찾기 초기화
  Future<void> _initializeDefaultFavorites() async {
    _favoriteList.clear();
    for (var favorite in _defaultFavorites) {
      _favoriteList.add({
        'name': favorite['name']!,
        'address': favorite['address']!,
        'icon': favorite['icon']!,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
      });
    }
    await _saveFavorites();
  }

  // 데이터 로드
  Future<void> loadData() async {
    if (_isLoaded) return;
    
    await _loadFavorites();
    _isLoaded = true;
    notifyListeners();
  }

  // 특정 즐겨찾기 찾기
  Map<String, dynamic>? findFavorite(String name) {
    try {
      return _favoriteList.firstWhere((item) => item['name'] == name);
    } catch (e) {
      return null;
    }
  }
}