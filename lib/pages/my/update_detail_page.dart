import 'package:flutter/material.dart';

class UpdateDetailPage extends StatelessWidget {
  final String title;
  final String date;

  const UpdateDetailPage({Key? key, required this.title, required this.date}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Center(
        child: Text('$date의 상세 업데이트 내용입니다.'),
      ),
    );
  }
} 