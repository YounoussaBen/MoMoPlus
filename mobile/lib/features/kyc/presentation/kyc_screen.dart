import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/data/repositories/auth_repository.dart';
import '../../../core/data/services/file_upload_service.dart';
import '../../../core/ui/theme/app_theme.dart';
import '../../auth/presentation/auth_view_model.dart';
import '../data/kyc_repository.dart';
import 'kyc_status_screen.dart';
import 'kyc_view_model.dart';
import 'steps/step1_id_type_screen.dart';
import 'steps/step2_selfie_screen.dart';
import 'steps/step3_address_screen.dart';
import 'widgets/kyc_progress_bar.dart';

class KycScreen extends StatelessWidget {
  const KycScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) => KycViewModel(
        repository: KycRepository(
          authRepository: ctx.read<AuthRepository>(),
          uploadService: ctx.read<FileUploadService>(),
        ),
        authViewModel: ctx.read<AuthViewModel>(),
      ),
      child: const _KycView(),
    );
  }
}

class _KycView extends StatelessWidget {
  const _KycView();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<KycViewModel>();

    if (vm.screenState == KycScreenState.loading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            color: AppColors.primary,
            strokeWidth: 2,
          ),
        ),
      );
    }

    final isWizard = vm.screenState == KycScreenState.wizard;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Identity Verification'),
        leading: isWizard && vm.step > 0
            ? BackButton(
                onPressed: () => context.read<KycViewModel>().prevStep(),
              )
            : const SizedBox.shrink(),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isWizard) ...[
                const SizedBox(height: 4),
                KycProgressBar(currentStep: vm.step),
                const SizedBox(height: 28),
              ] else
                const SizedBox(height: 16),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 280),
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position:
                          Tween<Offset>(
                            begin: const Offset(0.06, 0),
                            end: Offset.zero,
                          ).animate(
                            CurvedAnimation(
                              parent: animation,
                              curve: Curves.easeOut,
                            ),
                          ),
                      child: child,
                    ),
                  ),
                  child: KeyedSubtree(
                    key: ValueKey(isWizard ? vm.step : vm.screenState),
                    child: isWizard
                        ? _stepWidget(vm.step)
                        : const KycStatusScreen(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stepWidget(int step) => switch (step) {
    0 => const Step1IdTypeScreen(),
    1 => const Step2SelfieScreen(),
    2 => const Step3AddressScreen(),
    _ => const Step1IdTypeScreen(),
  };
}
