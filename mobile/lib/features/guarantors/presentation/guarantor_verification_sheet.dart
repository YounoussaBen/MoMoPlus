import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/data/services/backend_api_service.dart';
import '../../../core/ui/theme/app_theme_extension.dart';
import '../../../core/ui/widgets/app_button.dart';
import '../../../core/utils/error_helpers.dart';
import '../data/guarantor_model.dart';

Future<bool?> showGuarantorVerificationSheet(
  BuildContext context, {
  required BackendApiService api,
  required Guarantor guarantor,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _GuarantorVerificationSheet(api: api, guarantor: guarantor),
  );
}

class _GuarantorVerificationSheet extends StatefulWidget {
  final BackendApiService api;
  final Guarantor guarantor;

  const _GuarantorVerificationSheet({
    required this.api,
    required this.guarantor,
  });

  @override
  State<_GuarantorVerificationSheet> createState() =>
      _GuarantorVerificationSheetState();
}

class _GuarantorVerificationSheetState
    extends State<_GuarantorVerificationSheet> {
  final _codeController = TextEditingController();
  final _codeFocusNode = FocusNode();
  bool _isVerifying = false;
  bool _isResending = false;
  String? _error;
  String? _message;

  @override
  void dispose() {
    _codeController.dispose();
    _codeFocusNode.dispose();
    super.dispose();
  }

  bool get _isComplete => _codeController.text.trim().length == 6;

  Future<void> _verify() async {
    if (!_isComplete || _isVerifying) return;
    setState(() {
      _isVerifying = true;
      _error = null;
      _message = null;
    });
    try {
      await widget.api.verifyGuarantorOtp(
        guarantorId: widget.guarantor.id,
        code: _codeController.text.trim(),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => _error = friendlyErrorMessage(e));
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  Future<void> _resend() async {
    if (_isResending || _isVerifying) return;
    setState(() {
      _isResending = true;
      _error = null;
      _message = null;
    });
    try {
      await widget.api.resendGuarantorOtp(widget.guarantor.id);
      _codeController.clear();
      if (mounted) {
        setState(
          () => _message = 'A new code was sent. It expires in 5 minutes.',
        );
        _codeFocusNode.requestFocus();
      }
    } catch (e) {
      if (mounted) setState(() => _error = friendlyErrorMessage(e));
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomInset),
      decoration: BoxDecoration(
        color: context.appColors.surfaceSection,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: context.appColors.surfaceSubtle,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Icon(Icons.sms_outlined, size: 32),
            const SizedBox(height: 12),
            const Text(
              'Confirm guarantor consent',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'We sent a 6-digit code to ${widget.guarantor.phoneNumber}. '
              '${widget.guarantor.name} must share the code with you. Entering it confirms their consent to be your guarantor.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.appColors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'The code expires in 5 minutes. Do not enter a code unless the guarantor agreed to share it.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.appColors.textSecondary,
                fontSize: 12,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _codeController,
              focusNode: _codeFocusNode,
              autofocus: true,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.oneTimeCode],
              maxLength: 6,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                letterSpacing: 8,
              ),
              decoration: const InputDecoration(
                labelText: '6-digit consent code',
                counterText: '',
              ),
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6),
              ],
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _verify(),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: context.appColors.error, fontSize: 13),
              ),
            ],
            if (_message != null) ...[
              const SizedBox(height: 10),
              Text(
                _message!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: context.appColors.textSecondary,
                  fontSize: 13,
                ),
              ),
            ],
            const SizedBox(height: 18),
            AppButton(
              label: 'Confirm consent',
              onPressed: _isComplete && !_isVerifying ? _verify : null,
              isLoading: _isVerifying,
            ),
            const SizedBox(height: 4),
            TextButton(
              onPressed: _isResending || _isVerifying ? null : _resend,
              child: _isResending
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Resend code'),
            ),
          ],
        ),
      ),
    );
  }
}
