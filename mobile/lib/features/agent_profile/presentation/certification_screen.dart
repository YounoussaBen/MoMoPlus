import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../../core/data/services/backend_api_service.dart';
import '../../../core/data/services/file_upload_service.dart';
import '../../../core/ui/theme/app_theme.dart';
import '../../../core/ui/widgets/top_in_app_notification.dart';
import 'agent_profile_view_model.dart';

class _PhotoUploadState {
  final String displayPath;
  final String? assetId;
  final bool uploading;
  final String? error;

  const _PhotoUploadState({
    required this.displayPath,
    this.assetId,
    this.uploading = false,
    this.error,
  });

  bool get isReady => assetId != null && !uploading;
}

class CertificationScreen extends StatelessWidget {
  const CertificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) => AgentProfileViewModel(ctx.read<BackendApiService>()),
      child: const _CertificationBody(),
    );
  }
}

class _CertificationBody extends StatefulWidget {
  const _CertificationBody();

  @override
  State<_CertificationBody> createState() => _CertificationBodyState();
}

class _CertificationBodyState extends State<_CertificationBody> {
  final _agentIdCtrl = TextEditingController();
  final _bizRegCtrl = TextEditingController();
  final _picker = ImagePicker();
  final Set<String> _ownedAssetIds = {};
  final Set<String> _preservedAssetIds = {};

  late final FileUploadService _uploadService;
  _PhotoUploadState? _agentIdPhoto;
  _PhotoUploadState? _businessPhoto;

  @override
  void initState() {
    super.initState();
    _uploadService = FileUploadService(context.read<BackendApiService>());
  }

  @override
  void dispose() {
    for (final assetId
        in _ownedAssetIds.difference(_preservedAssetIds).toList()) {
      _scheduleDeleteAsset(assetId);
    }
    _agentIdCtrl.dispose();
    _bizRegCtrl.dispose();
    super.dispose();
  }

  void _setPhotoState(bool isAgentId, _PhotoUploadState? state) {
    setState(() {
      if (isAgentId) {
        _agentIdPhoto = state;
      } else {
        _businessPhoto = state;
      }
    });
  }

  void _scheduleDeleteAsset(String assetId) {
    unawaited(
      _uploadService
          .deleteAsset(assetId)
          .then((_) {
            _ownedAssetIds.remove(assetId);
          })
          .catchError((_) {}),
    );
  }

