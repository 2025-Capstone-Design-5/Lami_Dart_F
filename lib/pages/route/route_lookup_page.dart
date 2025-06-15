import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import '../../config/server_config.dart';
import '../../models/summary_response.dart';
import 'route_results_page.dart';

class RouteLookupPage extends StatelessWidget {
  final String from;
  final String to;
  final String date;
  final String time;

  const RouteLookupPage({
    Key? key,
    required this.from,
    required this.to,
    required this.date,
    required this.time,
  }) : super(key: key);

  Future<SummaryData> _fetchSummary() async {
    final baseUrl = getServerBaseUrl();
    final uri = Uri.parse('$baseUrl/traffic/routes');
    final payload = {
      'fromAddress': from,
      'toAddress': to,
      'date': date,
      'time': time,
    };
    final resp = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      final summaryResp = SummaryResponse.parse(resp.body);
      
      // Debug logging for route categories
      final data = summaryResp.data;
      print('===== ROUTE DATA DEBUG =====');
      print('Total routes received: ${data.routes.length}');
      
      // Count by category
      final Map<String, int> categoryCounts = {};
      for (var route in data.routes) {
        categoryCounts[route.category] = (categoryCounts[route.category] ?? 0) + 1;
      }
      
      print('Routes by category:');
      categoryCounts.forEach((category, count) {
        print('- $category: $count routes');
      });
      
      // Print the raw response for inspection
      print('Raw response body:');
      print(resp.body.substring(0, 200) + '...'); // Just show the beginning to avoid too much output
      print('==========================');
      
      return summaryResp.data;
    } else {
      throw Exception('경로 조회 실패: ${resp.statusCode}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<SummaryData>(
      future: _fetchSummary(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            appBar: AppBar(title: const Text('경로 결과')),
            body: const Center(child: CircularProgressIndicator()),
          );
        } else if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('경로 결과')),
            body: Center(child: Text('오류: ${snapshot.error}')),
          );
        } else if (!snapshot.hasData) {
          return Scaffold(
            appBar: AppBar(title: const Text('경로 결과')),
            body: const Center(child: Text('경로 데이터가 없습니다.')),
          );
        } else {
          return RouteResultsPage(summaryData: snapshot.data!);
        }
      },
    );
  }
} 