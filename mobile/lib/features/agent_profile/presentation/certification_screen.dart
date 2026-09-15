import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../../core/data/services/backend_api_service.dart';
import '../../../core/data/services/file_upload_service.dart';
import '../../../core/ui/theme/app_spacing.dart';
import '../../../core/ui/theme/app_theme_extension.dart';
import '../../../core/ui/widgets/app_button.dart';
import '../../../core/ui/widgets/app_screen.dart';
import '../../../core/ui/widgets/app_section.dart';
import '../../../core/ui/widgets/app_status.dart';
import '../../../core/ui/widgets/app_text_field.dart';
import '../../../core/utils/error_helpers.dart';
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
    return const _CertificationBody();
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
      _showError('Could not open image picker: ${friendlyErrorMessage(e)}');
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
      final message = friendlyErrorMessage(e);
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
      _showError(friendlyErrorMessage(e));
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

    return AppScreen(
      title: 'Certification',
      body: vm.isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: context.appColors.brandAccent,
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
        padding: const EdgeInsets.all(AppSpacing.space4),
        child: AppSection(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.space6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: context.appColors.successContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.verified_rounded,
                    size: 36,
                    color: context.appColors.success,
                  ),
                ),
                const SizedBox(height: AppSpacing.space4),
                Text(
                  'Certified agent',
                  style: context.appTextTheme.headlineMedium,
                ),
                const SizedBox(height: AppSpacing.space2),
                Text(
                  'Your certification badge is visible to users across MoMo Plus.',
                  textAlign: TextAlign.center,
                  style: context.appTextTheme.bodyMedium?.copyWith(
                    color: context.appColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.space3),
                const AppStatusBadge(
                  label: 'Verified',
                  tone: AppStatusTone.success,
                  icon: Icons.check_circle_outline_rounded,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPendingView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.space4),
        child: AppSection(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.space6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: context.appColors.warningContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.hourglass_top_rounded,
                    size: 36,
                    color: context.appColors.warning,
                  ),
                ),
                const SizedBox(height: AppSpacing.space4),
                Text(
                  'Under review',
                  style: context.appTextTheme.headlineMedium,
                ),
                const SizedBox(height: AppSpacing.space2),
                Text(
                  'Your certification application is being reviewed. We will notify you when a decision is ready.',
                  textAlign: TextAlign.center,
                  style: context.appTextTheme.bodyMedium?.copyWith(
                    color: context.appColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.space3),
                const AppStatusBadge(
                  label: 'Pending review',
                  tone: AppStatusTone.warning,
                ),
              ],
            ),
          ),
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
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 48),
      children: [
        if (previousCert != null && previousCert.isRejected) ...[
          Container(
            decoration: BoxDecoration(
              color: context.appColors.errorContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: context.appColors.error,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    previousCert.rejectionReason.isNotEmpty
                        ? 'Previous application rejected: ${previousCert.rejectionReason}'
                        : 'Your previous application was rejected. You can reapply.',
                    style: context.appTextTheme.bodySmall?.copyWith(
                      color: context.appColors.error,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
        Text(
          'Become a certified agent',
          style: context.appTextTheme.headlineMedium,
        ),
        const SizedBox(height: 6),
        Text(
          'Certified agents get a verification badge and are prioritized in search results.',
          style: context.appTextTheme.bodyMedium?.copyWith(
            color: context.appColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.space6),
        const AppSectionHeader(title: 'Agent details'),
        const SizedBox(height: AppSpacing.space2),
        AppSection(
          child: Column(
            children: [
              AppTextField(
                controller: _agentIdCtrl,
                label: 'MTN MoMo agent ID',
                hint: 'e.g. MTN-AGT-12345',
              ),
              const SizedBox(height: AppSpacing.space4),
              AppTextField(
                controller: _bizRegCtrl,
                label: 'Business registration',
                hint: 'Optional registration number',
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.space6),
        const AppSectionHeader(title: 'Verification photos'),
        const SizedBox(height: AppSpacing.space2),
        AppSection(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Agent ID card', style: context.appTextTheme.titleSmall),
              const SizedBox(height: AppSpacing.space2),
              _PhotoTile(
                photo: _agentIdPhoto,
                label: 'Upload your agent ID card',
                onTap: vm.isSaving || (_agentIdPhoto?.uploading ?? false)
                    ? null
                    : () => _choosePhotoSource(true),
              ),
              if (_agentIdPhoto?.error != null) ...[
                const SizedBox(height: AppSpacing.space2),
                _InlineError(message: _agentIdPhoto!.error!),
              ],
              const SizedBox(height: AppSpacing.space4),
              Text('Business location', style: context.appTextTheme.titleSmall),
              const SizedBox(height: AppSpacing.space2),
              _PhotoTile(
                photo: _businessPhoto,
                label: 'Upload your business location',
                onTap: vm.isSaving || (_businessPhoto?.uploading ?? false)
                    ? null
                    : () => _choosePhotoSource(false),
              ),
              if (_businessPhoto?.error != null) ...[
                const SizedBox(height: AppSpacing.space2),
                _InlineError(message: _businessPhoto!.error!),
              ],
            ],
          ),
        ),
        if (vm.errorMessage != null) ...[
          const SizedBox(height: AppSpacing.space4),
          _InlineError(message: vm.errorMessage!),
        ],
        const SizedBox(height: AppSpacing.space6),
        AppButton(
          label: 'Submit application',
          onPressed: canSubmit ? _submit : null,
          isLoading: vm.isSaving,
        ),
      ],
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Text(
    message,
    style: context.appTextTheme.bodySmall?.copyWith(
      color: context.appColors.error,
    ),
  );
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
          color: context.appColors.surfaceInteractive,
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
                      color: context.appColors.textMuted,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      label,
                      style: context.appTextTheme.bodySmall?.copyWith(
                        color: context.appColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
