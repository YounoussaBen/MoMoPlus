import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import '../../../core/data/services/backend_api_service.dart';
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

  LatLng get _initialCenter {
    final p = context.read<AgentProfileViewModel>().profile;
    if (p != null && p.hasLocation) {
      return LatLng(p.latitude!, p.longitude!);
    }
    return const LatLng(5.6037, -0.1870); // Accra default
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

  Future<void> _useCurrentLocation() async {
    setState(() => _isLocating = true);
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
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

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      final loc = LatLng(pos.latitude, pos.longitude);
      setState(() => _selectedLocation = loc);

      final controller = await _mapCtrl.future;
      controller.animateCamera(CameraUpdate.newLatLng(loc));
    } catch (e) {
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

  String _availabilitySubtitle() {
    if (_availabilityValue == true) return 'Visible to users nearby';
    return 'Hidden from nearby users';
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
    final radius = _serviceRadiusKm(vm) * 1000;
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
                            Row(
                              children: [
                                const Text(
                                  'Available',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ],
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
                // Map
                Expanded(
                  child: Stack(
                    children: [
                      GoogleMap(
                        initialCameraPosition: CameraPosition(
                          target: _initialCenter,
                          zoom: 14,
                        ),
                        onMapCreated: (controller) {
                          if (!_mapCtrl.isCompleted) {
                            _mapCtrl.complete(controller);
                          }
                        },
                        onTap: (latLng) {
                          setState(() => _selectedLocation = latLng);
                        },
                        markers: _selectedLocation != null
                            ? {
                                Marker(
                                  markerId: const MarkerId('agent'),
                                  position: _selectedLocation!,
                                  icon: BitmapDescriptor.defaultMarkerWithHue(
                                    BitmapDescriptor.hueGreen,
                                  ),
                                ),
                              }
                            : {},
                        circles: _selectedLocation != null
                            ? {
                                Circle(
                                  circleId: const CircleId('radius'),
                                  center: _selectedLocation!,
                                  radius: radius,
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
                      ),
                      // Use current location button
                      Positioned(
                        bottom: 100,
                        right: 16,
                        child: Material(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: _isLocating ? null : _useCurrentLocation,
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: _isLocating
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppColors.primary,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.my_location,
                                      color: AppColors.primary,
                                    ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Bottom bar
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _selectedLocation != null
                            ? 'Tap the map or use current location'
                            : 'Tap on the map to set your location',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
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
                        decoration: const InputDecoration(hintText: '5'),
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
