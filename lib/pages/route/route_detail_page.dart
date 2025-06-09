import 'package:flutter/material.dart';
import '../../models/route_response.dart';
import 'package:intl/intl.dart';

class RouteDetailPage extends StatelessWidget {
  final RouteOption option;
  const RouteDetailPage({Key? key, required this.option}) : super(key: key);

  @override
  Widget build(BuildContext context) {
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
            children: leg.steps.map((step) => ListTile(
                  leading: const Icon(Icons.circle, size: 8),
                  title: Text(step.streetName),
                  trailing: Text('${step.distance.toStringAsFixed(0)}m'),
                )).toList(),
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