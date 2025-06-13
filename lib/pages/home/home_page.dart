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
import '../my/favorite_places_page.dart';
import '../../services/alarm_api_service.dart';
import '../../models/route_response.dart';
import '../../models/favorite_route_model.dart';
import '../assistant/assistant_page.dart';

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
  late final AlarmApiService _alarmApiService;
  String? _googleId;

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

  // 알람 등록 시 홈 알람 위젯 갱신 콜백
  VoidCallback? globalAlarmRefreshCallback;

  @override
  void initState() {
    super.initState();
    _initializeAlarm();
    _requestPermissions();

    // EventService 리스너 등록
    _eventService.addListener(_refreshState);
    _favoriteService.loadData();
    _favoriteService.addListener(_refreshState);
    _initAlarmApiService();

    // 알람 등록 시 홈 알람 위젯 갱신 콜백 등록
    globalAlarmRefreshCallback = () async {
      // 서버 알람 재조회 및 상태 갱신
      await _loadAlarms();
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
      if (alarms.isNotEmpty) {
        // 가장 빠른 알람을 선택
        alarms.sort((a, b) => DateTime.parse(a['wakeUpTime']).compareTo(DateTime.parse(b['wakeUpTime'])));
        final alarm = alarms.first;
        final arrivalTime = DateTime.parse(alarm['arrivalTime']);
        final prepMinutes = alarm['preparationTime'] as int;
        setState(() {
          // 도착 시간 설정
          final hour24 = arrivalTime.hour;
          arrivalPeriod = hour24 >= 12 ? '오후' : '오전';
          arrivalHour = hour24 % 12 == 0 ? 12 : hour24 % 12;
          arrivalMinute = arrivalTime.minute;
          // 준비 시간 및 남은 시간
          preparationTime = Duration(minutes: prepMinutes);
          remainingTime = preparationTime;
          isAlarmScheduleActive = true;
        });
        // 타이머 실행(내부 로직 재사용)
        alarmCheckTimer?.cancel();
        alarmCheckTimer = Timer.periodic(
          const Duration(seconds: 1),
          (timer) {
            final now = DateTime.now();
            final wakeUpTime = DateTime.parse(alarm['wakeUpTime']);
            if (now.isAfter(wakeUpTime) || now.isAtSameMomentAs(wakeUpTime)) {
              timer.cancel();
              setState(() { isAlarmScheduleActive = false; });
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
    // 의존성이 변경될 때마다 상태를 갱신
    setState(() {});
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
    // 콜백 해제
    globalAlarmRefreshCallback = null;
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
  void _stopAlarmSchedule() {
    setState(() {
      alarmCheckTimer?.cancel();
      isAlarmScheduleActive = false;
    });
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
    String hourStr = arrivalHour.toString().padLeft(2, '0');
    String minuteStr = arrivalMinute.toString().padLeft(2, '0');
    return "$arrivalPeriod $hourStr:$minuteStr";
  }

  // 알람예정시간 계산 및 표시 문자열 반환
  String _getAlarmTimeString() {
    DateTime alarmTime = _getAlarmDateTime();

    String period = alarmTime.hour < 12 ? '오전' : '오후';
    int displayHour = alarmTime.hour;
    if (displayHour == 0) {
      displayHour = 12;
    } else if (displayHour > 12) {
      displayHour -= 12;
    }

    String hourStr = displayHour.toString().padLeft(2, '0');
    String minuteStr = alarmTime.minute.toString().padLeft(2, '0');

    return "$period $hourStr:$minuteStr";
  }

  void _goToShortestRoutePage() {
    // 선택된 경로가 없으면 안내 메시지
    if (RouteStore.selectedOption == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('먼저 경로를 선택해주세요')),
      );
      return;
    }
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

    // 오늘의 일정 가져오기
    final todayEvents = _eventService.getEvents(today);
    
    // 상위 3개 즐겨찾기 가져오기 (메인 페이지용)
    final List<FavoriteRouteModel> topFavorites = _favoriteService.getTopFavorites();

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
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 2,
                          offset: Offset(0, 1),
                        ),
                      ],
                      // 알람이 울릴 때 테두리 색상 변경
                      border: _isAlarmRinging
                          ? Border.all(color: Colors.red, width: 2)
                          : null,
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
                        // 버튼 영역 - 상태에 따라 다른 버튼 표시
                        if (!isAlarmScheduleActive && !isCountdownActive)
                          ElevatedButton(
                            onPressed: _startAlarmSchedule,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              minimumSize: Size(160, 36),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                            child: const Text(
                              '알람 시작',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          )
                        else if (isAlarmScheduleActive)
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
                _buildFavoriteIcons(topFavorites),
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
                            itemCount: todayEvents.length > 3 ? 3 : todayEvents.length, // 최대 3개만 표시
                            itemBuilder: (context, index) {
                              final event = todayEvents[index]; // 이벤트 객체를 미리 가져오기
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
                                      Icon(
                                        Icons.event,
                                        color: Colors.blue,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          event.title ?? event.content ?? '제목 없음', // title이 있으면 title, 없으면 content 사용
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                            color: Colors.black87,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (event.time != null && event.time!.isNotEmpty) // time 속성 사용
                                        Text(
                                          event.time!,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.black54,
                                          ),
                                        ),
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

  // 즐겨찾기 아이콘 위젯
  Widget _buildFavoriteIcons(List<FavoriteRouteModel> favorites) {
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
                '즐겨찾는 경로',
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
                      builder: (context) => const FavoritePlacesPage(),
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
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
            children: favorites.isEmpty
                  ? [ _buildEmptyFavoriteIcon() ]
                : [
                      ...favorites.map((f) => Padding(
                        padding: const EdgeInsets.only(right: 16.0),
                        child: _buildFavoriteIcon(f),
                      )),
                      _buildEmptyFavoriteIcon(),
                  ],
            ),
          ),
        ],
      ),
    );
  }

  // 즐겨찾기 경로 아이콘
  Widget _buildFavoriteIcon(FavoriteRouteModel favorite) {
    final iconData = _getFavoriteIconData(favorite.category);
    final iconColor = _getFavoriteIconColor(favorite.category);
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SearchPage(
              initialDestination: favorite.destination,
              initialDestinationAddress: favorite.destination,
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
            child: Icon(
                iconData,
              color: Colors.white,
              size: 28,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _getCategoryLabel(favorite.category),
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
  Widget _buildEmptyFavoriteIcon() {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const FavoritePlacesPage(),
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
            '추가',
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
}