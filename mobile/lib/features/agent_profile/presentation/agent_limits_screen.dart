import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/data/services/backend_api_service.dart';
import '../../../core/ui/theme/app_theme.dart';
import '../../../core/ui/widgets/top_in_app_notification.dart';
import 'agent_profile_view_model.dart';

class AgentLimitsScreen extends StatelessWidget {
  const AgentLimitsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) => AgentProfileViewModel(ctx.read<BackendApiService>()),
      child: const _LimitsBody(),
    );
  }
}

class _LimitsBody extends StatefulWidget {
  const _LimitsBody();

  @override
  State<_LimitsBody> createState() => _LimitsBodyState();
}

class _LimitsBodyState extends State<_LimitsBody> {
  final _minCtrl = TextEditingController();
  final _maxCtrl = TextEditingController();
  bool _didInit = false;

  @override
  void dispose() {
    _minCtrl.dispose();
    _maxCtrl.dispose();
    super.dispose();
  }

  void _initFromProfile(AgentProfileViewModel vm) {
    if (_didInit || vm.profile == null) return;
    _didInit = true;
    final p = vm.profile!;
    _minCtrl.text = p.minAmount > 0 ? p.minAmount.toStringAsFixed(0) : '';
    _maxCtrl.text = p.maxAmount != null ? p.maxAmount!.toStringAsFixed(0) : '';
  }

  Future<void> _save() async {
    final vm = context.read<AgentProfileViewModel>();

    final min = double.tryParse(_minCtrl.text);
    final max = double.tryParse(_maxCtrl.text);

    if (min == null || max == null) {
      showTopInAppNotification(
        context,
        title: 'Missing Fields',
        message: 'Please enter both a minimum and maximum amount.',
        type: AppNotificationType.error,
      );
      return;
    }

    if (min <= 0 || max <= 0) {
      showTopInAppNotification(
        context,
        title: 'Invalid Amounts',
        message: 'Both minimum and maximum amounts must be greater than zero.',
        type: AppNotificationType.error,
      );
      return;
    }

    final fields = <String, dynamic>{
      'min_amount': min.toStringAsFixed(2),
      'max_amount': max.toStringAsFixed(2),
    };

    final ok = await vm.updateProfile(fields);
    if (ok && mounted) {
      showTopInAppNotification(
        context,
        title: 'Saved',
        message: 'Your amount limits were updated successfully.',
        type: AppNotificationType.success,
      );
    } else if (mounted && vm.errorMessage != null) {
      showTopInAppNotification(
        context,
        title: 'Could Not Save',
        message: vm.errorMessage!,
        type: AppNotificationType.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AgentProfileViewModel>();
    _initFromProfile(vm);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Limits'),
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
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
              children: [
                _SectionLabel('AMOUNT LIMITS'),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _Field(
                        label: 'Minimum Amount (GHS)',
                        controller: _minCtrl,
                        hint: '0',
                      ),
                      const SizedBox(height: 16),
                      _Field(
                        label: 'Maximum Amount (GHS)',
                        controller: _maxCtrl,
                        hint: 'e.g. 500',
                      ),
                    ],
                  ),
                ),
                if (vm.errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    vm.errorMessage!,
                    style: const TextStyle(
                      color: AppColors.error,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: vm.isSaving ? null : _save,
                  child: vm.isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Save'),
                ),
              ],
            ),
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

class _Field extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String hint;
  const _Field({
    required this.label,
    required this.controller,
    required this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(hintText: hint),
        ),
      ],
    );
  }
}
