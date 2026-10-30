import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;
import '../models/models.dart';
import '../services/gemini_service.dart';
import '../services/location_service.dart';
import '../services/routing_service.dart';
import '../theme/app_colors.dart';
import '../widgets/swipe_action_control.dart';

enum MapLayerStyle {
  satellite,
  streets,
}

enum MapPinMode {
  destination,
  start,
}

/// Real-time traffic estimation profile based on time-of-day rush hours
class TrafficEstimation {
  final double congestionMultiplier;
  final String statusLabel;
  final String description;
  final Color badgeColor;
  final IconData icon;

  const TrafficEstimation({
    required this.congestionMultiplier,
    required this.statusLabel,
    required this.description,
    required this.badgeColor,
    required this.icon,
  });
}

/// Dynamic travel duration calculation breakdown
class DynamicTimingPrediction {
  final int totalMinutes;
  final int baseTravelMinutes;
  final int trafficDelayMinutes;
  final double averageSpeedKmh;
  final String modeRationale;
  final TrafficEstimation traffic;

  const DynamicTimingPrediction({
    required this.totalMinutes,
    required this.baseTravelMinutes,
    required this.trafficDelayMinutes,
    required this.averageSpeedKmh,
    required this.modeRationale,
    required this.traffic,
  });
}

/// Dynamic adaptive check-in recommendation based on environmental risk and transit type
class DynamicCheckInRecommendation {
  final int recommendedIntervalMinutes;
  final String safetyTier;
  final String rationale;
  final String crowdContext;
  final Color tierColor;
  final IconData icon;

  const DynamicCheckInRecommendation({
    required this.recommendedIntervalMinutes,
    required this.safetyTier,
    required this.rationale,
    required this.crowdContext,
    required this.tierColor,
    required this.icon,
  });
}

class JourneySetupScreen extends StatefulWidget {
  final List<TrustedContact> contacts;
  final String initialStartLocation;
  final LatLngPoint? initialStartPoint;
  final VoidCallback onBack;
  final VoidCallback? onOpenContacts;
  final Function(
    String start,
    String dest,
    TransportMode mode,
    String vehicleNo,
    int durationMinutes,
    int intervalMinutes,
    bool geofence, [
    List<String>? selectedContactIds,
    List<LatLngPoint>? waypoints,
  ]) onStartJourney;

  const JourneySetupScreen({
    super.key,
    required this.contacts,
    this.initialStartLocation = 'Connaught Place, Inner Circle',
    this.initialStartPoint,
    required this.onBack,
    this.onOpenContacts,
    required this.onStartJourney,
  });

  @override
  State<JourneySetupScreen> createState() => _JourneySetupScreenState();
}

class _JourneySetupScreenState extends State<JourneySetupScreen> {
  final LocationService _locationService = LocationService();
  final RoutingService _routingService = RoutingService();
  final MapController _mapController = MapController();

  late TextEditingController _startController;
  late TextEditingController _destController;
  late TextEditingController _vehicleController;

  late Set<String> _selectedContactIds;

  // Real Geo Coordinates for Route
  late LatLng _startCoord;
  late LatLng _destCoord;

  // Route & Navigation State
  bool _hasSelectedDestination = false;
  RoadRouteResult? _roadRoute;
  MetroRouteResult? _metroRoute;
  bool _isCalculatingRoute = false;

  TransportMode _selectedMode = TransportMode.cab;
  int _durationMinutes = 25;
  int _checkInInterval = 10;
  bool _geofenceEnabled = true;
  int _geofenceRadiusMeters = 300; // 150m (Strict), 300m (Standard), 500m (Flexible)

  /// Checks whether a transport mode is logically viable for the given route distance
  bool _isModeViable(TransportMode mode, double distanceKm) {
    switch (mode) {
      case TransportMode.walking:
        return distanceKm <= 12.0; // Logical limit: nobody travels long distance by walking
      case TransportMode.auto:
        return distanceKm <= 45.0; // Auto-rickshaws restricted to municipal/NCR radius
      case TransportMode.metro:
        return distanceKm <= 60.0 && (_metroRoute == null || _metroRoute!.isAvailable);
      case TransportMode.cab:
      case TransportMode.bus:
        return true;
    }
  }

  List<TransportMode> _getViableModes(double distanceKm) {
    return TransportMode.values.where((m) => _isModeViable(m, distanceKm)).toList();
  }

  // Map state
  MapLayerStyle _mapLayerStyle = MapLayerStyle.satellite;
  MapPinMode _pinMode = MapPinMode.destination;
  bool _isLocatingUser = false;
  bool _isReverseGeocoding = false;
  List<SearchLocationPreset> _dynamicSuggestions = [];
  GeminiCheckInPrediction? _geminiPrediction;
  Timer? _searchDebounceTimer;

