class Guarantor {
  final String id;
  final String name;
  final String phoneNumber;
  final bool isVerified;
  final DateTime createdAt;

  const Guarantor({
    required this.id,
    required this.name,
    required this.phoneNumber,
    required this.isVerified,
    required this.createdAt,
  });

  factory Guarantor.fromJson(Map<String, dynamic> json) {
    return Guarantor(
      id: json['id'] as String,
      name: json['name'] as String,
      phoneNumber: json['phone_number'] as String,
      isVerified: json['is_verified'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
