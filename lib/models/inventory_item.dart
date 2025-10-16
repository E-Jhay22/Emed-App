// InventoryItem model

class InventoryItem {
  final String id;
  final String name;
  final String? description;
  final String? category;
  final String? imageUrl;
  final int quantity;
  final int? minQuantity;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  InventoryItem({
    required this.id,
    required this.name,
    this.description,
    this.category,
    this.imageUrl,
    required this.quantity,
    this.minQuantity,
    this.createdAt,
    this.updatedAt,
  });

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    if (v is String) {
      try {
        return DateTime.parse(v);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  factory InventoryItem.fromJson(Map<String, dynamic> json) => InventoryItem(
    id: json['id'] as String,
    name: json['name'] as String? ?? '',
    description: json['description'] as String?,
    category: json['category'] as String?,
    imageUrl: json['image_url'] as String?,
    quantity: (json['quantity'] is int)
        ? json['quantity'] as int
        : int.tryParse('${json['quantity']}') ?? 0,
    minQuantity: (json['min_quantity'] is int)
        ? json['min_quantity'] as int
        : (json['min_quantity'] == null
              ? null
              : int.tryParse('${json['min_quantity']}')),
    createdAt: _parseDate(json['created_at']),
    updatedAt: _parseDate(json['updated_at']),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'category': category,
    'image_url': imageUrl,
    'quantity': quantity,
    'min_quantity': minQuantity,
    'created_at': createdAt?.toIso8601String(),
    'updated_at': updatedAt?.toIso8601String(),
  };
}
