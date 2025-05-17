import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// 일정 데이터 모델
class Event {
  final String content;
  final DateTime date;
  final String id;

  Event({required this.content, required this.date})
      : id = '${date.toString()}_${DateTime.now().millisecondsSinceEpoch}';
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
    return _events[key] ?? [];
  }

  // 일정 추가 함수
  void addEvent(DateTime date, String content) {
    if (content.trim().isEmpty) return;

    final key = dateToKey(date);
    if (!_events.containsKey(key)) {
      _events[key] = [];
    }
    _events[key]!.add(Event(content: content.trim(), date: date));
    notifyListeners();
  }

  // 일정 삭제 함수
  void deleteEvent(DateTime date, String eventId) {
    final key = dateToKey(date);
    _events[key]!.removeWhere((event) => event.id == eventId);
    if (_events[key]!.isEmpty) {
      _events.remove(key);
    }
    notifyListeners();
  }
}