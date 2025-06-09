class FavoriteRouteModel {
  final String id;
  final String origin;
  final String destination;
  final String category;
  final DateTime createdAt;

  FavoriteRouteModel({
    required this.id,
    required this.origin,
    required this.destination,
    required this.category,
    required this.createdAt,
  });

  factory FavoriteRouteModel.fromJson(Map<String, dynamic> json) {
    return FavoriteRouteModel(
      id: json['id'] as String,
      origin: json['origin'] as String,
      destination: json['destination'] as String,
      category: json['category'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}
 