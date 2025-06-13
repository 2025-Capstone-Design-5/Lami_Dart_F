class FavoriteRouteModel {
  final String id;
  final String origin;
  final String originAddress;
  final String destination;
  final String destinationAddress;
  final String category;
  final String iconName;
  final DateTime createdAt;
  final bool isDeparture; // 출발지 즐겨찾기인지 여부

  FavoriteRouteModel({
    required this.id,
    required this.origin,
    this.originAddress = '',
    required this.destination,
    this.destinationAddress = '',
    required this.category,
    this.iconName = 'place',
    required this.createdAt,
    this.isDeparture = false,
  });

  factory FavoriteRouteModel.fromJson(Map<String, dynamic> json) {
    return FavoriteRouteModel(
      id: json['id'] as String,
      origin: json['origin'] as String,
      originAddress: json['originAddress'] as String? ?? json['origin'] as String,
      destination: json['destination'] as String,
      destinationAddress: json['destinationAddress'] as String? ?? json['destination'] as String,
      category: json['category'] as String,
      iconName: json['iconName'] as String? ?? 'place',
      createdAt: DateTime.parse(json['createdAt'] as String),
      isDeparture: json['isDeparture'] as bool? ?? false,
    );
  }
  
  // JSON으로 변환하는 메서드 추가
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'origin': origin,
      'originAddress': originAddress,
      'destination': destination,
      'destinationAddress': destinationAddress,
      'category': category,
      'iconName': iconName,
      'createdAt': createdAt.toIso8601String(),
      'isDeparture': isDeparture,
    };
  }
}
 