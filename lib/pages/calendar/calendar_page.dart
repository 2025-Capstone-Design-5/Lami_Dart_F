import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../services/calendar_service.dart';
import 'package:googleapis/calendar/v3.dart' as gcal;

// Google Calendar Page: fetch and display events using TableCalendar
class CalendarPage extends StatefulWidget {
  const CalendarPage({Key? key}) : super(key: key);

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  Map<DateTime, List<gcal.Event>> _eventsMap = {};
  bool _loading = true;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDay = DateTime(now.year, now.month, now.day);
    _focusedDay = _selectedDay!;
    _loadGoogleCalendarEvents();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 페이지가 다시 활성화될 때마다 이벤트 로드
    _loadGoogleCalendarEvents();
  }

  Future<void> _loadGoogleCalendarEvents() async {
    try {
      // 항상 Google Sign-In 수행
      await CalendarService.signIn();
      // Fetch events for the current month
      final startOfMonth = DateTime(_focusedDay.year, _focusedDay.month, 1);
      final endOfMonth = DateTime(_focusedDay.year, _focusedDay.month + 1, 1).subtract(const Duration(seconds: 1));
      final events = await CalendarService.fetchEvents(
        timeMin: startOfMonth,
        timeMax: endOfMonth,
        maxResults: 1000,
      );
      final map = <DateTime, List<gcal.Event>>{};
      for (var e in events) {
        final dt = e.start?.dateTime?.toLocal();
        if (dt == null) continue;
        final day = DateTime(dt.year, dt.month, dt.day);
        map.putIfAbsent(day, () => []).add(e);
      }
      setState(() {
        _eventsMap = map;
        _loading = false;
      });
    } catch (e) {
      debugPrint('캘린더 이벤트 로드 실패: $e');
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final eventsForSelected = _eventsMap[_selectedDay] ?? [];
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
                '${_selectedDay?.year}년 ${_selectedDay?.month}월',
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
      body: Column(
        children: [
          TableCalendar<gcal.Event>(
            firstDay: DateTime.utc(2000, 1, 1),
            lastDay: DateTime.utc(2100, 12, 31),
            focusedDay: _focusedDay,
            calendarFormat: CalendarFormat.month,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            eventLoader: (day) => _eventsMap[day] ?? [],
            onDaySelected: (selected, focused) {
              setState(() {
                _selectedDay = selected;
                _focusedDay = focused;
              });
            },
            onPageChanged: (focusedDay) {
              setState(() {
                _focusedDay = focusedDay;
              });
              _loadGoogleCalendarEvents();
            },
            calendarStyle: const CalendarStyle(
              markerDecoration: BoxDecoration(color: Colors.blue, shape: BoxShape.circle),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              itemCount: eventsForSelected.length,
              itemBuilder: (context, idx) {
                final e = eventsForSelected[idx];
                final time = e.start?.dateTime?.toLocal() != null
                    ? DateFormat('HH:mm').format(e.start!.dateTime!.toLocal())
                    : '';
                return ListTile(
                  title: Text(e.summary ?? 'No Title'),
                  subtitle: Text(time),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _previousMonth() {
    setState(() {
      _selectedDay = DateTime(_selectedDay!.year, _selectedDay!.month - 1, 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _selectedDay = DateTime(_selectedDay!.year, _selectedDay!.month + 1, 1);
    });
  }

  void _goToToday() {
    setState(() {
      _selectedDay = DateTime.now();
    });
  }
}