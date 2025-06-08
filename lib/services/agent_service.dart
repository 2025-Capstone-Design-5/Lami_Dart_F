import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AgentService {
  // 백엔드 URL을 .env의 BACKEND_URL 또는 기본 localhost로 설정
  static final _baseUrl = dotenv.env['BACKEND_URL'] ?? 'http://localhost:3000';

  /// 사용자 ID와 메시지를 보내고, 에이전트의 응답 문자열을 반환합니다.
  Future<String> processMessage({
    required String userId,
    required String message,
  }) async {
    // Log request to server
    print('AgentService: sending request to $_baseUrl/agent/process with userId=$userId, message=$message');
    final uri = Uri.parse('$_baseUrl/agent/process');
    final resp = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'userId': userId, 'message': message}),
    );
    // Log response status and body
    print('AgentService: received status code ${resp.statusCode}');
    print('AgentService: response body: ${resp.body}');

    if (resp.statusCode == 200 || resp.statusCode == 201) {
      final body = jsonDecode(resp.body);
      final result = body['result'];
      if (result is String) return result;
      return jsonEncode(result);
    } else if (resp.statusCode == 429) {
      // 한도 초과
      return '죄송합니다. 현재 API 사용 한도를 초과했습니다. 잠시 후 다시 시도해주세요.';
    } else {
      throw Exception('서버 오류: ${resp.statusCode}');
    }
  }

  /// Streams agent's thought/action logs via SSE.
  Stream<String> streamProcess({
    required String userId,
    required String message,
  }) async* {
    // Log request to server for streaming
    print('AgentService: streaming request to $_baseUrl/agent/process/stream with userId=$userId, message=$message');
    final uri = Uri.parse('$_baseUrl/agent/process/stream?userId=${Uri.encodeComponent(userId)}&message=${Uri.encodeComponent(message)}');
    final request = http.Request('GET', uri);
    request.headers['Accept'] = 'text/event-stream';
    final streamedResponse = await http.Client().send(request);
    final stream = streamedResponse.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter());
    await for (final line in stream) {
      if (line.startsWith('data:')) {
        final data = line.substring(5).trim();
        // Log SSE data to console
        print('SSE data: $data');
        yield data;
      }
    }
  }
} 