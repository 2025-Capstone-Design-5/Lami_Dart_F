import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// 일정 데이터 모델
class Event {
  final String content;
  final DateTime date;
  final String id;
  final String? title;  // title 속성 추가
  final String? time;   // time 속성 추가

  Event({
    required this.content,
    required this.date,
    this.title,
    this.time,
  }) : id = '${date.toString()}_${DateTime.now().millisecondsSinceEpoch}';

  // content를 title로 사용하는 getter 추가 (backward compatibility)
  String get displayTitle => title ?? content;

  // toString 메서드 추가 (디버깅용)
  @override
  String toString() {
    return 'Event{content: $content, date: $date, title: $title, time: $time, id: $id}';
  }

  // copyWith 메서드 추가 (수정 기능용)
  Event copyWith({
    String? content,
    DateTime? date,
    String? title,
    String? time,
  }) {
    return Event(
      content: content ?? this.content,
      date: date ?? this.date,
      title: title ?? this.title,
      time: time ?? this.time,
    );
  }
}

// 일정 데이터 관리를 위한 서비스 클래스
class EventService extends ChangeNotifier {
  // 싱글톤 패턴 구현
  static final EventService _instance = EventService._internal();

  factory EventService() {
    return _instance;
  }

  EventService._internal();

  // 일정을 저장할 Map 컬렉션 - 키는 'yyyy-MM-dd' 형식의 날짜 문자열
  final Map<String, List<Event>> _events = {};

  // 날짜를 키로 변환 (yyyy-MM-dd 형식)
  String dateToKey(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }

  // 해당 날짜에 일정이 있는지 확인
  bool hasEvents(DateTime date) {
    final key = dateToKey(date);
    return _events.containsKey(key) && _events[key]!.isNotEmpty;
  }

  // 특정 날짜의 일정 목록 가져오기
  List<Event> getEvents(DateTime date) {
    final key = dateToKey(date);
    return List.from(_events[key] ?? []); // 새로운 리스트 반환하여 외부 수정 방지
  }

  // 일정 추가 함수 (기존 버전 - backward compatibility)
  void addEvent(DateTime date, String content) {
    if (content.trim().isEmpty) return;

    final key = dateToKey(date);
    _events.putIfAbsent(key, () => []); // 더 간결한 방식

    _events[key]!.add(Event(
      content: content.trim(),
      date: date,
      title: content.trim(), // content를 title로도 설정
    ));

    notifyListeners();
    _debugPrint('일정 추가됨: $content (날짜: ${dateToKey(date)})');
  }

  // 일정 추가 함수 (새 버전 - title과 time 포함)
  void addEventWithDetails(DateTime date, String content, {String? title, String? time}) {
    if (content.trim().isEmpty) return;

    final key = dateToKey(date);
    _events.putIfAbsent(key, () => []);

    _events[key]!.add(Event(
      content: content.trim(),
      date: date,
      title: title?.trim() ?? content.trim(),
      time: time?.trim(),
    ));

    notifyListeners();
    _debugPrint('상세 일정 추가됨: ${title ?? content} (날짜: ${dateToKey(date)}, 시간: ${time ?? "미지정"})');
  }

  // 알람 일정 추가 함수 (TimeSettingPage에서 사용)
  void addAlarmEvent(DateTime alarmTime, DateTime arrivalDate, String arrivalTimeString) {
    // 알람 시간을 기준으로 일정 생성
    final alarmDateKey = dateToKey(alarmTime);

    // 알람 일정 내용 생성
    final alarmContent = '알람: ${DateFormat('yyyy-MM-dd').format(arrivalDate)} $arrivalTimeString 도착 준비';
    final alarmTitle = '출발 알람';
    final alarmTimeString = DateFormat('HH:mm').format(alarmTime);

    // 알람 일정 추가
    _events.putIfAbsent(alarmDateKey, () => []);

    _events[alarmDateKey]!.add(Event(
      content: alarmContent,
      date: alarmTime,
      title: alarmTitle,
      time: alarmTimeString,
    ));

    notifyListeners();

    _debugPrint('알람 일정이 추가되었습니다:');
    _debugPrint('- 알람 날짜: ${DateFormat('yyyy-MM-dd').format(alarmTime)}');
    _debugPrint('- 알람 시간: $alarmTimeString');
    _debugPrint('- 도착 예정: ${DateFormat('yyyy-MM-dd').format(arrivalDate)} $arrivalTimeString');
  }

