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
      _messages.add(_ChatMessage(text: text, isUser: true));
      // Show typing indicator
      _messages.add(_ChatMessage(isUser: false, isTyping: true, text: ''));
    });
    _controller.clear();
    setState(() {
      _isStreaming = true;
    });
    // Subscribe to SSE stream and handle a single response
    _streamSubscription = _agentService.streamProcess(
      message: text,
    ).listen((event) {
      // Remove typing indicator
      if (_messages.any((m) => m.isTyping)) {
        setState(() {
          _messages.removeWhere((m) => m.isTyping);
        });
      }
      try {
        final obj = json.decode(event) as Map<String, dynamic>;
        final response = obj['payload'] as String;
        setState(() {
          _messages.add(_ChatMessage(text: response.trim(), isUser: false));
          _isStreaming = false;
        });
      } catch (_) {
        setState(() {
          _messages.add(_ChatMessage(text: event, isUser: false));
          _isStreaming = false;
        });
      }
      _stopStreaming();
    }, onError: (e) {
      setState(() {
        _messages.add(_ChatMessage(text: '오류: $e', isUser: false));
      });
      _stopStreaming();
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
                // Chat messages
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      // Determine bubble alignment
                      final align = msg.isUser ? Alignment.centerRight : Alignment.centerLeft;
                      // Bubble color
                      final bgColor = msg.isUser
                          ? Colors.blue.withOpacity(0.3)
                          : Colors.white.withOpacity(0.3);
                      // Content widget
                      if (msg.isTyping == true) {
                        // Typing cursor indicator
                        return Align(
                          alignment: Alignment.centerLeft,
                          child: TypingIndicator(),
                        );
                      }
                      final content = msg.summaryData != null
                        ? SummaryChatWidget(summaryData: msg.summaryData!)
                        : msg.categoryData != null
                          ? CategoryMainWidget(
                              data: msg.categoryData!,
                              onDetailTap: (category, index) => _fetchDetail(category, index),
                            )
                          : msg.routeDetail != null
                            ? RouteDetailWidget(detail: msg.routeDetail!)
                            : msg.favorites != null
                              ? FavoriteListWidget(favorites: msg.favorites!)
                              : (() {
                                // Try to pretty-print JSON, else show raw text
                                try {
                                  final dynamic obj = json.decode(msg.text);
                                  final pretty = JsonEncoder.withIndent('  ').convert(obj);
                                  return SelectableText(
                                    pretty,
                                    style: TextStyle(
                                      color: msg.isUser ? Colors.white : Colors.black87,
                                      fontSize: 16,
                                    ),
                                  );
                                } catch (_) {
                                  return SelectableText(
                                    msg.text,
                                    style: TextStyle(
                                      color: msg.isUser ? Colors.white : Colors.black87,
                                      fontSize: 16,
                                    ),
                                  );
                                }
                              })();
                      return Align(
                        alignment: align,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 6),
                              padding: const EdgeInsets.all(16),
                              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                              decoration: BoxDecoration(
                                color: bgColor,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: msg.isUser
                                      ? Colors.blueAccent.withOpacity(0.5)
                                      : Colors.white.withOpacity(0.5),
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 8,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                              child: DefaultTextStyle(
                                style: TextStyle(color: msg.isUser ? Colors.white : Colors.black87, fontSize: 16),
                                child: content,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
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
  final SummaryData? summaryData;
  final Map<String, dynamic>? categoryData;
  final RouteDetail? routeDetail;
  final List<FavoriteRouteModel>? favorites;

  _ChatMessage({
    this.text = '',
    this.summaryData,
    this.categoryData,
    this.routeDetail,
    this.favorites,
    this.isTyping = false,
    required this.isUser,
  });
}