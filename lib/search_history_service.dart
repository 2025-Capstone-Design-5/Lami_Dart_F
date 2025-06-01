import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SearchHistoryService extends ChangeNotifier {
  // 싱글톤 패턴 구현
  static final SearchHistoryService _instance = SearchHistoryService._internal();
  factory SearchHistoryService() => _instance;
  SearchHistoryService._internal();

  // 목적지 검색 기록 저장 맵 (교통수단 정보 제거)
  Map<String, Map<String, dynamic>> _searchHistory = {};
  
  // 출발지-도착지 쌍 저장
  final List<Map<String, dynamic>> _routeHistory = [];
  
  bool _isLoaded = false;

  // 검색 기록 추가 - 교통수단 정보 제거
  void addSearchHistory(String placeName, String address) {
    print('검색 기록 추가: $placeName');
    
    if (_searchHistory.containsKey(placeName)) {
      _searchHistory[placeName]!['count'] = (_searchHistory[placeName]!['count'] as int) + 1;
      print('기존 검색 기록 업데이트: $placeName, 횟수: ${_searchHistory[placeName]!['count']}');
    } else {
      _searchHistory[placeName] = {
        'name': placeName,
        'address': address,
        'count': 1,
      };
      print('새 검색 기록 추가: $placeName');
    }
    
    _saveSearchHistory();
    notifyListeners();
  }

  // 검색 기록 삭제
  void removeSearchHistory(String placeName) {
    if (_searchHistory.containsKey(placeName)) {
      _searchHistory.remove(placeName);
    }
    
    _saveSearchHistory();
    notifyListeners();
  }

  // 모든 검색 기록 삭제
  void clearAllSearchHistory() {
    _searchHistory.clear();
    _saveSearchHistory();
    notifyListeners();
  }

  // 모든 검색 기록 가져오기
  List<Map<String, dynamic>> getAllSearchHistory() {
    return _searchHistory.values.toList();
  }

  // 가장 많이 검색한 장소 가져오기
  List<Map<String, dynamic>> getMostSearchedPlaces({int limit = 5}) {
    List<Map<String, dynamic>> places = _searchHistory.values.toList();
    
    // 검색 횟수에 따라 정렬
    places.sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));
    
    // 상위 n개 반환
    return places.take(limit).toList();
  }

  // 검색 기록 저장
  Future<void> _saveSearchHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String historyJson = jsonEncode(_searchHistory);
      await prefs.setString('search_history', historyJson);
      print('검색 기록 저장 성공');
    } catch (e) {
      print('검색 기록 저장 오류: $e');
    }
  }

  // 검색 기록 로드
  Future<void> _loadSearchHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? historyJson = prefs.getString('search_history');
      
      if (historyJson != null) {
        final Map<String, dynamic> decodedMap = jsonDecode(historyJson);
        _searchHistory = Map.from(decodedMap.map((key, value) => 
          MapEntry(key, Map<String, dynamic>.from(value))));
        print('검색 기록 로드 성공: ${_searchHistory.length}개 항목');
      }
    } catch (e) {
      print('검색 기록 로드 오류: $e');
    }
  }

  // 출발지-도착지 쌍 추가
  Future<void> addRouteHistory({
    required String departureName,
    required String departureAddress,
    required String destinationName,
    required String destinationAddress,
  }) async {
    // 동일한 경로가 있는지 확인
    final existingIndex = _routeHistory.indexWhere((route) => 
      route['departureName'] == departureName && 
      route['destinationName'] == destinationName
    );
    
    if (existingIndex != -1) {
      // 기존 경로가 있으면 카운트 증가
      _routeHistory[existingIndex]['count'] = (_routeHistory[existingIndex]['count'] ?? 0) + 1;
      _routeHistory[existingIndex]['lastUsed'] = DateTime.now().millisecondsSinceEpoch;
    } else {
      // 새로운 경로 추가
      _routeHistory.add({
        'departureName': departureName,
        'departureAddress': departureAddress,
        'destinationName': destinationName,
        'destinationAddress': destinationAddress,
        'count': 1,
        'lastUsed': DateTime.now().millisecondsSinceEpoch,
      });
    }
    
    await _saveRouteHistory();
    notifyListeners();
  }
  
  // 경로 기록 가져오기
  List<Map<String, dynamic>> getRouteHistory({int limit = 10}) {
    final routes = List<Map<String, dynamic>>.from(_routeHistory);
    
    // 사용 횟수와 최근 사용 시간을 기준으로 정렬
    routes.sort((a, b) {
      final countCompare = (b['count'] as int).compareTo(a['count'] as int);
      if (countCompare != 0) return countCompare;
      return (b['lastUsed'] as int).compareTo(a['lastUsed'] as int);
    });
    
    return routes.take(limit).toList();
  }
  
  // 특정 경로 삭제
  Future<void> removeRouteHistory(String departureName, String destinationName) async {
    _routeHistory.removeWhere((route) => 
      route['departureName'] == departureName && 
      route['destinationName'] == destinationName
    );
    await _saveRouteHistory();
    notifyListeners();
  }
  
  // 모든 경로 기록 삭제
  Future<void> clearAllRouteHistory() async {
    _routeHistory.clear();
    await _saveRouteHistory();
    notifyListeners();
  }
  
  // 경로 기록 저장
  Future<void> _saveRouteHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String routeHistoryJson = jsonEncode(_routeHistory);
      await prefs.setString('route_history', routeHistoryJson);
      print('경로 기록 저장 성공');
    } catch (e) {
      print('경로 기록 저장 오류: $e');
    }
  }
  
  // 경로 기록 로드
  Future<void> _loadRouteHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? routeHistoryJson = prefs.getString('route_history');
      
      if (routeHistoryJson != null) {
        final List<dynamic> routeList = jsonDecode(routeHistoryJson);
        _routeHistory.clear();
        _routeHistory.addAll(routeList.cast<Map<String, dynamic>>());
        print('경로 기록 로드 성공: ${_routeHistory.length}개 항목');
      }
    } catch (e) {
      print('경로 기록 로드 오류: $e');
    }
  }
  
  // 통합된 데이터 로드 메서드
  Future<void> loadData() async {
    if (_isLoaded) return;
    
    await _loadSearchHistory();
    await _loadRouteHistory();
    _isLoaded = true;
    notifyListeners();
  }
}