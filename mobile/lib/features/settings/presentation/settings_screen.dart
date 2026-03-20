import 'package:flutter/material.dart';
import '../../../core/ui/theme/app_theme.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: AppColors.background,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        children: [
          _SectionHeader(title: 'General'),
          const SizedBox(height: 8),
          _SectionCard(
            children: [
              _SettingsTile(
                icon: Icons.language_outlined,
                title: 'Language',
                trailing: 'English',
              ),
              const Divider(height: 1, indent: 56),
              _SettingsTile(
                icon: Icons.dark_mode_outlined,
                title: 'Appearance',
                trailing: 'Light',
              ),
              const Divider(height: 1, indent: 56),
              _SettingsTile(
                icon: Icons.currency_exchange_outlined,
                title: 'Currency',
                trailing: 'GHS',
              ),
            ],
          ),
          const SizedBox(height: 24),
          _SectionHeader(title: 'Notifications'),
          const SizedBox(height: 8),
          _SectionCard(
            children: [
              _ToggleTile(
                icon: Icons.notifications_outlined,
                title: 'Push Notifications',
                value: true,
              ),
              const Divider(height: 1, indent: 56),
              _ToggleTile(
                icon: Icons.email_outlined,
                title: 'Email Notifications',
                value: false,
              ),
            ],
          ),
          const SizedBox(height: 24),
          _SectionHeader(title: 'Security'),
          const SizedBox(height: 8),
          _SectionCard(
            children: [
              _SettingsTile(
                icon: Icons.fingerprint_outlined,
                title: 'Biometric Login',
              ),
              const Divider(height: 1, indent: 56),
              _SettingsTile(icon: Icons.lock_outline, title: 'Change Password'),
            ],
          ),
          const SizedBox(height: 24),
          _SectionHeader(title: 'About'),
          const SizedBox(height: 8),
          _SectionCard(
            children: [
              _SettingsTile(
                icon: Icons.info_outline,
                title: 'App Version',
                trailing: '1.0.0',
              ),
              const Divider(height: 1, indent: 56),
              _SettingsTile(
                icon: Icons.description_outlined,
                title: 'Terms of Service',
              ),
              const Divider(height: 1, indent: 56),
              _SettingsTile(
                icon: Icons.privacy_tip_outlined,
                title: 'Privacy Policy',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title.toUpperCase(),
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

class _SectionCard extends StatelessWidget {
  final List<Widget> children;
  const _SectionCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(mainAxisSize: MainAxisSize.min, children: children),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? trailing;
  const _SettingsTile({required this.icon, required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.textSecondary),
      title: Text(title),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (trailing != null)
            Text(
              trailing!,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right, color: AppColors.textSecondary),
        ],
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      onTap: () {},
    );
  }
}

class _ToggleTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool value;
  const _ToggleTile({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.textSecondary),
      title: Text(title),
      trailing: Switch.adaptive(
        value: value,
        activeTrackColor: AppColors.primary,
        onChanged: (_) {},
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
    );
  }
}
