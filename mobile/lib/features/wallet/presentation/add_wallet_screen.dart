import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/data/services/backend_api_service.dart';
import '../../../core/ui/theme/app_spacing.dart';
import '../../../core/ui/theme/app_theme_extension.dart';
import '../../../core/ui/widgets/app_button.dart';
import '../../../core/ui/widgets/app_screen.dart';
import '../../../core/ui/widgets/app_section.dart';
import '../../../core/ui/widgets/ghana_phone_field.dart';
import '../../../core/ui/widgets/network_logo.dart';
import '../../../core/utils/error_helpers.dart';
import 'wallet_view_model.dart';

class _WalletNetworkOption {
  final String value;
  final String label;
  final Color accentColor;
  final Set<String> prefixes;

  const _WalletNetworkOption({
    required this.value,
    required this.label,
    required this.accentColor,
    required this.prefixes,
  });
}

const _networkOptions = [
  _WalletNetworkOption(
    value: 'mtn',
    label: 'MTN Mobile Money',
    accentColor: Color(0xFFD4A300),
    prefixes: {'024', '054', '055', '059', '025', '053'},
  ),
  _WalletNetworkOption(
    value: 'vodafone',
    label: 'Telecel Cash',
    accentColor: Color(0xFFD32F2F),
    prefixes: {'020', '050'},
  ),
  _WalletNetworkOption(
    value: 'airteltigo',
    label: 'AirtelTigo Money',
    accentColor: Color(0xFF1976D2),
    prefixes: {'027', '057', '026', '056'},
  ),
];

class AddWalletScreen extends StatefulWidget {
  const AddWalletScreen({super.key});

  @override
  State<AddWalletScreen> createState() => _AddWalletScreenState();
}

class _AddWalletScreenState extends State<AddWalletScreen> {
  final _phoneController = TextEditingController();
  String _selectedNetwork = 'mtn';
  bool _isAdding = false;
  String? _errorMessage;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  String get _rawDigits => _phoneController.text.replaceAll(RegExp(r'\D'), '');
  String get _fullNumber => '0$_rawDigits';
  _WalletNetworkOption get _selectedOption =>
      _networkOptions.firstWhere((option) => option.value == _selectedNetwork);
  String? get _guessedNetwork {
    final normalized = _normalizePhoneNumber(_fullNumber);
    if (normalized == null) return null;
    final prefix = normalized.substring(0, 3);
    for (final option in _networkOptions) {
      if (option.prefixes.contains(prefix)) {
        return option.value;
      }
    }
    return '';
  }

  bool get _isSelectedNetworkValid =>
      _guessedNetwork != null && _guessedNetwork == _selectedNetwork;

  bool get _canSubmit => _rawDigits.length == 9 && _isSelectedNetworkValid;

  String? get _validationMessage {
    if (_rawDigits.isEmpty || _rawDigits.length < 9) return null;
    if (_guessedNetwork == '') {
      return 'This number prefix is not recognized for MTN, Telecel, or AirtelTigo.';
    }
    if (_guessedNetwork != _selectedNetwork) {
      final matchedOption = _networkOptions.firstWhere(
        (option) => option.value == _guessedNetwork,
      );
      return 'This number looks like ${matchedOption.label}. Select the matching network to continue.';
    }
    return null;
  }

  String? _normalizePhoneNumber(String phoneNumber) {
    var num = phoneNumber.replaceAll(RegExp(r'\D'), '');
    if (num.startsWith('233')) {
      num = '0${num.substring(3)}';
    } else if (!num.startsWith('0')) {
      num = '0$num';
    }
    if (num.length != 10) return null;
    return num;
  }

