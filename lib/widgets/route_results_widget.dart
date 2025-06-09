import 'package:flutter/material.dart';
import '../models/summary_response.dart';

/// Reusable widget to display route results from SummaryData
class RouteResultsWidget extends StatelessWidget {
  final SummaryData summaryData;

  const RouteResultsWidget({Key? key, required this.summaryData}) : super(key: key);

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
      child: Column(
        children: [
          TabBar(
            isScrollable: true,
            tabs: tabs.map((t) => Tab(text: t)).toList(),
          ),
          SizedBox(
            height: 300,
            child: TabBarView(
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
                      // reuse UI logic from RouteResultsPage
                      // For brevity, show minimal: duration and stops
                      return ListTile(
                        title: Text('${(option.duration/60).ceil()}분'),
                        subtitle: Text(option.stops.join(' → ')),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
} 