import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;

import '../models/models.dart';
import '../services/routing_service.dart';
import '../theme/app_colors.dart';
import '../widgets/swipe_action_control.dart';

enum ActiveMapLayer { streets, satellite }

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
    this.currentSpeedKmh = 0.0,
    this.onModifyDuration,
    required this.onManualCheckIn,
    required this.onTriggerEmergency,
    required this.onEndJourney,
    required this.onBack,
  });

  @override
  State<ActiveJourneyScreen> createState() => _ActiveJourneyScreenState();
}

class _ActiveJourneyScreenState extends State<ActiveJourneyScreen>
    with TickerProviderStateMixin {
  // Map Controller & State
  final MapController _mapController = MapController();
  ActiveMapLayer _mapLayer = ActiveMapLayer.streets;
  bool _autoFollow = true;

  // Animation Controllers
  late final AnimationController _sosPulseController;
  late final AnimationController _mapRadarController;
  Timer? _holdTimer;
  double _holdProgress = 0.0;
  bool _isHolding = false;

  // Journey Ticker & Reverse Countdown
  Timer? _journeyTicker;
  late int _remainingJourneySeconds;
  double _liveSpeedKmh = 0.0;

  // Real Route Coordinates & Vehicle Position
  List<LatLng> _routePoints = [];
  LatLng _vehiclePosition = const LatLng(28.6315, 77.2167);
  double _vehicleHeading = 0.0;
  double _totalRouteDistanceKm = 0.0;

  // Real Ground Track Breadcrumbs & Dynamic Rerouting
  final List<LatLng> _traversedBreadcrumbs = [];
  bool _isRerouting = false;
  int _lastRerouteMillis = 0;

  // Previous GPS for speed calculation
  LatLng? _prevGpsPosition;
  DateTime _prevGpsTime = DateTime.now();

  @override
  void initState() {
    super.initState();

    // 1. Calculate remaining seconds for the reverse countdown
    _initRemainingTime();

    // 2. Initialize route coordinates from waypoints or catalog
    _initRoutePoints();

    // 3. SOS Button Pulsing Glow Animation
    _sosPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);

    // 4. Vehicle Radar Pulse on Live Map
    _mapRadarController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();

    // 5. 1-second ticker for reverse countdown, speed drift, & vehicle movement
    _startTicker();
  }

  void _initRemainingTime() {
    final totalDurationSecs = widget.journey.estimatedMinutes * 60;
    final now = DateTime.now().millisecondsSinceEpoch;
    final elapsedSecs = math.max(
      0,
      (now - widget.journey.startTimeMillis) ~/ 1000,
    );
    _remainingJourneySeconds = math.max(15, totalDurationSecs - elapsedSecs);
  }

  void _initRoutePoints() {
    if (widget.journey.waypoints.isNotEmpty &&
        widget.journey.waypoints.length >= 2) {
      // Use exact route waypoints passed from the previous journey setup screen
      _routePoints = widget.journey.waypoints
          .map((p) => LatLng(p.latitude, p.longitude))
          .toList();
    } else {
      // Resolve start and destination coordinates from search catalog or defaults
      final start = _resolveCoordinate(
        widget.journey.startAddress,
        widget.currentLocation != null
            ? LatLng(
                widget.currentLocation!.latitude,
                widget.currentLocation!.longitude,
              )
            : const LatLng(28.6315, 77.2167), // Connaught Place
      );

      final dest = _resolveCoordinate(
        widget.journey.destinationAddress,
        const LatLng(28.5535, 77.1944), // Hauz Khas Village
      );

      _routePoints = [start, dest];
      _fetchRealRoadRoute(start, dest);
    }

    _totalRouteDistanceKm = _calculatePolylineDistance(_routePoints);

    // Initialize vehicle position from real GPS if available, otherwise route start
    if (widget.currentLocation != null) {
      _vehiclePosition = LatLng(
        widget.currentLocation!.latitude,
        widget.currentLocation!.longitude,
      );
      _prevGpsPosition = _vehiclePosition;
      _prevGpsTime = DateTime.now();
      _traversedBreadcrumbs.add(_vehiclePosition);
    } else if (_routePoints.isNotEmpty) {
      _vehiclePosition = _routePoints.first;
      _traversedBreadcrumbs.add(_vehiclePosition);
    }

    if (widget.currentHeading > 0) {
      _vehicleHeading = widget.currentHeading;
    }
  }

  Future<void> _fetchRealRoadRoute(LatLng start, LatLng dest) async {
    try {
      final road = await RoutingService().calculateRoadRoute(
        start: start,
        destination: dest,
        mode: widget.journey.transportMode,
      );
      if (mounted && road.polylinePoints.isNotEmpty) {
        setState(() {
          _routePoints = road.polylinePoints;
          _totalRouteDistanceKm = road.distanceKm;
        });
      }
    } catch (_) {}
  }

  LatLng _resolveCoordinate(String query, LatLng fallback) {
    final clean = query.trim().toLowerCase();
    for (final preset in RoutingService.searchCatalog) {
      final t = preset.title.toLowerCase();
      final s = preset.subtitle.toLowerCase();
      if (t == clean ||
          clean.contains(t) ||
          t.contains(clean) ||
          s.contains(clean)) {
        return LatLng(preset.latitude, preset.longitude);
      }
    }
    return fallback;
  }

  double _calculatePolylineDistance(List<LatLng> points) {
    if (points.length < 2) return 5.0;
    const distanceCalc = Distance();
    double total = 0.0;
    for (int i = 0; i < points.length - 1; i++) {
      total += distanceCalc.as(LengthUnit.Kilometer, points[i], points[i + 1]);
    }
    return double.parse(total.toStringAsFixed(1));
  }

  void _startTicker() {
    _journeyTicker?.cancel();
    _journeyTicker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        // Decrement reverse countdown timer
        if (_remainingJourneySeconds > 0) {
          _remainingJourneySeconds--;
        }
      });
    });
  }

  /// Handles real live location updates: computes real speed, bearing of motion,
  /// adds breadcrumbs, and updates the route in the route direction.
  void _onLiveLocationUpdate(LatLng newGps) {
    final now = DateTime.now();
    double computedSpeed = 0.0;

    if (_prevGpsPosition != null) {
      final dtSeconds = now.difference(_prevGpsTime).inMilliseconds / 1000.0;
      if (dtSeconds > 0.3) {
        const distCalc = Distance();
        final distMeters = distCalc.as(LengthUnit.Meter, _prevGpsPosition!, newGps);
        if (distMeters >= 1.5) {
          computedSpeed = (distMeters / dtSeconds) * 3.6;
          _vehicleHeading = _calculateBearing(_prevGpsPosition!, newGps);
        }
      }
    }

    if (widget.currentSpeedKmh > 0) {
      _liveSpeedKmh = widget.currentSpeedKmh;
    } else {
      _liveSpeedKmh = computedSpeed.clamp(0.0, 160.0);
    }

    if (widget.currentHeading > 0) {
      _vehicleHeading = widget.currentHeading;
    }

    _prevGpsPosition = newGps;
    _prevGpsTime = now;
    _vehiclePosition = newGps;

    // Record breadcrumb trail if moved >= 3 meters
    if (_traversedBreadcrumbs.isEmpty) {
      _traversedBreadcrumbs.add(newGps);
    } else {
      const distCalc = Distance();
      final lastDist = distCalc.as(LengthUnit.Meter, _traversedBreadcrumbs.last, newGps);
      if (lastDist >= 3.0) {
        _traversedBreadcrumbs.add(newGps);
      }
    }

    // Dynamic Route Direction Update: reroute if moving in an updated route direction
    _maybeUpdateRouteDirection(newGps);

    if (_autoFollow) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _autoFollow) {
          double zoom = 14.5;
          try {
            zoom = _mapController.camera.zoom;
          } catch (_) {}
          try {
            _mapController.move(_vehiclePosition, zoom);
          } catch (_) {}
        }
      });
    }
  }

  /// Checks if the vehicle has deviated or changed route direction, and updates the route ahead.
  void _maybeUpdateRouteDirection(LatLng newGps) {
    if (_routePoints.length < 2 || _isRerouting) return;

    final closest = _findClosestSegment(newGps);
    final nowMillis = DateTime.now().millisecondsSinceEpoch;

    // If deviated > 80m from corridor, recalculate real road path ahead from live location
    if (closest.distanceMeters > 80.0 && (nowMillis - _lastRerouteMillis > 15000)) {
      _lastRerouteMillis = nowMillis;
      _rerouteFromLiveLocation(newGps);
    }
  }

  Future<void> _rerouteFromLiveLocation(LatLng currentGps) async {
    if (_routePoints.isEmpty) return;
    final dest = _routePoints.last;
    _isRerouting = true;

    try {
      final road = await RoutingService().calculateRoadRoute(
        start: currentGps,
        destination: dest,
        mode: widget.journey.transportMode,
      );

      if (mounted && road.polylinePoints.isNotEmpty) {
        setState(() {
          final covered = _coveredRoutePoints;
          _routePoints = [...covered, ...road.polylinePoints];
          _totalRouteDistanceKm = _calculatePolylineDistance(_routePoints);
        });
      }
    } catch (_) {
    } finally {
      if (mounted) {
        setState(() => _isRerouting = false);
      }
    }
  }

  ({int segmentIndex, double distanceMeters}) _findClosestSegment(LatLng pos) {
    if (_routePoints.length < 2) {
      return (segmentIndex: 0, distanceMeters: 0.0);
    }

    const distCalc = Distance();
    double minMeters = double.infinity;
    int bestIndex = 0;

    for (int i = 0; i < _routePoints.length - 1; i++) {
      final a = _routePoints[i];
      final b = _routePoints[i + 1];

      final dx = b.latitude - a.latitude;
      final dy = b.longitude - a.longitude;
      final segLenSq = dx * dx + dy * dy;

      double t = 0.0;
      if (segLenSq > 0) {
        t = ((pos.latitude - a.latitude) * dx + (pos.longitude - a.longitude) * dy) / segLenSq;
        t = t.clamp(0.0, 1.0);
      }

      final proj = LatLng(a.latitude + t * dx, a.longitude + t * dy);
      final distMeters = distCalc.as(LengthUnit.Meter, pos, proj);

      if (distMeters < minMeters) {
        minMeters = distMeters;
        bestIndex = i;
      }
    }

    return (segmentIndex: bestIndex, distanceMeters: minMeters);
  }

  double _calculateBearing(LatLng from, LatLng to) {
    final dLon = (to.longitude - from.longitude) * math.pi / 180.0;
    final lat1 = from.latitude * math.pi / 180.0;
    final lat2 = to.latitude * math.pi / 180.0;
    final y = math.sin(dLon) * math.cos(lat2);
    final x =
        math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
    return (math.atan2(y, x) * 180.0 / math.pi + 360.0) % 360.0;
  }

  List<LatLng> get _coveredRoutePoints {
    if (_routePoints.isEmpty) return const [];
    if (_routePoints.length == 1) return [_routePoints.first];

    if (_traversedBreadcrumbs.length >= 2) {
      return [..._traversedBreadcrumbs, _vehiclePosition];
    }

    final closest = _findClosestSegment(_vehiclePosition);
    final points = <LatLng>[];
    for (int i = 0; i <= closest.segmentIndex && i < _routePoints.length; i++) {
      points.add(_routePoints[i]);
    }
    points.add(_vehiclePosition);
    return points;
  }

  List<LatLng> get _remainingRoutePoints {
    if (_routePoints.isEmpty) return const [];
    if (_routePoints.length == 1) return [_routePoints.first];

    final closest = _findClosestSegment(_vehiclePosition);
    final points = <LatLng>[_vehiclePosition];
    for (int i = closest.segmentIndex + 1; i < _routePoints.length; i++) {
      points.add(_routePoints[i]);
    }
    return points;
  }

  @override
  void didUpdateWidget(ActiveJourneyScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.journey.estimatedMinutes != widget.journey.estimatedMinutes) {
      final delta =
          widget.journey.estimatedMinutes - oldWidget.journey.estimatedMinutes;
      setState(() {
        _remainingJourneySeconds = math.max(
          10,
          _remainingJourneySeconds + (delta * 60),
        );
      });
    }

    // Check if journey waypoints updated from previous screen
    if (widget.journey.waypoints != oldWidget.journey.waypoints &&
        widget.journey.waypoints.length >= 2) {
      setState(() {
        _routePoints = widget.journey.waypoints
            .map((p) => LatLng(p.latitude, p.longitude))
            .toList();
        _totalRouteDistanceKm = _calculatePolylineDistance(_routePoints);
      });
    }

    // React to real GPS location updates: snap vehicle marker and update route direction
    if (widget.currentLocation != null) {
      final newGps = LatLng(
        widget.currentLocation!.latitude,
        widget.currentLocation!.longitude,
      );
      if (newGps != _vehiclePosition) {
        setState(() {
          _onLiveLocationUpdate(newGps);
        });
      }
    }

    if (widget.currentSpeedKmh > 0 && widget.currentSpeedKmh != _liveSpeedKmh) {
      setState(() {
        _liveSpeedKmh = widget.currentSpeedKmh;
      });
    }

    if (widget.currentHeading > 0 && widget.currentHeading != _vehicleHeading) {
      setState(() {
        _vehicleHeading = widget.currentHeading;
      });
    }
  }

  @override
  void dispose() {
    _journeyTicker?.cancel();
    _holdTimer?.cancel();
    _sosPulseController.dispose();
    _mapRadarController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Modify Protection Duration
  // ---------------------------------------------------------------------------
  void _modifyDuration(int deltaMinutes) {
    setState(() {
      _remainingJourneySeconds = math.max(
        30,
        _remainingJourneySeconds + (deltaMinutes * 60),
      );
    });

    widget.onModifyDuration?.call(deltaMinutes);

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.timer_outlined, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Protection time ${deltaMinutes >= 0 ? "+$deltaMinutes" : "$deltaMinutes"} min updated (${widget.journey.estimatedMinutes + deltaMinutes}m total)',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.primaryViolet,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showCustomDurationSheet(bool isDark) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.midnightDarkSurface
                : AppColors.lightSurface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(
              color: isDark
                  ? AppColors.midnightDarkCardBorder
                  : AppColors.lightCardBorder,
            ),
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.more_time_rounded,
                            color: AppColors.primaryViolet,
                            size: 22,
                          ),
                          SizedBox(width: 10),
                          Text(
                            'Modify Protection Window',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Select an adjustment preset below if you encounter traffic, detours, or stops.',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? AppColors.textSecondary
                          : AppColors.lightTextSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildModifyTile(ctx, isDark, '+5 min', 'Short Stop', 5),
                      _buildModifyTile(ctx, isDark, '+10 min', 'Moderate Traffic', 10),
                      _buildModifyTile(ctx, isDark, '+15 min', 'Heavy Congestion', 15),
                      _buildModifyTile(ctx, isDark, '+30 min', 'Major Detour', 30),
                      _buildModifyTile(ctx, isDark, '-5 min', 'Arriving Faster', -5),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildModifyTile(
    BuildContext ctx,
    bool isDark,
    String label,
    String reason,
    int delta,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.pop(ctx);
          _modifyDuration(delta);
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: AppColors.primaryViolet.withValues(alpha: isDark ? 0.18 : 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.primaryViolet.withValues(alpha: isDark ? 0.4 : 0.25),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                delta >= 0
                    ? Icons.add_circle_outline_rounded
                    : Icons.remove_circle_outline_rounded,
                size: 15,
                color: AppColors.primaryViolet,
              ),
              const SizedBox(width: 5),
              Text(
                '$label ',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryViolet,
                ),
              ),
              Text(
                '($reason)',
                style: TextStyle(
                  fontSize: 11,
                  color: isDark
                      ? AppColors.textSecondary
                      : AppColors.lightTextSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Hold SOS Logic with High-Precision 3-Second Countdown
  // ---------------------------------------------------------------------------
  void _startHolding() {
    setState(() {
      _isHolding = true;
      _holdProgress = 0.0;
    });

    const int totalDurationMs = 3000;
    const int stepMs = 40;
    final double increment = stepMs / totalDurationMs;

    _holdTimer?.cancel();
    _holdTimer = Timer.periodic(const Duration(milliseconds: stepMs), (timer) {
      if (mounted) {
        setState(() {
          _holdProgress += increment;
          if (_holdProgress >= 1.0) {
            _holdProgress = 1.0;
            timer.cancel();
            _isHolding = false;
            widget.onTriggerEmergency();
          }
        });
      }
    });
  }

  void _stopHolding() {
    _holdTimer?.cancel();
    if (mounted) {
      setState(() {
        _isHolding = false;
        _holdProgress = 0.0;
      });
    }
  }

  String _formatTimer(int totalSeconds) {
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.midnightDarkBackground
          : AppColors.lightBackground,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: widget.onBack,
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: widget.isCovertActive
                    ? AppColors.safeGreen.withValues(alpha: isDark ? 0.2 : 0.12)
                    : AppColors.primaryViolet.withValues(
                        alpha: isDark ? 0.2 : 0.12,
                      ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: widget.isCovertActive
                      ? AppColors.safeGreen
                      : AppColors.primaryViolet,
                  width: 1.2,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: widget.isCovertActive
                          ? AppColors.safeGreen
                          : AppColors.safeGreenGlow,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 7),
                  Text(
                    widget.isCovertActive
                        ? 'Safe & Monitored'
                        : 'Active Protection',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: widget.isCovertActive
                          ? AppColors.safeGreen
                          : AppColors.primaryViolet,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: const [],
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 6.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Visually Attractive Reverse Countdown Timer Card with Modification Controls
              _buildReverseCountdownCard(isDark),
              const SizedBox(height: 14),

              // 2. Real Live Map Moving on Selected Route
              _buildLiveMapCard(isDark),
              const SizedBox(height: 14),

              // 3. Next Check-In Reminder Card
              _buildCheckInPromptCard(isDark),
              const SizedBox(height: 16),

              // 4. Beautiful & Animated "Hold SOS for 3s to Escalate" Button
              _buildAnimatedSosButton(isDark),
              const SizedBox(height: 18),

              // 5. Swipe to Complete Safe Journey
              SwipeActionControl(
                label: 'Swipe right to confirm safe arrival',
                confirmedLabel: 'SAFE ARRIVAL CONFIRMED',
                sliderColor: AppColors.safeGreen,
                icon: Icons.check_circle_rounded,
                onConfirmed: widget.onEndJourney,
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 1. Visually Attractive Reverse Countdown Timer Card
  // ---------------------------------------------------------------------------
  Widget _buildReverseCountdownCard(bool isDark) {
    final totalDurationSecs = math.max(1, widget.journey.estimatedMinutes * 60);
    final progressFraction = (_remainingJourneySeconds / totalDurationSecs)
        .clamp(0.0, 1.0);
    final distanceLeftKm = math.max(
      0.1,
      _totalRouteDistanceKm * (1.0 - widget.journey.progressPercent),
    );

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppColors.midnightDarkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: AppColors.primaryViolet.withValues(
            alpha: isDark ? 0.35 : 0.22,
          ),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryViolet.withValues(
              alpha: isDark ? 0.08 : 0.04,
            ),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: AppColors.safeGreen,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'JOURNEY PROTECTION REMAINING',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                          color: isDark
                              ? AppColors.textSecondary
                              : AppColors.lightTextSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primaryViolet.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      widget.journey.transportMode.icon,
                      size: 12,
                      color: AppColors.primaryViolet,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      widget.journey.vehicleNumber.isNotEmpty
                          ? widget.journey.vehicleNumber
                          : widget.journey.transportMode.label,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryViolet,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Timer Dial & Trip Summary Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Attractive Circular Radial Countdown Dial
              SizedBox(
                width: 112,
                height: 112,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Background Track
                    SizedBox(
                      width: 104,
                      height: 104,
                      child: CircularProgressIndicator(
                        value: 1.0,
                        strokeWidth: 8,
                        color: (isDark ? Colors.white : Colors.black)
                            .withValues(alpha: 0.06),
                      ),
                    ),
                    // Animated Remaining Arc
                    SizedBox(
                      width: 104,
                      height: 104,
                      child: CircularProgressIndicator(
                        value: progressFraction,
                        strokeWidth: 8,
                        strokeCap: StrokeCap.round,
                        color: AppColors.primaryViolet,
                      ),
                    ),
                    // Centered Digital Countdown
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.timer_outlined,
                          size: 14,
                          color: AppColors.primaryViolet,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _formatTimer(_remainingJourneySeconds),
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                            color: isDark
                                ? AppColors.textPrimary
                                : AppColors.lightTextPrimary,
                          ),
                        ),
                        Text(
                          '${widget.journey.estimatedMinutes}m total',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? AppColors.textSecondary
                                : AppColors.lightTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),

              // Destination & Metrics Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.location_on_rounded,
                          size: 16,
                          color: AppColors.primaryViolet,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            widget.journey.destinationAddress,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? AppColors.textPrimary
                                  : AppColors.lightTextPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Progress Bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: widget.journey.progressPercent,
                        minHeight: 6,
                        backgroundColor: (isDark ? Colors.white : Colors.black)
                            .withValues(alpha: 0.08),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          AppColors.primaryViolet,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${(widget.journey.progressPercent * 100).toInt()}% completed',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? AppColors.textSecondary
                                : AppColors.lightTextSecondary,
                          ),
                        ),
                        Text(
                          '${distanceLeftKm.toStringAsFixed(1)} km left',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryViolet,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Quick Time Modification Controls Row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.midnightDarkBackground.withValues(alpha: 0.5)
                  : AppColors.lightBackground,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark
                    ? AppColors.midnightDarkCardBorder
                    : AppColors.lightCardBorder,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.edit_calendar_outlined,
                  size: 14,
                  color: isDark
                      ? AppColors.textSecondary
                      : AppColors.lightTextSecondary,
                ),
                const SizedBox(width: 6),
                Text(
                  'Extend Trip:',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? AppColors.textSecondary
                        : AppColors.lightTextSecondary,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildQuickDurationButton('+5m', 5),
                        const SizedBox(width: 6),
                        _buildQuickDurationButton('+10m', 10),
                        const SizedBox(width: 6),
                        _buildQuickDurationButton('+15m', 15),
                        const SizedBox(width: 6),
                        _buildQuickDurationButton('-5m', -5),
                        const SizedBox(width: 6),
                        InkWell(
                          onTap: () => _showCustomDurationSheet(isDark),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primaryViolet.withValues(
                                alpha: 0.15,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              children: [
                                Icon(
                                  Icons.tune_rounded,
                                  size: 12,
                                  color: AppColors.primaryViolet,
                                ),
                                SizedBox(width: 3),
                                Text(
                                  'More',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primaryViolet,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickDurationButton(String label, int delta) {
    return InkWell(
      onTap: () => _modifyDuration(delta),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.primaryViolet.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: AppColors.primaryViolet.withValues(alpha: 0.3),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: AppColors.primaryViolet,
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 2. Real Live Map Moving on Selected Route
  // ---------------------------------------------------------------------------
  Widget _buildLiveMapCard(bool isDark) {
    return Container(
      width: double.infinity,
      height: 270,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0C1024) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: AppColors.primaryViolet.withValues(alpha: isDark ? 0.35 : 0.2),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          // FlutterMap Real Interactive Map
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _vehiclePosition,
              initialZoom: 14.5,
              minZoom: 4.0,
              maxZoom: 19.0,
              onPositionChanged: (pos, hasGesture) {
                if (hasGesture && _autoFollow) {
                  setState(() => _autoFollow = false);
                }
              },
            ),
            children: [
              // Tile Layer
              TileLayer(
                urlTemplate: _mapLayer == ActiveMapLayer.satellite
                    ? 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}.jpg'
                    : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.shemove.app',
                maxZoom: 19,
              ),

              if (_mapLayer == ActiveMapLayer.satellite)
                TileLayer(
                  urlTemplate: 'https://server.arcgisonline.com/ArcGIS/rest/services/Reference/World_Boundaries_and_Places/MapServer/tile/{z}/{y}/{x}.png',
                  userAgentPackageName: 'com.shemove.app',
                  maxZoom: 19,
                ),

              // Route Polylines: Corridor, Remaining Ahead Path, and LIVE COVERED TRAIL
              if (_routePoints.length >= 2) ...[
                // 1. Outer corridor protective halo (entire route)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _routePoints,
                      strokeWidth: 13.0,
                      color: AppColors.primaryViolet.withValues(alpha: 0.14),
                    ),
                  ],
                ),

                // 2. Remaining path ahead (to destination)
                if (_remainingRoutePoints.length >= 2)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: _remainingRoutePoints,
                        strokeWidth: 4.5,
                        color: (isDark ? Colors.white : Colors.black)
                            .withValues(alpha: 0.25),
                        strokeCap: StrokeCap.round,
                      ),
                    ],
                  ),

                // 3. LIVE ROUTE COVERED TILL NOW (Real-time traversed trail)
                if (_coveredRoutePoints.length >= 2) ...[
                  // Traversed green glow
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: _coveredRoutePoints,
                        strokeWidth: 9.0,
                        color: AppColors.safeGreen.withValues(alpha: 0.35),
                        strokeCap: StrokeCap.round,
                      ),
                      // Core live covered route
                      Polyline(
                        points: _coveredRoutePoints,
                        strokeWidth: 5.0,
                        color: AppColors.safeGreen,
                        strokeCap: StrokeCap.round,
                      ),
                    ],
                  ),
                ],
              ],

              // Markers
              MarkerLayer(
                markers: [
                  // Start Pin
                  if (_routePoints.isNotEmpty)
                    Marker(
                      point: _routePoints.first,
                      width: 28,
                      height: 28,
                      child: ExcludeSemantics(
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.safeGreen,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.safeGreen.withValues(alpha: 0.5),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Text(
                              'A',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                  // Destination Pin
                  if (_routePoints.length >= 2)
                    Marker(
                      point: _routePoints.last,
                      width: 32,
                      height: 32,
                      child: ExcludeSemantics(
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.primaryViolet,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primaryViolet.withValues(
                                  alpha: 0.5,
                                ),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.flag_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ),

                  // Real Moving Vehicle Position Marker (Isolated from Semantics & Repaint Boundary)
                  Marker(
                    point: _vehiclePosition,
                    width: 54,
                    height: 54,
                    child: ExcludeSemantics(
                      child: RepaintBoundary(
                        child: AnimatedBuilder(
                          animation: _mapRadarController,
                          builder: (context, _) {
                            final pulseValue = _mapRadarController.value;
                            return Stack(
                              alignment: Alignment.center,
                              children: [
                                // Pulsing radar glow ring (fixed layout size with visual Transform.scale)
                                Transform.scale(
                                  scale: 0.6 + (pulseValue * 0.4),
                                  child: Container(
                                    width: 50,
                                    height: 50,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: AppColors.primaryViolet.withValues(
                                        alpha: (1.0 - pulseValue) * 0.35,
                                      ),
                                    ),
                                  ),
                                ),
                                // Vehicle Marker with Rotation Heading
                                Transform.rotate(
                                  angle: _vehicleHeading * math.pi / 180.0,
                                  child: Container(
                                    width: 34,
                                    height: 34,
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryViolet,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 2.5,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(
                                            alpha: 0.4,
                                          ),
                                          blurRadius: 6,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Icon(
                                      widget.journey.transportMode.icon,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Overlay 1: Live Speedometer HUD (Top Left)
          Positioned(
            top: 12,
            left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xEE0B0F22)
                    : const Color(0xEEFFFFFF),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark
                      ? const Color(0x338B5CF6)
                      : const Color(0x22000000),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 6,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.speed_rounded,
                    size: 16,
                    color: AppColors.primaryViolet,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${_liveSpeedKmh.toStringAsFixed(0)} KM/H',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.4,
                      color: isDark
                          ? AppColors.textPrimary
                          : AppColors.lightTextPrimary,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: AppColors.safeGreen,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Overlay 2: Map Controls (Top Right: Layer switch & Auto-follow)
          Positioned(
            top: 12,
            right: 12,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Re-center / Auto-follow toggle
                InkWell(
                  onTap: () {
                    setState(() => _autoFollow = !_autoFollow);
                    if (_autoFollow) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted && _autoFollow) {
                          try {
                            _mapController.move(_vehiclePosition, 14.5);
                          } catch (_) {}
                        }
                      });
                    }
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: _autoFollow
                          ? AppColors.primaryViolet
                          : (isDark
                                ? const Color(0xEE0B0F22)
                                : const Color(0xEEFFFFFF)),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _autoFollow
                            ? AppColors.primaryViolet
                            : (isDark
                                  ? const Color(0x338B5CF6)
                                  : const Color(0x22000000)),
                      ),
                    ),
                    child: Icon(
                      Icons.my_location_rounded,
                      size: 16,
                      color: _autoFollow
                          ? Colors.white
                          : (isDark
                                ? AppColors.textPrimary
                                : AppColors.lightTextPrimary),
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Map layer switcher (Streets / Satellite)
                InkWell(
                  onTap: () {
                    setState(() {
                      _mapLayer = _mapLayer == ActiveMapLayer.streets
                          ? ActiveMapLayer.satellite
                          : ActiveMapLayer.streets;
                    });
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xEE0B0F22)
                          : const Color(0xEEFFFFFF),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isDark
                            ? const Color(0x338B5CF6)
                            : const Color(0x22000000),
                      ),
                    ),
                    child: Icon(
                      _mapLayer == ActiveMapLayer.satellite
                          ? Icons.layers_clear_rounded
                          : Icons.layers_rounded,
                      size: 16,
                      color: isDark
                          ? AppColors.textPrimary
                          : AppColors.lightTextPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Overlay 3: Live Real-Time Route Progress HUD (Bottom)
          Positioned(
            bottom: 12,
            left: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xEE0B0F22) : const Color(0xEEFFFFFF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? const Color(0x338B5CF6) : const Color(0x22000000),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 6,
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: AppColors.safeGreen,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Live Covered: ${(_totalRouteDistanceKm * widget.journey.progressPercent).toStringAsFixed(1)} km',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppColors.textPrimary : AppColors.lightTextPrimary,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    height: 12,
                    width: 1,
                    color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.2),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: AppColors.primaryViolet,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Ahead: ${math.max(0.1, _totalRouteDistanceKm * (1.0 - widget.journey.progressPercent)).toStringAsFixed(1)} km',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppColors.textPrimary : AppColors.lightTextPrimary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 3. Next Check-In Reminder Card
  // ---------------------------------------------------------------------------
  Widget _buildCheckInPromptCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.midnightDarkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark
              ? AppColors.midnightDarkCardBorder
              : AppColors.lightCardBorder,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.safeGreen.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.timer_outlined,
                  color: AppColors.safeGreen,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Next Adaptive Check-In',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark
                          ? AppColors.textSecondary
                          : AppColors.lightTextSecondary,
                    ),
                  ),
                  Text(
                    _formatTimer(widget.checkInSecondsRemaining),
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                      color: isDark
                          ? AppColors.textPrimary
                          : AppColors.lightTextPrimary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          FilledButton.tonal(
            onPressed: widget.onManualCheckIn,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primaryViolet.withValues(alpha: 0.15),
              foregroundColor: AppColors.primaryViolet,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle_outline_rounded, size: 15),
                SizedBox(width: 6),
                Text(
                  'Check In Now',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 4. Beautiful & Animated "Hold SOS for 3s to Escalate" Button
  // ---------------------------------------------------------------------------
  Widget _buildAnimatedSosButton(bool isDark) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _sosPulseController,
        builder: (context, _) {
        final pulseGlow = _sosPulseController.value * 0.25;

        return GestureDetector(
          onTapDown: (_) => _startHolding(),
          onTapUp: (_) => _stopHolding(),
          onTapCancel: () => _stopHolding(),
          child: Container(
            width: double.infinity,
            height: 70,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xFF28070B), const Color(0xFF160205)]
                    : [const Color(0xFFFFF1F2), const Color(0xFFFFE4E6)],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.emergencyRed.withValues(
                  alpha: _isHolding ? 1.0 : 0.75,
                ),
                width: _isHolding ? 2.0 : 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.emergencyRed.withValues(
                    alpha: _isHolding ? 0.45 : pulseGlow,
                  ),
                  blurRadius: _isHolding ? 24 : 12,
                  spreadRadius: _isHolding ? 2 : 0,
                ),
              ],
            ),
            child: Stack(
              children: [
                // Animated Progress Fill on Hold
                if (_isHolding)
                  FractionallySizedBox(
                    widthFactor: _holdProgress,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFDC2626), Color(0xFFEF4444)],
                        ),
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                  ),

                // Content
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.emergencyRed.withValues(
                                  alpha: _isHolding ? 0.35 : 0.18,
                                ),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.warning_amber_rounded,
                                color: _isHolding
                                    ? Colors.white
                                    : AppColors.emergencyRed,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _isHolding
                                        ? 'HOLDING SOS (${(_holdProgress * 100).toInt()}%)'
                                        : 'HOLD SOS FOR 3s TO ESCALATE',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: _isHolding
                                          ? Colors.white
                                          : AppColors.emergencyRed,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _isHolding
                                        ? 'Escalating in ${(3.0 - (_holdProgress * 3.0)).clamp(0.1, 3.0).toStringAsFixed(1)}s...'
                                        : 'Instant priority alert to guardians & police',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: _isHolding
                                          ? Colors.white
                                          : (isDark
                                                ? AppColors.textSecondary
                                                : AppColors.lightTextSecondary),
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Countdown Indicator Ring on Right
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _isHolding
                              ? Colors.white.withValues(alpha: 0.2)
                              : AppColors.emergencyRed.withValues(alpha: 0.12),
                        ),
                        child: Center(
                          child: Text(
                            _isHolding
                                ? '${(3.0 - (_holdProgress * 3.0)).ceil()}s'
                                : '3s',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: _isHolding
                                  ? Colors.white
                                  : AppColors.emergencyRed,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}
}
