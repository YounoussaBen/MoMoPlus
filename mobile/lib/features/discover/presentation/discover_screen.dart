import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';

import '../../../core/data/services/backend_api_service.dart';
import '../../../core/services/native_map_launcher.dart';
import '../../../core/ui/theme/app_theme_extension.dart';
import '../../../core/ui/theme/app_map_style.dart';
import '../../../core/ui/widgets/profile_avatar.dart';
import '../../auth/presentation/auth_view_model.dart';
import '../../loans/domain/loan.dart';
import '../../loans/presentation/loan_view_model.dart';
import '../../transactions/domain/physical_transaction.dart';
import '../../transactions/presentation/transaction_view_model.dart';
import '../domain/agent_route_preview.dart';
import '../domain/nearby_agent.dart';
import 'agent_detail_sheet.dart';
import 'discover_view_model.dart';

class DiscoverScreen extends StatelessWidget {
  const DiscoverScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) {
        final viewModel = DiscoverViewModel(
          ctx.read<BackendApiService>(),
          autoStart: false,
        );
        viewModel.setSession(ctx.read<AuthViewModel>().currentUser?.id);
        viewModel.locateAndLoad();
        return viewModel;
      },
      child: const _DiscoverBody(),
    );
  }
}

class _DiscoverBody extends StatefulWidget {
  const _DiscoverBody();

  @override
  State<_DiscoverBody> createState() => _DiscoverBodyState();
}

