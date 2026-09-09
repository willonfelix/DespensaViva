class AuditEntry {
  final int id;
  final String action;
  final String entity;
  final String? entityId;
  final Map<String, dynamic>? details;
  final DateTime createdAt;
  final String? environment;

  const AuditEntry({
    required this.id,
    required this.action,
    required this.entity,
    this.entityId,
    this.details,
    required this.createdAt,
    this.environment,
  });

  factory AuditEntry.fromJson(Map<String, dynamic> json) => AuditEntry(
        id: _toInt(json['id']),
        action: json['action'] as String? ?? '',
        entity: json['entity'] as String? ?? '',
        entityId: json['entityId']?.toString(),
        details: json['details'] is Map
            ? (json['details'] as Map).map((k, v) => MapEntry(k.toString(), v))
            : null,
        createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
        environment: json['environment']?.toString(),
      );

  static int _toInt(dynamic v) =>
      v is num ? v.toInt() : int.tryParse(v?.toString() ?? '') ?? 0;

  String get title {
    switch (action) {
      case 'auth.login':
        return 'Login';
      case 'pantry.quantity_change':
        return 'Quantidade alterada';
      case 'pantry.add':
        return 'Item adicionado';
      case 'pantry.delete':
        return 'Item excluído';
      default:
        return action;
    }
  }

  String get itemName => details?['name']?.toString() ?? entityId ?? '';
}