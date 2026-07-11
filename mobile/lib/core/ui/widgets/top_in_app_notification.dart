import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_motion.dart';
import '../theme/app_radii.dart';
import '../theme/app_spacing.dart';
import '../theme/app_theme_extension.dart';

enum AppNotificationType { info, success, error }

OverlayEntry? _activeNotificationEntry;

void showTopInAppNotification(
  BuildContext context, {
  required String message,
  String? title,
  AppNotificationType type = AppNotificationType.info,
  Duration duration = const Duration(seconds: 3),
}) {
  final overlay = Overlay.of(context, rootOverlay: true);

  _activeNotificationEntry?.remove();
  _activeNotificationEntry = null;

  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _TopInAppNotificationOverlay(
      title: title,
      message: message,
      type: type,
      duration: duration,
      onDismissed: () {
        if (_activeNotificationEntry == entry) {
          _activeNotificationEntry = null;
        }
        entry.remove();
      },
    ),
  );

  _activeNotificationEntry = entry;
  overlay.insert(entry);
}

class _TopInAppNotificationOverlay extends StatefulWidget {
  const _TopInAppNotificationOverlay({
    this.title,
    required this.message,
    required this.type,
    required this.duration,
    required this.onDismissed,
  });

  final String? title;
  final String message;
  final AppNotificationType type;
  final Duration duration;
  final VoidCallback onDismissed;

  @override
  State<_TopInAppNotificationOverlay> createState() =>
      _TopInAppNotificationOverlayState();
}

class _TopInAppNotificationOverlayState
    extends State<_TopInAppNotificationOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slide;
  late final Animation<double> _fade;
  Timer? _timer;
  bool _isDismissing = false;
  double _dragOffset = 0;

  @override
  void initState() {
    super.initState();
    final reduceMotion = WidgetsBinding
        .instance
        .platformDispatcher
        .accessibilityFeatures
        .disableAnimations;
    _controller = AnimationController(
      vsync: this,
      duration: reduceMotion ? Duration.zero : AppMotion.standard,
      reverseDuration: reduceMotion ? Duration.zero : AppMotion.fast,
    );
    _slide = Tween<Offset>(begin: const Offset(0, -0.25), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _controller,
            curve: AppMotion.enter,
            reverseCurve: AppMotion.exit,
          ),
        );
    _fade = CurvedAnimation(parent: _controller, curve: AppMotion.enter);

    _controller.forward();
    _timer = Timer(widget.duration, _dismiss);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _dismiss() async {
    if (_isDismissing) return;
    _isDismissing = true;
    _timer?.cancel();
    await _controller.reverse();
    widget.onDismissed();
  }

  ({Color foreground, Color background}) _tone(BuildContext context) {
    final colors = context.appColors;
    return switch (widget.type) {
      AppNotificationType.info => (
        foreground: colors.info,
        background: colors.infoContainer,
      ),
      AppNotificationType.success => (
        foreground: colors.success,
        background: colors.successContainer,
      ),
      AppNotificationType.error => (
        foreground: colors.error,
        background: colors.errorContainer,
      ),
    };
  }

  IconData get _icon => switch (widget.type) {
    AppNotificationType.info => Icons.info_outline_rounded,
    AppNotificationType.success => Icons.check_circle_outline_rounded,
    AppNotificationType.error => Icons.error_outline_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final tone = _tone(context);
    final topPadding = MediaQuery.viewPaddingOf(context).top;

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SlideTransition(
        position: _slide,
        child: FadeTransition(
          opacity: _fade,
          child: GestureDetector(
            onVerticalDragUpdate: (details) {
              setState(() {
                _dragOffset += details.delta.dy;
                if (_dragOffset > 0) _dragOffset = 0;
              });
            },
            onVerticalDragEnd: (details) {
              if (_dragOffset < -30 ||
                  details.velocity.pixelsPerSecond.dy < -200) {
                HapticFeedback.lightImpact();
                _dismiss();
              } else {
                setState(() => _dragOffset = 0);
              }
            },
            child: Transform.translate(
              offset: Offset(0, _dragOffset),
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.space3,
                  topPadding + AppSpacing.space2,
                  AppSpacing.space3,
                  0,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Semantics(
                      liveRegion: true,
                      container: true,
                      child: Material(
                        color: colors.surfaceSubtle,
                        borderRadius: AppRadii.mediumBorderRadius,
                        clipBehavior: Clip.antiAlias,
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.space3),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: tone.background,
                                  borderRadius: AppRadii.smallBorderRadius,
                                ),
                                child: Icon(
                                  _icon,
                                  size: 20,
                                  color: tone.foreground,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.space3),
                              Expanded(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (widget.title != null) ...[
                                      Text(
                                        widget.title!,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: context.appTextTheme.titleSmall,
                                      ),
                                      const SizedBox(height: AppSpacing.space1),
                                    ],
                                    Text(
                                      widget.message,
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                      style: context.appTextTheme.bodyMedium
                                          ?.copyWith(
                                            color: widget.title == null
                                                ? colors.textPrimary
                                                : colors.textSecondary,
                                            fontWeight: widget.title == null
                                                ? FontWeight.w500
                                                : FontWeight.w400,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                tooltip: 'Dismiss notification',
                                onPressed: _dismiss,
                                icon: const Icon(Icons.close_rounded, size: 20),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
