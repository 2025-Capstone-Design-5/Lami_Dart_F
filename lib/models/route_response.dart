import 'dart:convert';

class RouteResponse {
  final List<RouteOption> walk;
  final List<RouteOption> car;
  final List<RouteOption> bus;
  final List<RouteOption> subway;
  final List<RouteOption> busSubway;

  RouteResponse({
    required this.walk,
    required this.car,
    required this.bus,
    required this.subway,
    required this.busSubway,
  });

  factory RouteResponse.fromJson(Map<String, dynamic> j) => RouteResponse(
        walk: (j['walk'] as List).map((e) => RouteOption.fromJson(e)).toList(),
        car: (j['car'] as List).map((e) => RouteOption.fromJson(e)).toList(),
        bus: (j['bus'] as List).map((e) => RouteOption.fromJson(e)).toList(),
        subway:
            (j['subway'] as List).map((e) => RouteOption.fromJson(e)).toList(),
        busSubway: (j['bus_subway'] as List)
            .map((e) => RouteOption.fromJson(e)).toList(),
      );

  static RouteResponse parse(String source) =>
      RouteResponse.fromJson(json.decode(source));
}

class RouteOption {
  final MainInfo main;
  final List<Leg> sub;

  RouteOption({required this.main, required this.sub});

  factory RouteOption.fromJson(Map<String, dynamic> j) => RouteOption(
        main: MainInfo.fromJson(j['main']),
        sub: (j['sub'] as List).map((e) => Leg.fromJson(e)).toList(),
      );

  Map<String, dynamic> toJson() {
    return {
      'main': main.toJson(),
      'sub': sub.map((e) => e.toJson()).toList(),
    };
  }
}

class MainInfo {
  final String origin;
  final String destination;
  final int duration;
  final List<String> stops;
  final List<int> walkDurations;
  final List<int> transitDurations;
  final List<String> routeShortNames;
  final List<String> modes;
  final int transferCount;
  final List<Map<String, dynamic>>? routeInfos;

  MainInfo({
    required this.origin,
    required this.destination,
    required this.duration,
    required this.stops,
    required this.walkDurations,
    required this.transitDurations,
    required this.routeShortNames,
    required this.modes,
    required this.transferCount,
    this.routeInfos,
  });

  factory MainInfo.fromJson(Map<String, dynamic> j) => MainInfo(
        origin: j['origin'] as String,
        destination: j['destination'] as String,
        duration: j['duration'] as int,
        stops: (j['stops'] as List).map((e) => e as String).toList(),
        walkDurations:
            (j['walkDurations'] as List).map((e) => e as int).toList(),
        transitDurations:
            (j['transitDurations'] as List).map((e) => e as int).toList(),
        routeShortNames:
            (j['routeShortNames'] as List).map((e) => e as String).toList(),
        modes: (j['modes'] as List).map((e) => e as String).toList(),
        transferCount: j['transferCount'] as int,
        routeInfos: j['routeInfos'] != null 
            ? (j['routeInfos'] as List).map((e) => e as Map<String, dynamic>).toList()
            : null,
      );

  Map<String, dynamic> toJson() {
    return {
      'origin': origin,
      'destination': destination,
      'duration': duration,
      'stops': stops,
      'walkDurations': walkDurations,
      'transitDurations': transitDurations,
      'routeShortNames': routeShortNames,
      'modes': modes,
      'transferCount': transferCount,
      'routeInfos': routeInfos,
    };
  }
}

class Leg {
  final String mode;
  final bool transitLeg;
  final Place from;
  final Place to;
  final List<Step> steps;
  final List<Place> intermediateStops;

  Leg({
    required this.mode,
    required this.transitLeg,
    required this.from,
    required this.to,
    required this.steps,
    required this.intermediateStops,
  });

  factory Leg.fromJson(Map<String, dynamic> j) => Leg(
        mode: j['mode'] as String,
        transitLeg: j['transitLeg'] as bool,
        from: Place.fromJson(j['from']),
        to: Place.fromJson(j['to']),
        steps:
            (j['steps'] as List).map((e) => Step.fromJson(e)).toList(),
        intermediateStops: (j['intermediateStops'] as List)
            .map((e) => Place.fromJson(e)).toList(),
      );

  Map<String, dynamic> toJson() {
    return {
      'mode': mode,
      'transitLeg': transitLeg,
      'from': from.toJson(),
      'to': to.toJson(),
      'steps': steps.map((e) => e.toJson()).toList(),
      'intermediateStops': intermediateStops.map((e) => e.toJson()).toList(),
    };
  }
}

class Step {
  final double distance;
  final String relativeDirection;
  final String streetName;
  final String absoluteDirection;
  final double lon;
  final double lat;

  Step({
    required this.distance,
    required this.relativeDirection,
    required this.streetName,
    required this.absoluteDirection,
    required this.lon,
    required this.lat,
  });

  factory Step.fromJson(Map<String, dynamic> j) => Step(
        distance: (j['distance'] as num).toDouble(),
        relativeDirection: j['relativeDirection'] as String,
        streetName: j['streetName'] as String,
        absoluteDirection: j['absoluteDirection'] as String,
        lon: (j['lon'] as num).toDouble(),
        lat: (j['lat'] as num).toDouble(),
      );

  Map<String, dynamic> toJson() {
    return {
      'distance': distance,
      'relativeDirection': relativeDirection,
      'streetName': streetName,
      'absoluteDirection': absoluteDirection,
      'lon': lon,
      'lat': lat,
    };
  }
}

class Place {
  final String name;
  final double lon;
  final double lat;
  final int? departure;
  final int? arrival;
  final String vertexType;
  final String? stopId;

  Place({
    required this.name,
    required this.lon,
    required this.lat,
    this.departure,
    this.arrival,
    required this.vertexType,
    this.stopId,
  });

  factory Place.fromJson(Map<String, dynamic> j) => Place(
        name: j['name'] as String,
        lon: (j['lon'] as num).toDouble(),
        lat: (j['lat'] as num).toDouble(),
        departure:
            j.containsKey('departure') ? j['departure'] as int : null,
        arrival: j.containsKey('arrival') ? j['arrival'] as int : null,
        vertexType: j['vertexType'] as String,
        stopId: j.containsKey('stopId') ? j['stopId'] as String : null,
      );

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'name': name,
      'lon': lon,
      'lat': lat,
      'vertexType': vertexType,
    };
    if (departure != null) map['departure'] = departure;
    if (arrival != null) map['arrival'] = arrival;
    if (stopId != null) map['stopId'] = stopId;
    return map;
  }
} 