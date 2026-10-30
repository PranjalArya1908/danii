import 'package:flutter/material.dart';
import '../models/models.dart';
import '../theme/app_colors.dart';

class InteractiveMapCanvas extends StatefulWidget {
  final double progress;
  final JourneyStatus journeyStatus;
  final String startLabel;
  final String destinationLabel;
  final int speedKmh;
  final bool isOffline;
  final bool isReplay;
  final double height;

  const InteractiveMapCanvas({
    super.key,
    this.progress = 0.35,
    this.journeyStatus = JourneyStatus.active,
    this.startLabel = 'Connaught Place',
    this.destinationLabel = 'Hauz Khas Village',
    this.speedKmh = 36,
    this.isOffline = false,
    this.isReplay = false,
    this.height = 180,
  });

  @override
  State<InteractiveMapCanvas> createState() => _InteractiveMapCanvasState();
}

class _InteractiveMapCanvasState extends State<InteractiveMapCanvas>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final beaconColor = switch (widget.journeyStatus) {
      JourneyStatus.emergency || JourneyStatus.escalating => AppColors.emergencyRed,
      JourneyStatus.checkInDue => AppColors.warningAmber,
      JourneyStatus.covertDuress => AppColors.safeGreen, // Discreetly looks safe
      JourneyStatus.completed => AppColors.safeGreen,
      _ => isDark ? AppColors.electricLavender : AppColors.primaryViolet,
    };

    final mapBgColor = isDark ? const Color(0xFF0B1026) : const Color(0xFFF1F5F9);

    return Container(
      width: double.infinity,
      height: widget.height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: mapBgColor,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Stack(
        children: [
          // Map canvas background & route
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _pulseController,
              builder: (context, _) {
                return CustomPaint(
                  painter: _MapCanvasPainter(
                    progress: widget.progress,
                    isDark: isDark,
                    beaconColor: beaconColor,
                    pulseValue: _pulseController.value,
                  ),
                );
              },
            ),
          ),

          // Top Status Overlay Bar
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xDD0D132D) : const Color(0xEEFFFFFF),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? const Color(0x338B5CF6) : const Color(0x22000000),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: widget.isOffline ? AppColors.warningAmber : AppColors.safeGreen,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        widget.isOffline
                            ? 'Mesh SMS Fallback'
                            : widget.isReplay
                                ? 'Route History Replay'
                                : 'SheMove Live GPS',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xDD0D132D) : const Color(0xEEFFFFFF),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? const Color(0x22FFFFFF) : const Color(0x22000000),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.speed,
                        size: 14,
                        color: isDark ? AppColors.electricLavender : AppColors.primaryViolet,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${widget.speedKmh} km/h',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppColors.textPrimary : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Bottom label overlay
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: isDark
                      ? [Colors.transparent, const Color(0xEE0B1026)]
                      : [Colors.transparent, const Color(0xEEF1F5F9)],
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                            color: AppColors.infoBlue,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            widget.startLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: isDark ? AppColors.textSecondary : AppColors.lightTextSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6.0),
                    child: Icon(Icons.arrow_forward, size: 12, color: Colors.grey),
                  ),
                  Expanded(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                            color: AppColors.safeGreen,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            widget.destinationLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.end,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: isDark ? AppColors.textSecondary : AppColors.lightTextSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MapCanvasPainter extends CustomPainter {
  final double progress;
  final bool isDark;
  final Color beaconColor;
  final double pulseValue;

  _MapCanvasPainter({
    required this.progress,
    required this.isDark,
    required this.beaconColor,
    required this.pulseValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final roadColor = isDark ? const Color(0xFF161F42) : const Color(0xFFE2E8F0);
    final majorRoadColor = isDark ? const Color(0xFF222C5A) : const Color(0xFFCBD5E1);
    final uncompletedRouteColor = isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1);

    final roadPaint = Paint()
      ..color = roadColor
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final majorRoadPaint = Paint()
      ..color = majorRoadColor
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke;

    // Horizontal roads
    canvas.drawLine(Offset(0, h * 0.2), Offset(w, h * 0.2), roadPaint);
    canvas.drawLine(Offset(0, h * 0.45), Offset(w, h * 0.45), roadPaint);
    canvas.drawLine(Offset(0, h * 0.7), Offset(w, h * 0.7), majorRoadPaint);
    canvas.drawLine(Offset(0, h * 0.88), Offset(w, h * 0.88), roadPaint..strokeWidth = 2.5);

    // Vertical roads
    canvas.drawLine(Offset(w * 0.22, 0), Offset(w * 0.22, h), roadPaint..strokeWidth = 3);
    canvas.drawLine(Offset(w * 0.5, 0), Offset(w * 0.5, h), majorRoadPaint..strokeWidth = 6);
    canvas.drawLine(Offset(w * 0.78, 0), Offset(w * 0.78, h), roadPaint..strokeWidth = 3);

    // Diagonal avenues
    canvas.drawLine(Offset(0, h * 0.35), Offset(w * 0.8, h), roadPaint..strokeWidth = 4);
    canvas.drawLine(Offset(w * 0.15, 0), Offset(w, h * 0.75), roadPaint..strokeWidth = 3.5);

    // City blocks highlights
    final blockPaint1 = Paint()
      ..color = isDark ? const Color(0x1238BDF8) : const Color(0x180284C7);
    canvas.drawRect(Rect.fromLTWH(w * 0.05, h * 0.05, w * 0.15, h * 0.12), blockPaint1);

    final blockPaint2 = Paint()
      ..color = isDark ? const Color(0x108B5CF6) : const Color(0x187C3AED);
    canvas.drawRect(Rect.fromLTWH(w * 0.55, h * 0.25, w * 0.2, h * 0.16), blockPaint2);

    final blockPaint3 = Paint()
      ..color = isDark ? const Color(0x1010B981) : const Color(0x1810B981);
    canvas.drawRect(Rect.fromLTWH(w * 0.26, h * 0.52, w * 0.2, h * 0.14), blockPaint3);

    // Route curve points
    final startPoint = Offset(w * 0.18, h * 0.82);
    final cp1 = Offset(w * 0.35, h * 0.65);
    final cp2 = Offset(w * 0.5, h * 0.35);
    final endPoint = Offset(w * 0.85, h * 0.18);

    final fullRoutePath = Path()
      ..moveTo(startPoint.dx, startPoint.dy)
      ..cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, endPoint.dx, endPoint.dy);

    // Background route path
    final uncompletedPaint = Paint()
      ..color = uncompletedRouteColor
      ..strokeWidth = 7
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(fullRoutePath, uncompletedPaint);

    // Active route path with gradient
    final gradientShader = LinearGradient(
      colors: [AppColors.infoBlue, AppColors.primaryViolet, beaconColor],
      begin: Alignment.bottomLeft,
      end: Alignment.topRight,
    ).createShader(Rect.fromPoints(startPoint, endPoint));

    // Active route subpath up to progress using PathMetrics
    final pathMetrics = fullRoutePath.computeMetrics().toList();
    Offset userPos = startPoint;
    if (pathMetrics.isNotEmpty) {
      final metric = pathMetrics.first;
      final clampedProgress = progress.clamp(0.0, 1.0);
      final coveredLength = metric.length * clampedProgress;

      if (coveredLength > 0.5) {
        final activeSubpath = metric.extractPath(0.0, coveredLength);
        final activeRoutePaint = Paint()
          ..shader = gradientShader
          ..strokeWidth = 7
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round;
        canvas.drawPath(activeSubpath, activeRoutePaint);
      }

      final tangent = metric.getTangentForOffset(coveredLength);
      if (tangent != null) {
        userPos = tangent.position;
      }
    }

    // Start point marker (A)
    canvas.drawCircle(startPoint, 8, Paint()..color = AppColors.infoBlue);
    canvas.drawCircle(startPoint, 3.5, Paint()..color = Colors.white);

    // End point marker (B)
    canvas.drawCircle(endPoint, 9, Paint()..color = AppColors.safeGreen);
    canvas.drawCircle(endPoint, 3.5, Paint()..color = Colors.white);

    // Pulsing beacon
    final pulseRadius = 10.0 + (pulseValue * 26.0);
    final pulseAlpha = (1.0 - pulseValue) * 0.8;
    canvas.drawCircle(
      userPos,
      pulseRadius,
      Paint()..color = beaconColor.withValues(alpha: pulseAlpha),
    );
    canvas.drawCircle(userPos, 10, Paint()..color = Colors.white);
    canvas.drawCircle(userPos, 7, Paint()..color = beaconColor);
  }

  @override
  bool shouldRepaint(covariant _MapCanvasPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.pulseValue != pulseValue ||
        oldDelegate.beaconColor != beaconColor ||
        oldDelegate.isDark != isDark;
  }
}
