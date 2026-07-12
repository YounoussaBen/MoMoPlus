import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';

import '../../../core/ui/theme/app_spacing.dart';
import '../../../core/ui/theme/app_theme_controller.dart';
import '../../../core/ui/theme/app_theme_extension.dart';
import '../../../core/ui/widgets/app_icon_button.dart';
import '../../../core/ui/widgets/app_list_row.dart';
import '../../../core/ui/widgets/app_screen.dart';
import '../../../core/ui/widgets/app_section.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final gutter = AppSpacing.gutterFor(MediaQuery.sizeOf(context).width);

    return AppScreen(
      title: 'Settings',
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          gutter,
          AppSpacing.space4,
          gutter,
          AppSpacing.space8,
        ),
        children: [
          const _AppearanceSection(),
          const SizedBox(height: AppSpacing.sectionBand),
          const _RegionalSection(),
          const SizedBox(height: AppSpacing.sectionBand),
          const _AboutSection(),
          if (kDebugMode) ...[
            const SizedBox(height: AppSpacing.sectionBand),
            // const _DeveloperSection(),
          ],
        ],
      ),
    );
  }
}

// class _DeveloperSection extends StatelessWidget {
//   const _DeveloperSection();

//   @override
//   Widget build(BuildContext context) {
//     return AppSection(
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Text('Development', style: context.appTextTheme.titleMedium),
//           const SizedBox(height: AppSpacing.space4),
//           AppListRow(
//             title: 'Design system preview',
//             subtitle: 'Inspect Batch 0 components and theme tokens',
//             leading: AppIconTile(
//               icon: Icons.palette_outlined,
//               backgroundColor: context.appColors.brandSoft,
//               foregroundColor: context.appColors.brandStrong,
//             ),
//             showChevron: true,
//             onTap: () => context.push('/design-system'),
//           ),
//         ],
//       ),
//     );
//   }

// }

class _AppearanceSection extends StatelessWidget {
  const _AppearanceSection();

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppThemeController>();

    return AppSection(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Appearance', style: context.appTextTheme.titleMedium),
          const SizedBox(height: AppSpacing.space1),
          Text(
            'Choose how MoMo Plus looks on this device.',
            style: context.appTextTheme.bodyMedium?.copyWith(
              color: context.appColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.space4),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<AppThemePreference>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                  value: AppThemePreference.system,
                  label: Text('System'),
                  icon: Icon(Icons.brightness_auto_rounded, size: 18),
                ),
                ButtonSegment(
                  value: AppThemePreference.light,
                  label: Text('Light'),
                  icon: Icon(Icons.light_mode_rounded, size: 18),
                ),
                ButtonSegment(
                  value: AppThemePreference.dark,
                  label: Text('Dark'),
                  icon: Icon(Icons.dark_mode_rounded, size: 18),
                ),
              ],
              selected: {controller.preference},
              onSelectionChanged: (selection) {
                controller.setPreference(selection.single);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _RegionalSection extends StatelessWidget {
  const _RegionalSection();

  @override
  Widget build(BuildContext context) {
    return AppSection(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Regional', style: context.appTextTheme.titleMedium),
          const SizedBox(height: AppSpacing.space4),
          AppListRow(
            title: 'Language',
            subtitle: 'English',
            leading: AppIconTile(
              icon: Icons.language_rounded,
              backgroundColor: context.appColors.surfaceSubtle,
            ),
          ),
          const SizedBox(height: AppSpacing.space2),
          AppListRow(
            title: 'Currency',
            subtitle: 'Ghanaian cedi (GHS)',
            leading: AppIconTile(
              icon: Icons.currency_exchange_rounded,
              backgroundColor: context.appColors.surfaceSubtle,
            ),
          ),
        ],
      ),
    );
  }
}

class _AboutSection extends StatelessWidget {
  const _AboutSection();

  @override
  Widget build(BuildContext context) {
    return AppSection(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('About', style: context.appTextTheme.titleMedium),
          const SizedBox(height: AppSpacing.space4),
          AppListRow(
            title: 'MoMo Plus',
            subtitle: 'Version 1.0.0',
            leading: AppIconTile(
              icon: Icons.info_outline_rounded,
              backgroundColor: context.appColors.brandSoft,
              foregroundColor: context.appColors.brandStrong,
            ),
          ),
        ],
      ),
    );
  }
}