  Future<void> _showNetworkPicker() async {
    final selected = await showModalBottomSheet<_WalletNetworkOption>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _NetworkPickerSheet(selectedNetwork: _selectedNetwork),
    );
    if (selected == null || !mounted) return;
    setState(() {
      _selectedNetwork = selected.value;
      _errorMessage = null;
    });
  }

  Future<void> _submit() async {
    final validationMessage = _validationMessage;
    if (validationMessage != null) {
      setState(() {
        _errorMessage = validationMessage;
      });
      return;
    }

    setState(() {
      _isAdding = true;
      _errorMessage = null;
    });
    try {
      final api = context.read<BackendApiService>();
      final data = await api.addWallet(
        phoneNumber: _fullNumber,
        network: _selectedNetwork,
      );
      if (mounted) {
        final walletId = data['id'] as String;
        final network = data['network'] as String? ?? _selectedNetwork;
        final verified = await context.push<bool>(
          '/wallet/verify',
          extra: {
            'walletId': walletId,
            'phoneNumber': _fullNumber,
            'network': network,
          },
        );
        if (!mounted) return;
        if (verified == true) {
          await context.read<WalletViewModel>().loadWallets();
          if (!mounted) return;
          context.pop(true);
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = friendlyErrorMessage(e);
      });
    } finally {
      if (mounted) setState(() => _isAdding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScreen(
      title: 'Add wallet',
      body: ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 48),
        children: [
          Text(
            'Enter your mobile money number',
            style: context.appTextTheme.headlineMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'Choose a network and enter the number linked to your wallet.',
            style: context.appTextTheme.bodyMedium?.copyWith(
              color: context.appColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.space6),
          AppSection(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Network', style: context.appTextTheme.titleSmall),
                const SizedBox(height: AppSpacing.space2),
                _NetworkSelectorField(
                  option: _selectedOption,
                  onTap: _showNetworkPicker,
                ),
                const SizedBox(height: AppSpacing.space4),
                Text('Phone number', style: context.appTextTheme.titleSmall),
                const SizedBox(height: AppSpacing.space2),
                GhanaPhoneField(
                  controller: _phoneController,
                  textInputAction: TextInputAction.done,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  onChanged: (_) => setState(() => _errorMessage = null),
                  onFieldSubmitted: (_) {
                    if (_canSubmit && !_isAdding) _submit();
                  },
                ),
              ],
            ),
          ),
          if (_validationMessage != null || _errorMessage != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.appColors.errorContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.error_outline,
                    color: context.appColors.error,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage ?? _validationMessage!,
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
          const SizedBox(height: 32),
          AppButton(
            label: 'Send verification code',
            onPressed: _canSubmit && !_isAdding ? _submit : null,
            isLoading: _isAdding,
          ),
        ],
      ),
    );
  }
}

class _NetworkSelectorField extends StatelessWidget {
  final _WalletNetworkOption option;
  final VoidCallback onTap;

  const _NetworkSelectorField({required this.option, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
        decoration: BoxDecoration(
          color: context.appColors.surfaceInteractive,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            NetworkLogo(network: option.value, size: 24),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                option.label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: context.appColors.textPrimary,
                ),
              ),
            ),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              color: context.appColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

class _NetworkPickerSheet extends StatelessWidget {
  final String selectedNetwork;

  const _NetworkPickerSheet({required this.selectedNetwork});

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewPadding.bottom;

    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: context.appColors.surfaceSection,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: context.appColors.textMuted.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Select Network',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: context.appColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: 12),
            ..._networkOptions.map(
              (option) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _NetworkTile(
                  option: option,
                  isSelected: selectedNetwork == option.value,
                  onTap: () => Navigator.pop(context, option),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NetworkTile extends StatelessWidget {
  final _WalletNetworkOption option;
  final bool isSelected;
  final VoidCallback onTap;

  const _NetworkTile({
    required this.option,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? context.appColors.brandSoft
              : context.appColors.surfaceInteractive,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? option.accentColor
                : context.appColors.surfaceInteractive,
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: option.accentColor.withValues(alpha: 0.10),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            NetworkLogo(network: option.value, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                option.label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: context.appColors.textPrimary,
                ),
              ),
            ),
            Icon(
              isSelected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              color: isSelected
                  ? option.accentColor
                  : context.appColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}
