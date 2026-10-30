import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../components/interactive_map_canvas.dart';
import '../components/swipe_action_control.dart';
import '../models/models.dart';
import '../theme/colors.dart';

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
  final void Function(
    String start,
    String dest,
    TransportMode mode,
    String vehicleNo,
    int durationMinutes,
    int intervalMinutes,
    bool geofence,
  ) onStartJourney;

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
  late TextEditingController _startController;
  late TextEditingController _destController;
  late TextEditingController _vehicleController;

  late Set<String> _selectedContactIds;
  TransportMode _selectedMode = TransportMode.cab;
  int _durationMinutes = 25;
  int _checkInInterval = 10;
  bool _geofenceEnabled = true;

  final List<String> _locationPresets = [
    'Hauz Khas Village, South Delhi',
    'Cyber City, Building 10, Gurugram',
    'Connaught Place, Inner Circle',
    'Aerocity Worldmark, Delhi',
    'Noida Sector 18 Commercial Hub',
    'Saket Select Citywalk, South Delhi',
  ];

  @override
  void initState() {
    super.initState();
    _startController = TextEditingController(text: widget.initialStartLocation);
    _destController = TextEditingController(text: 'Hauz Khas Village, South Delhi');
    _vehicleController = TextEditingController(text: 'DL 1Y B 4821');
    _selectedContactIds = widget.contacts.map((c) => c.id).toSet();

    _updatePredictions();
  }

  @override
  void dispose() {
    _startController.dispose();
    _destController.dispose();
    _vehicleController.dispose();
    super.dispose();
  }

  void _swapLocations() {
    setState(() {
      final temp = _startController.text;
      _startController.text = _destController.text;
      _destController.text = temp;
      _updatePredictions();
    });
  }

  double _estimateDistanceKm() {
    switch (_selectedMode) {
      case TransportMode.walking:
        return 2.8;
      case TransportMode.auto:
        return 8.5;
      case TransportMode.metro:
        return 14.2;
      case TransportMode.cab:
      case TransportMode.bus:
      default:
        return 12.4;
    }
  }

  TrafficEstimation _getTrafficEstimation() {
    final hour = DateTime.now().hour + (DateTime.now().minute / 60.0);

    if (hour >= 8.0 && hour < 11.5) {
      return const TrafficEstimation(
        congestionMultiplier: 1.45,
        statusLabel: 'Morning Peak (+45%)',
        description: 'Heavy arterial congestion & peak junction signal cycles',
        badgeColor: AppColors.warningAmber,
        icon: Icons.traffic_rounded,
      );
    } else if (hour >= 17.0 && hour < 21.5) {
      return const TrafficEstimation(
        congestionMultiplier: 1.50,
        statusLabel: 'Evening Peak (+50%)',
        description: 'Heavy commuter bottlenecks across primary corridors',
        badgeColor: AppColors.emergencyRedBright,
        icon: Icons.traffic_rounded,
      );
    } else if (hour >= 11.5 && hour < 17.0) {
      return const TrafficEstimation(
        congestionMultiplier: 1.20,
        statusLabel: 'Daytime Flow (+20%)',
        description: 'Moderate steady flow with active intersection lights',
        badgeColor: AppColors.safeGreen,
        icon: Icons.speed_rounded,
      );
    }
    return const TrafficEstimation(
      congestionMultiplier: 1.00,
      statusLabel: 'Night Free-Flow (0%)',
      description: 'Clear arterial roads and fast signal progression',
      badgeColor: AppColors.primaryViolet,
      icon: Icons.nightlight_round,
    );
  }

  DynamicTimingPrediction _calculateDynamicTiming({
    required double distanceKm,
    required TransportMode mode,
  }) {
    final traffic = _getTrafficEstimation();

    switch (mode) {
      case TransportMode.walking:
        const speedKmh = 4.6;
        final baseMinutes = math.max(5, ((distanceKm / speedKmh) * 60).round() + 2);
        return DynamicTimingPrediction(
          totalMinutes: baseMinutes,
          baseTravelMinutes: baseMinutes,
          trafficDelayMinutes: 0,
          averageSpeedKmh: speedKmh,
          modeRationale: 'Pedestrian pace (~4.6 km/h) • Road traffic exempt',
          traffic: const TrafficEstimation(
            congestionMultiplier: 1.0,
            statusLabel: 'Pedestrian Pace',
            description: 'Sidewalk route immune to vehicular road traffic',
            badgeColor: AppColors.safeGreen,
            icon: Icons.directions_walk_rounded,
          ),
        );

      case TransportMode.auto:
        final baseSpeed = 24.0;
        final autoTraffic = 1.0 + (traffic.congestionMultiplier - 1.0) * 0.85;
        final effectiveSpeed = baseSpeed / autoTraffic;
        final baseMins = ((distanceKm / baseSpeed) * 60).round() + 4;
        final totalMins = math.max(8, ((distanceKm / effectiveSpeed) * 60).round() + 4);
        return DynamicTimingPrediction(
          totalMinutes: totalMins,
          baseTravelMinutes: baseMins,
          trafficDelayMinutes: math.max(0, totalMins - baseMins),
          averageSpeedKmh: effectiveSpeed,
          modeRationale: 'Auto city transit • Agile lane filtering',
          traffic: traffic,
        );

      case TransportMode.metro:
        const totalMins = 24;
        return DynamicTimingPrediction(
          totalMinutes: totalMins,
          baseTravelMinutes: totalMins,
          trafficDelayMinutes: 0,
          averageSpeedKmh: 34.0,
          modeRationale: 'Rapid rail • 100% immune to road traffic jams',
          traffic: const TrafficEstimation(
            congestionMultiplier: 1.0,
            statusLabel: 'Dedicated Rail Line',
            description: 'Grade-separated line unaffected by surface traffic',
            badgeColor: AppColors.primaryViolet,
            icon: Icons.subway_rounded,
          ),
        );

      case TransportMode.cab:
      default:
        const baseSpeed = 32.0;
        final effectiveSpeed = baseSpeed / traffic.congestionMultiplier;
        final baseMins = ((distanceKm / baseSpeed) * 60).round() + 5;
        final totalMins = math.max(10, ((distanceKm / effectiveSpeed) * 60).round() + 5);
        return DynamicTimingPrediction(
          totalMinutes: totalMins,
          baseTravelMinutes: baseMins,
          trafficDelayMinutes: math.max(0, totalMins - baseMins),
          averageSpeedKmh: effectiveSpeed,
          modeRationale: 'City cab transit (~32 km/h base)',
          traffic: traffic,
        );
    }
  }

  DynamicCheckInRecommendation _calculateCheckInRecommendation({
    required TransportMode mode,
    required double distanceKm,
  }) {
    final hour = DateTime.now().hour;
    final isNight = hour >= 21 || hour < 5;
    final isEvening = hour >= 18 && hour < 21;

    if (mode == TransportMode.walking) {
      return DynamicCheckInRecommendation(
        recommendedIntervalMinutes: 5,
        safetyTier: 'High Alert',
        rationale: isNight
            ? 'Night Pedestrian: Maximum vigilance active for unlit/silent streets'
            : (isEvening
                ? 'Dusk Walking: 5 min check-ins armed for foot transit'
                : 'Pedestrian Route: Silent footpaths require frequent 5 min check-ins'),
        crowdContext: 'Direct Pedestrian Exposure',
        tierColor: AppColors.warningAmber,
        icon: Icons.directions_walk_rounded,
      );
    }

    if (isNight) {
      return const DynamicCheckInRecommendation(
        recommendedIntervalMinutes: 5,
        safetyTier: 'High Alert',
        rationale: 'Late Night Transit: Elevated safety corridor with 5 min check-ins',
        crowdContext: 'Night Transit Corridor',
        tierColor: AppColors.warningAmber,
        icon: Icons.nightlight_round,
      );
    }

    if (mode == TransportMode.metro) {
      return const DynamicCheckInRecommendation(
        recommendedIntervalMinutes: 20,
        safetyTier: 'Relaxed',
        rationale: 'Monitored Rapid Transit: High security station coverage',
        crowdContext: 'Public Transit Corridor',
        tierColor: AppColors.safeGreen,
        icon: Icons.subway_rounded,
      );
    }

    return const DynamicCheckInRecommendation(
      recommendedIntervalMinutes: 10,
      safetyTier: 'Balanced',
      rationale: 'Standard City Escort: 10 min periodic safety check-in corridor',
      crowdContext: 'Urban Transit Hub',
      tierColor: AppColors.primaryViolet,
      icon: Icons.shield_rounded,
    );
  }

  void _updatePredictions() {
    final dist = _estimateDistanceKm();
    final timing = _calculateDynamicTiming(distanceKm: dist, mode: _selectedMode);
    final checkIn = _calculateCheckInRecommendation(mode: _selectedMode, distanceKm: dist);

    setState(() {
      _durationMinutes = timing.totalMinutes;
      _checkInInterval = checkIn.recommendedIntervalMinutes;
    });
  }

  String get _expectedArrivalTime {
    final arrivalTime = DateTime.now().add(Duration(minutes: _durationMinutes));
    return DateFormat('hh:mm a').format(arrivalTime);
  }

  void _submitJourney() {
    final start = _startController.text.trim().isEmpty ? 'Current Location' : _startController.text.trim();
    final dest = _destController.text.trim().isEmpty ? 'Selected Destination' : _destController.text.trim();
    final vehicle = _vehicleController.text.trim();

    widget.onStartJourney(
      start,
      dest,
      _selectedMode,
      vehicle,
      _durationMinutes,
      _checkInInterval,
      _geofenceEnabled,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dist = _estimateDistanceKm();
    final timing = _calculateDynamicTiming(distanceKm: dist, mode: _selectedMode);
    final checkIn = _calculateCheckInRecommendation(mode: _selectedMode, distanceKm: dist);

    return Scaffold(
      backgroundColor: isDark ? AppColors.midnightDarkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('Configure Protected Journey', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: widget.onBack,
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Route Locations Card with Swap
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.midnightDarkSurface : AppColors.lightSurface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark ? AppColors.midnightDarkCardBorder : AppColors.lightCardBorder,
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(
                          children: [
                            const SizedBox(height: 12),
                            Container(
                              width: 10,
                              height: 10,
                              decoration: const BoxDecoration(
                                color: AppColors.safeGreen,
                                shape: BoxShape.circle,
                              ),
                            ),
                            Container(
                              width: 2,
                              height: 44,
                              color: isDark ? AppColors.midnightDarkCardBorder : AppColors.lightCardBorder,
                            ),
                            Container(
                              width: 10,
                              height: 10,
                              decoration: const BoxDecoration(
                                color: AppColors.primaryViolet,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            children: [
                              TextField(
                                controller: _startController,
                                decoration: const InputDecoration(
                                  labelText: 'Starting Point',
                                  prefixIcon: Icon(Icons.my_location, size: 20),
                                  isDense: true,
                                ),
                                onChanged: (_) => _updatePredictions(),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: _destController,
                                decoration: const InputDecoration(
                                  labelText: 'Destination Address',
                                  prefixIcon: Icon(Icons.place, size: 20),
                                  isDense: true,
                                ),
                                onChanged: (_) => _updatePredictions(),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: _swapLocations,
                          icon: const Icon(Icons.swap_vert, color: AppColors.primaryViolet),
                          tooltip: 'Swap locations',
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Quick Preset Chips
                    SizedBox(
                      height: 32,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _locationPresets.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 6),
                        itemBuilder: (context, idx) {
                          final preset = _locationPresets[idx];
                          return ActionChip(
                            label: Text(
                              preset.split(',').first,
                              style: const TextStyle(fontSize: 11),
                            ),
                            onPressed: () {
                              setState(() {
                                _destController.text = preset;
                                _updatePredictions();
                              });
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 2. Transport Mode Selector
              const Text('Transport Mode', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: TransportMode.values.map((mode) {
                  final isSelected = mode == _selectedMode;
                  return ChoiceChip(
                    avatar: Icon(
                      mode.icon,
                      size: 18,
                      color: isSelected ? Colors.white : (isDark ? AppColors.textSecondary : Colors.black87),
                    ),
                    label: Text(mode.label),
                    selected: isSelected,
                    selectedColor: AppColors.primaryViolet,
                    onSelected: (val) {
                      if (val) {
                        setState(() {
                          _selectedMode = mode;
                          _updatePredictions();
                        });
                      }
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // 3. Dynamic Traffic & Timing Prediction Card
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
                            Icon(timing.traffic.icon, color: timing.traffic.badgeColor, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              timing.traffic.statusLabel,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: timing.traffic.badgeColor,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          'ETA: $_expectedArrivalTime',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      timing.traffic.description,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.textSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Estimated Duration: $_durationMinutes min', style: const TextStyle(fontWeight: FontWeight.w600)),
                        Text('${dist.toStringAsFixed(1)} km (~${timing.averageSpeedKmh.toStringAsFixed(0)} km/h)',
                            style: TextStyle(fontSize: 12, color: isDark ? AppColors.textMuted : AppColors.lightTextSecondary)),
                      ],
                    ),
                    Slider(
                      value: _durationMinutes.toDouble(),
                      min: 5,
                      max: 120,
                      divisions: 23,
                      activeColor: AppColors.primaryViolet,
                      label: '$_durationMinutes min',
                      onChanged: (val) {
                        setState(() {
                          _durationMinutes = val.round();
                        });
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 4. Adaptive Check-In Recommendation Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      checkIn.tierColor.withValues(alpha: isDark ? 0.2 : 0.08),
                      (isDark ? AppColors.midnightDarkSurface : AppColors.lightSurface),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: checkIn.tierColor.withValues(alpha: 0.4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(checkIn.icon, color: checkIn.tierColor, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Adaptive Check-In: ${checkIn.safetyTier}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: checkIn.tierColor,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          'Every $_checkInInterval min',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: checkIn.tierColor,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      checkIn.rationale,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.textSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [5, 10, 15, 20].map((mins) {
                        final isSel = _checkInInterval == mins;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: ChoiceChip(
                            label: Text('$mins min'),
                            selected: isSel,
                            selectedColor: checkIn.tierColor,
                            onSelected: (val) {
                              if (val) setState(() => _checkInInterval = mins);
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 5. Vehicle / Driver Registration
              TextField(
                controller: _vehicleController,
                decoration: const InputDecoration(
                  labelText: 'Vehicle / Driver Registration (Optional)',
                  prefixIcon: Icon(Icons.badge, size: 20),
                  helperText: 'Attached to emergency dispatch beacons if distress is flagged',
                ),
              ),
              const SizedBox(height: 16),

              // 6. Trusted Emergency Circle Selection
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
                        const Text('Alert Guardians on Escalation', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        Text('${_selectedContactIds.length}/${widget.contacts.length} Selected',
                            style: const TextStyle(fontSize: 12, color: AppColors.primaryViolet, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    widget.contacts.isEmpty
                        ? const Text('No trusted contacts saved. Go to Contacts to add guardians.', style: TextStyle(fontSize: 12))
                        : Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: widget.contacts.map((contact) {
                              final isSelected = _selectedContactIds.contains(contact.id);
                              return FilterChip(
                                label: Text('${contact.name} (${contact.relationship})'),
                                selected: isSelected,
                                selectedColor: AppColors.primaryViolet.withValues(alpha: 0.3),
                                onSelected: (val) {
                                  setState(() {
                                    if (val) {
                                      _selectedContactIds.add(contact.id);
                                    } else {
                                      _selectedContactIds.remove(contact.id);
                                    }
                                  });
                                },
                              );
                            }).toList(),
                          ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 7. Route Corridor Geofence Toggle
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Real-Time Route Corridor Geofence', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: const Text('Alerts circle if path deviates significantly from expected transit line',
                    style: TextStyle(fontSize: 12)),
                value: _geofenceEnabled,
                activeThumbColor: AppColors.primaryViolet,
                activeTrackColor: AppColors.primaryViolet.withValues(alpha: 0.5),
                onChanged: (val) => setState(() => _geofenceEnabled = val),
              ),
              const SizedBox(height: 16),

              // 8. Vector Route Corridor Preview
              Container(
                height: 160,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.midnightDarkSurface : AppColors.lightSurface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isDark ? AppColors.midnightDarkCardBorder : AppColors.lightCardBorder,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: InteractiveMapCanvas(
                  progress: 0.05,
                  startLabel: _startController.text,
                  destinationLabel: _destController.text,
                  speedKmh: 0,
                  height: 160,
                ),
              ),
              const SizedBox(height: 24),

              // 9. Swipe Action to Start Journey
              SwipeActionControl(
                label: 'Swipe to Begin Protected Journey',
                onConfirmed: _submitJourney,
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
