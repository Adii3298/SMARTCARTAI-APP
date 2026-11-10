class OrderItemModel {
  final int id;
  final String productName;
  final String brand;
  final double requestedQuantity;
  final double packedQuantity;
  final String unit;
  final double unitPrice;
  final double subtotal;
  final bool isAvailable;

  OrderItemModel({
    required this.id,
    required this.productName,
    required this.brand,
    required this.requestedQuantity,
    required this.packedQuantity,
    required this.unit,
    required this.unitPrice,
    required this.subtotal,
    required this.isAvailable,
  });

  factory OrderItemModel.fromJson(Map<String, dynamic> json) {
    return OrderItemModel(
      id: json['id'] ?? 0,
      productName: json['product_name'] ?? '',
      brand: json['brand'] ?? '',
      requestedQuantity: (json['requested_quantity'] is num) ? (json['requested_quantity'] as num).toDouble() : 1.0,
      packedQuantity: (json['packed_quantity'] is num) ? (json['packed_quantity'] as num).toDouble() : 1.0,
      unit: json['unit'] ?? 'packet',
      unitPrice: (json['unit_price'] is num) ? (json['unit_price'] as num).toDouble() : 0.0,
      subtotal: (json['subtotal'] is num) ? (json['subtotal'] as num).toDouble() : 0.0,
      isAvailable: json['is_available'] ?? true,
    );
  }
}

class OrderModel {
  final int id;
  final String orderNumber;
  final String status;
  final double totalAmount;
  final double deliveryFee;
  final String paymentMode;
  final String paymentStatus;
  final String deliveryCode; // 6-digit delivery verification OTP
  final String deliveryAddress;
  final int estimatedDeliveryMinutes;
  final String createdAt;
  final String? confirmedAt;
  final String? dispatchedAt;
  final String? deliveredAt;
  final String storeName;
  final String storeAddress;
  final String? storeUpiId;
  final String? upiUri;
  final String? upiQrCode;
  final String? codInstructions;
  final String? deliveryPartnerName;
  final String? deliveryPartnerPhone;
  final String? deliveryPartnerVehicle;
  final List<OrderItemModel> items;

  bool get isFreeDelivery => deliveryFee == 0.0;
  double get itemsSubtotal => (totalAmount - deliveryFee).clamp(0.0, double.infinity);

  OrderModel({
    required this.id,
    required this.orderNumber,
    required this.status,
    required this.totalAmount,
    this.deliveryFee = 0.0,
    required this.paymentMode,
    required this.paymentStatus,
    required this.deliveryCode,
    required this.deliveryAddress,
    required this.estimatedDeliveryMinutes,
    required this.createdAt,
    this.confirmedAt,
    this.dispatchedAt,
    this.deliveredAt,
    required this.storeName,
    required this.storeAddress,
    this.storeUpiId,
    this.upiUri,
    this.upiQrCode,
    this.codInstructions,
    this.deliveryPartnerName,
    this.deliveryPartnerPhone,
    this.deliveryPartnerVehicle,
    required this.items,
  });

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    var rawItems = json['items'] as List? ?? [];
    var store = json['store'];
    var partner = json['delivery_partner'];

    String? storeUpi = json['upi_id'] ?? (store != null ? store['upi_id'] : null);
    String? uri = json['upi_uri'];
    String? qr = json['upi_qr_code'];
    String? codText = json['cod_instructions'];

    double parsedTotal = (json['total_amount'] is num) ? (json['total_amount'] as num).toDouble() : 0.0;
    double parsedFee = (json['delivery_fee'] is num)
        ? (json['delivery_fee'] as num).toDouble()
        : (parsedTotal >= 200.0 ? 0.0 : (parsedTotal > 0.0 ? 30.0 : 0.0));

    return OrderModel(
      id: json['id'] ?? 0,
      orderNumber: json['order_number'] ?? '',
      status: json['status'] ?? 'PENDING_MERCHANT',
      totalAmount: parsedTotal,
      deliveryFee: parsedFee,
      paymentMode: json['payment_mode'] ?? 'COD',
      paymentStatus: json['payment_status'] ?? 'PENDING',
      deliveryCode: json['delivery_code'] ?? '',
      deliveryAddress: json['delivery_address'] ?? json['customer_address'] ?? '',
      estimatedDeliveryMinutes: json['estimated_delivery_minutes'] ?? 15,
      createdAt: json['created_at'] ?? '',
      confirmedAt: json['confirmed_at'],
      dispatchedAt: json['dispatched_at'],
      deliveredAt: json['delivered_at'],
      storeName: store != null ? store['name'] : (json['store_name'] ?? 'Local Kirana Store'),
      storeAddress: store != null ? store['address'] : (json['store_address'] ?? ''),
      storeUpiId: storeUpi,
      upiUri: uri,
      upiQrCode: qr,
      codInstructions: codText,
      deliveryPartnerName: partner != null ? partner['name'] : json['delivery_partner_name'],
      deliveryPartnerPhone: partner != null ? partner['mobile'] : null,
      deliveryPartnerVehicle: partner != null ? partner['vehicle'] : null,
      items: rawItems.map((i) => OrderItemModel.fromJson(i)).toList(),
    );
  }
}
