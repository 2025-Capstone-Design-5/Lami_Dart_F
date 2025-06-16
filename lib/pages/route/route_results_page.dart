import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:untitled4/models/summary_response.dart';
import 'package:untitled4/models/route_detail_response.dart';
import 'package:untitled4/pages/route/route_detail_page.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:untitled4/event_service.dart';
import 'dart:convert';
import 'package:untitled4/route_store.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:untitled4/config/server_config.dart';
import 'package:untitled4/pages/assistant/assistant_page.dart';
import '../../services/calendar_service.dart';

/// RouteResultsPage: SummaryData를 받아 여러 경로 옵션을 탭별로 보여주는 페이지
class RouteResultsPage extends StatefulWidget {
  final SummaryData summaryData;

  const RouteResultsPage({Key? key, required this.summaryData})
      : super(key: key);

  @override
  State<RouteResultsPage> createState() => _RouteResultsPageState();
}

class _RouteResultsPageState extends State<RouteResultsPage> {
  SummaryData get summaryData => widget.summaryData;
  bool _sortFastest = false;

  @override
  Widget build(BuildContext context) {
    // 1) 탭 목록과 각 탭에 해당하는 경로 리스트 생성
    final tabs = ['전체 보기', '도보', '자동차', '버스', '지하철', '버스+지하철'];
    final lists = <List<dynamic>>[
      List<dynamic>.from(widget.summaryData.routes),
      widget.summaryData.routes.where((r) => r.category == 'walk').toList(),
      widget.summaryData.routes.where((r) => r.category == 'car').toList(),
      widget.summaryData.routes.where((r) => r.category == 'bus').toList(),
      widget.summaryData.routes.where((r) => r.category == 'subway').toList(),
      widget.summaryData.routes.where((r) => r.category == 'bus_subway').toList(),
    ];
    
    // Debug logging for filtered routes
    print('===== FILTERED ROUTES DEBUG =====');
    for (int i = 0; i < tabs.length; i++) {
      print('${tabs[i]} (${lists[i].length} routes)');
    }
    
    // Check if any routes might be missing due to category mismatch
    final allCategories = widget.summaryData.routes.map((r) => r.category).toSet();
    final expectedCategories = {'walk', 'car', 'bus', 'subway', 'bus_subway'};
    final unexpectedCategories = allCategories.difference(expectedCategories);
    if (unexpectedCategories.isNotEmpty) {
      print('WARNING: Found unexpected categories: $unexpectedCategories');
    }
    print('================================');

    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        extendBodyBehindAppBar: true,
        backgroundColor: const Color(0xFF0A0E27),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text(
            '경로 결과',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          iconTheme: const IconThemeData(color: Colors.white),
          bottom: TabBar(
            isScrollable: true,
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white.withOpacity(0.5),
            tabs: tabs.map((t) => Tab(text: t)).toList(),
          ),
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
            // Main content with sort control + tab views
            SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        const Text('정렬', style: TextStyle(color: Colors.white70)),
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: () => setState(() { _sortFastest = !_sortFastest; }),
                          child: Text(
                            _sortFastest ? '기본 순서' : '가장 빠른 순',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: TabBarView(
                      children: List.generate(
                        lists.length,
                        (i) {
                          final options = List<dynamic>.from(lists[i]);
                          if (_sortFastest) {
                            options.sort((a, b) => a.duration.compareTo(b.duration));
                          }

                          if (options.isEmpty) {
                            return Center(
                              child: Text(
                                '결과 없음',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.7),
                                  fontSize: 16,
                                ),
                              ),
                            );
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
                                  onTap: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => RouteDetailPage.fromSummaryKey(
                                          summaryKey: widget.summaryData.summaryKey,
                                          category: option.category,
                                          index: index,
                                        ),
                                      ),
                                    );
                                  },
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: Colors.white.withOpacity(0.2),
                                        width: 1,
                                      ),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(20),
                                      child: BackdropFilter(
                                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
                                                              color: Colors.white,
                                                            ),
                                                          ),
                                                          const SizedBox(width: 8),
                                                          if (option.startvehicletime != null && option.startvehicletime!.isNotEmpty) ...[
                                                            Container(
                                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                              decoration: BoxDecoration(
                                                                color: Colors.green.withOpacity(0.2),
                                                                borderRadius: BorderRadius.circular(12),
                                                                border: Border.all(color: Colors.green.withOpacity(0.5)),
                                                              ),
                                                              child: Text(
                                                                '첫차 ${option.startvehicletime!.substring(0, 5)}',
                                                                style: const TextStyle(
                                                                  fontSize: 8,
                                                                  fontWeight: FontWeight.w500,
                                                                  color: Colors.green,
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
                                                          color: Colors.white.withOpacity(0.7),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  Positioned(
                                                    right: 0,
                                                    top: 0,
                                                    child: Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        // 즐겨찾기 버튼
                                                        IconButton(
                                                          icon: Icon(
                                                            option.isFavorite == true ? Icons.favorite : Icons.favorite_border,
                                                            color: option.isFavorite == true ? Colors.red : Colors.white.withOpacity(0.7),
                                                          ),
                                                          onPressed: () async {
                                                            await _handleFavoriteAction(option, widget.summaryData, index);
                                                          },
                                                        ),
                                                        // 알람 버튼 (상세 설정 생략)
                                                        IconButton(
                                                          icon: const Icon(Icons.alarm, color: Colors.deepOrange),
                                                          tooltip: '이 경로로 알림 설정',
                                                          onPressed: () {
                                                            _showAlarmDialog(option, widget.summaryData, index);
                                                          },
                                                        ),
                                                      ],
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
                                                                color: Colors.white,
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
                                        // (4) 실시간 도착 정보 표시
                                        Text(
                                          option.realtimeArrivalTimes.isNotEmpty
                                              ? '실시간 도착 정보: ${option.realtimeArrivalTimes.first}'
                                              : '실시간 도착 정보 없음',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                  ),),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 즐겨찾기 액션 처리
  Future<void> _handleFavoriteAction(RouteSummary option, SummaryData summaryData, int index) async {
    final String baseUrl = getServerBaseUrl();
    final detailUrl = Uri.parse('${getServerBaseUrl()}/traffic/routes/detail');
    
    // 먼저 상세 정보 조회
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
      final prefs = await SharedPreferences.getInstance();
      final googleId = prefs.getString('googleId') ?? '';
      
      // 즐겨찾기 토글 - 서버에서 토글 처리
      const action = 'favorite';
      
      final quickActionPayload = {
        'googleId': googleId,
        'origin': summaryData.origin,
        'destination': summaryData.destination,
        'arrivalTime': DateTime.now().toIso8601String(),
        'category': 'general',
        'summary': option.toJson(),
        'detail': detailData.toJson(),
        'action': action,
      };
      
      try {
        final resp = await http.post(
          Uri.parse('${getServerBaseUrl()}/traffic/routes/quick-action'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(quickActionPayload),
        );
        
        if (resp.statusCode >= 200 && resp.statusCode < 300) {
          setState(() {
            // UI 상태 업데이트
            option.isFavorite = !(option.isFavorite ?? false);
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(option.isFavorite == true ? '즐겨찾기에 추가되었습니다.' : '즐겨찾기에서 제거되었습니다.')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('즐겨찾기 처리 실패: ${resp.statusCode}')),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('서버 통신 오류')),
        );
      }
    }
  }

  // 알람 액션 처리 및 경로 저장
  Future<void> _handleAlarmAction(RouteSummary option, SummaryData summaryData, int index, String arrivalTime, int preparationTime) async {
    try {
      // 1. 사용자 정보 로드
      final prefs = await SharedPreferences.getInstance();
      final googleId = prefs.getString('googleId') ?? '';
      if (googleId.isEmpty) {
        throw Exception('사용자 정보를 찾을 수 없습니다.');
      }

      // 2. 경로 상세 조회
      final detailUrl = Uri.parse('${getServerBaseUrl()}/traffic/routes/detail');
      final detailPayload = {
        'summaryKey': summaryData.summaryKey,
        'category': option.category,
        'index': index,
      };
      final detailResp = await http.post(
        detailUrl,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(detailPayload),
      );
      if (detailResp.statusCode < 200 || detailResp.statusCode >= 300) {
        throw Exception('경로 상세 조회 실패: ${detailResp.statusCode}');
      }
      final detailData = RouteDetailResponse.parse(detailResp.body).data;

      // 3. 경로 저장 및 알람 등록
      final saveUrl = Uri.parse('${getServerBaseUrl()}/traffic/routes/save');
      final savePayload = {
        'googleId': googleId,
        'origin': summaryData.origin,
        'destination': summaryData.destination,
        'arrivalTime': arrivalTime,
        'preparationTime': preparationTime,
        'summary': option.toJson(),
        'detail': detailData.toJson(),
        'category': option.category,
      };
      final saveResp = await http.post(
        saveUrl,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(savePayload),
      );
      if (saveResp.statusCode < 200 || saveResp.statusCode >= 300) {
        throw Exception('경로 저장 및 알람 등록 실패: ${saveResp.body}');
      }

      // 서버 응답에서 savedRouteId를 추출하여 전역 상태에 저장
      final saveBody = jsonDecode(saveResp.body) as Map<String, dynamic>;
      final savedRouteId = saveBody['id'] as String?;
      if (savedRouteId != null) {
        RouteStore.selectedRouteId = savedRouteId;
      }

      // 4. Google Calendar에 일정 추가
      if (!CalendarService.isSignedIn()) {
        await CalendarService.signIn();
      }
      final arrivalDt = DateTime.parse(arrivalTime);
      final startDt = arrivalDt.subtract(Duration(minutes: preparationTime));
      await CalendarService.addEvent(
        summary: '🚗 경로 알람: ${summaryData.origin} → ${summaryData.destination}',
        start: startDt,
        end: arrivalDt,
        description: '준비시간: ${preparationTime}분\n경로: ${option.routeShortNames.join(" → ")}',
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('경로 저장 및 알람이 등록되었습니다.')),
      );
      RouteStore.onAlarmSet?.call();
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('알람 설정 실패: $e')),
      );
    }
  }

