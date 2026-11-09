class StoreModel {
  final int id;
  final String name;
  final String ownerName;
  final String phone;
  final String address;
  final String area;
  final String pincode;
  final double rating;
  final String upiId;
  final int totalProducts;
  final double distanceKm;
  final int estimatedDeliveryMinutes;

  StoreModel({
    required this.id,
    required this.name,
    required this.ownerName,
    required this.phone,
    required this.address,
    required this.area,
    required this.pincode,
    required this.rating,
    this.upiId = 'navjeevan@okaxis',
    this.totalProducts = 0,
    this.distanceKm = 0.5,
    this.estimatedDeliveryMinutes = 15,
  });

  factory StoreModel.fromJson(Map<String, dynamic> json) {
    return StoreModel(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      ownerName: json['owner_name'] ?? '',
      phone: json['phone'] ?? '',
      address: json['address'] ?? '',
      area: json['area'] ?? '',
      pincode: json['pincode'] ?? '',
      rating: (json['rating'] is num) ? (json['rating'] as num).toDouble() : 4.8,
      upiId: json['upi_id'] ?? '${json['phone'] ?? '9820011223'}@paytm',
      totalProducts: json['total_products'] ?? 0,
      distanceKm: (json['distance_km'] is num) ? (json['distance_km'] as num).toDouble() : 0.5,
      estimatedDeliveryMinutes: json['estimated_delivery_minutes'] ?? 15,
    );
  }
}
