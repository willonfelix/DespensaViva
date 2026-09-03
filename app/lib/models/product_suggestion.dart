class ProductSuggestion {
  final String name;
  final String? brand;
  final int? categoryId;
  final String? imageUrl;

  const ProductSuggestion({
    required this.name,
    this.brand,
    this.categoryId,
    this.imageUrl,
  });

  factory ProductSuggestion.fromJson(Map<String, dynamic> json) =>
      ProductSuggestion(
        name: json['name'] as String? ?? '',
        brand: json['brand'] as String?,
        categoryId: (json['categoryId'] as num?)?.toInt(),
        imageUrl: json['imageUrl'] as String?,
      );
}
