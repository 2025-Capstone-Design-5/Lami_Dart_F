import 'dart:io';
import 'dart:convert';
import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../services/agent_service.dart';
import '../../models/summary_response.dart';
import '../route/route_results_page.dart';
import '../../widgets/category_main_widget.dart';
import '../../widgets/summary_chat_widget.dart';
import '../../models/route_response.dart';
import '../../models/route_detail.dart';
import '../../widgets/route_detail_widget.dart';
import '../../widgets/typing_indicator.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../route/route_detail_page.dart';
import '../../main.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../../widgets/favorite_list_widget.dart';
import '../../models/favorite_route_model.dart';
import '../../config/server_config.dart';
import '../../services/alarm_api_service.dart';

typedef AlarmRefreshCallback = void Function();
AlarmRefreshCallback? globalAlarmRefreshCallback;

class AssistantPage extends StatefulWidget {
  const AssistantPage({Key? key}) : super(key: key);

  @override
  State<AssistantPage> createState() => _AssistantPageState();
}

class _AssistantPageState extends State<AssistantPage> {
  final TextEditingController _controller = TextEditingController();
  final AgentService _agentService = AgentService();
  String? _googleId; // 실제 Google ID 저장
  final List<_ChatMessage> _messages = [];
  final ScrollController _scrollController = ScrollController();
  // STT and TTS
  late stt.SpeechToText _speech;
  bool _speechEnabled = false;
  String _lastWords = '';
  // Stream control
  StreamSubscription<String>? _streamSubscription;
  bool _isStreaming = false;
  List<String> _intermediateLogs = [];
  // Buffer for raw message tokens (Question/Thought)
  String _messageBuffer = '';
  // 저장 시 사용할 사용자 지정 카테고리 (general, home, work, school 등)
  String _selectedCategory = 'general';
  String? _cacheKey;