  // 일정 수정 함수 추가
  void updateEvent(DateTime date, String eventId, Event updatedEvent) {
    final key = dateToKey(date);
    if (_events.containsKey(key)) {
      final eventIndex = _events[key]!.indexWhere((event) => event.id == eventId);
      if (eventIndex != -1) {
        _events[key]![eventIndex] = updatedEvent;
        notifyListeners();
        _debugPrint('일정 수정됨: ${updatedEvent.displayTitle}');
      }
    }
  }

  // 일정 삭제 함수
  void deleteEvent(DateTime date, String eventId) {
    final key = dateToKey(date);
    if (_events.containsKey(key)) {
      final removedEvent = _events[key]!.firstWhere(
            (event) => event.id == eventId,
        orElse: () => Event(content: '', date: date), // 기본값
      );

      _events[key]!.removeWhere((event) => event.id == eventId);

      if (_events[key]!.isEmpty) {
        _events.remove(key);
      }

      notifyListeners();
      _debugPrint('일정 삭제됨: ${removedEvent.displayTitle}');
    }
  }

  // 특정 일정 찾기
  Event? findEventById(String eventId) {
    for (final eventList in _events.values) {
      try {
        return eventList.firstWhere((event) => event.id == eventId);
      } catch (e) {
        continue;
      }
    }
    return null;
  }

  // 모든 일정 가져오기 (디버깅용)
  Map<String, List<Event>> getAllEvents() {
    return Map.from(_events);
  }

  // 특정 날짜 범위의 일정 가져오기
  List<Event> getEventsInRange(DateTime start, DateTime end) {
    List<Event> events = [];
    DateTime current = DateTime(start.year, start.month, start.day);
    final endDate = DateTime(end.year, end.month, end.day);

    while (current.isBefore(endDate) || current.isAtSameMomentAs(endDate)) {
      events.addAll(getEvents(current));
      current = current.add(const Duration(days: 1));
    }

    // 날짜순으로 정렬
    events.sort((a, b) => a.date.compareTo(b.date));
    return events;
  }

  // 오늘의 일정 가져오기
  List<Event> getTodayEvents() {
    return getEvents(DateTime.now());
  }

  // 이번 주 일정 가져오기
  List<Event> getThisWeekEvents() {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final endOfWeek = startOfWeek.add(const Duration(days: 6));
    return getEventsInRange(startOfWeek, endOfWeek);
  }

  // 모든 일정 삭제 (리셋 기능)
  void clearAllEvents() {
    _events.clear();
    notifyListeners();
    _debugPrint('모든 일정이 삭제되었습니다.');
  }

  // 일정 개수 반환
  int getTotalEventCount() {
    return _events.values.fold(0, (sum, eventList) => sum + eventList.length);
  }

  // 특정 날짜의 일정 개수 반환
  int getEventCount(DateTime date) {
    return getEvents(date).length;
  }

  // 디버그 출력 함수
  void _debugPrint(String message) {
    // 개발 중에만 출력하려면 kDebugMode를 사용할 수 있습니다
    print('[EventService] $message');
  }

  // 일정 검색 기능
  List<Event> searchEvents(String query) {
    if (query.trim().isEmpty) return [];

    final searchQuery = query.toLowerCase();
    List<Event> results = [];

    for (final eventList in _events.values) {
      for (final event in eventList) {
        if (event.content.toLowerCase().contains(searchQuery) ||
            (event.title?.toLowerCase().contains(searchQuery) ?? false)) {
          results.add(event);
        }
      }
    }

    // 날짜순으로 정렬
    results.sort((a, b) => a.date.compareTo(b.date));
    return results;
  }
}