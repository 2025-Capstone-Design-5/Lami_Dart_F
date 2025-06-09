import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../config/server_config.dart'; // if server_config needed here, otherwise remove

class TmapPlace {
  final String name;
  final String address;
  final String? category;
  final double? lat;
  final double? lon;

  TmapPlace({
    required this.name,
    required this.address,
    this.category,
    this.lat,
    this.lon,
  });

  Map<String, String> toMap() {
    return {
      'name': name,
      'address': address,
      'category': category ?? '',
    };
  }

  factory TmapPlace.fromJson(Map<String, dynamic> json, {bool isPoi = true}) {
    if (isPoi) {
      String address = '';
      if (json['fullAddress'] != null && json['fullAddress'].toString().trim().isNotEmpty) {
        address = json['fullAddress'];
      } else if (json['address'] != null && json['address'].toString().trim().isNotEmpty) {
        address = json['address'];
      } else {
        List<String> addressParts = [];
        if (json['upperAddrName'] != null && json['upperAddrName'].toString().trim().isNotEmpty) {
          addressParts.add(json['upperAddrName']);
        }
        if (json['middleAddrName'] != null && json['middleAddrName'].toString().trim().isNotEmpty) {
          addressParts.add(json['middleAddrName']);
        }
        if (json['lowerAddrName'] != null && json['lowerAddrName'].toString().trim().isNotEmpty) {
          addressParts.add(json['lowerAddrName']);
        }
        if (json['detailAddrName'] != null && json['detailAddrName'].toString().trim().isNotEmpty) {
          addressParts.add(json['detailAddrName']);
        }
        if (json['buildingName'] != null && json['buildingName'].toString().trim().isNotEmpty) {
          addressParts.add(json['buildingName']);
        }
        if (json['roadName'] != null && json['roadName'].toString().trim().isNotEmpty) {
          addressParts.add(json['roadName']);
        }
        if (json['firstNo'] != null && json['firstNo'].toString().trim().isNotEmpty) {
          String jibun = json['firstNo'];
          if (json['secondNo'] != null && json['secondNo'].toString().trim().isNotEmpty) {
            jibun += '-' + json['secondNo'];
          }
          addressParts.add(jibun);
        }
        address = addressParts.join(' ');
      }
      return TmapPlace(
        name: json['name'] ?? '',
        address: address.trim(),
        category: json['category'] ?? '',
        lat: double.tryParse(json['lat']?.toString() ?? ''),
        lon: double.tryParse(json['lon']?.toString() ?? ''),
      );
    } else {
      return TmapPlace(
        name: json['fullAddress'] ?? json['city_do'] ?? '',
        address: json['fullAddress'] ?? '',
        lat: double.tryParse(json['lat']?.toString() ?? ''),
        lon: double.tryParse(json['lon']?.toString() ?? ''),
      );
    }
  }
}

class TmapService {
  static String? _apiKey;
  static const String _baseUrl = 'https://apis.openapi.sk.com';

  static void initialize() {
    _apiKey = dotenv.env['TMAP_API_KEY'];
    if (_apiKey == null || _apiKey!.isEmpty) {
      print('Warning: TMAP API key not found in .env file');
    }
  }

  static Future<List<TmapPlace>> searchPlaces(String query) async {
    if (_apiKey == null) {
      print('TMAP API key not initialized');
      return [];
    }
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/tmap/pois?version=1&format=json&callback=result&searchKeyword=${Uri.encodeComponent(query)}&resCoordType=WGS84GEO&reqCoordType=WGS84GEO&count=10'),
        headers: {
          'Accept': 'application/json',
          'appKey': _apiKey!,
        },
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final searchPoiInfo = data['searchPoiInfo'];
        if (searchPoiInfo != null && searchPoiInfo['pois'] != null) {
          final pois = searchPoiInfo['pois']['poi'] as List;
          return pois.map((poi) => TmapPlace.fromJson(poi, isPoi: true)).toList();
        }
      }
    } catch (e) {
      print('POI search error: $e');
    }
    return [];
  }

  static Future<List<TmapPlace>> searchAddress(String query) async {
    if (_apiKey == null) {
      print('TMAP API key not initialized');
      return [];
    }
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/tmap/geo/fullAddrGeo?version=1&format=json&callback=result&coordType=WGS84GEO&fullAddr=${Uri.encodeComponent(query)}'),
        headers: {
          'Accept': 'application/json',
          'appKey': _apiKey!,
        },
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final coordinateInfo = data['coordinateInfo'];
        if (coordinateInfo != null && coordinateInfo['coordinate'] != null) {
          final coordinates = coordinateInfo['coordinate'] as List;
          return coordinates.map((coord) => TmapPlace.fromJson(coord, isPoi: false)).toList();
        }
      }
    } catch (e) {
      print('Address search error: $e');
    }
    return [];
  }
} 