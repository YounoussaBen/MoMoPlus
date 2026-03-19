import 'package:flutter/material.dart';
import '../../../../core/ui/theme/app_theme.dart';

class KycProgressBar extends StatelessWidget {
  final int currentStep;

  const KycProgressBar({super.key, required this.currentStep});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _Segment(isActive: currentStep >= 0),
        const SizedBox(width: 6),
        _Segment(isActive: currentStep >= 1),
        const SizedBox(width: 6),
        _Segment(isActive: currentStep >= 2),
      ],
    );
  }
}

class _Segment extends StatelessWidget {
  final bool isActive;

  const _Segment({required this.isActive});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        height: 4,
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary : AppColors.divider,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}
