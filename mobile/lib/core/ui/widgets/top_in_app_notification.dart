import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

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
  final String? title;
  final String message;
  final AppNotificationType type;
  final Duration duration;
  final VoidCallback onDismissed;

  const _TopInAppNotificationOverlay({
    this.title,
    required this.message,
    required this.type,
    required this.duration,
    required this.onDismissed,
  });

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
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
      reverseDuration: const Duration(milliseconds: 250),
    );
    _slide = Tween<Offset>(begin: const Offset(0, -1.1), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _controller,
            curve: Curves.easeOutBack,
            reverseCurve: Curves.easeIn,
          ),
        );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);

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

  Color get _accentColor => switch (widget.type) {
    AppNotificationType.info => const Color(0xFF3B82F6),
    AppNotificationType.success => AppColors.primary,
    AppNotificationType.error => AppColors.error,
  };

  Color get _accentBg => switch (widget.type) {
    AppNotificationType.info => const Color(0xFFEFF6FF),
    AppNotificationType.success => const Color(0xFFECFCE5),
    AppNotificationType.error => const Color(0xFFFEF2F2),
  };

  IconData get _icon => switch (widget.type) {
    AppNotificationType.info => Icons.info_outline_rounded,
    AppNotificationType.success => Icons.check_circle_outline_rounded,
    AppNotificationType.error => Icons.error_outline_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).viewPadding.top;

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
            onTap: () {
              HapticFeedback.lightImpact();
              _dismiss();
            },
            child: Transform.translate(
              offset: Offset(0, _dragOffset),
              child: Padding(
                padding: EdgeInsets.fromLTRB(10, topPadding + 6, 10, 0),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                        child: Material(
                          color: Colors.transparent,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.82),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.5),
                                width: 0.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.06),
                                  blurRadius: 20,
                                  spreadRadius: 0,
                                  offset: const Offset(0, 8),
                                ),
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.03),
                                  blurRadius: 6,
                                  spreadRadius: 0,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Row(
                                children: [
                                  Container(
                                    width: 34,
                                    height: 34,
                                    decoration: BoxDecoration(
                                      color: _accentBg,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                      _icon,
                                      size: 20,
                                      color: _accentColor,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        if (widget.title != null) ...[
                                          Text(
                                            widget.title!,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.textPrimary,
                                              letterSpacing: -0.2,
                                              height: 1.2,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                        ],
                                        Text(
                                          widget.message,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 13,
                                            height: 1.3,
                                            fontWeight: widget.title == null
                                                ? FontWeight.w500
                                                : FontWeight.w400,
                                            color: widget.title == null
                                                ? AppColors.textPrimary
                                                : AppColors.textSecondary,
                                            letterSpacing: -0.1,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    width: 28,
                                    height: 28,
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(
                                        alpha: 0.04,
                                      ),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Icon(
                                      Icons.close_rounded,
                                      size: 15,
                                      color: AppColors.textSecondary.withValues(
                                        alpha: 0.6,
                                      ),
                                    ),
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
        ),
      ),
    );
  }
}
