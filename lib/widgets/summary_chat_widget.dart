import 'package:flutter/material.dart';
import '../models/summary_response.dart';
import '../pages/route/route_detail_page.dart';

/// Displays summary of routes inline in chat for SummaryData
class SummaryChatWidget extends StatelessWidget {
  final SummaryData summaryData;
  final void Function(RouteSummary route)? onSetAlarm;

  const SummaryChatWidget({Key? key, required this.summaryData, this.onSetAlarm}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final categories = <String, String>{
      'walk': '도보',
      'car': '자동차',
      'bus': '버스',
      'subway': '지하철',
      'bus_subway': '버스+지하철',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: categories.entries.map((entry) {
        final key = entry.key;
        final label = entry.value;
        final list = summaryData.routes.where((r) => r.category == key).toList();
        if (list.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Chip(
                    label: Text(
                      label,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 15,
                      ),
                    ),
                    backgroundColor: key == 'car'
                        ? Colors.blueGrey
                        : key == 'bus'
                            ? Colors.blue
                            : key == 'subway'
                                ? Colors.purple
                                : key == 'walk'
                                    ? Colors.grey
                                    : Colors.black45,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...list.map((option) {
                // 총 시간, 도보 시간
                final totalMin = (option.duration / 60).ceil();
                final walkSeconds = option.walkDurations.fold<int>(0, (sum, w) => sum + w);
                final walkMin = (walkSeconds / 60).ceil();
                // 정류장 및 노선
                final stops = option.stops.join(' → ');
                final routes = option.routeShortNames.join(', ');
                // compute segments (mode & seconds)
                final walkList = List<int>.from(option.walkDurations);
                final transitList = List<int>.from(option.transitDurations);
                final modes = List<String>.from(option.modes);
                final segments = <Map<String, dynamic>>[];
                for (var m in modes) {
                  final modeUpper = m.toUpperCase();
                  final sec = modeUpper == 'WALK'
                      ? (walkList.isNotEmpty ? walkList.removeAt(0) : 0)
                      : (transitList.isNotEmpty ? transitList.removeAt(0) : 0);
                  segments.add({'mode': modeUpper, 'seconds': sec});
                }
                return Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 2,
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () {
                      // 카테고리별 index로 상세 경로 페이지 이동
                      final categoryIndex = list.indexOf(option);
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => RouteDetailPage.fromSummaryKey(
                            summaryKey: summaryData.summaryKey,
                            category: option.category,
                            index: categoryIndex,
                          ),
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // (1) 시간 정보 + 알림 아이콘
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '$totalMin분',
                                style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '도보 $walkMin분',
                                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                              ),
                              const Spacer(),
                              IconButton(
                                icon: const Icon(Icons.alarm, color: Colors.deepOrange),
                                tooltip: '이 경로로 알림 설정',
                                onPressed: onSetAlarm != null ? () => onSetAlarm!(option) : null,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // (2) 정류장 및 노선 정보
                          if (stops.isNotEmpty) ...[
                            Text('정류장: $stops', style: const TextStyle(fontSize: 13)),
                            const SizedBox(height: 4),
                          ],
                          if (routes.isNotEmpty) ...[
                            Text('노선번호: $routes', style: const TextStyle(fontSize: 13)),
                            const SizedBox(height: 8),
                          ],
                          // (3) segments bar graph
                          const SizedBox(height: 8),
                          Container(
                            height: 8,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(4),
                              color: Colors.grey.shade300,
                            ),
                            child: Row(
                              children: segments.map((seg) {
                                final mode = seg['mode'] as String;
                                final seconds = seg['seconds'] as int;
                                Color barColor;
                                if (mode == 'WALK') {
                                  barColor = Colors.grey.shade500;
                                } else if (mode == 'BUS') {
                                  barColor = Colors.blue.shade400;
                                } else if (mode == 'SUBWAY') {
                                  barColor = Colors.purple.shade400;
                                } else {
                                  barColor = Colors.black38;
                                }
                                return Expanded(
                                  flex: seconds,
                                  child: Container(color: barColor),
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ],
          ),
        );
      }).toList(),
    );
  }
} 