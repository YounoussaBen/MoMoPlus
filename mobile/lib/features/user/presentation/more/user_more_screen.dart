import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../core/domain/models/app_user.dart';
import '../../../../core/ui/theme/app_spacing.dart';
import '../../../../core/ui/theme/app_theme_extension.dart';
import '../../../../core/ui/widgets/app_button.dart';
import '../../../../core/ui/widgets/app_icon_button.dart';
import '../../../../core/ui/widgets/app_list_row.dart';
import '../../../../core/ui/widgets/app_section.dart';
import '../../../../core/ui/widgets/profile_avatar.dart';
import '../../../../core/ui/widgets/sign_out_sheet.dart';
import '../../../auth/presentation/auth_view_model.dart';

class UserMoreScreen extends StatefulWidget {
  const UserMoreScreen({super.key});

  @override
  State<UserMoreScreen> createState() => _UserMoreScreenState();
}

class _UserMoreScreenState extends State<UserMoreScreen> {
  static const _titleRevealOffset = 32.0;
  final _scrollController = ScrollController();
  bool _showTitle = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
  }

  void _handleScroll() {
    final shouldShow = _scrollController.offset > _titleRevealOffset;
    if (shouldShow != _showTitle) {
      setState(() => _showTitle = shouldShow);
    }
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authVm = context.watch<AuthViewModel>();
    final appUser = authVm.appUser;

    return Scaffold(
      backgroundColor: context.appColors.canvas,
      appBar: AppBar(
        centerTitle: true,
        title: AnimatedOpacity(
          opacity: _showTitle ? 1 : 0,
          duration: const Duration(milliseconds: 180),
          child: const Text('More'),
        ),
      ),
      body: appUser == null
          ? Center(
              child: CircularProgressIndicator(
                color: context.appColors.brandAccent,
                strokeWidth: 2,
              ),
            )
          : ListView(
              controller: _scrollController,
              padding: const EdgeInsets.only(
                left: 16,
                right: 16,
                top: 20,
                bottom: 100,
              ),
              children: [
                _ProfileHeader(appUser: appUser),
                const SizedBox(height: 20),
                _SectionCard(
                  children: [
                    _MoreTile(
                      icon: Icons.person_outline,
                      title: 'Profile',
                      subtitle: 'Personal information',
                      onTap: () => context.push('/profile'),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _AgentApplicationSection(appUser: appUser, authVm: authVm),
                const SizedBox(height: 20),
                _SectionHeader(title: 'Activity'),
                const SizedBox(height: 8),
                _SectionCard(
                  children: [
                    _MoreTile(
                      icon: Icons.account_balance_wallet_outlined,
                      title: 'Wallet',
                      subtitle: 'Manage your wallet',
                      onTap: () => context.push('/wallet'),
                    ),
                    _MoreTile(
                      icon: Icons.people_outline,
                      title: 'Loan Guarantors',
                      subtitle: 'Manage your guarantors',
                      onTap: () => context.push('/guarantors/manage'),
                    ),
                    _MoreTile(
                      icon: Icons.receipt_long_outlined,
                      title: 'Activity',
                      subtitle: 'View all your activity',
                      onTap: () => context.go('/user/activity'),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _SectionHeader(title: 'Account'),
                const SizedBox(height: 8),
                _SectionCard(
                  children: [
                    _MoreTile(
                      icon: Icons.settings_outlined,
                      title: 'Settings',
                      subtitle: 'App preferences',
                      onTap: () => context.push('/settings'),
                    ),
                    _MoreTile(
                      icon: Icons.help_outline,
                      title: 'Support',
                      subtitle: 'Get help',
                      onTap: () => context.push('/support'),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                AppButton(
                  label: 'Sign out',
                  variant: AppButtonVariant.destructive,
                  onPressed: () async {
                    await showSignOutDialog(context, onConfirm: authVm.signOut);
                  },
                ),
                const SizedBox(height: 32),
              ],
            ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final List<Widget> children;
  const _SectionCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return AppSection(
      padding: const EdgeInsets.all(AppSpacing.space2),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var index = 0; index < children.length; index++) ...[
            children[index],
            if (index != children.length - 1)
              const SizedBox(height: AppSpacing.space2),
          ],
        ],
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  final AppUser appUser;
  const _ProfileHeader({required this.appUser});

  @override
  Widget build(BuildContext context) {
    final authVm = context.watch<AuthViewModel>();
    final displayName = appUser.fullName.isNotEmpty
        ? appUser.fullName
        : appUser.contactLabel;

    return Column(
      children: [
        ProfileAvatar(
          imageUrl: authVm.selfieUrl,
          fallbackLetter: displayName[0],
          radius: 36,
        ),
        const SizedBox(height: 12),
        Text(displayName, style: context.appTextTheme.headlineMedium),
        const SizedBox(height: 2),
        Text(
          appUser.contactLabel,
          style: context.appTextTheme.bodyMedium?.copyWith(
            color: context.appColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _AgentApplicationSection extends StatelessWidget {
  final AppUser appUser;
  final AuthViewModel authVm;
  const _AgentApplicationSection({required this.appUser, required this.authVm});

  @override
  Widget build(BuildContext context) {
    if (appUser.agentStatus == AgentStatus.pending) {
      return AppSection(
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: context.appColors.warningContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.hourglass_top_rounded,
                color: context.appColors.warning,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Become an Agent',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: context.appColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Application pending review',
                    style: TextStyle(
                      fontSize: 13,
                      color: context.appColors.warning,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final isRejected = appUser.agentStatus == AgentStatus.rejected;

    return GestureDetector(
      onTap: authVm.isLoading
          ? null
          : () => context.read<AuthViewModel>().requestAgent(),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.appColors.brandAccent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: context.appColors.onBrandAccent.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.badge_rounded,
                color: context.appColors.onBrandAccent,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isRejected ? 'Re-apply as Agent' : 'Become an Agent',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: context.appColors.onBrandAccent,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isRejected
                        ? 'Your previous application was rejected'
                        : 'Start earning by helping others',
                    style: TextStyle(
                      fontSize: 13,
                      color: context.appColors.onBrandAccent.withValues(
                        alpha: 0.78,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            authVm.isLoading
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: context.appColors.onBrandAccent,
                      strokeWidth: 2,
                    ),
                  )
                : Icon(
                    Icons.arrow_forward_rounded,
                    color: context.appColors.onBrandAccent,
                    size: 20,
                  ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return AppSectionHeader(title: title);
  }
}

class _MoreTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  const _MoreTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppListRow(
      leading: AppIconTile(icon: icon),
      title: title,
      subtitle: subtitle,
      showChevron: onTap != null,
      onTap: onTap,
    );
  }
}
