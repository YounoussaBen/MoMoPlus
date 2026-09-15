import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/data/services/backend_api_service.dart';
import '../../../core/ui/theme/app_theme_extension.dart';
import '../../../core/ui/widgets/app_button.dart';
import '../../../core/ui/widgets/ghana_phone_field.dart';
import '../../../core/utils/error_helpers.dart';
import '../../../core/utils/ghana_phone.dart';
import '../../auth/presentation/auth_view_model.dart';
import '../data/guarantor_model.dart';
import 'guarantor_verification_sheet.dart';

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
  _GuarantorEntry _entry = _GuarantorEntry();
  bool _isSubmitting = false;
  bool _isLoadingExisting = true;
  int _verifiedCount = 0;
  List<Guarantor> _pendingVerification = [];
  Guarantor? _activeGuarantor;
  String? _errorMessage;

  bool get _isComplete =>
      _verifiedCount >= 2 &&
      _pendingVerification.isEmpty &&
      _activeGuarantor == null;

  bool get _hasConsentToVerify =>
      _pendingVerification.isNotEmpty || _activeGuarantor != null;

  bool get _canSubmit =>
      !_isSubmitting &&
      !_isLoadingExisting &&
      !_isComplete &&
      (_hasConsentToVerify || _entry.isValid);

  int get _currentStep => _verifiedCount > 0 ? 2 : 1;

  @override
  void initState() {
    super.initState();
    unawaited(_loadExistingGuarantors());
  }

  Future<void> _loadExistingGuarantors() async {
    try {
      final data = await context.read<BackendApiService>().getGuarantors();
      if (!mounted) return;
      final guarantors = data
          .map((g) => Guarantor.fromJson(g as Map<String, dynamic>))
          .toList();
      setState(() {
        _verifiedCount = guarantors.where((g) => g.isVerified).length;
        _pendingVerification = guarantors.where((g) => !g.isVerified).toList();
        _isLoadingExisting = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoadingExisting = false);
    }
  }

  @override
  void dispose() {
    _entry.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final api = context.read<BackendApiService>();

      if (_pendingVerification.isNotEmpty) {
        await _verifyGuarantor(
          api,
          _pendingVerification.first,
          removeFromPending: true,
        );
      } else {
        var guarantor = _activeGuarantor;
        if (guarantor == null) {
          final details = _entry.toJson();
          final created = await api.addGuarantor(
            name: details['name']!,
            phoneNumber: details['phone_number']!,
          );
          guarantor = Guarantor.fromJson(created);
          if (mounted) setState(() => _activeGuarantor = guarantor);
        }
        await _verifyGuarantor(api, guarantor);
      }

      if (!mounted) return;
      if (_isComplete) {
        await context.read<AuthViewModel>().refreshProfile();
      } else {
        _resetEntry();
        setState(() {});
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = friendlyErrorMessage(e));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _verifyGuarantor(
    BackendApiService api,
    Guarantor guarantor, {
    bool removeFromPending = false,
  }) async {
    final verified = await showGuarantorVerificationSheet(
      context,
      api: api,
      guarantor: guarantor,
    );

    if (verified != true) {
      throw Exception(
        'Confirm this guarantor\'s consent before continuing to the next one.',
      );
    }

    if (!mounted) return;
    setState(() {
      _verifiedCount += 1;
      if (removeFromPending) {
        _pendingVerification.removeAt(0);
      } else {
        _activeGuarantor = null;
      }
    });
  }

  void _resetEntry() {
    _entry.dispose();
    _entry = _GuarantorEntry();
  }

  @override
  Widget build(BuildContext context) {
    final activeConsent =
        _activeGuarantor ??
        (_pendingVerification.isNotEmpty ? _pendingVerification.first : null);

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
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              children: [
                _buildProgress(context),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: context.appColors.brandSoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: context.appColors.brandStrong,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'We will verify one guarantor at a time. Their SMS code confirms that they consent to be your guarantor and expires in 5 minutes.',
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
                if (_isComplete)
                  _buildCompleteState(context)
                else if (activeConsent != null)
                  _buildConsentState(context, activeConsent)
                else
                  _GuarantorFormCard(
                    step: _currentStep,
                    entry: _entry,
                    onChanged: () => setState(() {}),
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
                      crossAxisAlignment: CrossAxisAlignment.start,
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
          if (!_isComplete)
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
                label: _buttonLabel,
                onPressed: _canSubmit ? _submit : null,
                isLoading: _isSubmitting,
              ),
            ),
        ],
      ),
    );
  }

  String get _buttonLabel {
    if (_hasConsentToVerify) return 'Enter consent code';
    return _currentStep == 1 ? 'Send consent code' : 'Send code to guarantor 2';
  }

  Widget _buildProgress(BuildContext context) {
    final completed = _verifiedCount.clamp(0, 2) / 2;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                _isComplete
                    ? 'Guarantors confirmed'
                    : 'Guarantor $_currentStep of 2',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: context.appColors.textPrimary,
                ),
              ),
            ),
            Text(
              '$_verifiedCount/2 confirmed',
              style: TextStyle(
                fontSize: 13,
                color: context.appColors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: completed.toDouble(),
            minHeight: 6,
            backgroundColor: context.appColors.surfaceSubtle,
            valueColor: AlwaysStoppedAnimation(context.appColors.brandStrong),
          ),
        ),
      ],
    );
  }

  Widget _buildConsentState(BuildContext context, Guarantor guarantor) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.appColors.surfaceSection,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.outline),
      ),
      child: Column(
        children: [
          Icon(
            Icons.mark_email_read_outlined,
            size: 42,
            color: context.appColors.brandStrong,
          ),
          const SizedBox(height: 14),
          Text(
            'Consent code sent',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: context.appColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Ask ${guarantor.name} to share the 6-digit code sent to ${guarantor.phoneNumber}.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: context.appColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'The code expires in 5 minutes.',
            style: TextStyle(
              fontSize: 12,
              color: context.appColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompleteState(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.appColors.successContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_circle_outline, color: context.appColors.success),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Both guarantors have confirmed their consent.',
              style: TextStyle(
                color: context.appColors.textPrimary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GuarantorFormCard extends StatelessWidget {
  final int step;
  final _GuarantorEntry entry;
  final VoidCallback onChanged;

  const _GuarantorFormCard({
    required this.step,
    required this.entry,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.appColors.surfaceSection,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Guarantor $step details',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: context.appColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Enter their details. We will send the consent code after you continue.',
            style: TextStyle(
              fontSize: 13,
              color: context.appColors.textSecondary,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: entry.nameController,
            onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
            onChanged: (_) => onChanged(),
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              hintText: 'Full name',
              prefixIcon: Icon(Icons.person_outline, size: 20),
            ),
          ),
          const SizedBox(height: 10),
          GhanaPhoneField(
            controller: entry.phoneController,
            onChanged: (_) => onChanged(),
            autovalidateMode: AutovalidateMode.onUserInteraction,
            textInputAction: TextInputAction.done,
          ),
        ],
      ),
    );
  }
}
