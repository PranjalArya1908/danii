import 'dart:async';
import 'package:flutter/material.dart';
import '../components/interactive_map_canvas.dart';
import '../components/swipe_action_control.dart';
import '../models/models.dart';
import '../theme/colors.dart';

class ActiveJourneyScreen extends StatefulWidget {
  final Journey journey;
  final int checkInSecondsRemaining;
  final bool isOnline;
  final bool isCovertActive;
  final LatLngPoint? currentLocation;
  final double currentHeading;
  final double currentSpeedKmh;
  final Function(int deltaMinutes)? onModifyDuration;
  final VoidCallback onManualCheckIn;
  final VoidCallback onTriggerEmergency;
  final VoidCallback onEndJourney;
  final VoidCallback onBack;

  const ActiveJourneyScreen({
    super.key,
    required this.journey,
    required this.checkInSecondsRemaining,
    required this.isOnline,
    required this.isCovertActive,
    this.currentLocation,
    this.currentHeading = 0.0,
    this.currentSpeedKmh = 38.0,
    this.onModifyDuration,
    required this.onManualCheckIn,
    required this.onTriggerEmergency,
    required this.onEndJourney,
    required this.onBack,
  });

  @override
  State<ActiveJourneyScreen> createState() => _ActiveJourneyScreenState();
}

class _ActiveJourneyScreenState extends State<ActiveJourneyScreen> {
  bool _isPressingEmergency = false;
  double _emergencyHoldProgress = 0.0;
  Timer? _holdTimer;

