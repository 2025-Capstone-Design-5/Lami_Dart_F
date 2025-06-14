import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'pages/route/route_detail_page.dart';
import 'models/route_response.dart';
import 'config/server_config.dart'; // baseUrl import 필요

class RouteStore {
  // Holds the last selected route option
  static RouteOption? selectedOption;
  // Holds the last saved route ID for fetching details on the home page
  static String? selectedRouteId;

  /// Fetch detailed route by routeId and navigate to detail page
  static Future<void> fetchRouteDetailAndShow(BuildContext context, String routeId) async {
    final url = Uri.parse('${getServerBaseUrl()}/traffic/routes/$routeId/details');
    try {
      final resp = await http.get(url, headers: {'Content-Type': 'application/json'});
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        final jsonBody = jsonDecode(resp.body) as Map<String, dynamic>;
        final data = jsonBody['data'] as Map<String, dynamic>;
        final option = RouteOption.fromJson(data);
        selectedOption = option;
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => RouteDetailPage(option: option),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('상세 경로 조회 실패: ${resp.statusCode}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('상세 경로 조회 오류: $e')),
      );
    }
  }
} 