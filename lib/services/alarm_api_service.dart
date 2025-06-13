import 'dart:convert';
import 'dart:io' show Platform;
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../config/server_config.dart';

class AlarmApiService {
  final String googleId;
  late final String baseUrl;

  AlarmApiService({required this.googleId}) {
    baseUrl = getServerBaseUrl();
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

  /// 서버에 등록된 모든 알람을 조회합니다.
  Future<List<Map<String, dynamic>>> getAlarms() async {
    final uri = Uri.parse('$baseUrl/alarm?googleId=$googleId');
    final resp = await http.get(uri);
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      final List<dynamic> data = jsonDecode(resp.body);
      return data.cast<Map<String, dynamic>>();
    } else {
      throw Exception('알람 조회 실패: ${resp.body}');
    }
  }
} 