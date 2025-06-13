import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/favorite_api_service.dart';
import 'models/favorite_route_model.dart';

class FavoriteService extends ChangeNotifier {
  // 싱글톤 패턴 구현
  static final FavoriteService _instance = FavoriteService._internal();
  factory FavoriteService() => _instance;
  FavoriteService._internal();
  
  List<FavoriteRouteModel> _favoriteList = [];
  List<FavoriteRouteModel> get favoriteList => List.unmodifiable(_favoriteList);
  
  // 마지막 데이터 로드 시간 추적
  DateTime? _lastLoadTime;
  // 캐시 유효 시간 (5분)
  static const Duration _cacheValidDuration = Duration(minutes: 5);
  // 데이터 로딩 상태
  bool _isLoading = false;
  
  // 로컬 데이터 로드 여부
  bool _localDataLoaded = false;

  // 데이터 로드 - 최적화된 버전
  Future<void> loadData() async {
    // 이미 로딩 중이면 중복 로드 방지
    if (_isLoading) return;
    
    // 캐시가 유효하면 다시 로드하지 않음
    if (_lastLoadTime != null && 
        DateTime.now().difference(_lastLoadTime!) < _cacheValidDuration &&
        _favoriteList.isNotEmpty) {
      return;
    }
    
    _isLoading = true;
    final prefs = await SharedPreferences.getInstance();
    final googleId = prefs.getString('googleId');
    if (googleId == null) {
      _isLoading = false;
      return;
    }
    
    // 로컬 데이터를 먼저 로드하여 UI 표시 지연 방지
    if (!_localDataLoaded) {
      try {
        final localList = await FavoriteApiService(googleId: googleId).getLocalFavorites();
        if (localList.isNotEmpty) {
          _favoriteList = localList;
          _localDataLoaded = true;
          notifyListeners();
        }
      } catch (e) {
        debugPrint('로컬 즐겨찾기 불러오기 에러: $e');
      }
    }
    
    // 서버에서 데이터 로드
    try {
      final list = await FavoriteApiService(googleId: googleId).getFavorites();
      _favoriteList = list;
      _lastLoadTime = DateTime.now();
      notifyListeners();
    } catch (e) {
      debugPrint('즐겨찾기 불러오기 에러: $e');
    } finally {
      _isLoading = false;
    }
  }

  // 경로 즐겨찾기 추가 (최적화)
  Future<void> addFavorite({
    required String origin,
    required String destination,
    required String category,
    String? originAddress,
    String? destinationAddress,
    String iconName = 'place',
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final googleId = prefs.getString('googleId');
    if (googleId == null) return;
    
    try {
      // 즐겨찾기 추가 요청 (비동기로 처리)
      FavoriteApiService(googleId: googleId).addFavorite(
        origin: origin,
        destination: destination,
        category: category,
        wakeUpTime: DateTime.now().toIso8601String(),
        originAddress: originAddress,
        destinationAddress: destinationAddress,
        iconName: iconName,
        isDeparture: false,
      );
      
      // 즉시 데이터 로드하여 UI 업데이트 (await 유지)
      await loadData();
    } catch (e) {
      debugPrint('즐겨찾기 추가 에러: $e');
      // 에러가 발생해도 UI 업데이트를 위해 데이터 로드
      await loadData();
    }
  }
  
  // 출발지 즐겨찾기 추가 (최적화)
  Future<void> addDepartureFavorite({
    required String place,
    required String category,
    String? address,
    String iconName = 'place',
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final googleId = prefs.getString('googleId');
    if (googleId == null) return;
    
    try {
      // 즐겨찾기 추가 요청 (비동기로 처리)
      FavoriteApiService(googleId: googleId).addFavorite(
        origin: place,
        destination: '',
        category: category,
        wakeUpTime: DateTime.now().toIso8601String(),
        originAddress: address,
        iconName: iconName,
        isDeparture: true,
      );
      
      // 즉시 데이터 로드하여 UI 업데이트 (await 유지)
      await loadData();
    } catch (e) {
      debugPrint('출발지 즐겨찾기 추가 에러: $e');
      // 에러가 발생해도 UI 업데이트를 위해 데이터 로드
      await loadData();
    }
  }
  
  // 목적지 즐겨찾기 추가 (최적화)
  Future<void> addDestinationFavorite({
    required String place,
    required String category,
    String? address,
    String iconName = 'place',
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final googleId = prefs.getString('googleId');
    if (googleId == null) return;
    
    try {
      // 즐겨찾기 추가 요청 (비동기로 처리)
      FavoriteApiService(googleId: googleId).addFavorite(
        origin: '',
        destination: place,
        category: category,
        wakeUpTime: DateTime.now().toIso8601String(),
        destinationAddress: address,
        iconName: iconName,
        isDeparture: false,
      );
      
      // 즉시 데이터 로드하여 UI 업데이트 (await 유지)
      await loadData();
    } catch (e) {
      debugPrint('목적지 즐겨찾기 추가 에러: $e');
      // 에러가 발생해도 UI 업데이트를 위해 데이터 로드
      await loadData();
    }
  }

  // 즐겨찾기 삭제 (최적화)
  Future<void> removeFavorite(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final googleId = prefs.getString('googleId');
    if (googleId == null) return;
    
    // 즉시 UI에서 삭제하여 반응성 향상
    _favoriteList.removeWhere((f) => f.id == id);
    notifyListeners();
    
    try {
      // 서버에서 삭제 요청 (비동기로 처리)
      FavoriteApiService(googleId: googleId).removeFavorite(id);
    } catch (e) {
      debugPrint('즐겨찾기 삭제 에러: $e');
      // 에러 발생 시 최신 데이터 다시 로드
      await loadData();
    }
  }

  // 상위 3개 즐겨찾기 가져오기 (메인 페이지용)
  List<FavoriteRouteModel> getTop3Favorites() {
    return _favoriteList.take(3).toList();
  }
  
  // 출발지 즐겨찾기 목록 가져오기
  List<FavoriteRouteModel> getDepartureFavorites() {
    return _favoriteList
        .where((favorite) => favorite.isDeparture == true)
        .toList();
  }
  
  // 목적지 즐겨찾기 목록 가져오기
  List<FavoriteRouteModel> getDestinationFavorites() {
    return _favoriteList
        .where((favorite) => 
            favorite.isDeparture == false && 
            favorite.destination.isNotEmpty && 
            favorite.origin.isEmpty)
        .toList();
  }
  
  // 상위 3개 출발지 즐겨찾기 가져오기
  List<FavoriteRouteModel> getTop3DepartureFavorites() {
    return getDepartureFavorites().take(3).toList();
  }
  
  // 상위 3개 목적지 즐겨찾기 가져오기
  List<FavoriteRouteModel> getTop3DestinationFavorites() {
    return getDestinationFavorites().take(3).toList();
  }
  
  // 모든 즐겨찾기를 가져오는 메서드 (최대 6개)
  List<FavoriteRouteModel> getTopFavorites({int limit = 6}) {
    return _favoriteList.take(limit).toList();
  }

  // 특정 ID의 즐겨찾기 찾기
  FavoriteRouteModel? findFavoriteById(String id) {
    try {
      return _favoriteList.firstWhere((favorite) => favorite.id == id);
    } catch (e) {
      return null;
    }
  }
}