  // 알람 설정 모달 다이얼로그 표시
  Future<void> _showAlarmDialog(RouteSummary option, SummaryData summaryData, int index) async {
    // 초기값: 오늘 날짜, 현재 시간, 준비 시간 0분
    DateTime selectedDate = DateTime.now();
    TimeOfDay selectedTime = TimeOfDay.now();
    int prepMinutes = 0;
    final dateController = TextEditingController(text: DateFormat('yyyy-MM-dd').format(selectedDate));
    final timeController = TextEditingController(text: selectedTime.format(context));
    final prepController = TextEditingController(text: '0');
    try {
      await showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('알람 설정'),
            content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 날짜 선택
                      TextField(
                        controller: dateController,
                        readOnly: true,
                  decoration: const InputDecoration(labelText: '날짜'),
                        onTap: () async {
                          final pickedDate = await showDatePicker(
                            context: context,
                            initialDate: selectedDate,
                            firstDate: DateTime.now().subtract(const Duration(days: 1)),
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                          );
                          if (pickedDate != null) {
                            selectedDate = pickedDate;
                            dateController.text = DateFormat('yyyy-MM-dd').format(pickedDate);
                          }
                        },
                      ),
                const SizedBox(height: 8),
                      // 시간 선택
                      TextField(
                        controller: timeController,
                        readOnly: true,
                  decoration: const InputDecoration(labelText: '도착 시간'),
                        onTap: () async {
                          final picked = await showTimePicker(
                            context: context,
                            initialTime: selectedTime,
                          );
                          if (picked != null) {
                            selectedTime = picked;
                            timeController.text = picked.format(context);
                          }
                        },
                      ),
                const SizedBox(height: 8),
                      TextField(
                        controller: prepController,
                        keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: '준비 시간 (분)'),
                        ),
              ],
                      ),
            actions: [
                          TextButton(
                child: const Text('취소'),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                          TextButton(
                child: const Text('확인'),
                            onPressed: () async {
                              prepMinutes = int.tryParse(prepController.text) ?? 0;
                              final arrivalDate = DateTime(
                                selectedDate.year,
                                selectedDate.month,
                                selectedDate.day,
                                selectedTime.hour,
                                selectedTime.minute,
                              );
                              final arrivalIso = arrivalDate.toIso8601String();
                              Navigator.of(context).pop();
                              try {
                                await _handleAlarmAction(
                                  option,
                                  summaryData,
                                  index,
                                  arrivalIso,
                                  prepMinutes,
                                );
                              } catch (e) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('알람 설정 중 오류: $e')),
                                );
                              }
                            },
                          ),
                        ],
          );
        },
      );
    } catch (e) {
      debugPrint('Error showing alarm dialog: $e');
    }
  }
}

/// 구간 정보를 저장하는 클래스
class _Segment {
  final String mode; // 'WALK' 또는 'BUS'
  final int seconds;

  _Segment({required this.mode, required this.seconds});
}