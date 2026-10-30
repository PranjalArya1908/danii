import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class BreathingGlowCard extends StatefulWidget {
  final Widget child;
  final VoidCallback onClick;
  final Color glowColor;
  final double cornerRadius;
  final EdgeInsetsGeometry padding;

  const BreathingGlowCard({
    super.key,
    required this.child,
    required this.onClick,
    this.glowColor = AppColors.primaryViolet,
    this.cornerRadius = 24.0,
    this.padding = const EdgeInsets.all(20.0),
  });

  @override
  State<BreathingGlowCard> createState() => _BreathingGlowCardState();
}

class _BreathingGlowCardState extends State<BreathingGlowCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _glowController;
  late Animation<double> _glowAlphaAnimation;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    _glowAlphaAnimation = Tween<double>(begin: 0.25, end: 0.85).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderRadius = BorderRadius.circular(widget.cornerRadius);

    final bgGradient = isDark
        ? const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF161F45), Color(0xFF0F1530)],
          )
        : const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF5F3FF), Color(0xFFFFFFFF)],
          );

    return AnimatedBuilder(
      animation: _glowAlphaAnimation,
      builder: (context, child) {
        final alpha = _glowAlphaAnimation.value;

        return Container(
          decoration: BoxDecoration(
            borderRadius: borderRadius,
            boxShadow: [
              BoxShadow(
                color: widget.glowColor.withValues(alpha: alpha * 0.25),
                blurRadius: 18,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: borderRadius,
            child: InkWell(
              onTap: widget.onClick,
              borderRadius: borderRadius,
              child: Container(
                padding: widget.padding,
                decoration: BoxDecoration(
                  gradient: bgGradient,
                  borderRadius: borderRadius,
                  border: Border.all(
                    width: 2.0,
                    color: isDark
                        ? widget.glowColor.withValues(alpha: alpha)
                        : AppColors.primaryViolet.withValues(alpha: alpha),
                  ),
                ),
                child: widget.child,
              ),
            ),
          ),
        );
      },
    );
  }
}

