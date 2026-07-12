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
import '../../../../core/ui/widgets/app_status.dart';
import '../../../../core/ui/widgets/profile_avatar.dart';
import '../../../../core/ui/widgets/sign_out_sheet.dart';
import '../../../auth/presentation/auth_view_model.dart';

class AgentMoreScreen extends StatefulWidget {
  const AgentMoreScreen({super.key});

  @override
  State<AgentMoreScreen> createState() => _AgentMoreScreenState();
}

class _AgentMoreScreenState extends State<AgentMoreScreen> {
  final _scrollController = ScrollController();
  bool _showTitle = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
  }

  void _handleScroll() {
    final shouldShow = _scrollController.offset > 32;
    if (shouldShow != _showTitle) setState(() => _showTitle = shouldShow);
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
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 112),
              children: [
                _ProfileHeader(appUser: appUser),
                const SizedBox(height: AppSpacing.space5),
                _SectionCard(
                  children: [
                    _MoreTile(
                      icon: Icons.person_outline,
                      title: 'Profile',
                      subtitle: 'Personal information and KYC documents',
                      onTap: () => context.push('/profile'),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.space6),
                const AppSectionHeader(title: 'Agent tools'),
                const SizedBox(height: AppSpacing.space2),
                _SectionCard(
                  children: [
                    _MoreTile(
                      icon: Icons.tune_outlined,
                      title: 'Limits',
                      subtitle: 'Set minimum and maximum amounts',
                      onTap: () => context.push('/agent/limits'),
                    ),
                    _MoreTile(
                      icon: Icons.location_on_outlined,
                      title: 'Service area',
                      subtitle: 'Manage your location and coverage',
                      onTap: () => context.push('/agent/service-area'),
                    ),
                    _MoreTile(
                      icon: Icons.verified_outlined,
                      title: 'Certification',
                      subtitle: 'Manage your agent certification',
                      onTap: () => context.push('/agent/certification'),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.space6),
                const AppSectionHeader(title: 'Activity'),
                const SizedBox(height: AppSpacing.space2),
                _SectionCard(
                  children: [
                    _MoreTile(
                      icon: Icons.account_balance_wallet_outlined,
                      title: 'Wallet',
                      subtitle: 'Manage your mobile money wallets',
                      onTap: () => context.push('/wallet'),
                    ),
                    _MoreTile(
                      icon: Icons.people_outline,
                      title: 'Loan guarantors',
                      subtitle: 'Manage your guarantors',
                      onTap: () => context.push('/guarantors/manage'),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.space6),
                const AppSectionHeader(title: 'Account'),
                const SizedBox(height: AppSpacing.space2),
                _SectionCard(
                  children: [
                    _MoreTile(
                      icon: Icons.settings_outlined,
                      title: 'Settings',
                      subtitle: 'Appearance and app preferences',
                      onTap: () => context.push('/settings'),
                    ),
                    _MoreTile(
                      icon: Icons.help_outline,
                      title: 'Support',
                      subtitle: 'Get help with MoMo Plus',
                      onTap: () => context.push('/support'),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.space6),
                AppButton(
                  label: 'Sign out',
                  variant: AppButtonVariant.destructive,
                  onPressed: () async {
                    await showSignOutDialog(context, onConfirm: authVm.signOut);
                  },
                ),
              ],
            ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.appUser});

  final AppUser appUser;

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
          radius: 38,
        ),
        const SizedBox(height: AppSpacing.space3),
        Text(
          displayName,
          textAlign: TextAlign.center,
          style: context.appTextTheme.headlineMedium,
        ),
        const SizedBox(height: AppSpacing.space1),
        Text(
          appUser.contactLabel,
          textAlign: TextAlign.center,
          style: context.appTextTheme.bodyMedium?.copyWith(
            color: context.appColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.space2),
        const AppStatusBadge(
          label: 'Agent account',
          tone: AppStatusTone.brand,
          icon: Icons.storefront_outlined,
        ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return AppSection(
      padding: const EdgeInsets.all(AppSpacing.space2),
      child: Column(
        children: [
          for (var index = 0; index < children.length; index++) ...[
            children[index],
            if (index < children.length - 1)
              const SizedBox(height: AppSpacing.space2),
          ],
        ],
      ),
    );
  }
}

class _MoreTile extends StatelessWidget {
  const _MoreTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppListRow(
      title: title,
      subtitle: subtitle,
      leading: AppIconTile(icon: icon),
      showChevron: true,
      onTap: onTap,
    );
  }
}
