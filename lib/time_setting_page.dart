import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class TimeSettingPage extends StatefulWidget {
  final Function(Duration)? onPrepTimeSet;
  final Function(String, int, int)? onArrivalTimeSet;
  final String? initialArrivalPeriod;
  final int? initialArrivalHour;
  final int? initialArrivalMinute;
  final Duration? initialPrepTime;

  const TimeSettingPage({
    Key? key,
    this.onPrepTimeSet,
    this.onArrivalTimeSet,
    this.initialArrivalPeriod,
    this.initialArrivalHour,
    this.initialArrivalMinute,
    this.initialPrepTime,
  }) : super(key: key);

  @override
  State<TimeSettingPage> createState() => _TimeSettingPageState();
}

class _TimeSettingPageState extends State<TimeSettingPage> {
  // 도착 시간
  late String arrivalPeriod;
  late int arrivalHour;
  late int arrivalMinute;

  // 준비 시간 (24시간 형식)
  late int prepHour;
  late int prepMinute;
  late int prepSecond;

  // 이동 소요시간 및 알람예정시간
  Duration? travelTime;
  DateTime? alarmTime;
  bool isLoadingTravelTime = false;

  final List<String> periodList = ['오전', '오후'];
  final List<int> hourList = List.generate(12, (i) => i + 1);
  final List<int> minuteList = List.generate(60, (i) => i);
  final List<int> secondList = List.generate(60, (i) => i);
  final List<int> hourList24 = List.generate(24, (i) => i);

  @override
  void initState() {
    super.initState();
    // 도착시간 초기값 설정
    arrivalPeriod = widget.initialArrivalPeriod ?? '오전';
    arrivalHour = widget.initialArrivalHour ?? 8;
    arrivalMinute = widget.initialArrivalMinute ?? 0;

    // 준비시간 초기값 설정 (24시간 형식)
    if (widget.initialPrepTime != null) {
      int totalSeconds = widget.initialPrepTime!.inSeconds;
      prepHour = totalSeconds ~/ 3600;
      prepMinute = (totalSeconds % 3600) ~/ 60;
      prepSecond = totalSeconds % 60;
    } else {
      prepHour = 0;
      prepMinute = 30;
      prepSecond = 0;
    }

    // 초기 로드 시 이동소요시간 가져오기
    _fetchTravelTime();
  }

