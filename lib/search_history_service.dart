import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';

class SearchHistoryService extends ChangeNotifier {
  // 싱글톤 패턴 구현
  static final SearchHistoryService _instance = SearchHistoryService._internal();
  factory SearchHistoryService() => _instance;
  SearchHistoryService._internal();

  // 교통수단별 검색 기록 저장 맵 (0: 지하철, 1: 버스, 2: 승용차)
  Map<int, Map<String, Map<String, dynamic>>> _searchHistoryByTransportation = {
    0: {}, // 지하철
    1: {}, // 버스
    2: {}, // 승용차
  };
  
  // 교통수단별 사용 횟수
  Map<int, int> _transportationUsage = {0: 0, 1: 0, 2: 0}; // 0: 지하철, 1: 버스, 2: 승용차

  // 가장 많이 사용한 교통수단 가져오기
  int getMostUsedTransportation() {
    int maxUsage = 0;
    int mostUsed = 0;
    
    _transportationUsage.forEach((key, value) {
      if (value > maxUsage) {
        maxUsage = value;
        mostUsed = key;
      }
    });
    
    return mostUsed;
  }

  // 교통수단 사용 횟수 증가
  void incrementTransportationUsage(int transportationType) {
    _transportationUsage[transportationType] = (_transportationUsage[transportationType] ?? 0) + 1;
    _saveTransportationUsage();
    notifyListeners();
  }

  // 검색 기록 추가 - 교통수단별로 분리하여 저장
  void addSearchHistory(String placeName, String address, int transportationType) {
    // 해당 교통수단의 검색 기록 맵 가져오기
    var transportationMap = _searchHistoryByTransportation[transportationType]!;
    
    print('검색 기록 추가: $placeName, 교통수단: $transportationType');
    
    if (transportationMap.containsKey(placeName)) {
      transportationMap[placeName]!['count'] = (transportationMap[placeName]!['count'] as int) + 1;
      print('기존 검색 기록 업데이트: $placeName, 횟수: ${transportationMap[placeName]!['count']}');
    } else {
      transportationMap[placeName] = {
        'name': placeName,
        'address': address,
        'count': 1,
        'transportationType': transportationType,
      };
      print('새 검색 기록 추가: $placeName, 교통수단: $transportationType');
    }
    
    // 교통수단 사용 횟수 증가
    incrementTransportationUsage(transportationType);
    
    _saveSearchHistory();
    notifyListeners();
  }

  // 검색 기록 삭제 - 특정 교통수단의 특정 장소 삭제
  void removeSearchHistory(String placeName, {int? transportationType}) {
    if (transportationType != null) {
      // 특정 교통수단의 검색 기록에서만 삭제
      if (_searchHistoryByTransportation[transportationType]!.containsKey(placeName)) {
        _searchHistoryByTransportation[transportationType]!.remove(placeName);
      }
    } else {
      // 모든 교통수단의 검색 기록에서 삭제
      for (var type in [0, 1, 2]) {
        if (_searchHistoryByTransportation[type]!.containsKey(placeName)) {
          _searchHistoryByTransportation[type]!.remove(placeName);
        }
      }
    }
    
    _saveSearchHistory();
    notifyListeners();
  }

  // 모든 검색 기록 삭제
  void clearAllSearchHistory() {
    for (var type in [0, 1, 2]) {
      _searchHistoryByTransportation[type]!.clear();
    }
    _saveSearchHistory();
    notifyListeners();
  }

  // 특정 교통수단의 모든 검색 기록 삭제
  void clearTransportationSearchHistory(int transportationType) {
    // 특정 교통수단의 검색 기록만 삭제
    _searchHistoryByTransportation[transportationType]!.clear();
    _saveSearchHistory();
    notifyListeners();
  }

  // 모든 교통수단의 검색 기록 가져오기
  List<Map<String, dynamic>> getAllSearchHistory() {
    List<Map<String, dynamic>> allHistory = [];
    
    for (var type in [0, 1, 2]) {
      allHistory.addAll(_searchHistoryByTransportation[type]!.values.toList());
    }
    
    return allHistory;
  }

  // 특정 교통수단의 검색 기록 가져오기
  List<Map<String, dynamic>> getSearchHistoryByTransportation(int transportationType) {
    return _searchHistoryByTransportation[transportationType]!.values.toList();
  }

  // 가장 많이 검색한 장소 가져오기 (교통수단별 필터링 옵션 추가)
  List<Map<String, dynamic>> getMostSearchedPlaces({int limit = 5, int? transportationType}) {
    List<Map<String, dynamic>> places = [];
    
    if (transportationType != null) {
      // 특정 교통수단의 검색 기록만 가져오기
      places = _searchHistoryByTransportation[transportationType]!.values.toList();
    } else {
      // 모든 교통수단의 검색 기록 가져오기
      places = getAllSearchHistory();
    }
    
    // 검색 횟수에 따라 정렬
    places.sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));
    
    // 상위 n개 반환
    return places.take(limit).toList();
  }

  // 검색 기록 저장
  Future<void> _saveSearchHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // 각 교통수단별 검색 기록을 JSON으로 변환하여 저장
      for (var type in [0, 1, 2]) {
        final String historyJson = jsonEncode(_searchHistoryByTransportation[type]);
        await prefs.setString('search_history_$type', historyJson);
      }
      
      print('검색 기록 저장 성공 (교통수단별)');
    } catch (e) {
      print('검색 기록 저장 오류: $e');
    }
  }

  // 교통수단 사용 횟수 저장
  Future<void> _saveTransportationUsage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String usageJson = jsonEncode(_transportationUsage.map((key, value) => 
        MapEntry(key.toString(), value)));
      await prefs.setString('transportation_usage', usageJson);
      print('교통수단 사용 횟수 저장 성공: $_transportationUsage');
    } catch (e) {
      print('교통수단 사용 횟수 저장 오류: $e');
    }
  }

  // 데이터 로드
  Future<void> loadData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // 각 교통수단별 검색 기록 로드
      for (var type in [0, 1, 2]) {
        final String? historyJson = prefs.getString('search_history_$type');
        if (historyJson != null) {
          final Map<String, dynamic> decodedMap = jsonDecode(historyJson);
          _searchHistoryByTransportation[type] = Map.from(decodedMap.map((key, value) => 
            MapEntry(key, Map<String, dynamic>.from(value))));
          print('교통수단 $type 검색 기록 로드 성공: ${_searchHistoryByTransportation[type]!.length}개 항목');
        }
      }
      
      // 교통수단 사용 횟수 로드
      final String? usageJson = prefs.getString('transportation_usage');
      if (usageJson != null) {
        final Map<String, dynamic> decodedMap = jsonDecode(usageJson);
        _transportationUsage = Map.from(decodedMap.map((key, value) => 
          MapEntry(int.parse(key), value as int)));
        print('교통수단 사용 횟수 로드 성공: $_transportationUsage');
      }
      
      notifyListeners();
    } catch (e) {
      print('데이터 로드 오류: $e');
    }
  }
}