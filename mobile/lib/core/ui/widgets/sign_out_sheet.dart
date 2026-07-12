import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import '../theme/app_theme_extension.dart';
import 'app_button.dart';

Future<bool?> showSignOutDialog(
  BuildContext context, {
  required Future<bool> Function() onConfirm,
}) {
  return showDialog<bool>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: false,
    barrierColor: context.appColors.scrim,
    builder: (_) => _SignOutDialog(onConfirm: onConfirm),
  );
}

class _SignOutDialog extends StatefulWidget {
  const _SignOutDialog({required this.onConfirm});

  final Future<bool> Function() onConfirm;

  @override
  State<_SignOutDialog> createState() => _SignOutDialogState();
}

class _SignOutDialogState extends State<_SignOutDialog> {
  bool _isSubmitting = false;
  String? _errorText;

  Future<void> _handleConfirm() async {
    if (_isSubmitting) return;

    setState(() {
      _isSubmitting = true;
      _errorText = null;
    });

    try {
      final didSignOut = await widget.onConfirm();
      if (!mounted) return;
      if (didSignOut) {
        Navigator.of(context, rootNavigator: true).pop(true);
        return;
      }
      setState(() {
        _isSubmitting = false;
        _errorText = 'Sign out failed. Please try again.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _errorText = 'Sign out failed. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return PopScope(
      canPop: !_isSubmitting,
      child: Dialog(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.space6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Sign out', style: context.appTextTheme.titleLarge),
              const SizedBox(height: AppSpacing.space2),
              Text(
                'Are you sure you want to sign out of your account?',
                textAlign: TextAlign.center,
                style: context.appTextTheme.bodyMedium?.copyWith(
                  color: colors.textSecondary,
                ),
              ),
              if (_errorText != null) ...[
                const SizedBox(height: AppSpacing.space3),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    _errorText!,
                    textAlign: TextAlign.center,
                    style: context.appTextTheme.bodyMedium?.copyWith(
                      color: colors.error,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.space6),
              AppButton(
                label: 'Sign out',
                variant: AppButtonVariant.destructive,
                isLoading: _isSubmitting,
                onPressed: _handleConfirm,
              ),
              const SizedBox(height: AppSpacing.space2),
              AppButton(
                label: 'Cancel',
                variant: AppButtonVariant.ghost,
                onPressed: _isSubmitting
                    ? null
                    : () =>
                          Navigator.of(context, rootNavigator: true).pop(false),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
