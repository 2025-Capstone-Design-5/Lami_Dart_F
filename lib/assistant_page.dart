import 'package:flutter/material.dart';

class AssistantPage extends StatelessWidget {
  const AssistantPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('어시스턴트'),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0.5,
        titleTextStyle: const TextStyle(
          color: Colors.black,
          fontWeight: FontWeight.w600,
          fontSize: 20,
        ),
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      backgroundColor: const Color(0xFFF3EFEE),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 32),
            const Icon(Icons.smart_toy, size: 80, color: Colors.blue),
            const SizedBox(height: 24),
            const Text(
              'AI 어시스턴트',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              '궁금한 점을 물어보세요!\n여행, 일정, 교통 등 다양한 정보를 도와드릴 수 있습니다.',
              style: TextStyle(fontSize: 16, color: Colors.black54),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            TextField(
              decoration: InputDecoration(
                hintText: '메시지를 입력하세요',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                suffixIcon: Icon(Icons.send),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
            // ... 추가적인 대화 UI 등 구현 가능
          ],
        ),
      ),
    );
  }
}