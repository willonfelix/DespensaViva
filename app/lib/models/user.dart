class User {
  final String id;
  final String email;
  final String? name;
  final bool hasGeminiKey;

  const User({
    required this.id,
    required this.email,
    this.name,
    this.hasGeminiKey = false,
  });

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['id'] as String,
        email: json['email'] as String? ?? '',
        name: json['name'] as String?,
        hasGeminiKey: json['has_gemini_key'] == true,
      );
}