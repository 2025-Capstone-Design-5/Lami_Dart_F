import 'dart:convert';
import 'dart:io' show Platform;
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/category.dart';
import '../models/favorite_route.dart';

class FavoriteApiService {
  late final String baseUrl;
  final String googleId;

  FavoriteApiService({required this.googleId}) {
    // Determine base URL with platform fallback
    final defaultUrl = dotenv.env['SERVER_BASE_URL']!;
    baseUrl = Platform.isAndroid
        ? (dotenv.env['SERVER_BASE_URL_ANDROID'] ?? defaultUrl)
        : Platform.isIOS
            ? (dotenv.env['SERVER_BASE_URL_IOS'] ?? defaultUrl)
            : defaultUrl;
  }

  Future<List<Category>> getCategories() async {
    final uri = Uri.parse('$baseUrl/categories?googleId=$googleId');
    final resp = await http.get(uri);
    if (resp.statusCode != 200) {
      throw Exception('Failed to load categories: ${resp.body}');
    }
    final data = jsonDecode(resp.body)['data'] as List<dynamic>;
    return data.map((e) => Category.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Category> addCategory(String name) async {
    final uri = Uri.parse('$baseUrl/categories');
    final body = jsonEncode({'googleId': googleId, 'name': name});
    final resp = await http.post(uri,
        headers: {'Content-Type': 'application/json'}, body: body);
    if (resp.statusCode != 200) {
      throw Exception('Failed to add category: ${resp.body}');
    }
    final data = jsonDecode(resp.body)['data'] as Map<String, dynamic>;
    return Category.fromJson(data);
  }

  Future<void> removeCategory(String categoryId) async {
    final uri = Uri.parse('$baseUrl/categories/$categoryId?googleId=$googleId');
    final resp = await http.delete(uri);
    if (resp.statusCode != 200) {
      throw Exception('Failed to delete category: ${resp.body}');
    }
  }

  Future<List<FavoriteRoute>> getFavorites() async {
    final uri = Uri.parse('$baseUrl/favorites?googleId=$googleId');
    final resp = await http.get(uri);
    if (resp.statusCode != 200) {
      throw Exception('Failed to load favorites: ${resp.body}');
    }
    final data = jsonDecode(resp.body)['data'] as List<dynamic>;
    return data
        .map((e) => FavoriteRoute.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<FavoriteRoute> addFavorite({
    required String name,
    required String origin,
    required String destination,
    List<String>? categoryIds,
  }) async {
    final uri = Uri.parse('$baseUrl/favorites');
    final payload = {
      'googleId': googleId,
      'name': name,
      'origin': origin,
      'destination': destination,
      if (categoryIds != null) 'categoryIds': categoryIds,
    };
    final resp = await http.post(uri,
        headers: {'Content-Type': 'application/json'}, body: jsonEncode(payload));
    if (resp.statusCode != 200) {
      throw Exception('Failed to add favorite: ${resp.body}');
    }
    final data = jsonDecode(resp.body)['data'] as Map<String, dynamic>;
    return FavoriteRoute.fromJson(data);
  }

  Future<void> removeFavorite(String favoriteId) async {
    final uri = Uri.parse('$baseUrl/favorites/$favoriteId?googleId=$googleId');
    final resp = await http.delete(uri);
    if (resp.statusCode != 200) {
      throw Exception('Failed to delete favorite: ${resp.body}');
    }
  }
} 