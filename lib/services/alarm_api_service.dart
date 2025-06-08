import 'dart:convert';
import 'dart:io' show Platform;
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AlarmApiService {
  final String googleId;
  late final String baseUrl;

  AlarmApiService({required this.googleId}) {
    final defaultUrl = dotenv.env['BACKEND_URL'] ?? 'http://localhost:3000';
    baseUrl = Platform.isAndroid
        ? (dotenv.env['SERVER_BASE_URL_ANDROID'] ?? defaultUrl)
        : Platform.isIOS
            ? (dotenv.env['SERVER_BASE_URL_IOS'] ?? defaultUrl)
            : defaultUrl;
  }

  /// 서버에 알람을 등록합니다.
  Future<void> registerAlarm({
    required String arrivalTime,
    required int preparationTime,
  }) async {
    final uri = Uri.parse('$baseUrl/alarm/register');
    final payload = {
      'googleId': googleId,
      'arrivalTime': arrivalTime,
      'preparationTime': preparationTime,
    };
    final resp = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception('알람 등록 실패: ${resp.body}');
    }
  }
} 