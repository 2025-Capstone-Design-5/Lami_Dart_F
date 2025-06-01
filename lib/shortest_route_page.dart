import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

enum TransportMode {
  bus('버스', Icons.directions_bus, Color(0xFF10B981)),
  subway('지하철', Icons.train, Color(0xFF2563EB)),
  transfer('버스+지하철', Icons.transfer_within_a_station, Color(0xFF8B5CF6));

  const TransportMode(this.label, this.icon, this.color);
  final String label;
  final IconData icon;
  final Color color;
}

class RouteOption {
  final String id;
  final TransportMode transportMode;
  final String routeName; // 경로 이름 (예: "최단시간", "최저요금", "환승최소")
  final String estimatedTime;
  final String totalDistance;
  final String cost;
  final int transferCount; // 환승 횟수
  final List<RouteStep> routes;
  final String? additionalInfo; // 추가 정보

  RouteOption({
    required this.id,
    required this.transportMode,
    required this.routeName,
    required this.estimatedTime,
    required this.totalDistance,
    required this.cost,
    required this.transferCount,
    required this.routes,
    this.additionalInfo,
  });

  factory RouteOption.fromJson(Map<String, dynamic> json) {
    return RouteOption(
      id: json['id'],
      transportMode: TransportMode.values.firstWhere(
              (mode) => mode.name == json['transportMode']
      ),
      routeName: json['routeName'],
      estimatedTime: json['estimatedTime'],
      totalDistance: json['totalDistance'],
      cost: json['cost'],
      transferCount: json['transferCount'] ?? 0,
      routes: (json['routes'] as List)
          .map((step) => RouteStep.fromJson(step))
          .toList(),
      additionalInfo: json['additionalInfo'],
    );
  }
}

class RouteData {
  final String departure;
  final String destination;
  final Map<TransportMode, List<RouteOption>> routesByMode;

  RouteData({
    required this.departure,
    required this.destination,
    required this.routesByMode,
  });

  factory RouteData.fromJson(Map<String, dynamic> json) {
    Map<TransportMode, List<RouteOption>> routesByMode = {};

    for (var mode in TransportMode.values) {
      if (json['routesByMode'][mode.name] != null) {
        routesByMode[mode] = (json['routesByMode'][mode.name] as List)
            .map((route) => RouteOption.fromJson(route))
            .toList();
      }
    }

    return RouteData(
      departure: json['departure'],
      destination: json['destination'],
      routesByMode: routesByMode,
    );
  }
}

class RouteStep {
  final int id;
  final String step;
  final String method;
  final String duration;
  final String description;
  final String icon;

  RouteStep({
    required this.id,
    required this.step,
    required this.method,
    required this.duration,
    required this.description,
    required this.icon,
  });

  factory RouteStep.fromJson(Map<String, dynamic> json) {
    return RouteStep(
      id: json['id'],
      step: json['step'],
      method: json['method'],
      duration: json['duration'],
      description: json['description'],
      icon: json['icon'],
    );
  }
}

// API 서비스 클래스
class RouteApiService {
  static const String baseUrl = 'https://your-api-server.com/api';

