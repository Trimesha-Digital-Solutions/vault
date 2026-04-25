class TeamModel {
  final String id;
  final String name;
  final String code;
  final String createdBy;
  final String role;
  final int memberCount;
  final DateTime createdAt;

  TeamModel({
    required this.id,
    required this.name,
    required this.code,
    required this.createdBy,
    required this.role,
    required this.memberCount,
    required this.createdAt,
  });

  factory TeamModel.fromJson(Map<String, dynamic> json) {
    return TeamModel(
      id: json['id'],
      name: json['name'],
      code: json['code'],
      createdBy: json['created_by'],
      role: json['role'] ?? 'Member',
      memberCount: json['member_count'] ?? 0,
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}

class TeamMemberModel {
  final String id; // User ID
  final String name;
  final String email;
  final String role;
  final DateTime joinedAt;
  final bool isOnline; // Not from DB yet, defaulting

  TeamMemberModel({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.joinedAt,
    this.isOnline = false,
  });

  factory TeamMemberModel.fromJson(Map<String, dynamic> json) {
    return TeamMemberModel(
      id: json['id'],
      name: json['name'],
      email: json['email'],
      role: json['role'],
      joinedAt: DateTime.parse(json['joined_at']),
    );
  }
}

class TeamRole {
  static const String organiser = 'Organiser';
  static const String member = 'Member';
}

class SharedVaultModel {
  final String id;
  final String name;
  final String teamId;
  final String createdBy;
  final List<String> memberIds;
  final int passwordCount;
  final DateTime createdAt;

  SharedVaultModel({
    required this.id,
    required this.name,
    required this.teamId,
    required this.createdBy,
    required this.memberIds,
    required this.passwordCount,
    required this.createdAt,
  });

  factory SharedVaultModel.fromJson(Map<String, dynamic> json) {
    return SharedVaultModel(
      id: json['id'],
      name: json['name'],
      teamId: json['team_id'],
      createdBy: json['created_by'],
      memberIds: List<String>.from(json['member_ids']),
      passwordCount: json['password_count'] ?? 0,
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}

class TeamCreateRequest {
  final String name;

  TeamCreateRequest({required this.name});

  Map<String, dynamic> toJson() => {'name': name};
}

class SharedVaultCreateRequest {
  final String name;
  final List<String>? memberIds;

  SharedVaultCreateRequest({required this.name, this.memberIds});

  Map<String, dynamic> toJson() => {
        'name': name,
        'member_ids': memberIds ?? [],
      };
}
