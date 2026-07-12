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
  String? _sessionId;
  bool _isSessionActive = false;
  bool _isDisposed = false;
  int _sessionGeneration = 0;

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
  double get radius => _radius;
  bool get isLocating => _isLocating;
  bool get hasLocation => _userLat != null && _userLon != null;
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
    final generation = _sessionGeneration;
    _isLocating = true;
    _errorMessage = null;
    _notifyListeners();
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (!_isCurrentSession(generation)) return;
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
        if (!_isCurrentSession(generation)) return;
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        _errorMessage = 'Location permission denied';
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      if (!_isCurrentSession(generation)) return;
      _userLat = pos.latitude;
      _userLon = pos.longitude;
      _routeCache.clear();
      await loadAgents();
    } catch (e) {
      if (!_isCurrentSession(generation)) return;
      _errorMessage = 'Could not get location';
    } finally {
      if (_isCurrentSession(generation)) {
        _isLocating = false;
        _notifyListeners();
      }
    }
  }

  Future<void> loadAgents() async {
    if (!_isSessionActive || _isDisposed) return;
    final inFlight = _loadAgentsFuture;
    if (inFlight != null) return inFlight;

    final generation = _sessionGeneration;
    final future = _loadAgentsInternal(generation);
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

  Future<void> _loadAgentsInternal(int generation) async {
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
      if (!_isCurrentSession(generation)) return;
      _agents = data
          .map((j) => NearbyAgent.fromJson(j as Map<String, dynamic>))
          .toList();
    } catch (e) {
      if (!_isCurrentSession(generation)) return;
      _errorMessage = friendlyErrorMessage(e);
    } finally {
      if (_isCurrentSession(generation)) {
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
    final generation = _sessionGeneration;

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
    if (!_isCurrentSession(generation)) {
      throw StateError('The signed-in session changed.');
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
    _routeCache.clear();
  }

  bool _isCurrentSession(int generation) =>
      !_isDisposed && _isSessionActive && generation == _sessionGeneration;

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
