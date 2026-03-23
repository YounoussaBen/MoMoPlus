import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';

import '../../../core/data/services/backend_api_service.dart';
import '../../../core/services/native_map_launcher.dart';
import '../../../core/ui/theme/app_theme.dart';
import '../../../core/ui/widgets/profile_avatar.dart';
import '../domain/agent_route_preview.dart';
import '../domain/nearby_agent.dart';
import 'agent_detail_sheet.dart';
import 'discover_view_model.dart';

class DiscoverScreen extends StatelessWidget {
  const DiscoverScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) =>
          DiscoverViewModel(ctx.read<BackendApiService>())..locateAndLoad(),
      child: const _DiscoverBody(),
    );
  }
}

class _DiscoverBody extends StatefulWidget {
  const _DiscoverBody();

  @override
  State<_DiscoverBody> createState() => _DiscoverBodyState();
}

class _DiscoverBodyState extends State<_DiscoverBody> {
  final Completer<GoogleMapController> _mapCtrl = Completer();
  final DraggableScrollableController _sheetCtrl =
      DraggableScrollableController();
  String? _selectedAgentId;
  String? _lastCameraSignature;
  AgentRoutePreview? _activeRoute;
  bool _isRouteLoading = false;
  String? _routeErrorMessage;
  MapType _mapType = MapType.normal;

  // Cached custom marker icons.
  BitmapDescriptor? _certifiedMarker;
  BitmapDescriptor? _selfEnrolledMarker;
  BitmapDescriptor? _selectedMarker;
  bool _markersInitialised = false;

  Future<void> _initMarkerIcons() async {
    if (_markersInitialised) return;
    _markersInitialised = true;
    final dpr = MediaQuery.of(context).devicePixelRatio;
    final results = await Future.wait([
      _paintMarkerIcon(
        color: AppColors.primary,
        badgeIcon: Icons.verified,
        dpr: dpr,
      ),
      _paintMarkerIcon(color: const Color(0xFFFF9800), dpr: dpr),
      _paintMarkerIcon(color: const Color(0xFFE53935), dpr: dpr),
    ]);
    if (!mounted) return;
    setState(() {
      _certifiedMarker = results[0];
      _selfEnrolledMarker = results[1];
      _selectedMarker = results[2];
    });
  }

  static Future<BitmapDescriptor> _paintMarkerIcon({
    required Color color,
    IconData? badgeIcon,
    required double dpr,
  }) async {
    const double width = 48;
    const double height = 56;
    final double scale = dpr.clamp(1.0, 3.0);
    final int w = (width * scale).toInt();
    final int h = (height * scale).toInt();

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(
      recorder,
      Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
    );

    // Pin body (rounded rect with pointed bottom).
    final pinPaint = Paint()..color = color;
    final pinWidth = w * 0.75;
    final pinHeight = h * 0.68;
    final pinLeft = (w - pinWidth) / 2;
    final pinRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(pinLeft, 0, pinWidth, pinHeight),
      Radius.circular(pinWidth * 0.3),
    );
    canvas.drawRRect(pinRect, pinPaint);

    // Pin pointer triangle.
    final pointerPath = Path()
      ..moveTo(w / 2 - pinWidth * 0.18, pinHeight - 1)
      ..lineTo(w / 2, h.toDouble())
      ..lineTo(w / 2 + pinWidth * 0.18, pinHeight - 1)
      ..close();
    canvas.drawPath(pointerPath, pinPaint);

    // White circle inside pin.
    final circlePaint = Paint()..color = Colors.white;
    final circleRadius = pinWidth * 0.28;
    final circleCenter = Offset(w / 2, pinHeight * 0.46);
    canvas.drawCircle(circleCenter, circleRadius, circlePaint);

