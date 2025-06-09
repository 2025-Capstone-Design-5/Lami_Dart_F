import 'package:flutter/material.dart';
import '../models/favorite_route_model.dart';
import 'package:intl/intl.dart';

class FavoriteListWidget extends StatelessWidget {
  final List<FavoriteRouteModel> favorites;

  const FavoriteListWidget({
    Key? key,
    required this.favorites,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (favorites.isEmpty) {
      return Text('즐겨찾기가 없습니다.');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: favorites.map((fav) {
        final formattedDate = DateFormat('yyyy-MM-dd HH:mm').format(fav.createdAt);
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${fav.origin} → ${fav.destination}',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              Text('카테고리: ${fav.category}'),
              Text(formattedDate, style: TextStyle(fontSize: 12)),
            ],
          ),
        );
      }).toList(),
    );
  }
} 