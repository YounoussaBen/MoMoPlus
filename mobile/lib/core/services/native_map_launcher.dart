import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class NativeMapLauncher {
  static const MethodChannel _channel = MethodChannel('momoplus/maps');

  static Future<void> openStreetView({
    required double latitude,
    required double longitude,
    required String title,
    double bearing = 0,
  }) async {
    _ensureMobile('Street View');
    await _channel.invokeMethod<void>('openStreetView', {
      'latitude': latitude,
      'longitude': longitude,
      'title': title,
      'bearing': bearing,
    });
  }

  static Future<void> openDirections({
    required double latitude,
    required double longitude,
    required String label,
  }) async {
    _ensureMobile('Google Maps directions');
    await _channel.invokeMethod<void>('openDirections', {
      'latitude': latitude,
      'longitude': longitude,
      'label': label,
    });
  }

  static void _ensureMobile(String featureName) {
    if (defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS) {
      throw Exception('$featureName is only available on mobile devices.');
    }
  }
}
