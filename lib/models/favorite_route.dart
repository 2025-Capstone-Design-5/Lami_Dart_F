import 'category.dart';

class FavoriteRoute {
  final String id;
  final String name;
  final String origin;
  final String destination;
  final List<Category> categories;

  FavoriteRoute({
    required this.id,
    required this.name,
    required this.origin,
    required this.destination,
    required this.categories,
  });

  factory FavoriteRoute.fromJson(Map<String, dynamic> json) {
    var catsJson = json['categories'] as List<dynamic>?;
    List<Category> cats = catsJson != null
        ? catsJson.map((c) => Category.fromJson(c as Map<String, dynamic>)).toList()
        : [];
    return FavoriteRoute(
      id: json['id'] as String,
      name: json['name'] as String,
      origin: json['origin'] as String,
      destination: json['destination'] as String,
      categories: cats,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'origin': origin,
        'destination': destination,
        'categoryIds': categories.map((c) => c.id).toList(),
      };
} 