import 'package:flutter/material.dart';

import '../theme/app_theme_extension.dart';

class AppScreen extends StatelessWidget {
  const AppScreen({
    super.key,
    required this.body,
    this.title,
    this.titleWidget,
    this.leading,
    this.actions,
    this.bottomNavigationBar,
    this.bottomSheet,
    this.floatingActionButton,
    this.automaticallyImplyLeading = true,
    this.resizeToAvoidBottomInset = true,
  }) : assert(title == null || titleWidget == null);

  final Widget body;
  final String? title;
  final Widget? titleWidget;
  final Widget? leading;
  final List<Widget>? actions;
  final Widget? bottomNavigationBar;
  final Widget? bottomSheet;
  final Widget? floatingActionButton;
  final bool automaticallyImplyLeading;
  final bool resizeToAvoidBottomInset;

  @override
  Widget build(BuildContext context) {
    final hasAppBar =
        title != null ||
        titleWidget != null ||
        leading != null ||
        (actions?.isNotEmpty ?? false);

    return Scaffold(
      backgroundColor: context.appColors.canvas,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      appBar: hasAppBar
          ? AppBar(
              title: titleWidget ?? (title == null ? null : Text(title!)),
              leading: leading,
              actions: actions,
              automaticallyImplyLeading: automaticallyImplyLeading,
            )
          : null,
      body: body,
      bottomNavigationBar: bottomNavigationBar,
      bottomSheet: bottomSheet,
      floatingActionButton: floatingActionButton,
    );
  }
}
