import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';

/// An ultra-modern, interactive swipe-to-confirm action slider.
/// Features full-track swipe interaction, animated radar pulse waves, dynamic
/// contextual text guidance, glowing 3D thumb orb, and celebratory confirmation animation.
/// Completely glitch-free with monotonic easing and gesture cancellation protection.
class SwipeActionControl extends StatefulWidget {
  final String label;
  final String confirmedLabel;
  final VoidCallback onConfirmed;
  final Color sliderColor;
  final Color? backgroundColor;
  final IconData icon;
  final IconData confirmedIcon;

  const SwipeActionControl({
    super.key,
    required this.label,
    this.confirmedLabel = 'ESCORT ACTIVE • ARMED & MONITORED',
    required this.onConfirmed,
    this.sliderColor = AppColors.primaryCobalt,
    this.backgroundColor,
    this.icon = Icons.chevron_right,
    this.confirmedIcon = Icons.check_circle_rounded,
  });

  @override
  State<SwipeActionControl> createState() => _SwipeActionControlState();
}

class _SwipeActionControlState extends State<SwipeActionControl>
    with TickerProviderStateMixin {
  double _dragPosition = 0.0;
  double _dragStartPos = 0.0;
  double _dragTargetPos = 0.0;
  double _activeMaxDrag = 0.0;
  bool _isConfirmed = false;
  bool _hasTriggeredCallback = false;

  late AnimationController _resetController;

  // Animated sliding chevron waves (>>>)
  late AnimationController _shimmerController;

  // Gentle breathing glow & radar pulse on thumb
  late AnimationController _pulseController;

  // Confirmation celebration burst animation
  late AnimationController _confirmController;
  late Animation<double> _confirmScale;

  @override
  void initState() {
    super.initState();

    // Dedicated smooth glide animation controller (monotonic Curves.easeOutCubic)
    _resetController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
    );

    _resetController.addListener(() {
      if (!mounted) return;
      setState(() {
        final t = Curves.easeOutCubic.transform(_resetController.value);
        _dragPosition = (_dragStartPos + (_dragTargetPos - _dragStartPos) * t)
            .clamp(0.0, _activeMaxDrag > 0 ? _activeMaxDrag : double.infinity);
      });
    });

    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();

    _confirmController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );

    _confirmScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.12), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.12, end: 1.0), weight: 60),
    ]).animate(CurvedAnimation(parent: _confirmController, curve: Curves.easeInOutBack));
  }

  @override
  void dispose() {
    _resetController.dispose();
    _shimmerController.dispose();
    _pulseController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _onDragStart(DragStartDetails details, double maxDrag) {
    if (_isConfirmed || maxDrag <= 0) return;
    _activeMaxDrag = maxDrag;
    if (_resetController.isAnimating) {
      _resetController.stop();
    }
  }

  void _onDragUpdate(DragUpdateDetails details, double maxDrag) {
    if (_isConfirmed || maxDrag <= 0) return;
    _activeMaxDrag = maxDrag;
    setState(() {
      _dragPosition = (_dragPosition + details.delta.dx).clamp(0.0, maxDrag);
    });
  }

  void _onDragEnd(DragEndDetails details, double maxDrag) {
    _finishDrag(maxDrag, velocity: details.primaryVelocity ?? 0.0);
  }

  void _onDragCancel(double maxDrag) {
    _finishDrag(maxDrag, velocity: 0.0);
  }

  void _finishDrag(double maxDrag, {double velocity = 0.0}) {
    if (_isConfirmed || maxDrag <= 0) return;
    _activeMaxDrag = maxDrag;

    // Trigger confirmation if dragged past 65% or swiped with confident velocity
    final shouldConfirm = _dragPosition >= maxDrag * 0.65 ||
        (velocity > 250 && _dragPosition >= maxDrag * 0.25);

    if (shouldConfirm) {
      // Smoothly glide thumb to complete position without abrupt jumps
      _dragStartPos = _dragPosition;
      _dragTargetPos = maxDrag;
      setState(() {
        _isConfirmed = true;
      });

      _confirmController.forward(from: 0.0);
      try {
        HapticFeedback.heavyImpact();
      } catch (_) {}

      if (!_hasTriggeredCallback) {
        _hasTriggeredCallback = true;
        widget.onConfirmed();
      }

      _resetController.duration = const Duration(milliseconds: 140);
      _resetController.forward(from: 0.0);
    } else {
      // Smoothly snap back to 0.0 using strictly monotonic easing
      _dragStartPos = _dragPosition;
      _dragTargetPos = 0.0;
      _resetController.duration = const Duration(milliseconds: 200);
      _resetController.forward(from: 0.0);
    }
  }

  String _getInteractiveLabel(double progress) {
    if (_isConfirmed) return widget.confirmedLabel;
    if (progress >= 0.75) return 'RELEASE TO ARM PROTECTION';
    if (progress >= 0.35) return 'KEEP SLIDING RIGHT TO SECURE...';
    return widget.label;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final defaultBg = isDark
        ? AppColors.midnightDarkSurfaceVariant
        : AppColors.lightSurfaceVariant;
    final bgColor = widget.backgroundColor ?? defaultBg;

    const double height = 66.0;
    const double thumbSize = 54.0;
    const double padding = 6.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final double maxDrag =
            (constraints.maxWidth - thumbSize - (padding * 2)).clamp(0.0, double.infinity);
        final double progress = maxDrag > 0 ? (_dragPosition / maxDrag).clamp(0.0, 1.0) : 0.0;

        return GestureDetector(
          onHorizontalDragStart: (d) => _onDragStart(d, maxDrag),
          onHorizontalDragUpdate: (d) => _onDragUpdate(d, maxDrag),
          onHorizontalDragEnd: (d) => _onDragEnd(d, maxDrag),
          onHorizontalDragCancel: () => _onDragCancel(maxDrag),
          child: AnimatedBuilder(
            animation: _confirmScale,
            builder: (context, child) {
              return Transform.scale(
                scale: _isConfirmed ? _confirmScale.value : 1.0,
                child: Container(
                  width: double.infinity,
                  height: height,
                  decoration: BoxDecoration(
                    color: _isConfirmed
                        ? AppColors.safeGreen.withValues(alpha: isDark ? 0.28 : 0.2)
                        : bgColor,
                    borderRadius: BorderRadius.circular(36),
                    border: Border.all(
                      color: _isConfirmed
                          ? AppColors.safeGreen
                          : Color.lerp(widget.sliderColor, AppColors.safeGreenGlow, progress)!
                              .withValues(alpha: isDark ? 0.6 : 0.4),
                      width: 1.8,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _isConfirmed
                            ? AppColors.safeGreen.withValues(alpha: 0.4)
                            : widget.sliderColor.withValues(alpha: 0.18 + (progress * 0.25)),
                        blurRadius: 18 + (progress * 8),
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(36),
                    child: Stack(
                      alignment: Alignment.centerLeft,
                      children: [
                        // 1. Dynamic Progress Fill behind thumb
                        Positioned(
                          left: 0,
                          top: 0,
                          bottom: 0,
                          width: _isConfirmed
                              ? constraints.maxWidth
                              : (padding + _dragPosition + (thumbSize / 2)).clamp(0.0, constraints.maxWidth),
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  widget.sliderColor.withValues(alpha: isDark ? 0.45 : 0.35),
                                  Color.lerp(widget.sliderColor, AppColors.safeGreenGlow, progress)!
                                      .withValues(alpha: isDark ? 0.65 : 0.55),
                                ],
                              ),
                            ),
                          ),
                        ),

                        // 2. Animated Sliding Chevron Guides (>>>)
                        if (!_isConfirmed && progress < 0.65)
                          Positioned.fill(
                            child: AnimatedBuilder(
                              animation: _shimmerController,
                              builder: (context, child) {
                                return CustomPaint(
                                  painter: _ChevronFlowPainter(
                                    animationValue: _shimmerController.value,
                                    thumbPosition: padding + _dragPosition + thumbSize,
                                    isDark: isDark,
                                    accentColor: Color.lerp(widget.sliderColor, AppColors.safeGreenGlow, progress)!,
                                  ),
                                );
                              },
                            ),
                          ),

                        // 3. Central Interactive Label Text with Progress-Aware Feedback (Bounded & Safe)
                        Positioned.fill(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 50.0),
                            child: Center(
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 180),
                                layoutBuilder: (currentChild, previousChildren) {
                                  return Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      ...previousChildren,
                                      ?currentChild,
                                    ],
                                  );
                                },
                                child: SizedBox(
                                  key: ValueKey('${_isConfirmed}_${progress >= 0.75}_${progress >= 0.35}'),
                                  width: double.infinity,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      if (_isConfirmed) ...[
                                        const Icon(Icons.verified_rounded, color: AppColors.safeGreen, size: 18),
                                        const SizedBox(width: 6),
                                      ] else if (progress >= 0.75) ...[
                                        const Icon(Icons.bolt_rounded, color: AppColors.safeGreenGlow, size: 16),
                                        const SizedBox(width: 4),
                                      ],
                                      Flexible(
                                        child: Text(
                                          _getInteractiveLabel(progress),
                                          textAlign: TextAlign.center,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 0.4,
                                            color: _isConfirmed
                                                ? AppColors.safeGreen
                                                : (progress >= 0.75
                                                    ? AppColors.safeGreenGlow
                                                    : (progress >= 0.35
                                                        ? widget.sliderColor
                                                        : (isDark ? AppColors.textPrimary : AppColors.lightTextPrimary))),
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

                        // 4. Draggable High-Tech Thumb Orb with Radar Wave Rings
                        Positioned(
                          left: padding + _dragPosition,
                          child: AnimatedBuilder(
                            animation: _pulseController,
                            builder: (context, child) {
                              final pulse = _pulseController.value;
                              final activeColor = _isConfirmed
                                  ? AppColors.safeGreen
                                  : Color.lerp(widget.sliderColor, AppColors.safeGreenGlow, progress)!;

                              return SizedBox(
                                width: thumbSize,
                                height: thumbSize,
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    // Radar Expanding Wave Ring when idle
                                    if (!_isConfirmed && progress < 0.15)
                                      Transform.scale(
                                        scale: 1.0 + (pulse * 0.4),
                                        child: Container(
                                          width: thumbSize,
                                          height: thumbSize,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: activeColor.withValues(alpha: (1.0 - pulse) * 0.5),
                                              width: 2.0,
                                            ),
                                          ),
                                        ),
                                      ),

                                    // Main Thumb Orb
                                    Container(
                                      width: thumbSize - 2,
                                      height: thumbSize - 2,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: _isConfirmed
                                              ? [AppColors.safeGreenGlow, AppColors.safeGreen]
                                              : [
                                                  activeColor,
                                                  Color.lerp(activeColor, const Color(0xFF0F172A), 0.45)!,
                                                ],
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: activeColor.withValues(alpha: 0.55),
                                            blurRadius: 14 + (progress * 8),
                                            spreadRadius: 1 + (progress * 2),
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                        border: Border.all(
                                          color: Colors.white.withValues(alpha: 0.75),
                                          width: 2.0,
                                        ),
                                      ),
                                      child: Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          // Specular gloss flare
                                          Positioned(
                                            top: 3,
                                            child: Container(
                                              width: thumbSize * 0.52,
                                              height: thumbSize * 0.24,
                                              decoration: BoxDecoration(
                                                borderRadius: BorderRadius.circular(20),
                                                gradient: LinearGradient(
                                                  begin: Alignment.topCenter,
                                                  end: Alignment.bottomCenter,
                                                  colors: [
                                                    Colors.white.withValues(alpha: 0.65),
                                                    Colors.white.withValues(alpha: 0.0),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),

                                          // Inner Icon
                                          AnimatedSwitcher(
                                            duration: const Duration(milliseconds: 250),
                                            transitionBuilder: (child, anim) => ScaleTransition(
                                              scale: anim,
                                              child: child,
                                            ),
                                            child: Icon(
                                              _isConfirmed ? widget.confirmedIcon : widget.icon,
                                              key: ValueKey(_isConfirmed),
                                              color: Colors.white,
                                              size: 28,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

/// Custom painter that draws sliding glowing chevron arrow waves across the track
class _ChevronFlowPainter extends CustomPainter {
  final double animationValue;
  final double thumbPosition;
  final bool isDark;
  final Color accentColor;

  _ChevronFlowPainter({
    required this.animationValue,
    required this.thumbPosition,
    required this.isDark,
    required this.accentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final startX = math.max(thumbPosition + 15, size.width * 0.55);
    final endX = size.width - 24;
    final availableWidth = endX - startX;

    if (availableWidth <= 20) return;

    final centerY = size.height / 2;
    const chevronCount = 4;

    for (int i = 0; i < chevronCount; i++) {
      final phase = (animationValue + (i / chevronCount)) % 1.0;
      final x = startX + (phase * availableWidth);

      final alpha = math.sin(phase * math.pi).clamp(0.0, 1.0) * (isDark ? 0.6 : 0.45);
      final paint = Paint()
        ..color = accentColor.withValues(alpha: alpha)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = 2.6;

      final path = Path()
        ..moveTo(x - 5, centerY - 7)
        ..lineTo(x + 3, centerY)
        ..lineTo(x - 5, centerY + 7);

      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ChevronFlowPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.thumbPosition != thumbPosition ||
        oldDelegate.isDark != isDark ||
        oldDelegate.accentColor != accentColor;
  }
}
