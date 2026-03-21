class NearbyAgent {
  final String id;
  final String fullName;
  final double latitude;
  final double longitude;
  final bool isAvailable;
  final double? maxAmount;
  final double minAmount;
  final double rating;
  final int totalRatings;
  final String agentType;
  final double distanceKm;

  const NearbyAgent({
    required this.id,
    required this.fullName,
    required this.latitude,
    required this.longitude,
    required this.isAvailable,
    this.maxAmount,
    required this.minAmount,
    required this.rating,
    required this.totalRatings,
    required this.agentType,
    required this.distanceKm,
  });

  bool get isCertified => agentType == 'certified';

  String get distanceLabel {
    if (distanceKm < 1) {
      return '${(distanceKm * 1000).round()} m';
    }
    return '${distanceKm.toStringAsFixed(1)} km';
  }

  factory NearbyAgent.fromJson(Map<String, dynamic> json) {
    return NearbyAgent(
      id: json['id'] as String,
      fullName: json['full_name'] as String? ?? '',
      latitude: _toDouble(json['latitude']) ?? 0,
      longitude: _toDouble(json['longitude']) ?? 0,
      isAvailable: json['is_available'] as bool? ?? false,
      maxAmount: _toDouble(json['max_amount']),
      minAmount: _toDouble(json['min_amount']) ?? 0,
      rating: _toDouble(json['rating']) ?? 0,
      totalRatings: json['total_ratings'] as int? ?? 0,
      agentType: json['agent_type'] as String? ?? 'self_enrolled',
      distanceKm: _toDouble(json['distance_km']) ?? 0,
    );
  }

  static double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }
}
