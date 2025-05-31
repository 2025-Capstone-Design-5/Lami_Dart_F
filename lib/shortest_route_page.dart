import 'package:flutter/material.dart';

class RouteData {
  final String departure;
  final String destination;
  final String estimatedTime;
  final String totalDistance;
  final List<RouteStep> routes;

  RouteData({
    required this.departure,
    required this.destination,
    required this.estimatedTime,
    required this.totalDistance,
    required this.routes,
  });
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
}

class ShortestRoutePage extends StatefulWidget {
  const ShortestRoutePage({Key? key}) : super(key: key);

  @override
  State<ShortestRoutePage> createState() => _ShortestRoutePageState();
}

class _ShortestRoutePageState extends State<ShortestRoutePage> {
  RouteData? routeData;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchRouteData();
  }

  // 백엔드에서 데이터를 받아오는 함수 (모의 데이터 사용)
  Future<void> fetchRouteData() async {
    setState(() {
      isLoading = true;
    });

    // 실제로는 백엔드 API 호출
    // final response = await http.get(Uri.parse('/api/shortest-route'));
    // final data = jsonDecode(response.body);

    // 모의 데이터로 1초 지연
    await Future.delayed(const Duration(seconds: 1));

    final mockData = RouteData(
      departure: "서울역",
      destination: "강남역",
      estimatedTime: "50분",
      totalDistance: "23.5km",
      routes: [
        RouteStep(
          id: 1,
          step: "서울역 출발",
          method: "도보",
          duration: "3분",
          description: "서울역 1번 출구로 나와서 지하철 4호선 승강장으로 이동",
          icon: "🚶‍♂️",
        ),
        RouteStep(
          id: 2,
          step: "지하철 4호선 탑승",
          method: "지하철",
          duration: "15분",
          description: "4호선 당고개 방면 → 동대문역사문화공원역까지 (8정거장)",
          icon: "🚇",
        ),
        RouteStep(
          id: 3,
          step: "동대문역사문화공원역 환승",
          method: "환승",
          duration: "5분",
          description: "2호선으로 환승 (환승통로 이용)",
          icon: "🔄",
        ),
        RouteStep(
          id: 4,
          step: "지하철 2호선 탑승",
          method: "지하철",
          duration: "20분",
          description: "2호선 잠실 방면 → 강남역까지 (11정거장)",
          icon: "🚇",
        ),
        RouteStep(
          id: 5,
          step: "강남역 도착",
          method: "도보",
          duration: "2분",
          description: "강남역 12번 출구로 나와서 목적지 도착",
          icon: "🏁",
        ),
      ],
    );

    setState(() {
      routeData = mockData;
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.navigation, color: Color(0xFF2563EB)),
            SizedBox(width: 8),
            Text('최단 경로'),
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
      ),
      body: isLoading ? _buildLoadingWidget() : _buildRouteContent(),
    );
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

  Widget _buildRouteContent() {
    if (routeData == null) return const SizedBox();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildRouteInfoCard(),
          const SizedBox(height: 24),
          _buildRouteDetailSection(),
          const SizedBox(height: 24),
          _buildWarningCard(),
          const SizedBox(height: 24),
          _buildRefreshButton(),
        ],
      ),
    );
  }

  Widget _buildRouteInfoCard() {
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
              const Text(
                '경로 정보',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1F2937),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withOpacity(0.1),
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
                      routeData!.estimatedTime,
                      style: const TextStyle(
                        color: Color(0xFF2563EB),
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
                      routeData!.estimatedTime,
                      const Color(0xFF2563EB),
                      const Color(0xFFEFF6FF),
                    ),
                    const SizedBox(height: 12),
                    _buildInfoBox(
                      "총 거리",
                      routeData!.totalDistance,
                      const Color(0xFF6B7280),
                      const Color(0xFFF9FAFB),
                    ),
                  ],
                ),
              ),
            ],
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
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: textColor,
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
        ...routeData!.routes.asMap().entries.map((entry) {
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
          if (index < routeData!.routes.length - 1)
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
                        color: const Color(0xFF2563EB).withOpacity(0.1),
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
                                  color: const Color(0xFF2563EB).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  route.method,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF2563EB),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                route.duration,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF2563EB),
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