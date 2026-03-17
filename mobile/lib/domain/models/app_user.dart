class AppUser {
  final String id;
  final String email;
  final String firstName;
  final String lastName;

  const AppUser({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
  });

  String get fullName => '$firstName $lastName'.trim();

  factory AppUser.fromSupabaseUser(Map<String, dynamic> data) {
    final meta = data['user_metadata'] as Map<String, dynamic>? ?? {};
    return AppUser(
      id: data['id'] as String,
      email: data['email'] as String? ?? '',
      firstName: meta['first_name'] as String? ?? '',
      lastName: meta['last_name'] as String? ?? '',
    );
  }
}
