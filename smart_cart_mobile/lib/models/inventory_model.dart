class InventoryItemModel {
  final int id;
  String name;
  String brand;
  String category;
  String unit;
  double price;
  double stockQuantity;
  bool isInStock;

  InventoryItemModel({
    required this.id,
    required this.name,
    required this.brand,
    required this.category,
    required this.unit,
    required this.price,
    required this.stockQuantity,
    required this.isInStock,
  });

  factory InventoryItemModel.fromJson(Map<String, dynamic> json) {
    return InventoryItemModel(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      brand: json['brand'] ?? 'Standard',
      category: json['category'] ?? 'General',
      unit: json['unit'] ?? 'packet',
      price: (json['price'] is num) ? (json['price'] as num).toDouble() : 0.0,
      stockQuantity: (json['stock_quantity'] is num) ? (json['stock_quantity'] as num).toDouble() : 0.0,
      isInStock: json['is_in_stock'] ?? true,
    );
  }
}
