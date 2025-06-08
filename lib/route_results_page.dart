import 'package:flutter/material.dart';
import 'models/summary_response.dart';
import 'models/route_detail_response.dart';
import 'route_detail_page.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/intl.dart';
import 'event_service.dart';
import 'dart:convert';
import 'route_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// RouteResultsPage: SummaryData를 받아 여러 경로 옵션을 탭별로 보여주는 페이지
class RouteResultsPage extends StatelessWidget {
  final SummaryData summaryData;

  const RouteResultsPage({Key? key, required this.summaryData})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    // 1) 탭 목록과 각 탭에 해당하는 경로 리스트 생성
    final tabs = ['도보', '자동차', '버스', '지하철', '버스+지하철'];
    final lists = <List<dynamic>>[
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

                  // 2) 전체 소요 시간(초 → 분 올림)
                  final totalMin = (option.duration / 60).ceil();

                  // 3) 도보/대중교통 구간별 시간 복사본 생성
                  final walkDurations = List<int>.from(option.walkDurations);
                  final transitDurations = List<int>.from(option.transitDurations);
                  final modes = List<String>.from(option.modes);

                  int walkSeconds = 0;
                  for (var w in walkDurations) {
                    walkSeconds += w;
                  }
                  final walkMin = (walkSeconds / 60).ceil();

                  // 4) 정류장 목록과 노선명 문자열
                  final stops = option.stops;
                  final routeNames = option.routeShortNames.join(', ');

                  // 5) segments(구간) 리스트 구성: 걸을 구간은 'WALK', 버스/트램은 'BUS', 지하철/철도는 'SUBWAY'
                  final List<_Segment> segments = <_Segment>[];
                  for (var m in modes) {
                    final modeUpper = m.toUpperCase();
                    final int sec = (modeUpper == 'WALK'
                        ? (walkDurations.isNotEmpty ? walkDurations.removeAt(0) : 0)
                        : (transitDurations.isNotEmpty ? transitDurations.removeAt(0) : 0));
                    String segMode;
                    if (modeUpper == 'WALK') {
                      segMode = 'WALK';
                    } else if (modeUpper == 'BUS' || modeUpper == 'TRAM') {
                      segMode = 'BUS';
                    } else if (modeUpper == 'SUBWAY' || modeUpper == 'RAIL') {
                      segMode = 'SUBWAY';
                    } else {
                      segMode = modeUpper;
                    }
                    segments.add(_Segment(mode: segMode, seconds: sec));
                  }

                  // 6) 모든 세그먼트 합산 시간 (초 → safeTotal)
                  final totalSeconds = segments.fold<int>(0, (sum, seg) => sum + seg.seconds);
                  final safeTotal = totalSeconds == 0 ? 1.0 : totalSeconds.toDouble();

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: InkWell(
                      onTap: () async {
                        // 카드 전체 터치 시 "상세 조회" 로직 실행
                        final baseUrl = dotenv.env['SERVER_BASE_URL']!;
                        final url = Uri.parse('$baseUrl/traffic/routes/detail');
                        final body = jsonEncode({
                          'summaryKey': summaryData.summaryKey,
                          'category': option.category,
                          'index': index,
                        });
                        final resp = await http.post(
                          url,
                          headers: {'Content-Type': 'application/json'},
                          body: body,
                        );
                        if (resp.statusCode >= 200 && resp.statusCode < 300) {
                          final detailResp = RouteDetailResponse.parse(resp.body);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => RouteDetailPage(option: detailResp.data),
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
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // (1) 상단: 총 시간 + 도보 시간 + 알림(벨) 아이콘 + 첫차 정보
                              Stack(
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            '$totalMin분',
                                            style: const TextStyle(
                                              fontSize: 24,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.black87,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          if (option.startvehicletime != null && option.startvehicletime!.isNotEmpty) ...[
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: Colors.green.shade100,
                                                borderRadius: BorderRadius.circular(12),
                                                border: Border.all(color: Colors.green.shade300),
                                              ),
                                              child: Text(
                                                '첫차 ${option.startvehicletime!.substring(0, 5)}',
                                                style: TextStyle(
                                                  fontSize: 8,
                                                  fontWeight: FontWeight.w500,
                                                  color: Colors.green.shade700,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                          ],
                                          const Spacer(),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '도보 $walkMin분',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Positioned(
                                    right: 0,
                                    top: 0,
                                    child: IconButton(
                                      icon: Icon(Icons.notifications, color: Colors.grey.shade700),
                                      onPressed: () async {
                                        // "벨 아이콘 탭" → 상세 조회 후 저장 로직
                                        final baseUrl = dotenv.env['SERVER_BASE_URL']!;
                                        final detailUrl = Uri.parse('$baseUrl/traffic/routes/detail');
                                        final requestPayload = {
                                          'summaryKey': summaryData.summaryKey,
                                          'category': option.category,
                                          'index': index,
                                        };
                                        final detailResp = await http.post(
                                          detailUrl,
                                          headers: {'Content-Type': 'application/json'},
                                          body: jsonEncode(requestPayload),
                                        );
                                        if (detailResp.statusCode >= 200 && detailResp.statusCode < 300) {
                                          final detailData = RouteDetailResponse.parse(detailResp.body).data;
                                          RouteStore.selectedOption = detailData;

                                          // Load stored Google ID for identifying the user
                                          final prefs = await SharedPreferences.getInstance();
                                          final googleId = prefs.getString('googleId') ?? '';
                                          // Construct payload matching backend SavedRoute schema
                                          final savePayload = {
                                            'googleId': googleId,
                                            'origin': summaryData.origin,
                                            'destination': summaryData.destination,
                                            'arrivalTime': DateTime.now().toIso8601String(),
                                            'preparationTime': 0,
                                            'options': {},
                                            'category': option.category,
                                            'route': {
                                              'summary': option.toJson(),
                                              'detail': detailData.toJson(),
                                              'cityCode': option.cityCode,
                                              'busId': option.busId,
                                              'departureStopId': option.departureStopId,
                                              'linkIds': <String>[],
                                              'sectionIds': <String>[],
                                            },
                                          };
                                          try {
                                            final saveResp = await http.post(
                                              Uri.parse('$baseUrl/traffic/routes/save'),
                                              headers: {'Content-Type': 'application/json'},
                                              body: jsonEncode(savePayload),
                                            );
                                            if (saveResp.statusCode >= 200 && saveResp.statusCode < 300) {
                                              final now = DateTime.now();
                                              EventService().addEventWithDetails(
                                                now,
                                                '경로: ${summaryData.origin} → ${summaryData.destination}',
                                                title: '저장된 경로',
                                                time: DateFormat('HH:mm').format(now),
                                              );
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(content: Text('경로가 저장되었습니다.')),
                                              );
                                            } else {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(content: Text('경로 저장 실패: ${saveResp.statusCode}')),
                                              );
                                            }
                                          } catch (e) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(content: Text('서버 통신 오류')),
                                            );
                                          }
                                          // 화면 팝(Pop) 연쇄
                                          Navigator.of(context).pop();
                                          Navigator.of(context).pop();
                                          Navigator.of(context).pop();
                                        } else {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('상세 조회 실패: ${detailResp.statusCode}')),
                                          );
                                        }
                                      },
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 8),

                              // (2) 분할 막대 시각화: 아이콘 + 분 단위 텍스트 (최소 너비 확보 후 비례 분배)
                              SizedBox(
                                height: 32,
                                child: LayoutBuilder(
                                  builder: (context, constraints) {
                                    final double totalWidth = constraints.maxWidth;
                                    final int count = segments.length;
                                    const double minSegmentWidth = 60.0;

                                    // 1) rawWidths 계산
                                    final List<double> rawWidths = segments
                                        .map((seg) => (seg.seconds / safeTotal) * totalWidth)
                                        .toList();
                                    // 2) 실제 widths 초기화
                                    final List<double> widths = List<double>.filled(count, 0.0);

                                    // 3) 최소 너비 확보해야 할 세그먼트 체크
                                    double usedMinWidth = 0;
                                    double restTotalSeconds = 0;
                                    final List<int> needFlexIndices = [];

                                    for (int j = 0; j < count; j++) {
                                      if (rawWidths[j] < minSegmentWidth) {
                                        widths[j] = minSegmentWidth;
                                        usedMinWidth += minSegmentWidth;
                                      } else {
                                        needFlexIndices.add(j);
                                        restTotalSeconds += segments[j].seconds;
                                      }
                                    }

                                    // 4) 남은 가로 공간 계산
                                    double remainingWidth = totalWidth - usedMinWidth;
                                    if (remainingWidth < 0) remainingWidth = 0;

                                    // 5) 나머지 세그먼트 비례 분배
                                    double assignedSoFar = 0;
                                    for (int k = 0; k < needFlexIndices.length; k++) {
                                      final int j = needFlexIndices[k];
                                      if (k == needFlexIndices.length - 1) {
                                        widths[j] = remainingWidth - assignedSoFar;
                                      } else {
                                        final double w = (segments[j].seconds / restTotalSeconds) * remainingWidth;
                                        widths[j] = w;
                                        assignedSoFar += w;
                                      }
                                    }

                                    // 6) 실제 막대 그리기
                                    return Row(
                                      children: List.generate(count, (j) {
                                        final seg = segments[j];
                                        final bool isFirst = (j == 0);
                                        final bool isLast = (j == count - 1);
                                        // 모드별 색상 및 배경 색 구분
                                        Color segColor;
                                        Color circleBgColor;
                                        const Color iconColor = Colors.white;
                                        switch (seg.mode) {
                                          case 'BUS':
                                            segColor = Colors.blue;
                                            circleBgColor = Colors.blue.shade700;
                                            break;
                                          case 'SUBWAY':
                                            segColor = Colors.purple;
                                            circleBgColor = Colors.purple.shade700;
                                            break;
                                          default: // WALK, 기타
                                            segColor = Colors.grey.shade300;
                                            circleBgColor = Colors.grey.shade500;
                                        }
                                        final Color textColor = (seg.mode == 'WALK')
                                            ? Colors.grey.shade800
                                            : Colors.white;

                                        // 모서리 둥글게 처리 (pill)
                                        BorderRadius radius = BorderRadius.zero;
                                        if (isFirst && isLast) {
                                          radius = BorderRadius.circular(12);
                                        } else if (isFirst) {
                                          radius = const BorderRadius.only(
                                            topLeft: Radius.circular(12),
                                            bottomLeft: Radius.circular(12),
                                          );
                                        } else if (isLast) {
                                          radius = const BorderRadius.only(
                                            topRight: Radius.circular(12),
                                            bottomRight: Radius.circular(12),
                                          );
                                        }

                                        return Container(
                                          width: widths[j],
                                          height: 24,
                                          decoration: BoxDecoration(
                                            color: segColor,
                                            borderRadius: radius,
                                          ),
                                          padding: const EdgeInsets.symmetric(horizontal: 4),
                                          child: FittedBox(
                                            fit: BoxFit.scaleDown,
                                            alignment: Alignment.centerLeft,
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              crossAxisAlignment: CrossAxisAlignment.center,
                                              children: [
                                                // 도보 첫 세그먼트에만 아이콘
                                                if (seg.mode == 'WALK' && j == 0) ...[
                                                  Container(
                                                    width: 20,
                                                    height: 20,
                                                    decoration: BoxDecoration(
                                                      color: circleBgColor,
                                                      shape: BoxShape.circle,
                                                    ),
                                                    child: const Center(
                                                      child: Icon(
                                                        Icons.directions_walk,
                                                        size: 12,
                                                        color: iconColor,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 4),
                                                ],
                                                // 버스 세그먼트 아이콘
                                                if (seg.mode == 'BUS') ...[
                                                  Container(
                                                    width: 20,
                                                    height: 20,
                                                    decoration: BoxDecoration(
                                                      color: circleBgColor,
                                                      shape: BoxShape.circle,
                                                    ),
                                                    child: const Center(
                                                      child: Icon(
                                                        Icons.directions_bus,
                                                        size: 12,
                                                        color: iconColor,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 4),
                                                ],
                                                // 지하철 세그먼트 아이콘
                                                if (seg.mode == 'SUBWAY') ...[
                                                  Container(
                                                    width: 20,
                                                    height: 20,
                                                    decoration: BoxDecoration(
                                                      color: circleBgColor,
                                                      shape: BoxShape.circle,
                                                    ),
                                                    child: const Center(
                                                      child: Icon(
                                                        Icons.subway,
                                                        size: 12,
                                                        color: iconColor,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 4),
                                                ],
                                                // 분 단위 텍스트
                                                Text(
                                                  '${(seg.seconds / 60).ceil()}분',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w500,
                                                    color: textColor,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      }),
                                    );
                                  },
                                ),
                              ),

                              const SizedBox(height: 8),

                              // (3) 세로 정류장 + 버스 번호 + 추가 정보
                              Stack(
                                children: [
                                  // 배경 세로 연결선
                                  Positioned(
                                    left: 9,
                                    top: 0,
                                    bottom: 0,
                                    child: Container(
                                      width: 2,
                                      color: Colors.grey.shade300,
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      if (stops.isNotEmpty) ...[
                                        // 출발 정류장 (파란 원 + 흰 버스 아이콘)
                                        Row(
                                          crossAxisAlignment: CrossAxisAlignment.center,
                                          children: [
                                            Container(
                                              width: 20,
                                              height: 20,
                                              decoration: const BoxDecoration(
                                                color: Colors.blue,
                                                shape: BoxShape.circle,
                                              ),
                                              child: const Center(
                                                child: Icon(
                                                  Icons.directions_bus,
                                                  size: 12,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              stops[0],
                                              style: const TextStyle(
                                                fontSize: 13,
                                                color: Colors.black87,
                                              ),
                                            ),
                                          ],
                                        ),

                                        // 출발 정류장 바로 밑: 노선 유형 + 버스 번호
                                        if (routeNames.isNotEmpty) ...[
                                          const SizedBox(height: 2),
                                          Padding(
                                            padding: const EdgeInsets.only(left: 28),
                                            child: Row(
                                              children: [
                                                // 노선 유형 태그 (간선, 지선 등)
                                                if (option.routetp != null && option.routetp!.isNotEmpty) ...[
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: Colors.blue.shade50,
                                                      borderRadius: BorderRadius.circular(8),
                                                      border: Border.all(color: Colors.blue.shade200),
                                                    ),
                                                    child: Text(
                                                      option.routetp!,
                                                      style: TextStyle(
                                                        fontSize: 9,
                                                        fontWeight: FontWeight.w500,
                                                        color: Colors.blue.shade700,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                ],
                                                // 버스 번호
                                                Text(
                                                  routeNames,
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w600,
                                                    color: Colors.blue.shade700,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],

                                        const SizedBox(height: 4),
                                      ],
                                      if (stops.length >= 2) ...[
                                        // 도착 정류장 (연회색 원 + 회색 버스 아이콘)
                                        Row(
                                          crossAxisAlignment: CrossAxisAlignment.center,
                                          children: [
                                            Container(
                                              width: 20,
                                              height: 20,
                                              decoration: BoxDecoration(
                                                color: Colors.grey[300],
                                                shape: BoxShape.circle,
                                              ),
                                              child: const Center(
                                                child: Icon(
                                                  Icons.directions_bus,
                                                  size: 12,
                                                  color: Colors.grey,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              stops[1],
                                              style: const TextStyle(
                                                fontSize: 13,
                                                color: Colors.black87,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),

                              const SizedBox(height: 8),
                              // "선택" 버튼은 제거되었습니다.
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

/// 구간 정보를 저장하는 클래스
class _Segment {
  final String mode; // 'WALK' 또는 'BUS'
  final int seconds;

  _Segment({required this.mode, required this.seconds});
}