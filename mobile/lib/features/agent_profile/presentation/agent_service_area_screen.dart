import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';

import '../../../core/data/services/backend_api_service.dart';
import '../../../core/services/native_map_launcher.dart';
import '../../../core/ui/theme/app_theme.dart';
import '../../../core/ui/widgets/top_in_app_notification.dart';
import 'agent_profile_view_model.dart';

class AgentServiceAreaScreen extends StatelessWidget {
  const AgentServiceAreaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) => AgentProfileViewModel(ctx.read<BackendApiService>()),
      child: const _ServiceAreaBody(),
    );
  }
}

class _ServiceAreaBody extends StatefulWidget {
  const _ServiceAreaBody();

  @override
  State<_ServiceAreaBody> createState() => _ServiceAreaBodyState();
}

class _ServiceAreaBodyState extends State<_ServiceAreaBody> {
  final Completer<GoogleMapController> _mapCtrl = Completer();
  final _radiusCtrl = TextEditingController();
  LatLng? _selectedLocation;
  bool? _availabilityValue;
  bool _isSyncingAvailability = false;
  bool _isProcessingAvailability = false;
  bool _isLocating = false;
  bool _didInitRadius = false;
  MapType _mapType = MapType.normal;

  LatLng get _initialCenter {
    final profile = context.read<AgentProfileViewModel>().profile;
    if (profile != null && profile.hasLocation) {
      return LatLng(profile.latitude!, profile.longitude!);
    }
    return const LatLng(5.6037, -0.1870);
  }

  @override
  void dispose() {
    _radiusCtrl.dispose();
    super.dispose();
  }

  void _initFromProfile(AgentProfileViewModel vm) {
    final profile = vm.profile;
    if (_didInitRadius || profile == null) return;

    _didInitRadius = true;
    _radiusCtrl.text = _formatRadius(profile.serviceRadiusKm);
    _availabilityValue = profile.isAvailable;
    if (profile.hasLocation) {
      _selectedLocation = LatLng(profile.latitude!, profile.longitude!);
    }
  }

  String _formatRadius(double value) {
    if (value == value.truncateToDouble()) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(1);
  }

  double _serviceRadiusKm(AgentProfileViewModel vm) {
    final parsed = double.tryParse(_radiusCtrl.text.trim());
    if (parsed != null && parsed > 0) return parsed;
    return vm.profile?.serviceRadiusKm ?? 5;
  }

  String _availabilitySubtitle() {
    if (_availabilityValue == true) return 'Visible to users nearby';
    return 'Hidden from nearby users';
  }

  String _coordinateLabel() {
    final location = _selectedLocation;
    if (location == null) return 'No pin selected';
    return '${location.latitude.toStringAsFixed(5)}, ${location.longitude.toStringAsFixed(5)}';
  }

