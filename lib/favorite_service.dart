import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models/favorite_route_model.dart';

class FavoriteService extends ChangeNotifier {
  List<FavoriteRouteModel> _favoriteList = [];
  List<FavoriteRouteModel> get favoriteList => List.unmodifiable(_favoriteList);

  Future<void> loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final googleId = prefs.getString('googleId');
    if (googleId == null) return;
    final baseUrl = dotenv.env['BACKEND_URL'] ?? 'http://localhost:3000';
    final uri = Uri.parse('$baseUrl/traffic/routes/favorites?googleId=$googleId');
    final resp = await http.get(uri);
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      final List<dynamic> data = json.decode(resp.body);
      _favoriteList = data
          .map((e) => FavoriteRouteModel.fromJson(e as Map<String, dynamic>))
          .toList();
      notifyListeners();
    } else {
      throw Exception('즐겨찾기 불러오기 실패: ${resp.body}');
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
    final baseUrl = dotenv.env['BACKEND_URL'] ?? 'http://localhost:3000';
    final uri = Uri.parse('$baseUrl/traffic/routes/favorites');
    final payload = {
      'googleId': googleId,
      'origin': origin,
      'destination': destination,
      'category': category,
    };
    final resp = await http.post(uri,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(payload));
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      await loadData();
    } else {
      throw Exception('즐겨찾기 추가 실패: ${resp.body}');
    }
  }

  Future<void> removeFavorite(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final googleId = prefs.getString('googleId');
    if (googleId == null) return;
    final baseUrl = dotenv.env['BACKEND_URL'] ?? 'http://localhost:3000';
    final uri = Uri.parse('$baseUrl/traffic/routes/favorites/$id?googleId=$googleId');
    final resp = await http.delete(uri);
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      _favoriteList.removeWhere((f) => f.id == id);
      notifyListeners();
    } else {
      throw Exception('즐겨찾기 삭제 실패: ${resp.body}');
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