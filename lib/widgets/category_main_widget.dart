import 'package:flutter/material.dart';

/// Displays only the 'main' fields for each category in the agent JSON response
class CategoryMainWidget extends StatelessWidget {
  final Map<String, dynamic> data;
  // Callback when user taps detail button: category and index
  final void Function(String category, int index)? onDetailTap;

  const CategoryMainWidget({Key? key, required this.data, this.onDetailTap}) : super(key: key);

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
        final list = data[key];
        if (list == null || list is! List || list.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              ...list.map((route) {
                final main = route['main'] as Map<String, dynamic>?;
                if (main == null) return const SizedBox.shrink();
                // summary data main fields
                final origin = main['origin'] as String? ?? '';
                final destination = main['destination'] as String? ?? '';
                final durationSec = main['duration'] as num? ?? 0;
                final durationMin = (durationSec / 60).ceil();
                // Join stops if available
                final stopsList = (main['stops'] as List<dynamic>?)?.cast<String>() ?? [];
                final stops = stopsList.isNotEmpty ? stopsList.join(' → ') : '';
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  elevation: 2,
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    title: Text('$durationMin분', style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      '$origin → $destination${stops.isNotEmpty ? '\n정류장: $stops' : ''}',
                      style: const TextStyle(fontSize: 13),
                    ),
                    // Detail button
                    trailing: onDetailTap != null
                      ? IconButton(
                          icon: const Icon(Icons.info_outline),
                          onPressed: () {
                            final idx = (list as List).indexOf(route);
                            onDetailTap!(key, idx);
                          },
                        )
                      : null,
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