import 'package:flutter/material.dart';
import '../../models/summary_response.dart';
import '../../models/route_detail_response.dart';
import 'route_detail_page.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/intl.dart';
import '../../event_service.dart';
import 'dart:convert';
import '../../route_store.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../widgets/route_summary_widget.dart';

/// RouteResultsPage: SummaryData를 받아 여러 경로 옵션을 탭별로 보여주는 페이지
class RouteResultsPage extends StatelessWidget {
  final SummaryData summaryData;

  const RouteResultsPage({Key? key, required this.summaryData})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Delegate summary UI to reusable widget
    return RouteSummaryWidget(summaryData: summaryData);
  }
}

/// 구간 정보를 저장하는 클래스
class _Segment {
  final String mode; // 'WALK' 또는 'BUS'
  final int seconds;

  _Segment({required this.mode, required this.seconds});
}