  @override
  void initState() {
    super.initState();
    _loadGoogleId();
    // Instantiate speech recognizer
    _speech = stt.SpeechToText();
    // Defer initialize until after first frame so Activity is attached
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initSpeech();
    });
  }

  Future<void> _initSpeech() async {
    _speechEnabled = await _speech.initialize();
    setState(() {});
  }

  void _startListening() {
    _speech.listen(onResult: (result) {
      setState(() {
        _lastWords = result.recognizedWords;
        _controller.text = _lastWords;
      });
    });
  }

  void _stopListening() => _speech.stop();

  Future<void> _loadGoogleId() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _googleId = prefs.getString('googleId');
    });
  }

  void _stopStreaming() {
    _streamSubscription?.cancel();
    _streamSubscription = null;
    setState(() {
      _isStreaming = false;
    });
  }

  Future<void> _sendMessage(String text) async {
    if (_isStreaming) {
      _stopStreaming();
      return;
    }
    if (text.trim().isEmpty) return;
    // Ensure googleId is loaded
    if (_googleId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인 정보가 로드되지 않았습니다.')), 
      );
      return;
    }
    final userId = _googleId!;
    setState(() {
      _messages.add(_ChatMessage(text: text, isUser: true, tag: '입력'));
      // Show typing indicator
      _messages.add(_ChatMessage(isUser: false, isTyping: true, text: ''));
    });
    _scrollToBottom();
    _controller.clear();
    setState(() {
      _isStreaming = true;
      _intermediateLogs.clear();
      _messageBuffer = '';
    });
    _scrollToBottom();
    // Subscribe to SSE stream and handle a single response
    _streamSubscription = _agentService.streamProcess(
      message: text,
    ).listen((event) {
      // Remove typing indicator on first event
      if (_messages.any((m) => m.isTyping)) {
        setState(() {
          _messages.removeWhere((m) => m.isTyping);
        });
      }
      try {
        final obj = json.decode(event) as Map<String, dynamic>;
        var type = obj['type'];
        var payload = obj['payload'];
        // 이중 인코딩 방어: type이 JSON string이면 한 번 더 파싱
        if (type is String && type.startsWith('{')) {
          final inner = json.decode(type);
          type = inner['type'];
          payload = inner['payload'];
        }
        switch (type) {
          case 'action_start':
            final map = payload as Map<String, dynamic>;
            final toolName = map['tool'] as String? ?? '';
            final reason = map['reason'] as String? ?? '';
            // Parse and format tool input values
            Map<String, dynamic> inputMap;
            final rawInput = map['toolInput'];
            if (rawInput is String) {
              inputMap = json.decode(rawInput) as Map<String, dynamic>;
            } else {
              inputMap = Map<String, dynamic>.from(rawInput as Map);
            }
            final inputText = inputMap.entries
                .map((e) => '${e.key}: ${e.value}')
                .join(', ');
            final logText = '🔧 $toolName 호출 • 입력: $inputText • 이유: $reason';
            setState(() {
              _intermediateLogs.add(logText);
              _messages.add(_ChatMessage(text: logText, isLog: true, isUser: false, tag: toolName));
            });
            _scrollToBottom();
            break;
          case 'status':
            final statusMsg = (payload as String).trim();
            setState(() {
              _intermediateLogs.add(statusMsg);
              _messages.add(_ChatMessage(text: statusMsg, isLog: true, isUser: false));
            });
            _scrollToBottom();
            break;
          case 'step':
            final stepMap = payload as Map<String, dynamic>;
            final reason = stepMap['reason'] as String? ?? '';
            final stepLog = '💭 $reason';
            setState(() {
              _intermediateLogs.add(stepLog);
              _messages.add(_ChatMessage(text: stepLog, isLog: true, isUser: false, tag: '추론'));
            });
            _scrollToBottom();
            break;
          case 'action_result':
            // No-op: skip action_result events
            break;
          case 'observation':
            final obsText = payload is String ? payload : json.encode(payload);
            final obsLog = obsText.trim();
            setState(() {
              _intermediateLogs.add(obsLog);
              _messages.add(_ChatMessage(text: obsLog, isLog: true, isUser: false));
            });
            _scrollToBottom();
            break;
          case 'final':
            // Handle final event: detect summary+routes payload
            if (payload is Map<String, dynamic> && payload.containsKey('routes')) {
              final summaryText = payload['summary'] as String;
              final cacheKey = payload['cacheKey'] as String;
              // parse structured routes
              final routesJson = payload['routes'] as List<dynamic>;
              final routesList = routesJson
                  .map((e) => RouteSummary.fromJson(e as Map<String, dynamic>))
                  .toList();
              final summaryData = SummaryData(
                origin: '',
                destination: '',
                summaryKey: cacheKey,
                routes: routesList,
              );
              setState(() {
                _cacheKey = cacheKey;
                _messages.add(_ChatMessage(
                  text: summaryText,
                  isUser: false,
                  summaryData: summaryData,
                  tag: '결과',
                ));
                _isStreaming = false;
              });
            } else {
              final rawText = payload is String ? payload : json.encode(payload);
              final trimmed = rawText.trim();

              // intermediateSteps가 있으면 추론 과정 메시지로 추가
              if (payload is Map<String, dynamic> && payload.containsKey('intermediateSteps')) {
                final steps = payload['intermediateSteps'] as List<dynamic>;
                for (final step in steps) {
                  final action = step['action'];
                  final observation = step['observation'];
                  final log = action?['log'] ?? '';
                  final tool = action?['tool'] ?? '';
                  // log(사고 과정) 메시지
                  if (log != null && log.toString().trim().isNotEmpty) {
                    setState(() {
                      _messages.add(_ChatMessage(
                        text: '💭 $log',
                        isUser: false,
                        isLog: true,
                        tag: '추론',
                      ));
                    });
                  }
                  // observation 메시지
                  if (observation != null && observation.toString().trim().isNotEmpty) {
                    setState(() {
                      _messages.add(_ChatMessage(
                        text: '👀 $observation',
                        isUser: false,
                        isLog: true,
                        tag: '관찰',
                      ));
                    });
                  }
                }
              }

              setState(() {
                _messages.add(_ChatMessage(text: trimmed, isUser: false, tag: '결과'));
                _isStreaming = false;
              });
            }
            _intermediateLogs.clear();
            _stopStreaming();
            _scrollToBottom();
            break;
          case 'error':
            final msg = payload is Map ? (payload['message'] ?? payload.toString()) : payload.toString();
            setState(() {
              _messages.add(_ChatMessage(text: '오류: $msg', isUser: false));
              _isStreaming = false;
            });
            _stopStreaming();
            _scrollToBottom();
            break;
          case 'token':
            // JSON-encoded event inside token payload
            if (payload is String && payload.startsWith('{')) {
              try {
                final inner = json.decode(payload) as Map<String, dynamic>;
                final innerType = inner['type'];
                final innerPayload = inner['payload'];
                switch (innerType) {
                  case 'action_start':
                    final map = innerPayload as Map<String, dynamic>;
                    final toolName = map['tool'] as String? ?? '';
                    final reason = map['reason'] as String? ?? '';
                    Map<String, dynamic> inputMap;
                    final rawInput = map['toolInput'];
                    if (rawInput is String) {
                      inputMap = json.decode(rawInput) as Map<String, dynamic>;
                    } else {
                      inputMap = Map<String, dynamic>.from(rawInput as Map);
                    }
                    final inputText = inputMap.entries.map((e) => '${e.key}: ${e.value}').join(', ');
                    final logText = '🔧 $toolName 호출 • 입력: $inputText • 이유: $reason';
                    setState(() {
                      _intermediateLogs.add(logText);
                      _messages.add(_ChatMessage(text: logText, isLog: true, isUser: false, tag: toolName));
                    });
                    _scrollToBottom();
                    break;
                  case 'status':
                    final statusMsg = (innerPayload as String).trim();
                    setState(() {
                      _intermediateLogs.add(statusMsg);
                      _messages.add(_ChatMessage(text: statusMsg, isLog: true, isUser: false));
                    });
                    _scrollToBottom();
                    break;
                  case 'step':
                    final stepMap = innerPayload as Map<String, dynamic>;
                    final reason = stepMap['reason'] as String? ?? '';
                    final stepLog = '💭 $reason';
                    setState(() {
                      _intermediateLogs.add(stepLog);
                      _messages.add(_ChatMessage(text: stepLog, isLog: true, isUser: false, tag: '추론'));
                    });
                    _scrollToBottom();
                    break;
                  case 'action_result':
                    // skip or handle as needed
                    break;
                  case 'observation':
                    final obsText = innerPayload is String ? innerPayload : json.encode(innerPayload);
                    final obsLog = obsText.trim();
                    setState(() {
                      _intermediateLogs.add(obsLog);
                      _messages.add(_ChatMessage(text: obsLog, isLog: true, isUser: false));
                    });
                    _scrollToBottom();
                    break;
                  case 'final':
                    // Parse JSON string if needed
                    dynamic finalData = innerPayload;
                    if (innerPayload is String) {
                      try {
                        finalData = json.decode(innerPayload);
                      } catch (_) {}
                    }
                    // Handle route summary object
                    if (finalData is Map<String, dynamic> && finalData.containsKey('routes')) {
                      final summaryText = finalData['summary'] as String;
                      final cacheKey = finalData['cacheKey'] as String;
                      final routesJson = finalData['routes'] as List<dynamic>;
                      final routesList = routesJson.map((e) => RouteSummary.fromJson(e as Map<String, dynamic>)).toList();
                      final summaryData = SummaryData(origin: '', destination: '', summaryKey: cacheKey, routes: routesList);
                      setState(() {
                        _cacheKey = cacheKey;
                        _messages.add(_ChatMessage(text: summaryText, isUser: false, summaryData: summaryData, tag: '결과'));
                        _isStreaming = false;
                      });
                    } else {
                      final rawText = finalData is String ? finalData : json.encode(finalData);
                      final trimmed = rawText.trim();
                      setState(() {
                        _messages.add(_ChatMessage(text: trimmed, isUser: false, tag: '결과'));
                        _isStreaming = false;
                      });
                    }
                    _intermediateLogs.clear();
                    _stopStreaming();
                    _scrollToBottom();
                    break;
                  default:
                    break;
                }
              } catch (_) {
                // parsing failed, ignore
              }
            } else if (payload is String) {
              // accumulate real tokens
              setState(() {
                _messageBuffer += payload;
                if (_messages.isNotEmpty && _messages.last.isTyping) {
                  _messages.last = _ChatMessage(text: _messageBuffer, isUser: false, isTyping: true);
                } else {
                  _messages.add(_ChatMessage(text: _messageBuffer, isUser: false, isTyping: true));
                }
              });
              _scrollToBottom();
            }
            break;
          default:
            break;
        }
      } catch (_) {
        setState(() {
          _messages.add(_ChatMessage(text: event, isUser: false));
          _isStreaming = false;
        });
        _stopStreaming();
        _scrollToBottom();
      }
    }, onError: (e) {
      setState(() {
        _messages.add(_ChatMessage(text: '스트리밍 오류: $e', isUser: false));
        _isStreaming = false;
      });
      _stopStreaming();
      _scrollToBottom();
    });
  }

  /// Traffic 컨트롤러 캐시에서 상세 경로를 가져와 모달로 보여줍니다.
  Future<void> _fetchDetail(String category, int index) async {
    if (_cacheKey == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('요약 키가 없습니다. 먼저 경로 요약을 확인하세요.')),
      );
      return;
    }
    final uri = Uri.parse('${getServerBaseUrl()}/agent/detail');
    try {
      final resp = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'summaryKey': _cacheKey,
          'category': category,
          'index': index,
        }),
      );
      print('[AssistantPage] fetchDetail 응답: status=${resp.statusCode}, body=${resp.body}');
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        final decodedResp = json.decode(resp.body) as Map<String, dynamic>;
        final data = decodedResp['data'] as Map<String, dynamic>;
        final mainJson = data['main'] as Map<String, dynamic>;
        final detail = RouteDetail.fromJson(mainJson);
        // Show a simple detail modal with RouteDetailWidget
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          builder: (context) {
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 사용자 카테고리 선택 드롭다운
                  DropdownButton<String>(
                    value: _selectedCategory,
                    items: const [
                      DropdownMenuItem(value: 'general', child: Text('General')),
                      DropdownMenuItem(value: 'home', child: Text('집')),
                      DropdownMenuItem(value: 'work', child: Text('직장')),
                      DropdownMenuItem(value: 'school', child: Text('학교')),
                    ],
                    onChanged: (val) => setState(() {
                      _selectedCategory = val!;
                    }),
                  ),
                  const SizedBox(height: 8),
                  RouteDetailWidget(detail: detail),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.save),
                    label: const Text('경로 저장'),
                    onPressed: () async {
                      if (_googleId == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('로그인 정보가 로드되지 않았습니다.')), 
                        );
                        return;
                      }
                      final userId = _googleId!;
                      final saveUri = Uri.parse('${getServerBaseUrl()}/traffic/routes/save');
                      // Prepare payload
                      final payload = {
                        'googleId': userId,
                        'origin': detail.origin,
                        'destination': detail.destination,
                        'arrivalTime': DateTime.now().toIso8601String(),
                        'preparationTime': 0,
                        'options': {},
                        // 서버에 저장할 실제 서비스 카테고리
                        'category': _selectedCategory,
                        'summary': detail.toJson(),
                        'detail': detail.toJson(),
                      };
                      // Log request
                      print('[AssistantPage] saveRoute request: uri=$saveUri, payload=${jsonEncode(payload)}');
                      try {
                        final saveResp = await http.post(
                          saveUri,
                          headers: {'Content-Type': 'application/json'},
                          body: jsonEncode(payload),
                        );
                        // Log response
                        print('[AssistantPage] saveRoute response: status=${saveResp.statusCode}, body=${saveResp.body}');
                        if (saveResp.statusCode >= 200 && saveResp.statusCode < 300) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('경로가 저장되었습니다!')),
                          );
                          // Close detail modal and return to Home tab
                          Navigator.of(context).pop();
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(
                              builder: (_) => const MainScreen(initialIndex: 0),
                            ),
                            (route) => false,
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('저장 실패: ${saveResp.body}')),
                          );
                        }
                      } catch (e) {
                        // Log error
                        print('[AssistantPage] saveRoute error: $e');
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('저장 오류: $e')),
                        );
                      }
                    },
                  ),
                ],
              ),
            );
          },
        );
      }
    } catch (e) {
      print('[AssistantPage] fetchDetail 오류: $e');
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Background gradient
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF2C3E50), Color(0xFF34495E)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    'Lami',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      shadows: [Shadow(color: Colors.black26, blurRadius: 4)],
                    ),
                  ),
                ),
                // Chat messages list
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      // Render summary with inline UI and navigation button
                      if (msg.summaryData != null) {
                        final summaryData = msg.summaryData!;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SummaryChatWidget(
                                summaryData: summaryData,
                                onSetAlarm: (route) async {
                                  if (_googleId == null) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('로그인 정보가 없습니다.')),
                                    );
                                    return;
                                  }
                                  try {
                                    // 예시: 도착 예정 시간(현재 시간 + duration), 준비 시간(5분)
                                    final now = DateTime.now();
                                    final arrival = now.add(Duration(seconds: route.duration));
                                    final arrivalStr = arrival.toIso8601String();
                                    final preparationTime = 5; // 분 단위, 필요시 UI에서 입력받게 할 수 있음
                                    final alarmService = AlarmApiService(googleId: _googleId!);
                                    await alarmService.registerAlarm(
                                      arrivalTime: arrivalStr,
                                      preparationTime: preparationTime,
                                    );
                                    // 홈 알람 위젯 갱신 트리거
                                    if (globalAlarmRefreshCallback != null) {
                                      globalAlarmRefreshCallback!();
                                    }
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('알람이 성공적으로 등록되었습니다.')),
                                    );
                                  } catch (e) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('알람 등록 실패: $e')),
                                    );
                                  }
                                },
                              ),
                              const SizedBox(height: 8),
                              ElevatedButton(
                                onPressed: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => RouteResultsPage(summaryData: summaryData),
                                    ),
                                  );
                                },
                                child: const Text('전체 경로 보기'),
                              ),
                            ],
                          ),
                        );
                      }
                      // Skip typing indicators
                      if (msg.isTyping) {
                        return SizedBox.shrink();
                      }
                      // Display logs and intermediate events as plain text
                      if (!msg.isUser && msg.tag != '결과') {
                        return Align(
                          alignment: Alignment.centerLeft,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Text(
                              msg.text,
                              style: TextStyle(color: Colors.white70, fontSize: 14),
                            ),
                          ),
                        );
                      }
                      // Show only user messages and final results as chat bubbles
                      final isUser = msg.isUser;
                      final alignment = isUser ? Alignment.centerRight : Alignment.centerLeft;
                      final bgColor = isUser ? Colors.grey.shade200 : Colors.blueAccent;
                      final textColor = isUser ? Colors.black87 : Colors.white;
                      return Align(
                        alignment: alignment,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                          decoration: BoxDecoration(
                            color: bgColor,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(msg.text, style: TextStyle(color: textColor, fontSize: 16)),
                        ),
                      );
                    },
                  ),
                ),
                // Streaming indicator
                if (_isStreaming)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: LinearProgressIndicator(
                      backgroundColor: Colors.white54,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.blueAccent),
                      minHeight: 4,
                    ),
                  ),
                // Input field
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(30),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.25),
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.15),
                              blurRadius: 6,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _controller,
                                style: TextStyle(color: Colors.white),
                                decoration: InputDecoration(
                                  hintText: '메시지를 입력하세요',
                                  hintStyle: TextStyle(color: Colors.white70),
                                  border: InputBorder.none,
                                ),
                                onSubmitted: _sendMessage,
                              ),
                            ),
                            IconButton(
                              icon: Icon(
                                _speech.isListening ? Icons.mic : Icons.mic_none,
                                color: Colors.white,
                              ),
                              onPressed: _speechEnabled
                                  ? (_speech.isListening ? _stopListening : _startListening)
                                  : null,
                            ),
                            IconButton(
                              icon: Icon(_isStreaming ? Icons.stop : Icons.send, color: Colors.white),
                              onPressed: () => _sendMessage(_controller.text),
                            ),
                            // Cancel button during streaming
                            if (_isStreaming)
                              TextButton(
                                onPressed: _stopStreaming,
                                child: Text('취소', style: TextStyle(color: Colors.white)),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatMessage {
  final String text;
  final bool isUser;
  final bool isTyping;
  final bool? isLog;
  final SummaryData? summaryData;
  final Map<String, dynamic>? categoryData;
  final RouteDetail? routeDetail;
  final List<FavoriteRouteModel>? favorites;
  final String? tag;

  _ChatMessage({
    this.text = '',
    this.summaryData,
    this.categoryData,
    this.routeDetail,
    this.favorites,
    this.isTyping = false,
    this.isLog = false,
    required this.isUser,
    this.tag,
  });
}