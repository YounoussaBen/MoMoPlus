import 'dart:math' as math;

import 'package:google_maps_flutter/google_maps_flutter.dart';

class AgentRoutePreview {
  final List<LatLng> points;
  final int distanceMeters;
  final int? durationSeconds;
  final bool isApproximate;

  const AgentRoutePreview({
    required this.points,
    required this.distanceMeters,
    required this.durationSeconds,
    this.isApproximate = false,
  });

  factory AgentRoutePreview.fromJson(Map<String, dynamic> json) {
    final encodedPolyline = json['encoded_polyline'] as String? ?? '';
    return AgentRoutePreview(
      points: _decodePolyline(encodedPolyline),
      distanceMeters: _toInt(json['distance_meters']) ?? 0,
      durationSeconds: _toInt(json['duration_seconds']),
      isApproximate: false,
    );
  }

  factory AgentRoutePreview.directLine({
    required LatLng origin,
    required LatLng destination,
    required int distanceMeters,
  }) {
    return AgentRoutePreview(
      points: [origin, destination],
      distanceMeters: distanceMeters,
      durationSeconds: null,
      isApproximate: true,
    );
  }

  bool get hasGeometry => points.length >= 2;

  String get distanceLabel {
    if (distanceMeters < 1000) {
      return '$distanceMeters m';
    }

    final distanceKm = distanceMeters / 1000;
    final fractionDigits = distanceKm < 10 ? 1 : 0;
    return '${distanceKm.toStringAsFixed(fractionDigits)} km';
  }

  String get durationLabel {
    final seconds = durationSeconds;
    if (seconds == null || seconds <= 0) return 'ETA unavailable';

    final minutes = (seconds / 60).round();
    if (minutes < 60) return '$minutes min';

    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;
    if (remainingMinutes == 0) return '$hours hr';
    return '$hours hr $remainingMinutes min';
  }

  String get summaryLabel {
    if (isApproximate) return 'Approx. $distanceLabel';
    return '$distanceLabel • $durationLabel';
  }

  double get bearing {
    if (!hasGeometry) return 0;
    return _bearingBetween(points.first, points.last);
  }

  LatLng get focusPoint {
    if (points.isEmpty) return const LatLng(0, 0);
    return points[points.length ~/ 2];
  }

  static int? _toInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static List<LatLng> _decodePolyline(String encoded) {
    if (encoded.isEmpty) return const [];

    final points = <LatLng>[];
    var index = 0;
    var latitude = 0;
    var longitude = 0;

    while (index < encoded.length) {
      var result = 0;
      var shift = 0;
      var byte = 0;
      do {
        byte = encoded.codeUnitAt(index++) - 63;
        result |= (byte & 0x1f) << shift;
        shift += 5;
      } while (byte >= 0x20);
      final deltaLatitude = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      latitude += deltaLatitude;

      result = 0;
      shift = 0;
      do {
        byte = encoded.codeUnitAt(index++) - 63;
        result |= (byte & 0x1f) << shift;
        shift += 5;
      } while (byte >= 0x20);
      final deltaLongitude = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      longitude += deltaLongitude;

      points.add(LatLng(latitude / 1e5, longitude / 1e5));
    }

    return points;
  }

  static double _bearingBetween(LatLng start, LatLng end) {
    final startLatitude = _degreesToRadians(start.latitude);
    final endLatitude = _degreesToRadians(end.latitude);
    final deltaLongitude = _degreesToRadians(end.longitude - start.longitude);

    final y = math.sin(deltaLongitude) * math.cos(endLatitude);
    final x =
        math.cos(startLatitude) * math.sin(endLatitude) -
        math.sin(startLatitude) *
            math.cos(endLatitude) *
            math.cos(deltaLongitude);

    return (_radiansToDegrees(math.atan2(y, x)) + 360) % 360;
  }

  static double _degreesToRadians(double degrees) => degrees * math.pi / 180;

  static double _radiansToDegrees(double radians) => radians * 180 / math.pi;
}
