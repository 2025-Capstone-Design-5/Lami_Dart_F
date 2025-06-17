import 'package:flutter/material.dart';
import 'dart:ui';
import '../../models/route_response.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../config/server_config.dart';
import 'package:flutter/rendering.dart';

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
    final main = option.main;
    // 1) calculate total minutes
    final totalMin = (main.duration / 60).ceil();

    // 2) build segment list for bar
    final walkDurations = List<int>.from(main.walkDurations);
    final transitDurations = List<int>.from(main.transitDurations);
    final modes = List<String>.from(main.modes);
    final segments = <_Segment>[];
    for (var m in modes) {
      final modeUpper = m.toUpperCase();
      final secs = modeUpper == 'WALK'
          ? (walkDurations.isNotEmpty ? walkDurations.removeAt(0) : 0)
          : (transitDurations.isNotEmpty ? transitDurations.removeAt(0) : 0);
      String segMode;
      if (modeUpper == 'WALK') segMode = 'WALK';
      else if (modeUpper == 'BUS' || modeUpper == 'TRAM') segMode = 'BUS';
      else if (modeUpper == 'SUBWAY' || modeUpper == 'RAIL') segMode = 'SUBWAY';
      else segMode = modeUpper;
      segments.add(_Segment(mode: segMode, seconds: secs));
    }
    final totalSeconds = segments.fold<int>(0, (sum, s) => sum + s.seconds);
    final safeTotal = totalSeconds == 0 ? 1.0 : totalSeconds.toDouble();

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('${main.origin} → ${main.destination}'),
      ),
      body: Stack(
        children: [
          // Gradient background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF0A0E27),
                  Color(0xFF1A1E3A),
                ],
              ),
            ),
          ),
          // Gradient orbs
          Positioned(
            top: -100,
            left: -50,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF6366F1).withOpacity(0.3),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -100,
            right: -50,
            child: Container(
              width: 350,
              height: 350,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF3B82F6).withOpacity(0.3),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // Glass container for detail content
          SafeArea(
            child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withOpacity(0.2), width: 1.5),
                    ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: total time
              Row(
                children: [
                            Text('$totalMin분', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                  const Spacer(),
                ],
              ),
              const SizedBox(height: 16),
              // Segment bar
              SizedBox(
                height: 24,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final totalWidth = constraints.maxWidth;
                    final count = segments.length;
                    const minWidth = 40.0;
                    final rawWidths = segments.map((s) => (s.seconds / safeTotal) * totalWidth).toList();
                    final widths = List<double>.filled(count, 0);
                    double usedMin = 0, restSecs = 0; final flexIdx = <int>[];
                    for (int i = 0; i < count; i++) {
                      if (rawWidths[i] < minWidth) { widths[i] = minWidth; usedMin += minWidth; }
                      else { flexIdx.add(i); restSecs += segments[i].seconds; }
                    }
                    final remWidth = (totalWidth - usedMin).clamp(0.0, double.infinity);
                    double acc = 0;
                    for (int k = 0; k < flexIdx.length; k++) {
                      final i = flexIdx[k];
                      final w = (k == flexIdx.length - 1)
                          ? (remWidth - acc)
                          : (segments[i].seconds / restSecs) * remWidth;
                      widths[i] = w; acc += w;
                    }
                    return Row(
                      children: List.generate(count, (i) {
                        final seg = segments[i];
                        final bool isFirst = i == 0;
                        final bool isLast = i == count - 1;
                        Color bg;
                        switch (seg.mode) {
                          case 'BUS': bg = Colors.blue; break;
                          case 'SUBWAY': bg = Colors.purple; break;
                          default: bg = Colors.grey.shade300;
                        }
                        BorderRadius radius = BorderRadius.zero;
                        if (isFirst && isLast) radius = BorderRadius.circular(12);
                        else if (isFirst) radius = const BorderRadius.only(topLeft: Radius.circular(12), bottomLeft: Radius.circular(12));
                        else if (isLast) radius = const BorderRadius.only(topRight: Radius.circular(12), bottomRight: Radius.circular(12));
                        return Container(
                          width: widths[i], height: 24,
                          decoration: BoxDecoration(color: bg, borderRadius: radius), padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Center(child: Text('${(seg.seconds / 60).ceil()}분', style: TextStyle(fontSize: 12, color: seg.mode == 'WALK' ? Colors.grey.shade800 : Colors.white))),
                        );
                      }),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
              // 각 구간별 정류장 타임라인 (출발지 → 경유 → 도착지)
              ...option.sub.map((leg) {
                // 출발, 경유, 도착 리스트 구성
                final stopsList = [leg.from, ...leg.intermediateStops, leg.to];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('구간: ${leg.mode}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    ...List.generate(stopsList.length, (i) {
                      final place = stopsList[i];
                      final bool isFirst = i == 0;
                      final bool isLast = i == stopsList.length - 1;
                      final IconData icon = isFirst
                        ? Icons.play_circle_fill
                        : isLast
                          ? Icons.stop_circle
                          : Icons.radio_button_checked;
                      final Color iconColor = isFirst
                        ? Colors.green
                        : isLast
                          ? Colors.red
                          : Colors.grey;
                      final String label = isFirst
                        ? '출발지: ${place.name}'
                        : isLast
                          ? '도착지: ${place.name}'
                          : place.name;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Column(
                              children: [
                                Icon(icon, size: 20, color: iconColor),
                                if (!isLast) Container(width: 2, height: 40, color: Colors.grey.shade300),
                              ],
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                                decoration: BoxDecoration(
                                  color: isFirst
                                    ? Colors.green.shade50
                                    : isLast
                                      ? Colors.red.shade50
                                      : Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                          child: Text(
                                            label,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              color: Colors.black,
                                            ),
                                          ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 16),
                  ],
                );
              }).toList(),
            ],
          ),
        ),
                ),
              ),
            ),
          ),
        ],
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

// Helper for detail segment bar
class _Segment {
  final String mode;
  final int seconds;
  _Segment({required this.mode, required this.seconds});
} 