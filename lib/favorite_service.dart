import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/favorite_api_service.dart';
import 'models/favorite_route_model.dart';

class FavoriteService extends ChangeNotifier {
  List<FavoriteRouteModel> _favoriteList = [];
  List<FavoriteRouteModel> get favoriteList => List.unmodifiable(_favoriteList);

  Future<void> loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final googleId = prefs.getString('googleId');
    if (googleId == null) return;
    try {
      final list = await FavoriteApiService(googleId: googleId).getFavorites();
      _favoriteList = list;
      notifyListeners();
    } catch (e) {
      debugPrint('즐겨찾기 불러오기 에러: $e');
    }
  }

  // 경로 즐겨찾기 추가
  Future<void> addFavorite({
    required String origin,
    required String destination,
    required String category,
    String? originAddress,
    String? destinationAddress,
    String iconName = 'place',
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final googleId = prefs.getString('googleId');
    if (googleId == null) return;
    try {
      await FavoriteApiService(googleId: googleId).addFavorite(
        origin: origin,
        destination: destination,
        category: category,
        wakeUpTime: DateTime.now().toIso8601String(),
        originAddress: originAddress,
        destinationAddress: destinationAddress,
        iconName: iconName,
        isDeparture: false,
      );
      await loadData();
    } catch (e) {
      debugPrint('즐겨찾기 추가 에러: $e');
      rethrow;
    }
  }
  
  // 출발지 즐겨찾기 추가
  Future<void> addDepartureFavorite({
    required String place,
    required String category,
    String? address,
    String iconName = 'place',
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final googleId = prefs.getString('googleId');
    if (googleId == null) return;
    try {
      await FavoriteApiService(googleId: googleId).addFavorite(
        origin: place,
        destination: '',
        category: category,
        wakeUpTime: DateTime.now().toIso8601String(),
        originAddress: address,
        iconName: iconName,
        isDeparture: true,
      );
      await loadData();
    } catch (e) {
      debugPrint('출발지 즐겨찾기 추가 에러: $e');
      rethrow;
    }
  }
  
  // 목적지 즐겨찾기 추가
  Future<void> addDestinationFavorite({
    required String place,
    required String category,
    String? address,
    String iconName = 'place',
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final googleId = prefs.getString('googleId');
    if (googleId == null) return;
    try {
      await FavoriteApiService(googleId: googleId).addFavorite(
        origin: '',
        destination: place,
        category: category,
        wakeUpTime: DateTime.now().toIso8601String(),
        destinationAddress: address,
        iconName: iconName,
        isDeparture: false,
      );
      await loadData();
    } catch (e) {
      debugPrint('목적지 즐겨찾기 추가 에러: $e');
      rethrow;
    }
  }

  Future<void> removeFavorite(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final googleId = prefs.getString('googleId');
    if (googleId == null) return;
    try {
      await FavoriteApiService(googleId: googleId).removeFavorite(id);
      _favoriteList.removeWhere((f) => f.id == id);
      notifyListeners();
    } catch (e) {
      debugPrint('즐겨찾기 삭제 에러: $e');
      rethrow;
    }
  }

  // 상위 3개 즐겨찾기 가져오기 (메인 페이지용)
  List<FavoriteRouteModel> getTop3Favorites() {
    return _favoriteList.take(3).toList();
  }
  
  // 출발지 즐겨찾기 목록 가져오기
  List<FavoriteRouteModel> getDepartureFavorites() {
    return _favoriteList
        .where((favorite) => favorite.isDeparture == true)
        .toList();
  }
  
  // 목적지 즐겨찾기 목록 가져오기
  List<FavoriteRouteModel> getDestinationFavorites() {
    return _favoriteList
        .where((favorite) => 
            favorite.isDeparture == false && 
            favorite.destination.isNotEmpty && 
            favorite.origin.isEmpty)
        .toList();
  }
  
  // 상위 3개 출발지 즐겨찾기 가져오기
  List<FavoriteRouteModel> getTop3DepartureFavorites() {
    return getDepartureFavorites().take(3).toList();
  }
  
  // 상위 3개 목적지 즐겨찾기 가져오기
  List<FavoriteRouteModel> getTop3DestinationFavorites() {
    return getDestinationFavorites().take(3).toList();
  }
  
  // 모든 즐겨찾기를 가져오는 메서드 (최대 6개)
  List<FavoriteRouteModel> getTopFavorites({int limit = 6}) {
    return _favoriteList.take(limit).toList();
  }

  // 특정 ID의 즐겨찾기 찾기
  FavoriteRouteModel? findFavoriteById(String id) {
    try {
      return _favoriteList.firstWhere((favorite) => favorite.id == id);
    } catch (e) {
      return null;
    }
  }
}