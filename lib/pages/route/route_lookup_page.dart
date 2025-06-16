import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import '../../config/server_config.dart';
import '../../models/summary_response.dart';
import 'route_results_page.dart';
import 'package:shimmer/shimmer.dart';

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
          // Glass-morphism themed shimmer skeleton while loading
          return Scaffold(
            extendBodyBehindAppBar: true,
            backgroundColor: const Color(0xFF0A0E27),
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              title: const Text(
                '경로 결과',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
              ),
              iconTheme: const IconThemeData(color: Colors.white),
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
                // Skeleton cards
                SafeArea(
                  child: ListView.builder(
                    itemCount: 5,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                            child: Shimmer.fromColors(
                              baseColor: Colors.white.withOpacity(0.1),
                              highlightColor: Colors.white.withOpacity(0.25),
                              child: Container(
                                height: 200,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: Colors.white.withOpacity(0.2), width: 1.5),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
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