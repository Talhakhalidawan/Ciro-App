import 'package:flutter/material.dart';
import '../utils/ciro_theme.dart';

/// A modern animated crisis notification overlay.
///
/// Call [CrisisNotification.show] to display a sleek banner that slides
/// down from the top of the screen. Tapping it calls [onTap] (typically
/// to navigate to the crisis page). It auto-dismisses after [duration].
class CrisisNotification {
  CrisisNotification._();

  static OverlayEntry? _activeEntry;

  /// Show a crisis notification overlay on top of the current screen.
  static void show(
    BuildContext context, {
    required String title,
    required String body,
    required VoidCallback onTap,
    Duration duration = const Duration(seconds: 5),
  }) {
    // Dismiss any existing notification first
    dismiss();

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => _CrisisNotificationWidget(
        title: title,
        body: body,
        onTap: () {
          dismiss();
          onTap();
        },
        onDismiss: dismiss,
        duration: duration,
      ),
    );

    _activeEntry = entry;
    Overlay.of(context).insert(entry);
  }

  /// Dismiss the currently active notification.
  static void dismiss() {
    _activeEntry?.remove();
    _activeEntry = null;
  }
}

class _CrisisNotificationWidget extends StatefulWidget {
  final String title;
  final String body;
  final VoidCallback onTap;
  final VoidCallback onDismiss;
  final Duration duration;

  const _CrisisNotificationWidget({
    required this.title,
    required this.body,
    required this.onTap,
    required this.onDismiss,
    required this.duration,
  });

  @override
  State<_CrisisNotificationWidget> createState() =>
      _CrisisNotificationWidgetState();
}

class _CrisisNotificationWidgetState extends State<_CrisisNotificationWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
      reverseDuration: const Duration(milliseconds: 300),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
      reverseCurve: Curves.easeIn,
    ));

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _controller.forward();

    // Auto-dismiss after duration
    Future.delayed(widget.duration, () {
      if (mounted) {
        _controller.reverse().then((_) {
          if (mounted) widget.onDismiss();
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: GestureDetector(
            onTap: widget.onTap,
            onVerticalDragEnd: (details) {
              // Swipe up to dismiss
              if (details.primaryVelocity != null &&
                  details.primaryVelocity! < -200) {
                _controller.reverse().then((_) {
                  if (mounted) widget.onDismiss();
                });
              }
            },
            child: Container(
              margin: EdgeInsets.only(
                top: topPadding + 8,
                left: 16,
                right: 16,
              ),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1C1C1E), Color(0xFF2C2C2E)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                  BoxShadow(
                    color: CiroTheme.crisisRed.withValues(alpha: 0.15),
                    blurRadius: 40,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Pulsing alert icon
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: CiroTheme.crisisRed.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.warning_rounded,
                        color: Color(0xFFFF6B6B),
                        size: 24,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),

                  // Text content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: Color(0xFFFF6B6B),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Text(
                              'CRISIS ALERT',
                              style: TextStyle(
                                color: Color(0xFFFF6B6B),
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          widget.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            height: 1.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          widget.body,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            height: 1.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Tap indicator
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: Colors.white.withValues(alpha: 0.5),
                      size: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
