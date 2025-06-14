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
      // 타임아웃 시간을 3초로 단축
      final resp = await http.get(uri).timeout(const Duration(seconds: 3));
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        final List<dynamic> list = jsonDecode(resp.body) as List<dynamic>;
        final favorites = list
            .map((e) => FavoriteRouteModel.fromJson(e as Map<String, dynamic>))
            .toList();
        // 서버에서 가져온 즐겨찾기를 로컬에도 저장 (백그라운드에서 처리)
        _saveLocalFavorites(favorites); // await 제거하여 비동기로 처리
        return favorites;
      } else {
        print('서버 응답 오류: ${resp.statusCode} - ${resp.body}');
        return getLocalFavorites();
      }
    } catch (e) {
      print('서버 연결 실패, 로컬 데이터 사용: $e');
      return getLocalFavorites();
    }
  }

  /// 새로운 즐겨찾기를 추가합니다. (최적화)
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
    
    // 먼저 로컬에 즐겨찾기 추가 (UI 반응성 향상)
    _addLocalFavorite(payload);
    
    try {
      final uri = Uri.parse('$baseUrl/traffic/routes/favorites');
      // 타임아웃 시간을 3초로 단축
      final resp = await http.post(uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(payload))
          .timeout(const Duration(seconds: 3));
      
      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        print('서버 응답 오류: ${resp.statusCode} - ${resp.body}');
        // 오류 발생 시 로컬 저장소에 이미 저장되어 있으므로 추가 작업 불필요
      }
    } catch (e) {
      print('서버 연결 실패, 로컬에 즐겨찾기 추가 완료: $e');
      // 이미 로컬에 저장했으므로 추가 작업 불필요
    }
  }

  /// 지정한 ID의 즐겨찾기를 삭제합니다. (최적화)
  Future<void> removeFavorite(String favoriteId) async {
    // 먼저 로컬에서 즐겨찾기 삭제 (UI 반응성 향상)
    _removeLocalFavorite(favoriteId);
    
    try {
      final uri = Uri.parse('$baseUrl/traffic/routes/favorites/$favoriteId?googleId=$googleId');
      // 타임아웃 시간을 3초로 단축
      final resp = await http.delete(uri).timeout(const Duration(seconds: 3));
      
      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        print('서버 응답 오류: ${resp.statusCode} - ${resp.body}');
        // 오류 발생 시 로컬 저장소에서 이미 삭제되어 있으므로 추가 작업 불필요
      }
    } catch (e) {
      print('서버 연결 실패, 로컬에서 즐겨찾기 삭제 완료: $e');
      // 이미 로컬에서 삭제했으므로 추가 작업 불필요
    }
  }

  // 로컬 저장소에서 즐겨찾기 목록 가져오기 (public으로 변경)
  Future<List<FavoriteRouteModel>> getLocalFavorites() async {
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

  // 로컬 저장소에 즐겨찾기 목록 저장 (최적화)
  Future<void> _saveLocalFavorites(List<FavoriteRouteModel> favorites) async {
    // 백그라운드에서 처리하기 위해 isolate나 compute를 사용할 수 있지만,
    // 간단하게 Future.microtask를 사용하여 메인 스레드 차단 방지
    Future.microtask(() async {
      try {
        final prefs = await SharedPreferences.getInstance();
        final favoritesJson = jsonEncode(favorites.map((f) => f.toJson()).toList());
        await prefs.setString(_localFavoritesKey, favoritesJson);
        print('로컬 즐겨찾기 저장 완료: ${favorites.length}개');
      } catch (e) {
        print('로컬 즐겨찾기 저장 오류: $e');
      }
    });
  }

  // 로컬 저장소에 즐겨찾기 추가 (최적화)
  Future<void> _addLocalFavorite(Map<String, dynamic> favoriteData) async {
    // 백그라운드에서 처리
    Future.microtask(() async {
      try {
        final favorites = await getLocalFavorites();
        
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
        _saveLocalFavorites(favorites); // await 제거하여 비동기로 처리
        print('로컬 즐겨찾기 추가 완료: ${newFavorite.id}');
      } catch (e) {
        print('로컬 즐겨찾기 추가 오류: $e');
      }
    });
  }

  // 로컬 저장소에서 즐겨찾기 삭제 (최적화)
  Future<void> _removeLocalFavorite(String favoriteId) async {
    // 백그라운드에서 처리
    Future.microtask(() async {
      try {
        final favorites = await getLocalFavorites();
        favorites.removeWhere((f) => f.id == favoriteId);
        _saveLocalFavorites(favorites); // await 제거하여 비동기로 처리
        print('로컬 즐겨찾기 삭제 완료: $favoriteId');
      } catch (e) {
        print('로컬 즐겨찾기 삭제 오류: $e');
      }
    });
  }
  
  /// 모든 즐겨찾기를 삭제합니다.
  Future<void> removeAllFavorites() async {
    // 먼저 로컬에서 모든 즐겨찾기 삭제 (UI 반응성 향상)
    _removeAllLocalFavorites();
    
    try {
      final uri = Uri.parse('$baseUrl/traffic/routes/favorites/all?googleId=$googleId');
      // 타임아웃 시간을 3초로 단축
      final resp = await http.delete(uri).timeout(const Duration(seconds: 3));
      
      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        print('서버 응답 오류: ${resp.statusCode} - ${resp.body}');
      }
    } catch (e) {
      print('서버 연결 실패, 로컬에서 모든 즐겨찾기 삭제 완료: $e');
    }
  }
  
  // 로컬 저장소에서 모든 즐겨찾기 삭제
  Future<void> _removeAllLocalFavorites() async {
    // 백그라운드에서 처리
    Future.microtask(() async {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_localFavoritesKey);
        print('로컬 즐겨찾기 전체 삭제 완료');
      } catch (e) {
        print('로컬 즐겨찾기 전체 삭제 오류: $e');
      }
    });
  }
}