    // Badge for certified agents.
    if (badgeIcon != null) {
      final badgeRadius = w * 0.22;
      final badgeCenter = Offset(w - badgeRadius - 1, badgeRadius + 1);
      canvas.drawCircle(
        badgeCenter,
        badgeRadius,
        Paint()..color = Colors.white,
      );
      canvas.drawCircle(
        badgeCenter,
        badgeRadius - 1.5 * scale,
        Paint()..color = const Color(0xFF1976D2),
      );

      // Draw checkmark inside badge.
      final checkPaint = Paint()
        ..color = Colors.white
        ..strokeWidth = 2.0 * scale
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      final checkSize = badgeRadius * 0.55;
      final checkPath = Path()
        ..moveTo(badgeCenter.dx - checkSize * 0.55, badgeCenter.dy)
        ..lineTo(
          badgeCenter.dx - checkSize * 0.1,
          badgeCenter.dy + checkSize * 0.45,
        )
        ..lineTo(
          badgeCenter.dx + checkSize * 0.55,
          badgeCenter.dy - checkSize * 0.35,
        );
      canvas.drawPath(checkPath, checkPaint);
    }

    final picture = recorder.endRecording();
    final image = await picture.toImage(w, h);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);

    return BitmapDescriptor.bytes(
      bytes!.buffer.asUint8List(),
      width: width,
      height: height,
    );
  }

  @override
  void dispose() {
    _sheetCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<DiscoverViewModel>();

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: vm.isLocating
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(
                    color: AppColors.primary,
                    strokeWidth: 2,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Getting your location...',
                    style: TextStyle(
                      fontSize: 15,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            )
          : !vm.hasLocation
          ? _buildNoLocation(vm)
          : _buildContent(vm),
    );
  }

  Widget _buildNoLocation(DiscoverViewModel vm) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.location_off_outlined,
              size: 56,
              color: AppColors.textSecondary.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 16),
            const Text(
              'Location Required',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              vm.errorMessage ?? 'Enable location to find agents near you.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: vm.locateAndLoad,
              child: const Text('Enable Location'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(DiscoverViewModel vm) {
    final selectedAgent = _selectedAgent(vm);
    final safeTop = MediaQuery.of(context).padding.top;
    final bottomInset = MediaQuery.of(context).size.height * 0.24;
    _scheduleCameraUpdate(vm, selectedAgent);

    return Stack(
      children: [
        Positioned.fill(
          child: GoogleMap(
            initialCameraPosition: CameraPosition(
              target: LatLng(vm.userLat!, vm.userLon!),
              zoom: 13,
            ),
            onMapCreated: (controller) => _onMapCreated(controller, vm),
            onTap: (_) => _resetFocus(vm),
            markers: _buildMarkers(vm),
            circles: _buildCircles(vm),
            polylines: _buildPolylines(),
            padding: EdgeInsets.only(top: safeTop + 88, bottom: bottomInset),
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            buildingsEnabled: true,
            trafficEnabled: true,
            compassEnabled: true,
            tiltGesturesEnabled: true,
            rotateGesturesEnabled: true,
            mapType: _mapType,
          ),
        ),
        Positioned(
          top: safeTop + 12,
          left: 16,
          right: 16,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _MapInfoCard(
                  title: _mapPanelTitle(vm, selectedAgent),
                  subtitle: _mapPanelSubtitle(vm, selectedAgent),
                  isLoading: vm.isLoading || _isRouteLoading,
                ),
              ),
              const SizedBox(width: 12),
              _MapActionButton(
                icon: _mapType == MapType.normal
                    ? Icons.layers_outlined
                    : Icons.map_outlined,
                onTap: _toggleMapType,
              ),
              const SizedBox(width: 12),
              _MapActionButton(
                icon: Icons.my_location,
                onTap: () => _resetFocus(vm),
              ),
            ],
          ),
        ),
        DraggableScrollableSheet(
          controller: _sheetCtrl,
          initialChildSize: 0.30,
          minChildSize: 0.15,
          maxChildSize: 0.84,
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 20,
                    offset: const Offset(0, -6),
                  ),
                ],
              ),
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.textSecondary.withValues(alpha: 0.24),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _SortChip(
                        label: 'Distance',
                        selected: vm.sortBy == 'distance',
                        onTap: () => vm.setSortBy('distance'),
                      ),
                      _SortChip(
                        label: 'Rating',
                        selected: vm.sortBy == 'rating',
                        onTap: () => vm.setSortBy('rating'),
                      ),
                      GestureDetector(
                        onTap: () => _showRadiusFilter(vm),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.tune,
                                size: 16,
                                color: AppColors.textSecondary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '${vm.radius.toStringAsFixed(0)} km',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (selectedAgent != null) ...[
                    const SizedBox(height: 16),
                    _SelectedAgentCard(
                      agent: selectedAgent,
                      routePreview: _activeRoute,
                      isRouteLoading: _isRouteLoading,
                      routeErrorMessage: _routeErrorMessage,
                      onClear: () => _resetFocus(vm),
                      onViewDetails: () => _showAgentDetail(selectedAgent),
                      onStreetView: () => _openStreetView(selectedAgent),
                      onOpenDirections: () => _openDirections(selectedAgent),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Text(
                        'Nearby Agents',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${vm.agents.length}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (vm.isLoading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 48),
                      child: Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primary,
                          strokeWidth: 2,
                        ),
                      ),
                    )
                  else if (vm.agents.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 48),
                      child: Column(
                        children: [
                          Icon(
                            Icons.person_search_outlined,
                            size: 48,
                            color: AppColors.textSecondary.withValues(
                              alpha: 0.35,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'No agents found nearby',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Try increasing the search radius',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    )
                  else ...[
                    for (var i = 0; i < vm.agents.length; i++) ...[
                      _AgentCard(
                        agent: vm.agents[i],
                        selected: vm.agents[i].id == _selectedAgentId,
                        onTap: () => _handleAgentTap(vm, vm.agents[i]),
                      ),
                      if (i < vm.agents.length - 1) const SizedBox(height: 8),
                    ],
                  ],
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  NearbyAgent? _selectedAgent(DiscoverViewModel vm) {
    for (final agent in vm.agents) {
      if (agent.id == _selectedAgentId) return agent;
    }
    return null;
  }

  String _mapPanelTitle(DiscoverViewModel vm, NearbyAgent? selectedAgent) {
    if (selectedAgent == null) {
      return '${vm.agents.length} agent${vm.agents.length == 1 ? '' : 's'} nearby';
    }
    return 'Route to ${selectedAgent.fullName}';
  }

  String _mapPanelSubtitle(DiscoverViewModel vm, NearbyAgent? selectedAgent) {
    if (selectedAgent == null) {
      return 'Searching within ${vm.radius.toStringAsFixed(0)} km of your location';
    }
    if (_isRouteLoading) {
      return 'Fetching driving route and road geometry...';
    }
    if (_activeRoute != null) {
      if (_activeRoute!.isApproximate) {
        return '${_activeRoute!.summaryLabel} • fallback preview';
      }
      return '${_activeRoute!.summaryLabel} by road';
    }
    return '${selectedAgent.distanceLabel} away';
  }

  void _scheduleCameraUpdate(DiscoverViewModel vm, NearbyAgent? selectedAgent) {
    if (!vm.hasLocation) return;

    final signature = [
      vm.userLat?.toStringAsFixed(5),
      vm.userLon?.toStringAsFixed(5),
      vm.radius.toStringAsFixed(1),
      for (final agent in vm.agents)
        '${agent.id}:${agent.latitude.toStringAsFixed(5)},${agent.longitude.toStringAsFixed(5)}',
      'selected:${selectedAgent?.id ?? ''}',
    ].join('|');

    if (_lastCameraSignature == signature) return;
    _lastCameraSignature = signature;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (selectedAgent != null) {
        unawaited(_focusOnAgent(vm, selectedAgent, expandSheet: false));
      } else {
        unawaited(_fitMapToVisiblePoints(vm));
      }
    });
  }

  Future<void> _onMapCreated(
    GoogleMapController controller,
    DiscoverViewModel vm,
  ) async {
    if (!_mapCtrl.isCompleted) {
      _mapCtrl.complete(controller);
    }
    await Future<void>.delayed(const Duration(milliseconds: 80));
    if (!mounted) return;
    final selectedAgent = _selectedAgent(vm);
    if (selectedAgent != null) {
      await _focusOnAgent(vm, selectedAgent, expandSheet: false);
    } else {
      await _fitMapToVisiblePoints(vm);
    }
  }

  LatLngBounds _boundsForPoints(List<LatLng> points) {
    final latitudes = points.map((p) => p.latitude);
    final longitudes = points.map((p) => p.longitude);

    return LatLngBounds(
      southwest: LatLng(
        latitudes.reduce(math.min),
        longitudes.reduce(math.min),
      ),
      northeast: LatLng(
        latitudes.reduce(math.max),
        longitudes.reduce(math.max),
      ),
    );
  }

  Future<void> _fitMapToVisiblePoints(
    DiscoverViewModel vm, {
    List<LatLng>? extraPoints,
  }) async {
    if (!vm.hasLocation) return;

    final controller = await _mapCtrl.future;
    final points = <LatLng>[
      LatLng(vm.userLat!, vm.userLon!),
      ...vm.agents.map((a) => LatLng(a.latitude, a.longitude)),
      ...?extraPoints,
    ];

    if (points.length == 1) {
      await controller.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: points.first, zoom: 15.2),
        ),
      );
      return;
    }

    final bounds = _boundsForPoints(points);
    try {
      await controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 84));
    } catch (_) {
      await Future<void>.delayed(const Duration(milliseconds: 120));
      if (!mounted) return;
      await controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 84));
    }
  }

  AgentRoutePreview _fallbackRoute(DiscoverViewModel vm, NearbyAgent agent) {
    return AgentRoutePreview.directLine(
      origin: LatLng(vm.userLat!, vm.userLon!),
      destination: LatLng(agent.latitude, agent.longitude),
      distanceMeters: (agent.distanceKm * 1000).round(),
    );
  }

  Future<AgentRoutePreview> _loadRouteForAgent(
    DiscoverViewModel vm,
    NearbyAgent agent,
  ) async {
    if (_selectedAgentId == agent.id &&
        _activeRoute != null &&
        !_isRouteLoading) {
      return _activeRoute!;
    }

    setState(() {
      _isRouteLoading = true;
      _routeErrorMessage = null;
    });

    try {
      final route = await vm.loadRoutePreview(agent);
      if (!mounted || _selectedAgentId != agent.id) return route;
      setState(() => _activeRoute = route);
      return route;
    } catch (error) {
      final fallbackRoute = _fallbackRoute(vm, agent);
      if (!mounted || _selectedAgentId != agent.id) return fallbackRoute;
      setState(() {
        _activeRoute = fallbackRoute;
        _routeErrorMessage = error.toString().replaceFirst('Exception: ', '');
      });
      return fallbackRoute;
    } finally {
      if (mounted && _selectedAgentId == agent.id) {
        setState(() => _isRouteLoading = false);
      }
    }
  }

  Future<void> _focusMapForRoute(
    DiscoverViewModel vm,
    NearbyAgent agent,
    AgentRoutePreview route,
  ) async {
    final routePoints = route.hasGeometry
        ? route.points
        : [LatLng(agent.latitude, agent.longitude)];

    await _fitMapToVisiblePoints(vm, extraPoints: routePoints);

    if (route.isApproximate || agent.distanceKm > 3.5 || !route.hasGeometry) {
      return;
    }

    final controller = await _mapCtrl.future;
    await controller.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: route.focusPoint,
          zoom: 16.2,
          tilt: 58,
          bearing: route.bearing,
        ),
      ),
    );
  }

  Future<void> _focusOnAgent(
    DiscoverViewModel vm,
    NearbyAgent agent, {
    bool expandSheet = true,
  }) async {
    final isNewSelection = _selectedAgentId != agent.id;
    if (isNewSelection) {
      setState(() {
        _selectedAgentId = agent.id;
        _activeRoute = null;
        _routeErrorMessage = null;
      });
    }
    if (expandSheet && _sheetCtrl.isAttached) {
      unawaited(
        _sheetCtrl.animateTo(
          0.46,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
        ),
      );
    }

    await _fitMapToVisiblePoints(
      vm,
      extraPoints: [LatLng(agent.latitude, agent.longitude)],
    );
    final route = await _loadRouteForAgent(vm, agent);
    if (!mounted || _selectedAgentId != agent.id) return;
    await _focusMapForRoute(vm, agent, route);
  }

  Future<void> _resetFocus(DiscoverViewModel vm) async {
    if (mounted) {
      setState(() {
        _selectedAgentId = null;
        _activeRoute = null;
        _isRouteLoading = false;
        _routeErrorMessage = null;
      });
    }
    if (_sheetCtrl.isAttached) {
      unawaited(
        _sheetCtrl.animateTo(
          0.30,
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
        ),
      );
    }
    await _fitMapToVisiblePoints(vm);
  }

  void _handleAgentTap(DiscoverViewModel vm, NearbyAgent agent) {
    if (_selectedAgentId == agent.id) {
      _showAgentDetail(agent);
      return;
    }
    unawaited(_focusOnAgent(vm, agent));
  }

  Set<Marker> _buildMarkers(DiscoverViewModel vm) {
    _initMarkerIcons();

    final markers = <Marker>{
      Marker(
        markerId: const MarkerId('current_user'),
        position: LatLng(vm.userLat!, vm.userLon!),
        zIndexInt: 2,
        infoWindow: const InfoWindow(title: 'Your location'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
      ),
    };

    for (final agent in vm.agents) {
      final isSelected = _selectedAgentId == agent.id;
      BitmapDescriptor icon;
      if (isSelected && _selectedMarker != null) {
        icon = _selectedMarker!;
      } else if (agent.isCertified && _certifiedMarker != null) {
        icon = _certifiedMarker!;
      } else if (_selfEnrolledMarker != null) {
        icon = _selfEnrolledMarker!;
      } else {
        // Fallback while custom icons are loading.
        icon = BitmapDescriptor.defaultMarkerWithHue(
          isSelected
              ? BitmapDescriptor.hueRed
              : agent.isCertified
              ? BitmapDescriptor.hueGreen
              : BitmapDescriptor.hueOrange,
        );
      }

      markers.add(
        Marker(
          markerId: MarkerId(agent.id),
          position: LatLng(agent.latitude, agent.longitude),
          zIndexInt: isSelected ? 3 : 1,
          icon: icon,
          onTap: () => _handleAgentTap(vm, agent),
        ),
      );
    }

    return markers;
  }

  Set<Circle> _buildCircles(DiscoverViewModel vm) {
    return {
      Circle(
        circleId: const CircleId('search_radius'),
        center: LatLng(vm.userLat!, vm.userLon!),
        radius: vm.radius * 1000,
        fillColor: AppColors.primary.withValues(alpha: 0.08),
        strokeColor: AppColors.primary.withValues(alpha: 0.24),
        strokeWidth: 1,
      ),
    };
  }

  Set<Polyline> _buildPolylines() {
    final route = _activeRoute;
    if (route == null || !route.hasGeometry) return const {};

    return {
      Polyline(
        polylineId: const PolylineId('route_shadow'),
        points: route.points,
        color: Colors.black.withValues(alpha: 0.12),
        width: 10,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
        jointType: JointType.round,
      ),
      Polyline(
        polylineId: const PolylineId('route_main'),
        points: route.points,
        color: route.isApproximate
            ? AppColors.textSecondary
            : AppColors.primary,
        width: 6,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
        jointType: JointType.round,
        patterns: route.isApproximate
            ? [PatternItem.dash(18), PatternItem.gap(12)]
            : const [],
      ),
    };
  }

  Future<void> _openStreetView(NearbyAgent agent) async {
    try {
      await NativeMapLauncher.openStreetView(
        latitude: agent.latitude,
        longitude: agent.longitude,
        title: agent.fullName,
        bearing: _activeRoute?.bearing ?? 0,
      );
    } catch (error) {
      _showMapActionError(error.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _openDirections(NearbyAgent agent) async {
    try {
      await NativeMapLauncher.openDirections(
        latitude: agent.latitude,
        longitude: agent.longitude,
        label: agent.fullName,
      );
    } catch (error) {
      _showMapActionError(error.toString().replaceFirst('Exception: ', ''));
    }
  }

  void _showMapActionError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _showAgentDetail(NearbyAgent agent) {
    final vm = context.read<DiscoverViewModel>();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useRootNavigator: true,
      builder: (_) => AgentDetailSheet(
        agent: agent,
        routePreview: _selectedAgentId == agent.id ? _activeRoute : null,
        isRouteLoading: _selectedAgentId == agent.id && _isRouteLoading,
        routeErrorMessage: _selectedAgentId == agent.id
            ? _routeErrorMessage
            : null,
        onStreetView: () => _openStreetView(agent),
        onOpenDirections: () => _openDirections(agent),
        activeTransaction: vm.activeTransactionWith(agent.id),
      ),
    );
  }

  void _showRadiusFilter(DiscoverViewModel vm) {
    final options = [5.0, 10.0, 15.0, 25.0, 50.0];
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('Search Radius'),
        actions: options.map((r) {
          return CupertinoActionSheetAction(
            isDefaultAction: r == vm.radius,
            onPressed: () {
              Navigator.pop(ctx);
              vm.setRadius(r);
            },
            child: Text('${r.toStringAsFixed(0)} km'),
          );
        }).toList(),
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  void _toggleMapType() {
    setState(() {
      _mapType = _mapType == MapType.normal ? MapType.hybrid : MapType.normal;
    });
  }
}

class _SortChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _SortChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.1)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? AppColors.primary : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _MapInfoCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool isLoading;

  const _MapInfoCard({
    required this.title,
    required this.subtitle,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (isLoading) ...[
            const SizedBox(width: 12),
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MapActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _MapActionButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.96),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: SizedBox(
          width: 52,
          height: 52,
          child: Icon(icon, color: AppColors.primary, size: 22),
        ),
      ),
    );
  }
}

