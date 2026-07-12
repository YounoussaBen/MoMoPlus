import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/data/services/backend_api_service.dart';
import '../../../core/ui/theme/app_theme_extension.dart';
import '../../../core/ui/widgets/app_button.dart';
import '../../../core/ui/widgets/ghana_phone_field.dart';
import '../../../core/utils/error_helpers.dart';
import '../../../core/utils/ghana_phone.dart';
import '../../auth/presentation/auth_view_model.dart';

class _GuarantorEntry {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();

  bool get isValid {
    if (nameController.text.trim().isEmpty) return false;
    try {
      normalizeGhanaPhone(phoneController.text);
      return true;
    } on GhanaPhoneException {
      return false;
    }
  }

  Map<String, String> toJson() => {
    'name': nameController.text.trim(),
    'phone_number': normalizeGhanaPhone(phoneController.text),
  };

  void dispose() {
    nameController.dispose();
    phoneController.dispose();
  }
}

class GuarantorsOnboardingScreen extends StatefulWidget {
  const GuarantorsOnboardingScreen({super.key});

  @override
  State<GuarantorsOnboardingScreen> createState() =>
      _GuarantorsOnboardingScreenState();
}

class _GuarantorsOnboardingScreenState
    extends State<GuarantorsOnboardingScreen> {
  final List<_GuarantorEntry> _entries = [_GuarantorEntry(), _GuarantorEntry()];
  bool _isSubmitting = false;
  String? _errorMessage;

  bool get _canSubmit =>
      !_isSubmitting && _entries.where((e) => e.isValid).length >= 2;

  @override
  void dispose() {
    for (final e in _entries) {
      e.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });
    try {
      final validEntries = _entries
          .where((e) => e.isValid)
          .map((e) => e.toJson())
          .toList();
      final api = context.read<BackendApiService>();
      await api.bulkCreateGuarantors(validEntries);
      if (mounted) {
        await context.read<AuthViewModel>().refreshProfile();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = friendlyErrorMessage(e));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _addEntry() {
    setState(() => _entries.add(_GuarantorEntry()));
  }

  void _removeEntry(int index) {
    if (_entries.length <= 2) return;
    setState(() {
      _entries[index].dispose();
      _entries.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appColors.canvas,
      appBar: AppBar(
        title: const Text('Loan Guarantors'),
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: context.appColors.brandSoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: context.appColors.brandStrong,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Add at least 2 guarantors for your loan applications. They may be contacted for verification.',
                          style: TextStyle(
                            fontSize: 13,
                            color: context.appColors.textPrimary,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                for (var i = 0; i < _entries.length; i++) ...[
                  _GuarantorCard(
                    index: i,
                    entry: _entries[i],
                    canRemove: _entries.length > 2,
                    onRemove: () => _removeEntry(i),
                    onChanged: () => setState(() {}),
                  ),
                  const SizedBox(height: 12),
                ],
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _addEntry,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add Another Guarantor'),
                    style: TextButton.styleFrom(
                      foregroundColor: context.appColors.brandStrong,
                    ),
                  ),
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: context.appColors.errorContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.error_outline,
                          color: context.appColors.error,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: TextStyle(
                              fontSize: 13,
                              color: context.appColors.error,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            decoration: BoxDecoration(
              color: context.appColors.surfaceSection,
              boxShadow: [
                BoxShadow(
                  color: context.appColors.scrim.withValues(alpha: 0.08),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: AppButton(
              label: 'Continue',
              onPressed: _canSubmit ? _submit : null,
              isLoading: _isSubmitting,
            ),
          ),
        ],
      ),
    );
  }
}

class _GuarantorCard extends StatelessWidget {
  final int index;
  final _GuarantorEntry entry;
  final bool canRemove;
  final VoidCallback onRemove;
  final VoidCallback onChanged;

  const _GuarantorCard({
    required this.index,
    required this.entry,
    required this.canRemove,
    required this.onRemove,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.appColors.surfaceSection,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: context.appColors.brandSoft,
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Text(
                  '${index + 1}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: context.appColors.brandStrong,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Guarantor ${index + 1}',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: context.appColors.textPrimary,
                ),
              ),
              const Spacer(),
              if (canRemove)
                GestureDetector(
                  onTap: onRemove,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: context.appColors.errorContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.close,
                      size: 16,
                      color: context.appColors.error,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: entry.nameController,
            onChanged: (_) => onChanged(),
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              hintText: 'Full name',
              prefixIcon: const Icon(Icons.person_outline, size: 20),
            ),
          ),
          const SizedBox(height: 10),
          GhanaPhoneField(
            controller: entry.phoneController,
            onChanged: (_) => onChanged(),
            autovalidateMode: AutovalidateMode.onUserInteraction,
          ),
        ],
      ),
    );
  }
}
