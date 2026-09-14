import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/ui/theme/app_theme_extension.dart';
import '../../../core/ui/theme/app_map_style.dart';

class MeetingPointResult {
  final double latitude;
  final double longitude;
  final String description;

  const MeetingPointResult({
    required this.latitude,
    required this.longitude,
    required this.description,
  });
}

class MeetingPointPicker extends StatefulWidget {
  const MeetingPointPicker({super.key});

  @override
  State<MeetingPointPicker> createState() => _MeetingPointPickerState();
}

class _MeetingPointPickerState extends State<MeetingPointPicker> {
  final Completer<GoogleMapController> _mapCtrl = Completer();
  final _descCtrl = TextEditingController();
  LatLng? _selectedPoint;
  LatLng? _userLocation;
  bool _isLocating = true;
  bool _isMoving = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentLocation();
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentLocation() async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      if (!mounted) return;
      final point = LatLng(pos.latitude, pos.longitude);
      setState(() {
        _userLocation = point;
        _selectedPoint = point;
        _isLocating = false;
      });
    } catch (_) {
      if (!mounted) return;
      // Default to Accra center if location unavailable
      setState(() {
        _userLocation = const LatLng(5.6037, -0.1870);
        _selectedPoint = const LatLng(5.6037, -0.1870);
        _isLocating = false;
      });
    }
  }

  Future<void> _goToCurrentLocation() async {
    if (_userLocation == null) return;
    final controller = await _mapCtrl.future;
    await controller.animateCamera(CameraUpdate.newLatLng(_userLocation!));
    setState(() => _selectedPoint = _userLocation);
  }

  void _confirm() {
    if (_selectedPoint == null) return;
    Navigator.pop(
      context,
      MeetingPointResult(
        latitude: _selectedPoint!.latitude,
        longitude: _selectedPoint!.longitude,
        description: _descCtrl.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final safeTop = MediaQuery.of(context).padding.top;
    final safeBottom = MediaQuery.of(context).viewPadding.bottom;
    final colors = context.appColors;

    return Scaffold(
      backgroundColor: colors.canvas,
      body: _isLocating
          ? Center(
              child: CircularProgressIndicator(
                color: colors.brandStrong,
                strokeWidth: 2,
              ),
            )
          : Stack(
              children: [
                // Map
                Positioned.fill(
                  bottom: 180,
                  child: GoogleMap(
                    style: AppMapStyle.forBrightness(
                      Theme.of(context).brightness,
                    ),
                    initialCameraPosition: CameraPosition(
                      target: _selectedPoint!,
                      zoom: 16,
                    ),
                    onMapCreated: (controller) {
                      if (!_mapCtrl.isCompleted) {
                        _mapCtrl.complete(controller);
                      }
                    },
                    onCameraMove: (position) {
                      _selectedPoint = position.target;
                      if (!_isMoving) {
                        setState(() => _isMoving = true);
                      }
                    },
                    onCameraIdle: () {
                      if (_isMoving) {
                        setState(() => _isMoving = false);
                      }
                    },
                    myLocationEnabled: true,
                    myLocationButtonEnabled: false,
                    zoomControlsEnabled: false,
                    mapToolbarEnabled: false,
                    compassEnabled: true,
                    tiltGesturesEnabled: false,
                    buildingsEnabled: true,
                  ),
                ),

                // Center pin
                Positioned.fill(
                  bottom: 180,
                  child: IgnorePointer(
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.only(bottom: _isMoving ? 48 : 40),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          child: Icon(
                            Icons.location_on,
                            size: _isMoving ? 48 : 44,
                            color: colors.error,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Pin shadow
                if (!_isMoving)
                  Positioned.fill(
                    bottom: 180,
                    child: IgnorePointer(
                      child: Center(
                        child: Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.3),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                  ),

                // Top bar
                Positioned(
                  top: safeTop + 8,
                  left: 16,
                  right: 16,
                  child: Row(
                    children: [
                      _CircleButton(
                        icon: Icons.arrow_back,
                        onTap: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: colors.surfaceSection,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(
                            _isMoving
                                ? 'Move map to set pin...'
                                : _selectedPoint != null
                                ? '${_selectedPoint!.latitude.toStringAsFixed(5)}, ${_selectedPoint!.longitude.toStringAsFixed(5)}'
                                : 'Select a meeting point',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: _isMoving
                                  ? colors.textSecondary
                                  : colors.textPrimary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // My location button
                Positioned(
                  bottom: 196,
                  right: 16,
                  child: _CircleButton(
                    icon: Icons.my_location,
                    onTap: _goToCurrentLocation,
                  ),
                ),

                // Bottom panel
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: EdgeInsets.fromLTRB(20, 20, 20, 16 + safeBottom),
                    decoration: BoxDecoration(
                      color: colors.surfaceSection,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(24),
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Meeting Point',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: colors.textPrimary,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Drag the map to place the pin, then add a description.',
                          style: TextStyle(
                            fontSize: 14,
                            color: colors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _descCtrl,
                          decoration: InputDecoration(
                            hintText: 'e.g. By the market entrance',
                            prefixIcon: const Icon(
                              Icons.edit_location_alt_outlined,
                              size: 20,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: _goToCurrentLocation,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  decoration: BoxDecoration(
                                    color: colors.surfaceInteractive,
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.my_location,
                                        size: 18,
                                        color: colors.brandStrong,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Use My Location',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: colors.brandStrong,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _selectedPoint == null
                                    ? null
                                    : _confirm,
                                child: const Text('Confirm'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _CircleButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: context.appColors.surfaceSection,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(icon, size: 22, color: context.appColors.textPrimary),
      ),
    );
  }
}