  // 백엔드에서 이동소요시간 가져오기
  Future<void> _fetchTravelTime() async {
    setState(() {
      isLoadingTravelTime = true;
    });

    try {
      final response = await http.get(
        Uri.parse('https://your-backend-server.com/api/travel-time'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // 백엔드에서 분 단위로 받는다고 가정
        int travelMinutes = data['travelTimeMinutes'] ?? 30;

        setState(() {
          travelTime = Duration(minutes: travelMinutes);
          _calculateAlarmTime();
          isLoadingTravelTime = false;
        });
      } else {
        // 기본값 설정 (30분)
        setState(() {
          travelTime = const Duration(minutes: 30);
          _calculateAlarmTime();
          isLoadingTravelTime = false;
        });
        print('이동소요시간 조회 실패: ${response.statusCode}');
      }
    } catch (e) {
      // 기본값 설정 (30분)
      setState(() {
        travelTime = const Duration(minutes: 30);
        _calculateAlarmTime();
        isLoadingTravelTime = false;
      });
      print('이동소요시간 조회 에러: $e');
    }
  }

  // 알람예정시간 계산
  void _calculateAlarmTime() {
    if (travelTime == null) return;

    // 도착시간을 DateTime으로 변환 (오늘 날짜 기준)
    DateTime today = DateTime.now();
    int hour24 = _convertTo24Hour(arrivalPeriod, arrivalHour);
    DateTime arrivalDateTime = DateTime(
      today.year,
      today.month,
      today.day,
      hour24,
      arrivalMinute,
    );

    // 준비시간 계산
    Duration prepTime = _calculatePrepTime();

    // 알람예정시간 = 도착시간 - (준비시간 + 이동소요시간)
    setState(() {
      alarmTime = arrivalDateTime.subtract(prepTime + travelTime!);
    });
  }

  // 시간 변경 시 알람시간 재계산
  void _onTimeChanged() {
    _calculateAlarmTime();
  }

  // 백엔드 서버에 도착시간 데이터 전송
  Future<void> _sendArrivalTimeToServer() async {
    try {
      int hour24 = _convertTo24Hour(arrivalPeriod, arrivalHour);

      final response = await http.post(
        Uri.parse('https://your-backend-server.com/api/arrival-time'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode(<String, dynamic>{
          'hour': hour24,
          'minute': arrivalMinute,
        }),
      );

      if (response.statusCode == 200) {
        print('도착시간이 성공적으로 서버에 전송되었습니다.');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('도착시간이 성공적으로 저장되었습니다.'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        print('서버 요청 실패: ${response.statusCode}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('서버 저장에 실패했습니다.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      print('서버 통신 에러: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('네트워크 오류가 발생했습니다.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // 12시간 형식을 24시간 형식으로 변환하는 헬퍼 함수
  int _convertTo24Hour(String period, int hour) {
    if (period == '오후' && hour < 12) {
      return hour + 12;
    } else if (period == '오전' && hour == 12) {
      return 0;
    }
    return hour;
  }

  // 준비시간을 Duration으로 변환
  Duration _calculatePrepTime() {
    return Duration(
      hours: prepHour,
      minutes: prepMinute,
      seconds: prepSecond,
    );
  }

  // 설정 유효성 검사
  bool _validateSettings() {
    // 준비시간이 0인지 확인
    if (prepHour == 0 && prepMinute == 0 && prepSecond == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('준비시간은 0보다 커야 합니다.'),
          backgroundColor: Colors.orange,
        ),
      );
      return false;
    }

    // 알람시간이 현재 시간보다 이전인지 확인
    if (alarmTime != null && alarmTime!.isBefore(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('알람시간이 현재 시간보다 이전입니다. 시간을 조정해주세요.'),
          backgroundColor: Colors.orange,
        ),
      );
      return false;
    }

    return true;
  }

  // 시간을 AM/PM 형식으로 포맷팅
  String _formatTime(DateTime dateTime) {
    int hour = dateTime.hour;
    int minute = dateTime.minute;
    String period = hour >= 12 ? '오후' : '오전';
    int displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);

    return '$period ${displayHour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3EFEE),
      appBar: AppBar(
        title: const Text('시간설정'),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0.5,
        titleTextStyle: const TextStyle(
          color: Color(0xFF334066),
          fontWeight: FontWeight.w700,
          fontSize: 20,
        ),
        iconTheme: const IconThemeData(color: Color(0xFF334066)),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          children: [
            // 알람예정시간 표시 카드
            _alarmTimeCard(),
            const SizedBox(height: 16),
            // 도착시간설정 카드
            _arrivalTimeCard(
              title: '도착시간설정',
              period: arrivalPeriod,
              hour: arrivalHour,
              minute: arrivalMinute,
              onPeriodChanged: (val) {
                setState(() => arrivalPeriod = val);
                _onTimeChanged();
              },
              onHourChanged: (val) {
                setState(() => arrivalHour = val);
                _onTimeChanged();
              },
              onMinuteChanged: (val) {
                setState(() => arrivalMinute = val);
                _onTimeChanged();
              },
            ),
            const SizedBox(height: 16),
            // 준비시간설정 카드 (24시간 형식)
            _prepTimeCard(
              title: '준비시간설정',
              hour: prepHour,
              minute: prepMinute,
              second: prepSecond,
              onHourChanged: (val) {
                setState(() => prepHour = val);
                _onTimeChanged();
              },
              onMinuteChanged: (val) {
                setState(() => prepMinute = val);
                _onTimeChanged();
              },
              onSecondChanged: (val) {
                setState(() => prepSecond = val);
                _onTimeChanged();
              },
            ),
            const Spacer(),
            // 설정 완료 버튼
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  // 유효성 검사
                  if (!_validateSettings()) {
                    return;
                  }

                  // 로딩 인디케이터 표시
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (BuildContext context) {
                      return const Center(
                        child: CircularProgressIndicator(),
                      );
                    },
                  );

                  try {
                    // 도착시간 서버로 전송
                    await _sendArrivalTimeToServer();

                    // 준비시간 계산 및 홈페이지로 전달
                    if (widget.onPrepTimeSet != null) {
                      widget.onPrepTimeSet!(_calculatePrepTime());
                    }

                    // 도착시간도 홈페이지로 전달
                    if (widget.onArrivalTimeSet != null) {
                      widget.onArrivalTimeSet!(arrivalPeriod, arrivalHour, arrivalMinute);
                    }

                    // 로딩 인디케이터 제거
                    if (mounted) {
                      Navigator.of(context).pop();
                      // 페이지 종료
                      Navigator.pop(context);
                    }
                  } catch (e) {
                    // 오류 발생 시 로딩 인디케이터 제거
                    if (mounted) {
                      Navigator.of(context).pop();
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF334066),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  elevation: 2,
                ),
                child: const Text(
                  '설정 완료',
                  style: TextStyle(
                      fontSize: 18,
                      color: Colors.white,
                      fontWeight: FontWeight.bold
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 알람예정시간 표시 카드
  Widget _alarmTimeCard() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4A90E2), Color(0xFF357ABD)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(
            Icons.alarm,
            color: Colors.white,
            size: 32,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '알람예정시간',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 4),
                if (isLoadingTravelTime)
                  const Row(
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                      SizedBox(width: 8),
                      Text(
                        '계산 중...',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  )
                else if (alarmTime != null)
                  Text(
                    _formatTime(alarmTime!),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  )
                else
                  const Text(
                    '계산 불가',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white70,
                    ),
                  ),
              ],
            ),
          ),
          if (travelTime != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text(
                  '이동시간',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white70,
                  ),
                ),
                Text(
                  '${travelTime!.inMinutes}분',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  // 도착시간 카드 (오전/오후 포함)
  Widget _arrivalTimeCard({
    required String title,
    required String period,
    required int hour,
    required int minute,
    required ValueChanged<String> onPeriodChanged,
    required ValueChanged<int> onHourChanged,
    required ValueChanged<int> onMinuteChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Color(0xFF334066),
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // 오전/오후 피커
                    _buildWheelPicker(
                      width: 70,
                      items: periodList,
                      selectedItem: period,
                      onChanged: onPeriodChanged,
                      label: ' ',
                    ),
                    const SizedBox(width: 24),
                    // 시 피커
                    _buildWheelPicker(
                      width: 70,
                      items: hourList.map((e) => e.toString().padLeft(2, '0')).toList(),
                      selectedItem: hour.toString().padLeft(2, '0'),
                      onChanged: (val) => onHourChanged(int.parse(val)),
                      label: '시',
                    ),
                    const SizedBox(width: 16),
                    // 분 피커
                    _buildWheelPicker(
                      width: 70,
                      items: minuteList.map((e) => e.toString().padLeft(2, '0')).toList(),
                      selectedItem: minute.toString().padLeft(2, '0'),
                      onChanged: (val) => onMinuteChanged(int.parse(val)),
                      label: '분',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 준비시간 카드 (24시간 형식 + 초 추가)
  Widget _prepTimeCard({
    required String title,
    required int hour,
    required int minute,
    required int second,
    required ValueChanged<int> onHourChanged,
    required ValueChanged<int> onMinuteChanged,
    required ValueChanged<int> onSecondChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Color(0xFF334066),
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // 시간 피커 (24시간 형식)
                    _buildWheelPicker(
                      width: 70,
                      items: hourList24.map((e) => e.toString().padLeft(2, '0')).toList(),
                      selectedItem: hour.toString().padLeft(2, '0'),
                      onChanged: (val) => onHourChanged(int.parse(val)),
                      label: '시',
                    ),
                    const SizedBox(width: 16),
                    // 분 피커
                    _buildWheelPicker(
                      width: 70,
                      items: minuteList.map((e) => e.toString().padLeft(2, '0')).toList(),
                      selectedItem: minute.toString().padLeft(2, '0'),
                      onChanged: (val) => onMinuteChanged(int.parse(val)),
                      label: '분',
                    ),
                    const SizedBox(width: 16),
                    // 초 피커
                    _buildWheelPicker(
                      width: 70,
                      items: secondList.map((e) => e.toString().padLeft(2, '0')).toList(),
                      selectedItem: second.toString().padLeft(2, '0'),
                      onChanged: (val) => onSecondChanged(int.parse(val)),
                      label: '초',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 공통 휠 피커 빌더
  Widget _buildWheelPicker({
    required double width,
    required List<String> items,
    required String selectedItem,
    required ValueChanged<String> onChanged,
    required String label,
  }) {
    return Column(
      children: [
        SizedBox(
          width: width,
          height: 120,
          child: ListWheelScrollView.useDelegate(
            itemExtent: 36,
            diameterRatio: 1.2,
            physics: const FixedExtentScrollPhysics(),
            onSelectedItemChanged: (index) => onChanged(items[index]),
            childDelegate: ListWheelChildBuilderDelegate(
              builder: (context, index) {
                if (index < 0 || index >= items.length) return null;
                return Center(
                  child: Text(
                    items[index],
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: selectedItem == items[index] ? FontWeight.bold : FontWeight.normal,
                      color: selectedItem == items[index] ? const Color(0xFF334066) : Colors.black54,
                    ),
                  ),
                );
              },
              childCount: items.length,
            ),
            controller: FixedExtentScrollController(
              initialItem: items.indexOf(selectedItem),
            ),
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 14, color: Colors.black38),
        ),
      ],
    );
  }
}