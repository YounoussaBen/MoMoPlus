import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';

import '../../../core/services/native_map_launcher.dart';
import '../../../core/ui/theme/app_map_style.dart';
import '../../../core/ui/theme/app_theme_extension.dart';
import '../../../core/ui/widgets/app_button.dart';
import '../../../core/ui/widgets/top_in_app_notification.dart';
import 'agent_profile_view_model.dart';
import 'widgets/agent_availability_pill.dart';

class AgentServiceAreaScreen extends StatelessWidget {
  const AgentServiceAreaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _ServiceAreaBody();
  }
}

class _ServiceAreaBody extends StatefulWidget {
  const _ServiceAreaBody();

  @override
  State<_ServiceAreaBody> createState() => _ServiceAreaBodyState();
}

class _ServiceAreaBodyState extends State<_ServiceAreaBody>
    with SingleTickerProviderStateMixin {
  final Completer<GoogleMapController> _mapCtrl = Completer();
  static const List<double> _radiusOptions = [5, 10, 15, 25, 50];
  LatLng? _selectedLocation;
  double? _selectedRadiusKm;
  bool? _availabilityValue;
  bool _isSyncingAvailability = false;
  bool _isProcessingAvailability = false;
  bool _isLocating = false;
  bool _didInitRadius = false;
  MapType _mapType = MapType.normal;
  late final AnimationController _skeletonController;
  late final Animation<double> _skeletonPulse;

  @override
  void initState() {
    super.initState();
    _skeletonController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _skeletonPulse = CurvedAnimation(
      parent: _skeletonController,
      curve: Curves.easeInOut,
    );
  }

  LatLng get _initialCenter {
    final profile = context.read<AgentProfileViewModel>().profile;
    if (profile != null && profile.hasLocation) {
      return LatLng(profile.latitude!, profile.longitude!);
    }
    return const LatLng(5.6037, -0.1870);
  }

  @override
  void dispose() {
    _skeletonController.dispose();
    super.dispose();
  }

  void _initFromProfile(AgentProfileViewModel vm) {
    final profile = vm.profile;
    if (profile == null) return;

    if (!_didInitRadius) {
      _didInitRadius = true;
      _selectedRadiusKm = _nearestRadiusOption(profile.serviceRadiusKm);
      if (profile.hasLocation) {
        _selectedLocation = LatLng(profile.latitude!, profile.longitude!);
      }
    }
    if (!_isSyncingAvailability && !_isProcessingAvailability) {
      _availabilityValue = profile.isAvailable;
    }
  }

  double _nearestRadiusOption(double value) {
    var nearest = _radiusOptions.first;
    for (final option in _radiusOptions) {
      if ((option - value).abs() < (nearest - value).abs()) {
        nearest = option;
      }
    }
    return nearest;
  }

  double _serviceRadiusKm(AgentProfileViewModel vm) {
    final selected = _selectedRadiusKm;
    if (selected != null && selected > 0) return selected;
    return vm.profile?.serviceRadiusKm ?? 5;
  }

  String _availabilitySubtitle() {
    if (_availabilityValue == true) return 'Visible';
    return 'Hidden';
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
    final radius = _serviceRadiusKm(vm);

    final fields = <String, dynamic>{
      'service_radius_km': radius.toStringAsFixed(2),
    };
    if (_selectedLocation != null) {
      fields['latitude'] = _selectedLocation!.latitude.toStringAsFixed(6);
      fields['longitude'] = _selectedLocation!.longitude.toStringAsFixed(6);
    }

    final ok = await vm.updateProfile(fields);
    if (ok && mounted) {
      _selectedRadiusKm = _nearestRadiusOption(
        vm.profile?.serviceRadiusKm ?? radius,
      );
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

  void _showRadiusPicker() {
    final vm = context.read<AgentProfileViewModel>();
    final selectedRadius = _serviceRadiusKm(vm);
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('Service Radius'),
        actions: _radiusOptions.map((radius) {
          return CupertinoActionSheetAction(
            isDefaultAction: radius == selectedRadius,
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => _selectedRadiusKm = radius);
            },
            child: Text('${radius.toStringAsFixed(0)} km'),
          );
        }).toList(),
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  void _handleAvailabilityChanged(bool nextValue) {
    final vm = context.read<AgentProfileViewModel>();
    final currentValue = _availabilityValue ?? vm.profile?.isAvailable ?? false;

    if (currentValue == nextValue) return;

    final shouldStartProcessing = !_isProcessingAvailability;
    setState(() {
      _availabilityValue = nextValue;
      _isSyncingAvailability = true;
    });

    if (!shouldStartProcessing) return;
    unawaited(_syncAvailability());
  }

  Future<void> _syncAvailability() async {
    final vm = context.read<AgentProfileViewModel>();
    _isProcessingAvailability = true;
    try {
      while (mounted) {
        final serverValue = vm.profile?.isAvailable ?? false;
        final desiredValue = _availabilityValue ?? serverValue;

        if (serverValue == desiredValue) break;

        final guard = await vm.validateAvailabilityChange(desiredValue);
        if (!mounted) return;
        if (guard != null) {
          final revertedValue = vm.profile?.isAvailable ?? false;
          setState(() {
            _availabilityValue = revertedValue;
          });
          showTopInAppNotification(
            context,
            title: guard.title,
            message: guard.message,
            type: AppNotificationType.info,
          );
          continue;
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

        if (_availabilityValue == desiredValue) {
          setState(() => _availabilityValue = updatedServerValue);
        }
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

  Widget _buildLoadingState() {
    final mediaQuery = MediaQuery.of(context);
    final size = mediaQuery.size;
    final safeTop = mediaQuery.padding.top;
    final bottomPadding = mediaQuery.padding.bottom;

    return Stack(
      children: [
        Positioned.fill(
          child: ColoredBox(
            color: context.appColors.canvas,
            child: Stack(
              children: [
                Positioned(
                  top: safeTop + 90,
                  left: -36,
                  child: _ServiceBackdropOrb(
                    size: 170,
                    color: context.appColors.brandSoft.withValues(alpha: 0.7),
                  ),
                ),
                Positioned(
                  top: safeTop + 240,
                  right: -28,
                  child: _ServiceBackdropOrb(
                    size: 130,
                    color: context.appColors.warningContainer.withValues(
                      alpha: 0.7,
                    ),
                  ),
                ),
                Positioned(
                  top: safeTop + 220,
                  left: size.width * 0.24,
                  child: _ServiceGhostPin(animation: _skeletonPulse),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          top: 12,
          left: 16,
          right: 16,
          child: _ServiceAreaLoadingCard(animation: _skeletonPulse, height: 76),
        ),
        Positioned(
          top: 104,
          left: 16,
          right: 88,
          child: _ServiceAreaLoadingCard(animation: _skeletonPulse, height: 72),
        ),
        Positioned(
          right: 16,
          bottom: 190,
          child: Column(
            children: [
              _ServiceLoadingActionButton(animation: _skeletonPulse),
              const SizedBox(height: 10),
              _ServiceLoadingActionButton(animation: _skeletonPulse),
              const SizedBox(height: 10),
              _ServiceLoadingActionButton(animation: _skeletonPulse),
            ],
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            padding: EdgeInsets.fromLTRB(16, 14, 16, bottomPadding + 40),
            decoration: BoxDecoration(
              color: context.appColors.surfaceSection,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _ServiceSkeletonStat(animation: _skeletonPulse),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _ServiceSkeletonStat(animation: _skeletonPulse),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _ServiceSkeletonStat(animation: _skeletonPulse),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _ServiceSkeletonBlock(
                  animation: _skeletonPulse,
                  height: 12,
                  width: double.infinity,
                  borderRadius: BorderRadius.circular(999),
                ),
                const SizedBox(height: 8),
                _ServiceSkeletonBlock(
                  animation: _skeletonPulse,
                  height: 12,
                  width: size.width * 0.62,
                  borderRadius: BorderRadius.circular(999),
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerLeft,
                  child: _ServiceSkeletonBlock(
                    animation: _skeletonPulse,
                    height: 12,
                    width: 128,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 8),
                _ServiceSkeletonBlock(
                  animation: _skeletonPulse,
                  height: 52,
                  width: double.infinity,
                  borderRadius: BorderRadius.circular(12),
                ),
                const SizedBox(height: 16),
                _ServiceSkeletonBlock(
                  animation: _skeletonPulse,
                  height: 52,
                  width: double.infinity,
                  borderRadius: BorderRadius.circular(14),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AgentProfileViewModel>();
    _initFromProfile(vm);
    final radiusKm = _serviceRadiusKm(vm);
    final radiusMeters = radiusKm * 1000;
    final isAvailable = _availabilityValue ?? vm.profile?.isAvailable ?? false;

    return Scaffold(
      backgroundColor: context.appColors.canvas,
      appBar: AppBar(
        title: const Text('Service Area'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: vm.isLoading
          ? _buildLoadingState()
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
                        ? context.appColors.successContainer
                        : context.appColors.surfaceSection,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isAvailable
                          ? context.appColors.success.withValues(alpha: 0.28)
                          : context.appColors.surfaceInteractive,
                    ),
                  ),
                  child: Row(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: isAvailable
                              ? context.appColors.successContainer
                              : context.appColors.surfaceInteractive,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isAvailable
                              ? Icons.visibility_rounded
                              : Icons.visibility_off_rounded,
                          color: isAvailable
                              ? context.appColors.success
                              : context.appColors.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isAvailable ? 'Available' : 'Unavailable',
                              style: context.appTextTheme.titleSmall,
                            ),
                            const SizedBox(height: 4),
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 200),
                              child: Text(
                                _availabilitySubtitle(),
                                key: ValueKey(_availabilitySubtitle()),
                                style: context.appTextTheme.bodySmall?.copyWith(
                                  color: context.appColors.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      AgentAvailabilityPill(
                        isAvailable: isAvailable,
                        onPressed: () =>
                            _handleAvailabilityChanged(!isAvailable),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Stack(
                    children: [
                      GoogleMap(
                        style: AppMapStyle.forBrightness(
                          Theme.of(context).brightness,
                        ),
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
                                  fillColor: context.appColors.brandAccent
                                      .withValues(alpha: 0.08),
                                  strokeColor: context.appColors.brandStrong
                                      .withValues(alpha: 0.3),
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
                  color: context.appColors.surfaceSection,
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
                                  : 'Map pin',
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
                          style: context.appTextTheme.bodySmall?.copyWith(
                            color: context.appColors.textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Service Radius (km)',
                          style: context.appTextTheme.labelLarge?.copyWith(
                            color: context.appColors.textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      GestureDetector(
                        onTap: _showRadiusPicker,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: context.appColors.surfaceInteractive,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.radar_outlined,
                                color: context.appColors.textSecondary,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  '${radiusKm.toStringAsFixed(0)} km',
                                  style: context.appTextTheme.titleSmall,
                                ),
                              ),
                              Icon(
                                Icons.keyboard_arrow_down_rounded,
                                color: context.appColors.textSecondary,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (vm.errorMessage != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          vm.errorMessage!,
                          style: context.appTextTheme.bodySmall?.copyWith(
                            color: context.appColors.error,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                      const SizedBox(height: 16),
                      AppButton(
                        label: 'Save service area',
                        onPressed: vm.isSaving || _isSyncingAvailability
                            ? null
                            : _save,
                        isLoading: vm.isSaving,
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _ServiceBackdropOrb extends StatelessWidget {
  final double size;
  final Color color;

  const _ServiceBackdropOrb({required this.size, required this.color});

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

class _ServiceGhostPin extends StatelessWidget {
  final Animation<double> animation;

  const _ServiceGhostPin({required this.animation});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: animation,
          builder: (context, child) {
            final color = Color.lerp(
              context.appColors.brandAccent.withValues(alpha: 0.22),
              context.appColors.brandAccent.withValues(alpha: 0.34),
              animation.value,
            )!;
            return Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.7),
                  width: 2,
                ),
              ),
            );
          },
        ),
        Container(
          width: 4,
          height: 22,
          decoration: BoxDecoration(
            color: context.appColors.brandAccent.withValues(alpha: 0.24),
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      ],
    );
  }
}

class _ServiceAreaLoadingCard extends StatelessWidget {
  final Animation<double> animation;
  final double height;

  const _ServiceAreaLoadingCard({
    required this.animation,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(minHeight: height),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.appColors.surfaceSection,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ServiceSkeletonBlock(
            animation: animation,
            height: 14,
            width: 120,
            borderRadius: BorderRadius.circular(999),
          ),
          const SizedBox(height: 10),
          _ServiceSkeletonBlock(
            animation: animation,
            height: 10,
            width: double.infinity,
            borderRadius: BorderRadius.circular(999),
          ),
          const SizedBox(height: 8),
          _ServiceSkeletonBlock(
            animation: animation,
            height: 10,
            width: 180,
            borderRadius: BorderRadius.circular(999),
          ),
        ],
      ),
    );
  }
}

class _ServiceLoadingActionButton extends StatelessWidget {
  final Animation<double> animation;

  const _ServiceLoadingActionButton({required this.animation});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: context.appColors.surfaceSection,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Center(
        child: _ServiceSkeletonBlock(
          animation: animation,
          height: 18,
          width: 18,
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }
}

class _ServiceSkeletonStat extends StatelessWidget {
  final Animation<double> animation;

  const _ServiceSkeletonStat({required this.animation});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.appColors.surfaceInteractive,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ServiceSkeletonBlock(
            animation: animation,
            height: 10,
            width: 56,
            borderRadius: BorderRadius.circular(999),
          ),
          const SizedBox(height: 8),
          _ServiceSkeletonBlock(
            animation: animation,
            height: 14,
            width: double.infinity,
            borderRadius: BorderRadius.circular(999),
          ),
        ],
      ),
    );
  }
}

class _ServiceSkeletonBlock extends StatelessWidget {
  final Animation<double> animation;
  final double height;
  final double width;
  final BorderRadius borderRadius;

  const _ServiceSkeletonBlock({
    required this.animation,
    required this.height,
    required this.width,
    required this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final color = Color.lerp(
          context.appColors.surfaceSubtle,
          context.appColors.surfaceInteractive,
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

class _MapOverlayCard extends StatelessWidget {
  final String title;
  final String subtitle;

  const _MapOverlayCard({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: context.appColors.surfaceSection.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: context.appTextTheme.titleSmall),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: context.appTextTheme.bodySmall?.copyWith(
              color: context.appColors.textSecondary,
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
      color: context.appColors.surfaceSection,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: SizedBox(
          width: 52,
          height: 52,
          child: Center(
            child: isLoading
                ? SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: context.appColors.brandStrong,
                    ),
                  )
                : Icon(icon, color: context.appColors.brandStrong, size: 22),
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
        color: context.appColors.surfaceInteractive,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: context.appTextTheme.labelSmall?.copyWith(
              color: context.appColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: context.appTextTheme.titleSmall,
          ),
        ],
      ),
    );
  }
}
