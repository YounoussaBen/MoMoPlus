import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/data/services/backend_api_service.dart';
import '../../../core/ui/formatters/ghana_phone_formatter.dart';
import '../../../core/ui/theme/app_theme_extension.dart';
import '../../../core/ui/widgets/app_button.dart';
import '../../../core/utils/error_helpers.dart';
import '../data/guarantor_model.dart';

class GuarantorsScreen extends StatefulWidget {
  const GuarantorsScreen({super.key});

  @override
  State<GuarantorsScreen> createState() => _GuarantorsScreenState();
}

class _GuarantorsScreenState extends State<GuarantorsScreen> {
  List<Guarantor> _guarantors = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final api = context.read<BackendApiService>();
      final data = await api.getGuarantors();
      if (mounted) {
        setState(() {
          _guarantors = data
              .map((g) => Guarantor.fromJson(g as Map<String, dynamic>))
              .toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = friendlyErrorMessage(e);
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _addGuarantor() async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _GuarantorFormSheet(
        title: 'Add Guarantor',
        onSave: (name, phone) async {
          final api = context.read<BackendApiService>();
          await api.addGuarantor(name: name, phoneNumber: phone);
        },
      ),
    );
    if (result == true) _load();
  }

  Future<void> _editGuarantor(Guarantor g) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _GuarantorFormSheet(
        title: 'Edit Guarantor',
        initialName: g.name,
        initialPhone: _stripCountryCode(g.phoneNumber),
        onSave: (name, phone) async {
          final api = context.read<BackendApiService>();
          await api.updateGuarantor(g.id, name: name, phoneNumber: phone);
        },
      ),
    );
    if (result == true) _load();
  }

  Future<void> _deleteGuarantor(Guarantor g) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Guarantor'),
        content: Text('Remove ${g.name} as a guarantor?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
              foregroundColor: context.appColors.error,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      final api = context.read<BackendApiService>();
      await api.deleteGuarantor(g.id);
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(friendlyErrorMessage(e)),
            backgroundColor: context.appColors.error,
          ),
        );
      }
    }
  }

  String _stripCountryCode(String phone) {
    if (phone.startsWith('+233')) return phone.substring(4);
    if (phone.startsWith('233')) return phone.substring(3);
    if (phone.startsWith('0')) return phone.substring(1);
    return phone;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appColors.canvas,
      appBar: AppBar(title: const Text('Loan Guarantors')),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: context.appColors.brandAccent,
                strokeWidth: 2,
              ),
            )
          : _errorMessage != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: context.appColors.textSecondary),
                    ),
                    const SizedBox(height: 16),
                    AppButton(
                      label: 'Retry',
                      variant: AppButtonVariant.secondary,
                      onPressed: _load,
                    ),
                  ],
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: context.appColors.surfaceSection,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      for (var i = 0; i < _guarantors.length; i++) ...[
                        if (i > 0)
                          Divider(
                            height: 1,
                            indent: 56,
                            color: context.appColors.surfaceSubtle,
                          ),
                        _GuarantorTile(
                          guarantor: _guarantors[i],
                          canDelete: _guarantors.length > 2,
                          onEdit: () => _editGuarantor(_guarantors[i]),
                          onDelete: () => _deleteGuarantor(_guarantors[i]),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                AppButton(
                  label: 'Add Another Guarantor',
                  variant: AppButtonVariant.secondary,
                  onPressed: _addGuarantor,
                  icon: const Icon(Icons.add, size: 18),
                ),
              ],
            ),
    );
  }
}

class _GuarantorTile extends StatelessWidget {
  final Guarantor guarantor;
  final bool canDelete;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _GuarantorTile({
    required this.guarantor,
    required this.canDelete,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: context.appColors.brandSoft,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          Icons.person_outline,
          color: context.appColors.brandStrong,
          size: 20,
        ),
      ),
      title: Text(
        guarantor.name,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      ),
      subtitle: Text(
        guarantor.phoneNumber,
        style: TextStyle(color: context.appColors.textSecondary, fontSize: 13),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 18),
            color: context.appColors.textSecondary,
            onPressed: onEdit,
          ),
          if (canDelete)
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 18),
              color: context.appColors.error,
              onPressed: onDelete,
            ),
        ],
      ),
    );
  }
}

class _GuarantorFormSheet extends StatefulWidget {
  final String title;
  final String? initialName;
  final String? initialPhone;
  final Future<void> Function(String name, String phone) onSave;

  const _GuarantorFormSheet({
    required this.title,
    this.initialName,
    this.initialPhone,
    required this.onSave,
  });

  @override
  State<_GuarantorFormSheet> createState() => _GuarantorFormSheetState();
}

class _GuarantorFormSheetState extends State<_GuarantorFormSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  bool _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.initialName ?? '');
    _phoneCtrl = TextEditingController(text: widget.initialPhone ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  bool get _isValid =>
      _nameCtrl.text.trim().isNotEmpty &&
      _phoneCtrl.text.replaceAll(' ', '').length >= 9;

  Future<void> _save() async {
    if (!_isValid) return;
    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      final phone = '0${_phoneCtrl.text.replaceAll(' ', '')}';
      await widget.onSave(_nameCtrl.text.trim(), phone);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => _error = friendlyErrorMessage(e));
    } finally {
      if (mounted) setState(() => _isSaving = false);
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
          Text(
            widget.title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _nameCtrl,
            textCapitalization: TextCapitalization.words,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              hintText: 'Full name',
              prefixIcon: Icon(Icons.person_outline, size: 20),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
            onChanged: (_) => setState(() {}),
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              GhanaPhoneFormatter(),
            ],
            decoration: InputDecoration(
              hintText: '24 XXX XXXX',
              prefixIcon: Padding(
                padding: const EdgeInsets.only(left: 12, right: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '+233',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: context.appColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 1,
                      height: 20,
                      color: context.appColors.surfaceSubtle,
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: TextStyle(color: context.appColors.error, fontSize: 13),
            ),
          ],
          const SizedBox(height: 20),
          AppButton(
            label: 'Save',
            onPressed: _isValid ? _save : null,
            isLoading: _isSaving,
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
