import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ui/theme/app_theme.dart';
import '../../../core/ui/widgets/profile_avatar.dart';
import '../../transactions/domain/physical_transaction.dart';
import '../domain/agent_route_preview.dart';
import '../domain/nearby_agent.dart';

class AgentDetailSheet extends StatelessWidget {
  final NearbyAgent agent;
  final AgentRoutePreview? routePreview;
  final bool isRouteLoading;
  final String? routeErrorMessage;
  final VoidCallback onStreetView;
  final VoidCallback onOpenDirections;
  final PhysicalTransaction? activeTransaction;

  const AgentDetailSheet({
    super.key,
    required this.agent,
    required this.routePreview,
    required this.isRouteLoading,
    required this.routeErrorMessage,
    required this.onStreetView,
    required this.onOpenDirections,
    this.activeTransaction,
  });

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewPadding.bottom;
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(24, 12, 24, 24 + bottomPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textSecondary.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            ProfileAvatar(
              imageUrl: agent.selfieUrl,
              fallbackLetter: agent.fullName.isNotEmpty
                  ? agent.fullName[0]
                  : '?',
              radius: 32,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    agent.fullName,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
                if (agent.isCertified) ...[
                  const SizedBox(width: 6),
                  const Icon(
                    Icons.verified,
                    size: 20,
                    color: AppColors.primary,
                  ),
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
                    value: routePreview?.distanceLabel ?? agent.distanceLabel,
                    label: 'Distance',
                  ),
                  _divider(),
                  _StatItem(
                    icon: Icons.route_rounded,
                    value: isRouteLoading
                        ? 'Loading'
                        : routePreview?.durationLabel ?? 'By road',
                    label: routePreview?.isApproximate == true
                        ? 'Approximate'
                        : 'Route preview',
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
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.divider),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Map Preview',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _RouteChip(
                        icon: Icons.navigation_outlined,
                        label: isRouteLoading
                            ? 'Loading driving route...'
                            : routePreview?.summaryLabel ?? 'Direct distance',
                      ),
                      _RouteChip(
                        icon: routePreview?.isApproximate == true
                            ? Icons.near_me_outlined
                            : Icons.directions_car_filled_outlined,
                        label: routePreview?.isApproximate == true
                            ? 'Fallback preview'
                            : 'Road-by-road route',
                      ),
                      _RouteChip(
                        icon: Icons.pin_drop_outlined,
                        label:
                            '${agent.latitude.toStringAsFixed(5)}, ${agent.longitude.toStringAsFixed(5)}',
                      ),
                    ],
                  ),
                  if (routeErrorMessage != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      routeErrorMessage!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
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
                    Expanded(
                      child: Text(
                        'Minimum amount: GHS ${agent.minAmount.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      onStreetView();
                    },
                    icon: const Icon(Icons.streetview_outlined),
                    label: const Text('Street View'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      onOpenDirections();
                    },
                    icon: const Icon(Icons.navigation_outlined),
                    label: const Text('Directions'),
                  ),
                ),
              ],
            ),
            if (agent.isCertified) ...[
              const SizedBox(height: 12),
              if (activeTransaction != null)
                GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/transactions/${activeTransaction!.id}');
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.hourglass_top_rounded,
                            size: 18,
                            color: Colors.orange,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${activeTransaction!.statusLabel} ${activeTransaction!.typeLabel}',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'GHS ${activeTransaction!.amount.toStringAsFixed(2)} · Tap to view',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right,
                          color: AppColors.textSecondary,
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                )
              else
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      context.push(
                        '/transactions/create',
                        extra: {
                          'agentId': agent.id,
                          'agentName': agent.fullName,
                          'agentSelfieUrl': agent.selfieUrl,
                        },
                      );
                    },
                    child: const Text('Request Physical Transaction'),
                  ),
                ),
            ],
          ],
        ),
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

class _RouteChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _RouteChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
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
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
