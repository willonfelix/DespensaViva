class Environment {
  final String id;
  final String name;
  final String myRole;
  final int memberCount;
  final List<EnvironmentMember> members;

  const Environment({
    required this.id,
    required this.name,
    required this.myRole,
    this.memberCount = 0,
    this.members = const [],
  });

  factory Environment.fromJson(Map<String, dynamic> json) => Environment(
        id: json['id'] as String,
        name: json['name'] as String? ?? '',
        myRole: json['myRole'] as String? ?? 'member',
        memberCount: (json['memberCount'] as num?)?.toInt() ?? 0,
        members: (json['members'] as List? ?? [])
            .map((e) => EnvironmentMember.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  bool get isOwner => myRole == 'owner';

  Environment copyWith({List<EnvironmentMember>? members, int? memberCount}) =>
      Environment(
        id: id,
        name: name,
        myRole: myRole,
        memberCount: memberCount ?? this.memberCount,
        members: members ?? this.members,
      );
}

class EnvironmentMember {
  final String userId;
  final String email;
  final String? name;
  final String role;

  const EnvironmentMember({
    required this.userId,
    required this.email,
    this.name,
    required this.role,
  });

  factory EnvironmentMember.fromJson(Map<String, dynamic> json) =>
      EnvironmentMember(
        userId: json['userId'] as String,
        email: json['email'] as String? ?? '',
        name: json['name'] as String?,
        role: json['role'] as String? ?? 'member',
      );

  bool get isOwner => role == 'owner';
}
