import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'models/route_response.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:add_2_calendar/add_2_calendar.dart' as add2cal;
import 'event_service.dart';

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
  final RouteOption option;
  const ShortestRoutePage({Key? key, required this.option}) : super(key: key);

  @override
  State<ShortestRoutePage> createState() => _ShortestRoutePageState();
}

class _ShortestRoutePageState extends State<ShortestRoutePage> {
  RouteData? routeData;

  @override
  void initState() {
    super.initState();
    _initializeRouteData();
  }

  void _initializeRouteData() {
    final main = widget.option.main;
    final totalDistMeters = widget.option.sub.fold<double>(
      0,
      (sum, leg) => sum + leg.steps.fold<double>(0, (lsum, step) => lsum + step.distance),
    );
    setState(() {
      routeData = RouteData(
        departure: main.origin,
        destination: main.destination,
        estimatedTime: '\\${(main.duration / 60).ceil()}분',
        totalDistance: '\\${(totalDistMeters / 1000).toStringAsFixed(1)}km',
        routes: widget.option.sub.asMap().entries.map((entry) {
          final idx = entry.key;
          final leg = entry.value;
          final durMs = (leg.to.arrival ?? leg.from.departure)! - (leg.from.departure ?? leg.to.arrival)!;
          final durMin = (durMs / 60000).ceil();
          final desc = leg.steps.map((s) => s.streetName).join(' → ');
          return RouteStep(
            id: idx,
            step: leg.mode,
            method: leg.transitLeg ? '대중교통' : '도보',
            duration: '\\$durMin분',
            description: desc,
            icon: leg.mode,
          );
        }).toList(),
      );
    });
  }

  void _addEventToCalendar() {
    if (routeData == null) return;
    final minutes = int.tryParse(routeData!.estimatedTime.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    final start = DateTime.now();
    final end = start.add(Duration(minutes: minutes));
    final add2cal.Event calendarEvent = add2cal.Event(
      title: '최단 경로',
      description: '출발: ${routeData!.departure}, 도착: ${routeData!.destination}',
      location: '',
      startDate: start,
      endDate: end,
    );
    add2cal.Add2Calendar.addEvent2Cal(calendarEvent);
    EventService().addEventWithDetails(
      start,
      '출발: ${routeData!.departure}, 도착: ${routeData!.destination}',
      title: '최단 경로',
      time: DateFormat('HH:mm').format(start),
    );
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
      body: routeData == null ? const SizedBox() : _buildRouteContent(),
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
          _buildCalendarButton(),
          const SizedBox(height: 16),
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
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
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
                      // step, method, duration in a single row to prevent overflow
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              route.step,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1F2937),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                                overflow: TextOverflow.ellipsis,
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

  Widget _buildCalendarButton() {
    return Center(
      child: ElevatedButton(
        onPressed: _addEventToCalendar,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF10B981),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 4,
        ),
        child: const Text(
          '캘린더에 저장',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildRefreshButton() {
    return Center(
      child: ElevatedButton(
        onPressed: _initializeRouteData,
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