  String get _checkInTimerText {
    final minutes = widget.checkInSecondsRemaining ~/ 60;
    final seconds = widget.checkInSecondsRemaining % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  void _startHoldingEmergency() {
    setState(() {
      _isPressingEmergency = true;
      _emergencyHoldProgress = 0.0;
    });

    final startTime = DateTime.now();
    _holdTimer?.cancel();
    _holdTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (!_isPressingEmergency) {
        timer.cancel();
        return;
      }
      final elapsed = DateTime.now().difference(startTime).inMilliseconds;
      final progress = (elapsed / 2500.0).clamp(0.0, 1.0);
      setState(() {
        _emergencyHoldProgress = progress;
      });
      if (progress >= 1.0) {
        timer.cancel();
        _isPressingEmergency = false;
        widget.onTriggerEmergency();
      }
    });
  }

  void _stopHoldingEmergency() {
    _holdTimer?.cancel();
    setState(() {
      _isPressingEmergency = false;
      _emergencyHoldProgress = 0.0;
    });
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    super.dispose();
  }

  void _showEndConfirmDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('End Protected Journey?', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text(
          'Are you sure you want to end active protection? Your trusted contacts will be notified that your journey has closed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Keep Active'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.safeGreen),
            onPressed: () {
              Navigator.of(ctx).pop();
              widget.onEndJourney();
            },
            child: const Text('Yes, End Journey', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final remainingMins = (widget.journey.estimatedMinutes * (1.0 - widget.journey.progressPercent))
        .toInt()
        .clamp(1, widget.journey.estimatedMinutes);

    final isCheckInUrgent = widget.checkInSecondsRemaining < 120;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: widget.onBack,
        ),
        title: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: widget.isCovertActive
                ? AppColors.safeGreen.withValues(alpha: isDark ? 0.2 : 0.12)
                : AppColors.primaryViolet.withValues(alpha: isDark ? 0.2 : 0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: widget.isCovertActive ? AppColors.safeGreen : AppColors.primaryViolet,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.isCovertActive ? AppColors.safeGreen : AppColors.safeGreenGlow,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                widget.isCovertActive
                    ? 'Covert Guardian Active'
                    : 'Protected Escort Active',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: widget.isCovertActive ? AppColors.safeGreenGlow : AppColors.primaryViolet,
                ),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.stop_circle_outlined, color: AppColors.emergencyRed),
            tooltip: 'End Journey',
            onPressed: () => _showEndConfirmDialog(context),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Live Interactive Map Canvas
              Container(
                height: 220,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isDark ? AppColors.midnightDarkCardBorder : AppColors.lightCardBorder,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  children: [
                    InteractiveMapCanvas(
                      progress: widget.journey.progressPercent,
                      journeyStatus: widget.journey.status,
                      startLabel: widget.journey.startAddress,
                      destinationLabel: widget.journey.destinationAddress,
                      speedKmh: widget.currentSpeedKmh.toInt(),
                      isOffline: !widget.isOnline,
                      height: 220,
                    ),
                    Positioned(
                      top: 10,
                      left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black87,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Icon(widget.journey.transportMode.icon, size: 14, color: Colors.white),
                            const SizedBox(width: 6),
                            Text(
                              widget.journey.transportMode.label,
                              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                            if (widget.journey.vehicleNumber.isNotEmpty) ...[
                              const SizedBox(width: 6),
                              Text('• ${widget.journey.vehicleNumber}',
                                  style: const TextStyle(color: Colors.white70, fontSize: 11)),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // 2. Check-In Timer Card with Urgent Pulsing
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      (isCheckInUrgent ? AppColors.warningAmber : AppColors.primaryViolet)
                          .withValues(alpha: isDark ? 0.25 : 0.12),
                      (isDark ? AppColors.midnightDarkSurface : AppColors.lightSurface),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: (isCheckInUrgent ? AppColors.warningAmber : AppColors.primaryViolet)
                        .withValues(alpha: 0.5),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: (isCheckInUrgent ? AppColors.warningAmber : AppColors.primaryViolet)
                                .withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isCheckInUrgent ? Icons.access_time_filled : Icons.timer_outlined,
                            color: isCheckInUrgent ? AppColors.warningAmber : AppColors.primaryViolet,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isCheckInUrgent ? 'CHECK-IN DUE SOON' : 'NEXT SAFETY CHECK-IN',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                                color: isCheckInUrgent ? AppColors.warningAmber : AppColors.primaryViolet,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _checkInTimerText,
                              style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    ElevatedButton.icon(
                      onPressed: widget.onManualCheckIn,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isCheckInUrgent ? AppColors.warningAmber : AppColors.primaryViolet,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                      icon: const Icon(Icons.check_circle_outline, size: 18),
                      label: const Text('Check In', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // 3. Modify Duration / Transit Delay Extension
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.midnightDarkSurface : AppColors.lightSurface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isDark ? AppColors.midnightDarkCardBorder : AppColors.lightCardBorder,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Encountered Traffic / Delay?', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        Text('Extend ETA: ~$remainingMins min left',
                            style: TextStyle(fontSize: 11, color: isDark ? AppColors.textSecondary : AppColors.lightTextSecondary)),
                      ],
                    ),
                    Row(
                      children: [5, 10, 15].map((mins) {
                        return Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              visualDensity: VisualDensity.compact,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: () {
                              if (widget.onModifyDuration != null) {
                                widget.onModifyDuration!(mins);
                              }
                            },
                            child: Text('+$mins m', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // 4. Geofence Corridor & Route Details Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.midnightDarkSurface : AppColors.lightSurface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isDark ? AppColors.midnightDarkCardBorder : AppColors.lightCardBorder,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.security, color: AppColors.safeGreen, size: 18),
                            const SizedBox(width: 8),
                            const Text(
                              'Corridor: Safe & Monitored',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.safeGreen),
                            ),
                          ],
                        ),
                        Text(
                          '${(widget.journey.progressPercent * 100).toInt()}% Done',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: isDark ? AppColors.textSecondary : AppColors.lightTextSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    LinearProgressIndicator(
                      value: widget.journey.progressPercent,
                      backgroundColor: isDark ? AppColors.midnightDarkSurfaceVariant : Colors.grey.shade300,
                      valueColor: const AlwaysStoppedAnimation<Color>(AppColors.safeGreen),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Destination',
                                  style: TextStyle(fontSize: 10, color: isDark ? AppColors.textMuted : AppColors.lightTextSecondary)),
                              Text(widget.journey.destinationAddress,
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text('${widget.currentSpeedKmh.toInt()} km/h',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // 5. Emergency SOS Long-Press Trigger (Hold for 3s to activate)
              GestureDetector(
                onTapDown: (_) => _startHoldingEmergency(),
                onTapUp: (_) => _stopHoldingEmergency(),
                onTapCancel: () => _stopHoldingEmergency(),
                child: Container(
                  height: 56,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: AppColors.emergencyRed.withValues(alpha: isDark ? 0.22 : 0.12),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.emergencyRed.withValues(alpha: 0.6), width: 1.5),
                  ),
                  child: Stack(
                    children: [
                      // Fill animation
                      FractionallySizedBox(
                        widthFactor: _emergencyHoldProgress,
                        heightFactor: 1.0,
                        child: Container(color: AppColors.emergencyRed),
                      ),
                      Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.warning_rounded,
                              size: 22,
                              color: _emergencyHoldProgress > 0.3 || isDark ? Colors.white : AppColors.emergencyRed,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              _isPressingEmergency
                                  ? 'HOLD FOR SOS (${(_emergencyHoldProgress * 100).toInt()}%)'
                                  : 'HOLD 3s FOR EMERGENCY SOS',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                                letterSpacing: 0.5,
                                color: _emergencyHoldProgress > 0.3 || isDark ? Colors.white : AppColors.emergencyRed,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 6. Swipe Action to End Journey
              SwipeActionControl(
                label: 'Swipe to End Protected Journey',
                icon: Icons.check,
                sliderColor: AppColors.safeGreen,
                onConfirmed: () => _showEndConfirmDialog(context),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
