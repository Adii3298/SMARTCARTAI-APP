class UserModel {
  final int id;
  final String userId;
  final String name;
  final String mobile;
  final String email;
  final String role; // customer, merchant, delivery, admin
  final String address;
  final String area;
  final String pincode;
  final String? storeName;
  final String? upiId;
  final String? vehicleType;
  final String? vehicleNumber;
  final bool isOnline;

  UserModel({
    required this.id,
    required this.userId,
    required this.name,
    required this.mobile,
    required this.email,
    required this.role,
    required this.address,
    required this.area,
    required this.pincode,
    this.storeName,
    this.upiId,
    this.vehicleType,
    this.vehicleNumber,
    this.isOnline = true,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? 0,
      userId: json['user_id'] ?? '',
      name: json['name'] ?? '',
      mobile: json['mobile'] ?? '',
      email: json['email'] ?? '',
      role: json['role'] ?? 'customer',
      address: json['address'] ?? '',
      area: json['area'] ?? '',
      pincode: json['pincode'] ?? '',
      storeName: json['store'] != null ? json['store']['name'] : json['store_name'],
      upiId: json['upi_id'] ?? (json['store'] != null ? json['store']['upi_id'] : null),
      vehicleType: json['vehicle_type'],
      vehicleNumber: json['vehicle_number'],
      isOnline: json['is_online'] ?? true,
    );
  }
}
