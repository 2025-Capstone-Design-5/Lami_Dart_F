import 'package:flutter/material.dart';

class CalendarPage extends StatelessWidget {
  const CalendarPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final days = ['일', '월', '화', '수', '목', '금', '토'];
    final dates = List.generate(30, (i) => (i + 1).toString());

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: const Text(
          '2025년 1월',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        toolbarHeight: 48,
      ),
      backgroundColor: const Color(0xFFF3EFEE),
      body: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          children: [
            // 요일 헤더
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: days
                  .map((d) => Expanded(
                child: Center(
                  child: Text(
                    d,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ))
                  .toList(),
            ),
            const SizedBox(height: 8),
            // 날짜 그리드
            Expanded(
              child: GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                itemCount: 35, // 5주 * 7일
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 1,
                ),
                itemBuilder: (context, index) {
                  if (index < 2 || index > 31) {
                    // 빈칸
                    return Container();
                  }
                  return GestureDetector(
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (context) => _CalendarPopup(
                          date: dates[index - 2],
                        ),
                      );
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.black12),
                      ),
                      child: Center(
                        child: Text(
                          dates[index - 2],
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              '일정을 선택하면 상세 정보를 볼 수 있습니다.',
              style: TextStyle(
                fontSize: 15,
                color: Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CalendarPopup extends StatefulWidget {
  final String date;
  const _CalendarPopup({required this.date});

  @override
  State<_CalendarPopup> createState() => _CalendarPopupState();
}

class _CalendarPopupState extends State<_CalendarPopup> {
  final TextEditingController _controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${widget.date}일 일정',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 20,
              color: Color(0xFF334066),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '오늘의 일정을 입력하세요',
            style: TextStyle(
              fontSize: 15,
              color: Colors.black54,
            ),
          ),
        ],
      ),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(
          hintText: '일정 입력',
          hintStyle: TextStyle(
            color: Colors.black.withOpacity(0.3), // 반투명
            fontSize: 16,
          ),
          filled: true,
          fillColor: const Color(0xFFF3EFEE),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        ),
        style: const TextStyle(fontSize: 16),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('닫기'),
        ),
        TextButton(
          onPressed: () {
            // 일정 저장 등 원하는 동작 추가
            Navigator.pop(context);
          },
          child: const Text('저장'),
        ),
      ],
    );
  }
}