class _DiscoverBodyState extends State<_DiscoverBody>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
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
  late final AnimationController _skeletonController;
  late final Animation<double> _skeletonPulse;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _skeletonController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _skeletonPulse = CurvedAnimation(
      parent: _skeletonController,
      curve: Curves.easeInOut,
    );
  }

  Future<void> _initMarkerIcons() async {
    if (_markersInitialised) return;
    _markersInitialised = true;
    final dpr = MediaQuery.of(context).devicePixelRatio;
    final results = await Future.wait([
      _paintMarkerIcon(
        color: context.appColors.brandAccent,
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
    WidgetsBinding.instance.removeObserver(this);
    _skeletonController.dispose();
    _sheetCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;
    final vm = context.read<DiscoverViewModel>();
    if (state == AppLifecycleState.resumed) {
      vm.startAutoRefresh();
      if (!vm.hasLocation) return;
      vm.loadAgents();
      return;
    }
    vm.stopAutoRefresh();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<DiscoverViewModel>();
    final activeTransactions = context
        .select<TransactionViewModel, List<PhysicalTransaction>>(
          (txnVm) => txnVm.activeTransactions,
        );
    final ongoingLoans = context.select<LoanViewModel, List<Loan>>(
      (loanVm) => loanVm.ongoingLoans,
    );

    return Scaffold(
      backgroundColor: context.appColors.canvas,
      body: vm.isLocating
          ? _buildLocatingState()
          : !vm.hasLocation
          ? _buildNoLocation(vm)
          : _buildContent(vm, activeTransactions, ongoingLoans),
    );
  }

  Widget _buildLocatingState() {
    final mediaQuery = MediaQuery.of(context);
    final safeTop = mediaQuery.padding.top;
    final bottomPadding = mediaQuery.padding.bottom;
    final size = mediaQuery.size;

    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  context.appColors.canvas,
                  context.appColors.surfaceSubtle,
                  context.appColors.brandSoft,
                ],
              ),
            ),
            child: Stack(
              children: [
                Positioned(
                  top: safeTop + 80,
                  left: -40,
                  child: _BackdropOrb(
                    size: 180,
                    color: context.appColors.brandSoft,
                  ),
                ),
                Positioned(
                  top: safeTop + 200,
                  right: -30,
                  child: _BackdropOrb(
                    size: 140,
                    color: const Color(0xFFFFC95B).withValues(alpha: 0.16),
                  ),
                ),
                Positioned(
                  bottom: size.height * 0.34,
                  left: 28,
                  child: _MapGhostMarker(
                    animation: _skeletonPulse,
                    color: context.appColors.brandAccent,
                  ),
                ),
                Positioned(
                  top: safeTop + 210,
                  right: 52,
                  child: _MapGhostMarker(
                    animation: _skeletonPulse,
                    color: const Color(0xFFFF9800),
                  ),
                ),
                Positioned(
                  top: safeTop + 320,
                  left: size.width * 0.42,
                  child: _MapGhostMarker(
                    animation: _skeletonPulse,
                    color: const Color(0xFFE53935),
                  ),
                ),
              ],
            ),
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
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: context.appColors.surfaceSection,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: context.appColors.scrim.withValues(alpha: 0.08),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Finding Agents Nearby',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: context.appColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Preparing your location and loading live availability.',
                        style: TextStyle(
                          fontSize: 12,
                          color: context.appColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _SkeletonBlock(
                        animation: _skeletonPulse,
                        height: 8,
                        width: 150,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              const _LoadingActionButton(icon: Icons.layers_outlined),
              const SizedBox(width: 12),
              const _LoadingActionButton(icon: Icons.my_location),
            ],
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            height: size.height * 0.54,
            padding: EdgeInsets.fromLTRB(16, 12, 16, bottomPadding + 110),
            decoration: BoxDecoration(
              color: context.appColors.surfaceSection,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
              boxShadow: [
                BoxShadow(
                  color: context.appColors.scrim.withValues(alpha: 0.1),
                  blurRadius: 20,
                  offset: const Offset(0, -6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: context.appColors.surfaceInteractive,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [_StaticLoadingChip(label: 'Radius')],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Text(
                      'Nearby Agents',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: context.appColors.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    _SkeletonBlock(
                      animation: _skeletonPulse,
                      height: 18,
                      width: 28,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  'We are warming up your map and nearby agent list.',
                  style: TextStyle(
                    fontSize: 13,
                    color: context.appColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 18),
                Expanded(
                  child: ListView.separated(
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: 4,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 10),
                    itemBuilder: (context, index) =>
                        _LoadingAgentCard(animation: _skeletonPulse),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
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
              color: context.appColors.textMuted,
            ),
            const SizedBox(height: 16),
            Text(
              'Location Required',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: context.appColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              vm.errorMessage ?? 'Enable location to find agents near you.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: context.appColors.textSecondary,
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

  Widget _buildContent(
    DiscoverViewModel vm,
    List<PhysicalTransaction> activeTransactions,
    List<Loan> ongoingLoans,
  ) {
    final selectedAgent = _selectedAgent(vm);
    final safeTop = MediaQuery.of(context).padding.top;
    final bottomInset = MediaQuery.of(context).size.height * 0.24;
    _scheduleCameraUpdate(vm, selectedAgent);

    return Stack(
      children: [
        Positioned.fill(
          child: GoogleMap(
            style: AppMapStyle.forBrightness(Theme.of(context).brightness),
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
                color: context.appColors.surfaceSection,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
                boxShadow: [
                  BoxShadow(
                    color: context.appColors.scrim.withValues(alpha: 0.1),
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
                        color: context.appColors.surfaceInteractive,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: () => _showRadiusFilter(vm),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: context.appColors.surfaceInteractive,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.tune,
                            size: 16,
                            color: context.appColors.textSecondary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${vm.radius.toStringAsFixed(0)} km',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: context.appColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (selectedAgent != null) ...[
                    const SizedBox(height: 16),
                    _SelectedAgentCard(
                      agent: selectedAgent,
                      routePreview: _activeRoute,
                      isRouteLoading: _isRouteLoading,
                      routeErrorMessage: _routeErrorMessage,
                      onClear: () => _resetFocus(vm),
                      onViewDetails: () => _showAgentDetail(
                        selectedAgent,
                        activeTransactions,
                        ongoingLoans,
                      ),
                      onStreetView: () => _openStreetView(selectedAgent),
                      onOpenDirections: () => _openDirections(selectedAgent),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Text(
                        'Nearby Agents',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: context.appColors.textPrimary,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${vm.agents.length}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: context.appColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (vm.isLoading)
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 48),
                      child: _LoadingAgentList(animation: _skeletonPulse),
                    )
                  else if (vm.agents.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 48),
                      child: Column(
                        children: [
                          Icon(
                            Icons.person_search_outlined,
                            size: 48,
                            color: context.appColors.textMuted,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No agents found nearby',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: context.appColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Try increasing the search radius',
                            style: TextStyle(
                              fontSize: 14,
                              color: context.appColors.textSecondary,
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
                        onTap: () => _handleAgentTap(
                          vm,
                          vm.agents[i],
                          activeTransactions,
                          ongoingLoans,
                        ),
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
      return '...';
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
      } else if (_selectedAgentId != null) {
        unawaited(_resetFocus(vm));
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

  void _handleAgentTap(
    DiscoverViewModel vm,
    NearbyAgent agent,
    List<PhysicalTransaction> activeTransactions,
    List<Loan> ongoingLoans,
  ) {
    if (_selectedAgentId == agent.id) {
      _showAgentDetail(agent, activeTransactions, ongoingLoans);
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
          onTap: () => _handleAgentTap(
            vm,
            agent,
            context.read<TransactionViewModel>().activeTransactions,
            context.read<LoanViewModel>().ongoingLoans,
          ),
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
        fillColor: context.appColors.brandAccent.withValues(alpha: 0.08),
        strokeColor: context.appColors.brandStrong.withValues(alpha: 0.3),
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
            ? context.appColors.textSecondary
            : context.appColors.brandStrong,
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

  void _showAgentDetail(
    NearbyAgent agent,
    List<PhysicalTransaction> activeTransactions,
    List<Loan> ongoingLoans,
  ) {
    Loan? activeLoan;
    for (final loan in ongoingLoans) {
      if (loan.agentId == agent.id) {
        activeLoan = loan;
        break;
      }
    }

    PhysicalTransaction? activeTransaction;
    for (final txn in activeTransactions) {
      if (txn.agentId == agent.id) {
        activeTransaction = txn;
        break;
      }
    }

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
        activeTransaction: activeTransaction,
        activeLoan: activeLoan,
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

class _BackdropOrb extends StatelessWidget {
  final double size;
  final Color color;

  const _BackdropOrb({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      ),
    );
  }
}

class _MapGhostMarker extends StatelessWidget {
  final Animation<double> animation;
  final Color color;

  const _MapGhostMarker({required this.animation, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: animation,
          builder: (context, _) {
            final markerColor = Color.lerp(
              color.withValues(alpha: 0.22),
              color.withValues(alpha: 0.36),
              animation.value,
            )!;
            return Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: markerColor,
                shape: BoxShape.circle,
                border: Border.all(
                  color: context.appColors.surfaceSection,
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.12),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
            );
          },
        ),
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.24),
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      ],
    );
  }
}

class _LoadingActionButton extends StatelessWidget {
  final IconData icon;

  const _LoadingActionButton({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: context.appColors.surfaceSection,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: context.appColors.scrim.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Icon(icon, color: context.appColors.brandStrong, size: 22),
    );
  }
}

class _StaticLoadingChip extends StatelessWidget {
  final String label;

  const _StaticLoadingChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: context.appColors.surfaceInteractive,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: context.appColors.textSecondary,
        ),
      ),
    );
  }
}

class _LoadingAgentList extends StatelessWidget {
  final Animation<double> animation;

  const _LoadingAgentList({required this.animation});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        3,
        (index) => Padding(
          padding: EdgeInsets.only(bottom: index == 2 ? 0 : 10),
          child: _LoadingAgentCard(animation: animation),
        ),
      ),
    );
  }
}

class _LoadingAgentCard extends StatelessWidget {
  final Animation<double> animation;

  const _LoadingAgentCard({required this.animation});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.appColors.surfaceInteractive,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          _SkeletonBlock(
            animation: animation,
            height: 44,
            width: 44,
            borderRadius: BorderRadius.circular(14),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SkeletonBlock(
                  animation: animation,
                  height: 14,
                  width: 140,
                  borderRadius: BorderRadius.circular(999),
                ),
                const SizedBox(height: 8),
                _SkeletonBlock(
                  animation: animation,
                  height: 11,
                  width: 112,
                  borderRadius: BorderRadius.circular(999),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _SkeletonBlock(
                animation: animation,
                height: 13,
                width: 64,
                borderRadius: BorderRadius.circular(999),
              ),
              const SizedBox(height: 8),
              _SkeletonBlock(
                animation: animation,
                height: 11,
                width: 40,
                borderRadius: BorderRadius.circular(999),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SkeletonBlock extends StatelessWidget {
  final Animation<double> animation;
  final double height;
  final double? width;
  final BorderRadius borderRadius;

  const _SkeletonBlock({
    required this.animation,
    required this.height,
    this.width,
    required this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final color = Color.lerp(
          const Color(0xFFE7EDE2),
          const Color(0xFFF2F6EF),
          animation.value,
        )!;
        return Container(
          width: width,
          height: height,
          decoration: BoxDecoration(color: color, borderRadius: borderRadius),
        );
      },
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
        color: context.appColors.surfaceSection,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: context.appColors.scrim.withValues(alpha: 0.08),
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
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: context.appColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: context.appColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (isLoading) ...[
            const SizedBox(width: 12),
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: context.appColors.brandAccent,
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
      color: context.appColors.surfaceSection,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: SizedBox(
          width: 52,
          height: 52,
          child: Icon(icon, color: context.appColors.brandStrong, size: 22),
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
        color: context.appColors.brandSoft,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Selected On Map',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: context.appColors.brandStrong,
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
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: context.appColors.textPrimary,
                            ),
                          ),
                        ),
                        if (agent.isCertified) ...[
                          const SizedBox(width: 4),
                          Icon(
                            Icons.verified,
                            size: 16,
                            color: context.appColors.brandStrong,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      routePreview?.summaryLabel ??
                          '${agent.distanceLabel} away',
                      style: TextStyle(
                        fontSize: 13,
                        color: context.appColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton(
                onPressed: onViewDetails,
                style: OutlinedButton.styleFrom(
                  foregroundColor: context.appColors.brandStrong,
                  side: BorderSide(
                    color: context.appColors.brandStrong.withValues(alpha: 0.4),
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
        color: context.appColors.surfaceInteractive,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: context.appColors.brandStrong),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: context.appColors.textPrimary,
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
          color: context.appColors.surfaceInteractive,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? context.appColors.brandStrong.withValues(alpha: 0.42)
                : Colors.transparent,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: context.appColors.brandSoft,
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
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: context.appColors.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (agent.isCertified) ...[
                        const SizedBox(width: 4),
                        Icon(
                          Icons.verified,
                          size: 16,
                          color: context.appColors.brandStrong,
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
                        color: context.appColors.textMuted,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        agent.distanceLabel,
                        style: TextStyle(
                          fontSize: 13,
                          color: context.appColors.textSecondary,
                        ),
                      ),
                      if (agent.isCertified && agent.totalRatings > 0) ...[
                        const SizedBox(width: 12),
                        Icon(
                          Icons.star,
                          size: 14,
                          color: Colors.amber.shade600,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          agent.rating.toStringAsFixed(1),
                          style: TextStyle(
                            fontSize: 13,
                            color: context.appColors.textSecondary,
                          ),
                        ),
                      ],
                      if (agent.maxAmount != null) ...[
                        const SizedBox(width: 12),
                        Text(
                          'Up to GHS ${agent.maxAmount!.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 13,
                            color: context.appColors.textSecondary,
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
              color: selected
                  ? context.appColors.brandStrong
                  : context.appColors.textMuted,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
