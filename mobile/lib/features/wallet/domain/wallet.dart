class Wallet {
  final String id;
  final String phoneNumber;
  final String network;
  final bool isVerified;
  final bool isDefault;
  final DateTime createdAt;

  const Wallet({
    required this.id,
    required this.phoneNumber,
    required this.network,
    required this.isVerified,
    required this.isDefault,
    required this.createdAt,
  });

  String get networkLabel => switch (network) {
    'mtn' => 'MTN',
    'vodafone' => 'Vodafone',
    'airteltigo' => 'AirtelTigo',
    _ => network,
  };

  factory Wallet.fromJson(Map<String, dynamic> json) {
    return Wallet(
      id: json['id'] as String,
      phoneNumber: json['phone_number'] as String,
      network: json['network'] as String,
      isVerified: json['is_verified'] as bool,
      isDefault: json['is_default'] as bool,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Wallet copyWith({
    String? id,
    String? phoneNumber,
    String? network,
    bool? isVerified,
    bool? isDefault,
    DateTime? createdAt,
  }) {
    return Wallet(
      id: id ?? this.id,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      network: network ?? this.network,
      isVerified: isVerified ?? this.isVerified,
      isDefault: isDefault ?? this.isDefault,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
