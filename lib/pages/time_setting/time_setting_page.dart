import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:ui';
import 'package:intl/intl.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../event_service.dart';
import '../../models/route_response.dart';
import '../../models/summary_response.dart';
import '../route/route_results_page.dart';
import '../../config/server_config.dart';
import '../../services/alarm_api_service.dart';

class TimeSettingPage extends StatefulWidget {
  final Function(Duration)? onPrepTimeSet;
  final Function(String, int, int, DateTime)? onArrivalTimeSet;
  final String? departureName;
  final String? departureAddress;
  final String? destinationName;
  final String? destinationAddress;
  final String? initialArrivalPeriod;
  final int? initialArrivalHour;
  final int? initialArrivalMinute;
  final DateTime? initialArrivalDate;
  final Duration? initialPrepTime;

  const TimeSettingPage({
    Key? key,
    this.departureName,
    this.departureAddress,
    this.destinationName,
    this.destinationAddress,
    this.onPrepTimeSet,
    this.onArrivalTimeSet,
    this.initialArrivalPeriod,
    this.initialArrivalHour,
    this.initialArrivalMinute,
    this.initialArrivalDate,
    this.initialPrepTime,
  }) : super(key: key);

  @override
  State<TimeSettingPage> createState() => _TimeSettingPageState();
}

class _TimeSettingPageState extends State<TimeSettingPage> {
  late String arrivalPeriod;
  late int arrivalHour;
  late int arrivalMinute;
  late DateTime arrivalDate;
  late String? departureName;
  late String? departureAddress;
  late String? destinationName;
  late String? destinationAddress;
  late int prepHour;
  late int prepMinute;
  late int prepSecond;
  DateTime? alarmTime;

  final EventService _eventService = EventService();

  final List<String> periodList = ['오전', '오후'];
  final List<int> hourList = List.generate(12, (i) => i + 1);
  final List<int> minuteList = List.generate(60, (i) => i);
  final List<int> secondList = List.generate(60, (i) => i);
  final List<int> hourList24 = List.generate(24, (i) => i);

  @override
  void initState() {
    super.initState();
    departureName = widget.departureName;
    departureAddress = widget.departureAddress;
    destinationName = widget.destinationName;
    destinationAddress = widget.destinationAddress;

    arrivalPeriod = widget.initialArrivalPeriod ?? '오전';
    arrivalHour = widget.initialArrivalHour ?? 8;
    arrivalMinute = widget.initialArrivalMinute ?? 0;

    final now = DateTime.now();
    arrivalDate = widget.initialArrivalDate ?? DateTime(now.year, now.month, now.day);

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

    _calculateAlarmTime();
  }

  void _calculateAlarmTime() {
    int hour24 = _convertTo24Hour(arrivalPeriod, arrivalHour);
    DateTime arrivalDateTime = DateTime(
      arrivalDate.year,
      arrivalDate.month,
      arrivalDate.day,
      hour24,
      arrivalMinute,
    );

    Duration prepTime = Duration(hours: prepHour, minutes: prepMinute, seconds: prepSecond);

    setState(() {
      alarmTime = arrivalDateTime.subtract(prepTime);
    });
  }

  void _onTimeChanged() {
    _calculateAlarmTime();
  }

