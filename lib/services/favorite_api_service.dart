import 'dart:convert';
import 'dart:io' show Platform;
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/favorite_route_model.dart';
import '../config/server_config.dart';

class FavoriteApiService {
  final String googleId;
  late final String baseUrl;
  static const String _localFavoritesKey = 'local_favorites';

  FavoriteApiService({required this.googleId}) {
    baseUrl = getServerBaseUrl();
  }

  /// 즐겨찾기 목록을 가져옵니다.
  Future<List<FavoriteRouteModel>> getFavorites() async {
    try {
      final uri = Uri.parse('$baseUrl/traffic/routes/favorites?googleId=$googleId');
      final resp = await http.get(uri).timeout(const Duration(seconds: 5));
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        final List<dynamic> list = jsonDecode(resp.body) as List<dynamic>;
        final favorites = list
            .map((e) => FavoriteRouteModel.fromJson(e as Map<String, dynamic>))
            .toList();
        // 서버에서 가져온 즐겨찾기를 로컬에도 저장
        await _saveLocalFavorites(favorites);
        return favorites;
      } else {
        print('서버 응답 오류: ${resp.statusCode} - ${resp.body}');
        return _getLocalFavorites();
      }
    } catch (e) {
      print('서버 연결 실패, 로컬 데이터 사용: $e');
      return _getLocalFavorites();
    }
  }

  /// 새로운 즐겨찾기를 추가합니다.
  Future<void> addFavorite({
    required String origin,
    required String destination,
    required String category,
    required String wakeUpTime,
    String? originAddress,
    String? destinationAddress,
    String? iconName,
    bool? isDeparture,
  }) async {
    final payload = {
      'googleId': googleId,
      'origin': origin,
      'destination': destination,
      'category': category,
      'wakeUpTime': wakeUpTime,
      if (originAddress != null) 'originAddress': originAddress,
      if (destinationAddress != null) 'destinationAddress': destinationAddress,
      if (iconName != null) 'iconName': iconName,
      if (isDeparture != null) 'isDeparture': isDeparture,
    };
    print('FavoriteApiService.addFavorite payload: $payload');
    
    try {
      final uri = Uri.parse('$baseUrl/traffic/routes/favorites');
      final resp = await http.post(uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(payload))
          .timeout(const Duration(seconds: 5));
      
      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        print('서버 응답 오류: ${resp.statusCode} - ${resp.body}');
        throw Exception('즐겨찾기 추가 실패: ${resp.body}');
      }
    } catch (e) {
      print('서버 연결 실패, 로컬에 즐겨찾기 추가: $e');
      // 서버 연결 실패 시 로컬에 즐겨찾기 추가
      await _addLocalFavorite(payload);
    }
  }

  /// 지정한 ID의 즐겨찾기를 삭제합니다.
  Future<void> removeFavorite(String favoriteId) async {
    try {
      final uri = Uri.parse('$baseUrl/traffic/routes/favorites/$favoriteId?googleId=$googleId');
      final resp = await http.delete(uri).timeout(const Duration(seconds: 5));
      
      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        print('서버 응답 오류: ${resp.statusCode} - ${resp.body}');
        throw Exception('즐겨찾기 삭제 실패: ${resp.body}');
      }
    } catch (e) {
      print('서버 연결 실패, 로컬에서 즐겨찾기 삭제: $e');
      // 서버 연결 실패 시 로컬에서 즐겨찾기 삭제
      await _removeLocalFavorite(favoriteId);
    }
  }

  // 로컬 저장소에서 즐겨찾기 목록 가져오기
  Future<List<FavoriteRouteModel>> _getLocalFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final favoritesJson = prefs.getString(_localFavoritesKey);
    if (favoritesJson == null) return [];
    
    try {
      final List<dynamic> list = jsonDecode(favoritesJson) as List<dynamic>;
      return list
          .map((e) => FavoriteRouteModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('로컬 즐겨찾기 파싱 오류: $e');
      return [];
    }
  }

  // 로컬 저장소에 즐겨찾기 목록 저장
  Future<void> _saveLocalFavorites(List<FavoriteRouteModel> favorites) async {
    final prefs = await SharedPreferences.getInstance();
    final favoritesJson = jsonEncode(favorites.map((f) => f.toJson()).toList());
    await prefs.setString(_localFavoritesKey, favoritesJson);
  }

  // 로컬 저장소에 즐겨찾기 추가
  Future<void> _addLocalFavorite(Map<String, dynamic> favoriteData) async {
    final favorites = await _getLocalFavorites();
    
    // 고유 ID 생성 (현재 시간 기반)
    final id = 'local_${DateTime.now().millisecondsSinceEpoch}';
    final newFavorite = FavoriteRouteModel(
      id: id,
      origin: favoriteData['origin'] as String,
      originAddress: favoriteData['originAddress'] as String? ?? favoriteData['origin'] as String,
      destination: favoriteData['destination'] as String,
      destinationAddress: favoriteData['destinationAddress'] as String? ?? favoriteData['destination'] as String,
      category: favoriteData['category'] as String,
      iconName: favoriteData['iconName'] as String? ?? 'place',
      createdAt: DateTime.now(),
      isDeparture: favoriteData['isDeparture'] as bool? ?? false,
    );
    
    favorites.add(newFavorite);
    await _saveLocalFavorites(favorites);
  }

  // 로컬 저장소에서 즐겨찾기 삭제
  Future<void> _removeLocalFavorite(String favoriteId) async {
    final favorites = await _getLocalFavorites();
    favorites.removeWhere((f) => f.id == favoriteId);
    await _saveLocalFavorites(favorites);
  }
}