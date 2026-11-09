class ExtractedGroceryItem {
  String name;
  String brand;
  double quantity;
  String unit;
  String category;
  double confidence;

  ExtractedGroceryItem({
    required this.name,
    this.brand = 'Standard',
    this.quantity = 1.0,
    this.unit = 'packet',
    this.category = 'General',
    this.confidence = 0.95,
  });

  factory ExtractedGroceryItem.fromJson(Map<String, dynamic> json) {
    return ExtractedGroceryItem(
      name: json['name'] ?? '',
      brand: json['brand'] ?? 'Standard',
      quantity: (json['quantity'] is num) ? (json['quantity'] as num).toDouble() : 1.0,
      unit: json['unit'] ?? 'packet',
      category: json['category'] ?? 'General',
      confidence: (json['confidence'] is num) ? (json['confidence'] as num).toDouble() : 0.95,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'brand': brand,
      'quantity': quantity,
      'unit': unit,
      'category': category,
      'confidence': confidence,
    };
  }
}

class OcrResultModel {
  final String rawText;
  final String? annotatedImageBase64;
  final List<ExtractedGroceryItem> items;

  OcrResultModel({
    required this.rawText,
    this.annotatedImageBase64,
    required this.items,
  });

  factory OcrResultModel.fromJson(Map<String, dynamic> json) {
    var rawList = json['items'] as List? ?? [];
    return OcrResultModel(
      rawText: json['raw_text'] ?? '',
      annotatedImageBase64: json['annotated_image'],
      items: rawList.map((i) => ExtractedGroceryItem.fromJson(i)).toList(),
    );
  }
}
