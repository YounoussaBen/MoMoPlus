import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/ui/theme/app_spacing.dart';
import '../../../core/ui/theme/app_theme_extension.dart';
import '../../../core/ui/widgets/app_button.dart';
import '../../../core/ui/widgets/app_icon_button.dart';
import '../../../core/ui/widgets/app_screen.dart';
import '../../../core/ui/widgets/app_section.dart';
import '../../../core/ui/widgets/app_text_field.dart';
import '../../../core/ui/widgets/top_in_app_notification.dart';
import 'agent_profile_view_model.dart';

class AgentLimitsScreen extends StatelessWidget {
  const AgentLimitsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _LimitsBody();
  }
}

class _LimitsBody extends StatefulWidget {
  const _LimitsBody();

  @override
  State<_LimitsBody> createState() => _LimitsBodyState();
}

class _LimitsBodyState extends State<_LimitsBody> {
  final _minimumController = TextEditingController();
  final _maximumController = TextEditingController();
  bool _didInitialize = false;

  @override
  void dispose() {
    _minimumController.dispose();
    _maximumController.dispose();
    super.dispose();
  }

  void _initializeFromProfile(AgentProfileViewModel viewModel) {
    if (_didInitialize || viewModel.profile == null) return;
    _didInitialize = true;
    final profile = viewModel.profile!;
    _minimumController.text = profile.minAmount > 0
        ? profile.minAmount.toStringAsFixed(0)
        : '';
    _maximumController.text = profile.maxAmount?.toStringAsFixed(0) ?? '';
  }

  Future<void> _save() async {
    final viewModel = context.read<AgentProfileViewModel>();
    final minimum = double.tryParse(_minimumController.text.trim());
    final maximum = double.tryParse(_maximumController.text.trim());

    if (minimum == null || maximum == null) {
      _showError(
        title: 'Missing amounts',
        message: 'Enter both a minimum and maximum amount.',
      );
      return;
    }

    if (minimum <= 0 || maximum <= 0) {
      _showError(
        title: 'Invalid amounts',
        message: 'Both amounts must be greater than zero.',
      );
      return;
    }

    if (maximum < minimum) {
      _showError(
        title: 'Check your limits',
        message: 'The maximum amount cannot be less than the minimum.',
      );
      return;
    }

    final saved = await viewModel.updateProfile({
      'min_amount': minimum.toStringAsFixed(2),
      'max_amount': maximum.toStringAsFixed(2),
    });

    if (!mounted) return;
    if (saved) {
      showTopInAppNotification(
        context,
        title: 'Limits saved',
        message: 'Your transaction limits were updated successfully.',
        type: AppNotificationType.success,
      );
    } else if (viewModel.errorMessage != null) {
      _showError(title: 'Could not save', message: viewModel.errorMessage!);
    }
  }

  void _showError({required String title, required String message}) {
    showTopInAppNotification(
      context,
      title: title,
      message: message,
      type: AppNotificationType.error,
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<AgentProfileViewModel>();
    _initializeFromProfile(viewModel);

    return AppScreen(
      title: 'Limits',
      body: viewModel.isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: context.appColors.brandAccent,
                strokeWidth: 2,
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 48),
              children: [
                Text(
                  'Transaction limits',
                  style: context.appTextTheme.headlineMedium,
                ),
                const SizedBox(height: AppSpacing.space1),
                Text(
                  'Choose the range of transaction amounts you can support.',
                  style: context.appTextTheme.bodyMedium?.copyWith(
                    color: context.appColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.space6),
                const AppSectionHeader(title: 'Amount range'),
                const SizedBox(height: AppSpacing.space2),
                AppSection(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AppTextField(
                        controller: _minimumController,
                        label: 'Minimum amount',
                        hint: 'GHS 0',
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        textInputAction: TextInputAction.next,
                        prefixIcon: const AppIconTile(
                          icon: Icons.south_west_rounded,
                          size: 40,
                          iconSize: 19,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.space4),
                      AppTextField(
                        controller: _maximumController,
                        label: 'Maximum amount',
                        hint: 'GHS 500',
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        textInputAction: TextInputAction.done,
                        prefixIcon: const AppIconTile(
                          icon: Icons.north_east_rounded,
                          size: 40,
                          iconSize: 19,
                        ),
                        onFieldSubmitted: (_) {
                          if (!viewModel.isSaving) _save();
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.space4),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.space3),
                  decoration: BoxDecoration(
                    color: context.appColors.infoContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 20,
                        color: context.appColors.info,
                      ),
                      const SizedBox(width: AppSpacing.space2),
                      Expanded(
                        child: Text(
                          'Users will only see you for eligible requests within this range.',
                          style: context.appTextTheme.bodySmall?.copyWith(
                            color: context.appColors.info,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (viewModel.errorMessage != null) ...[
                  const SizedBox(height: AppSpacing.space4),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.space3),
                    decoration: BoxDecoration(
                      color: context.appColors.errorContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      viewModel.errorMessage!,
                      textAlign: TextAlign.center,
                      style: context.appTextTheme.bodySmall?.copyWith(
                        color: context.appColors.error,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.space6),
                AppButton(
                  label: 'Save limits',
                  onPressed: viewModel.isSaving ? null : _save,
                  isLoading: viewModel.isSaving,
                ),
              ],
            ),
    );
  }
}