  Future<void> _selectDate(BuildContext context) async {
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final picked = await showDatePicker(
        context: context,
        initialDate: arrivalDate.isBefore(today) ? today : arrivalDate,
        firstDate: today,
        lastDate: DateTime(now.year + 1, now.month, now.day),
        builder: (ctx, child) => Theme(
          data: Theme.of(ctx).copyWith(
            colorScheme: ColorScheme.light(
              primary: const Color(0xFF334066),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: const Color(0xFF334066),
            ),
          ),
          child: child!,
        ),
      );
      if (picked != null && picked != arrivalDate) {
        setState(() => arrivalDate = picked);
        _onTimeChanged();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('날짜 선택 중 오류가 발생했습니다.')),
        );
      }
    }
  }

  Future<void> _saveAlarmToCalendar() async {
    if (alarmTime == null) return;
    final arrivalDateTime = DateTime(
      arrivalDate.year,
      arrivalDate.month,
      arrivalDate.day,
      _convertTo24Hour(arrivalPeriod, arrivalHour),
      arrivalMinute,
    );
    final prefs = await SharedPreferences.getInstance();
    final googleId = prefs.getString('googleId') ?? '';
    final alarmService = AlarmApiService(googleId: googleId);
    await alarmService.registerAlarm(
      arrivalTime: arrivalDateTime.toIso8601String(),
      preparationTime: Duration(hours: prepHour, minutes: prepMinute).inMinutes,
    );
    _eventService.addAlarmEvent(alarmTime!, arrivalDate, DateFormat('HH:mm').format(arrivalDateTime));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('알람이 서버와 캘린더에 저장되었습니다.')),
      );
    }
  }

  int _convertTo24Hour(String period, int hour) {
    if (period == '오후' && hour < 12) return hour + 12;
    if (period == '오전' && hour == 12) return 0;
    return hour;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E27),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('시간설정'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.alarm_add),
            onPressed: () async {
              if (alarmTime == null) return;
              await _saveAlarmToCalendar();
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF0A0E27),
                  const Color(0xFF1A1E3A),
                ],
              ),
            ),
          ),
          Positioned(
            top: -100,
            left: -50,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF6366F1).withOpacity(0.3),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (departureName != null && destinationName != null) ...[
                    Text('출발: $departureName', style: const TextStyle(color: Colors.white)),
                    const SizedBox(height: 4),
                    Text('도착: $destinationName', style: const TextStyle(color: Colors.white)),
                    const SizedBox(height: 16),
                  ],
                  _alarmTimeCard(),
                  const SizedBox(height: 16),
                  _arrivalTimeCard(),
                  const SizedBox(height: 16),
                  _prepTimeCard(),
                  const SizedBox(height: 24),
                  _submitButton(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _alarmTimeCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.alarm, color: Colors.blue, size: 32),
              ),
              const SizedBox(width: 16),
              if (alarmTime != null) ...[
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '알람예정시간',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(_formatDate(alarmTime!), style: const TextStyle(color: Colors.white70, fontSize: 16)),
                    Text(_formatTime(alarmTime!), style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                  ],
                ),
              ] else ...[
                const Text('계산 불가', style: TextStyle(color: Colors.white)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _arrivalTimeCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '도착시간설정',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 18),
              GestureDetector(
                onTap: () => _selectDate(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.2)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.calendar_today,
                        size: 18,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatDate(arrivalDate),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildWheelPicker(
                    width: 70,
                    items: periodList,
                    selectedItem: arrivalPeriod,
                    onChanged: (val) {
                      setState(() => arrivalPeriod = val);
                      _onTimeChanged();
                    },
                    label: ' ',
                  ),
                  const SizedBox(width: 24),
                  _buildWheelPicker(
                    width: 70,
                    items: hourList.map((e) => e.toString().padLeft(2, '0')).toList(),
                    selectedItem: arrivalHour.toString().padLeft(2, '0'),
                    onChanged: (val) {
                      setState(() => arrivalHour = int.parse(val));
                      _onTimeChanged();
                    },
                    label: '시',
                  ),
                  const SizedBox(width: 16),
                  _buildWheelPicker(
                    width: 70,
                    items: minuteList.map((e) => e.toString().padLeft(2, '0')).toList(),
                    selectedItem: arrivalMinute.toString().padLeft(2, '0'),
                    onChanged: (val) {
                      setState(() => arrivalMinute = int.parse(val));
                      _onTimeChanged();
                    },
                    label: '분',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _prepTimeCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '준비시간설정',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildWheelPicker(
                    width: 70,
                    items: hourList24.map((e) => e.toString().padLeft(2, '0')).toList(),
                    selectedItem: prepHour.toString().padLeft(2, '0'),
                    onChanged: (val) {
                      setState(() => prepHour = int.parse(val));
                      _onTimeChanged();
                    },
                    label: '시',
                  ),
                  const SizedBox(width: 16),
                  _buildWheelPicker(
                    width: 70,
                    items: minuteList.map((e) => e.toString().padLeft(2, '0')).toList(),
                    selectedItem: prepMinute.toString().padLeft(2, '0'),
                    onChanged: (val) {
                      setState(() => prepMinute = int.parse(val));
                      _onTimeChanged();
                    },
                    label: '분',
                  ),
                  const SizedBox(width: 16),
                  _buildWheelPicker(
                    width: 70,
                    items: secondList.map((e) => e.toString().padLeft(2, '0')).toList(),
                    selectedItem: prepSecond.toString().padLeft(2, '0'),
                    onChanged: (val) {
                      setState(() => prepSecond = int.parse(val));
                      _onTimeChanged();
                    },
                    label: '초',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWheelPicker({
    required double width,
    required List<String> items,
    required String selectedItem,
    required ValueChanged<String> onChanged,
    required String label,
  }) {
    return Column(
      children: [
        Container(
          width: width,
          height: 120,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
          ),
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
                      color: selectedItem == items[index] ? Colors.white : Colors.white.withOpacity(0.5),
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
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.5)),
        ),
      ],
    );
  }

  Widget _submitButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () async {
          if (prepHour == 0 && prepMinute == 0 && prepSecond == 0) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('준비시간은 0보다 커야 합니다.')),
            );
            return;
          }

          if (alarmTime != null && alarmTime!.isBefore(DateTime.now())) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('알람시간이 현재 시간보다 이전입니다.')),
            );
            return;
          }

          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (BuildContext context) {
              return const Center(
                child: CircularProgressIndicator(color: Colors.white),
              );
            },
          );

          try {
            final serverBaseUrl = getServerBaseUrl();
            final int hour24 = _convertTo24Hour(arrivalPeriod, arrivalHour);
            final String timeString = '${hour24.toString().padLeft(2, '0')}:${arrivalMinute.toString().padLeft(2, '0')}:00';
            final String dateString = DateFormat('yyyy-MM-dd').format(arrivalDate);
            final String url = '$serverBaseUrl/traffic/routes';
            final headers = <String, String>{
              'Content-Type': 'application/json; charset=UTF-8',
            };
            final prefs = await SharedPreferences.getInstance();
            final googleId = prefs.getString('googleId') ?? '';
            
            final body = jsonEncode({
              'fromAddress': departureAddress,
              'toAddress': destinationAddress,
              'date': dateString,
              'time': timeString,
              'arriveBy': false,
              'googleId': googleId,
            });
            
            final response = await http.post(
              Uri.parse(url),
              headers: headers,
              body: body,
            );
            
            if (response.statusCode >= 200 && response.statusCode < 300) {
              try {
                final summaryResponse = SummaryResponse.parse(response.body);
                final summaryData = summaryResponse.data;
                if (mounted) {
                  Navigator.of(context).pop();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => RouteResultsPage(summaryData: summaryData),
                    ),
                  );
                }
              } catch (parseError) {
                if (mounted) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('응답 파싱 실패: $parseError')),
                  );
                }
              }
            } else {
              if (mounted) {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('경로 조회 실패: ${response.statusCode}')),
                );
              }
            }
          } catch (e) {
            if (mounted) {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('오류가 발생했습니다: $e')),
              );
            }
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF4A90E2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16),
          elevation: 0,
        ),
        child: const Text(
          '설정 완료',
          style: TextStyle(
            fontSize: 18,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final weekdays = ['일', '월', '화', '수', '목', '금', '토'];
    final wd = weekdays[date.weekday % 7];
    final today = DateTime.now();
    final tomorrow = today.add(const Duration(days: 1));
    final d = DateTime(date.year, date.month, date.day);
    if (d == DateTime(today.year, today.month, today.day)) return '오늘 (${date.month}/${date.day})';
    if (d == DateTime(tomorrow.year, tomorrow.month, tomorrow.day)) return '내일 (${date.month}/${date.day})';
    return '${date.month}/${date.day} ($wd)';
  }

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour;
    final min = dateTime.minute;
    final period = hour >= 12 ? '오후' : '오전';
    final displayHour = hour % 12 == 0 ? 12 : hour % 12;
    return '$period ${displayHour.toString().padLeft(2, '0')}:${min.toString().padLeft(2, '0')}';
  }
}
