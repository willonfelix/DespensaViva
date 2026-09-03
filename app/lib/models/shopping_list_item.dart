class ShoppingListItem {
  final int id;
  final int productId;
  final String name;
  final String unitOfMeasure;
  final String category;
  final double suggestedQuantity;
  bool isChecked;

  ShoppingListItem({
    required this.id,
    required this.productId,
    required this.name,
    required this.unitOfMeasure,
    required this.category,
    required this.suggestedQuantity,
    this.isChecked = false,
  });

  factory ShoppingListItem.fromJson(Map<String, dynamic> json) =>
      ShoppingListItem(
        id: _toInt(json['id']),
        productId: _toInt(json['productId']),
        name: json['name'] as String? ?? '',
        unitOfMeasure: json['unitOfMeasure'] as String? ?? 'unidade',
        category: json['category'] as String? ?? '',
        suggestedQuantity: _toDouble(json['suggestedQuantity']) ?? 1,
        isChecked: json['isChecked'] as bool? ?? false,
      );

  static int _toInt(dynamic v) =>
      v is num ? v.toInt() : int.tryParse(v?.toString() ?? '') ?? 0;

  static double? _toDouble(dynamic v) =>
      v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '');

  ShoppingListItem copyWith({bool? isChecked}) => ShoppingListItem(
        id: id,
        productId: productId,
        name: name,
        unitOfMeasure: unitOfMeasure,
        category: category,
        suggestedQuantity: suggestedQuantity,
        isChecked: isChecked ?? this.isChecked,
      );
}