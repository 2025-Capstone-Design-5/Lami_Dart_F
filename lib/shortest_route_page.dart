import 'package:flutter/material.dart';

class ShortestRoutePage extends StatelessWidget {
  const ShortestRoutePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // 피그마 디자인에 맞게 구성요소를 추가하세요!
    return Scaffold(
      appBar: AppBar(
        title: const Text('최단 경로'),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0.5,
        titleTextStyle: const TextStyle(
          color: Color(0xFF334066),
          fontWeight: FontWeight.w700,
          fontSize: 20,
        ),
        iconTheme: const IconThemeData(color: Color(0xFF334066)),
      ),
      backgroundColor: const Color(0xFFF3EFEE),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 상단 경로 정보 카드
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    '최단 경로',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF334066),
                    ),
                  ),
                  SizedBox(height: 12),
                  Text(
                    '출발지: 서울역',
                    style: TextStyle(fontSize: 16),
                  ),
                  Text(
                    '도착지: 강남역',
                    style: TextStyle(fontSize: 16),
                  ),
                  SizedBox(height: 12),
                  Text(
                    '예상 소요 시간: 50분',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.blue,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // 경로 상세 정보
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Text(
                '경로 상세: 서울역 → 시청 → 교대 → 강남역\n\n환승 1회, 총 3정거장',
                style: TextStyle(fontSize: 16),
              ),
            ),
            const SizedBox(height: 24),
            // 안내 문구
            const Text(
              '상세 경로와 소요 시간은 실제 교통 상황에 따라 달라질 수 있습니다.',
              style: TextStyle(fontSize: 14, color: Colors.black54),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}