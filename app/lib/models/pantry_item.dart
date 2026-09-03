class PantryItem {
  final int id;
  final int productId;
  final String name;
  final String unitOfMeasure;
  final String category;
  double quantity;
  final double minQuantity;
  final DateTime? expirationDate;

  PantryItem({
    required this.id,
    required this.productId,
    required this.name,
    required this.unitOfMeasure,
    required this.category,
    required this.quantity,
    required this.minQuantity,
    this.expirationDate,
  });

  factory PantryItem.fromJson(Map<String, dynamic> json) => PantryItem(
        id: _toInt(json['id']),
        productId: _toInt(json['productId']),
        name: json['name'] as String? ?? '',
        unitOfMeasure: json['unitOfMeasure'] as String? ?? 'unidade',
        category: json['category'] as String? ?? '',
        quantity: _toDouble(json['quantity']),
        minQuantity: _toDouble(json['minQuantity']),
        expirationDate: json['expirationDate'] == null
            ? null
            : DateTime.tryParse(json['expirationDate'] as String),
      );

  static int _toInt(dynamic v) =>
      v is num ? v.toInt() : int.tryParse(v?.toString() ?? '') ?? 0;

  static double _toDouble(dynamic v) =>
      v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '') ?? 0;

  bool get isLowStock => quantity <= minQuantity;

  bool get isNearExpiration {
    final exp = expirationDate;
    if (exp == null) return false;
    final days = exp.difference(DateTime.now()).inDays;
    return days >= 0 && days <= 7;
  }

  bool get isExpired {
    final exp = expirationDate;
    if (exp == null) return false;
    return exp.difference(DateTime.now()).inDays < 0;
  }

  PantryItem copyWith({double? quantity}) => PantryItem(
        id: id,
        productId: productId,
        name: name,
        unitOfMeasure: unitOfMeasure,
        category: category,
        quantity: quantity ?? this.quantity,
        minQuantity: minQuantity,
        expirationDate: expirationDate,
      );
}