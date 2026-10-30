import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/models.dart';
import '../theme/app_colors.dart';

/// A futuristic, interactive circular journey launcher card.
/// Features a central animated "Aegis Core" orb with rotating telemetry arcs,
/// pulsing radar halo, responsive touch feedback, and crisp headline text.
class CircularJourneyLauncher extends StatefulWidget {
  final bool hasActiveJourney;
  final Journey? activeJourney;
  final VoidCallback onStartJourney;
  final VoidCallback onViewActiveJourney;
  final VoidCallback? onQuickEmergency;
  final ValueChanged<TransportMode>? onModeChanged;
  final int contactsCount;
  final bool isGpsLocked;

  const CircularJourneyLauncher({
    super.key,
    required this.hasActiveJourney,
    this.activeJourney,
    required this.onStartJourney,
    required this.onViewActiveJourney,
    this.onQuickEmergency,
    this.onModeChanged,
    this.contactsCount = 0,
    this.isGpsLocked = false,
  });

  @override
  State<CircularJourneyLauncher> createState() => _CircularJourneyLauncherState();
}

class _CircularJourneyLauncherState extends State<CircularJourneyLauncher>
    with TickerProviderStateMixin {
  late AnimationController _rotationController;
  late AnimationController _pulseController;
  late AnimationController _scaleController;

  @override
  void initState() {
    super.initState();

    // Smooth continuous telemetry rotation (10s loop)
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();

    // Breathing pulse for guardian glow (2.6s loop)
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat(reverse: true);

    // Micro-interaction spring on tap
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 140),
      lowerBound: 0.92,
      upperBound: 1.0,
      value: 1.0,
    );
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _pulseController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  void _onOrbTapDown(TapDownDetails details) {
    _scaleController.reverse();
  }

  void _onOrbTapUp(TapUpDetails details) {
    _scaleController.forward();
    if (widget.hasActiveJourney) {
      widget.onViewActiveJourney();
    } else {
      widget.onStartJourney();
    }
  }

  void _onOrbTapCancel() {
    _scaleController.forward();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.midnightDarkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: widget.hasActiveJourney
              ? AppColors.primaryViolet.withValues(alpha: isDark ? 0.6 : 0.4)
              : (isDark ? AppColors.midnightDarkCardBorder : AppColors.lightCardBorder),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: widget.hasActiveJourney
                ? AppColors.primaryViolet.withValues(alpha: isDark ? 0.25 : 0.15)
                : (isDark ? Colors.black.withValues(alpha: 0.35) : Colors.black.withValues(alpha: 0.05)),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.hasActiveJourney ? widget.onViewActiveJourney : widget.onStartJourney,
            borderRadius: BorderRadius.circular(24),
            splashColor: AppColors.primaryViolet.withValues(alpha: 0.12),
            highlightColor: AppColors.primaryViolet.withValues(alpha: 0.06),
            child: Stack(
              children: [
                // Background tactical grid painter
                Positioned.fill(
                  child: CustomPaint(
                    painter: _TacticalGridPainter(
                      isDark: isDark,
                      isActive: widget.hasActiveJourney,
                    ),
                  ),
                ),

                // Main Card Content: Orb and Headline Text Only
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Active Journey Header Ribbon (only rendered when transit is active)
                      if (widget.hasActiveJourney) ...[
                        _buildActiveHeaderRibbon(isDark),
                        const SizedBox(height: 16),
                      ],

                      // Hero Circular Aegis Core Orb with Concentric Telemetry
                      _buildCircularOrb(isDark),
                      const SizedBox(height: 16),

                      // Title & Subtitle Text
                      _buildHeadline(isDark),

                      // Active Journey Action Buttons
                      if (widget.hasActiveJourney) ...[
                        const SizedBox(height: 18),
                        _buildActiveJourneyTelemetry(isDark),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActiveHeaderRibbon(bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.primaryViolet.withValues(alpha: isDark ? 0.25 : 0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppColors.primaryViolet.withValues(alpha: 0.4),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: AppColors.safeGreenGlow,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.safeGreenGlow.withValues(
                            alpha: 0.4 + (_pulseController.value * 0.5),
                          ),
                          blurRadius: 6,
                          spreadRadius: 2 * _pulseController.value,
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(width: 6),
              const Text(
                'ESCORT ACTIVE',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                  color: AppColors.primaryViolet,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: isDark ? AppColors.midnightDarkCard : AppColors.lightSurfaceVariant,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            'LIVE TELEMETRY',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.6,
              color: isDark ? AppColors.textSecondary : AppColors.lightTextSecondary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCircularOrb(bool isDark) {
    const double orbSize = 136.0;
    const double telemetrySize = 186.0;

    final progress = widget.activeJourney?.progressPercent ?? 0.0;

    return Center(
      child: GestureDetector(
        onTapDown: _onOrbTapDown,
        onTapUp: _onOrbTapUp,
        onTapCancel: _onOrbTapCancel,
        child: ScaleTransition(
          scale: _scaleController,
          child: SizedBox(
            width: telemetrySize,
            height: telemetrySize,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // 1. Concentric Breathing Halo Aura
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    final pulse = _pulseController.value;
                    final haloRadius = (telemetrySize / 2) + (pulse * 10);
                    return Container(
                      width: haloRadius * 2,
                      height: haloRadius * 2,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            widget.hasActiveJourney
                                ? AppColors.safeGreenGlow.withValues(alpha: 0.22 * pulse)
                                : AppColors.primaryViolet.withValues(alpha: (0.16 + (0.12 * pulse))),
                            Colors.transparent,
                          ],
                          stops: const [0.45, 1.0],
                        ),
                      ),
                    );
                  },
                ),

                // 2. Animated Outer Telemetry Ring / Progress Arc
                AnimatedBuilder(
                  animation: _rotationController,
                  builder: (context, child) {
                    return CustomPaint(
                      size: const Size(telemetrySize, telemetrySize),
                      painter: _OrbTelemetryPainter(
                        rotationAngle: _rotationController.value * 2 * math.pi,
                        hasActiveJourney: widget.hasActiveJourney,
                        progressPercent: progress,
                        isDark: isDark,
                      ),
                    );
                  },
                ),

                // 3. Central Interactive Orb Container
                Container(
                  width: orbSize,
                  height: orbSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: widget.hasActiveJourney
                          ? [
                              AppColors.deepCobalt,
                              const Color(0xFF0F265C),
                              const Color(0xFF07122E),
                            ]
                          : (isDark
                              ? [
                                  AppColors.primaryCobalt,
                                  AppColors.deepCobalt,
                                  const Color(0xFF0A183C),
                                ]
                              : [
                                  AppColors.electricCyan,
                                  AppColors.primaryCobalt,
                                  AppColors.deepCobalt,
                                ]),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: widget.hasActiveJourney
                            ? AppColors.primaryViolet.withValues(alpha: 0.5)
                            : AppColors.primaryViolet.withValues(alpha: 0.35),
                        blurRadius: 18,
                        spreadRadius: 2,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Specular Gloss Flare
                      Positioned(
                        top: 6,
                        left: 20,
                        right: 20,
                        child: Container(
                          height: 34,
                          decoration: BoxDecoration(
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(60),
                              bottom: Radius.circular(30),
                            ),
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.white.withValues(alpha: 0.35),
                                Colors.white.withValues(alpha: 0.0),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Inner Orb Content
                      if (widget.hasActiveJourney)
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              widget.activeJourney?.transportMode.icon ?? Icons.navigation_rounded,
                              color: Colors.white,
                              size: 26,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${(progress * 100).toInt()}%',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: -0.5,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Text(
                                'VIEW COCKPIT',
                                style: TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.8,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        )
                      else
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withValues(alpha: 0.15),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.25),
                                  width: 1.5,
                                ),
                              ),
                              child: const Icon(
                                Icons.shield_rounded,
                                color: Colors.white,
                                size: 30,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'ACTIVATE',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: 2.2,
                              ),
                            ),
                            Text(
                              'TAP ORB',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                color: Colors.white.withValues(alpha: 0.8),
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeadline(bool isDark) {
    if (widget.hasActiveJourney) {
      final dest = widget.activeJourney?.destinationAddress ?? 'Destination';
      final vehicle = widget.activeJourney?.vehicleNumber ?? '';

      return Column(
        children: [
          Text(
            'JOURNEY IN PROGRESS',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              color: isDark ? AppColors.textPrimary : AppColors.lightTextPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.place_rounded, size: 14, color: AppColors.primaryViolet),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  dest,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.textSecondary : AppColors.lightTextSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (vehicle.isNotEmpty) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.midnightDarkCard : AppColors.lightSurfaceVariant,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isDark ? AppColors.midnightDarkCardBorder : AppColors.lightCardBorder,
                    ),
                  ),
                  child: Text(
                    vehicle,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                      color: isDark ? AppColors.textPrimary : AppColors.lightTextPrimary,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      );
    }

    return Column(
      children: [
        Text(
          'Start Protected Journey',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.3,
            color: isDark ? AppColors.textPrimary : AppColors.lightTextPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Adaptive check-ins & automatic escalation with live telemetry',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            height: 1.35,
            color: isDark ? AppColors.textSecondary : AppColors.lightTextSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildActiveJourneyTelemetry(bool isDark) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: widget.onViewActiveJourney,
                icon: const Icon(Icons.map_rounded, size: 18),
                label: const Text('Open Live Cockpit'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryViolet,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 4,
                ),
              ),
            ),
            if (widget.onQuickEmergency != null) ...[
              const SizedBox(width: 10),
              IconButton.filled(
                onPressed: widget.onQuickEmergency,
                icon: const Icon(Icons.emergency, color: Colors.white, size: 22),
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.emergencyRed,
                  padding: const EdgeInsets.all(14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                tooltip: 'Emergency SOS',
              ),
            ],
          ],
        ),
      ],
    );
  }
}

/// Custom painter that draws rotating concentric telemetry arcs, tick marks,
/// and satellite blips around the central orb.
class _OrbTelemetryPainter extends CustomPainter {
  final double rotationAngle;
  final bool hasActiveJourney;
  final double progressPercent;
  final bool isDark;

  _OrbTelemetryPainter({
    required this.rotationAngle,
    required this.hasActiveJourney,
    required this.progressPercent,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerRadius = (size.width / 2) - 4;
    final innerRadius = outerRadius - 14;

    // 1. Draw base faint track ring
    final baseTrackPaint = Paint()
      ..color = isDark
          ? AppColors.midnightDarkCardBorder.withValues(alpha: 0.6)
          : AppColors.lightCardBorder
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawCircle(center, outerRadius, baseTrackPaint);

    if (hasActiveJourney) {
      // Draw Circular Progress Arc
      final sweepAngle = 2 * math.pi * progressPercent.clamp(0.01, 1.0);

      final progressPaint = Paint()
        ..shader = const SweepGradient(
          colors: [
            AppColors.primaryViolet,
            AppColors.electricLavender,
            AppColors.safeGreenGlow,
          ],
          stops: [0.0, 0.7, 1.0],
          transform: GradientRotation(-math.pi / 2),
        ).createShader(Rect.fromCircle(center: center, radius: outerRadius))
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 6.0;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: outerRadius),
        -math.pi / 2,
        sweepAngle,
        false,
        progressPaint,
      );

      // Glowing tip indicator
      final tipAngle = -math.pi / 2 + sweepAngle;
      final tipX = center.dx + outerRadius * math.cos(tipAngle);
      final tipY = center.dy + outerRadius * math.sin(tipAngle);

      final glowPaint = Paint()
        ..color = AppColors.safeGreenGlow.withValues(alpha: 0.6)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      canvas.drawCircle(Offset(tipX, tipY), 6, glowPaint);

      final tipPointPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(tipX, tipY), 4, tipPointPaint);

      return;
    }

    // Idle Mode: Futuristic Segmented Rotating Radar Arcs
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotationAngle);

    final arcPaint = Paint()
      ..color = AppColors.primaryViolet.withValues(alpha: isDark ? 0.75 : 0.55)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2.5;

    // 4 tactical arc segments around the ring
    const segments = 4;
    const arcSweep = math.pi / 3.2; // ~56 degrees
    for (int i = 0; i < segments; i++) {
      final startAngle = i * (2 * math.pi / segments);
      canvas.drawArc(
        Rect.fromCircle(center: Offset.zero, radius: outerRadius),
        startAngle,
        arcSweep,
        false,
        arcPaint,
      );
    }

    // Draw inner dashed tactical ring (rotating in reverse)
    final innerArcPaint = Paint()
      ..color = AppColors.electricLavender.withValues(alpha: isDark ? 0.45 : 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    for (int i = 0; i < 8; i++) {
      final start = -rotationAngle * 1.5 + (i * (math.pi / 4));
      canvas.drawArc(
        Rect.fromCircle(center: Offset.zero, radius: innerRadius),
        start,
        math.pi / 12,
        false,
        innerArcPaint,
      );
    }

    // Orbiting Satellite Energy Node with trail
    final orbiterX = outerRadius * math.cos(0);
    final orbiterY = outerRadius * math.sin(0);

    final orbiterGlow = Paint()
      ..color = AppColors.electricLavender.withValues(alpha: 0.8)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
    canvas.drawCircle(Offset(orbiterX, orbiterY), 5, orbiterGlow);

    final orbiterDot = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(orbiterX, orbiterY), 3, orbiterDot);

    // Cardinal coordinate tick marks
    final tickPaint = Paint()
      ..color = isDark
          ? AppColors.electricLavender.withValues(alpha: 0.5)
          : AppColors.primaryViolet.withValues(alpha: 0.4)
      ..strokeWidth = 1.5;

    for (int i = 0; i < 4; i++) {
      final angle = i * (math.pi / 2);
      final r1 = outerRadius - 3;
      final r2 = outerRadius + 3;
      canvas.drawLine(
        Offset(r1 * math.cos(angle), r1 * math.sin(angle)),
        Offset(r2 * math.cos(angle), r2 * math.sin(angle)),
        tickPaint,
      );
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _OrbTelemetryPainter oldDelegate) {
    return oldDelegate.rotationAngle != rotationAngle ||
        oldDelegate.hasActiveJourney != hasActiveJourney ||
        oldDelegate.progressPercent != progressPercent ||
        oldDelegate.isDark != isDark;
  }
}

/// Custom painter for tactical background HUD lines and corner crosshairs
class _TacticalGridPainter extends CustomPainter {
  final bool isDark;
  final bool isActive;

  _TacticalGridPainter({
    required this.isDark,
    required this.isActive,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = isDark
          ? (isActive ? AppColors.primaryViolet.withValues(alpha: 0.08) : Colors.white.withValues(alpha: 0.025))
          : (isActive ? AppColors.primaryViolet.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.02))
      ..strokeWidth = 1.0;

    // Subtle corner tactical crosshairs
    const crossSize = 8.0;
    const padding = 14.0;

    // Top-left crosshair
    canvas.drawLine(
      const Offset(padding, padding + crossSize / 2),
      const Offset(padding + crossSize, padding + crossSize / 2),
      linePaint,
    );
    canvas.drawLine(
      const Offset(padding + crossSize / 2, padding),
      const Offset(padding + crossSize / 2, padding + crossSize),
      linePaint,
    );

    // Top-right crosshair
    canvas.drawLine(
      Offset(size.width - padding - crossSize, padding + crossSize / 2),
      Offset(size.width - padding, padding + crossSize / 2),
      linePaint,
    );
    canvas.drawLine(
      Offset(size.width - padding - crossSize / 2, padding),
      Offset(size.width - padding - crossSize / 2, padding + crossSize),
      linePaint,
    );

    // Bottom-left crosshair
    canvas.drawLine(
      Offset(padding, size.height - padding - crossSize / 2),
      Offset(padding + crossSize, size.height - padding - crossSize / 2),
      linePaint,
    );
    canvas.drawLine(
      Offset(padding + crossSize / 2, size.height - padding - crossSize),
      Offset(padding + crossSize / 2, size.height - padding),
      linePaint,
    );

    // Bottom-right crosshair
    canvas.drawLine(
      Offset(size.width - padding - crossSize, size.height - padding - crossSize / 2),
      Offset(size.width - padding, size.height - padding - crossSize / 2),
      linePaint,
    );
    canvas.drawLine(
      Offset(size.width - padding - crossSize / 2, size.height - padding - crossSize),
      Offset(size.width - padding - crossSize / 2, size.height - padding),
      linePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _TacticalGridPainter oldDelegate) {
    return oldDelegate.isDark != isDark || oldDelegate.isActive != isActive;
  }
}
