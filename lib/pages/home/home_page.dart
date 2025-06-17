import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:http/http.dart' as http;
import '../time_setting/time_setting_page.dart';
import '../search/search_page.dart';
import '../../event_service.dart';
import '../calendar/calendar_page.dart' hide EventService;
import '../../route_store.dart';
import '../../favorite_service.dart';
import '../favorite/favorite_management_page.dart';
import '../../services/alarm_api_service.dart';
import '../../models/route_response.dart';
import '../../models/favorite_route_model.dart';
import '../assistant/assistant_page.dart';
import '../../services/calendar_service.dart';
import 'package:googleapis/calendar/v3.dart' as gcal;
import '../../config/server_config.dart';
import '../../services/notification_service.dart';
import '../../pages/route/route_lookup_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  // Animation controllers
  AnimationController? _backgroundAnimationController;
  AnimationController? _cardAnimationController;
  Animation<double>? _backgroundAnimation;
  Animation<double>? _cardAnimation;
  
  TextEditingController searchController = TextEditingController();

  // 이벤트 서비스 인스턴스
  final EventService _eventService = EventService();
  final FavoriteService _favoriteService = FavoriteService();
  late AlarmApiService _alarmApiService;
  String? _googleId;
  // DB에서 가져온 알람 도착시간 및 알람시간
  DateTime? _dbArrivalTime;
  DateTime? _dbWakeUpTime;

  // 준비 시간 관련 변수
  Duration preparationTime = const Duration(minutes: 30);
  Duration remainingTime = const Duration(minutes: 30);
  Timer? countdownTimer;
  Timer? alarmCheckTimer;
  String arrivalPeriod = '오전';
  int arrivalHour = 8;
  int arrivalMinute = 0;
  DateTime? arrivalDate;
  bool isCountdownActive = false;
  bool isAlarmScheduleActive = false;

  // 알람 관련 변수
  AudioPlayer? _audioPlayer;
  bool _isAlarmRinging = false;
  Timer? _alarmTimer;
  Timer? _vibrationTimer;
  String _currentAlarmType = '';
  String? _currentAlarmId;
  int? _notificationId;
  int? _wakeNotificationId;

  // 알람 등록 시 홈 알람 위젯 갱신 콜백
  VoidCallback? globalAlarmRefreshCallback;

  // 오늘 Google Calendar 이벤트 리스트
  List<gcal.Event> _todayGoogleEvents = [];

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeAlarm();
    _requestPermissions();

    // EventService 리스너 등록
    _eventService.addListener(_refreshState);
    _favoriteService.loadData();
    _favoriteService.addListener(_refreshState);
    _initAlarmApiService().then((_) => _loadTodayGoogleEvents());

    // Register callback for route alarm set
    RouteStore.onAlarmSet = () {
      setState(() {
        isAlarmScheduleActive = true;
      });
      _loadAlarms();
      _loadTodayGoogleEvents();
    };
  }

  void _initializeAnimations() {
    _backgroundAnimationController = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    )..repeat(reverse: true);
    
    _cardAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _backgroundAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _backgroundAnimationController!,
      curve: Curves.easeInOut,
    ));
    
    _cardAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _cardAnimationController!,
      curve: Curves.easeOutBack,
    ));
    
    _cardAnimationController!.forward();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E27),
      body: Stack(
        children: [
          // Animated gradient background
          AnimatedBuilder(
            animation: _backgroundAnimation ?? AlwaysStoppedAnimation(0.0),
            builder: (context, child) {
              return Stack(
                children: [
                  // Primary gradient orb
                  Positioned(
                    top: -100 + ((_backgroundAnimation?.value ?? 0) * 50),
                    right: -50,
                    child: Container(
                      width: 350,
                      height: 350,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            const Color(0xFF6366F1).withOpacity(0.8),
                            const Color(0xFF8B5CF6).withOpacity(0.4),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Secondary gradient orb
                  Positioned(
                    bottom: -150 + ((_backgroundAnimation?.value ?? 0) * 30),
                    left: -100,
                    child: Transform.rotate(
                      angle: (_backgroundAnimation?.value ?? 0) * 3.14,
                      child: Container(
                        width: 400,
                        height: 400,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              const Color(0xFF3B82F6).withOpacity(0.6),
                              const Color(0xFF06B6D4).withOpacity(0.3),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Accent gradient orb
                  Positioned(
                    top: MediaQuery.of(context).size.height * 0.4,
                    right: -80,
                    child: Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            const Color(0xFFEC4899).withOpacity(0.5),
                            const Color(0xFFF43F5E).withOpacity(0.2),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          // Main content
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    _buildHeader(),
                    const SizedBox(height: 30),
                    // Search bar
                    _buildSearchBar(),
                    const SizedBox(height: 30),
                    // Alarm card (with route find attached)
                    if (isAlarmScheduleActive || isCountdownActive) ...[
                      _buildAlarmCard(),
                      const SizedBox(height: 20),
                    ],
                    // Favorites only quick action
                    _buildFavoritesQuickAction(),
                    const SizedBox(height: 20),
                    // Today's schedule
                    _buildTodaySchedule(),
                    const SizedBox(height: 20),
                    // Favorites
                    _buildFavorites(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '안녕하세요 👋',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Lami와 함께해요',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withOpacity(0.2),
                  width: 1.5,
                ),
              ),
              child: const Icon(
                Icons.notifications_outlined,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const SearchPage()),
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.search,
                  color: Colors.white.withOpacity(0.7),
                ),
                const SizedBox(width: 12),
                Text(
                  '어디로 가시나요?',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRouteAlarmCard() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.white.withOpacity(0.2), width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Route Find Button
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SearchPage()),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.route, color: Colors.blue),
                      SizedBox(width: 8),
                      Text(
                        '경로 찾기',
                        style: TextStyle(
                          color: Colors.blue,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Alarm section inline
              if (isAlarmScheduleActive || isCountdownActive) ...[
                // Alarm status indicator
                if (isAlarmScheduleActive)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.orange.withOpacity(0.5)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.alarm, color: Colors.orange, size: 16),
                        SizedBox(width: 6),
                        Text(
                          '알람 활성화됨',
                          style: TextStyle(
                            color: Colors.orange,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 20),
                // Time display
                ShaderMask(
                  shaderCallback: (bounds) => LinearGradient(
                    colors: [Colors.white, Colors.white.withOpacity(0.8)],
                  ).createShader(bounds),
                  child: Text(
                    _formatDuration(remainingTime),
                    style: const TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 2,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '남은 준비 시간',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 24),
                // Time info row
                Row(
                  children: [
                    Expanded(
                      child: _buildTimeInfo('도착 시간', _getArrivalTimeString(), Icons.location_on),
                    ),
                    Container(
                      height: 40,
                      width: 1,
                      color: Colors.white.withOpacity(0.2),
                    ),
                    Expanded(
                      child: _buildTimeInfo('알람 시간', _getAlarmTimeString(), Icons.alarm),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // Action buttons
                if (isAlarmScheduleActive)
                  _buildGlassButton('알람 취소', Colors.red, _stopAlarmSchedule)
                else if (isCountdownActive)
                  _buildGlassButton('타이머 중지', Colors.orange, _stopCountdown)
                else
                  _buildGlassButton('알람 설정', Colors.blue, _startAlarmSchedule),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFavoritesQuickAction() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '빠른 실행',
          style: TextStyle(
            color: Colors.white.withOpacity(0.9),
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildQuickActionCard(
                '즐겨찾기',
                Icons.star,
                const Color(0xFFF59E0B),
                () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const FavoriteManagementPage(),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickActionCard(String title, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1.5,
              ),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    icon,
                    color: color,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTimeInfo(String label, String time, IconData icon) {
    return Column(
      children: [
        Icon(
          icon,
          color: Colors.white.withOpacity(0.7),
          size: 20,
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.5),
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          time.isEmpty ? '--:--' : time,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildGlassButton(String text, Color color, VoidCallback onPressed) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: color.withOpacity(0.5),
              width: 1.5,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onPressed,
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                child: Text(
                  text,
                  style: TextStyle(
                    color: color,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTodaySchedule() {
    final today = DateTime.now();
    final formattedDate = '${today.month}/${today.day} ${_getWeekdayString(today.weekday)}요일';
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '오늘의 일정',
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              formattedDate,
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 14,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withOpacity(0.2),
                  width: 1.5,
                ),
              ),
              child: _todayGoogleEvents.isEmpty
                  ? Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.event_available,
                            color: Colors.white.withOpacity(0.3),
                            size: 48,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '오늘 예정된 일정이 없습니다',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.5),
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _todayGoogleEvents.length > 3 ? 3 : _todayGoogleEvents.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final event = _todayGoogleEvents[index];
                        final title = event.summary ?? '제목 없음';
                        final dt = event.start?.dateTime?.toLocal();
                        final timeStr = dt != null ? DateFormat('HH:mm').format(dt) : '';
                        
                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.1),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.event,
                                  color: Colors.blue,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  title,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (timeStr.isNotEmpty)
                                Text(
                                  timeStr,
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.7),
                                    fontSize: 14,
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFavorites() {
    final displayFavorites = _favoriteService.getTopFavorites();
    
    if (displayFavorites.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '즐겨찾는 장소',
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const FavoriteManagementPage(),
                  ),
                );
              },
              child: Text(
                '모두 보기',
                style: TextStyle(
                  color: Colors.blue.withOpacity(0.8),
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 100,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: displayFavorites.length,
            separatorBuilder: (context, index) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final favorite = displayFavorites[index];
              return _buildFavoriteCard(favorite);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFavoriteCard(FavoriteRouteModel favorite) {
    IconData icon;
    Color color;
    
    switch (favorite.category) {
      case 'home':
        icon = Icons.home;
        color = const Color(0xFF10B981);
        break;
      case 'work':
        icon = Icons.work;
        color = const Color(0xFF3B82F6);
        break;
      case 'school':
        icon = Icons.school;
        color = const Color(0xFF8B5CF6);
        break;
      default:
        icon = Icons.place;
        color = const Color(0xFFF59E0B);
    }
    
    return GestureDetector(
      onTap: () {
        // Handle favorite tap
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            width: 100,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1.5,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: color,
                    size: 24,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  favorite.isDeparture ? favorite.origin : favorite.destination,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _initAlarmApiService() async {
    final prefs = await SharedPreferences.getInstance();
    final googleId = prefs.getString('googleId') ?? '';
    setState(() { _googleId = googleId; });
    _alarmApiService = AlarmApiService(googleId: googleId);
    await _loadAlarms();
  }

  Future<void> _loadAlarms() async {
    if (_googleId == null || _googleId!.isEmpty) return;
    try {
      final alarms = await _alarmApiService.getAlarms();
      if (alarms.isEmpty) return;
      _currentAlarmId = null;
      final now = DateTime.now();
      final upcoming = alarms.where((a) => DateTime.parse(a['wakeUpTime']).toLocal().isAfter(now)).toList();
      List<Map<String, dynamic>> candidates = [];
      candidates.addAll(upcoming.where((a) => a['savedRouteId'] != null));
      if (candidates.isEmpty && upcoming.isNotEmpty) {
        candidates = upcoming;
      }
      if (candidates.isEmpty) {
        final savedOnly = alarms.where((a) => a['savedRouteId'] != null).toList();
        candidates = savedOnly.isNotEmpty ? savedOnly : alarms;
      }
      candidates.sort((a, b) => DateTime.parse(a['wakeUpTime']).compareTo(DateTime.parse(b['wakeUpTime'])));
      final alarm = candidates.first;
      final arrivalTime = DateTime.parse(alarm['arrivalTime']).toLocal();
      final wakeUpTime = DateTime.parse(alarm['wakeUpTime']).toLocal();
      _dbArrivalTime = arrivalTime;
      _dbWakeUpTime = wakeUpTime;
      RouteStore.selectedRouteId = alarm['savedRouteId'] as String?;
      _currentAlarmId = alarm['id'] as String?;
      final prepMinutes = alarm['preparationTime'] as int;
      setState(() {
        preparationTime = Duration(minutes: prepMinutes);
        remainingTime = preparationTime;
        isAlarmScheduleActive = wakeUpTime.isAfter(now);
      });
      alarmCheckTimer?.cancel();
      if (wakeUpTime.isAfter(now)) {
        alarmCheckTimer = Timer.periodic(
          const Duration(seconds: 1),
          (timer) {
            final current = DateTime.now();
            if (current.isAfter(wakeUpTime) || current.isAtSameMomentAs(wakeUpTime)) {
              timer.cancel();
              setState(() {
                isAlarmScheduleActive = false;
              });
              _startAlarm('schedule');
            }
          },
        );
      }
      // Schedule local notifications for this alarm
      if (wakeUpTime.isAfter(now)) {
        if (_notificationId != null) {
          await NotificationService.cancelNotification(_notificationId!);
        }
        if (_wakeNotificationId != null) {
          await NotificationService.cancelNotification(_wakeNotificationId!);
        }
        final startDt = wakeUpTime.subtract(preparationTime);
        final alarmTimeStr = _getAlarmTimeString();
        final now2 = DateTime.now();
        if (startDt.isAfter(now2)) {
          _notificationId = startDt.millisecondsSinceEpoch ~/ 1000;
          await NotificationService.scheduleNotification(
            id: _notificationId!,
            title: '⏰ 알람: $alarmTimeStr 도착 준비',
            body: '준비시간: ${preparationTime.inMinutes}분\n도착 예정: $alarmTimeStr',
            scheduledDate: startDt,
          );
        }
        _wakeNotificationId = wakeUpTime.millisecondsSinceEpoch ~/ 1000;
        await NotificationService.scheduleNotification(
          id: _wakeNotificationId!,
          title: '⏰ 준비할 시간입니다',
          body: '설정된 도착 시간($alarmTimeStr)에 맞춰 준비하세요.',
          scheduledDate: wakeUpTime,
        );
      }
    } catch (e) {
      print('알람 조회 실패: $e');
    }
  }

  Future<void> _initializeAlarm() async {
    _audioPlayer = AudioPlayer();
  }

  Future<void> _requestPermissions() async {
    await Permission.notification.request();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _initAlarmApiService();
  }

  void _refreshState() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _backgroundAnimationController?.dispose();
    _cardAnimationController?.dispose();
    _eventService.removeListener(_refreshState);
    _favoriteService.removeListener(_refreshState);
    countdownTimer?.cancel();
    alarmCheckTimer?.cancel();
    _stopAlarm();
    _audioPlayer?.dispose();
    RouteStore.onAlarmSet = null;
    super.dispose();
  }

  Future<void> _startAlarmSchedule() async {
    alarmCheckTimer?.cancel();
    countdownTimer?.cancel();

    try {
      final now = DateTime.now();
      var hour24 = arrivalHour;
      if (arrivalPeriod == '오후' && arrivalHour != 12) hour24 += 12;
      else if (arrivalPeriod == '오전' && arrivalHour == 12) hour24 = 0;
      var arrivalDateTime = DateTime(now.year, now.month, now.day, hour24, arrivalMinute);
      if (arrivalDateTime.isBefore(now)) arrivalDateTime = arrivalDateTime.add(const Duration(days: 1));
      
      await _alarmApiService.registerAlarm(
        arrivalTime: arrivalDateTime.toIso8601String(),
        preparationTime: preparationTime.inMinutes,
      );
      
      final startDt = arrivalDateTime.subtract(preparationTime);
      final arrivalTimeStr = '${arrivalPeriod} ${arrivalHour}:${arrivalMinute.toString().padLeft(2, '0')}';

      try {
        if (!CalendarService.isSignedIn()) {
          await CalendarService.signIn();
        }
        
        await CalendarService.addEvent(
          summary: '⏰ 알람: ${arrivalTimeStr} 도착 준비',
          start: startDt,
          end: arrivalDateTime,
          description: '준비시간: ${preparationTime.inMinutes}분\n도착 예정: $arrivalTimeStr',
        );
        
        print('✅ 홈 알람 - Google Calendar 일정 추가 성공!');
      } catch (e) {
        print('❌ 홈 알람 - 캘린더 추가 실패: $e');
      }

      final now2 = DateTime.now();
      if (startDt.isAfter(now2)) {
        _notificationId = startDt.millisecondsSinceEpoch ~/ 1000;
        await NotificationService.scheduleNotification(
          id: _notificationId!,
          title: '⏰ 알람: $arrivalTimeStr 도착 준비',
          body: '준비시간: ${preparationTime.inMinutes}분\n도착 예정: $arrivalTimeStr',
          scheduledDate: startDt,
        );
      }
      _wakeNotificationId = arrivalDateTime.millisecondsSinceEpoch ~/ 1000;
      await NotificationService.scheduleNotification(
        id: _wakeNotificationId!,
        title: '⏰ 준비할 시간입니다',
        body: '설정된 도착 시간($arrivalTimeStr)에 맞춰 준비하세요.',
        scheduledDate: arrivalDateTime.subtract(preparationTime),
      );
    } catch (e) {
      print('알람 서버 등록 실패: $e');
    }

    setState(() {
      isAlarmScheduleActive = true;
      isCountdownActive = false;
    });

    alarmCheckTimer = Timer.periodic(
      const Duration(seconds: 1),
          (timer) {
        DateTime now = DateTime.now();
        DateTime alarmTime = _getAlarmDateTime();

        if (now.isAfter(alarmTime) || now.isAtSameMomentAs(alarmTime)) {
          timer.cancel();
          setState(() {
            isAlarmScheduleActive = false;
          });

          _startAlarm('schedule');
        }
      },
    );
  }

  Future<void> _stopAlarmSchedule() async {
    alarmCheckTimer?.cancel();
    setState(() {
      isAlarmScheduleActive = false;
    });
    if (_notificationId != null) {
      await NotificationService.cancelNotification(_notificationId!);
      _notificationId = null;
    }
    if (_wakeNotificationId != null) {
      await NotificationService.cancelNotification(_wakeNotificationId!);
      _wakeNotificationId = null;
    }
    if (_currentAlarmId != null) {
      try {
        await _alarmApiService.deleteAlarm(id: _currentAlarmId!);
        final routeId = RouteStore.selectedRouteId;
        if (routeId != null) {
          final resp = await http.delete(
            Uri.parse('${getServerBaseUrl()}/traffic/routes/save/$routeId'),
            headers: {'Content-Type': 'application/json'},
          );
          if (resp.statusCode >= 200 && resp.statusCode < 300) {
            RouteStore.selectedRouteId = null;
          }
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('알람 취소 실패: $e')),
        );
      }
      _currentAlarmId = null;
      await _loadAlarms();
    }
  }

  DateTime _getAlarmDateTime() {
    DateTime now = DateTime.now();
    DateTime arrivalDateTime;
    int hour24 = arrivalHour;
    if (arrivalPeriod == '오후' && arrivalHour != 12) {
      hour24 += 12;
    } else if (arrivalPeriod == '오전' && arrivalHour == 12) {
      hour24 = 0;
    }

    arrivalDateTime = DateTime(now.year, now.month, now.day, hour24, arrivalMinute);

    if (arrivalDateTime.isBefore(now)) {
      arrivalDateTime = arrivalDateTime.add(const Duration(days: 1));
    }

    return arrivalDateTime.subtract(preparationTime);
  }

  Future<void> _startAlarm(String alarmType) async {
    if (_isAlarmRinging) return;

    setState(() {
      _isAlarmRinging = true;
      _currentAlarmType = alarmType;
    });

    WakelockPlus.enable();

    _alarmTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      if (_isAlarmRinging) {
        try {
          await _audioPlayer?.play(AssetSource('sounds/notification.mp3')).catchError((_) async {
            SystemSound.play(SystemSoundType.alert);
          });
        } catch (e) {
          SystemSound.play(SystemSoundType.alert);
        }
      }
    });

    _vibrationTimer = Timer.periodic(const Duration(milliseconds: 1000), (timer) {
      if (_isAlarmRinging) {
        HapticFeedback.heavyImpact();
      }
    });

    _showAlarmDialog(alarmType);
  }

  void _stopAlarm() {
    if (!_isAlarmRinging) return;

    setState(() {
      _isAlarmRinging = false;
      _currentAlarmType = '';
    });

    _alarmTimer?.cancel();
    _vibrationTimer?.cancel();
    _audioPlayer?.stop();
    WakelockPlus.disable();
  }

  void _showAlarmDialog(String alarmType) {
    String title = '';
    String message = '';
    String buttonText = '';
    VoidCallback onPressed = () {};

    if (alarmType == 'schedule') {
      title = '준비시간 시작!';
      message = '설정한 알람예정시간이 되었습니다!\n이제 준비를 시작하세요.';
      buttonText = '준비 시작';
      onPressed = () {
        _stopAlarm();
        Navigator.of(context).pop();
        _startCountdown();
      };
    } else if (alarmType == 'countdown') {
      title = '준비시간 완료!';
      message = '설정한 준비시간이 완료되었습니다!\n이제 출발할 시간입니다.';
      buttonText = '알람 끄기';
      onPressed = () {
        _stopAlarm();
        Navigator.of(context).pop();
        setState(() {
          remainingTime = preparationTime;
        });
      };
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return WillPopScope(
          onWillPop: () async => false,
          child: Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.all(24),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.2), width: 1.5),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                  Icons.alarm,
                  color: Colors.red,
                  size: 28,
                ),
                          ),
                          const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                              color: Colors.white,
                  ),
                ),
              ],
            ),
                      const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.notifications_active,
                        size: 48,
                              color: Colors.red.withOpacity(0.8),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        message,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                                color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                      const SizedBox(height: 24),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.red.withOpacity(0.5),
                                width: 1.5,
                              ),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: onPressed,
                                borderRadius: BorderRadius.circular(12),
                                child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                          alarmType == 'schedule' ? Icons.play_arrow : Icons.alarm_off,
                                        size: 20,
                                        color: Colors.white,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        buttonText,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                        ),
                      ),
                    ],
                                  ),
                                ),
                              ),
                            ),
                  ),
                ),
              ),
            ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void setPrepTime(Duration newPrepTime) {
    setState(() {
      preparationTime = newPrepTime;
      remainingTime = newPrepTime;

      if (isCountdownActive) {
        countdownTimer?.cancel();
        isCountdownActive = false;
      }
      if (isAlarmScheduleActive) {
        alarmCheckTimer?.cancel();
        isAlarmScheduleActive = false;
      }
    });
  }

  void setArrivalTime(String period, int hour, int minute, DateTime date) {
    setState(() {
      arrivalPeriod = period;
      arrivalHour = hour;
      arrivalMinute = minute;
      arrivalDate = date;
    });
  }

  void _startCountdown() {
    countdownTimer?.cancel();

    setState(() {
      isCountdownActive = true;
      remainingTime = preparationTime;
    });

    countdownTimer = Timer.periodic(
      const Duration(seconds: 1),
          (timer) {
        setState(() {
          if (remainingTime.inSeconds > 0) {
            remainingTime = remainingTime - const Duration(seconds: 1);
          } else {
            countdownTimer?.cancel();
            isCountdownActive = false;
            _startAlarm('countdown');
          }
        });
      },
    );
  }

  void _stopCountdown() {
    setState(() {
      countdownTimer?.cancel();
      isCountdownActive = false;
    });
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String hours = twoDigits(duration.inHours);
    String minutes = twoDigits(duration.inMinutes.remainder(60));
    String seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$hours:$minutes:$seconds";
  }

  String _formatPrepTime() {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String hours = twoDigits(preparationTime.inHours);
    String minutes = twoDigits(preparationTime.inMinutes.remainder(60));
    String seconds = twoDigits(preparationTime.inSeconds.remainder(60));
    return "+$hours:$minutes:$seconds";
  }

  String _getArrivalTimeString() {
    if (_dbArrivalTime != null) {
      final dt = _dbArrivalTime!;
      final hour = dt.hour;
      final minute = dt.minute;
      final period = hour >= 12 ? '오후' : '오전';
      final displayHour = hour % 12 == 0 ? 12 : hour % 12;
      final hourStr = displayHour.toString().padLeft(2, '0');
      final minuteStr = minute.toString().padLeft(2, '0');
      return '$period $hourStr:$minuteStr';
    }
    return '';
  }

  String _getAlarmTimeString() {
    if (_dbWakeUpTime != null) {
      final dt = _dbWakeUpTime!;
      final hour = dt.hour;
      final minute = dt.minute;
      final period = hour < 12 ? '오전' : '오후';
      final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
      final hourStr = displayHour.toString().padLeft(2, '0');
      final minuteStr = minute.toString().padLeft(2, '0');
      return '$period $hourStr:$minuteStr';
    }
    return '';
  }

  void _goToShortestRoutePage() {
    final routeId = RouteStore.selectedRouteId;
    if (routeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('먼저 경로를 저장해주세요')),
      );
      return;
    }
    RouteStore.fetchRouteDetailAndShow(context, routeId);
  }

  void _goToTimeSettingPage() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TimeSettingPage(
          onPrepTimeSet: setPrepTime,
          onArrivalTimeSet: setArrivalTime,
          initialArrivalPeriod: arrivalPeriod,
          initialArrivalHour: arrivalHour,
          initialArrivalMinute: arrivalMinute,
          initialPrepTime: preparationTime,
        ),
      ),
    ).then((_) {
      _loadAlarms();
      setState(() {});
    });
  }

  void _goToCalendarPage() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CalendarPage()),
    ).then((_) {
      setState(() {});
    });
  }

  String _getWeekdayString(int weekday) {
    const weekdays = ['월', '화', '수', '목', '금', '토', '일'];
    return weekdays[weekday - 1];
  }

  Future<void> _loadTodayGoogleEvents() async {
    try {
      if (!CalendarService.isSignedIn()) {
        await CalendarService.signIn();
      }
      
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));
      
      final events = await CalendarService.fetchEvents(
        timeMin: startOfDay,
        timeMax: endOfDay,
      );
      
      setState(() {
        _todayGoogleEvents = events;
      });
    } catch (e) {
      print('Google Calendar 이벤트 로드 실패: $e');
    }
  }

  Widget _buildAlarmCard() {
    return AnimatedBuilder(
      animation: _cardAnimation ?? AlwaysStoppedAnimation(1.0),
      builder: (context, child) {
        return Transform.scale(
          scale: 0.9 + ((_cardAnimation?.value ?? 1.0) * 0.1),
          child: Opacity(
            opacity: _cardAnimation?.value ?? 1.0,
            child: GestureDetector(
              onTap: _goToTimeSettingPage,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withOpacity(0.15),
                          Colors.white.withOpacity(0.05),
                        ],
                    ),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.2),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Top: Alarm details panel
                        Column(
                          children: [
                            // Alarm status indicator
                            if (isAlarmScheduleActive)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(color: Colors.orange.withOpacity(0.2), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.orange.withOpacity(0.5))),
                                child: Row(mainAxisSize: MainAxisSize.min, children: const [Icon(Icons.alarm, color: Colors.orange, size: 16), SizedBox(width: 6), Text('알람 활성화됨', style: TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.bold))]),
                              ),
                            const SizedBox(height: 20),
                            // Time display and prep info
                            ShaderMask(shaderCallback: (bounds) => LinearGradient(colors: [Colors.white, Colors.white.withOpacity(0.8)]).createShader(bounds), child: Text(_formatDuration(remainingTime), style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 2))),
                        const SizedBox(height: 8),
                            Text('남은 준비 시간', style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 16)),
                            const SizedBox(height: 24),
                            // Time info row
                        Row(
                          children: [
                                Expanded(
                                  child: _buildTimeInfo('도착 시간', _getArrivalTimeString(), Icons.location_on),
                                ),
                            Container(
                              height: 40,
                              width: 1,
                                  color: Colors.white.withOpacity(0.2),
                            ),
                                Expanded(
                                  child: _buildTimeInfo('알람 시간', _getAlarmTimeString(), Icons.alarm),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            // Action button
                        if (isAlarmScheduleActive)
                              _buildGlassButton('알람 취소', Colors.red, _stopAlarmSchedule)
                        else if (isCountdownActive)
                              _buildGlassButton('타이머 중지', Colors.orange, _stopCountdown)
                            else
                              _buildGlassButton('알람 설정', Colors.blue, _startAlarmSchedule),
                          ],
                        ),
                        const SizedBox(height: 20),
                        // Bottom: Route lookup button
                        _buildRouteButton(),
                      ],
                    ),
                  ),
            ),
          ),
        ),
      ),
    );
      },
    );
  }
  
  // Button leading to the saved route's detail, styled like a route summary card
  Widget _buildRouteButton() {
    return GestureDetector(
      onTap: () {
        if (RouteStore.selectedRouteId != null) {
          RouteStore.fetchRouteDetailAndShow(context, RouteStore.selectedRouteId!);
        }
      },
                      child: Container(
                        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Row(
        children: [
                  const Icon(Icons.route, color: Colors.white),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      '경로 조회',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 16),
          ],
        ),
            ),
          ),
        ),
      ),
    );
  }
}