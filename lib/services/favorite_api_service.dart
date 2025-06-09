import 'dart:convert';
import 'dart:io' show Platform;
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/favorite_route_model.dart';

class FavoriteApiService {
  final String googleId;
  late final String baseUrl;

  FavoriteApiService({required this.googleId}) {
    // Determine base URL with platform fallback
    final defaultUrl = dotenv.env['BACKEND_URL'] ?? 'http://localhost:3000';
    baseUrl = Platform.isAndroid
        ? (dotenv.env['SERVER_BASE_URL_ANDROID'] ?? defaultUrl)
        : Platform.isIOS
            ? (dotenv.env['SERVER_BASE_URL_IOS'] ?? defaultUrl)
            : defaultUrl;
  }

  /// 즐겨찾기 목록을 가져옵니다.
  Future<List<FavoriteRouteModel>> getFavorites() async {
    final uri = Uri.parse('$baseUrl/traffic/routes/favorites?googleId=$googleId');
    final resp = await http.get(uri);
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      final List<dynamic> list = jsonDecode(resp.body) as List<dynamic>;
      return list
          .map((e) => FavoriteRouteModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } else {
      throw Exception('즐겨찾기 불러오기 실패: ${resp.body}');
    }
  }

  /// 새로운 즐겨찾기를 추가합니다.
  Future<void> addFavorite({
    required String origin,
    required String destination,
    required String category,
    required String wakeUpTime,
  }) async {
    final uri = Uri.parse('$baseUrl/traffic/routes/favorites');
    final payload = {
      'googleId': googleId,
      'origin': origin,
      'destination': destination,
      'category': category,
      'wakeUpTime': wakeUpTime,
    };
    print('FavoriteApiService.addFavorite payload: $payload');
    final resp = await http.post(uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload));
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception('즐겨찾기 추가 실패: ${resp.body}');
    }
  }

  /// 지정한 ID의 즐겨찾기를 삭제합니다.
  Future<void> removeFavorite(String favoriteId) async {
    final uri = Uri.parse('$baseUrl/traffic/routes/favorites/$favoriteId?googleId=$googleId');
    final resp = await http.delete(uri);
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception('즐겨찾기 삭제 실패: ${resp.body}');
    }
  }
} 