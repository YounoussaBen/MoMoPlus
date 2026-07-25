import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

class TransactionSafetyService {
  static const String emergencyNumber = '112';

  static Future<void> callEmergencyServices() async {
    final launched = await launchUrl(
      Uri(scheme: 'tel', path: emergencyNumber),
      mode: LaunchMode.externalApplication,
    );
    if (!launched) {
      throw Exception('Could not open the phone app.');
    }
  }

  static Future<void> shareCurrentLocation({
    required String transactionId,
    required String otherPartyName,
  }) async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw Exception('Turn on location services to share your location.');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw Exception(
        'Location permission is required to share your current location.',
      );
    }

    final position = await Geolocator.getCurrentPosition();
    final mapUrl =
        'https://maps.google.com/?q=${position.latitude},${position.longitude}';
    final message =
        'MoMo Plus safety update: I am meeting $otherPartyName for cash '
        'service ${_shortId(transactionId)}. My current location: $mapUrl';
    final uri = Uri(scheme: 'sms', queryParameters: {'body': message});
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched) {
      throw Exception('Could not open messaging to share your location.');
    }
  }

  static String _shortId(String id) {
    final compact = id.replaceAll('-', '');
    return compact.substring(0, compact.length < 8 ? compact.length : 8);
  }
}
