import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'event_service.dart';
// 일정 데이터 모델
class Event {
  final String content;
  final DateTime date;
  final String id;
  final String? title;
  final String? time;
  final bool isAlarmEvent;
  final DateTime? alarmTime;
  final String? arrivalTime;

  Event({
    required this.content,
    required this.date,
    this.title,
    this.time,
    this.isAlarmEvent = false,
    this.alarmTime,
    this.arrivalTime,
  }) : id = '${date.toString()}_${DateTime.now().millisecondsSinceEpoch}';

  String get displayTitle => title ?? content;
}

// 일정 데이터 관리를 위한 서비스 클래스
class EventService extends ChangeNotifier {
  static final EventService _instance = EventService._internal();
  factory EventService() => _instance;
  EventService._internal();

  final Map<String, List<Event>> _events = {};

  String dateToKey(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }

  bool hasEvents(DateTime date) {
    final key = dateToKey(date);
    return _events.containsKey(key) && _events[key]!.isNotEmpty;
  }

  List<Event> getEvents(DateTime date) {
    final key = dateToKey(date);
    return _events[key] ?? [];
  }

  void addEvent(DateTime date, String content) {
    if (content.trim().isEmpty) return;

    final key = dateToKey(date);
    if (!_events.containsKey(key)) {
      _events[key] = [];
    }
    _events[key]!.add(Event(
      content: content.trim(),
      date: date,
      title: content.trim(),
      isAlarmEvent: false,
    ));
    notifyListeners();
  }

  void addAlarmEvent(DateTime alarmTime, DateTime arrivalDate, String arrivalTimeString) {
    final alarmDateKey = dateToKey(alarmTime);
    final alarmContent = '알람: ${DateFormat('yyyy-MM-dd').format(arrivalDate)} $arrivalTimeString 도착 준비';

    if (!_events.containsKey(alarmDateKey)) {
      _events[alarmDateKey] = [];
    }

    _events[alarmDateKey]!.add(Event(
      content: alarmContent,
      date: alarmTime,
      title: '출발 알람',
      time: DateFormat('HH:mm').format(alarmTime),
      isAlarmEvent: true,
      alarmTime: alarmTime,
      arrivalTime: arrivalTimeString,
    ));

    notifyListeners();
  }

  void deleteEvent(DateTime date, String eventId) {
    final key = dateToKey(date);
    if (_events.containsKey(key)) {
      _events[key]!.removeWhere((event) => event.id == eventId);
      if (_events[key]!.isEmpty) {
        _events.remove(key);
      }
      notifyListeners();
    }
  }
}

class CalendarPage extends StatefulWidget {
  const CalendarPage({Key? key}) : super(key: key);

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  late DateTime _currentMonth;
  late List<DateTime?> _calendarDays;
  final EventService _eventService = EventService();

  @override
  void initState() {
    super.initState();
    _currentMonth = DateTime.now();
    _calendarDays = _generateCalendarDays(_currentMonth);

    // EventService 변경사항 감지
    _eventService.addListener(_onEventServiceChanged);
  }

  @override
  void dispose() {
    _eventService.removeListener(_onEventServiceChanged);
    super.dispose();
  }

