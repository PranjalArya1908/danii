import 'package:flutter/material.dart';
import '../theme/colors.dart';

class BreathingGlowCard extends StatefulWidget {
  final Widget child;
  final VoidCallback onClick;
  final Color glowColor;
  final double cornerRadius;

  const BreathingGlowCard({
    super.key,
    required this.child,
    required this.onClick,
    this.glowColor = SafeLoopColors.primaryViolet,
    this.cornerRadius = 24.0,
  });

  @override
  State<BreathingGlowCard> createState() => _BreathingGlowCardState();
}

class _BreathingGlowCardState extends State<BreathingGlowCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(begin: 0.25, end: 0.75).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bgGradient = isDark
        ? const [Color(0xFF161F45), Color(0xFF0F1530)]
        : const [Color(0xFFF5F3FF), Color(0xFFFFFFFF)];

    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        final glowAlpha = _glowAnimation.value;

        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.cornerRadius),
            boxShadow: [
              BoxShadow(
                color: widget.glowColor.withValues(alpha: glowAlpha * 0.4),
                blurRadius: 16,
                spreadRadius: 2,
              ),
            ],
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: bgGradient,
            ),
            border: Border.all(
              width: 2.0,
              color: isDark
                  ? widget.glowColor.withValues(alpha: glowAlpha)
                  : SafeLoopColors.primaryViolet.withValues(alpha: glowAlpha),
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(widget.cornerRadius),
              onTap: widget.onClick,
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: widget.child,
              ),
            ),
          ),
        );
      },
    );
  }
}

