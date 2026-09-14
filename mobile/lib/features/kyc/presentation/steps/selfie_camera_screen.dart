import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../core/ui/widgets/app_button.dart';
import '../../data/demo_selfie_file.dart';

// Debug builds support simulator demos by default. Release/profile demo builds
// can opt in explicitly with --dart-define=MOMO_DEMO_MODE=true.
const _demoModeEnabled = bool.fromEnvironment(
  'MOMO_DEMO_MODE',
  defaultValue: false,
);

class SelfieCameraScreen extends StatefulWidget {
  const SelfieCameraScreen({super.key});

  static Future<File?> open(BuildContext context) {
    return Navigator.of(context).push<File>(
      MaterialPageRoute(
        builder: (_) => const SelfieCameraScreen(),
        fullscreenDialog: true,
      ),
    );
  }

  @override
  State<SelfieCameraScreen> createState() => _SelfieCameraScreenState();
}

class _SelfieCameraScreenState extends State<SelfieCameraScreen> {
  List<CameraDescription> _cameras = const [];
  CameraController? _controller;
  bool _isPreparing = true;
  bool _isCapturing = false;
  String? _errorMessage;
  int _selectedCameraIndex = 0;

  @override
  void initState() {
    super.initState();
    _prepareCamera();
  }

  @override
  void dispose() {
    final controller = _controller;
    _controller = null;
    controller?.dispose();
    super.dispose();
  }

  Future<void> _prepareCamera() async {
    if (!mounted) return;

    setState(() {
      _isPreparing = true;
      _errorMessage = null;
    });

    try {
      final cameras = await availableCameras();
      if (!mounted) return;

      if (cameras.isEmpty) {
        setState(() {
          _isPreparing = false;
          _errorMessage = 'No camera is available on this device.';
        });
        return;
      }

      if (_cameras.isEmpty) {
        _cameras = cameras;
        final frontIndex = cameras.indexWhere(
          (camera) => camera.lensDirection == CameraLensDirection.front,
        );
        _selectedCameraIndex = frontIndex >= 0 ? frontIndex : 0;
      }

      final oldController = _controller;
      final controller = CameraController(
        _cameras[_selectedCameraIndex],
        ResolutionPreset.medium,
        enableAudio: false,
      );
      _controller = controller;

      await oldController?.dispose();
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }

      setState(() {
        _isPreparing = false;
      });
    } on CameraException catch (error) {
      final controller = _controller;
      _controller = null;
      await controller?.dispose();
      if (!mounted) return;

      setState(() {
        _isPreparing = false;
        _errorMessage = _cameraErrorMessage(error);
      });
    } catch (_) {
      final controller = _controller;
      _controller = null;
      await controller?.dispose();
      if (!mounted) return;

      setState(() {
        _isPreparing = false;
        _errorMessage = 'Could not open the camera.';
      });
    }
  }

  Future<void> _switchCamera() async {
    if (_cameras.length < 2 || _isPreparing || _isCapturing) return;

    setState(() {
      _selectedCameraIndex = (_selectedCameraIndex + 1) % _cameras.length;
    });

    await _prepareCamera();
  }

  Future<void> _captureSelfie() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized || _isCapturing) {
      return;
    }

    setState(() {
      _isCapturing = true;
      _errorMessage = null;
    });

    try {
      final picture = await controller.takePicture();
      if (!mounted) return;
      Navigator.of(context).pop(File(picture.path));
    } on CameraException catch (error) {
      if (!mounted) return;

      setState(() {
        _errorMessage = _cameraErrorMessage(error);
      });
    } finally {
      if (mounted) {
        setState(() {
          _isCapturing = false;
        });
      }
    }
  }

  Future<void> _useDemoSelfie() async {
    if ((!kDebugMode && !_demoModeEnabled) || _isCapturing) return;

    setState(() {
      _isCapturing = true;
      _errorMessage = null;
    });

    try {
      final file = await DemoSelfieFile.create();
      if (!mounted) return;
      Navigator.of(context).pop(file);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isCapturing = false;
        _errorMessage = 'Could not create the demo selfie.';
      });
    }
  }

  String _cameraErrorMessage(CameraException error) {
    return switch (error.code) {
      'CameraAccessDenied' ||
      'CameraAccessDeniedWithoutPrompt' => 'Camera permission was denied.',
      'CameraAccessRestricted' => 'Camera access is restricted on this device.',
      _ => error.description ?? 'Could not initialize the camera.',
    };
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final canPreview =
        controller != null && controller.value.isInitialized && !_isPreparing;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Take a selfie'),
        actions: [
          if (_cameras.length > 1)
            IconButton(
              onPressed: _switchCamera,
              icon: const Icon(Icons.cameraswitch_outlined),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: canPreview
                  ? Center(child: CameraPreview(controller))
                  : _buildFallback(),
            ),
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 14),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: AppButton(
                      label: 'Cancel',
                      variant: AppButtonVariant.secondary,
                      onPressed: _isCapturing
                          ? null
                          : () => Navigator.of(context).pop(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppButton(
                      label: _isPreparing ? 'Opening...' : 'Capture',
                      isLoading: _isCapturing,
                      onPressed: canPreview && !_isCapturing
                          ? _captureSelfie
                          : null,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFallback() {
    if (_isPreparing) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
      );
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.camera_alt_outlined,
            color: Colors.white70,
            size: 42,
          ),
          const SizedBox(height: 12),
          Text(
            _errorMessage ?? 'Camera preview unavailable.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 16),
          if (kDebugMode || _demoModeEnabled) ...[
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'The simulator has no camera. Use an illustrated image for this demo.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54, fontSize: 13),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: AppButton(
                label: 'Use demo selfie',
                variant: AppButtonVariant.primary,
                isLoading: _isCapturing,
                onPressed: _isCapturing ? null : _useDemoSelfie,
              ),
            ),
            const SizedBox(height: 12),
          ],
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: AppButton(
              label: 'Try Again',
              variant: AppButtonVariant.secondary,
              onPressed: _prepareCamera,
            ),
          ),
        ],
      ),
    );
  }
}
