import 'dart:io';
import 'dart:convert';
import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'services/agent_service.dart';
import 'models/summary_response.dart';
import 'route_results_page.dart';
import 'widgets/category_main_widget.dart';
import 'widgets/summary_chat_widget.dart';
import 'models/route_response.dart';
import 'models/route_detail.dart';
import 'widgets/route_detail_widget.dart';
import 'widgets/typing_indicator.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'route_detail_page.dart';
import 'main.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'widgets/favorite_list_widget.dart';
import 'models/favorite_route_model.dart';

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
  // 저장 시 사용할 사용자 지정 카테고리 (general, home, work, school 등)
  String _selectedCategory = 'general';

  @override
  void initState() {
    super.initState();
    _loadGoogleId();
    // Initialize speech and TTS
    _speech = stt.SpeechToText();
    _initSpeech();
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

  Future<void> _sendMessage(String text) async {
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
    try {
      await for (final event in _agentService.streamProcess(
        userId: userId,
        message: text,
      )) {
        // Log received event to console
        print('AssistantPage SSE event: $event');
        // Remove typing indicator on first event
        if (_messages.any((m) => m.isTyping == true)) {
          setState(() {
            _messages.removeWhere((m) => m.isTyping == true);
          });
        }
        // Try parse JSON for route detail and summary
        try {
          final decoded = json.decode(event);
          if (decoded is Map<String, dynamic> && decoded.containsKey('favorites')) {
            final favs = (decoded['favorites'] as List)
                .map((e) => FavoriteRouteModel.fromJson(e as Map<String, dynamic>))
                .toList();
            setState(() {
              _messages.add(_ChatMessage(favorites: favs, isUser: false));
            });
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _scrollController.animateTo(
                _scrollController.position.maxScrollExtent,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
              );
            });
            continue;
          }
          if (decoded is Map<String, dynamic> && decoded.containsKey('main')) {
            final resp = RouteDetailResponse.fromJson(decoded);
            setState(() {
              _messages.add(_ChatMessage(routeDetail: resp.main, isUser: false));
            });
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _scrollController.animateTo(
                _scrollController.position.maxScrollExtent,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
              );
            });
            continue;
          }
          // Detect category summary JSON and display via CategoryMainWidget
          if (decoded is Map<String, dynamic> && decoded.keys.any((k) => ['walk','bus','car','subway','bus_subway'].contains(k))) {
            setState(() {
              _messages.add(_ChatMessage(categoryData: decoded, isUser: false));
            });
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _scrollController.animateTo(
                _scrollController.position.maxScrollExtent,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
              );
            });
            continue;
          }
        } catch (_) {}
        // Fallback: raw text event
        setState(() {
          _messages.add(_ChatMessage(text: event, isUser: false));
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final maxExtent = _scrollController.position.maxScrollExtent;
          _scrollController.animateTo(
            maxExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        });
      }
      return;
    } catch (e) {
      // Log streaming error to console
      print('AssistantPage streaming error: $e');
      setState(() {
        _messages.add(_ChatMessage(text: '오류: $e', isUser: false));
      });
    }
  }

  /// Traffic 컨트롤러 캐시에서 상세 경로를 가져와 모달로 보여줍니다.
  Future<void> _fetchDetail(String category, int index) async {
    final baseUrl = dotenv.env['BACKEND_URL'] ?? 'http://localhost:3000';
    final uri = Uri.parse('$baseUrl/agent/detail');
    if (_googleId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인 정보가 로드되지 않았습니다.')), 
      );
      return;
    }
    final userId = _googleId!;
    print('[AssistantPage] fetchDetail 요청: userId=$userId, category=$category, index=$index');
    try {
      final resp = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'category': category,
          'index': index,
          'userId': userId,
        }),
      );
      print('[AssistantPage] fetchDetail 응답: status=${resp.statusCode}, body=${resp.body}');
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        // Parse the 'main' object from the detail response
        final Map<String, dynamic> decoded = json.decode(resp.body) as Map<String, dynamic>;
        final mainJson = decoded['main'] as Map<String, dynamic>;
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
                      final baseUrl = dotenv.env['BACKEND_URL'] ?? 'http://localhost:3000';
                      final saveUri = Uri.parse('$baseUrl/traffic/routes/save');
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
                      final bgColor = Colors.white.withOpacity(0.2);
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
                            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 6),
                              padding: const EdgeInsets.all(16),
                              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.35),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.white.withOpacity(0.25), width: 1),
                              ),
                              child: DefaultTextStyle(
                                style: TextStyle(color: Colors.white, fontSize: 16),
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
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(color: Colors.white.withOpacity(0.25), width: 1),
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
                              icon: Icon(Icons.send, color: Colors.white),
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