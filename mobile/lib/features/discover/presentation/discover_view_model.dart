import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/data/services/backend_api_service.dart';
import '../domain/nearby_agent.dart';

class DiscoverViewModel extends ChangeNotifier {
  final BackendApiService _api;

  List<NearbyAgent> _agents = [];
  bool _isLoading = false;
  String? _errorMessage;
  double? _userLat;
  double? _userLon;
  double _radius = 10.0;
  String _sortBy = 'distance';
  bool _isLocating = false;

  DiscoverViewModel(this._api);

  List<NearbyAgent> get agents => _agents;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  double? get userLat => _userLat;
  double? get userLon => _userLon;
  double get radius => _radius;
  String get sortBy => _sortBy;
  bool get isLocating => _isLocating;
  bool get hasLocation => _userLat != null && _userLon != null;

  Future<void> locateAndLoad() async {
    _isLocating = true;
    notifyListeners();
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        _errorMessage = 'Location permission denied';
        _isLocating = false;
        notifyListeners();
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      _userLat = pos.latitude;
      _userLon = pos.longitude;
      _isLocating = false;
      notifyListeners();
      await loadAgents();
    } catch (e) {
      _errorMessage = 'Could not get location';
      _isLocating = false;
      notifyListeners();
    }
  }

  Future<void> loadAgents() async {
    if (_userLat == null || _userLon == null) return;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final data = await _api.getNearbyAgents(
        lat: _userLat!,
        lon: _userLon!,
        radius: _radius,
        sortBy: _sortBy,
      );
      _agents = data
          .map((j) => NearbyAgent.fromJson(j as Map<String, dynamic>))
          .toList();
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setSortBy(String sort) {
    if (_sortBy == sort) return;
    _sortBy = sort;
    notifyListeners();
    loadAgents();
  }

  void setRadius(double r) {
    if (_radius == r) return;
    _radius = r;
    notifyListeners();
    loadAgents();
  }
}
