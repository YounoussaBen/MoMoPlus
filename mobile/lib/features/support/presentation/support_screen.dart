import 'package:flutter/material.dart';
import '../../../core/ui/theme/app_theme.dart';

class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Support'),
        backgroundColor: AppColors.background,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        children: [
          _HeroBanner(),
          const SizedBox(height: 24),
          _SectionHeader(title: 'Get Help'),
          const SizedBox(height: 8),
          _SectionCard(
            children: [
              _SupportTile(
                icon: Icons.chat_bubble_outline,
                title: 'Live Chat',
                subtitle: 'Chat with our support team',
              ),
              const Divider(height: 1, indent: 56),
              _SupportTile(
                icon: Icons.email_outlined,
                title: 'Email Us',
                subtitle: 'support@momoplus.com',
              ),
              const Divider(height: 1, indent: 56),
              _SupportTile(
                icon: Icons.phone_outlined,
                title: 'Call Us',
                subtitle: '+233 XX XXX XXXX',
              ),
            ],
          ),
          const SizedBox(height: 24),
          _SectionHeader(title: 'Resources'),
          const SizedBox(height: 8),
          _SectionCard(
            children: [
              _SupportTile(
                icon: Icons.help_outline,
                title: 'FAQ',
                subtitle: 'Frequently asked questions',
              ),
              const Divider(height: 1, indent: 56),
              _SupportTile(
                icon: Icons.menu_book_outlined,
                title: 'User Guide',
                subtitle: 'Learn how to use MoMo Plus',
              ),
              const Divider(height: 1, indent: 56),
              _SupportTile(
                icon: Icons.bug_report_outlined,
                title: 'Report a Problem',
                subtitle: 'Let us know about issues',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.support_agent_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'How can we help?',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'We\'re here to assist you 24/7',
                  style: TextStyle(fontSize: 14, color: Colors.white70),
                ),
              ],
            ),
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

class _SupportTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _SupportTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.textSecondary),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      onTap: () {},
    );
  }
}
