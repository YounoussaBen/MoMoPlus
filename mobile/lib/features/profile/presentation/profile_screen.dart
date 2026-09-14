import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/domain/models/app_user.dart';
import '../../../core/ui/theme/app_spacing.dart';
import '../../../core/ui/theme/app_theme_extension.dart';
import '../../../core/ui/widgets/app_icon_button.dart';
import '../../../core/ui/widgets/app_list_row.dart';
import '../../../core/ui/widgets/app_screen.dart';
import '../../../core/ui/widgets/app_section.dart';
import '../../../core/ui/widgets/app_status.dart';
import '../../../core/ui/widgets/profile_avatar.dart';
import '../../auth/presentation/auth_view_model.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

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

    return ListView(
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
        _buildKycSection(context, authVm),
      ],
    );
  }

  Widget _buildKycSection(BuildContext context, AuthViewModel authVm) {
    final submission = authVm.kycSubmission;
    final documentUrls = authVm.kycDocumentUrls;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: AppSectionHeader(title: 'Identity verification'),
            ),
            AppStatusBadge(
              label: _statusLabel(authVm.kycStatus),
              tone: _statusTone(authVm.kycStatus),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.space2),
        if (submission == null)
          AppSection(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Text(
                'No verification documents have been submitted yet.',
                textAlign: TextAlign.center,
                style: context.appTextTheme.bodyMedium?.copyWith(
                  color: context.appColors.textSecondary,
                ),
              ),
            ),
          )
        else ...[
          const SizedBox(height: AppSpacing.space2),
          AppSection(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppListRow(
                  title: 'Ghana Card number',
                  subtitle:
                      submission['ghana_card_number']?.toString().isNotEmpty ==
                          true
                      ? submission['ghana_card_number'].toString()
                      : 'Not provided',
                  leading: const AppIconTile(icon: Icons.contact_page_outlined),
                ),
                const SizedBox(height: AppSpacing.space4),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final itemWidth = (constraints.maxWidth - 12) / 2;
                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        SizedBox(
                          width: itemWidth,
                          child: _DocumentCard(
                            label: 'Ghana Card front',
                            imageUrl: documentUrls['id_front_id'],
                            onTap: _previewAction(
                              context,
                              'Ghana Card front',
                              documentUrls['id_front_id'],
                            ),
                          ),
                        ),
                        SizedBox(
                          width: itemWidth,
                          child: _DocumentCard(
                            label: 'Ghana Card back',
                            imageUrl: documentUrls['id_back_id'],
                            onTap: _previewAction(
                              context,
                              'Ghana Card back',
                              documentUrls['id_back_id'],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.space6),
          const AppSectionHeader(title: 'Proof of residence'),
          const SizedBox(height: AppSpacing.space2),
          AppSection(
            child: _DocumentCard(
              label: 'Proof of residence',
              imageUrl: documentUrls['proof_of_address_id'],
              aspectRatio: 2.1,
              onTap: _previewAction(
                context,
                'Proof of residence',
                documentUrls['proof_of_address_id'],
              ),
            ),
          ),
          if ((submission['rejection_reason']?.toString() ?? '')
              .isNotEmpty) ...[
            const SizedBox(height: AppSpacing.space4),
            Container(
              padding: const EdgeInsets.all(AppSpacing.space3),
              decoration: BoxDecoration(
                color: context.appColors.errorContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                submission['rejection_reason'].toString(),
                style: context.appTextTheme.bodyMedium?.copyWith(
                  color: context.appColors.error,
                ),
              ),
            ),
          ],
        ],
      ],
    );
  }

  VoidCallback? _previewAction(
    BuildContext context,
    String label,
    String? imageUrl,
  ) {
    if (imageUrl == null) return null;
    return () => _showDocument(context, label, imageUrl);
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
                  child: Image(
                    image: NetworkImage(imageUrl),
                    fit: BoxFit.contain,
                    gaplessPlayback: true,
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
    this.aspectRatio = 1.45,
  });

  final String label;
  final String? imageUrl;
  final VoidCallback? onTap;
  final double aspectRatio;

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
              aspectRatio: aspectRatio,
              child: imageUrl == null
                  ? const _DocumentUnavailable()
                  : Image(
                      image: NetworkImage(imageUrl!),
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
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
