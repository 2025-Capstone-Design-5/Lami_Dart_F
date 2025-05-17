import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class TimeSettingPage extends StatefulWidget {
  final Function(Duration)? onPrepTimeSet;
  final String? initialArrivalPeriod;
  final int? initialArrivalHour;
  final int? initialArrivalMinute;
  final Duration? initialPrepTime;

  const TimeSettingPage({
    Key? key,
    this.onPrepTimeSet,
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
  late int prepSecond; // 초 추가

  final List<String> periodList = ['오전', '오후'];
  final List<int> hourList = List.generate(12, (i) => i + 1);
  final List<int> minuteList = List.generate(60, (i) => i);
  final List<int> secondList = List.generate(60, (i) => i); // 초 리스트 추가

  // 준비 시간용 24시간 형식 시간 리스트
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
  }

  // 백엔드 서버에 도착시간 데이터 전송
  Future<void> _sendArrivalTimeToServer() async {
    try {
      // 24시간 형식으로 변환
      int hour24 = arrivalHour;
      if (arrivalPeriod == '오후' && arrivalHour < 12) {
        hour24 += 12;
      } else if (arrivalPeriod == '오전' && arrivalHour == 12) {
        hour24 = 0;
      }

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
      } else {
        print('서버 요청 실패: ${response.statusCode}');
      }
    } catch (e) {
      print('서버 통신 에러: $e');
    }
  }

  // 준비시간을 Duration으로 변환
  Duration _calculatePrepTime() {
    return Duration(
      hours: prepHour,
      minutes: prepMinute,
      seconds: prepSecond,
    );
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
            // 도착시간설정 카드
            _arrivalTimeCard(
              title: '도착시간설정',
              period: arrivalPeriod,
              hour: arrivalHour,
              minute: arrivalMinute,
              onPeriodChanged: (val) => setState(() => arrivalPeriod = val),
              onHourChanged: (val) => setState(() => arrivalHour = val),
              onMinuteChanged: (val) => setState(() => arrivalMinute = val),
            ),
            const SizedBox(height: 24),
            // 준비시간설정 카드 (24시간 형식)
            _prepTimeCard(
              title: '준비시간설정',
              hour: prepHour,
              minute: prepMinute,
              second: prepSecond,
              onHourChanged: (val) => setState(() => prepHour = val),
              onMinuteChanged: (val) => setState(() => prepMinute = val),
              onSecondChanged: (val) => setState(() => prepSecond = val),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  // 도착시간 서버로 전송
                  await _sendArrivalTimeToServer();

                  // 준비시간 계산 및 홈페이지로 전달
                  if (widget.onPrepTimeSet != null) {
                    widget.onPrepTimeSet!(_calculatePrepTime());
                  }

                  Navigator.pop(context);
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
                  style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
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
              // 시간 선택기들을 위한 컨테이너 (가로 정렬)
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // 오전/오후 피커
                    Column(
                      children: [
                        SizedBox(
                          width: 70,
                          height: 120,
                          child: ListWheelScrollView.useDelegate(
                            itemExtent: 36,
                            diameterRatio: 1.2,
                            physics: const FixedExtentScrollPhysics(),
                            onSelectedItemChanged: (index) => onPeriodChanged(periodList[index]),
                            childDelegate: ListWheelChildBuilderDelegate(
                              builder: (context, index) {
                                if (index < 0 || index >= periodList.length) return null;
                                return Center(
                                  child: Text(
                                    periodList[index],
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: period == periodList[index] ? FontWeight.bold : FontWeight.normal,
                                      color: period == periodList[index] ? const Color(0xFF334066) : Colors.black54,
                                    ),
                                  ),
                                );
                              },
                              childCount: periodList.length,
                            ),
                            controller: FixedExtentScrollController(
                              initialItem: periodList.indexOf(period),
                            ),
                          ),
                        ),
                        const Text(
                          ' ',
                          style: TextStyle(fontSize: 14, color: Colors.black38),
                        ),
                      ],
                    ),
                    const SizedBox(width: 24),
                    // 시 피커
                    Column(
                      children: [
                        SizedBox(
                          width: 70,
                          height: 120,
                          child: ListWheelScrollView.useDelegate(
                            itemExtent: 36,
                            diameterRatio: 1.2,
                            physics: const FixedExtentScrollPhysics(),
                            onSelectedItemChanged: (index) => onHourChanged(hourList[index]),
                            childDelegate: ListWheelChildBuilderDelegate(
                              builder: (context, index) {
                                if (index < 0 || index >= hourList.length) return null;
                                return Center(
                                  child: Text(
                                    '${hourList[index].toString().padLeft(2, '0')}',
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: hour == hourList[index] ? FontWeight.bold : FontWeight.normal,
                                      color: hour == hourList[index] ? const Color(0xFF334066) : Colors.black54,
                                    ),
                                  ),
                                );
                              },
                              childCount: hourList.length,
                            ),
                            controller: FixedExtentScrollController(
                              initialItem: hourList.indexOf(hour),
                            ),
                          ),
                        ),
                        const Text(
                          '시',
                          style: TextStyle(fontSize: 14, color: Colors.black38),
                        ),
                      ],
                    ),
                    const SizedBox(width: 16),
                    // 분 피커
                    Column(
                      children: [
                        SizedBox(
                          width: 70,
                          height: 120,
                          child: ListWheelScrollView.useDelegate(
                            itemExtent: 36,
                            diameterRatio: 1.2,
                            physics: const FixedExtentScrollPhysics(),
                            onSelectedItemChanged: (index) => onMinuteChanged(minuteList[index]),
                            childDelegate: ListWheelChildBuilderDelegate(
                              builder: (context, index) {
                                if (index < 0 || index >= minuteList.length) return null;
                                return Center(
                                  child: Text(
                                    '${minuteList[index].toString().padLeft(2, '0')}',
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: minute == minuteList[index] ? FontWeight.bold : FontWeight.normal,
                                      color: minute == minuteList[index] ? const Color(0xFF334066) : Colors.black54,
                                    ),
                                  ),
                                );
                              },
                              childCount: minuteList.length,
                            ),
                            controller: FixedExtentScrollController(
                              initialItem: minuteList.indexOf(minute),
                            ),
                          ),
                        ),
                        const Text(
                          '분',
                          style: TextStyle(fontSize: 14, color: Colors.black38),
                        ),
                      ],
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

  // 준비시간 카드 (오전/오후 없이 24시간 형식 + 초 추가)
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
              // 시간 선택기들을 위한 컨테이너 (가로 정렬)
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // 시간 피커 (24시간 형식)
                    Column(
                      children: [
                        SizedBox(
                          width: 70,
                          height: 120,
                          child: ListWheelScrollView.useDelegate(
                            itemExtent: 36,
                            diameterRatio: 1.2,
                            physics: const FixedExtentScrollPhysics(),
                            onSelectedItemChanged: (index) => onHourChanged(hourList24[index]),
                            childDelegate: ListWheelChildBuilderDelegate(
                              builder: (context, index) {
                                if (index < 0 || index >= hourList24.length) return null;
                                return Center(
                                  child: Text(
                                    '${hourList24[index].toString().padLeft(2, '0')}',
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: hour == hourList24[index] ? FontWeight.bold : FontWeight.normal,
                                      color: hour == hourList24[index] ? const Color(0xFF334066) : Colors.black54,
                                    ),
                                  ),
                                );
                              },
                              childCount: hourList24.length,
                            ),
                            controller: FixedExtentScrollController(
                              initialItem: hourList24.indexOf(hour),
                            ),
                          ),
                        ),
                        const Text(
                          '시',
                          style: TextStyle(fontSize: 14, color: Colors.black38),
                        ),
                      ],
                    ),
                    const SizedBox(width: 16),
                    // 분 피커
                    Column(
                      children: [
                        SizedBox(
                          width: 70,
                          height: 120,
                          child: ListWheelScrollView.useDelegate(
                            itemExtent: 36,
                            diameterRatio: 1.2,
                            physics: const FixedExtentScrollPhysics(),
                            onSelectedItemChanged: (index) => onMinuteChanged(minuteList[index]),
                            childDelegate: ListWheelChildBuilderDelegate(
                              builder: (context, index) {
                                if (index < 0 || index >= minuteList.length) return null;
                                return Center(
                                  child: Text(
                                    '${minuteList[index].toString().padLeft(2, '0')}',
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: minute == minuteList[index] ? FontWeight.bold : FontWeight.normal,
                                      color: minute == minuteList[index] ? const Color(0xFF334066) : Colors.black54,
                                    ),
                                  ),
                                );
                              },
                              childCount: minuteList.length,
                            ),
                            controller: FixedExtentScrollController(
                              initialItem: minuteList.indexOf(minute),
                            ),
                          ),
                        ),
                        const Text(
                          '분',
                          style: TextStyle(fontSize: 14, color: Colors.black38),
                        ),
                      ],
                    ),
                    const SizedBox(width: 16),
                    // 초 피커
                    Column(
                      children: [
                        SizedBox(
                          width: 70,
                          height: 120,
                          child: ListWheelScrollView.useDelegate(
                            itemExtent: 36,
                            diameterRatio: 1.2,
                            physics: const FixedExtentScrollPhysics(),
                            onSelectedItemChanged: (index) => onSecondChanged(secondList[index]),
                            childDelegate: ListWheelChildBuilderDelegate(
                              builder: (context, index) {
                                if (index < 0 || index >= secondList.length) return null;
                                return Center(
                                  child: Text(
                                    '${secondList[index].toString().padLeft(2, '0')}',
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: second == secondList[index] ? FontWeight.bold : FontWeight.normal,
                                      color: second == secondList[index] ? const Color(0xFF334066) : Colors.black54,
                                    ),
                                  ),
                                );
                              },
                              childCount: secondList.length,
                            ),
                            controller: FixedExtentScrollController(
                              initialItem: secondList.indexOf(second),
                            ),
                          ),
                        ),
                        const Text(
                          '초',
                          style: TextStyle(fontSize: 14, color: Colors.black38),
                        ),
                      ],
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
}