class AgentProfile {
  final String id;
  final String fullName;
  final String email;
  final double? latitude;
  final double? longitude;
  final bool isAvailable;
  final double? maxAmount;
  final double minAmount;
  final double serviceRadiusKm;
  final String bio;
  final double rating;
  final int totalRatings;
  final String agentType;

  const AgentProfile({
    required this.id,
    required this.fullName,
    required this.email,
    this.latitude,
    this.longitude,
    required this.isAvailable,
    this.maxAmount,
    required this.minAmount,
    required this.serviceRadiusKm,
    required this.bio,
    required this.rating,
    required this.totalRatings,
    required this.agentType,
  });

  bool get isCertified => agentType == 'certified';
  bool get hasLocation => latitude != null && longitude != null;

  factory AgentProfile.fromJson(Map<String, dynamic> json) {
    return AgentProfile(
      id: json['id'] as String,
      fullName: json['full_name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      latitude: _toDouble(json['latitude']),
      longitude: _toDouble(json['longitude']),
      isAvailable: json['is_available'] as bool? ?? false,
      maxAmount: _toDouble(json['max_amount']),
      minAmount: _toDouble(json['min_amount']) ?? 0,
      serviceRadiusKm: _toDouble(json['service_radius_km']) ?? 5,
      bio: json['bio'] as String? ?? '',
      rating: _toDouble(json['rating']) ?? 0,
      totalRatings: json['total_ratings'] as int? ?? 0,
      agentType: json['agent_type'] as String? ?? 'self_enrolled',
    );
  }

  static double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }
}
