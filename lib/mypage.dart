import 'package:flutter/material.dart';
import 'settingspage.dart';
import 'updatepage.dart';
import 'favorite_places_page.dart';

class MyPage extends StatelessWidget {
  const MyPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('마이페이지'),
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
            const CircleAvatar(
              radius: 40,
              backgroundColor: Colors.blue,
              child: Icon(Icons.person, size: 50, color: Colors.white),
            ),
            const SizedBox(height: 16),
            const Text(
              '홍길동',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'myemail@email.com',
              style: TextStyle(fontSize: 16, color: Colors.black54),
            ),
            const SizedBox(height: 32),
            // 교통수단 항목
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Column(
                  children: const [
                    Icon(Icons.train, size: 36, color: Colors.blue),
                    SizedBox(height: 4),
                    Text('지하철', style: TextStyle(fontSize: 14)),
                  ],
                ),
                Column(
                  children: const [
                    Icon(Icons.directions_bus, size: 36, color: Colors.green),
                    SizedBox(height: 4),
                    Text('버스', style: TextStyle(fontSize: 14)),
                  ],
                ),
                Column(
                  children: const [
                    Icon(Icons.directions_car, size: 36, color: Colors.orange),
                    SizedBox(height: 4),
                    Text('승용차', style: TextStyle(fontSize: 14)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            // 즐겨찾는 장소 항목
            ListTile(
              leading: Icon(Icons.star, color: Colors.amber),
              title: Text('즐겨찾는 장소'),
              trailing: Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const FavoritePlacesPage()),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.notifications),
              title: Text('업데이트'),
              trailing: Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const UpdatePage()),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.settings),
              title: Text('설정'),
              trailing: Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SettingsPage()),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.logout),
              title: Text('로그아웃'),
              trailing: Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {},
            ),
            // ... 추가 메뉴
          ],
        ),
      ),
    );
  }
}