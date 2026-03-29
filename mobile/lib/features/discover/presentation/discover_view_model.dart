import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import '../../../core/data/services/backend_api_service.dart';
import '../../../core/utils/error_helpers.dart';
import '../domain/agent_route_preview.dart';
import '../domain/nearby_agent.dart';

const Duration _discoverRefreshInterval = Duration(seconds: 10);

class DiscoverViewModel extends ChangeNotifier {
  final BackendApiService _api;

  List<NearbyAgent> _agents = [];
  bool _isLoading = false;
  String? _errorMessage;
  bool _hasLoadedAgents = false;
  double? _userLat;
  double? _userLon;
  double _radius = 10.0;
  bool _isLocating = false;
  final Map<String, AgentRoutePreview> _routeCache = {};
  Timer? _refreshTimer;
  Future<void>? _loadAgentsFuture;

  DiscoverViewModel(this._api) {
    _refreshTimer = Timer.periodic(
      _discoverRefreshInterval,
      (_) => loadAgents(),
    );
  }

  List<NearbyAgent> get agents => _agents;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  double? get userLat => _userLat;
  double? get userLon => _userLon;
  double get radius => _radius;
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
      _routeCache.clear();
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
    final inFlight = _loadAgentsFuture;
    if (inFlight != null) return inFlight;

    final future = _loadAgentsInternal();
    _loadAgentsFuture = future;
    future.whenComplete(() => _loadAgentsFuture = null);
    return future;
  }

  Future<void> _loadAgentsInternal() async {
    if (_userLat == null || _userLon == null) return;
    _isLoading = !_hasLoadedAgents && _agents.isEmpty;
    _errorMessage = null;
    notifyListeners();
    try {
      final data = await _api.getNearbyAgents(
        lat: _userLat!,
        lon: _userLon!,
        radius: _radius,
      );
      _agents = data
          .map((j) => NearbyAgent.fromJson(j as Map<String, dynamic>))
          .toList();
    } catch (e) {
      _errorMessage = friendlyErrorMessage(e);
    } finally {
      _hasLoadedAgents = true;
      _isLoading = false;
      notifyListeners();
    }
  }

  void setRadius(double r) {
    if (_radius == r) return;
    _radius = r;
    notifyListeners();
    loadAgents();
  }

  Future<AgentRoutePreview> loadRoutePreview(NearbyAgent agent) async {
    if (!hasLocation) {
      throw Exception('Your location is unavailable.');
    }

    final cacheKey = [
      agent.id,
      _userLat!.toStringAsFixed(5),
      _userLon!.toStringAsFixed(5),
      agent.latitude.toStringAsFixed(5),
      agent.longitude.toStringAsFixed(5),
    ].join(':');
    final cached = _routeCache[cacheKey];
    if (cached != null) return cached;

    final data = await _api.getAgentRoutePreview(
      originLatitude: _userLat!,
      originLongitude: _userLon!,
      destinationLatitude: agent.latitude,
      destinationLongitude: agent.longitude,
    );
    final route = AgentRoutePreview.fromJson(data);
    final normalizedRoute = route.hasGeometry
        ? route
        : AgentRoutePreview.directLine(
            origin: LatLng(_userLat!, _userLon!),
            destination: LatLng(agent.latitude, agent.longitude),
            distanceMeters: (agent.distanceKm * 1000).round(),
          );
    _routeCache[cacheKey] = normalizedRoute;
    return normalizedRoute;
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }
}
