import 'package:flutter/material.dart';

class FavoritePlacesPage extends StatelessWidget {
  const FavoritePlacesPage({Key? key}) : super(key: key);

  // 검색 횟수가 높은 3가지 장소 (실제로는 데이터베이스나 로컬 저장소에서 가져와야 함)
  final List<Map<String, dynamic>> frequentPlaces = const [
    {
      'name': '서울역',
      'address': '서울특별시 중구 통일로 1',
      'count': 15,
      'icon': Icons.train,
    },
    {
      'name': '용산역',
      'address': '서울특별시 용산구 한강대로 23길',
      'count': 12,
      'icon': Icons.train,
    },
    {
      'name': '천안역',
      'address': '충청남도 천안시 동남구 태조산길 103',
      'count': 8,
      'icon': Icons.train,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('즐겨찾는 장소'),
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
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16.0),
              child: Text(
                '자주 방문한 장소',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: frequentPlaces.length,
                itemBuilder: (context, index) {
                  final place = frequentPlaces[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(16),
                      leading: CircleAvatar(
                        backgroundColor: Colors.blue.shade100,
                        child: Icon(place['icon'], color: Colors.blue),
                      ),
                      title: Text(
                        place['name'],
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text(place['address']),
                          const SizedBox(height: 4),
                          Text(
                            '방문 횟수: ${place['count']}회',
                            style: TextStyle(color: Colors.blue.shade700),
                          ),
                        ],
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.map, color: Colors.blue),
                        onPressed: () {
                          // 지도 페이지로 이동하는 기능 구현
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('${place['name']} 지도 보기')),
                          );
                        },
                      ),
                      isThreeLine: true,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}