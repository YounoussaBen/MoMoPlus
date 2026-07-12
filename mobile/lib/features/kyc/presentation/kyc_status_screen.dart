import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/ui/theme/app_theme_extension.dart';
import '../../../core/ui/widgets/app_button.dart';
import '../../auth/presentation/auth_view_model.dart';
import 'kyc_view_model.dart';

class KycStatusScreen extends StatelessWidget {
  const KycStatusScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<KycViewModel>();
    final content = switch (vm.screenState) {
      KycScreenState.pending => const _PendingView(),
      KycScreenState.rejected => const _RejectedView(),
      KycScreenState.approved => const _ApprovedView(),
      KycScreenState.error => const _ErrorView(),
      _ => const SizedBox.shrink(),
    };

    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: content,
        ),
      ),
    );
  }
}

class _PendingView extends StatelessWidget {
  const _PendingView();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<KycViewModel>();
    final authVm = context.read<AuthViewModel>();

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: context.appColors.warningContainer,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.hourglass_top_rounded,
            size: 40,
            color: context.appColors.warning,
          ),
        ),
        const SizedBox(height: 24),
        Text('Under review', style: context.appTextTheme.headlineMedium),
        const SizedBox(height: 10),
        Text(
          'Your documents are being reviewed. We\'ll let you know once the process is complete.',
          textAlign: TextAlign.center,
          style: context.appTextTheme.bodyMedium?.copyWith(
            color: context.appColors.textSecondary,
          ),
        ),
        if (vm.errorMessage != null) ...[
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.appColors.errorContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              vm.errorMessage!,
              textAlign: TextAlign.center,
              style: context.appTextTheme.bodyMedium?.copyWith(
                color: context.appColors.error,
              ),
            ),
          ),
        ],
        const SizedBox(height: 28),
        AppButton(
          label: 'Check status',
          isLoading: vm.isRefreshing,
          onPressed: vm.refreshStatus,
        ),
        const SizedBox(height: 8),
        AppButton(
          label: 'Get help',
          variant: AppButtonVariant.secondary,
          onPressed: () => context.push('/support'),
        ),
        const SizedBox(height: 8),
        AppButton(
          label: 'Sign out',
          variant: AppButtonVariant.ghost,
          onPressed: authVm.isLoading ? null : authVm.signOut,
        ),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<KycViewModel>();
    final authVm = context.read<AuthViewModel>();

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: context.appColors.errorContainer,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.cloud_off_rounded,
            size: 40,
            color: context.appColors.error,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Could not load your status',
          textAlign: TextAlign.center,
          style: context.appTextTheme.headlineMedium,
        ),
        const SizedBox(height: 10),
        Text(
          vm.errorMessage ?? 'Check your connection and try again.',
          textAlign: TextAlign.center,
          style: context.appTextTheme.bodyMedium?.copyWith(
            color: context.appColors.textSecondary,
          ),
        ),
        const SizedBox(height: 28),
        AppButton(
          label: 'Try again',
          isLoading: vm.isRefreshing,
          onPressed: () => vm.refreshStatus(showLoading: true),
        ),
        const SizedBox(height: 8),
        AppButton(
          label: 'Get help',
          variant: AppButtonVariant.secondary,
          onPressed: () => context.push('/support'),
        ),
        const SizedBox(height: 8),
        AppButton(
          label: 'Sign out',
          variant: AppButtonVariant.ghost,
          onPressed: authVm.isLoading ? null : authVm.signOut,
        ),
      ],
    );
  }
}

class _RejectedView extends StatelessWidget {
  const _RejectedView();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<KycViewModel>();
    final reason = vm.submission?.rejectionReason ?? '';

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: context.appColors.errorContainer,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.close_rounded,
            size: 40,
            color: context.appColors.error,
          ),
        ),
        const SizedBox(height: 24),
        Text('Verification failed', style: context.appTextTheme.headlineMedium),
        const SizedBox(height: 10),
        if (reason.isNotEmpty) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.appColors.surfaceSection,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              reason,
              style: context.appTextTheme.bodyMedium?.copyWith(
                color: context.appColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(height: 28),
        ] else
          const SizedBox(height: 16),
        AppButton(
          label: 'Resubmit documents',
          onPressed: () => context.read<KycViewModel>().startResubmit(),
        ),
      ],
    );
  }
}

class _ApprovedView extends StatefulWidget {
  const _ApprovedView();

  @override
  State<_ApprovedView> createState() => _ApprovedViewState();
}

class _ApprovedViewState extends State<_ApprovedView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(context.read<AuthViewModel>().markKycApprovalPresented());
    });
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<KycViewModel>();
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: context.appColors.successContainer,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.check_circle_outline,
            size: 40,
            color: context.appColors.success,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Verified',
          textAlign: TextAlign.center,
          style: context.appTextTheme.headlineMedium,
        ),
        const SizedBox(height: 10),
        Text(
          'Your identity has been verified.',
          textAlign: TextAlign.center,
          style: context.appTextTheme.bodyMedium?.copyWith(
            color: context.appColors.textSecondary,
          ),
        ),
        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity,
          child: AppButton(
            label: 'Continue',
            isLoading: vm.isGoingHome,
            onPressed: () async {
              await vm.goHome();
              if (context.mounted) {
                final authVm = context.read<AuthViewModel>();
                context.go(
                  authVm.appUser?.isAgent == true
                      ? '/agent/home'
                      : '/user/home',
                );
              }
            },
          ),
        ),
      ],
    );
  }
}
