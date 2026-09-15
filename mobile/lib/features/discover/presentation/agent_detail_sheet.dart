import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ui/theme/app_theme_extension.dart';
import '../../../core/ui/widgets/profile_avatar.dart';
import '../../loans/domain/loan.dart';
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
  final Loan? activeLoan;

  const AgentDetailSheet({
    super.key,
    required this.agent,
    required this.routePreview,
    required this.isRouteLoading,
    required this.routeErrorMessage,
    required this.onStreetView,
    required this.onOpenDirections,
    this.activeTransaction,
    this.activeLoan,
  });

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewPadding.bottom;
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: BoxDecoration(
        color: context.appColors.surfaceSection,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
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
                color: context.appColors.surfaceInteractive,
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
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: context.appColors.textPrimary,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
                if (agent.isCertified) ...[
                  const SizedBox(width: 6),
                  Icon(
                    Icons.verified,
                    size: 20,
                    color: context.appColors.brandStrong,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 4),
            Text(
              agent.isCertified ? 'Certified Agent' : 'Agent',
              style: TextStyle(
                fontSize: 15,
                color: context.appColors.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            Container(
              decoration: BoxDecoration(
                color: context.appColors.surfaceInteractive,
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
                  _divider(context),
                  _StatItem(
                    icon: Icons.route_rounded,
                    value: isRouteLoading
                        ? 'Loading'
                        : routePreview?.durationLabel ?? 'By road',
                    label: routePreview?.isApproximate == true
                        ? 'Approximate'
                        : 'Route preview',
                  ),
                  _divider(context),
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
                color: context.appColors.surfaceInteractive,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Map Preview',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: context.appColors.textPrimary,
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
                      style: TextStyle(
                        fontSize: 12,
                        color: context.appColors.textSecondary,
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
                    Icon(
                      Icons.info_outline,
                      size: 16,
                      color: context.appColors.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Minimum amount: GHS ${agent.minAmount.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 14,
                          color: context.appColors.textSecondary,
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
            const SizedBox(height: 12),
            if (activeLoan != null)
              _ActiveItemCard(
                label: 'Get Funds',
                statusText:
                    '${activeLoan!.statusLabel} · GHS ${activeLoan!.amount.toStringAsFixed(2)}',
                color: context.appColors.brandStrong,
                icon: Icons.account_balance_wallet_rounded,
                onTap: () {
                  Navigator.pop(context);
                  context.push('/loans/${activeLoan!.id}');
                },
              )
            else if (agent.canProvideGetFunds)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    context.push(
                      '/loans/request',
                      extra: {
                        'agentId': agent.id,
                        'agentName': agent.fullName,
                        'agentSelfieUrl': agent.selfieUrl,
                      },
                    );
                  },
                  icon: const Icon(
                    Icons.account_balance_wallet_rounded,
                    size: 18,
                  ),
                  label: const Text('Get Funds'),
                ),
              ),
            if (activeLoan == null && !agent.canProvideGetFunds) ...[
              if (agent.isCertified) const SizedBox(height: 10),
              Text(
                'Get Funds is unavailable for this agent right now.',
                style: TextStyle(
                  fontSize: 13,
                  color: context.appColors.textSecondary,
                ),
              ),
            ],
            if (agent.isCertified) ...[
              const SizedBox(height: 10),
              if (activeTransaction != null)
                _ActiveItemCard(
                  label: 'Cash Service',
                  statusText:
                      '${activeTransaction!.statusLabel} ${activeTransaction!.typeLabel} · GHS ${activeTransaction!.amount.toStringAsFixed(2)}',
                  color: context.appColors.warning,
                  icon: Icons.swap_horiz_rounded,
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/transactions/${activeTransaction!.id}');
                  },
                )
              else
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
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
                    icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                    label: const Text('Cash Services'),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _divider(BuildContext context) {
    return Container(
      width: 1,
      height: 32,
      color: context.appColors.surfaceSubtle,
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
        color: context.appColors.surfaceInteractive,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: context.appColors.brandStrong),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: context.appColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActiveItemCard extends StatelessWidget {
  final String label;
  final String statusText;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  const _ActiveItemCard({
    required this.label,
    required this.statusText,
    required this.color,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: context.appColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$statusText · Tap to view',
                    style: TextStyle(
                      fontSize: 13,
                      color: context.appColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: context.appColors.textMuted,
              size: 20,
            ),
          ],
        ),
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
          Icon(icon, size: 18, color: context.appColors.brandStrong),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: context.appColors.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: context.appColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
