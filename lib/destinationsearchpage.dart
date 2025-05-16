import 'package:flutter/material.dart';

class DestinationSearchPage extends StatelessWidget {
  const DestinationSearchPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3EFEE),
      body: SafeArea(
        child: Column(
          children: [
            // 헤더
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFFCFAF8),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.25),
                      blurRadius: 4,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '출발, 도착지 검색 ',
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w700,
                          fontSize: 24,
                          color: Color(0xFF334066),
                        ),
                      ),
                      Image.asset('assets/images/header_image4.png', width: 32, height: 32),
                    ],
                  ),
                ),
              ),
            ),
            // 검색 결과 카드
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFFCFAF8),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.25),
                      blurRadius: 4,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '천안역',
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w400,
                              fontSize: 25,
                              color: Color(0xFF334066),
                            ),
                          ),
                          Image.asset('assets/images/icon_x.png', width: 24, height: 24),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '주소지  000도000시000로00-00',
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w400,
                          fontSize: 11,
                          color: Color(0xFF334066),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '아산역',
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w400,
                              fontSize: 25,
                              color: Color(0xFF334066),
                            ),
                          ),
                          Image.asset('assets/images/icon_x.png', width: 24, height: 24),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '주소지  000도000시000로00-00',
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w400,
                          fontSize: 11,
                          color: Color(0xFF334066),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '용산역',
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w400,
                              fontSize: 25,
                              color: Color(0xFF334066),
                            ),
                          ),
                          Image.asset('assets/images/icon_x.png', width: 24, height: 24),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '주소지  000도000시000로00-00',
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w400,
                          fontSize: 11,
                          color: Color(0xFF334066),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          '검색기록 삭제 ',
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w400,
                            fontSize: 15,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const Spacer(),
            // 하단 네비게이션 바
            Container(
              width: double.infinity,
              height: 84,
              decoration: BoxDecoration(
                color: const Color(0xFFFCFAF8),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.25),
                    blurRadius: 4,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: const [
                    Icon(Icons.home, size: 40, color: Color(0xFF334066)),
                    Icon(Icons.search, size: 40, color: Color(0xFF334066)),
                    Icon(Icons.notifications, size: 40, color: Color(0xFF334066)),
                    Icon(Icons.person, size: 40, color: Color(0xFF334066)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
} 