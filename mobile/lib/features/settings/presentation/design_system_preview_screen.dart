import 'package:flutter/material.dart';

import '../../../core/ui/theme/app_radii.dart';
import '../../../core/ui/theme/app_spacing.dart';
import '../../../core/ui/theme/app_theme_extension.dart';
import '../../../core/ui/widgets/app_button.dart';
import '../../../core/ui/widgets/app_icon_button.dart';
import '../../../core/ui/widgets/app_list_row.dart';
import '../../../core/ui/widgets/app_screen.dart';
import '../../../core/ui/widgets/app_section.dart';
import '../../../core/ui/widgets/app_status.dart';
import '../../../core/ui/widgets/app_text_field.dart';

class DesignSystemPreviewScreen extends StatelessWidget {
  const DesignSystemPreviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final gutter = AppSpacing.gutterFor(MediaQuery.sizeOf(context).width);

    return AppScreen(
      title: 'Design system',
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          gutter,
          AppSpacing.space4,
          gutter,
          AppSpacing.space8,
        ),
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.space6),
            decoration: BoxDecoration(
              color: colors.brandAccent,
              borderRadius: AppRadii.xLargeBorderRadius,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Quiet Energy',
                  style: context.appTextTheme.screenTitle.copyWith(
                    color: colors.onBrandAccent,
                  ),
                ),
                const SizedBox(height: AppSpacing.space2),
                Text(
                  'Black and white structure with deep MoMo green for action.',
                  style: context.appTextTheme.bodyLarge?.copyWith(
                    color: colors.onBrandAccent,
                  ),
                ),
                const SizedBox(height: AppSpacing.space6),
                Text(
                  'GHS 1,560.00',
                  style: context.appTextTheme.displayAmount.copyWith(
                    color: colors.onBrandAccent,
                  ),
                ),
                Text(
                  'Available balance',
                  style: context.appTextTheme.bodyMedium?.copyWith(
                    color: colors.onBrandAccent.withValues(alpha: 0.72),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sectionBand),
          AppSection(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AppSectionHeader(title: 'Actions'),
                const SizedBox(height: AppSpacing.space4),
                AppButton(label: 'Request GHS 200', onPressed: () {}),
                const SizedBox(height: AppSpacing.space2),
                AppButton(
                  label: 'Choose another wallet',
                  variant: AppButtonVariant.secondary,
                  onPressed: () {},
                ),
                const SizedBox(height: AppSpacing.space2),
                AppButton(
                  label: 'Cancel request',
                  variant: AppButtonVariant.destructive,
                  onPressed: () {},
                ),
                const SizedBox(height: AppSpacing.space2),
                Center(
                  child: AppButton(
                    label: 'Learn more',
                    variant: AppButtonVariant.ghost,
                    onPressed: () {},
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sectionBand),
          AppSection(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AppSectionHeader(title: 'Status and input'),
                const SizedBox(height: AppSpacing.space4),
                const Wrap(
                  spacing: AppSpacing.space2,
                  runSpacing: AppSpacing.space2,
                  children: [
                    AppStatusBadge(
                      label: 'Pending',
                      tone: AppStatusTone.warning,
                      icon: Icons.schedule_rounded,
                    ),
                    AppStatusBadge(
                      label: 'Verified',
                      tone: AppStatusTone.success,
                      icon: Icons.check_circle_rounded,
                    ),
                    AppStatusBadge(
                      label: 'Overdue',
                      tone: AppStatusTone.error,
                      icon: Icons.error_rounded,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.space4),
                const AppTextField(
                  label: 'Amount',
                  hint: '0.00',
                  helperText: 'Your current limit is GHS 500.00',
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  prefixIcon: Icon(Icons.payments_outlined),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sectionBand),
          AppSection(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AppSectionHeader(title: 'Rows and icons'),
                const SizedBox(height: AppSpacing.space4),
                AppListRow(
                  title: 'Main wallet',
                  subtitle: 'MTN · 053 827 2768',
                  leading: AppIconTile(
                    icon: Icons.account_balance_wallet_outlined,
                    backgroundColor: colors.brandSoft,
                    foregroundColor: colors.brandStrong,
                  ),
                  trailing: AppStatusBadge(
                    label: 'Default',
                    tone: AppStatusTone.brand,
                  ),
                  onTap: () {},
                ),
                const SizedBox(height: AppSpacing.space2),
                AppListRow(
                  title: 'Support',
                  subtitle: 'Get help with a transaction',
                  leading: const AppIconTile(icon: Icons.help_outline_rounded),
                  showChevron: true,
                  onTap: () {},
                ),
                const SizedBox(height: AppSpacing.space4),
                Row(
                  children: [
                    AppIconButton(
                      icon: Icons.notifications_outlined,
                      label: 'Notifications',
                      onPressed: () {},
                    ),
                    const SizedBox(width: AppSpacing.space2),
                    AppIconButton(
                      icon: Icons.more_horiz_rounded,
                      label: 'More options',
                      onPressed: () {},
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
