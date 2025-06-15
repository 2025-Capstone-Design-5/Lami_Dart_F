import 'dart:convert';
import 'package:googleapis/calendar/v3.dart' as calendar;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';

/// Google Calendar service for direct API integration
class CalendarService {
  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      'email',
      'https://www.googleapis.com/auth/calendar',
      'https://www.googleapis.com/auth/calendar.events',
    ],
  );

  /// Check if user is signed in
  static bool isSignedIn() {
    return _googleSignIn.currentUser != null;
  }

  /// Sign in with Google
  static Future<void> signIn() async {
    try {
      await _googleSignIn.signIn();
    } catch (error) {
      print('Error signing in: $error');
      rethrow;
    }
  }

  /// Try to sign in silently (without prompt)
  static Future<bool> signInSilently() async {
    try {
      final account = await _googleSignIn.signInSilently();
      return account != null;
    } catch (error) {
      print('Error signing in silently: $error');
      return false;
    }
  }

  /// Sign out
  static Future<void> signOut() async {
    await _googleSignIn.signOut();
  }

  /// Add event to Google Calendar
  static Future<void> addEvent({
    required String summary,
    required DateTime start,
    required DateTime end,
    String? description,
    String? location,
  }) async {
    if (!isSignedIn()) {
      throw Exception('User not signed in to Google');
    }

    try {
      // Get authenticated HTTP client
      final httpClient = await _googleSignIn.authenticatedClient();
      if (httpClient == null) {
        throw Exception('Failed to get authenticated client');
      }

      // Create calendar API instance
      final calendarApi = calendar.CalendarApi(httpClient);

      // Create event
      final event = calendar.Event()
        ..summary = summary
        ..description = description
        ..location = location
        ..start = calendar.EventDateTime(
          dateTime: start,
          timeZone: 'Asia/Seoul',
        )
        ..end = calendar.EventDateTime(
          dateTime: end,
          timeZone: 'Asia/Seoul',
        );

      // Insert event
      await calendarApi.events.insert(event, 'primary');
      print('✅ Google Calendar 이벤트 추가 성공!');
    } catch (error) {
      print('❌ Google Calendar 이벤트 추가 실패: $error');
      rethrow;
    }
  }

  /// Fetch events from Google Calendar
  static Future<List<calendar.Event>> fetchEvents({
    DateTime? timeMin,
    DateTime? timeMax,
    int maxResults = 10,
  }) async {
    if (!isSignedIn()) {
      throw Exception('User not signed in to Google');
    }

    try {
      final httpClient = await _googleSignIn.authenticatedClient();
      if (httpClient == null) {
        throw Exception('Failed to get authenticated client');
      }

      final calendarApi = calendar.CalendarApi(httpClient);
      
      final events = await calendarApi.events.list(
        'primary',
        timeMin: timeMin ?? DateTime.now(),
        timeMax: timeMax,
        maxResults: maxResults,
        singleEvents: true,
        orderBy: 'startTime',
      );

      return events.items ?? [];
    } catch (error) {
      print('❌ Google Calendar 이벤트 조회 실패: $error');
      rethrow;
    }
  }
} 