  void _onEventServiceChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _previousMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1, 1);
      _calendarDays = _generateCalendarDays(_currentMonth);
    });
  }

  void _nextMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 1);
      _calendarDays = _generateCalendarDays(_currentMonth);
    });
  }

  void _goToToday() {
    setState(() {
      _currentMonth = DateTime.now();
      _calendarDays = _generateCalendarDays(_currentMonth);
    });
  }

  List<DateTime?> _generateCalendarDays(DateTime month) {
    final firstDayOfMonth = DateTime(month.year, month.month, 1);
    final lastDayOfMonth = DateTime(month.year, month.month + 1, 0);
    final firstWeekday = firstDayOfMonth.weekday % 7;
    final calendarDays = List<DateTime?>.filled(42, null);

    // 이전 달의 날짜들
    final prevMonth = DateTime(month.year, month.month - 1, 1);
    final daysInPrevMonth = DateTime(month.year, month.month, 0).day;

    for (int i = 0; i < firstWeekday; i++) {
      calendarDays[i] = DateTime(
        prevMonth.year,
        prevMonth.month,
        daysInPrevMonth - (firstWeekday - i - 1),
      );
    }

    // 현재 달의 날짜들
    for (int i = 1; i <= lastDayOfMonth.day; i++) {
      calendarDays[firstWeekday + i - 1] = DateTime(month.year, month.month, i);
    }

    // 다음 달의 날짜들
    final nextMonth = DateTime(month.year, month.month + 1, 1);
    int nextMonthDay = 1;
    for (int i = firstWeekday + lastDayOfMonth.day; i < 42; i++) {
      calendarDays[i] = DateTime(
        nextMonth.year,
        nextMonth.month,
        nextMonthDay++,
      );
    }

    return calendarDays;
  }

  Map<String, dynamic> _getEventInfo(DateTime date) {
    final events = _eventService.getEvents(date);
    bool hasNormalEvents = false;
    bool hasAlarmEvents = false;

    for (Event event in events) {
      if (event.isAlarmEvent) {
        hasAlarmEvents = true;
      } else {
        hasNormalEvents = true;
      }
    }

    return {
      'hasNormalEvents': hasNormalEvents,
      'hasAlarmEvents': hasAlarmEvents,
      'eventCount': events.length,
    };
  }

  @override
  Widget build(BuildContext context) {
    final days = ['일', '월', '화', '수', '목', '금', '토'];
    final today = DateTime.now();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left, color: Colors.black87),
              onPressed: _previousMonth,
            ),
            GestureDetector(
              onTap: _goToToday,
              child: Text(
                '${_currentMonth.year}년 ${_currentMonth.month}월',
                style: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w600,
                  fontSize: 20,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right, color: Colors.black87),
              onPressed: _nextMonth,
            ),
          ],
        ),
        centerTitle: true,
        toolbarHeight: 48,
      ),
      backgroundColor: const Color(0xFFF3EFEE),
      body: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          children: [
            // 요일 헤더
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: days
                  .map((d) => Expanded(
                child: Center(
                  child: Text(
                    d,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: d == '일'
                          ? Colors.red
                          : (d == '토' ? Colors.blue : Colors.black),
                    ),
                  ),
                ),
              ))
                  .toList(),
            ),
            const SizedBox(height: 8),
            // 날짜 그리드
            Expanded(
              child: GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                itemCount: 42,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 1,
                ),
                itemBuilder: (context, index) {
                  final date = _calendarDays[index];
                  if (date == null) {
                    return Container();
                  }

                  final isToday = date.year == today.year &&
                      date.month == today.month &&
                      date.day == today.day;

                  final isCurrentMonth = date.month == _currentMonth.month;
                  final eventInfo = _getEventInfo(date);
                  final hasNormalEvents = eventInfo['hasNormalEvents'] as bool;
                  final hasAlarmEvents = eventInfo['hasAlarmEvents'] as bool;
                  final eventCount = eventInfo['eventCount'] as int;
                  final isWeekend = date.weekday == DateTime.sunday ||
                      date.weekday == DateTime.saturday;

                  return GestureDetector(
                    onTap: () {
                      if (isCurrentMonth) {
                        showDialog(
                          context: context,
                          builder: (context) => _CalendarPopup(
                            date: date,
                            formattedDate: DateFormat('yyyy년 MM월 dd일').format(date),
                            events: _eventService.getEvents(date),
                            onAddEvent: (date, content) {
                              _eventService.addEvent(date, content);
                            },
                            onDeleteEvent: (date, eventId) {
                              _eventService.deleteEvent(date, eventId);
                            },
                          ),
                        );
                      }
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: isToday ? Colors.blue.withOpacity(0.2) : Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isToday ? Colors.blue : Colors.black12,
                          width: isToday ? 1.5 : 1,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            date.day.toString(),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: isToday ? FontWeight.bold : FontWeight.w500,
                              color: !isCurrentMonth
                                  ? Colors.grey.withOpacity(0.5)
                                  : isWeekend
                                  ? (date.weekday == DateTime.sunday
                                  ? Colors.red
                                  : Colors.blue)
                                  : Colors.black,
                            ),
                          ),
                          // 이벤트 인디케이터
                          if ((hasNormalEvents || hasAlarmEvents) && isCurrentMonth)
                            Container(
                              margin: const EdgeInsets.only(top: 4),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (hasNormalEvents)
                                    Container(
                                      height: 6,
                                      width: 6,
                                      margin: const EdgeInsets.symmetric(horizontal: 1),
                                      decoration: const BoxDecoration(
                                        color: Colors.blue,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  if (hasAlarmEvents)
                                    Container(
                                      height: 6,
                                      width: 6,
                                      margin: const EdgeInsets.symmetric(horizontal: 1),
                                      decoration: const BoxDecoration(
                                        color: Colors.orange,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          // 이벤트 개수 표시
                          if (eventCount > 2 && isCurrentMonth)
                            Container(
                              margin: const EdgeInsets.only(top: 2),
                              child: Text(
                                '+${eventCount - 2}',
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            // 범례
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  height: 12,
                  width: 12,
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.blue, width: 1.5),
                  ),
                ),
                const SizedBox(width: 6),
                const Text(
                  '오늘',
                  style: TextStyle(fontSize: 14, color: Colors.black54),
                ),
                const SizedBox(width: 16),
                Container(
                  height: 6,
                  width: 6,
                  decoration: const BoxDecoration(
                    color: Colors.blue,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                const Text(
                  '일반 일정',
                  style: TextStyle(fontSize: 14, color: Colors.black54),
                ),
                const SizedBox(width: 16),
                Container(
                  height: 6,
                  width: 6,
                  decoration: const BoxDecoration(
                    color: Colors.orange,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                const Text(
                  '알람 일정',
                  style: TextStyle(fontSize: 14, color: Colors.black54),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CalendarPopup extends StatefulWidget {
  final DateTime date;
  final String formattedDate;
  final List<Event> events;
  final Function(DateTime, String) onAddEvent;
  final Function(DateTime, String) onDeleteEvent;

  const _CalendarPopup({
    required this.date,
    required this.formattedDate,
    required this.events,
    required this.onAddEvent,
    required this.onDeleteEvent,
  });

  @override
  State<_CalendarPopup> createState() => _CalendarPopupState();
}

class _CalendarPopupState extends State<_CalendarPopup> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _formatTime(DateTime dateTime) {
    int hour = dateTime.hour;
    int minute = dateTime.minute;
    String period = hour >= 12 ? '오후' : '오전';
    int displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);

    return '$period ${displayHour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final alarmEvents = widget.events.where((event) => event.isAlarmEvent).toList();
    final normalEvents = widget.events.where((event) => !event.isAlarmEvent).toList();

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.formattedDate,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 20,
              color: Color(0xFF334066),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '오늘의 일정',
            style: TextStyle(fontSize: 15, color: Colors.black54),
          ),
        ],
      ),
      content: Container(
        width: double.maxFinite,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.6,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 알람 일정 섹션
              if (alarmEvents.isNotEmpty) ...[
                Row(
                  children: [
                    Container(
                      height: 8,
                      width: 8,
                      decoration: const BoxDecoration(
                        color: Colors.orange,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      '알람 일정',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...alarmEvents.map((event) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.alarm, color: Colors.orange, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              event.content,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (event.alarmTime != null)
                              Text(
                                '알람: ${_formatTime(event.alarmTime!)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            if (event.arrivalTime != null)
                              Text(
                                '도착: ${event.arrivalTime}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                        onPressed: () {
                          widget.onDeleteEvent(widget.date, event.id);
                          Navigator.pop(context);
                        },
                      ),
                    ],
                  ),
                )),
                if (normalEvents.isNotEmpty) const SizedBox(height: 16),
              ],

              // 일반 일정 섹션
              if (normalEvents.isNotEmpty) ...[
                Row(
                  children: [
                    Container(
                      height: 8,
                      width: 8,
                      decoration: const BoxDecoration(
                        color: Colors.blue,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      '일반 일정',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...normalEvents.map((event) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                    leading: Container(
                      height: 6,
                      width: 6,
                      decoration: const BoxDecoration(
                        color: Colors.blue,
                        shape: BoxShape.circle,
                      ),
                    ),
                    title: Text(
                      event.content,
                      style: const TextStyle(fontSize: 16),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                      onPressed: () {
                        widget.onDeleteEvent(widget.date, event.id);
                        Navigator.pop(context);
                      },
                    ),
                  ),
                )),
              ],

              if (widget.events.isNotEmpty)
                Divider(color: Colors.grey.withOpacity(0.3)),

              // 새로운 일정 입력
              const Text(
                '새 일정 추가',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _controller,
                autofocus: widget.events.isEmpty,
                decoration: InputDecoration(
                  hintText: '일정 입력',
                  hintStyle: TextStyle(
                    color: Colors.black.withOpacity(0.3),
                    fontSize: 16,
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF3EFEE),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 14,
                    horizontal: 12,
                  ),
                ),
                style: const TextStyle(fontSize: 16),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('닫기'),
        ),
        TextButton(
          onPressed: () {
            if (_controller.text.trim().isNotEmpty) {
              widget.onAddEvent(widget.date, _controller.text.trim());
            }
            Navigator.pop(context);
          },
          child: const Text('저장'),
        ),
      ],
    );
  }
}