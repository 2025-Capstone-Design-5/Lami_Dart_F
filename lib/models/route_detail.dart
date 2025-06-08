import 'dart:convert';

class RouteDetailResponse {
  final RouteDetail main;

  RouteDetailResponse({required this.main});

  factory RouteDetailResponse.fromJson(Map<String, dynamic> json) {
    return RouteDetailResponse(
      main: RouteDetail.fromJson(json['main'] as Map<String, dynamic>),
    );
  }

  static RouteDetailResponse parse(String source) =>
      RouteDetailResponse.fromJson(json.decode(source));
}

class RouteDetail {
  final String origin;
  final String destination;
  final List<String> stops;
  final int duration;
  final List<int> walkDurations;
  final List<int> transitDurations;
  final List<String> routeShortNames;
  final List<String> modes;
  final int transferCount;
  final List<dynamic> transfers;
  final List<int> realtimeArrivalTimes;
  final List<dynamic> routeInfos;
  final String? startVehicleTime;
  final String? routeTp;
  final int cityCode;
  final String nodeId;
  final String routeId;
  final List<TrafficItem> trafficItems;

  RouteDetail({
    required this.origin,
    required this.destination,
    required this.stops,
    required this.duration,
    required this.walkDurations,
    required this.transitDurations,
    required this.routeShortNames,
    required this.modes,
    required this.transferCount,
    required this.transfers,
    required this.realtimeArrivalTimes,
    required this.routeInfos,
    this.startVehicleTime,
    this.routeTp,
    required this.cityCode,
    required this.nodeId,
    required this.routeId,
    required this.trafficItems,
  });

  factory RouteDetail.fromJson(Map<String, dynamic> json) {
    return RouteDetail(
      origin: json['origin'] as String,
      destination: json['destination'] as String,
      stops: (json['stops'] as List).map((e) => e as String).toList(),
      duration: json['duration'] as int,
      walkDurations:
          (json['walkDurations'] as List).map((e) => e as int).toList(),
      transitDurations:
          (json['transitDurations'] as List).map((e) => e as int).toList(),
      routeShortNames:
          (json['routeShortNames'] as List).map((e) => e as String).toList(),
      modes: (json['modes'] as List).map((e) => e as String).toList(),
      transferCount: json['transferCount'] as int,
      transfers: json['transfers'] as List<dynamic>,
      realtimeArrivalTimes: (json['realtimeArrivalTimes'] as List)
          .map((e) => e as int)
          .toList(),
      routeInfos: json['routeInfos'] as List<dynamic>,
      startVehicleTime: json['startvehicletime'] != null
          ? json['startvehicletime'].toString()
          : null,
      routeTp:
          json['routetp'] != null ? json['routetp'].toString() : null,
      cityCode: (json['cityCode'] as num).toInt(),
      nodeId: json['nodeId'] as String,
      routeId: json['routeId'] as String,
      trafficItems: (json['trafficItems'] as List)
          .map((e) => TrafficItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'origin': origin,
      'destination': destination,
      'stops': stops,
      'duration': duration,
      'walkDurations': walkDurations,
      'transitDurations': transitDurations,
      'routeShortNames': routeShortNames,
      'modes': modes,
      'transferCount': transferCount,
      'transfers': transfers,
      'realtimeArrivalTimes': realtimeArrivalTimes,
      'routeInfos': routeInfos,
      'startvehicletime': startVehicleTime,
      'routetp': routeTp,
      'cityCode': cityCode,
      'nodeId': nodeId,
      'routeId': routeId,
      'trafficItems': trafficItems.map((e) => e.toJson()).toList(),
    };
  }
}

class TrafficItem {
  final String roadName;
  final String roadDrcType;
  final String linkNo;
  final String linkId;
  final String startNodeId;
  final String endNodeId;
  final String speed;
  final String travelTime;
  final String createdDate;

  TrafficItem({
    required this.roadName,
    required this.roadDrcType,
    required this.linkNo,
    required this.linkId,
    required this.startNodeId,
    required this.endNodeId,
    required this.speed,
    required this.travelTime,
    required this.createdDate,
  });

  factory TrafficItem.fromJson(Map<String, dynamic> json) {
    return TrafficItem(
      roadName: json['roadName'] as String,
      roadDrcType: json['roadDrcType'] as String,
      linkNo: json['linkNo'] as String,
      linkId: json['linkId'] as String,
      startNodeId: json['startNodeId'] as String,
      endNodeId: json['endNodeId'] as String,
      speed: json['speed'] as String,
      travelTime: json['travelTime'] as String,
      createdDate: json['createdDate'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'roadName': roadName,
      'roadDrcType': roadDrcType,
      'linkNo': linkNo,
      'linkId': linkId,
      'startNodeId': startNodeId,
      'endNodeId': endNodeId,
      'speed': speed,
      'travelTime': travelTime,
      'createdDate': createdDate,
    };
  }
} 