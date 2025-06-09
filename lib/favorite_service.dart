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

  Future<void> addFavorite({
    required String origin,
    required String destination,
    required String category,
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
      );
      await loadData();
    } catch (e) {
      debugPrint('즐겨찾기 추가 에러: $e');
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
  List<FavoriteRouteModel> getTopFavorites() {
    return _favoriteList.take(3).toList();
  }

  // 특정 ID의 즐겨찾기 찾기
  FavoriteRouteModel? findFavorite(String id) {
    try {
      return _favoriteList.firstWhere((item) => item.id == id);
    } catch (_) {
      return null;
    }
  }
}