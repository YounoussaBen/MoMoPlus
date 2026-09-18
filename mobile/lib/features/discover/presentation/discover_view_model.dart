import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import '../../../core/data/services/backend_api_service.dart';
import '../../../core/utils/error_helpers.dart';
import '../domain/agent_route_preview.dart';
import '../domain/nearby_agent.dart';

const Duration _discoverRefreshInterval = Duration(seconds: 10);
const Duration _discoverLocationTimeout = Duration(seconds: 12);

// Match the agent service-area map so Discover can render before GPS resolves.
const double discoverFallbackLatitude = 5.6037;
const double discoverFallbackLongitude = -0.1870;

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
  bool _usesPinnedLocation = false;
  final Map<String, AgentRoutePreview> _routeCache = {};
  Timer? _refreshTimer;
  Future<void>? _loadAgentsFuture;
  String? _sessionId;
  bool _isSessionActive = false;
  bool _isDisposed = false;
  int _sessionGeneration = 0;
  int _locationGeneration = 0;

  DiscoverViewModel(this._api, {bool autoStart = true}) {
    if (autoStart) {
      _startSession();
    }
  }

  List<NearbyAgent> get agents => _agents;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  double? get userLat => _userLat;
  double? get userLon => _userLon;
  double get mapLatitude => _userLat ?? discoverFallbackLatitude;
  double get mapLongitude => _userLon ?? discoverFallbackLongitude;
  double get radius => _radius;
  bool get isLocating => _isLocating;
  bool get hasLocation => _userLat != null && _userLon != null;
  bool get usesPinnedLocation => hasLocation && _usesPinnedLocation;
  bool get hasDeviceLocation => hasLocation && !_usesPinnedLocation;
  bool get isSessionActive => _isSessionActive;

  /// Switches discovery state to [sessionId] after clearing cached agents,
  /// location, and route previews belonging to the previous session.
  void setSession(String? sessionId) {
    if (sessionId == null) {
      clearSession();
      return;
    }
    if (_isSessionActive && _sessionId == sessionId) return;
    _startSession(sessionId: sessionId);
  }

  /// Stops refresh work and immediately removes all session-scoped map data.
  void clearSession() {
    if (_isDisposed) return;
    _resetSessionState();
    _notifyListeners();
  }

  void startAutoRefresh() {
    if (!_isSessionActive || _refreshTimer != null || _isDisposed) return;
    _refreshTimer = Timer.periodic(
      _discoverRefreshInterval,
      (_) => unawaited(loadAgents()),
    );
  }

  void stopAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  Future<void> locateAndLoad() async {
    if (!_isSessionActive || _isDisposed) return;
    final sessionGeneration = _sessionGeneration;
    final locationGeneration = ++_locationGeneration;
    _loadAgentsFuture = null;
    _isLoading = false;
    _isLocating = true;
    _errorMessage = null;
    _notifyListeners();
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!_isCurrentLocationRequest(sessionGeneration, locationGeneration)) {
        return;
      }
      if (!serviceEnabled) {
        _errorMessage = 'Turn on Location Services to find agents near you.';
        return;
      }

      LocationPermission perm = await Geolocator.checkPermission();
      if (!_isCurrentLocationRequest(sessionGeneration, locationGeneration)) {
        return;
      }
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
        if (!_isCurrentLocationRequest(sessionGeneration, locationGeneration)) {
          return;
        }
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        _errorMessage = 'Allow location access to find agents near you.';
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: _discoverLocationTimeout,
        ),
      );
      if (!_isCurrentLocationRequest(sessionGeneration, locationGeneration)) {
        return;
      }
      _userLat = pos.latitude;
      _userLon = pos.longitude;
      _usesPinnedLocation = false;
      _agents = [];
      _hasLoadedAgents = false;
      _routeCache.clear();
      // Render the located map before waiting for nearby-agent data.
      _isLocating = false;
      _notifyListeners();
      await loadAgents();
    } on TimeoutException {
      if (!_isCurrentLocationRequest(sessionGeneration, locationGeneration)) {
        return;
      }
      _errorMessage = 'We could not determine your location.';
    } catch (e) {
      if (!_isCurrentLocationRequest(sessionGeneration, locationGeneration)) {
        return;
      }
      _errorMessage = 'Could not get location';
    } finally {
      if (_isCurrentLocationRequest(sessionGeneration, locationGeneration)) {
        _isLocating = false;
        _notifyListeners();
      }
    }
  }

  Future<void> setSearchLocation({
    required double latitude,
    required double longitude,
  }) async {
    if (!_isSessionActive || _isDisposed) return;
    if (!latitude.isFinite || latitude < -90 || latitude > 90) {
      throw ArgumentError.value(
        latitude,
        'latitude',
        'Must be between -90 and 90.',
      );
    }
    if (!longitude.isFinite || longitude < -180 || longitude > 180) {
      throw ArgumentError.value(
        longitude,
        'longitude',
        'Must be between -180 and 180.',
      );
    }

    _locationGeneration++;
    _loadAgentsFuture = null;
    _isLoading = false;
    _isLocating = false;
    _usesPinnedLocation = true;
    _userLat = latitude;
    _userLon = longitude;
    _agents = [];
    _hasLoadedAgents = false;
    _errorMessage = null;
    _routeCache.clear();
    _notifyListeners();
    await loadAgents();
  }

  Future<void> loadAgents() async {
    if (!_isSessionActive || _isDisposed) return;
    final inFlight = _loadAgentsFuture;
    if (inFlight != null) return inFlight;

    final sessionGeneration = _sessionGeneration;
    final locationGeneration = _locationGeneration;
    final future = _loadAgentsInternal(sessionGeneration, locationGeneration);
    _loadAgentsFuture = future;
    unawaited(
      future.whenComplete(() {
        if (identical(_loadAgentsFuture, future)) {
          _loadAgentsFuture = null;
        }
      }),
    );
    return future;
  }

  Future<void> _loadAgentsInternal(
    int sessionGeneration,
    int locationGeneration,
  ) async {
    if (_userLat == null || _userLon == null) return;
    _isLoading = !_hasLoadedAgents && _agents.isEmpty;
    _errorMessage = null;
    _notifyListeners();
    try {
      final data = await _api.getNearbyAgents(
        lat: _userLat!,
        lon: _userLon!,
        radius: _radius,
      );
      if (!_isCurrentLocationRequest(sessionGeneration, locationGeneration)) {
        return;
      }
      _agents = data
          .map((j) => NearbyAgent.fromJson(j as Map<String, dynamic>))
          .toList();
    } catch (e) {
      if (!_isCurrentLocationRequest(sessionGeneration, locationGeneration)) {
        return;
      }
      _errorMessage = friendlyErrorMessage(e);
    } finally {
      if (_isCurrentLocationRequest(sessionGeneration, locationGeneration)) {
        _hasLoadedAgents = true;
        _isLoading = false;
        _notifyListeners();
      }
    }
  }

  void setRadius(double r) {
    if (!_isSessionActive || _isDisposed || _radius == r) return;
    _radius = r;
    _notifyListeners();
    unawaited(loadAgents());
  }

  Future<AgentRoutePreview> loadRoutePreview(NearbyAgent agent) async {
    if (!_isSessionActive || _isDisposed || !hasLocation) {
      throw Exception('Your location is unavailable.');
    }
    final sessionGeneration = _sessionGeneration;
    final locationGeneration = _locationGeneration;

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
    if (!_isCurrentLocationRequest(sessionGeneration, locationGeneration)) {
      throw StateError('The search location changed.');
    }
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

  void _startSession({String? sessionId}) {
    _resetSessionState();
    _sessionId = sessionId;
    _isSessionActive = true;
    startAutoRefresh();
  }

  void _resetSessionState() {
    stopAutoRefresh();
    _sessionGeneration++;
    _locationGeneration++;
    _sessionId = null;
    _isSessionActive = false;
    _loadAgentsFuture = null;
    _agents = [];
    _isLoading = false;
    _errorMessage = null;
    _hasLoadedAgents = false;
    _userLat = null;
    _userLon = null;
    _radius = 10.0;
    _isLocating = false;
    _usesPinnedLocation = false;
    _routeCache.clear();
  }

  bool _isCurrentSession(int generation) =>
      !_isDisposed && _isSessionActive && generation == _sessionGeneration;

  bool _isCurrentLocationRequest(
    int sessionGeneration,
    int locationGeneration,
  ) =>
      _isCurrentSession(sessionGeneration) &&
      locationGeneration == _locationGeneration;

  void _notifyListeners() {
    if (!_isDisposed) notifyListeners();
  }

  @override
  void dispose() {
    if (_isDisposed) return;
    _resetSessionState();
    _isDisposed = true;
    super.dispose();
  }
}
