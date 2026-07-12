import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/data/services/backend_api_service.dart';
import '../../../core/domain/models/app_user.dart';
import '../../../core/ui/theme/app_spacing.dart';
import '../../../core/ui/theme/app_theme_extension.dart';
import '../../../core/ui/widgets/app_button.dart';
import '../../../core/ui/widgets/app_icon_button.dart';
import '../../../core/ui/widgets/app_list_row.dart';
import '../../../core/ui/widgets/app_screen.dart';
import '../../../core/ui/widgets/app_section.dart';
import '../../../core/ui/widgets/app_status.dart';
import '../../../core/ui/widgets/profile_avatar.dart';
import '../../auth/presentation/auth_view_model.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const _documentFields = <String, String>{
    'id_front_id': 'ID front',
    'id_back_id': 'ID back',
    'proof_of_address_id': 'Proof of address',
  };

  bool _isLoadingDocuments = true;
  String? _documentsError;
  Map<String, dynamic>? _kycSubmission;
  final Map<String, String> _documentUrls = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadDocuments());
  }

  Future<void> _loadDocuments() async {
    if (!mounted) return;
    setState(() {
      _isLoadingDocuments = true;
      _documentsError = null;
    });

    try {
      final api = context.read<BackendApiService>();
      final submission = await api.getKycStatus();
      final urls = <String, String>{};

      if (submission != null) {
        for (final field in _documentFields.keys) {
          final assetId = submission[field]?.toString();
          if (assetId == null || assetId.isEmpty) continue;
          final url = await api.getFileAccessUrl(assetId);
          if (url != null && url.isNotEmpty) urls[field] = url;
        }
      }

      if (!mounted) return;
      setState(() {
        _kycSubmission = submission;
        _documentUrls
          ..clear()
          ..addAll(urls);
        _isLoadingDocuments = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _documentsError = 'We could not load your verification documents.';
        _isLoadingDocuments = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authVm = context.watch<AuthViewModel>();
    final appUser = authVm.appUser;

    return AppScreen(
      title: 'Profile',
      body: appUser == null
          ? Center(
              child: CircularProgressIndicator(
                color: context.appColors.brandAccent,
                strokeWidth: 2,
              ),
            )
          : _buildProfile(context, authVm, appUser),
    );
  }

  Widget _buildProfile(
    BuildContext context,
    AuthViewModel authVm,
    AppUser appUser,
  ) {
    final displayName = appUser.fullName.isNotEmpty
        ? appUser.fullName
        : appUser.contactLabel;

    return RefreshIndicator(
      color: context.appColors.brandAccent,
      onRefresh: _loadDocuments,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 48),
        children: [
          Center(
            child: ProfileAvatar(
              imageUrl: authVm.selfieUrl,
              fallbackLetter: displayName[0],
              radius: 52,
            ),
          ),
          const SizedBox(height: AppSpacing.space4),
          Text(
            displayName,
            textAlign: TextAlign.center,
            style: context.appTextTheme.headlineMedium,
          ),
          const SizedBox(height: AppSpacing.space2),
          Center(
            child: AppStatusBadge(
              label: appUser.isAgent ? 'Agent' : 'User',
              tone: AppStatusTone.brand,
            ),
          ),
          const SizedBox(height: AppSpacing.space6),
          const AppSectionHeader(title: 'Personal information'),
          const SizedBox(height: AppSpacing.space2),
          AppSection(
            padding: const EdgeInsets.all(AppSpacing.space2),
            child: Column(
              children: [
                AppListRow(
                  title: 'First name',
                  subtitle: appUser.firstName.isNotEmpty
                      ? appUser.firstName
                      : 'Not provided',
                  leading: const AppIconTile(icon: Icons.person_outline),
                ),
                const SizedBox(height: AppSpacing.space2),
                AppListRow(
                  title: 'Last name',
                  subtitle: appUser.lastName.isNotEmpty
                      ? appUser.lastName
                      : 'Not provided',
                  leading: const AppIconTile(icon: Icons.badge_outlined),
                ),
                const SizedBox(height: AppSpacing.space2),
                AppListRow(
                  title: appUser.phone.isNotEmpty ? 'Phone number' : 'Email',
                  subtitle: appUser.contactLabel,
                  leading: AppIconTile(
                    icon: appUser.phone.isNotEmpty
                        ? Icons.phone_outlined
                        : Icons.email_outlined,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.space6),
          _buildKycSection(context, appUser),
        ],
      ),
    );
  }

  Widget _buildKycSection(BuildContext context, AppUser appUser) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: AppSectionHeader(title: 'Identity verification'),
            ),
            AppStatusBadge(
              label: _statusLabel(appUser.kycStatus),
              tone: _statusTone(appUser.kycStatus),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.space2),
        AppSection(
          child: _isLoadingDocuments
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: context.appColors.brandAccent,
                      strokeWidth: 2,
                    ),
                  ),
                )
              : _documentsError != null
              ? Column(
                  children: [
                    Icon(
                      Icons.cloud_off_outlined,
                      color: context.appColors.textMuted,
                    ),
                    const SizedBox(height: AppSpacing.space2),
                    Text(
                      _documentsError!,
                      textAlign: TextAlign.center,
                      style: context.appTextTheme.bodyMedium?.copyWith(
                        color: context.appColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.space2),
                    AppButton(
                      label: 'Try again',
                      variant: AppButtonVariant.ghost,
                      onPressed: _loadDocuments,
                    ),
                  ],
                )
              : _kycSubmission == null
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Text(
                    'No verification documents have been submitted yet.',
                    textAlign: TextAlign.center,
                    style: context.appTextTheme.bodyMedium?.copyWith(
                      color: context.appColors.textSecondary,
                    ),
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppListRow(
                      title: 'ID type',
                      subtitle: _formatIdType(
                        _kycSubmission?['id_type']?.toString(),
                      ),
                      leading: const AppIconTile(
                        icon: Icons.contact_page_outlined,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.space4),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final itemWidth = (constraints.maxWidth - 12) / 2;
                        return Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            for (final entry in _documentFields.entries)
                              SizedBox(
                                width: itemWidth,
                                child: _DocumentCard(
                                  label: entry.value,
                                  imageUrl: _documentUrls[entry.key],
                                  onTap: _documentUrls[entry.key] == null
                                      ? null
                                      : () => _showDocument(
                                          context,
                                          entry.value,
                                          _documentUrls[entry.key]!,
                                        ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                    if ((_kycSubmission?['rejection_reason']?.toString() ?? '')
                        .isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.space4),
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.space3),
                        decoration: BoxDecoration(
                          color: context.appColors.errorContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _kycSubmission!['rejection_reason'].toString(),
                          style: context.appTextTheme.bodyMedium?.copyWith(
                            color: context.appColors.error,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
        ),
      ],
    );
  }

  void _showDocument(BuildContext context, String label, String imageUrl) {
    showDialog<void>(
      context: context,
      barrierColor: context.appColors.scrim,
      builder: (dialogContext) => Dialog(
        backgroundColor: context.appColors.surfaceSection,
        insetPadding: const EdgeInsets.all(16),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        style: context.appTextTheme.titleMedium,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.pop(dialogContext),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: InteractiveViewer(
                  minScale: 0.8,
                  maxScale: 4,
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => const _DocumentUnavailable(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DocumentCard extends StatelessWidget {
  const _DocumentCard({
    required this.label,
    required this.imageUrl,
    required this.onTap,
  });

  final String label;
  final String? imageUrl;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.appColors.surfaceInteractive,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 1.45,
              child: imageUrl == null
                  ? const _DocumentUnavailable()
                  : Image.network(
                      imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const _DocumentUnavailable(),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.space3),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.appTextTheme.labelLarge,
                    ),
                  ),
                  if (imageUrl != null)
                    Icon(
                      Icons.open_in_full_rounded,
                      size: 16,
                      color: context.appColors.textMuted,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DocumentUnavailable extends StatelessWidget {
  const _DocumentUnavailable();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: context.appColors.surfaceSubtle,
      child: Center(
        child: Icon(
          Icons.description_outlined,
          color: context.appColors.textMuted,
          size: 32,
        ),
      ),
    );
  }
}

String _formatIdType(String? value) {
  if (value == null || value.isEmpty) return 'Not provided';
  return value
      .split('_')
      .map(
        (part) => part.isEmpty
            ? part
            : '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}',
      )
      .join(' ');
}

String _statusLabel(KycStatus status) => switch (status) {
  KycStatus.none => 'Not submitted',
  KycStatus.pending => 'Pending',
  KycStatus.approved => 'Verified',
  KycStatus.rejected => 'Rejected',
};

AppStatusTone _statusTone(KycStatus status) => switch (status) {
  KycStatus.none => AppStatusTone.neutral,
  KycStatus.pending => AppStatusTone.warning,
  KycStatus.approved => AppStatusTone.success,
  KycStatus.rejected => AppStatusTone.error,
};
