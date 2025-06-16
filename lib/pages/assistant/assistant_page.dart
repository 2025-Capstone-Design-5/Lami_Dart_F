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
import '../../services/calendar_service.dart';

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
    // Notify in chat that microphone is on
    setState(() {
      _messages.add(_ChatMessage(text: '🔊 마이크 켜짐', isLog: true, isUser: false, tag: '시스템'));
    });
    _scrollToBottom();
  }

  void _stopListening() {
    _speech.stop();
    // Notify in chat that microphone is off
    setState(() {
      _messages.add(_ChatMessage(text: '🔇 마이크 꺼짐', isLog: true, isUser: false, tag: '시스템'));
    });
    _scrollToBottom();
  }

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
            // Display tool execution results
            try {
              final resultMap = payload as Map<String, dynamic>;
              final toolName = resultMap['tool'] as String? ?? '';
              final toolResult = resultMap['result'];
              final logText = '✅ $toolName 결과: $toolResult';
              setState(() {
                _messages.add(
                  _ChatMessage(
                    text: logText,
                    isLog: true,
                    isUser: false,
                    tag: '결과',
                  ),
                );
              });
              _scrollToBottom();
            } catch (_) {
              // Fallback: show raw payload
              setState(() {
                _messages.add(_ChatMessage(text: payload.toString(), isLog: true, isUser: false, tag: '결과'));
              });
              _scrollToBottom();
            }
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
                    // Display tool execution results from token stream
                    try {
                      final innerMap = innerPayload as Map<String, dynamic>;
                      final toolName2 = innerMap['tool'] as String? ?? '';
                      final toolResult2 = innerMap['result'];
                      final logText2 = '✅ $toolName2 결과: $toolResult2';
                      setState(() {
                        _messages.add(
                          _ChatMessage(
                            text: logText2,
                            isLog: true,
                            isUser: false,
                            tag: '결과',
                          ),
                        );
                      });
                      _scrollToBottom();
                    } catch (_) {
                      setState(() {
                        _messages.add(
                          _ChatMessage(
                            text: innerPayload.toString(),
                            isLog: true,
                            isUser: false,
                            tag: '결과',
                          ),
                        );
                      });
                      _scrollToBottom();
                    }
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
      backgroundColor: const Color(0xFF0A0E27),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'AI 어시스턴트',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(
              Icons.cleaning_services_rounded,
              color: Colors.white.withOpacity(0.8),
            ),
            tooltip: '대화 내용 지우기',
            onPressed: () {
              setState(() {
                _messages.clear();
              });
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF0A0E27), Color(0xFF1A1E3A)],
              ),
            ),
          ),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
              child: Container(color: Colors.transparent),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    // Exclude result log messages (tag == '결과')
                    itemCount: _messages.where((m) => !(m.isLog && m.tag == '결과')).toList().length,
                    itemBuilder: (context, index) {
                      // Build only filtered messages
                      final displayMessages = _messages.where((m) => !(m.isLog && m.tag == '결과')).toList();
                      final message = displayMessages[index];
                      return _buildMessageBubble(message);
                    },
                  ),
                ),
                _buildInputArea(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(_ChatMessage message) {
    final isUser = message.isUser;
    final alignment = isUser ? Alignment.centerRight : Alignment.centerLeft;

    if (message.isTyping) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
          ),
          child: const TypingIndicator(),
        ),
      );
    }

    return Align(
      alignment: alignment,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.85,
        ),
        decoration: BoxDecoration(
          color: isUser
              ? Colors.blue.withOpacity(0.2)
              : Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isUser
                ? Colors.blue.withOpacity(0.3)
                : Colors.white.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: _buildMessageContent(message),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMessageContent(_ChatMessage message) {
    if (message.summaryData != null) {
      return SummaryChatWidget(
        summaryData: message.summaryData!,
        onSetAlarm: (route) async {
          // Alarm setting logic...
        },
      );
    }
    if (message.isLog) {
      return _buildLogCard(message);
    }
    return Text(
      message.text,
      style: const TextStyle(color: Colors.white, fontSize: 16),
    );
  }
  
  Widget _buildLogCard(_ChatMessage message) {
    final tag = message.tag ?? '로그';
    final color = _getTagColor(tag);
    final icon = _getTagIcon(tag);
    final description = _getTagDescription(tag);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                tag,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          description,
          style: TextStyle(
            fontSize: 14,
            color: color.withOpacity(0.8),
            fontStyle: FontStyle.italic,
          ),
        ),
        Divider(color: color.withOpacity(0.3), height: 20),
        ..._parseLogText(message.text, color),
      ],
    );
  }

  List<Widget> _parseLogText(String text, Color color) {
    final List<Widget> widgets = [];
    final parts = text.split(RegExp(r'•\s*|\n')).map((e) => e.trim()).where((e) => e.isNotEmpty);

    for (var part in parts) {
      if (part.startsWith('```')) {
        // Code block handling
      } else if (part.contains(':')) {
        final keyValue = part.split(':');
        final key = keyValue[0].trim();
        final value = keyValue.sublist(1).join(':').trim();
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$key: ',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Expanded(
                  child: Text(
                    value,
                    style: TextStyle(color: Colors.white.withOpacity(0.8)),
                  ),
                ),
              ],
            ),
          ),
        );
      } else {
         widgets.add(Text(part, style: TextStyle(color: Colors.white.withOpacity(0.8))));
      }
    }
    return widgets;
  }
  
  Color _getTagColor(String tag) {
    switch (tag) {
      case '입력': return Colors.blueAccent;
      case '추론': return Colors.purpleAccent;
      case '결과': return Colors.greenAccent;
      case '시스템': return Colors.orangeAccent;
      case 'route-summary': return Colors.cyanAccent;
      case '경로 조회': return Colors.cyanAccent;
      case 'fallback': return Colors.grey;
      case '일반 대화': return Colors.grey;
      default: return Colors.tealAccent;
    }
  }

  IconData _getTagIcon(String tag) {
    switch (tag) {
      case '입력': return Icons.input;
      case '추론': return Icons.lightbulb_outline;
      case '결과': return Icons.check_circle_outline;
      case '시스템': return Icons.settings_suggest;
      case 'route-summary': return Icons.alt_route;
      case '경로 조회': return Icons.alt_route;
      case 'fallback': return Icons.chat_bubble_outline;
      case '일반 대화': return Icons.chat_bubble_outline;
      default: return Icons.code;
    }
  }

  String _getTagDescription(String tag) {
    switch (tag) {
      case '추론': return '사고 과정을 나타냅니다.';
      case '결과': return '도구 실행 결과를 표시합니다.';
      case '경로 조회': return '경로 조회 도구를 호출합니다.';
      case '일반 대화': return '일반 대화 도구를 호출합니다.';
      default: return '로그 메시지입니다.';
    }
  }

  Widget _buildInputArea() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.2),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.2))),
      ),
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Row(
              children: [
                // Microphone button
                _buildCircularButton(
                  onPressed: _speechEnabled
                      ? (_speech.isListening ? _stopListening : _startListening)
                      : null,
                  icon: _speech.isListening ? Icons.mic : Icons.mic_none,
                  color: _speech.isListening ? Colors.redAccent : Colors.white,
                ),
                const SizedBox(width: 12),
                // Text field
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white.withOpacity(0.2)),
                    ),
                    child: TextField(
                      controller: _controller,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: '메시지를 입력하세요...',
                        hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                      onSubmitted: _sendMessage,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Send/Cancel button
                _buildCircularButton(
                  onPressed: () => _isStreaming ? _stopStreaming() : _sendMessage(_controller.text),
                  icon: _isStreaming ? Icons.stop : Icons.send,
                  color: _isStreaming ? Colors.redAccent : Colors.blueAccent,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCircularButton({required VoidCallback? onPressed, required IconData icon, required Color color}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: IconButton(
        icon: Icon(icon, color: color),
        onPressed: onPressed,
      ),
    );
  }
}

class _ChatMessage {
  final String text;
  final bool isUser;
  final bool isTyping;
  final bool isLog;
  final SummaryData? summaryData;
  final String? tag;

  _ChatMessage({
    required this.text,
    this.isUser = false,
    this.isTyping = false,
    this.isLog = false,
    this.summaryData,
    this.tag,
  });
}