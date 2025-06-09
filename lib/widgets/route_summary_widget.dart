import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import '../models/summary_response.dart';
import '../models/route_detail_response.dart';
import '../pages/route/route_detail_page.dart';
import '../event_service.dart';
import '../route_store.dart';
import '../config/server_config.dart';

/// Reusable widget that displays route summary UI (tabs and list of route options).
class RouteSummaryWidget extends StatelessWidget {
  final SummaryData summaryData;

  const RouteSummaryWidget({Key? key, required this.summaryData}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final tabs = ['도보', '자동차', '버스', '지하철', '버스+지하철'];
    final lists = <List<RouteSummary>>[
      summaryData.routes.where((r) => r.category == 'walk').toList(),
      summaryData.routes.where((r) => r.category == 'car').toList(),
      summaryData.routes.where((r) => r.category == 'bus').toList(),
      summaryData.routes.where((r) => r.category == 'subway').toList(),
      summaryData.routes.where((r) => r.category == 'bus_subway').toList(),
    ];

    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('경로 결과'),
          bottom: TabBar(
            isScrollable: true,
            tabs: tabs.map((t) => Tab(text: t)).toList(),
          ),
        ),
        body: TabBarView(
          children: List.generate(
            lists.length,
            (i) {
              final options = lists[i];
              if (options.isEmpty) {
                return const Center(child: Text('결과 없음'));
              }
              return ListView.builder(
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final option = options[index];

                  // Duration and segments calculation
                  final totalMin = (option.duration / 60).ceil();
                  final walkDurations = List<int>.from(option.walkDurations);
                  final transitDurations = List<int>.from(option.transitDurations);
                  final modes = List<String>.from(option.modes);
                  int walkSeconds = walkDurations.fold(0, (sum, w) => sum + w);
                  final walkMin = (walkSeconds / 60).ceil();
                  final List<_Segment> segments = [];
                  for (var m in modes) {
                    final modeUpper = m.toUpperCase();
                    final sec = modeUpper == 'WALK'
                        ? (walkDurations.isNotEmpty ? walkDurations.removeAt(0) : 0)
                        : (transitDurations.isNotEmpty ? transitDurations.removeAt(0) : 0);
                    String segMode;
                    if (modeUpper == 'WALK') segMode = 'WALK';
                    else if (modeUpper == 'BUS' || modeUpper == 'TRAM') segMode = 'BUS';
                    else if (modeUpper == 'SUBWAY' || modeUpper == 'RAIL') segMode = 'SUBWAY';
                    else segMode = modeUpper;
                    segments.add(_Segment(mode: segMode, seconds: sec));
                  }
                  final totalSeconds = segments.fold<int>(0, (sum, seg) => sum + seg.seconds);
                  final safeTotal = totalSeconds.toDouble().clamp(1.0, double.infinity);

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: InkWell(
                      onTap: () async {
                        final prefs = await SharedPreferences.getInstance();
                        final googleId = prefs.getString('googleId') ?? '';
                        final url = Uri.parse('${getServerBaseUrl()}/traffic/routes/detail');
                        final body = jsonEncode({
                          'summaryKey': summaryData.summaryKey,
                          'category': option.category,
                          'index': index,
                        });
                        final resp = await http.post(url, headers: {'Content-Type': 'application/json'}, body: body);
                        if (resp.statusCode >= 200 && resp.statusCode < 300) {
                          final detail = RouteDetailResponse.parse(resp.body).data;
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => RouteDetailPage(option: detail),
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('상세 조회 실패: ${resp.statusCode}')),
                          );
                        }
                      },
                      child: Card(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        elevation: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text('$totalMin분', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                                  const SizedBox(width: 8),
                                  const Spacer(),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text('도보 $walkMin분', style: TextStyle(color: Colors.grey.shade600)),
                              const SizedBox(height: 8),
                              // Segment bar visualization omitted for brevity
                              // ...
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Segment {
  final String mode;
  final int seconds;
  _Segment({required this.mode, required this.seconds});
} 