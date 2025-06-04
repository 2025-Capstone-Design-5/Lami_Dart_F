import 'dart:convert';
import 'route_response.dart';

class RouteDetailResponse {
  final int status;
  final String message;
  final RouteOption data;

  RouteDetailResponse({required this.status, required this.message, required this.data});

  factory RouteDetailResponse.fromJson(Map<String, dynamic> json) {
    return RouteDetailResponse(
      status: json['status'] as int,
      message: json['message'] as String,
      data: RouteOption.fromJson(json['data'] as Map<String, dynamic>),
    );
  }

  static RouteDetailResponse parse(String source) =>
      RouteDetailResponse.fromJson(json.decode(source));
} 