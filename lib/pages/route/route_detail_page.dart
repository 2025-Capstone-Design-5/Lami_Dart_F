import 'package:flutter/material.dart';
import '../../models/route_response.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../config/server_config.dart';

class RouteDetailPage extends StatelessWidget {
  final RouteOption? option;
  final String? summaryKey;
  final String? category;
  final int? index;

  const RouteDetailPage({Key? key, required this.option})
      : summaryKey = null,
        category = null,
        index = null,
        super(key: key);

  const RouteDetailPage.fromSummaryKey({Key? key, required this.summaryKey, required this.category, required this.index})
      : option = null,
        super(key: key);

  Future<RouteOption?> _fetchDetail() async {
    final resp = await http.post(
      Uri.parse('${getServerBaseUrl()}/traffic/routes/detail'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'summaryKey': summaryKey,
        'category': category,
        'index': index,
      }),
    );
    print('[상세경로] status: \\${resp.statusCode}, body: \\${resp.body}');
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception('상세 경로 조회 실패: ${resp.body}');
    }
    final data = jsonDecode(resp.body)['data'];
    print('[상세경로] data 타입: \\${data.runtimeType}');
    print('[상세경로] data 내용: \\${data}');
    if (data == null || (data is Map && data.isEmpty)) {
      // 정상 응답이지만 상세 경로 없음
      return null;
    }
    try {
      dynamic parsedData = data;
      if (parsedData is String) {
        parsedData = jsonDecode(parsedData);
        if (parsedData is String) {
          parsedData = jsonDecode(parsedData);
        }
      }
      if (parsedData is Map && parsedData.containsKey('main') && parsedData.containsKey('sub')) {
        return RouteOption.fromJson(Map<String, dynamic>.from(parsedData));
      } else {
        throw Exception('상세 경로 데이터 구조 오류: main/sub 필드가 없습니다.\\n$parsedData');
      }
    } catch (e) {
      throw Exception('상세 경로 데이터 파싱 오류: $e\\n$data');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (option != null) {
      return _buildDetail(context, option!);
    } else {
      // summaryKey, category, index로 fetch
      return FutureBuilder<RouteOption?>(
        future: _fetchDetail(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Scaffold(
              appBar: AppBar(title: const Text('상세 경로')),
              body: const Center(child: CircularProgressIndicator()),
            );
          } else if (snapshot.hasError) {
            return Scaffold(
              appBar: AppBar(title: const Text('상세 경로')),
              body: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('오류: \\${snapshot.error}', style: TextStyle(color: Colors.red)),
                    if (snapshot.stackTrace != null)
                      Text('Stack: \\${snapshot.stackTrace}', style: TextStyle(fontSize: 10)),
                  ],
                ),
              ),
            );
          } else if (!snapshot.hasData || snapshot.data == null) {
            return Scaffold(
              appBar: AppBar(title: const Text('상세 경로')),
              body: const Center(child: Text('상세 경로 데이터가 없습니다.')),
            );
          } else {
            return _buildDetail(context, snapshot.data!);
          }
        },
      );
    }
  }

  Widget _buildDetail(BuildContext context, RouteOption option) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('상세 경로'),
      ),
      body: ListView.builder(
        itemCount: option.sub.length,
        itemBuilder: (context, index) {
          final leg = option.sub[index];
          final mode = leg.mode;
          final icon = _getIcon(mode);
          final from = leg.from;
          final to = leg.to;
          final depTime = from.departure != null
              ? DateTime.fromMillisecondsSinceEpoch(from.departure!)
              : null;
          final arrTime = to.arrival != null
              ? DateTime.fromMillisecondsSinceEpoch(to.arrival!)
              : null;
          String timeRange = '';
          if (depTime != null && arrTime != null) {
            final start = DateFormat('a h:mm', 'ko').format(depTime);
            final end = DateFormat('a h:mm', 'ko').format(arrTime);
            timeRange = '$start ~ $end';
          }
          return ExpansionTile(
            leading: Icon(icon, color: Theme.of(context).primaryColor),
            title: Text('${from.name} → ${to.name}'),
            subtitle: Text(timeRange),
            children: leg.steps
                .map((step) => ListTile(
                      leading: const Icon(Icons.circle, size: 8),
                      title: Text(step.streetName),
                      trailing: Text('${step.distance.toStringAsFixed(0)}m'),
                    ))
                .toList(),
          );
        },
      ),
    );
  }

  IconData _getIcon(String mode) {
    switch (mode) {
      case 'WALK':
        return Icons.directions_walk;
      case 'CAR':
        return Icons.directions_car;
      case 'BUS':
        return Icons.directions_bus;
      case 'SUBWAY':
        return Icons.subway;
      default:
        return Icons.directions;
    }
  }
} 