class _SelectedAgentCard extends StatelessWidget {
  final NearbyAgent agent;
  final AgentRoutePreview? routePreview;
  final bool isRouteLoading;
  final String? routeErrorMessage;
  final VoidCallback onClear;
  final VoidCallback onViewDetails;
  final VoidCallback onStreetView;
  final VoidCallback onOpenDirections;

  const _SelectedAgentCard({
    required this.agent,
    required this.routePreview,
    required this.isRouteLoading,
    required this.routeErrorMessage,
    required this.onClear,
    required this.onViewDetails,
    required this.onStreetView,
    required this.onOpenDirections,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Selected On Map',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                  letterSpacing: 0.6,
                ),
              ),
              const Spacer(),
              TextButton(onPressed: onClear, child: const Text('Clear')),
            ],
          ),
          Row(
            children: [
              ProfileAvatar(
                imageUrl: agent.selfieUrl,
                fallbackLetter: agent.fullName.isNotEmpty
                    ? agent.fullName[0]
                    : '?',
                radius: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            agent.fullName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        if (agent.isCertified) ...[
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.verified,
                            size: 16,
                            color: AppColors.primary,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      routePreview?.summaryLabel ??
                          '${agent.distanceLabel} away',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton(
                onPressed: onViewDetails,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: BorderSide(
                    color: AppColors.primary.withValues(alpha: 0.25),
                  ),
                ),
                child: const Text('Details'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _RouteInfoChip(
                icon: Icons.route_rounded,
                label: isRouteLoading
                    ? 'Loading route...'
                    : routePreview?.summaryLabel ?? 'Direct distance',
              ),
              _RouteInfoChip(
                icon: routePreview?.isApproximate == true
                    ? Icons.near_me_outlined
                    : Icons.directions_car_filled_outlined,
                label: routePreview?.isApproximate == true
                    ? 'Approximate path'
                    : 'Road route',
              ),
              if (routeErrorMessage != null)
                const _RouteInfoChip(
                  icon: Icons.info_outline,
                  label: 'Google route unavailable',
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onStreetView,
                  icon: const Icon(Icons.streetview_outlined),
                  label: const Text('Street View'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onOpenDirections,
                  icon: const Icon(Icons.navigation_outlined),
                  label: const Text('Directions'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RouteInfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _RouteInfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _AgentCard extends StatelessWidget {
  final NearbyAgent agent;
  final VoidCallback onTap;
  final bool selected;
  const _AgentCard({
    required this.agent,
    required this.onTap,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.32)
                : AppColors.divider,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            ProfileAvatar(
              imageUrl: agent.selfieUrl,
              fallbackLetter: agent.fullName.isNotEmpty
                  ? agent.fullName[0]
                  : '?',
              radius: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          agent.fullName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (agent.isCertified) ...[
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.verified,
                          size: 16,
                          color: AppColors.primary,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on,
                        size: 14,
                        color: AppColors.textSecondary.withValues(alpha: 0.6),
                      ),
                      const SizedBox(width: 2),
                      Text(
                        agent.distanceLabel,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      if (agent.rating > 0) ...[
                        const SizedBox(width: 12),
                        Icon(
                          Icons.star,
                          size: 14,
                          color: Colors.amber.shade600,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          agent.rating.toStringAsFixed(1),
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                      if (agent.maxAmount != null) ...[
                        const SizedBox(width: 12),
                        Text(
                          'Up to GHS ${agent.maxAmount!.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: selected ? AppColors.primary : AppColors.textSecondary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