  Future<void> _pickPhoto(bool isAgentId, ImageSource source) async {
    try {
      final file = await _picker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 1200,
      );
      if (file == null) return;
      await _uploadPhoto(isAgentId, file);
    } catch (e) {
      _showError(
        'Could not open image picker: ${e.toString().replaceFirst('Exception: ', '')}',
      );
    }
  }

  Future<void> _uploadPhoto(bool isAgentId, XFile file) async {
    final previous = isAgentId ? _agentIdPhoto : _businessPhoto;
    _setPhotoState(
      isAgentId,
      _PhotoUploadState(displayPath: file.path, uploading: true),
    );

    try {
      final assetId = await _uploadService.upload(
        file: File(file.path),
        kind: 'document',
        contentType: 'image/jpeg',
      );

      if (!mounted) {
        _scheduleDeleteAsset(assetId);
        return;
      }

      setState(() {
        _ownedAssetIds.add(assetId);
        if (isAgentId) {
          _agentIdPhoto = _PhotoUploadState(
            displayPath: file.path,
            assetId: assetId,
          );
        } else {
          _businessPhoto = _PhotoUploadState(
            displayPath: file.path,
            assetId: assetId,
          );
        }
      });

      if (previous?.assetId != null) {
        _scheduleDeleteAsset(previous!.assetId!);
      }
    } catch (e) {
      final message = e.toString().replaceFirst('Exception: ', '');
      if (!mounted) return;

      _setPhotoState(
        isAgentId,
        previous?.assetId != null
            ? _PhotoUploadState(
                displayPath: previous!.displayPath,
                assetId: previous.assetId,
                error: message,
              )
            : _PhotoUploadState(displayPath: file.path, error: message),
      );
      _showError(message);
    }
  }

  Future<void> _choosePhotoSource(bool isAgentId) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a picture'),
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.of(context).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (!mounted || source == null) return;
    await _pickPhoto(isAgentId, source);
  }

  Future<void> _submit() async {
    if (_agentIdCtrl.text.isEmpty) {
      _showError('Please enter your MoMo Agent ID');
      return;
    }
    if (!(_agentIdPhoto?.isReady ?? false)) {
      _showError('Please upload your agent ID card photo');
      return;
    }
    if (!(_businessPhoto?.isReady ?? false)) {
      _showError('Please upload your business location photo');
      return;
    }

    final vm = context.read<AgentProfileViewModel>();

    try {
      final ok = await vm.applyCertification(
        agentIdNumber: _agentIdCtrl.text.trim(),
        agentIdPhotoId: _agentIdPhoto!.assetId!,
        businessLocationPhotoId: _businessPhoto!.assetId!,
        businessRegistrationNumber: _bizRegCtrl.text.trim(),
      );

      if (ok && mounted) {
        _preservedAssetIds
          ..clear()
          ..addAll([_agentIdPhoto!.assetId!, _businessPhoto!.assetId!]);
        showTopInAppNotification(
          context,
          title: 'Submitted',
          message: 'Your certification application was submitted successfully.',
          type: AppNotificationType.success,
        );
      }
    } catch (e) {
      _showError(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  void _showError(String msg) {
    showTopInAppNotification(
      context,
      title: 'Something Went Wrong',
      message: msg,
      type: AppNotificationType.error,
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AgentProfileViewModel>();
    final cert = vm.certification;
    final profile = vm.profile;
    final canSubmit =
        (_agentIdPhoto?.isReady ?? false) &&
        (_businessPhoto?.isReady ?? false) &&
        !vm.isSaving;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Certification'),
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
          : profile?.isCertified == true
          ? _buildCertifiedView()
          : cert != null && cert.isPending
          ? _buildPendingView()
          : _buildApplicationForm(vm, cert, canSubmit),
    );
  }

  Widget _buildCertifiedView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.verified,
                size: 40,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Certified Agent',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'You are a verified certified MoMo agent.\nUsers can see your certification badge.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.hourglass_top_rounded,
                size: 40,
                color: Colors.orange,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Under Review',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Your certification application is being reviewed.\nWe\'ll notify you once it\'s approved.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildApplicationForm(
    AgentProfileViewModel vm,
    dynamic previousCert,
    bool canSubmit,
  ) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
      children: [
        if (previousCert != null && previousCert.isRejected) ...[
          Container(
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline,
                  color: AppColors.error,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    previousCert.rejectionReason.isNotEmpty
                        ? 'Previous application rejected: ${previousCert.rejectionReason}'
                        : 'Your previous application was rejected. You can reapply.',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.error,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
        // Description
        const Text(
          'Become a Certified Agent',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Certified agents get a verification badge and are prioritized in search results.',
          style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 24),
        // Agent ID
        _SectionLabel('MTN MOMO AGENT ID'),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _agentIdCtrl,
            decoration: const InputDecoration(hintText: 'e.g. MTN-AGT-12345'),
          ),
        ),
        const SizedBox(height: 24),
        // Agent ID Photo
        _SectionLabel('AGENT ID CARD PHOTO'),
        const SizedBox(height: 8),
        _PhotoTile(
          photo: _agentIdPhoto,
          label: 'Upload your agent ID card',
          onTap: vm.isSaving || (_agentIdPhoto?.uploading ?? false)
              ? null
              : () => _choosePhotoSource(true),
        ),
        if (_agentIdPhoto?.error != null) ...[
          const SizedBox(height: 8),
          Text(
            _agentIdPhoto!.error!,
            style: const TextStyle(color: AppColors.error, fontSize: 13),
          ),
        ],
        const SizedBox(height: 24),
        // Business location photo
        _SectionLabel('BUSINESS LOCATION PHOTO'),
        const SizedBox(height: 8),
        _PhotoTile(
          photo: _businessPhoto,
          label: 'Upload your business stall photo',
          onTap: vm.isSaving || (_businessPhoto?.uploading ?? false)
              ? null
              : () => _choosePhotoSource(false),
        ),
        if (_businessPhoto?.error != null) ...[
          const SizedBox(height: 8),
          Text(
            _businessPhoto!.error!,
            style: const TextStyle(color: AppColors.error, fontSize: 13),
          ),
        ],
        const SizedBox(height: 24),
        // Business reg (optional)
        _SectionLabel('BUSINESS REGISTRATION (OPTIONAL)'),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _bizRegCtrl,
            decoration: const InputDecoration(hintText: 'Registration number'),
          ),
        ),
        if (vm.errorMessage != null) ...[
          const SizedBox(height: 16),
          Text(
            vm.errorMessage!,
            style: const TextStyle(color: AppColors.error, fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ],
        const SizedBox(height: 32),
        ElevatedButton(
          onPressed: canSubmit ? _submit : null,
          child: vm.isSaving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Submit Application'),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _PhotoTile extends StatelessWidget {
  final _PhotoUploadState? photo;
  final String label;
  final VoidCallback? onTap;
  const _PhotoTile({this.photo, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 140,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        clipBehavior: Clip.antiAlias,
        child: photo != null
            ? Stack(
                fit: StackFit.expand,
                children: [
                  Image.file(File(photo!.displayPath), fit: BoxFit.cover),
                  if (photo!.uploading)
                    Container(
                      color: Colors.black38,
                      alignment: Alignment.center,
                      child: const SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        photo!.uploading
                            ? 'Uploading...'
                            : photo!.isReady
                            ? 'Change Photo'
                            : 'Retry Upload',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ],
              )
            : Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.add_a_photo_outlined,
                      size: 32,
                      color: AppColors.textSecondary.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