  @override
  void initState() {
    super.initState();
    _startController = TextEditingController(text: widget.initialStartLocation);
    _destController = TextEditingController(text: '');
    _vehicleController = TextEditingController(text: 'DL 1Y B 4821');
    _selectedContactIds = widget.contacts.map((c) => c.id).toSet();

    if (widget.initialStartPoint != null) {
      _startCoord = LatLng(
        widget.initialStartPoint!.latitude,
        widget.initialStartPoint!.longitude,
      );
    } else {
      _startCoord = const LatLng(28.6315, 77.2167); // Connaught Place default
    }

    _destCoord = const LatLng(28.5535, 77.1944);
    _hasSelectedDestination = false;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateGeminiPrediction();
    });
  }

  /// Predicts adaptive check-in interval and contextual risk analysis using Gemini AI.
  Future<void> _updateGeminiPrediction() async {
    final dist = _getEffectiveRouteDistanceKm();
    final mode = _selectedMode;
    final start = _startController.text;
    final dest = _destController.text;

    try {
      final prediction = await GeminiSafetyService.predictCheckIn(
        mode: mode,
        distanceKm: dist,
        startAddress: start,
        destinationAddress: dest,
      );
      if (mounted) {
        setState(() {
          _geminiPrediction = prediction;
          _checkInInterval = prediction.recommendedIntervalMinutes;
        });
      }
    } catch (_) {}
  }

  @override
  void didUpdateWidget(covariant JourneySetupScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.contacts != widget.contacts) {
      final validIds = widget.contacts.map((c) => c.id).toSet();
      _selectedContactIds = _selectedContactIds.intersection(validIds);
      if (_selectedContactIds.isEmpty && widget.contacts.isNotEmpty) {
        _selectedContactIds = validIds;
      }
    }
  }

  @override
  void dispose() {
    _searchDebounceTimer?.cancel();
    _startController.dispose();
    _destController.dispose();
    _vehicleController.dispose();
    super.dispose();
  }

  /// Generates the effective list of waypoints matching exactly what is rendered on the map.
  List<LatLngPoint> _getEffectiveRouteWaypoints() {
    final List<LatLng> points = [];
    if (_selectedMode == TransportMode.metro &&
        _metroRoute != null &&
        _metroRoute!.isAvailable) {
      points.add(_startCoord);
      if (_metroRoute!.originStation != null) {
        points.add(_metroRoute!.originStation!.latLng);
      }
      points.addAll(_metroRoute!.metroPath);
      if (_metroRoute!.destinationStation != null) {
        points.add(_metroRoute!.destinationStation!.latLng);
      }
      points.add(_destCoord);
    } else if (_roadRoute != null && _roadRoute!.polylinePoints.isNotEmpty) {
      points.addAll(_roadRoute!.polylinePoints);
    } else {
      points.add(_startCoord);
      points.add(_destCoord);
    }

    return points
        .map((p) => LatLngPoint(latitude: p.latitude, longitude: p.longitude))
        .toList();
  }

  /// Recalculates real road route or metro line with dynamic transit physics & traffic predictions
  Future<void> _calculateActiveRoute() async {
    if (!_hasSelectedDestination) return;

    setState(() => _isCalculatingRoute = true);

    if (_selectedMode == TransportMode.metro) {
      final metro = _routingService.checkMetroAvailability(
        start: _startCoord,
        destination: _destCoord,
      );

      setState(() {
        _metroRoute = metro;
        _isCalculatingRoute = false;
        final dist = _getEffectiveRouteDistanceKm();
        final timing = _calculateDynamicTiming(distanceKm: dist, mode: TransportMode.metro);
        final checkIn = _calculateCheckInRecommendation(mode: TransportMode.metro, distanceKm: dist);
        if (metro.isAvailable) {
          _setSmartDuration(metro.totalEstimatedMinutes);
        } else {
          _setSmartDuration(timing.totalMinutes);
        }
        _checkInInterval = checkIn.recommendedIntervalMinutes;
      });
    } else {
      final road = await _routingService.calculateRoadRoute(
        start: _startCoord,
        destination: _destCoord,
        mode: _selectedMode,
      );

      if (mounted) {
        setState(() {
          _roadRoute = road;
          _isCalculatingRoute = false;
          final dist = road.distanceKm;
          final timing = _calculateDynamicTiming(distanceKm: dist, mode: _selectedMode);
          final checkIn = _calculateCheckInRecommendation(mode: _selectedMode, distanceKm: dist);
          _setSmartDuration(timing.totalMinutes);
          _checkInInterval = checkIn.recommendedIntervalMinutes;
        });
      }
    }

    _updateGeminiPrediction();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fitMapBounds();
    });
  }

  /// Evaluates real-time diurnal traffic congestion multiplier for road vehicles
  TrafficEstimation _getTrafficEstimation() {
    final now = DateTime.now();
    final hour = now.hour;
    final minute = now.minute;
    final time = hour + (minute / 60.0);

    // Morning Peak Rush: 08:00 - 11:30 (+45% travel delay)
    if (time >= 8.0 && time < 11.5) {
      return const TrafficEstimation(
        congestionMultiplier: 1.45,
        statusLabel: 'Morning Peak (+45%)',
        description: 'Heavy arterial congestion & peak junction signal cycles',
        badgeColor: AppColors.warningAmber,
        icon: Icons.traffic_rounded,
      );
    }
    // Evening Peak Rush: 17:00 - 21:30 (+50% travel delay)
    if (time >= 17.0 && time < 21.5) {
      return const TrafficEstimation(
        congestionMultiplier: 1.50,
        statusLabel: 'Evening Peak (+50%)',
        description: 'Heavy commuter bottlenecks across primary corridors',
        badgeColor: Color(0xFFFF5252),
        icon: Icons.traffic_rounded,
      );
    }
    // Midday Steady: 11:30 - 17:00 (+20% travel delay)
    if (time >= 11.5 && time < 17.0) {
      return const TrafficEstimation(
        congestionMultiplier: 1.20,
        statusLabel: 'Daytime Flow (+20%)',
        description: 'Moderate steady flow with active intersection lights',
        badgeColor: AppColors.safeGreen,
        icon: Icons.speed_rounded,
      );
    }
    // Early Morning: 05:30 - 08:00 (+8% travel delay)
    if (time >= 5.5 && time < 8.0) {
      return const TrafficEstimation(
        congestionMultiplier: 1.08,
        statusLabel: 'Early Morning (+8%)',
        description: 'Smooth flow with clear arterial transit routes',
        badgeColor: AppColors.safeGreen,
        icon: Icons.check_circle_outline_rounded,
      );
    }
    // Night Free-Flow: 21:30 - 05:30 (0% delay)
    return const TrafficEstimation(
      congestionMultiplier: 1.00,
      statusLabel: 'Night Free-Flow (0%)',
      description: 'Clear arterial roads and fast signal progression',
      badgeColor: AppColors.primaryCobalt,
      icon: Icons.nightlight_round,
    );
  }

  /// Calculates dynamic travel duration based on transport mode physics and real-time traffic
  DynamicTimingPrediction _calculateDynamicTiming({
    required double distanceKm,
    required TransportMode mode,
  }) {
    final traffic = _getTrafficEstimation();

    switch (mode) {
      case TransportMode.walking:
        // Human walking speed: 4.6 km/h (~13.04 min/km).
        // Pedestrians walk on sidewalks/paths and are exempt from motor traffic jams.
        const speedKmh = 4.6;
        final baseMinutes = math.max(5, ((distanceKm / speedKmh) * 60).round() + 2);
        return DynamicTimingPrediction(
          totalMinutes: baseMinutes,
          baseTravelMinutes: baseMinutes,
          trafficDelayMinutes: 0,
          averageSpeedKmh: speedKmh,
          modeRationale: 'Pedestrian pace (~4.6 km/h) • Road traffic congestion exempt',
          traffic: const TrafficEstimation(
            congestionMultiplier: 1.0,
            statusLabel: 'Pedestrian Pace',
            description: 'Sidewalk route immune to vehicular road traffic jams',
            badgeColor: AppColors.safeGreen,
            icon: Icons.directions_walk_rounded,
          ),
        );

      case TransportMode.auto:
        // Auto-rickshaw: speed governed ~35-40 km/h; cruising speed 22-26 km/h.
        final baseSpeed = distanceKm > 20 ? 26.0 : 22.0;
        final autoTraffic = 1.0 + (traffic.congestionMultiplier - 1.0) * 0.85;
        final effectiveSpeed = baseSpeed / autoTraffic;
        final baseMins = ((distanceKm / baseSpeed) * 60).round() + 4;
        final totalMins = math.max(8, ((distanceKm / effectiveSpeed) * 60).round() + 4);
        final delay = math.max(0, totalMins - baseMins);

        return DynamicTimingPrediction(
          totalMinutes: totalMins,
          baseTravelMinutes: baseMins,
          trafficDelayMinutes: delay,
          averageSpeedKmh: effectiveSpeed,
          modeRationale: 'Auto city transit (~${baseSpeed.toInt()} km/h) • Lane filtering flexibility',
          traffic: traffic,
        );

      case TransportMode.cab:
        // Cab/Taxi: city streets (28 km/h), arterial (42 km/h), expressways (72 km/h).
        double baseSpeed;
        int bufferMins;
        String profile;

        if (distanceKm > 60) {
          baseSpeed = 72.0;
          bufferMins = 12;
          profile = 'Highway express cruising (~72 km/h base)';
        } else if (distanceKm > 20) {
          baseSpeed = 42.0;
          bufferMins = 8;
          profile = 'Arterial / suburban cab transit (~42 km/h base)';
        } else {
          baseSpeed = 28.0;
          bufferMins = 5;
          profile = 'City street driving (~28 km/h base)';
        }

        final effectiveSpeed = baseSpeed / traffic.congestionMultiplier;
        final baseMins = ((distanceKm / baseSpeed) * 60).round() + bufferMins;
        final totalMins = math.max(10, ((distanceKm / effectiveSpeed) * 60).round() + bufferMins);
        final delay = math.max(0, totalMins - baseMins);

        return DynamicTimingPrediction(
          totalMinutes: totalMins,
          baseTravelMinutes: baseMins,
          trafficDelayMinutes: delay,
          averageSpeedKmh: effectiveSpeed,
          modeRationale: profile,
          traffic: traffic,
        );

      case TransportMode.bus:
        // Public Bus: frequent passenger stop dwelling
        final baseSpeed = distanceKm > 40 ? 50.0 : 18.0;
        final dwellFactor = distanceKm > 40 ? 1.08 : 1.25;
        final bufferMins = distanceKm > 40 ? 15 : 8;

        final effectiveSpeed = (baseSpeed / traffic.congestionMultiplier) / dwellFactor;
        final baseMins = ((distanceKm / baseSpeed) * 60 * dwellFactor).round() + bufferMins;
        final totalMins = math.max(12, ((distanceKm / effectiveSpeed) * 60).round() + bufferMins);
        final delay = math.max(0, totalMins - baseMins);

        return DynamicTimingPrediction(
          totalMinutes: totalMins,
          baseTravelMinutes: baseMins,
          trafficDelayMinutes: delay,
          averageSpeedKmh: effectiveSpeed,
          modeRationale: distanceKm > 40 ? 'Intercity state transit coach' : 'City public bus with scheduled stop dwelling',
          traffic: traffic,
        );

      case TransportMode.metro:
        // Dedicated rapid rail: 100% immune to road traffic jams
        int totalMins;
        if (_metroRoute != null && _metroRoute!.isAvailable) {
          totalMins = _metroRoute!.totalEstimatedMinutes;
        } else {
          totalMins = ((distanceKm / 34.0) * 60).round() + 6;
        }
        totalMins = math.max(10, totalMins);

        return DynamicTimingPrediction(
          totalMinutes: totalMins,
          baseTravelMinutes: totalMins,
          trafficDelayMinutes: 0,
          averageSpeedKmh: 34.0,
          modeRationale: 'Grade-separated rapid rail • 100% immune to road traffic jams',
          traffic: const TrafficEstimation(
            congestionMultiplier: 1.0,
            statusLabel: 'Dedicated Rail Line',
            description: 'Grade-separated line unaffected by surface street gridlock',
            badgeColor: AppColors.primaryCobalt,
            icon: Icons.subway_rounded,
          ),
        );
    }
  }

  /// Context-aware check-in recommendation based on Time of Day & Route Risk/Silence
  DynamicCheckInRecommendation _calculateCheckInRecommendation({
    required TransportMode mode,
    required double distanceKm,
  }) {
    final now = DateTime.now();
    final hour = now.hour;
    final isNight = hour >= 21 || hour < 5;
    final isEvening = hour >= 18 && hour < 21;

    // 1. Walking: Always High Alert (5 min) because pedestrians are directly exposed outdoors
    if (mode == TransportMode.walking) {
      return DynamicCheckInRecommendation(
        recommendedIntervalMinutes: 5,
        safetyTier: 'High Alert',
        rationale: isNight
            ? 'Night Pedestrian Route: Maximum vigilance active for unlit/silent streets'
            : (isEvening
                ? 'Dusk Walking Route: 5 min check-ins armed for foot transit'
                : 'Pedestrian Street Route: Silent footpaths require frequent 5 min check-ins'),
        crowdContext: 'Silent / Pedestrian Exposure',
        tierColor: AppColors.warningAmber,
        icon: Icons.directions_walk_rounded,
      );
    }

    // 2. Metro: Crowded, CISF secured, high public presence -> Relaxed (20 min)
    if (mode == TransportMode.metro) {
      return const DynamicCheckInRecommendation(
        recommendedIntervalMinutes: 20,
        safetyTier: 'Relaxed',
        rationale: 'Secure Metro Transit: CISF protection & dense crowds allow relaxed check-ins',
        crowdContext: 'Crowded Metro Transit',
        tierColor: AppColors.primaryCobalt,
        icon: Icons.subway_rounded,
      );
    }

    // 3. Long-Distance / Intercity Highway Route (> 45 km)
    if (distanceKm > 45) {
      if (isNight) {
        return const DynamicCheckInRecommendation(
          recommendedIntervalMinutes: 5,
          safetyTier: 'High Alert',
          rationale: 'Silent Highway Corridor at Night: 5 min high-alert pings active for isolated stretches',
          crowdContext: 'Silent Intercity Highway',
          tierColor: AppColors.warningAmber,
          icon: Icons.alt_route_rounded,
        );
      } else {
        return const DynamicCheckInRecommendation(
          recommendedIntervalMinutes: 10,
          safetyTier: 'Balanced',
          rationale: 'Intercity Highway Corridor: Balanced 10 min pings for long-distance transit',
          crowdContext: 'Intercity Arterial',
          tierColor: AppColors.safeGreen,
          icon: Icons.alt_route_rounded,
        );
      }
    }

    // 4. Night Cab / Auto (Night window: 21:00 to 05:00)
    if (isNight) {
      final hourDisplay = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
      final ampm = hour >= 12 ? 'PM' : 'AM';
      final minDisplay = now.minute.toString().padLeft(2, '0');
      return DynamicCheckInRecommendation(
        recommendedIntervalMinutes: 5,
        safetyTier: 'High Alert',
        rationale: 'Night Solo Ride ($hourDisplay:$minDisplay $ampm): High-alert 5 min pings active for driver accountability',
        crowdContext: 'Private Vehicle (Night Isolation)',
        tierColor: AppColors.warningAmber,
        icon: Icons.nightlight_round,
      );
    }

    // 5. Evening Cab / Auto (18:00 to 21:00)
    if (isEvening) {
      if (distanceKm > 15) {
        return const DynamicCheckInRecommendation(
          recommendedIntervalMinutes: 5,
          safetyTier: 'High Alert',
          rationale: 'Evening Transit: Tightened 5 min check-ins as darkness falls on outer routes',
          crowdContext: 'Evening Suburban Transit',
          tierColor: AppColors.warningAmber,
          icon: Icons.wb_twilight_rounded,
        );
      } else {
        return const DynamicCheckInRecommendation(
          recommendedIntervalMinutes: 10,
          safetyTier: 'Balanced',
          rationale: 'Evening City Transit: Balanced 10 min check-ins along lit corridors',
          crowdContext: 'Evening Urban Arterial',
          tierColor: AppColors.safeGreen,
          icon: Icons.wb_twilight_rounded,
        );
      }
    }

    // 6. Public Bus in daytime
    if (mode == TransportMode.bus) {
      return const DynamicCheckInRecommendation(
        recommendedIntervalMinutes: 10,
        safetyTier: 'Balanced',
        rationale: 'Daylight Public Bus: Balanced 10 min check-ins with conductor & passenger presence',
        crowdContext: 'Crowded Public Bus',
        tierColor: AppColors.safeGreen,
        icon: Icons.directions_bus_rounded,
      );
    }

    // 7. Daytime Cab / Auto (05:00 to 18:00)
    return const DynamicCheckInRecommendation(
      recommendedIntervalMinutes: 10,
      safetyTier: 'Balanced',
      rationale: 'Daylight Urban Commute: Balanced 10 min check-in intervals in active traffic',
      crowdContext: 'Crowded City Arterial',
      tierColor: AppColors.safeGreen,
      icon: Icons.wb_sunny_rounded,
    );
  }

  /// Sets journey duration clamped to realistic limits
  void _setSmartDuration(int minutes) {
    _durationMinutes = minutes.clamp(5, 1440);
  }

  double _getEffectiveRouteDistanceKm() {
    if (_selectedMode == TransportMode.metro && _metroRoute != null && _metroRoute!.isAvailable) {
      return _metroRoute!.totalKm;
    }
    if (_roadRoute != null) {
      return _roadRoute!.distanceKm;
    }
    const distanceCalc = Distance();
    return distanceCalc.as(LengthUnit.Kilometer, _startCoord, _destCoord) * 1.25;
  }

  String _formatExpectedArrival() {
    final now = DateTime.now();
    final arrival = now.add(Duration(minutes: _durationMinutes));
    final hour = arrival.hour == 0 ? 12 : (arrival.hour > 12 ? arrival.hour - 12 : arrival.hour);
    final minute = arrival.minute.toString().padLeft(2, '0');
    final ampm = arrival.hour >= 12 ? 'PM' : 'AM';

    final isTomorrow = arrival.day != now.day;
    final dayLabel = isTomorrow ? ' (Tomorrow)' : '';
    return '$hour:$minute $ampm$dayLabel';
  }

  String _formatDurationDisplay(int totalMinutes) {
    final hours = totalMinutes ~/ 60;
    final mins = totalMinutes % 60;
    if (hours == 0) {
      return '$mins mins';
    }
    if (mins == 0) {
      return '$hours hrs';
    }
    return '${hours}h ${mins}m';
  }

  /// Use device GPS to fetch real-time location and set as Start location
  Future<void> _fetchAndUseCurrentGps() async {
    setState(() => _isLocatingUser = true);
    try {
      final result = await _locationService.getCurrentLocation(requestIfDenied: true);
      if (mounted) {
        setState(() {
          _isLocatingUser = false;
          _startCoord = LatLng(result.point.latitude, result.point.longitude);
          _startController.text = result.point.address;
        });
        if (_hasSelectedDestination) {
          _calculateActiveRoute();
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Starting location updated: ${result.point.address}'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.safeGreen,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLocatingUser = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('GPS lookup failed: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.emergencyRed,
          ),
        );
      }
    }
  }

  /// User taps on map to set Start or Destination pin
  Future<void> _handleMapTap(LatLng tapped) async {
    setState(() {
      _isReverseGeocoding = true;
      if (_pinMode == MapPinMode.destination) {
        _destCoord = tapped;
        _hasSelectedDestination = true;
        const distanceCalc = Distance();
        final estKm = distanceCalc.as(LengthUnit.Kilometer, _startCoord, tapped) * 1.25;
        if (!_isModeViable(_selectedMode, estKm)) {
          _selectedMode = TransportMode.cab;
        }
      } else {
        _startCoord = tapped;
      }
    });

    _calculateActiveRoute();

    final address = await _locationService.reverseGeocode(tapped.latitude, tapped.longitude);

    if (mounted) {
      setState(() {
        _isReverseGeocoding = false;
        if (_pinMode == MapPinMode.destination) {
          _destController.text = address;
        } else {
          _startController.text = address;
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${_pinMode == MapPinMode.destination ? "Destination" : "Start"} pin placed: $address',
          ),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(milliseconds: 1500),
          backgroundColor: AppColors.primaryViolet,
        ),
      );
    }
  }

  void _fitMapBounds() {
    try {
      final points = <LatLng>[_startCoord, _destCoord];
      if (_selectedMode == TransportMode.metro && _metroRoute != null && _metroRoute!.isAvailable) {
        points.addAll(_metroRoute!.metroPath);
      } else if (_roadRoute != null && _roadRoute!.polylinePoints.isNotEmpty) {
        points.addAll(_roadRoute!.polylinePoints);
      }
      final bounds = LatLngBounds.fromPoints(points);
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 48),
          maxZoom: 16.5,
        ),
      );
    } catch (e) {
      try {
        _mapController.move(_destCoord, 14.5);
      } catch (_) {}
    }
  }

  /// Dynamic Autocomplete based on what the user types (e.g. 'de' -> Delhi, Dehradun...)
  Future<void> _onDestinationTextChanged(String query) async {
    _searchDebounceTimer?.cancel();
    final clean = query.trim().toLowerCase();
    if (clean.isEmpty) {
      setState(() {
        _dynamicSuggestions = const [];
      });
      return;
    }

    // 1. Instant prefix match from comprehensive catalog
    final catalogMatches = _routingService.filterSearchCatalog(clean);

    setState(() {
      _dynamicSuggestions = catalogMatches;
    });

    // 2. Debounced query geocoding API if query has at least 3 characters and local matches are few
    if (clean.length >= 3 && catalogMatches.length < 3) {
      _searchDebounceTimer = Timer(const Duration(milliseconds: 250), () async {
        try {
          final geocoded = await _locationService.locationFromAddress(query);
          if (geocoded.isNotEmpty && mounted) {
            final additional = geocoded.take(2).map((loc) {
              return SearchLocationPreset(
                title: query,
                subtitle: '${loc.latitude.toStringAsFixed(3)}°N, ${loc.longitude.toStringAsFixed(3)}°E',
                latitude: loc.latitude,
                longitude: loc.longitude,
                icon: Icons.travel_explore_rounded,
              );
            }).toList();

            setState(() {
              _dynamicSuggestions = [...catalogMatches, ...additional];
            });
          }
        } catch (e) {
          debugPrint('Geocode suggestion error: $e');
        }
      });
    }
  }

  void _selectDestinationSuggestion(SearchLocationPreset preset) {
    _searchDebounceTimer?.cancel();
    final dest = LatLng(preset.latitude, preset.longitude);
    const distanceCalc = Distance();
    final estKm = distanceCalc.as(LengthUnit.Kilometer, _startCoord, dest) * 1.25;

    // Interactive logical check: auto-switch mode if current mode is not viable for this distance
    if (!_isModeViable(_selectedMode, estKm)) {
      final oldMode = _selectedMode;
      _selectedMode = TransportMode.cab;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Switched from ${oldMode.label} to Cab / Taxi: ${estKm.toStringAsFixed(0)} km exceeds ${oldMode.label.toLowerCase()} range.',
              ),
              behavior: SnackBarBehavior.floating,
              backgroundColor: AppColors.primaryViolet,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      });
    }

    setState(() {
      _destCoord = dest;
      _destController.text = preset.title;
      _hasSelectedDestination = true;
      _dynamicSuggestions = const [];
    });

    _calculateActiveRoute();
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveDistanceKm = _getEffectiveRouteDistanceKm();

    return Scaffold(
      backgroundColor: isDark ? AppColors.midnightDarkBackground : AppColors.lightBackground,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: widget.onBack,
        ),
        title: const Text(
          'Plan Protected Journey',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Origin & Highlighted Destination Input
              _buildOriginAndHighlightedDestinationCard(isDark),
              const SizedBox(height: 8),

              // 2. Real-Time Dynamic Typed Autocomplete Suggestions
              if (_dynamicSuggestions.isNotEmpty) ...[
                _buildTypedSuggestionsDropdown(isDark),
                const SizedBox(height: 16),
              ],

              // 3. Interactive Route Map (Revealed upon selecting destination)
              if (_hasSelectedDestination) ...[
                const SizedBox(height: 8),
                _buildInteractiveMapSection(isDark, effectiveDistanceKm),
                const SizedBox(height: 18),

                // Metro Train Route Status (if Metro is selected)
                if (_selectedMode == TransportMode.metro) ...[
                  _buildMetroRouteStatusCard(isDark),
                  const SizedBox(height: 16),
                ],


                // 4. Transport Mode Selector
                _buildTransportModeSelector(isDark),
                const SizedBox(height: 16),

                // 5. Vehicle Registration Number (Cab, Auto, Bus)
                if (_selectedMode == TransportMode.cab ||
                    _selectedMode == TransportMode.auto ||
                    _selectedMode == TransportMode.bus) ...[
                  _buildVehicleNumberInput(isDark),
                  const SizedBox(height: 16),
                ],

                // 6. Simplified Estimated Journey Time Card
                _buildEstimatedTimeCard(isDark),
                const SizedBox(height: 16),

                // 7. Separate Simplified Adaptive Check-In Frequency Card
                _buildAdaptiveCheckInCard(isDark),
                const SizedBox(height: 16),

                // 7. Corridor Geofence Toggle
                _buildGeofenceCard(isDark),
                const SizedBox(height: 16),

                // 8. Escort Guardians Selection for This Trip
                _buildContactsNotificationPreview(isDark),
                const SizedBox(height: 24),

                // 9. Modern Interactive Animated Swipe Slider
                SwipeActionControl(
                  label: 'Swipe right to arm journey protection',
                  confirmedLabel: 'PROTECTED ESCORT ACTIVE',
                  sliderColor: AppColors.primaryViolet,
                  onConfirmed: () {
                    final waypoints = _getEffectiveRouteWaypoints();
                    widget.onStartJourney(
                      _startController.text,
                      _destController.text,
                      _selectedMode,
                      _vehicleController.text,
                      _durationMinutes,
                      _checkInInterval,
                      _geofenceEnabled,
                      _selectedContactIds.toList(),
                      waypoints,
                    );
                  },
                ),
                const SizedBox(height: 28),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Highlights destination field with glow outline and clean layout
  Widget _buildOriginAndHighlightedDestinationCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.midnightDarkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? AppColors.midnightDarkCardBorder : AppColors.lightCardBorder,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Starting Point Field
          TextField(
            controller: _startController,
            onChanged: (val) {
              if (_hasSelectedDestination) {
                _calculateActiveRoute();
              }
            },
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              labelText: 'Starting Location',
              prefixIcon: IconButton(
                icon: _isLocatingUser
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.my_location, color: AppColors.infoBlue),
                tooltip: 'Fetch Current GPS Location',
                onPressed: _fetchAndUseCurrentGps,
              ),
              suffixIcon: Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.infoBlue.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'GPS Live',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: AppColors.infoBlue,
                  ),
                ),
              ),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.primaryViolet, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Prominently Highlighted Destination Address Input
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _hasSelectedDestination
                    ? AppColors.safeGreen
                    : AppColors.primaryViolet.withValues(alpha: 0.8),
                width: 2.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: (_hasSelectedDestination ? AppColors.safeGreen : AppColors.primaryViolet)
                      .withValues(alpha: isDark ? 0.25 : 0.12),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: TextField(
              controller: _destController,
              autofocus: !_hasSelectedDestination,
              onChanged: _onDestinationTextChanged,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                labelText: 'Destination Address',
                labelStyle: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: _hasSelectedDestination ? AppColors.safeGreen : AppColors.primaryViolet,
                ),
                hintText: 'Search city, landmark or transit hub...',
                hintStyle: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.normal,
                  color: isDark ? AppColors.textMuted : AppColors.lightTextSecondary,
                ),
                prefixIcon: Icon(
                  Icons.location_on_rounded,
                  color: _hasSelectedDestination ? AppColors.safeGreen : AppColors.primaryViolet,
                  size: 24,
                ),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_destController.text.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _destController.clear();
                          setState(() {
                            _dynamicSuggestions = const [];
                            _hasSelectedDestination = false;
                          });
                        },
                      ),
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.primaryViolet,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        'SEARCH',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Dynamic Autocomplete Suggestion Dropdown based strictly on user typing
  Widget _buildTypedSuggestionsDropdown(bool isDark) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 250),
      decoration: BoxDecoration(
        color: isDark ? AppColors.midnightDarkSurfaceVariant : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.primaryViolet.withValues(alpha: 0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Material(
          color: Colors.transparent,
          child: ListView.separated(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(vertical: 4),
            itemCount: _dynamicSuggestions.length,
            separatorBuilder: (context, index) => const Divider(height: 1, indent: 52),
            itemBuilder: (context, index) {
              final suggestion = _dynamicSuggestions[index];
              return ListTile(
                dense: true,
                leading: Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: AppColors.primaryViolet.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(suggestion.icon, size: 18, color: AppColors.primaryViolet),
                ),
                title: Text(
                  suggestion.title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                subtitle: Text(
                  suggestion.subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? AppColors.textSecondary : AppColors.lightTextSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: const Icon(Icons.north_west, size: 14, color: AppColors.primaryViolet),
                onTap: () => _selectDestinationSuggestion(suggestion),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildInteractiveMapSection(bool isDark, double routeDistanceKm) {
    final isMetroMode = _selectedMode == TransportMode.metro;
    final hasMetroLine = isMetroMode && _metroRoute != null && _metroRoute!.isAvailable;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF070B19),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppColors.midnightDarkCardBorder : AppColors.lightCardBorder,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Map Control & Mode Tool Bar (horizontally scrollable to eliminate right overflow)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            color: isDark ? AppColors.midnightDarkSurface : AppColors.lightSurface,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      InkWell(
                        onTap: () => setState(() => _pinMode = MapPinMode.destination),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _pinMode == MapPinMode.destination
                                ? AppColors.safeGreen.withValues(alpha: 0.2)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: _pinMode == MapPinMode.destination
                                  ? AppColors.safeGreen
                                  : Colors.transparent,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.place, size: 14, color: AppColors.safeGreen),
                              const SizedBox(width: 4),
                              Text(
                                'Pick Dest',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: _pinMode == MapPinMode.destination
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color: _pinMode == MapPinMode.destination
                                      ? AppColors.safeGreen
                                      : (isDark ? AppColors.textSecondary : AppColors.lightTextSecondary),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      InkWell(
                        onTap: () => setState(() => _pinMode = MapPinMode.start),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _pinMode == MapPinMode.start
                                ? AppColors.primaryCobalt.withValues(alpha: 0.2)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: _pinMode == MapPinMode.start
                                  ? AppColors.primaryCobalt
                                  : Colors.transparent,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.flag, size: 14, color: AppColors.primaryCobalt),
                              const SizedBox(width: 4),
                              Text(
                                'Pick Start',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: _pinMode == MapPinMode.start
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color: _pinMode == MapPinMode.start
                                      ? AppColors.primaryCobalt
                                      : (isDark ? AppColors.textSecondary : AppColors.lightTextSecondary),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.refresh, size: 18, color: AppColors.safeGreen),
                        tooltip: 'Recalculate Route',
                        onPressed: _calculateActiveRoute,
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: Icon(
                          _mapLayerStyle == MapLayerStyle.satellite
                              ? Icons.satellite_alt
                              : Icons.map,
                          size: 18,
                          color: AppColors.primaryCobalt,
                        ),
                        tooltip: 'Toggle Satellite / Streets',
                        onPressed: () {
                          setState(() {
                            _mapLayerStyle = _mapLayerStyle == MapLayerStyle.satellite
                                ? MapLayerStyle.streets
                                : MapLayerStyle.satellite;
                          });
                        },
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.fit_screen, size: 18, color: AppColors.infoBlue),
                        tooltip: 'Fit route in view',
                        onPressed: _fitMapBounds,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Map View with Polyline & Markers
          SizedBox(
            height: 250,
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _destCoord,
                    initialZoom: 13.0,
                    minZoom: 3.0,
                    maxZoom: 19.0,
                    onTap: (tapPosition, latLng) => _handleMapTap(latLng),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: _mapLayerStyle == MapLayerStyle.satellite
                          ? 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}.jpg'
                          : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.shemove.app',
                      maxZoom: 19,
                    ),

                    if (_mapLayerStyle == MapLayerStyle.satellite)
                      TileLayer(
                        urlTemplate:
                            'https://server.arcgisonline.com/ArcGIS/rest/services/Reference/World_Boundaries_and_Places/MapServer/tile/{z}/{y}/{x}.png',
                        userAgentPackageName: 'com.shemove.app',
                        maxZoom: 19,
                      ),

                    // 1. Metro Track (if Metro selected & available)
                    if (hasMetroLine) ...[
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: _metroRoute!.metroPath,
                            color: Colors.black.withValues(alpha: 0.6),
                            strokeWidth: 8.0,
                            strokeCap: StrokeCap.round,
                            strokeJoin: StrokeJoin.round,
                          ),
                          Polyline(
                            points: _metroRoute!.metroPath,
                            color: _metroRoute!.primaryLineColor,
                            strokeWidth: 5.5,
                            strokeCap: StrokeCap.round,
                            strokeJoin: StrokeJoin.round,
                          ),
                          Polyline(
                            points: [_startCoord, _metroRoute!.originStation!.latLng],
                            color: AppColors.infoBlue,
                            strokeWidth: 3.0,
                            pattern: StrokePattern.dashed(segments: [6, 4]),
                          ),
                          Polyline(
                            points: [_metroRoute!.destinationStation!.latLng, _destCoord],
                            color: AppColors.safeGreen,
                            strokeWidth: 3.0,
                            pattern: StrokePattern.dashed(segments: [6, 4]),
                          ),
                        ],
                      ),

                      MarkerLayer(
                        markers: _metroRoute!.passedStations.map((station) {
                          return Marker(
                            point: station.latLng,
                            width: 14,
                            height: 14,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                border: Border.all(color: _metroRoute!.primaryLineColor, width: 3),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.4),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ]
                    // 2. Road Network with Corridor Geofence & Clean Route Polyline
                    else ...[
                      // Geofence Protection Corridor Envelope
                      if (_geofenceEnabled)
                        PolylineLayer(
                          polylines: [
                            Polyline(
                              points: _roadRoute?.polylinePoints ?? [_startCoord, _destCoord],
                              color: AppColors.infoBlue.withValues(alpha: isDark ? 0.22 : 0.14),
                              strokeWidth: _geofenceRadiusMeters == 150
                                  ? 22.0
                                  : (_geofenceRadiusMeters == 300 ? 32.0 : 44.0),
                              strokeCap: StrokeCap.round,
                              strokeJoin: StrokeJoin.round,
                            ),
                            Polyline(
                              points: _roadRoute?.polylinePoints ?? [_startCoord, _destCoord],
                              color: AppColors.infoBlue.withValues(alpha: isDark ? 0.45 : 0.3),
                              strokeWidth: 1.5,
                              pattern: StrokePattern.dashed(segments: [6, 4]),
                            ),
                          ],
                        ),

                      // Clean Single Route Polyline
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: _roadRoute?.polylinePoints ?? [_startCoord, _destCoord],
                            color: AppColors.primaryViolet,
                            strokeWidth: 4.5,
                            strokeCap: StrokeCap.round,
                            strokeJoin: StrokeJoin.round,
                          ),
                        ],
                      ),
                    ],

                    MarkerLayer(
                      markers: [
                        // Start Marker
                        Marker(
                          point: _startCoord,
                          width: 56,
                          height: 56,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(5),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryViolet,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.primaryViolet.withValues(alpha: 0.5),
                                      blurRadius: 8,
                                    ),
                                  ],
                                  border: Border.all(color: Colors.white, width: 2),
                                ),
                                child: const Icon(Icons.flag, color: Colors.white, size: 14),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.75),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'START',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Destination Marker
                        Marker(
                          point: _destCoord,
                          width: 56,
                          height: 56,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: AppColors.safeGreen,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.safeGreen.withValues(alpha: 0.6),
                                      blurRadius: 10,
                                    ),
                                  ],
                                  border: Border.all(color: Colors.white, width: 2),
                                ),
                                child: const Icon(Icons.location_on, color: Colors.white, size: 16),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.8),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'DEST',
                                  style: TextStyle(
                                    color: AppColors.safeGreenGlow,
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                // Floating HUD: Distance & Route Status
                Positioned(
                  top: 10,
                  left: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.84),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          hasMetroLine ? Icons.subway : Icons.route,
                          color: hasMetroLine ? _metroRoute!.primaryLineColor : AppColors.safeGreenGlow,
                          size: 14,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${routeDistanceKm.toStringAsFixed(1)} km',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          hasMetroLine ? 'Metro Line' : 'Road Route',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Floating Corridor Guard Badge
                if (_geofenceEnabled)
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.infoBlue.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.infoBlue.withValues(alpha: 0.35),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.shield_rounded, size: 12, color: Colors.white),
                          const SizedBox(width: 4),
                          Text(
                            '${_geofenceRadiusMeters}m Corridor',
                            style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),

                if (_isReverseGeocoding || _isCalculatingRoute)
                  Positioned(
                    bottom: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.white),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _isCalculatingRoute ? 'Live routing...' : 'Resolving pin...',
                            style: const TextStyle(color: Colors.white, fontSize: 10),
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

  Widget _buildMetroRouteStatusCard(bool isDark) {
    if (_metroRoute == null) return const SizedBox.shrink();

    if (_metroRoute!.isAvailable) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _metroRoute!.primaryLineColor.withValues(alpha: isDark ? 0.15 : 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _metroRoute!.primaryLineColor.withValues(alpha: 0.4),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: _metroRoute!.primaryLineColor,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.subway, color: Colors.black, size: 16),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'METRO ROUTE AVAILABLE',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                          color: _metroRoute!.primaryLineColor,
                        ),
                      ),
                      Text(
                        _metroRoute!.lineSummary,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppColors.textPrimary : AppColors.lightTextPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.midnightDarkSurface : AppColors.lightSurface,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${_metroRoute!.totalStations} stops',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const Divider(height: 18),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Board at',
                        style: TextStyle(fontSize: 10, color: isDark ? AppColors.textSecondary : AppColors.lightTextSecondary),
                      ),
                      Text(
                        _metroRoute!.originStation!.name,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${_metroRoute!.firstMileKm} km from start',
                        style: TextStyle(fontSize: 10, color: isDark ? AppColors.textSecondary : AppColors.lightTextSecondary),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward, size: 14),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Deboard at',
                        style: TextStyle(fontSize: 10, color: isDark ? AppColors.textSecondary : AppColors.lightTextSecondary),
                      ),
                      Text(
                        _metroRoute!.destinationStation!.name,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${_metroRoute!.lastMileKm} km to dest',
                        style: TextStyle(fontSize: 10, color: isDark ? AppColors.textSecondary : AppColors.lightTextSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.warningAmber.withValues(alpha: isDark ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.warningAmber.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: AppColors.warningAmber, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'No Direct Metro Route Available',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.textPrimary : AppColors.lightTextPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _metroRoute!.unavailableReason ?? 'Destination is outside the Metro corridor radius.',
            style: TextStyle(
              fontSize: 11,
              color: isDark ? AppColors.textSecondary : AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _selectedMode = TransportMode.cab;
                  });
                  _calculateActiveRoute();
                },
                icon: const Icon(Icons.local_taxi, size: 14),
                label: const Text('Switch to Cab'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryViolet,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _selectedMode = TransportMode.auto;
                  });
                  _calculateActiveRoute();
                },
                icon: const Icon(Icons.electric_rickshaw, size: 14),
                label: const Text('Switch to Auto'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }


  Widget _buildTransportModeSelector(bool isDark) {
    final distanceKm = _getEffectiveRouteDistanceKm();
    final viableModes = _getViableModes(distanceKm);
    final activeTiming = _calculateDynamicTiming(distanceKm: distanceKm, mode: _selectedMode);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Text(
                  'Transport Mode',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.textPrimary : AppColors.lightTextPrimary,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: (distanceKm > 45 ? AppColors.infoBlue : AppColors.safeGreen)
                        .withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    distanceKm > 45
                        ? 'Intercity (${distanceKm.toStringAsFixed(0)} km)'
                        : (distanceKm > 12
                            ? 'Regional (${distanceKm.toStringAsFixed(0)} km)'
                            : 'Local (${distanceKm.toStringAsFixed(1)} km)'),
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: distanceKm > 45 ? AppColors.infoBlue : AppColors.safeGreen,
                    ),
                  ),
                ),
              ],
            ),
            Text(
              '${_selectedMode.label} • ~${activeTiming.totalMinutes} min',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryViolet,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: viableModes.map((mode) {
              final isSelected = _selectedMode == mode;
              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: FilterChip(
                  selected: isSelected,
                  label: Text(mode.label),
                  avatar: Icon(
                    mode.icon,
                    size: 18,
                    color: isSelected ? Colors.white : AppColors.primaryViolet,
                  ),
                  onSelected: (val) {
                    setState(() {
                      _selectedMode = mode;
                      final dist = _getEffectiveRouteDistanceKm();
                      final timing = _calculateDynamicTiming(distanceKm: dist, mode: mode);
                      final checkIn = _calculateCheckInRecommendation(mode: mode, distanceKm: dist);
                      _durationMinutes = timing.totalMinutes;
                      _checkInInterval = checkIn.recommendedIntervalMinutes;
                    });
                    _calculateActiveRoute();
                  },
                  selectedColor: AppColors.primaryViolet,
                  labelStyle: TextStyle(
                    color: isSelected
                        ? Colors.white
                        : (isDark ? AppColors.textPrimary : AppColors.lightTextPrimary),
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(
                      color: isSelected ? AppColors.primaryViolet : Colors.transparent,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        if (distanceKm > 12) ...[
          const SizedBox(height: 6),
          Text(
            distanceKm > 45
                ? 'Walking and Auto are disabled because route distance (${distanceKm.toStringAsFixed(0)} km) exceeds realistic transit range.'
                : 'Walking is disabled because distance (${distanceKm.toStringAsFixed(0)} km) exceeds pedestrian feasibility (max 12 km).',
            style: TextStyle(
              fontSize: 11,
              color: isDark ? AppColors.textMuted : AppColors.lightTextSecondary,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildVehicleNumberInput(bool isDark) {
    return TextField(
      controller: _vehicleController,
      decoration: InputDecoration(
        labelText: 'Vehicle / Registration Number',
        prefixIcon: const Icon(Icons.badge, color: AppColors.primaryCobalt),
        hintText: 'e.g. DL 1Y B 4821',
        suffixIcon: IconButton(
          icon: const Icon(Icons.clear, size: 18),
          onPressed: () => _vehicleController.clear(),
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primaryCobalt, width: 2),
        ),
      ),
    );
  }

  /// Dynamic Estimated Journey Time Card with Quick Steppers & Detailed Info Dialog
  Widget _buildEstimatedTimeCard(bool isDark) {
    final distanceKm = _getEffectiveRouteDistanceKm();
    final timing = _calculateDynamicTiming(distanceKm: distanceKm, mode: _selectedMode);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppColors.midnightDarkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppColors.midnightDarkCardBorder : AppColors.lightCardBorder,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Title & Info Icon + Traffic Status Badge
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.schedule_rounded, color: AppColors.primaryCobalt, size: 20),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Estimated Journey Time',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppColors.textPrimary : AppColors.lightTextPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    InkWell(
                      onTap: () => _showEstimatedTimeInfoDialog(context, timing, distanceKm),
                      borderRadius: BorderRadius.circular(12),
                      child: const Padding(
                        padding: EdgeInsets.all(2.0),
                        child: Icon(Icons.info_outline, size: 16, color: AppColors.primaryCobalt),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: timing.traffic.badgeColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: timing.traffic.badgeColor.withValues(alpha: 0.35)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(timing.traffic.icon, size: 12, color: timing.traffic.badgeColor),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          timing.traffic.statusLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: timing.traffic.badgeColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Big, Clean Time Display & Expected Arrival
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        _formatDurationDisplay(_durationMinutes),
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: AppColors.primaryCobalt,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.flag_circle_rounded, size: 13, color: AppColors.safeGreen),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            'Expected Arrival: ${_formatExpectedArrival()}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDark ? AppColors.textSecondary : AppColors.lightTextSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Manual Increase / Decrease Stepper Controls
              Container(
                decoration: BoxDecoration(
                  color: isDark ? AppColors.midnightDarkSurfaceVariant : AppColors.lightSurfaceVariant,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark ? AppColors.midnightDarkCardBorder : AppColors.lightCardBorder,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove_rounded, size: 20),
                      tooltip: 'Decrease 5 mins',
                      onPressed: () {
                        setState(() {
                          _durationMinutes = math.max(5, _durationMinutes - 5);
                        });
                      },
                      color: isDark ? AppColors.textPrimary : AppColors.lightTextPrimary,
                    ),
                    Container(
                      height: 20,
                      width: 1,
                      color: isDark ? Colors.white24 : Colors.black12,
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_rounded, size: 20),
                      tooltip: 'Increase 5 mins',
                      onPressed: () {
                        setState(() {
                          _durationMinutes = math.min(1440, _durationMinutes + 5);
                        });
                      },
                      color: isDark ? AppColors.textPrimary : AppColors.lightTextPrimary,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Dynamic transit timing metrics breakdown
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? AppColors.midnightDarkSurfaceVariant : AppColors.lightSurfaceVariant,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? AppColors.midnightDarkCardBorder : AppColors.lightCardBorder,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildTimingMetricItem('Route Distance', '${distanceKm.toStringAsFixed(1)} km', isDark),
                Container(height: 24, width: 1, color: isDark ? Colors.white12 : Colors.black12),
                _buildTimingMetricItem('Avg Speed', '${timing.averageSpeedKmh.toStringAsFixed(0)} km/h', isDark),
                Container(height: 24, width: 1, color: isDark ? Colors.white12 : Colors.black12),
                _buildTimingMetricItem(
                  'Traffic Delay',
                  timing.trafficDelayMinutes > 0 ? '+${timing.trafficDelayMinutes}m' : '0m',
                  isDark,
                  valueColor: timing.trafficDelayMinutes > 0 ? AppColors.warningAmber : null,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Quick Time Adjust Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                _buildTimeStepperChip('-15m', -15, isDark),
                const SizedBox(width: 6),
                _buildTimeStepperChip('+15m', 15, isDark),
                const SizedBox(width: 6),
                _buildTimeStepperChip('+30m', 30, isDark),
                const SizedBox(width: 6),
                _buildTimeStepperChip('+1 Hour', 60, isDark),
                const SizedBox(width: 6),
                _buildTimeStepperChip('+3 Hours', 180, isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimingMetricItem(String label, String value, bool isDark, {Color? valueColor}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: isDark ? AppColors.textSecondary : AppColors.lightTextSecondary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: valueColor ?? (isDark ? AppColors.textPrimary : AppColors.lightTextPrimary),
          ),
        ),
      ],
    );
  }

  /// Displays comprehensive transit duration and traffic calculation breakdown dialog
  void _showEstimatedTimeInfoDialog(BuildContext context, DynamicTimingPrediction timing, double distanceKm) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.midnightDarkSurface : AppColors.lightSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.schedule_rounded, color: AppColors.primaryCobalt, size: 24),
            SizedBox(width: 10),
            Text(
              'Journey Duration Details',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'How is travel time calculated?',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primaryCobalt),
            ),
            const SizedBox(height: 6),
            Text(
              'Duration is calculated using live route geometry, transit mode mechanics, and diurnal road traffic patterns.',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? AppColors.textSecondary : AppColors.lightTextSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            _buildDialogBullet(
              'Route Distance',
              '${distanceKm.toStringAsFixed(1)} km along the selected path.',
              isDark,
            ),
            const SizedBox(height: 6),
            _buildDialogBullet(
              'Transit Speed',
              '~${timing.averageSpeedKmh.toStringAsFixed(0)} km/h based on ${_selectedMode.label} characteristics.',
              isDark,
            ),
            const SizedBox(height: 6),
            _buildDialogBullet(
              'Traffic & Congestion',
              '${timing.traffic.statusLabel} (${timing.trafficDelayMinutes > 0 ? "+${timing.trafficDelayMinutes} mins delay" : "Free flow"}). ${timing.traffic.description}',
              isDark,
            ),
            const SizedBox(height: 6),
            _buildDialogBullet(
              'Transit Model',
              timing.modeRationale,
              isDark,
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryCobalt,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  /// Context-Aware Adaptive Check-In Frequency Card with Diurnal & Route Risk Intelligence
  Widget _buildAdaptiveCheckInCard(bool isDark) {
    final distanceKm = _getEffectiveRouteDistanceKm();
    final localRec = _calculateCheckInRecommendation(mode: _selectedMode, distanceKm: distanceKm);
    final prediction = _geminiPrediction;
    final recommendedInterval = prediction?.recommendedIntervalMinutes ?? localRec.recommendedIntervalMinutes;
    final safetyTier = prediction?.safetyTier ?? localRec.safetyTier;
    final isAi = prediction?.isAiGenerated ?? false;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppColors.midnightDarkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppColors.midnightDarkCardBorder : AppColors.lightCardBorder,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Title & Info Icon + Frequency Pill
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.security_rounded, color: AppColors.safeGreen, size: 20),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Adaptive Check-In Frequency',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppColors.textPrimary : AppColors.lightTextPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    InkWell(
                      onTap: () => _showAdaptiveCheckInInfoDialog(context, prediction ?? localRec),
                      borderRadius: BorderRadius.circular(12),
                      child: const Padding(
                        padding: EdgeInsets.all(2.0),
                        child: Icon(Icons.info_outline, size: 16, color: AppColors.safeGreen),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.safeGreen.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.safeGreen.withValues(alpha: 0.4)),
                ),
                child: Text(
                  'Every $_checkInInterval min',
                  maxLines: 1,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppColors.safeGreen,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Clean Status Row with Recommended Badge
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: localRec.tierColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Smart Safety: Recommended $safetyTier ($recommendedInterval min)',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppColors.textSecondary : AppColors.lightTextSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (isAi) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primaryCobalt.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.primaryCobalt.withValues(alpha: 0.3)),
                  ),
                  child: const Text(
                    'Gemini AI',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryCobalt,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),

          // 3 Distinct Clean Presets (Capsules)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildSimpleCheckInChip(
                  label: 'High Alert',
                  interval: 5,
                  color: AppColors.warningAmber,
                  isDark: isDark,
                  isRecommended: recommendedInterval == 5,
                ),
                const SizedBox(width: 8),
                _buildSimpleCheckInChip(
                  label: 'Balanced',
                  interval: 10,
                  color: AppColors.safeGreen,
                  isDark: isDark,
                  isRecommended: recommendedInterval == 10,
                ),
                const SizedBox(width: 8),
                _buildSimpleCheckInChip(
                  label: 'Relaxed',
                  interval: 20,
                  color: AppColors.primaryCobalt,
                  isDark: isDark,
                  isRecommended: recommendedInterval == 20,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Displays intelligent adaptive check-in rationale, Gemini model insights, and escalation rules
  void _showAdaptiveCheckInInfoDialog(BuildContext context, dynamic prediction) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final String tier = prediction is GeminiCheckInPrediction
        ? prediction.safetyTier
        : (prediction as DynamicCheckInRecommendation).safetyTier;
    final int interval = prediction is GeminiCheckInPrediction
        ? prediction.recommendedIntervalMinutes
        : (prediction as DynamicCheckInRecommendation).recommendedIntervalMinutes;
    final String rationale = prediction is GeminiCheckInPrediction
        ? prediction.rationale
        : (prediction as DynamicCheckInRecommendation).rationale;
    final String crowd = prediction is GeminiCheckInPrediction
        ? prediction.crowdContext
        : (prediction as DynamicCheckInRecommendation).crowdContext;
    final List<String> tips = prediction is GeminiCheckInPrediction
        ? prediction.safetyTips
        : const [];
    final bool isAi = prediction is GeminiCheckInPrediction && prediction.isAiGenerated;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.midnightDarkSurface : AppColors.lightSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.security_rounded, color: AppColors.safeGreen, size: 24),
            SizedBox(width: 10),
            Text(
              'Adaptive Check-In Protection',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isAi
                  ? 'Gemini Safety Intelligence Prediction'
                  : 'Why is this check-in interval recommended?',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.safeGreen),
            ),
            const SizedBox(height: 6),
            Text(
              'Check-in intervals adapt based on transit mode, environmental exposure, route lighting, and time of day.',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? AppColors.textSecondary : AppColors.lightTextSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            _buildDialogBullet(
              'Recommended Level',
              '$tier ($interval min) for $crowd.',
              isDark,
            ),
            const SizedBox(height: 6),
            _buildDialogBullet(
              'Safety Analysis',
              rationale,
              isDark,
            ),
            if (tips.isNotEmpty) ...[
              const SizedBox(height: 6),
              ...tips.map((t) => Padding(
                    padding: const EdgeInsets.only(bottom: 6.0),
                    child: _buildDialogBullet('Precaution', t, isDark),
                  )),
            ],
            const SizedBox(height: 6),
            _buildDialogBullet(
              'Silent Verification',
              'Check-in alerts prompt quietly. If unanswered within 45 seconds, your emergency guardians receive instant live telemetry.',
              isDark,
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.safeGreen,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Got It'),
          ),
        ],
      ),
    );
  }

  Widget _buildSimpleCheckInChip({
    required String label,
    required int interval,
    required Color color,
    required bool isDark,
    bool isRecommended = false,
  }) {
    final isSelected = _checkInInterval == interval;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _checkInInterval = interval),
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          decoration: BoxDecoration(
            color: isSelected
                ? color.withValues(alpha: isDark ? 0.22 : 0.12)
                : (isDark ? AppColors.midnightDarkSurfaceVariant : AppColors.lightSurfaceVariant),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected
                  ? color
                  : (isDark ? AppColors.midnightDarkCardBorder : AppColors.lightCardBorder),
              width: isSelected ? 1.8 : 1.0,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isRecommended)
                Container(
                  margin: const EdgeInsets.only(bottom: 3),
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'Recommended',
                      style: TextStyle(
                        fontSize: 7.5,
                        fontWeight: FontWeight.w800,
                        color: color,
                        letterSpacing: 0.1,
                      ),
                    ),
                  ),
                )
              else
                const SizedBox(height: 12),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isSelected
                        ? color
                        : (isDark ? AppColors.textPrimary : AppColors.lightTextPrimary),
                  ),
                ),
              ),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '$interval min',
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isSelected
                        ? color
                        : (isDark ? AppColors.textSecondary : AppColors.lightTextSecondary),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimeStepperChip(String label, int deltaMinutes, bool isDark) {
    return InkWell(
      onTap: () {
        setState(() {
          final updated = (_durationMinutes + deltaMinutes).clamp(5, 1440);
          _setSmartDuration(updated);
        });
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: isDark ? AppColors.midnightDarkSurfaceVariant : AppColors.lightSurfaceVariant,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isDark ? AppColors.midnightDarkCardBorder : AppColors.lightCardBorder,
          ),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            maxLines: 1,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  Widget _buildGeofenceCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.midnightDarkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _geofenceEnabled
              ? AppColors.infoBlue.withValues(alpha: isDark ? 0.45 : 0.3)
              : (isDark ? AppColors.midnightDarkCardBorder : AppColors.lightCardBorder),
        ),
        boxShadow: _geofenceEnabled
            ? [
                BoxShadow(
                  color: AppColors.infoBlue.withValues(alpha: isDark ? 0.15 : 0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.infoBlue.withValues(alpha: _geofenceEnabled ? 0.2 : 0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.shield_rounded,
                  color: _geofenceEnabled ? AppColors.infoBlue : Colors.grey,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            'Corridor Geofence Protection',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: isDark ? AppColors.textPrimary : AppColors.lightTextPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        InkWell(
                          onTap: () => _showGeofenceInfoDialog(context),
                          borderRadius: BorderRadius.circular(12),
                          child: const Padding(
                            padding: EdgeInsets.all(2.0),
                            child: Icon(Icons.info_outline, size: 16, color: AppColors.infoBlue),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _geofenceEnabled
                          ? 'Active ${_geofenceRadiusMeters}m safety buffer. Detours trigger instant alert.'
                          : 'Corridor tracking disabled. No off-route alerts.',
                      style: TextStyle(
                        fontSize: 11,
                        color: _geofenceEnabled
                            ? AppColors.infoBlue
                            : (isDark ? AppColors.textSecondary : AppColors.lightTextSecondary),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Switch.adaptive(
                value: _geofenceEnabled,
                activeTrackColor: AppColors.infoBlue,
                onChanged: (val) => setState(() => _geofenceEnabled = val),
              ),
            ],
          ),

          // Interactive Sensitivity Level (when enabled)
          if (_geofenceEnabled) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? AppColors.midnightDarkSurfaceVariant : AppColors.lightSurfaceVariant,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Corridor Sensitivity / Width',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppColors.textPrimary : AppColors.lightTextPrimary,
                        ),
                      ),
                      Text(
                        '${_geofenceRadiusMeters}m Envelope',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.infoBlue,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _buildSensitivityChip('Strict (150m)', 150, isDark),
                      const SizedBox(width: 6),
                      _buildSensitivityChip('Standard (300m)', 300, isDark),
                      const SizedBox(width: 6),
                      _buildSensitivityChip('Flexible (500m)', 500, isDark),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSensitivityChip(String label, int radius, bool isDark) {
    final isSelected = _geofenceRadiusMeters == radius;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _geofenceRadiusMeters = radius),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.infoBlue
                : (isDark ? AppColors.midnightDarkSurface : AppColors.lightSurface),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected
                  ? AppColors.infoBlue
                  : (isDark ? AppColors.midnightDarkCardBorder : AppColors.lightCardBorder),
            ),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Colors.white : (isDark ? AppColors.textPrimary : AppColors.lightTextPrimary),
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }

  void _showGeofenceInfoDialog(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.midnightDarkSurface : AppColors.lightSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.shield_rounded, color: AppColors.infoBlue, size: 24),
            SizedBox(width: 10),
            Text(
              'Corridor Geofence',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'What is Corridor Geofence Protection?',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.infoBlue),
            ),
            const SizedBox(height: 6),
            Text(
              'Unlike a static circular geofence around a fixed address, Corridor Geofence creates a continuous dynamic safety envelope (a virtual tunnel) along your active travel route on the map.',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? AppColors.textSecondary : AppColors.lightTextSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'How It Protects You:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 6),
            _buildDialogBullet(
              'Detour Detection',
              'If the vehicle makes an unauthorized turn into dark alleys or strays beyond the corridor envelope, SheMove flags an Off-Route alert.',
              isDark,
            ),
            const SizedBox(height: 6),
            _buildDialogBullet(
              'Auto Escalation',
              'A silent check-in prompt appears. If unanswered within 45s, emergency contacts receive live SOS telemetry and GPS breadcrumbs.',
              isDark,
            ),
            const SizedBox(height: 6),
            _buildDialogBullet(
              'Custom Sensitivity',
              'Strict (150m) for high-risk city night trips; Standard (300m) for normal streets; Flexible (500m) for highways with bypasses.',
              isDark,
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.infoBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Got It'),
          ),
        ],
      ),
    );
  }

  Widget _buildDialogBullet(String title, String body, bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 4.0),
          child: Icon(Icons.circle, size: 6, color: AppColors.infoBlue),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: TextStyle(
                fontSize: 11,
                color: isDark ? AppColors.textSecondary : AppColors.lightTextSecondary,
                height: 1.35,
              ),
              children: [
                TextSpan(
                  text: '$title: ',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.textPrimary : AppColors.lightTextPrimary,
                  ),
                ),
                TextSpan(text: body),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContactsNotificationPreview(bool isDark) {
    final hasContacts = widget.contacts.isNotEmpty;
    final noneSelected = _selectedContactIds.isEmpty;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.midnightDarkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: noneSelected
              ? AppColors.warningAmber.withValues(alpha: isDark ? 0.45 : 0.3)
              : AppColors.primaryViolet.withValues(alpha: isDark ? 0.35 : 0.22),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Header with Title, Count Pill, and Select All / Clear Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: AppColors.primaryViolet.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.people_alt_rounded, color: AppColors.primaryViolet, size: 18),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Escort Guardians for Trip',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppColors.textPrimary : AppColors.lightTextPrimary,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (noneSelected ? AppColors.warningAmber : AppColors.primaryViolet)
                      .withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: (noneSelected ? AppColors.warningAmber : AppColors.primaryViolet)
                        .withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  '${_selectedContactIds.length} of ${widget.contacts.length} Alerted',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: noneSelected ? AppColors.warningAmber : AppColors.primaryViolet,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          if (hasContacts) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Select circle members who will receive live trip telemetry and arrival notifications:',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? AppColors.textSecondary : AppColors.lightTextSecondary,
                    ),
                  ),
                ),
                if (widget.contacts.length > 1) ...[
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () {
                      setState(() {
                        if (_selectedContactIds.isNotEmpty) {
                          _selectedContactIds.clear();
                        } else {
                          _selectedContactIds = widget.contacts.map((c) => c.id).toSet();
                        }
                      });
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      child: Text(
                        _selectedContactIds.isNotEmpty ? 'Deselect All' : 'Select All',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryViolet,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),

            // Interactive Contact Selection Cards
            Column(
              children: widget.contacts.map((contact) {
                final isSelected = _selectedContactIds.contains(contact.id);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          if (isSelected) {
                            _selectedContactIds.remove(contact.id);
                          } else {
                            _selectedContactIds.add(contact.id);
                          }
                        });
                      },
                      borderRadius: BorderRadius.circular(14),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primaryViolet.withValues(alpha: isDark ? 0.16 : 0.08)
                              : (isDark
                                  ? AppColors.midnightDarkSurfaceVariant
                                  : AppColors.lightSurfaceVariant),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.primaryViolet.withValues(alpha: 0.5)
                                : (isDark
                                    ? AppColors.midnightDarkCardBorder
                                    : AppColors.lightCardBorder),
                            width: isSelected ? 1.4 : 1.0,
                          ),
                        ),
                        child: Row(
                          children: [
                            // Initial Avatar with check badge
                            Stack(
                              clipBehavior: Clip.none,
                              children: [
                                CircleAvatar(
                                  radius: 18,
                                  backgroundColor: isSelected
                                      ? AppColors.primaryViolet
                                      : (isDark ? Colors.grey.shade700 : Colors.grey.shade300),
                                  child: Text(
                                    contact.name.isNotEmpty ? contact.name[0].toUpperCase() : 'C',
                                    style: TextStyle(
                                      color: isSelected
                                          ? Colors.white
                                          : (isDark ? Colors.white70 : Colors.black87),
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                if (isSelected)
                                  Positioned(
                                    right: -2,
                                    bottom: -2,
                                    child: Container(
                                      padding: const EdgeInsets.all(2),
                                      decoration: const BoxDecoration(
                                        color: AppColors.safeGreen,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.check, size: 9, color: Colors.white),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(width: 12),

                            // Name, Relationship, and Phone
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          contact.name,
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: isSelected
                                                ? (isDark ? AppColors.textPrimary : AppColors.lightTextPrimary)
                                                : (isDark ? AppColors.textSecondary : AppColors.lightTextSecondary),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? AppColors.primaryViolet.withValues(alpha: 0.15)
                                              : (isDark
                                                  ? AppColors.midnightDarkSurface
                                                  : AppColors.lightSurface),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          contact.relationship,
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w600,
                                            color: isSelected ? AppColors.primaryViolet : AppColors.textMuted,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.phone_rounded,
                                        size: 11,
                                        color: isDark ? AppColors.textMuted : AppColors.lightTextSecondary,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        contact.phone,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: isDark ? AppColors.textMuted : AppColors.lightTextSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),

                            // Tactile Selection Check Indicator
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.primaryViolet
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isSelected
                                      ? AppColors.primaryViolet
                                      : (isDark ? Colors.white30 : Colors.black26),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
                                    size: 14,
                                    color: isSelected ? Colors.white : (isDark ? Colors.white54 : Colors.black45),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    isSelected ? 'Alerted' : 'Skip',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: isSelected ? Colors.white : (isDark ? Colors.white54 : Colors.black54),
                                    ),
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
              }).toList(),
            ),

            if (noneSelected) ...[
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.warningAmber.withValues(alpha: isDark ? 0.15 : 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.warningAmber.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, size: 16, color: AppColors.warningAmber),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Local Mode: No guardians selected. Journey will be logged on this device only.',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: isDark ? AppColors.textPrimary : AppColors.lightTextPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ] else ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warningAmber.withValues(alpha: isDark ? 0.12 : 0.07),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.warningAmber.withValues(alpha: 0.25)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.person_add_disabled_rounded, color: AppColors.warningAmber, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'No emergency contacts configured yet. Journeys are safer when trusted guardians receive live tracking links.',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? AppColors.textSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                  ),

                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
