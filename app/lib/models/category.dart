class Category {
  final int id;
  final String name;

  const Category({required this.id, required this.name});

  factory Category.fromJson(Map<String, dynamic> json) => Category(
        id: (json['id'] as num).toInt(),
        name: json['name'] as String? ?? '',
      );
}