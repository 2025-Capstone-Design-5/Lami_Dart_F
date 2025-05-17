import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'shortest_route_page.dart';
import 'time_setting_page.dart';
import 'arrivemappage.dart';
import 'dart:async';
import 'event_service.dart'; // EventService 불러오기
import 'calendar_page.dart'; // CalendarPage 불러오기

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int selectedIconIndex = 0;
  TextEditingController searchController = TextEditingController();

  // 이벤트 서비스 인스턴스
  final EventService _eventService = EventService();

  // 준비 시간 관련 변수
  Duration preparationTime = const Duration(minutes: 30); // 기본값 30분
  Duration remainingTime = const Duration(minutes: 30); // 남은 시간 (초기값 30분)
  Timer? countdownTimer;
  String arrivalPeriod = '오전';
  int arrivalHour = 8;
  int arrivalMinute = 0;
  bool isCountdownActive = false;

  @override
  void initState() {
    super.initState();
    // 필요한 초기화 작업이 있으면 여기에 추가

    // EventService 리스너 등록
    _eventService.addListener(_refreshState);
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
    countdownTimer?.cancel();
    super.dispose();
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
    });
  }

  // 카운트다운 시작
  void _startCountdown() {
    // 기존 타이머 취소
    countdownTimer?.cancel();

    // 새 타이머 시작
    setState(() {
      isCountdownActive = true;
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
            // 카운트다운 완료 알림 표시
            _showCompletionAlert();
          }
        });
      },
    );
  }

  // 준비시간 완료 알림 표시
  void _showCompletionAlert() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text(
            '준비시간 완료',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
            textAlign: TextAlign.center,
          ),
          content: const Text(
            '설정한 준비시간이 완료되었습니다.',
            style: TextStyle(fontSize: 16),
            textAlign: TextAlign.center,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text(
                '확인',
                style: TextStyle(
                  color: Colors.blue,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
          actionsAlignment: MainAxisAlignment.center,
        );
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

  void _goToShortestRoutePage() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ShortestRoutePage()),
    );
  }

  void _goToTimeSettingPage() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TimeSettingPage(
          onPrepTimeSet: setPrepTime,
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

    return Scaffold(
      backgroundColor: const Color(0xFFF3EFEE),
      body: SingleChildScrollView(
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
                    MaterialPageRoute(builder: (context) => const ArriveMapPage()),
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
              // 남은 준비 시간 카드
              GestureDetector(
                onTap: _goToTimeSettingPage,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 12),
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
                  ),
                  child: Column(
                    children: [
                      const Text(
                        '남은 준비 시간',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.black87,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _formatDuration(remainingTime),
                        style: const TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
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
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: isCountdownActive ? _stopCountdown : _startCountdown,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isCountdownActive ? Colors.red : Colors.green,
                          foregroundColor: Colors.white,
                          minimumSize: Size(160, 36),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        child: Text(
                          isCountdownActive ? '중지' : '카운트다운 시작',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: verticalGap),
              // 교통수단 아이콘 3개
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildSelectIcon(
                    icon: Icons.train,
                    label: '지하철',
                    selected: selectedIconIndex == 0,
                    onTap: () {
                      setState(() => selectedIconIndex = 0);
                      _goToShortestRoutePage();
                    },
                  ),
                  _buildSelectIcon(
                    icon: Icons.directions_bus,
                    label: '버스',
                    selected: selectedIconIndex == 1,
                    onTap: () {
                      setState(() => selectedIconIndex = 1);
                      _goToShortestRoutePage();
                    },
                  ),
                  _buildSelectIcon(
                    icon: Icons.directions_car,
                    label: '승용차',
                    selected: selectedIconIndex == 2,
                    onTap: () {
                      setState(() => selectedIconIndex = 2);
                      _goToShortestRoutePage();
                    },
                  ),
                ],
              ),
              SizedBox(height: verticalGap),
              // MM/DD 요일 + 오늘 일정 요약 카드 (수정된 부분)
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
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4.0),
                              child: Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                      color: Colors.green,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      todayEvents[index].content,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        color: Colors.black87,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      if (todayEvents.length > 3)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            '외 ${todayEvents.length - 3}개 일정이 더 있습니다',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.blue,
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      const SizedBox(height: 8),
                      const Text(
                        '일정 관리는 캘린더 탭에서',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.black54,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: verticalGap),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSelectIcon({
    required IconData icon,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Icon(
            icon,
            size: 38,
            color: selected ? Colors.blue : Colors.grey.withOpacity(0.3),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: selected ? Colors.blue : Colors.grey.withOpacity(0.3),
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}