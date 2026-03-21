import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import '../../../core/data/services/backend_api_service.dart';
import '../../../core/ui/theme/app_theme.dart';
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
            padding: EdgeInsets.only(top: safeTop + 88, bottom: bottomInset),
            myLocationEnabled: false,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
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
                  title:
                      '${vm.agents.length} agent${vm.agents.length == 1 ? '' : 's'} nearby',
                  subtitle:
                      'Searching within ${vm.radius.toStringAsFixed(0)} km of your location',
                  isLoading: vm.isLoading,
                ),
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
          initialChildSize: 0.28,
          minChildSize: 0.15,
          maxChildSize: 0.82,
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
                      onClear: () => _resetFocus(vm),
                      onViewDetails: () => _showAgentDetail(selectedAgent),
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
        _focusOnAgent(vm, selectedAgent, expandSheet: false);
      } else {
        _fitMapToVisiblePoints(vm);
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

  Future<void> _focusOnAgent(
    DiscoverViewModel vm,
    NearbyAgent agent, {
    bool expandSheet = true,
  }) async {
    if (_selectedAgentId != agent.id) {
      setState(() => _selectedAgentId = agent.id);
    }
    if (expandSheet && _sheetCtrl.isAttached) {
      unawaited(
        _sheetCtrl.animateTo(
          0.42,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
        ),
      );
    }
    await _fitMapToVisiblePoints(
      vm,
      extraPoints: [LatLng(agent.latitude, agent.longitude)],
    );
  }

  Future<void> _resetFocus(DiscoverViewModel vm) async {
    if (_selectedAgentId != null && mounted) {
      setState(() => _selectedAgentId = null);
    }
    if (_sheetCtrl.isAttached) {
      unawaited(
        _sheetCtrl.animateTo(
          0.28,
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
    _focusOnAgent(vm, agent);
  }

  Set<Marker> _buildMarkers(DiscoverViewModel vm) {
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
      markers.add(
        Marker(
          markerId: MarkerId(agent.id),
          position: LatLng(agent.latitude, agent.longitude),
          zIndexInt: _selectedAgentId == agent.id ? 3 : 1,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            _selectedAgentId == agent.id
                ? BitmapDescriptor.hueRed
                : agent.isCertified
                ? BitmapDescriptor.hueGreen
                : BitmapDescriptor.hueOrange,
          ),
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

  void _showAgentDetail(NearbyAgent agent) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => AgentDetailSheet(agent: agent),
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
  final VoidCallback onClear;
  final VoidCallback onViewDetails;

  const _SelectedAgentCard({
    required this.agent,
    required this.onClear,
    required this.onViewDetails,
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
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    agent.fullName.isNotEmpty
                        ? agent.fullName[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
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
                child: const Text('View'),
              ),
            ],
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
            // Avatar
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: agent.isCertified
                    ? AppColors.primary.withValues(alpha: 0.1)
                    : AppColors.textSecondary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  agent.fullName.isNotEmpty
                      ? agent.fullName[0].toUpperCase()
                      : '?',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: agent.isCertified
                        ? AppColors.primary
                        : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Info
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
