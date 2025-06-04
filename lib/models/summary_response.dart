import 'dart:convert';

class SummaryResponse {
  final int status;
  final String message;
  final SummaryData data;

  SummaryResponse({required this.status, required this.message, required this.data});

  factory SummaryResponse.fromJson(Map<String, dynamic> json) {
    return SummaryResponse(
      status: json['status'] as int,
      message: json['message'] as String,
      data: SummaryData.fromJson(json['data'] as Map<String, dynamic>),
    );
  }

  static SummaryResponse parse(String source) =>
      SummaryResponse.fromJson(json.decode(source));
}

class SummaryData {
  final String origin;
  final String destination;
  final String summaryKey;
  final List<RouteSummary> routes;

  SummaryData({
    required this.origin,
    required this.destination,
    required this.summaryKey,
    required this.routes,
  });

  factory SummaryData.fromJson(Map<String, dynamic> json) {
    return SummaryData(
      origin: json['origin'] as String,
      destination: json['destination'] as String,
      summaryKey: json['summaryKey'] as String,
      routes: (json['routes'] as List)
          .map((e) => RouteSummary.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  @override
  String toString() {
    return 'SummaryData{origin: $origin, destination: $destination, summaryKey: $summaryKey, routes: ${routes.length} items}';
  }
}

class RouteSummary {
  final String category;
  final int duration;
  final List<int> walkDurations;
  final List<int> transitDurations;
  final List<String> modes;
  final List<String> routeShortNames;
  final int transferCount;
  final List<dynamic> transfers;
  final List<int> realtimeArrivalTimes;
  final List<dynamic> trafficItems;
  final List<dynamic> forecast;
  final List<String> stops;
  final String? startvehicletime;
  final String? routetp;
  final String? cityCode;
  final String? departureStopId;
  final String? busId;

  RouteSummary({
    required this.category,
    required this.duration,
    required this.walkDurations,
    required this.transitDurations,
    required this.modes,
    required this.routeShortNames,
    required this.transferCount,
    required this.transfers,
    required this.realtimeArrivalTimes,
    required this.trafficItems,
    required this.forecast,
    required this.stops,
    this.startvehicletime,
    this.routetp,
    this.cityCode,
    this.departureStopId,
    this.busId,
  });

  factory RouteSummary.fromJson(Map<String, dynamic> json) {
    return RouteSummary(
      category: json['category'] as String,
      duration: json['duration'] as int,
      walkDurations:
          (json['walkDurations'] as List).map((e) => e as int).toList(),
      transitDurations:
          (json['transitDurations'] as List).map((e) => e as int).toList(),
      modes: (json['modes'] as List).map((e) => e as String).toList(),
      routeShortNames:
          (json['routeShortNames'] as List).map((e) => e as String).toList(),
      transferCount: json['transferCount'] as int,
      transfers: json['transfers'] as List<dynamic>,
      realtimeArrivalTimes:
          (json['realtimeArrivalTimes'] as List).map((e) => e as int).toList(),
      trafficItems: json['trafficItems'] as List<dynamic>,
      forecast: json['forecast'] as List<dynamic>,
      stops: (json['stops'] as List).map((e) => e as String).toList(),
      startvehicletime: json['startvehicletime'] != null ? json['startvehicletime'].toString() : null,
      routetp: json['routetp'] != null ? json['routetp'].toString() : null,
      cityCode: json['cityCode'] != null ? json['cityCode'].toString() : null,
      departureStopId: json['departureStopId'] != null ? json['departureStopId'].toString() : null,
      busId: json['busId'] != null ? json['busId'].toString() : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'category': category,
      'duration': duration,
      'walkDurations': walkDurations,
      'transitDurations': transitDurations,
      'modes': modes,
      'routeShortNames': routeShortNames,
      'transferCount': transferCount,
      'transfers': transfers,
      'realtimeArrivalTimes': realtimeArrivalTimes,
      'trafficItems': trafficItems,
      'forecast': forecast,
      'stops': stops,
      'startvehicletime': startvehicletime,
      'routetp': routetp,
      'cityCode': cityCode,
      'departureStopId': departureStopId,
      'busId': busId,
    };
  }
} 