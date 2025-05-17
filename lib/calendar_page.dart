import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'event_service.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({Key? key}) : super(key: key);

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  late DateTime _currentMonth;
  late List<DateTime?> _calendarDays;

  // 이벤트 서비스 인스턴스
  final EventService _eventService = EventService();

  @override
  void initState() {
    super.initState();
    _currentMonth = DateTime.now();
    _calendarDays = _generateCalendarDays(_currentMonth);
  }

  // 이전 달로 이동
  void _previousMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1, 1);
      _calendarDays = _generateCalendarDays(_currentMonth);
    });
  }

  // 다음 달로 이동
  void _nextMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 1);
      _calendarDays = _generateCalendarDays(_currentMonth);
    });
  }

  // 현재 달로 이동
  void _goToToday() {
    setState(() {
      _currentMonth = DateTime.now();
      _calendarDays = _generateCalendarDays(_currentMonth);
    });
  }

  // 달력 날짜들 생성
  List<DateTime?> _generateCalendarDays(DateTime month) {
    // 해당 월의 첫째 날
    final firstDayOfMonth = DateTime(month.year, month.month, 1);

    // 해당 월의 마지막 날
    final lastDayOfMonth = DateTime(month.year, month.month + 1, 0);

    // 첫째 날의 요일 (0: 일요일, 1: 월요일, ...)
    final firstWeekday = firstDayOfMonth.weekday % 7;

    // 전체 캘린더 날짜 (이전 달 + 현재 달 + 다음 달)
    final calendarDays = List<DateTime?>.filled(42, null); // 6주 * 7일

    // 이전 달의 날짜들 채우기
    final prevMonth = DateTime(month.year, month.month - 1, 1);
    final daysInPrevMonth = DateTime(month.year, month.month, 0).day;

    for (int i = 0; i < firstWeekday; i++) {
      calendarDays[i] = DateTime(
        prevMonth.year,
        prevMonth.month,
        daysInPrevMonth - (firstWeekday - i - 1),
      );
    }

    // 현재 달의 날짜들 채우기
    for (int i = 1; i <= lastDayOfMonth.day; i++) {
      calendarDays[firstWeekday + i - 1] = DateTime(month.year, month.month, i);
    }

    // 다음 달의 날짜들 채우기
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
                      color: d == '일' ? Colors.red : (d == '토' ? Colors.blue : Colors.black),
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
                itemCount: 42, // 6주 * 7일
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

                  // 해당 날짜에 일정이 있는지 확인
                  final hasEvents = _eventService.hasEvents(date);

                  // 주말 여부 확인 (0: 일요일, 6: 토요일)
                  final isWeekend = date.weekday == DateTime.sunday || date.weekday == DateTime.saturday;

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
                              setState(() {}); // UI 갱신
                            },
                            onDeleteEvent: (date, eventId) {
                              _eventService.deleteEvent(date, eventId);
                              setState(() {}); // UI 갱신
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
                                  ? (date.weekday == DateTime.sunday ? Colors.red : Colors.blue)
                                  : Colors.black,
                            ),
                          ),
                          if (hasEvents && isCurrentMonth)
                            Container(
                              margin: const EdgeInsets.only(top: 4),
                              height: 6,
                              width: 6,
                              decoration: BoxDecoration(
                                color: Colors.green,
                                shape: BoxShape.circle,
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
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(width: 16),
                Container(
                  height: 6,
                  width: 6,
                  decoration: const BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                const Text(
                  '일정 있음',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.black54,
                  ),
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

  @override
  Widget build(BuildContext context) {
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
            style: TextStyle(
              fontSize: 15,
              color: Colors.black54,
            ),
          ),
        ],
      ),
      content: Container(
        width: double.maxFinite,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.5,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 기존 일정 목록
            if (widget.events.isNotEmpty)
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: widget.events.length,
                  itemBuilder: (context, index) {
                    final event = widget.events[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        event.content,
                        style: TextStyle(fontSize: 16),
                      ),
                      trailing: IconButton(
                        icon: Icon(Icons.delete, color: Colors.red),
                        onPressed: () {
                          widget.onDeleteEvent(widget.date, event.id);
                          Navigator.pop(context);
                        },
                      ),
                    );
                  },
                ),
              ),
            if (widget.events.isNotEmpty)
              Divider(color: Colors.grey.withOpacity(0.3)),

            // 새로운 일정 입력 필드
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
                contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
              ),
              style: const TextStyle(fontSize: 16),
            ),
          ],
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