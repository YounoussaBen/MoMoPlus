import 'package:flutter/cupertino.dart';

import '../../../../core/ui/theme/app_theme_extension.dart';

class AgentAvailabilityPill extends StatelessWidget {
  const AgentAvailabilityPill({
    super.key,
    required this.isAvailable,
    required this.onPressed,
  });

  final bool isAvailable;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final foreground = isAvailable
        ? context.appColors.success
        : context.appColors.brandStrong;
    final background = isAvailable
        ? context.appColors.successContainer
        : context.appColors.brandSoft;

    return Semantics(
      toggled: isAvailable,
      enabled: onPressed != null,
      label: isAvailable ? 'Agent availability, on' : 'Agent availability, off',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.only(left: 13, right: 7),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: foreground.withValues(alpha: 0.32)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isAvailable ? 'Available' : 'Unavailable',
                style: context.appTextTheme.labelLarge?.copyWith(
                  color: foreground,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 7),
              IgnorePointer(
                child: Transform.scale(
                  scale: 0.82,
                  child: CupertinoSwitch(
                    value: isAvailable,
                    activeTrackColor: context.appColors.success,
                    inactiveTrackColor: context.appColors.surfaceSubtle,
                    onChanged: (_) {},
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
