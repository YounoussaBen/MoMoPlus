import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/ui/theme/app_theme.dart';
import '../../../core/ui/widgets/app_button.dart';
import '../../auth/presentation/auth_view_model.dart';
import 'kyc_view_model.dart';

class KycStatusScreen extends StatelessWidget {
  const KycStatusScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<KycViewModel>();
    return switch (vm.screenState) {
      KycScreenState.pending => const _PendingView(),
      KycScreenState.rejected => const _RejectedView(),
      KycScreenState.approved => const _ApprovedView(),
      _ => const SizedBox.shrink(),
    };
  }
}

class _PendingView extends StatelessWidget {
  const _PendingView();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.hourglass_top_rounded,
            size: 40,
            color: Colors.orange.shade600,
          ),
        ),
        const SizedBox(height: 24),
        Text('Under review', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 10),
        Text(
          'Your documents are being reviewed. We\'ll let you know once the process is complete.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
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
            color: AppColors.error.withAlpha(20),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.close_rounded,
            size: 40,
            color: AppColors.error,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Verification failed',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 10),
        if (reason.isNotEmpty) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(reason, style: Theme.of(context).textTheme.bodyMedium),
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

class _ApprovedView extends StatelessWidget {
  const _ApprovedView();

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
            color: AppColors.primary.withAlpha(20),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.check_circle_outline,
            size: 40,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Verified',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 10),
        Text(
          'Your identity has been verified.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
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
