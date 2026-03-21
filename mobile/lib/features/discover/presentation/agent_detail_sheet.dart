import 'package:flutter/material.dart';
import '../../../core/ui/theme/app_theme.dart';
import '../domain/nearby_agent.dart';

class AgentDetailSheet extends StatelessWidget {
  final NearbyAgent agent;
  const AgentDetailSheet({super.key, required this.agent});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.textSecondary.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          // Avatar
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: agent.isCertified
                  ? AppColors.primary.withValues(alpha: 0.1)
                  : AppColors.textSecondary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                agent.fullName.isNotEmpty
                    ? agent.fullName[0].toUpperCase()
                    : '?',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: agent.isCertified
                      ? AppColors.primary
                      : AppColors.textSecondary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Name + badge
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                agent.fullName,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
              if (agent.isCertified) ...[
                const SizedBox(width: 6),
                const Icon(Icons.verified, size: 20, color: AppColors.primary),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Text(
            agent.isCertified ? 'Certified Agent' : 'Agent',
            style: const TextStyle(
              fontSize: 15,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 24),
          // Stats row
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              children: [
                _StatItem(
                  icon: Icons.location_on,
                  value: agent.distanceLabel,
                  label: 'Distance',
                ),
                _divider(),
                _StatItem(
                  icon: Icons.star,
                  value: agent.rating > 0
                      ? agent.rating.toStringAsFixed(1)
                      : '—',
                  label: agent.totalRatings > 0
                      ? '${agent.totalRatings} review${agent.totalRatings == 1 ? '' : 's'}'
                      : 'No reviews',
                ),
                _divider(),
                _StatItem(
                  icon: Icons.account_balance_wallet_outlined,
                  value: agent.maxAmount != null
                      ? 'GHS ${agent.maxAmount!.toStringAsFixed(0)}'
                      : '—',
                  label: 'Max amount',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Min amount info
          if (agent.minAmount > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline,
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Minimum transaction: GHS ${agent.minAmount.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          // Action button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                // TODO: Navigate to request screen with agent pre-selected
              },
              child: const Text('Request Transaction'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() {
    return Container(
      width: 1,
      height: 32,
      color: AppColors.textSecondary.withValues(alpha: 0.15),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  const _StatItem({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