  static Future<RouteData> fetchRoutes({
    required String departure,
    required String destination,
    String? departureTime,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/routes'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'departure': departure,
          'destination': destination,
          'departureTime': departureTime,
        }),
      );

      if (response.statusCode == 200) {
        return RouteData.fromJson(jsonDecode(response.body));
      } else {
        throw Exception('Failed to fetch routes: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }
}

class ShortestRoutePage extends StatefulWidget {
  final String? departure;
  final String? destination;

  const ShortestRoutePage({
    Key? key,
    this.departure,
    this.destination,
  }) : super(key: key);

  @override
  State<ShortestRoutePage> createState() => _ShortestRoutePageState();
}

class _ShortestRoutePageState extends State<ShortestRoutePage> {
  RouteData? routeData;
  TransportMode? selectedMode;
  RouteOption? selectedRoute;
  bool isLoading = true;
  bool showModeSelection = true;
  bool showRouteOptions = false;
  bool showRouteDetail = false;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    fetchRouteData();
  }

  Future<void> fetchRouteData() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
      showModeSelection = true;
      showRouteOptions = false;
      showRouteDetail = false;
      selectedMode = null;
      selectedRoute = null;
    });

    try {
      // 실제 환경에서는 RouteApiService.fetchRoutes() 사용
      // final data = await RouteApiService.fetchRoutes(
      //   departure: widget.departure ?? "서울역",
      //   destination: widget.destination ?? "강남역",
      // );

      // 목업 데이터 (개발/테스트용)
      await Future.delayed(const Duration(seconds: 1));
      final data = _getMockData();

      setState(() {
        routeData = data;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = e.toString();
      });
    }
  }

  RouteData _getMockData() {
    return RouteData(
      departure: widget.departure ?? "서울역",
      destination: widget.destination ?? "강남역",
      routesByMode: {
        TransportMode.bus: [
          RouteOption(
            id: "bus_1",
            transportMode: TransportMode.bus,
            routeName: "최단시간",
            estimatedTime: "58분",
            totalDistance: "24.8km",
            cost: "1,500원",
            transferCount: 0,
            additionalInfo: "직행 · 배차간격 5-7분",
            routes: [
              RouteStep(id: 1, step: "서울역 출발", method: "도보", duration: "5분", description: "서울역 광장 버스정류장으로 이동", icon: "🚶‍♂️"),
              RouteStep(id: 2, step: "간선버스 472번 탑승", method: "버스", duration: "48분", description: "472번 강남역 방면 → 강남역 정류장까지", icon: "🚌"),
              RouteStep(id: 3, step: "강남역 도착", method: "도보", duration: "5분", description: "강남역 정류장에서 목적지까지 도보 이동", icon: "🏁"),
            ],
          ),
          RouteOption(
            id: "bus_2",
            transportMode: TransportMode.bus,
            routeName: "최저요금",
            estimatedTime: "65분",
            totalDistance: "25.2km",
            cost: "1,300원",
            transferCount: 1,
            additionalInfo: "1회 환승 · 심야시간 운행",
            routes: [
              RouteStep(id: 1, step: "서울역 출발", method: "도보", duration: "3분", description: "서울역 2번 출구 버스정류장", icon: "🚶‍♂️"),
              RouteStep(id: 2, step: "간선버스 143번 탑승", method: "버스", duration: "25분", description: "143번 → 교대역 정류장까지", icon: "🚌"),
              RouteStep(id: 3, step: "교대역 환승", method: "환승", duration: "5분", description: "507번 버스로 환승", icon: "🔄"),
              RouteStep(id: 4, step: "간선버스 507번 탑승", method: "버스", duration: "28분", description: "507번 → 강남역까지", icon: "🚌"),
              RouteStep(id: 5, step: "강남역 도착", method: "도보", duration: "4분", description: "목적지까지 도보 이동", icon: "🏁"),
            ],
          ),
        ],
        TransportMode.subway: [
          RouteOption(
            id: "subway_1",
            transportMode: TransportMode.subway,
            routeName: "최단시간",
            estimatedTime: "45분",
            totalDistance: "23.1km",
            cost: "1,950원",
            transferCount: 1,
            additionalInfo: "1회 환승 · 출근시간 혼잡",
            routes: [
              RouteStep(id: 1, step: "서울역 출발", method: "도보", duration: "3분", description: "서울역 1번 출구로 나와서 지하철 4호선 승강장", icon: "🚶‍♂️"),
              RouteStep(id: 2, step: "지하철 4호선 탑승", method: "지하철", duration: "15분", description: "4호선 당고개 방면 → 동대문역사문화공원역 (8정거장)", icon: "🚇"),
              RouteStep(id: 3, step: "동대문역사문화공원역 환승", method: "환승", duration: "5분", description: "2호선으로 환승 (환승통로 이용)", icon: "🔄"),
              RouteStep(id: 4, step: "지하철 2호선 탑승", method: "지하철", duration: "20분", description: "2호선 잠실 방면 → 강남역 (11정거장)", icon: "🚇"),
              RouteStep(id: 5, step: "강남역 도착", method: "도보", duration: "2분", description: "강남역 12번 출구로 목적지 도착", icon: "🏁"),
            ],
          ),
          RouteOption(
            id: "subway_2",
            transportMode: TransportMode.subway,
            routeName: "환승최소",
            estimatedTime: "52분",
            totalDistance: "26.4km",
            cost: "1,950원",
            transferCount: 2,
            additionalInfo: "2회 환승 · 상대적으로 여유로움",
            routes: [
              RouteStep(id: 1, step: "서울역 출발", method: "도보", duration: "4분", description: "서울역 지하철 1호선 승강장", icon: "🚶‍♂️"),
              RouteStep(id: 2, step: "지하철 1호선 탑승", method: "지하철", duration: "8분", description: "1호선 인천 방면 → 시청역 (3정거장)", icon: "🚇"),
              RouteStep(id: 3, step: "시청역 환승", method: "환승", duration: "4분", description: "2호선으로 환승", icon: "🔄"),
              RouteStep(id: 4, step: "지하철 2호선 탑승", method: "지하철", duration: "33분", description: "2호선 잠실 방면 → 강남역 (18정거장)", icon: "🚇"),
              RouteStep(id: 5, step: "강남역 도착", method: "도보", duration: "3분", description: "강남역 12번 출구로 목적지 도착", icon: "🏁"),
            ],
          ),
        ],
        TransportMode.transfer: [
          RouteOption(
            id: "transfer_1",
            transportMode: TransportMode.transfer,
            routeName: "최적경로",
            estimatedTime: "42분",
            totalDistance: "22.8km",
            cost: "1,950원",
            transferCount: 1,
            additionalInfo: "버스+지하철 · 실시간 최적화",
            routes: [
              RouteStep(id: 1, step: "서울역 출발", method: "도보", duration: "3분", description: "서울역 광장 버스정류장", icon: "🚶‍♂️"),
              RouteStep(id: 2, step: "간선버스 162번 탑승", method: "버스", duration: "18분", description: "162번 → 을지로입구역 정류장", icon: "🚌"),
              RouteStep(id: 3, step: "을지로입구역 환승", method: "환승", duration: "4분", description: "지하철 2호선으로 환승", icon: "🔄"),
              RouteStep(id: 4, step: "지하철 2호선 탑승", method: "지하철", duration: "15분", description: "2호선 잠실 방면 → 강남역 (9정거장)", icon: "🚇"),
              RouteStep(id: 5, step: "강남역 도착", method: "도보", duration: "2분", description: "강남역 12번 출구로 목적지 도착", icon: "🏁"),
            ],
          ),
          RouteOption(
            id: "transfer_2",
            transportMode: TransportMode.transfer,
            routeName: "저렴한경로",
            estimatedTime: "48분",
            totalDistance: "24.1km",
            cost: "1,750원",
            transferCount: 1,
            additionalInfo: "버스+지하철 · 요금 절약형",
            routes: [
              RouteStep(id: 1, step: "서울역 출발", method: "도보", duration: "5분", description: "서울역 버스정류장", icon: "🚶‍♂️"),
              RouteStep(id: 2, step: "광역버스 9401번 탑승", method: "버스", duration: "22분", description: "9401번 → 삼성역 정류장", icon: "🚌"),
              RouteStep(id: 3, step: "삼성역 환승", method: "환승", duration: "6분", description: "지하철 2호선으로 환승", icon: "🔄"),
              RouteStep(id: 4, step: "지하철 2호선 탑승", method: "지하철", duration: "4분", description: "2호선 신도림 방면 → 강남역 (2정거장)", icon: "🚇"),
              RouteStep(id: 5, step: "강남역 도착", method: "도보", duration: "3분", description: "강남역 12번 출구로 목적지 도착", icon: "🏁"),
            ],
          ),
        ],
      },
    );
  }

  void selectTransportMode(TransportMode mode) {
    setState(() {
      selectedMode = mode;
      showModeSelection = false;
      showRouteOptions = true;
      showRouteDetail = false;
      selectedRoute = null;
    });
  }

  void selectRoute(RouteOption route) {
    setState(() {
      selectedRoute = route;
      showRouteOptions = false;
      showRouteDetail = true;
    });
  }

  void goBackToModeSelection() {
    setState(() {
      showModeSelection = true;
      showRouteOptions = false;
      showRouteDetail = false;
      selectedMode = null;
      selectedRoute = null;
    });
  }

  void goBackToRouteOptions() {
    setState(() {
      showRouteOptions = true;
      showRouteDetail = false;
      selectedRoute = null;
    });
  }

  String _getAppBarTitle() {
    if (showRouteDetail) return '상세 경로';
    if (showRouteOptions) return '${selectedMode?.label} 경로 선택';
    return '경로 검색';
  }

  Widget? _getAppBarLeading() {
    if (showRouteDetail) {
      return IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: goBackToRouteOptions,
      );
    }
    if (showRouteOptions) {
      return IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: goBackToModeSelection,
      );
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.navigation, color: Color(0xFF2563EB)),
            const SizedBox(width: 8),
            Text(_getAppBarTitle()),
          ],
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 1,
        shadowColor: Colors.black12,
        titleTextStyle: const TextStyle(
          color: Color(0xFF1F2937),
          fontWeight: FontWeight.bold,
          fontSize: 20,
        ),
        iconTheme: const IconThemeData(color: Color(0xFF1F2937)),
        leading: _getAppBarLeading(),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (isLoading) return _buildLoadingWidget();
    if (errorMessage != null) return _buildErrorWidget();
    if (showRouteDetail) return _buildRouteDetailContent();
    if (showRouteOptions) return _buildRouteOptionsContent();
    return _buildModeSelectionContent();
  }

  Widget _buildLoadingWidget() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
          ),
          SizedBox(height: 16),
          Text(
            '경로를 찾는 중...',
            style: TextStyle(
              color: Color(0xFF6B7280),
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              color: Color(0xFFEF4444),
              size: 64,
            ),
            const SizedBox(height: 16),
            Text(
              '경로를 불러올 수 없습니다',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1F2937),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF6B7280),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: fetchRouteData,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('다시 시도'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeSelectionContent() {
    if (routeData == null) return const SizedBox();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildDepartureDestinationCard(),
          const SizedBox(height: 24),
          _buildTransportModeSelection(),
          const SizedBox(height: 24),
          _buildRefreshButton(),
        ],
      ),
    );
  }

  Widget _buildTransportModeSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '교통수단 선택',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1F2937),
          ),
        ),
        const SizedBox(height: 16),
        ...TransportMode.values.map((mode) {
          final routes = routeData!.routesByMode[mode] ?? [];
          if (routes.isEmpty) return const SizedBox();

          return _buildTransportModeCard(mode, routes.length);
        }).toList(),
      ],
    );
  }

  Widget _buildTransportModeCard(TransportMode mode, int routeCount) {
    final routes = routeData!.routesByMode[mode] ?? [];
    final bestRoute = routes.isNotEmpty ? routes.first : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => selectTransportMode(mode),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: mode.color.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    mode.icon,
                    color: mode.color,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            mode.label,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1F2937),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: mode.color.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '$routeCount개 경로',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: mode.color,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (bestRoute != null) ...[
                        Text(
                          '최단: ${bestRoute.estimatedTime} · ${bestRoute.cost}',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          bestRoute.routeName,
                          style: TextStyle(
                            fontSize: 12,
                            color: mode.color,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  color: Color(0xFF9CA3AF),
                  size: 24,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRouteOptionsContent() {
    if (selectedMode == null || routeData == null) return const SizedBox();

    final routes = routeData!.routesByMode[selectedMode!] ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildDepartureDestinationCard(),
          const SizedBox(height: 24),
          _buildRouteOptionsSection(routes),
        ],
      ),
    );
  }

  Widget _buildRouteOptionsSection(List<RouteOption> routes) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${selectedMode!.label} 경로 옵션',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1F2937),
          ),
        ),
        const SizedBox(height: 16),
        ...routes.map((route) => _buildRouteOptionCard(route)).toList(),
      ],
    );
  }

  Widget _buildRouteOptionCard(RouteOption option) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => selectRoute(option),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: option.transportMode.color.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        option.transportMode.icon,
                        color: option.transportMode.color,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                option.routeName,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1F2937),
                                ),
                              ),
                              if (option.transferCount > 0) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0x1AF59E0B),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '환승${option.transferCount}회',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: Color(0xFFF59E0B),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${option.estimatedTime} · ${option.totalDistance}',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                          if (option.additionalInfo != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              option.additionalInfo!,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF9CA3AF),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: option.transportMode.color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            option.estimatedTime,
                            style: TextStyle(
                              color: option.transportMode.color,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          option.cost,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.chevron_right,
                      color: Color(0xFF9CA3AF),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDepartureDestinationCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '경로 정보',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 20),
          _buildLocationItem(
            "출발지",
            routeData!.departure,
            const Color(0xFF10B981),
          ),
          const SizedBox(height: 16),
          _buildLocationItem(
            "도착지",
            routeData!.destination,
            const Color(0xFFEF4444),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationItem(String label, String location, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF6B7280),
              ),
            ),
            Text(
              location,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1F2937),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRouteDetailContent() {
    if (selectedRoute == null) return const SizedBox();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSelectedRouteInfoCard(),
          const SizedBox(height: 24),
          _buildRouteDetailSection(),
          const SizedBox(height: 24),
          _buildWarningCard(),
        ],
      ),
    );
  }

  Widget _buildSelectedRouteInfoCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: selectedRoute!.transportMode.color.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      selectedRoute!.transportMode.icon,
                      color: selectedRoute!.transportMode.color,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        selectedRoute!.routeName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                      Text(
                        selectedRoute!.transportMode.label,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: selectedRoute!.transportMode.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.access_time,
                      size: 16,
                      color: Color(0xFF2563EB),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      selectedRoute!.estimatedTime,
                      style: TextStyle(
                        color: selectedRoute!.transportMode.color,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLocationItem(
                      "출발지",
                      routeData!.departure,
                      const Color(0xFF10B981),
                    ),
                    const SizedBox(height: 16),
                    _buildLocationItem(
                      "도착지",
                      routeData!.destination,
                      const Color(0xFFEF4444),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  children: [
                    _buildInfoBox(
                      "예상 소요 시간",
                      selectedRoute!.estimatedTime,
                      selectedRoute!.transportMode.color,
                      selectedRoute!.transportMode.color.withOpacity(0.1),
                    ),
                    const SizedBox(height: 12),
                    _buildInfoBox(
                      "총 거리 / 요금",
                      "${selectedRoute!.totalDistance}\n${selectedRoute!.cost}",
                      const Color(0xFF6B7280),
                      const Color(0xFFF9FAFB),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (selectedRoute!.additionalInfo != null) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F9FF),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFBAE6FD)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline,
                    color: Color(0xFF0284C7),
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      selectedRoute!.additionalInfo!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF0284C7),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoBox(String label, String value, Color textColor, Color bgColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: textColor.withOpacity(0.8),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: textColor,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRouteDetailSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '상세 경로',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1F2937),
          ),
        ),
        const SizedBox(height: 16),
        ...selectedRoute!.routes.asMap().entries.map((entry) {
          int index = entry.key;
          RouteStep route = entry.value;
          return _buildRouteStepCard(route, index);
        }).toList(),
      ],
    );
  }

  Widget _buildRouteStepCard(RouteStep route, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Stack(
        children: [
          // 연결선
          if (index < selectedRoute!.routes.length - 1)
            Positioned(
              left: 32,
              top: 64,
              child: Container(
                width: 2,
                height: 32,
                color: const Color(0xFFD1D5DB),
              ),
            ),
          // 카드
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: selectedRoute!.transportMode.color.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          route.icon,
                          style: const TextStyle(fontSize: 20),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${index + 1}단계',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              route.step,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1F2937),
                              ),
                            ),
                          ),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: selectedRoute!.transportMode.color.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  route.method,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: selectedRoute!.transportMode.color,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                route.duration,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: selectedRoute!.transportMode.color,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        route.description,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF6B7280),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWarningCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(12),
        border: const Border(
          left: BorderSide(
            color: Color(0xFFF59E0B),
            width: 4,
          ),
        ),
      ),
      child: const Text(
        '안내: 상세 경로와 소요 시간은 실제 교통 상황에 따라 달라질 수 있습니다. 실시간 교통정보를 확인하시기 바랍니다.',
        style: TextStyle(
          fontSize: 14,
          color: Color(0xFF92400E),
        ),
      ),
    );
  }

  Widget _buildRefreshButton() {
    return Center(
      child: ElevatedButton(
        onPressed: fetchRouteData,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF2563EB),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 4,
        ),
        child: const Text(
          '경로 새로고침',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
