import 'package:flutter/material.dart';
import '../../../../core/ui/theme/app_theme.dart';

class AgentTransactionsScreen extends StatelessWidget {
  const AgentTransactionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(backgroundColor: AppColors.primary, toolbarHeight: 12),
      body: Padding(
        padding: const EdgeInsets.only(bottom: 100),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.receipt_long_outlined,
                size: 64,
                color: AppColors.textSecondary.withValues(alpha: 0.4),
              ),
              const SizedBox(height: 16),
              Text(
                'Transactions',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Track disbursements, verify repayments,\nand manage active transactions.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
