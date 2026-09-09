class PendingChange {
  final int id;
  final int pantryItemId;
  final String name;
  final String unitOfMeasure;
  final double currentQuantity;
  final double newQuantity;

  const PendingChange({
    required this.id,
    required this.pantryItemId,
    required this.name,
    required this.unitOfMeasure,
    required this.currentQuantity,
    required this.newQuantity,
  });

  factory PendingChange.fromJson(Map<String, dynamic> json) => PendingChange(
        id: _toInt(json['id']),
        pantryItemId: _toInt(json['pantryItemId']),
        name: json['name'] as String? ?? '',
        unitOfMeasure: json['unitOfMeasure'] as String? ?? 'unidade',
        currentQuantity: _toDouble(json['currentQuantity']),
        newQuantity: _toDouble(json['newQuantity']),
      );

  static int _toInt(dynamic v) =>
      v is num ? v.toInt() : int.tryParse(v?.toString() ?? '') ?? 0;

  static double _toDouble(dynamic v) =>
      v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '') ?? 0;
}