import 'dart:async';
import 'dart:convert';
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
import '../../event_service.dart'; // EventService 불러오기
import '../calendar/calendar_page.dart' hide EventService; // CalendarPage 불러오기
import '../../route_store.dart';
import '../../favorite_service.dart';
import '../favorite/favorite_management_page.dart';
import '../../services/alarm_api_service.dart';
import '../../models/route_response.dart';
import '../../models/favorite_route_model.dart';
import '../assistant/assistant_page.dart';
import '../../services/calendar_service.dart';
import 'package:googleapis/calendar/v3.dart' as gcal;
import '../../config/server_config.dart'; // getServerBaseUrl import 추가
import '../../services/notification_service.dart';


class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
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
  Duration preparationTime = const Duration(minutes: 30); // 기본값 30분
  Duration remainingTime = const Duration(minutes: 30); // 남은 시간 (초기값 30분)
  Timer? countdownTimer;
  Timer? alarmCheckTimer; // 알람예정시간 체크용 타이머
  String arrivalPeriod = '오전';
  int arrivalHour = 8;
  int arrivalMinute = 0;
  DateTime? arrivalDate;
  bool isCountdownActive = false;
  bool isAlarmScheduleActive = false; // 알람예정시간 스케줄 활성화 여부

  // 알람 관련 변수
  AudioPlayer? _audioPlayer;
  bool _isAlarmRinging = false;
  Timer? _alarmTimer;
  Timer? _vibrationTimer;
  String _currentAlarmType = ''; // 현재 울리는 알람 타입 ('schedule' 또는 'countdown')
  // Currently scheduled alarm ID on server
  String? _currentAlarmId;
  // Currently scheduled local notification ID
  int? _notificationId;

  // 알람 등록 시 홈 알람 위젯 갱신 콜백
  VoidCallback? globalAlarmRefreshCallback;

  // 오늘 Google Calendar 이벤트 리스트
  List<gcal.Event> _todayGoogleEvents = [];

  @override
  void initState() {
    super.initState();
    _initializeAlarm();
    _requestPermissions();

    // EventService 리스너 등록
    _eventService.addListener(_refreshState);
    _favoriteService.loadData();
    _favoriteService.addListener(_refreshState);
    _initAlarmApiService().then((_) => _loadTodayGoogleEvents());

    // Register callback for route alarm set
    RouteStore.onAlarmSet = () {
      // Immediately mark alarm as scheduled in UI
      setState(() {
        isAlarmScheduleActive = true;
      });
      // Then refresh alarms from server if needed
      _loadAlarms();
      // 리로드 오늘 Google Calendar 일정
      _loadTodayGoogleEvents();
    };
  }

  Future<void> _initAlarmApiService() async {
    final prefs = await SharedPreferences.getInstance();
    final googleId = prefs.getString('googleId') ?? '';
    setState(() { _googleId = googleId; });
    _alarmApiService = AlarmApiService(googleId: googleId);
    // 서버에 저장된 알람 불러오기
    await _loadAlarms();
  }

  /// 서버에 저장된 알람을 조회하고 홈 화면 위젯 상태를 업데이트합니다.
  Future<void> _loadAlarms() async {
    if (_googleId == null || _googleId!.isEmpty) return;
    try {
      final alarms = await _alarmApiService.getAlarms();
      if (alarms.isEmpty) return;
      // Clear any previous ID
      _currentAlarmId = null;
      final now = DateTime.now();
      // Upcoming alarms
      final upcoming = alarms.where((a) => DateTime.parse(a['wakeUpTime']).toLocal().isAfter(now)).toList();
      // Select candidates: first upcoming with savedRouteId, or upcoming, or any savedRoute, or any alarm
      List<Map<String, dynamic>> candidates = [];
      candidates.addAll(upcoming.where((a) => a['savedRouteId'] != null));
      if (candidates.isEmpty && upcoming.isNotEmpty) {
        candidates = upcoming;
      }
      if (candidates.isEmpty) {
        final savedOnly = alarms.where((a) => a['savedRouteId'] != null).toList();
        candidates = savedOnly.isNotEmpty ? savedOnly : alarms;
      }
      // Sort by wakeUpTime ascending
      candidates.sort((a, b) => DateTime.parse(a['wakeUpTime']).compareTo(DateTime.parse(b['wakeUpTime'])));
      final alarm = candidates.first;
      // DB에서 가져온 arrivalTime, wakeUpTime 설정
      final arrivalTime = DateTime.parse(alarm['arrivalTime']).toLocal();
      final wakeUpTime = DateTime.parse(alarm['wakeUpTime']).toLocal();
      _dbArrivalTime = arrivalTime;
      _dbWakeUpTime = wakeUpTime;
      // 저장된 경로 ID를 전역 상태에 설정
      RouteStore.selectedRouteId = alarm['savedRouteId'] as String?;
      // Store alarm ID for cancellation
      _currentAlarmId = alarm['id'] as String?;
      final prepMinutes = alarm['preparationTime'] as int;
      setState(() {
        // 준비 시간 및 남은 시간
        preparationTime = Duration(minutes: prepMinutes);
        remainingTime = preparationTime;
        isAlarmScheduleActive = wakeUpTime.isAfter(now);
      });
      // Schedule alarm check only if wake-up is in the future
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
    } catch (e) {
      print('알람 조회 실패: $e');
    }
  }

  // 알람 초기화
  Future<void> _initializeAlarm() async {
    _audioPlayer = AudioPlayer();
  }

  // 권한 요청
  Future<void> _requestPermissions() async {
    await Permission.notification.request();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 로그인 상태 변경 시 알람 API 서비스 및 알람 데이터 초기화
    _initAlarmApiService();
  }

  // 상태 갱신 함수
  void _refreshState() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    // EventService 리스너 제거
    _eventService.removeListener(_refreshState);
    _favoriteService.removeListener(_refreshState);
    countdownTimer?.cancel();
    alarmCheckTimer?.cancel();
    _stopAlarm();
    _audioPlayer?.dispose();
    // Route alarm callback 해제
    RouteStore.onAlarmSet = null;
    super.dispose();
  }

  // 알람예정시간 스케줄 시작
  Future<void> _startAlarmSchedule() async {
    // 기존 타이머들 취소
    alarmCheckTimer?.cancel();
    countdownTimer?.cancel();

    // 서버에 알람 등록
    try {
      // arrivalDateTime 계산 (서버 계산에도 참고용)
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
      
      // Google Calendar에 일정 추가
      try {
        if (!CalendarService.isSignedIn()) {
          await CalendarService.signIn();
        }
        
        final startDt = arrivalDateTime.subtract(preparationTime);
        final arrivalTimeStr = '${arrivalPeriod} ${arrivalHour}:${arrivalMinute.toString().padLeft(2, '0')}';
        
        await CalendarService.addEvent(
          summary: '⏰ 알람: ${arrivalTimeStr} 도착 준비',
          start: startDt,
          end: arrivalDateTime,
          description: '준비시간: ${preparationTime.inMinutes}분\n도착 예정: $arrivalTimeStr',
        );
        
        print('✅ 홈 알람 - Google Calendar 일정 추가 성공!');
        // 로컬 알림 스케줄링
        _notificationId = startDt.millisecondsSinceEpoch ~/ 1000;
        await NotificationService.scheduleNotification(
          id: _notificationId!,
          title: '⏰ 알람: $arrivalTimeStr 도착 준비',
          body: '준비시간: ${preparationTime.inMinutes}분\n도착 예정: $arrivalTimeStr',
          scheduledDate: startDt,
        );
      } catch (e) {
        print('❌ 홈 알람 - 캘린더 추가 실패: $e');
        // 캘린더 추가 실패해도 알람은 정상 동작하도록
      }
    } catch (e) {
      print('알람 서버 등록 실패: $e');
    }

    setState(() {
      isAlarmScheduleActive = true;
      isCountdownActive = false;
    });

    // 1초마다 알람예정시간 체크
    alarmCheckTimer = Timer.periodic(
      const Duration(seconds: 1),
          (timer) {
        DateTime now = DateTime.now();
        DateTime alarmTime = _getAlarmDateTime();

        // 알람예정시간이 되면
        if (now.isAfter(alarmTime) || now.isAtSameMomentAs(alarmTime)) {
          timer.cancel();
          setState(() {
            isAlarmScheduleActive = false;
          });

          // 알람예정시간 알람 울리기
          _startAlarm('schedule');
        }
      },
    );
  }

  // 알람예정시간 스케줄 중지
  Future<void> _stopAlarmSchedule() async {
    // Cancel local timer & UI state
    alarmCheckTimer?.cancel();
    setState(() {
      isAlarmScheduleActive = false;
    });
    // 로컬 알림 취소
    if (_notificationId != null) {
      await NotificationService.cancelNotification(_notificationId!);
      _notificationId = null;
    }
    // Delete from server
    if (_currentAlarmId != null) {
      try {
        await _alarmApiService.deleteAlarm(id: _currentAlarmId!);
        // 저장된 경로 삭제
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
      // 알람 취소 후 최신 알람 정보 로드
      await _loadAlarms();
    }
  }

  // 알람예정시간 DateTime 계산
  DateTime _getAlarmDateTime() {
    DateTime now = DateTime.now();

    // 도착시간을 DateTime으로 변환
    DateTime arrivalDateTime;
    int hour24 = arrivalHour;
    if (arrivalPeriod == '오후' && arrivalHour != 12) {
      hour24 += 12;
    } else if (arrivalPeriod == '오전' && arrivalHour == 12) {
      hour24 = 0;
    }

    arrivalDateTime = DateTime(now.year, now.month, now.day, hour24, arrivalMinute);

    // 만약 도착시간이 현재시간보다 이르면 다음날로 설정
    if (arrivalDateTime.isBefore(now)) {
      arrivalDateTime = arrivalDateTime.add(const Duration(days: 1));
    }

    // 알람시간 = 도착시간 - 준비시간
    return arrivalDateTime.subtract(preparationTime);
  }

  // 알람 시작 (타입별로 구분)
  Future<void> _startAlarm(String alarmType) async {
    if (_isAlarmRinging) return;

    setState(() {
      _isAlarmRinging = true;
      _currentAlarmType = alarmType;
    });

    // 화면 켜짐 유지
    WakelockPlus.enable();

    // 시스템 알림음 재생 (반복)
    _alarmTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      if (_isAlarmRinging) {
        try {
          // 시스템 기본 알림음 재생
          await _audioPlayer?.play(AssetSource('sounds/notification.mp3')).catchError((_) async {
            // 에셋 파일이 없으면 시스템 사운드 사용
            SystemSound.play(SystemSoundType.alert);
          });
        } catch (e) {
          // 오류 발생 시 시스템 사운드로 대체
          SystemSound.play(SystemSoundType.alert);
        }
      }
    });

    // 진동 시작 (반복)
    _vibrationTimer = Timer.periodic(const Duration(milliseconds: 1000), (timer) {
      if (_isAlarmRinging) {
        HapticFeedback.heavyImpact(); // 강한 진동
      }
    });

    // 알람 다이얼로그 표시
    _showAlarmDialog(alarmType);
  }

  // 알람 중지
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

  // 알람 다이얼로그 표시 (타입별로 구분)
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
        // 준비시간 카운트다운 시작
        _startCountdown();
      };
    } else if (alarmType == 'countdown') {
      title = '준비시간 완료!';
      message = '설정한 준비시간이 완료되었습니다!\n이제 출발할 시간입니다.';
      buttonText = '알람 끄기';
      onPressed = () {
        _stopAlarm();
        Navigator.of(context).pop();
        // 타이머 리셋
        setState(() {
          remainingTime = preparationTime;
        });
      };
    }

    showDialog(
      context: context,
      barrierDismissible: false, // 다이얼로그 외부 터치로 닫기 방지
      builder: (BuildContext context) {
        return WillPopScope(
          onWillPop: () async => false, // 뒤로가기 버튼 막기
          child: AlertDialog(
            title: Row(
              children: [
                Icon(
                  Icons.alarm,
                  color: Colors.red,
                  size: 28,
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                    color: Colors.red,
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.notifications_active,
                        size: 48,
                        color: Colors.red,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        message,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            actions: [
              Container(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onPressed,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                          alarmType == 'schedule' ? Icons.play_arrow : Icons.alarm_off,
                          size: 20
                      ),
                      const SizedBox(width: 8),
                      Text(
                        buttonText,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // 준비 시간을 설정하는 콜백 함수
  void setPrepTime(Duration newPrepTime) {
    setState(() {
      preparationTime = newPrepTime;
      remainingTime = newPrepTime;

      // 타이머가 실행 중이면 취소
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

  // 도착 시간을 설정하는 콜백 함수
  void setArrivalTime(String period, int hour, int minute, DateTime date) {
    setState(() {
      arrivalPeriod = period;
      arrivalHour = hour;
      arrivalMinute = minute;
      arrivalDate = date; // 날짜도 저장
    });
  }

  // 카운트다운 시작 (준비시간 카운트다운)
  void _startCountdown() {
    // 기존 타이머 취소
    countdownTimer?.cancel();

    // 새 타이머 시작
    setState(() {
      isCountdownActive = true;
      remainingTime = preparationTime; // 준비시간으로 리셋
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
            // 준비시간 완료 알람 시작
            _startAlarm('countdown');
          }
        });
      },
    );
  }

  // 카운트다운 중지
  void _stopCountdown() {
    setState(() {
      countdownTimer?.cancel();
      isCountdownActive = false;
    });
  }

  // 포맷팅된 시간 문자열 반환 (00:00:00 형식)
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String hours = twoDigits(duration.inHours);
    String minutes = twoDigits(duration.inMinutes.remainder(60));
    String seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$hours:$minutes:$seconds";
  }

  // 준비시간 표시 문자열 ("+HH:MM:SS" 형식)
  String _formatPrepTime() {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String hours = twoDigits(preparationTime.inHours);
    String minutes = twoDigits(preparationTime.inMinutes.remainder(60));
    String seconds = twoDigits(preparationTime.inSeconds.remainder(60));
    return "+$hours:$minutes:$seconds";
  }

  // 도착시간 표시 문자열 반환
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
    // DB 데이터 없으면 빈 문자열 반환
    return '';
  }

  // 알람예정시간 계산 및 표시 문자열 반환
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
    // DB 데이터 없으면 빈 문자열 반환
    return '';
  }

  void _goToShortestRoutePage() {
    // 저장된 경로 ID가 없으면 안내 메시지
    final routeId = RouteStore.selectedRouteId;
    if (routeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('먼저 경로를 저장해주세요')),
      );
      return;
    }
    // 서버에서 상세 경로 조회 및 상세 페이지로 이동
    RouteStore.fetchRouteDetailAndShow(context, routeId);
  }

  void _goToTimeSettingPage() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TimeSettingPage(
          onPrepTimeSet: setPrepTime,
          onArrivalTimeSet: setArrivalTime, // 도착시간 설정 콜백
          initialArrivalPeriod: arrivalPeriod,
          initialArrivalHour: arrivalHour,
          initialArrivalMinute: arrivalMinute,
          initialPrepTime: preparationTime,
        ),
      ),
    );
  }

  // 캘린더 페이지로 이동
  void _goToCalendarPage() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CalendarPage()),
    ).then((_) {
      // 캘린더 페이지에서 돌아왔을 때 UI 갱신
      setState(() {});
    });
  }

  // 현재 날짜의 요일을 가져오는 함수
  String _getWeekdayString(int weekday) {
    const weekdays = ['월', '화', '수', '목', '금', '토', '일'];
    return weekdays[weekday - 1]; // weekday는 1(월요일)부터 7(일요일)
  }

  @override
  Widget build(BuildContext context) {
    double verticalGap = 24;

    // 오늘 날짜 가져오기
    final today = DateTime.now();
    final formattedDate = '${today.month}/${today.day} ${_getWeekdayString(today.weekday)}요일';

    // 오늘의 Google Calendar 일정 가져오기
    final todayEvents = _todayGoogleEvents;

    return Scaffold(
      backgroundColor: const Color(0xFFF3EFEE),
      body: SafeArea(
        top: true,
        left: false,
        right: false,
        bottom: false,
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 검색창
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const SearchPage()),
                    );
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.black26, width: 1),
                    ),
                    child: AbsorbPointer(
                      child: TextField(
                        controller: searchController,
                        decoration: const InputDecoration(
                          hintText: '출발, 도착지 검색',
                          prefixIcon: Icon(Icons.search, color: Colors.black54),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 14),
                        ),
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: verticalGap),
                // 남은 준비 시간 카드 (통합된 버전) - 알람 상태 표시 추가
                GestureDetector(
                  onTap: _goToTimeSettingPage,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                    decoration: BoxDecoration(
                      color: isAlarmScheduleActive ? Colors.orange.withOpacity(0.1) : Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 2,
                          offset: Offset(0, 1),
                        ),
                      ],
                      // 알람 울림/예정 상태에 따른 테두리 색상
                      border: _isAlarmRinging
                          ? Border.all(color: Colors.red, width: 2)
                          : (isAlarmScheduleActive ? Border.all(color: Colors.orange, width: 2) : null),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              '남은 준비 시간',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.black87,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (_isAlarmRinging) ...[
                              const SizedBox(width: 8),
                              Icon(
                                Icons.alarm,
                                color: Colors.red,
                                size: 20,
                              ),
                            ],
                            if (!_isAlarmRinging && isAlarmScheduleActive) ...[
                              const SizedBox(width: 8),
                              Icon(
                                Icons.alarm,
                                color: Colors.orange,
                                size: 20,
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _formatDuration(remainingTime),
                          style: TextStyle(
                            fontSize: 40,
                            fontWeight: FontWeight.bold,
                            color: _isAlarmRinging ? Colors.red : Colors.black,
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _formatPrepTime(),
                              style: const TextStyle(
                                fontSize: 18,
                                color: Colors.green,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // 도착시간과 알람예정시간 정보
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            // 설정 도착시간
                            Column(
                              children: [
                                const Text(
                                  '설정 도착시간',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.black54,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _getArrivalTimeString(),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    color: Colors.blue,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            // 구분선
                            Container(
                              height: 40,
                              width: 1,
                              color: Colors.black12,
                            ),
                            // 알람예정시간
                            Column(
                              children: [
                                const Text(
                                  '알람예정시간',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.black54,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _getAlarmTimeString(),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    color: Colors.orange,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // 버튼 영역 - 알람 설정 후 바로 활성화된 상태 표시 (시작 버튼 제거)
                        if (isAlarmScheduleActive)
                          Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.access_time, color: Colors.blue, size: 16),
                                  const SizedBox(width: 4),
                                  const Text(
                                    '알람예정시간 대기 중...',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.blue,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              ElevatedButton(
                                onPressed: _stopAlarmSchedule,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  foregroundColor: Colors.white,
                                  minimumSize: Size(160, 36),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                ),
                                child: const Text(
                                  '알람 취소',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          )
                        else if (isCountdownActive)
                            Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.timer, color: Colors.green, size: 16),
                                    const SizedBox(width: 4),
                                    const Text(
                                      '준비시간 카운트다운 진행 중...',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.green,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                ElevatedButton(
                                  onPressed: _stopCountdown,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                    foregroundColor: Colors.white,
                                    minimumSize: Size(160, 36),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(18),
                                    ),
                                  ),
                                  child: const Text(
                                    '중지',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: verticalGap),
                // 즐겨찾기 아이콘 섹션 추가
                _buildFavoriteIcons(),
                SizedBox(height: verticalGap),
                // 다음 경로 박스 (기존 교통수단 아이콘들을 대체)
                GestureDetector(
                  onTap: _goToShortestRoutePage,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.black26, width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        // 왼쪽 아이콘 영역
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.directions,
                            size: 32,
                            color: Colors.blue,
                          ),
                        ),
                        const SizedBox(width: 16),
                        // 중앙 텍스트 영역
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '다음 경로',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                '최적의 경로를 확인하세요',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // 오른쪽 화살표 아이콘
                        Icon(
                          Icons.arrow_forward_ios,
                          size: 20,
                          color: Colors.black54,
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: verticalGap),
                // MM/DD 요일 + 오늘 일정 요약 카드
                GestureDetector(
                  onTap: _goToCalendarPage, // 캘린더 페이지로 이동
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.black12, width: 1),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              formattedDate,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                            const Icon(
                              Icons.calendar_today,
                              color: Colors.blue,
                              size: 22,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Divider(height: 1, color: Colors.black12),
                        const SizedBox(height: 12),
                        const Text(
                          '오늘 일정',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                            color: Colors.black87,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        if (todayEvents.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12.0),
                            child: Text(
                              '오늘 예정된 일정이 없습니다',
                              style: TextStyle(
                                fontSize: 15,
                                color: Colors.black54,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          )
                        else
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: todayEvents.length > 3 ? 3 : todayEvents.length,
                            itemBuilder: (context, index) {
                              final evt = todayEvents[index];
                              final title = evt.summary ?? '제목 없음';
                              final dt = evt.start?.dateTime?.toLocal();
                              final timeStr = dt != null ? DateFormat('HH:mm').format(dt) : '';
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4.0),
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.blue.shade200),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.event, color: Colors.blue, size: 16),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          title,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                            color: Colors.black87,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (timeStr.isNotEmpty)
                                        Text(timeStr, style: const TextStyle(fontSize: 12, color: Colors.black54)),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 즐겨찾기 아이콘 섹션
  Widget _buildFavoriteIcons() {
    return _buildAllFavorites();
  }
  
  // 통합된 즐겨찾기 섹션
  Widget _buildAllFavorites() {
    // 모든 즐겨찾기를 가져옵니다 (최대 4개)
    final displayFavorites = _favoriteService.getTopFavorites();
    
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '즐겨찾는 장소',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const FavoriteManagementPage(),
                    ),
                  ).then((_) => _favoriteService.loadData());
                },
                child: Text(
                  '관리',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.blue[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          displayFavorites.isEmpty
            ? Center(
                child: Column(
                  children: [
                    _buildEmptyFavoriteIcon(isDeparture: false),
                    const SizedBox(height: 8),
                    Text(
                      '즐겨찾는 장소가 없습니다',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              )
            : Wrap(
                spacing: 16.0, // 가로 간격
                runSpacing: 16.0, // 세로 간격
                alignment: WrapAlignment.start,
                children: [
                  ...displayFavorites.map((f) => _buildFavoriteIcon(f, isDeparture: f.isDeparture)),
                ],
              ),
        ],
      ),
    );
  }

  // 즐겨찾기 경로 아이콘
  Widget _buildFavoriteIcon(FavoriteRouteModel favorite, {bool isDeparture = false}) {
    final iconData = _getFavoriteIconData(favorite.iconName.isNotEmpty ? favorite.iconName : favorite.category);
    final iconColor = _getFavoriteIconColor(favorite.iconName.isNotEmpty ? favorite.iconName : favorite.category);
    
    // 표시할 장소 이름 결정
    String placeName = '';
    if (isDeparture) {
      placeName = favorite.origin;
    } else {
      placeName = favorite.destination;
    }
    
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SearchPage(
              initialDeparture: isDeparture ? favorite.origin : null,
              initialDepartureAddress: isDeparture ? favorite.originAddress : null,
              initialDestination: !isDeparture ? favorite.destination : null,
              initialDestinationAddress: !isDeparture ? favorite.destinationAddress : null,
            ),
          ),
        );
      },
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: iconColor,
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: iconColor.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(
                    iconData,
                    color: Colors.white,
                    size: 28,
                  ),
                  if (isDeparture)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.departure_board,
                          color: iconColor,
                          size: 12,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            placeName,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // 빈 즐겨찾기 아이콘
  Widget _buildEmptyFavoriteIcon({bool isDeparture = false}) {
    return GestureDetector(
      onTap: () {
        // 즐겨찾기 추가 페이지로 이동
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const FavoriteManagementPage(),
          ),
        ).then((_) => _favoriteService.loadData());
      },
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: Colors.grey[400]!,
                width: 2,
                style: BorderStyle.solid,
              ),
            ),
            child: Icon(
              Icons.add,
              color: Colors.grey[600],
              size: 28,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '장소 추가',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  // 즐겨찾기 아이콘 데이터
  IconData _getFavoriteIconData(String iconName) {
    switch (iconName) {
      case 'home': return Icons.home;
      case 'work': return Icons.work;
      case 'school': return Icons.school;
      case 'restaurant': return Icons.restaurant;
      case 'shopping': return Icons.shopping_cart;
      case 'hospital': return Icons.local_hospital;
      case 'gas_station': return Icons.local_gas_station;
      default: return Icons.place;
    }
  }

  // 즐겨찾기 아이콘 색상
  Color _getFavoriteIconColor(String iconName) {
    switch (iconName) {
      case 'home': return Colors.green;
      case 'work': return Colors.blue;
      case 'school': return Colors.orange;
      case 'restaurant': return Colors.red;
      case 'shopping': return Colors.purple;
      case 'hospital': return Colors.pink;
      case 'gas_station': return Colors.brown;
      default: return Colors.grey;
    }
  }

  // 즐겨찾기 카테고리 레이블 (한글)
  String _getCategoryLabel(String category) {
    switch (category) {
      case 'general': return '일반';
      case 'home': return '집';
      case 'work': return '직장';
      case 'school': return '학교';
      case 'restaurant': return '식당';
      case 'shopping': return '쇼핑';
      case 'hospital': return '병원';
      case 'gas_station': return '주유소';
      default: return category;
    }
  }

  // 교통수단 아이콘 위젯 빌더
  Widget _buildSelectIcon({
    required IconData icon,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 90,
        height: 90,
        decoration: BoxDecoration(
          color: selected ? Colors.blue.shade100 : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? Colors.blue : Colors.black26,
            width: selected ? 2 : 1,
          ),
          boxShadow: selected
              ? [
            BoxShadow(
              color: Colors.blue.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ]
              : [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 32,
              color: selected ? Colors.blue : Colors.black54,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: selected ? Colors.blue : Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 오늘 Google Calendar 이벤트 로드
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
        maxResults: 10,
      );
      setState(() {
        _todayGoogleEvents = events;
      });
    } catch (e) {
      print('오늘 구글 캘린더 이벤트 로드 실패: $e');
    }
  }
}