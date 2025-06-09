import 'package:flutter/material.dart';
import '../models/route_detail.dart';

class RouteDetailWidget extends StatelessWidget {
  final RouteDetail detail;

  const RouteDetailWidget({Key? key, required this.detail}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final totalMin = (detail.duration / 60).ceil();
    final walkSeconds = detail.walkDurations.fold<int>(0, (sum, w) => sum + w);
    final walkMin = (walkSeconds / 60).ceil();
    final stops = detail.stops.join(' → ');
    final routes = detail.routeShortNames.join(', ');

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 시간 정보
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
              ],
            ),
            const SizedBox(height: 8),
            if (stops.isNotEmpty) ...[
              Text('정류장: $stops', style: const TextStyle(fontSize: 13)),
              const SizedBox(height: 4),
            ],
            if (routes.isNotEmpty) ...[
              Text('노선번호: $routes', style: const TextStyle(fontSize: 13)),
              const SizedBox(height: 8),
            ],
            // 추가 정보 예: 출발 시간
            if (detail.startVehicleTime != null) ...[
              Text('출발 시간: ${detail.startVehicleTime}', style: const TextStyle(fontSize: 13)),
              const SizedBox(height: 8),
            ],
            // Traffic items count
            if (detail.trafficItems.isNotEmpty) ...[
              Text('교통 정보 ${detail.trafficItems.length}건', style: const TextStyle(fontSize: 13)),
            ],
          ],
        ),
      ),
    );
  }
} 