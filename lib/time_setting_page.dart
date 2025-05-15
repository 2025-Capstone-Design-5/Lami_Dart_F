import 'package:flutter/material.dart';

class TimeSettingPage extends StatefulWidget {
  const TimeSettingPage({Key? key}) : super(key: key);

  @override
  State<TimeSettingPage> createState() => _TimeSettingPageState();
}

class _TimeSettingPageState extends State<TimeSettingPage> {
  // 도착 시간
  String arrivalPeriod = '오전';
  int arrivalHour = 8;
  int arrivalMinute = 0;

  // 준비 시간
  String prepPeriod = '오전';
  int prepHour = 0;
  int prepMinute = 30;

  final List<String> periodList = ['오전', '오후'];
  final List<int> hourList = List.generate(12, (i) => i + 1);
  final List<int> minuteList = List.generate(60, (i) => i);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3EFEE),
      appBar: AppBar(
        title: const Text('시간설정'),
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
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          children: [
            // 도착시간설정 카드
            _timeCard(
              title: '도착시간설정',
              period: arrivalPeriod,
              hour: arrivalHour,
              minute: arrivalMinute,
              onPeriodChanged: (val) => setState(() => arrivalPeriod = val),
              onHourChanged: (val) => setState(() => arrivalHour = val),
              onMinuteChanged: (val) => setState(() => arrivalMinute = val),
            ),
            const SizedBox(height: 24),
            // 준비시간설정 카드
            _timeCard(
              title: '준비시간설정',
              period: prepPeriod,
              hour: prepHour,
              minute: prepMinute,
              onPeriodChanged: (val) => setState(() => prepPeriod = val),
              onHourChanged: (val) => setState(() => prepHour = val),
              onMinuteChanged: (val) => setState(() => prepMinute = val),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF334066),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  elevation: 2,
                ),
                child: const Text(
                  '설정 완료',
                  style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _timeCard({
    required String title,
    required String period,
    required int hour,
    required int minute,
    required ValueChanged<String> onPeriodChanged,
    required ValueChanged<int> onHourChanged,
    required ValueChanged<int> onMinuteChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Color(0xFF334066),
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start, // 또는 center
            children: [
              // 오전/오후 피커
              _periodPicker(
                value: period,
                items: periodList,
                onChanged: onPeriodChanged,
              ),
              const SizedBox(width: 24),
              // 시 피커
              _numberPicker(
                value: hour,
                items: hourList,
                onChanged: onHourChanged,
                label: '시',
              ),
              const SizedBox(width: 16),
              // 분 피커
              _numberPicker(
                value: minute,
                items: minuteList,
                onChanged: onMinuteChanged,
                label: '분',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _periodPicker({
    required String value,
    required List<String> items,
    required ValueChanged<String> onChanged,
  }) {
    return Container(
      width: 70,
      height: 120,
      alignment: Alignment.center,
      child: ListWheelScrollView.useDelegate(
        itemExtent: 36,
        diameterRatio: 1.2,
        physics: const FixedExtentScrollPhysics(),
        onSelectedItemChanged: (index) => onChanged(items[index]),
        childDelegate: ListWheelChildBuilderDelegate(
          builder: (context, index) {
            if (index < 0 || index >= items.length) return null;
            return Center(
              child: Text(
                items[index],
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: value == items[index] ? FontWeight.bold : FontWeight.normal,
                  color: value == items[index] ? const Color(0xFF334066) : Colors.black54,
                ),
              ),
            );
          },
          childCount: items.length,
        ),
        controller: FixedExtentScrollController(
          initialItem: items.indexOf(value),
        ),
      ),
    );
  }

  Widget _numberPicker({
    required int value,
    required List<int> items,
    required ValueChanged<int> onChanged,
    required String label,
  }) {
    return SizedBox(
      width: 70,
      height: 120,
      child: Column(
        children: [
          Expanded(
            child: ListWheelScrollView.useDelegate(
              itemExtent: 36,
              diameterRatio: 1.2,
              physics: const FixedExtentScrollPhysics(),
              onSelectedItemChanged: (index) => onChanged(items[index]),
              childDelegate: ListWheelChildBuilderDelegate(
                builder: (context, index) {
                  if (index < 0 || index >= items.length) return null;
                  return Center(
                    child: Text(
                      '${items[index].toString().padLeft(2, '0')}',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: value == items[index] ? FontWeight.bold : FontWeight.normal,
                        color: value == items[index] ? const Color(0xFF334066) : Colors.black54,
                      ),
                    ),
                  );
                },
                childCount: items.length,
              ),
              controller: FixedExtentScrollController(
                initialItem: items.indexOf(value),
              ),
            ),
          ),
          Text(
            label,
            style: const TextStyle(fontSize: 14, color: Colors.black38),
          ),
        ],
      ),
    );
  }
}