import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/data/services/backend_api_service.dart';
import '../../../core/ui/theme/app_theme.dart';
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

/// Formats digits as "XX XXX XXXX" (Ghanaian local number without leading 0).
class _GhanaPhoneFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(' ', '');
    if (digits.length > 9) {
      return oldValue;
    }
    final buf = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i == 2 || i == 5) buf.write(' ');
      buf.write(digits[i]);
    }
    final formatted = buf.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

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

  String get _rawDigits => _phoneController.text.replaceAll(' ', '');
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
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Add Wallet'),
        backgroundColor: AppColors.background,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Enter your mobile money number',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'We\'ll send an OTP to verify this number',
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 28),
          const Text(
            'Network',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          _NetworkSelectorField(
            option: _selectedOption,
            onTap: _showNetworkPicker,
          ),
          const SizedBox(height: 18),
          const Text(
            'Phone Number',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 52,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.divider),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('\u{1F1EC}\u{1F1ED}', style: TextStyle(fontSize: 20)),
                    SizedBox(width: 6),
                    Text(
                      '+233',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() => _errorMessage = null),
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    _GhanaPhoneFormatter(),
                  ],
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                    letterSpacing: 0.5,
                  ),
                  decoration: InputDecoration(
                    hintText: '53 827 2768',
                    hintStyle: TextStyle(
                      color: AppColors.textSecondary.withValues(alpha: 0.5),
                      fontWeight: FontWeight.w400,
                      letterSpacing: 0.5,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 15,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.divider),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.divider),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: AppColors.primary,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (_validationMessage != null || _errorMessage != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: AppColors.error,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage ?? _validationMessage!,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.error,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: _canSubmit && !_isAdding ? _submit : null,
            child: _isAdding
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Text('Send OTP'),
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
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          children: [
            NetworkLogo(network: option.value, size: 24),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                option.label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              color: AppColors.textSecondary.withValues(alpha: 0.8),
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
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textSecondary.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 16),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Select Network',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
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
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? option.accentColor : AppColors.divider,
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
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            Icon(
              isSelected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              color: isSelected
                  ? option.accentColor
                  : AppColors.textSecondary.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }
}