  Future<void> _centerOnLocation(LatLng location, {double bearing = 12}) async {
    final controller = await _mapCtrl.future;
    await controller.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: location,
          zoom: 16.2,
          tilt: 54,
          bearing: bearing,
        ),
      ),
    );
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _isLocating = true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) {
          showTopInAppNotification(
            context,
            title: 'Location Unavailable',
            message: 'Allow location access to use your current position.',
            type: AppNotificationType.info,
          );
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      final location = LatLng(position.latitude, position.longitude);
      setState(() => _selectedLocation = location);
      await _centerOnLocation(location, bearing: 0);
    } catch (_) {
      if (mounted) {
        showTopInAppNotification(
          context,
          title: 'Location Error',
          message: 'We could not get your current location right now.',
          type: AppNotificationType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  Future<void> _openStreetView() async {
    final location = _selectedLocation;
    if (location == null) {
      showTopInAppNotification(
        context,
        title: 'Pick a Location',
        message: 'Select a point on the map before opening Street View.',
        type: AppNotificationType.info,
      );
      return;
    }

    try {
      await NativeMapLauncher.openStreetView(
        latitude: location.latitude,
        longitude: location.longitude,
        title: 'Service Area',
      );
    } catch (error) {
      if (!mounted) return;
      showTopInAppNotification(
        context,
        title: 'Street View Unavailable',
        message: error.toString().replaceFirst('Exception: ', ''),
        type: AppNotificationType.info,
      );
    }
  }

  Future<void> _save() async {
    final vm = context.read<AgentProfileViewModel>();
    final radius = double.tryParse(_radiusCtrl.text.trim());
    if (radius == null || radius <= 0) {
      showTopInAppNotification(
        context,
        title: 'Invalid Radius',
        message: 'Enter a valid service radius in kilometers.',
        type: AppNotificationType.error,
      );
      return;
    }

    final fields = <String, dynamic>{
      'service_radius_km': radius.toStringAsFixed(2),
    };
    if (_selectedLocation != null) {
      fields['latitude'] = _selectedLocation!.latitude.toStringAsFixed(6);
      fields['longitude'] = _selectedLocation!.longitude.toStringAsFixed(6);
    }

    final ok = await vm.updateProfile(fields);
    if (ok && mounted) {
      _radiusCtrl.text = _formatRadius(vm.profile?.serviceRadiusKm ?? radius);
      showTopInAppNotification(
        context,
        title: 'Saved',
        message: 'Your service area was updated successfully.',
        type: AppNotificationType.success,
      );
    } else if (mounted && vm.errorMessage != null) {
      showTopInAppNotification(
        context,
        title: 'Could Not Save',
        message: vm.errorMessage!,
        type: AppNotificationType.error,
      );
    }
  }

  Future<void> _handleAvailabilityChanged(bool nextValue) async {
    final vm = context.read<AgentProfileViewModel>();
    final currentValue = _availabilityValue ?? vm.profile?.isAvailable ?? false;

    if (currentValue == nextValue && !_isSyncingAvailability) return;

    final shouldStartProcessing = !_isProcessingAvailability;
    setState(() {
      _availabilityValue = nextValue;
      _isSyncingAvailability = true;
    });

    if (!shouldStartProcessing) return;
    await _syncAvailability();
  }

  Future<void> _syncAvailability() async {
    final vm = context.read<AgentProfileViewModel>();
    _isProcessingAvailability = true;
    try {
      while (mounted) {
        final serverValue = vm.profile?.isAvailable ?? false;
        final desiredValue = _availabilityValue ?? serverValue;

        if (serverValue == desiredValue) break;

        if (desiredValue && !vm.hasVerifiedWallet) {
          await vm.refreshWalletEligibility();
          if (!mounted) return;

          if (!vm.hasVerifiedWallet) {
            final revertedValue = vm.profile?.isAvailable ?? false;
            setState(() {
              _availabilityValue = revertedValue;
            });
            showTopInAppNotification(
              context,
              title: 'Wallet Required',
              message: vm.hasAnyWallet
                  ? 'Verify at least one mobile money wallet before making yourself available to users.'
                  : 'Add and verify a mobile money wallet before making yourself available to users.',
              type: AppNotificationType.info,
            );
            continue;
          }
        }

        final ok = await vm.toggleAvailability();
        if (!mounted) return;

        final updatedServerValue = vm.profile?.isAvailable ?? serverValue;
        if (!ok) {
          setState(() {
            _availabilityValue = updatedServerValue;
          });
          showTopInAppNotification(
            context,
            title: 'Availability Not Updated',
            message:
                vm.errorMessage ??
                'We could not update your availability right now.',
            type: AppNotificationType.error,
          );
          break;
        }

        setState(() {
          _availabilityValue = updatedServerValue;
        });
      }
    } finally {
      _isProcessingAvailability = false;
      if (mounted) {
        setState(() {
          _isSyncingAvailability = false;
          _availabilityValue =
              _availabilityValue ?? vm.profile?.isAvailable ?? false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AgentProfileViewModel>();
    _initFromProfile(vm);
    final radiusKm = _serviceRadiusKm(vm);
    final radiusMeters = radiusKm * 1000;
    final isAvailable = _availabilityValue ?? vm.profile?.isAvailable ?? false;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Service Area'),
        backgroundColor: AppColors.background,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: vm.isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: AppColors.primary,
                strokeWidth: 2,
              ),
            )
          : Column(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: isAvailable
                        ? AppColors.primary.withValues(alpha: 0.08)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isAvailable
                          ? AppColors.primary.withValues(alpha: 0.18)
                          : AppColors.divider,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 18,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: isAvailable
                              ? AppColors.primary.withValues(alpha: 0.14)
                              : AppColors.surface,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isAvailable
                              ? Icons.visibility_rounded
                              : Icons.visibility_off_rounded,
                          color: isAvailable
                              ? AppColors.primary
                              : AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Available',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 200),
                              child: Text(
                                _availabilitySubtitle(),
                                key: ValueKey(_availabilitySubtitle()),
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      CupertinoSwitch(
                        value: isAvailable,
                        activeTrackColor: AppColors.primary,
                        onChanged: _handleAvailabilityChanged,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Stack(
                    children: [
                      GoogleMap(
                        initialCameraPosition: CameraPosition(
                          target: _initialCenter,
                          zoom: 14.5,
                          tilt: 42,
                          bearing: 10,
                        ),
                        onMapCreated: (controller) {
                          if (!_mapCtrl.isCompleted) {
                            _mapCtrl.complete(controller);
                          }
                        },
                        onTap: (latLng) {
                          setState(() => _selectedLocation = latLng);
                          unawaited(_centerOnLocation(latLng));
                        },
                        markers: _selectedLocation != null
                            ? {
                                Marker(
                                  markerId: const MarkerId('agent_service'),
                                  position: _selectedLocation!,
                                  infoWindow: const InfoWindow(
                                    title: 'Service location',
                                  ),
                                  icon: BitmapDescriptor.defaultMarkerWithHue(
                                    BitmapDescriptor.hueGreen,
                                  ),
                                ),
                              }
                            : {},
                        circles: _selectedLocation != null
                            ? {
                                Circle(
                                  circleId: const CircleId('service_radius'),
                                  center: _selectedLocation!,
                                  radius: radiusMeters,
                                  fillColor: AppColors.primary.withValues(
                                    alpha: 0.08,
                                  ),
                                  strokeColor: AppColors.primary.withValues(
                                    alpha: 0.3,
                                  ),
                                  strokeWidth: 1,
                                ),
                              }
                            : {},
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
                      Positioned(
                        top: 16,
                        left: 16,
                        right: 88,
                        child: _MapOverlayCard(
                          title: _selectedLocation != null
                              ? 'Service point pinned'
                              : 'Set your service point',
                          subtitle: _selectedLocation != null
                              ? 'Coverage radius ${radiusKm.toStringAsFixed(1)} km • ${_coordinateLabel()}'
                              : 'Tap the map to pin your working location.',
                        ),
                      ),
                      Positioned(
                        right: 16,
                        bottom: 110,
                        child: Column(
                          children: [
                            _FloatingMapButton(
                              icon: _mapType == MapType.normal
                                  ? Icons.layers_outlined
                                  : Icons.map_outlined,
                              onTap: () {
                                setState(() {
                                  _mapType = _mapType == MapType.normal
                                      ? MapType.hybrid
                                      : MapType.normal;
                                });
                              },
                            ),
                            const SizedBox(height: 10),
                            _FloatingMapButton(
                              icon: Icons.streetview_outlined,
                              onTap: _openStreetView,
                            ),
                            const SizedBox(height: 10),
                            _FloatingMapButton(
                              icon: Icons.my_location,
                              isLoading: _isLocating,
                              onTap: _isLocating ? null : _useCurrentLocation,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _ServiceStatTile(
                              label: 'Radius',
                              value: '${radiusKm.toStringAsFixed(1)} km',
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _ServiceStatTile(
                              label: 'Coordinates',
                              value: _selectedLocation != null
                                  ? _coordinateLabel()
                                  : 'Add a map pin',
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _ServiceStatTile(
                              label: 'Visibility',
                              value: isAvailable ? 'Visible' : 'Hidden',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          _selectedLocation != null
                              ? 'Tap the map, use current location, or open Street View to confirm the spot.'
                              : 'Tap on the map to set your service location.',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Service Radius (km)',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _radiusCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          hintText: '5',
                          prefixIcon: Icon(Icons.radar_outlined),
                        ),
                      ),
                      if (vm.errorMessage != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          vm.errorMessage!,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.error,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: vm.isSaving || _isSyncingAvailability
                              ? null
                              : _save,
                          child: vm.isSaving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('Save Service Area'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _MapOverlayCard extends StatelessWidget {
  final String title;
  final String subtitle;

  const _MapOverlayCard({required this.title, required this.subtitle});

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
    );
  }
}

class _FloatingMapButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final bool isLoading;

  const _FloatingMapButton({
    required this.icon,
    required this.onTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: SizedBox(
          width: 52,
          height: 52,
          child: Center(
            child: isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primary,
                    ),
                  )
                : Icon(icon, color: AppColors.primary, size: 22),
          ),
        ),
      ),
    );
  }
}

class _ServiceStatTile extends StatelessWidget {
  final String label;
  final String value;

  const _ServiceStatTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
