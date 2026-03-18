enum UserRole { user, agent }

enum AgentStatus { none, pending, approved, rejected }

class AppUser {
  final String id;
  final String email;
  final String firstName;
  final String lastName;
  final UserRole role;
  final AgentStatus agentStatus;

  const AppUser({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    this.role = UserRole.user,
    this.agentStatus = AgentStatus.none,
  });

  String get fullName => '$firstName $lastName'.trim();

  bool get isAgent => role == UserRole.agent;

  factory AppUser.fromSupabaseUser(Map<String, dynamic> data) {
    final meta = data['user_metadata'] as Map<String, dynamic>? ?? {};
    return AppUser(
      id: data['id'] as String,
      email: data['email'] as String? ?? '',
      firstName: meta['first_name'] as String? ?? '',
      lastName: meta['last_name'] as String? ?? '',
    );
  }

  factory AppUser.fromBackendProfile(Map<String, dynamic> data) {
    return AppUser(
      id: data['id'] as String,
      email: data['email'] as String? ?? '',
      firstName: data['first_name'] as String? ?? '',
      lastName: data['last_name'] as String? ?? '',
      role: _parseRole(data['role'] as String? ?? 'user'),
      agentStatus: _parseAgentStatus(data['agent_status'] as String? ?? 'none'),
    );
  }

  static UserRole _parseRole(String value) {
    return UserRole.values.firstWhere(
      (r) => r.name == value,
      orElse: () => UserRole.user,
    );
  }

  static AgentStatus _parseAgentStatus(String value) {
    return AgentStatus.values.firstWhere(
      (s) => s.name == value,
      orElse: () => AgentStatus.none,
    );
  }
}
