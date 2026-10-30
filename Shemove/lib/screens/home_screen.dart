import 'package:flutter/material.dart';
import '../models/models.dart';
import '../theme/app_colors.dart';
import '../widgets/circular_journey_launcher.dart';
import '../widgets/satellite_map_view.dart';

class HomeScreen extends StatefulWidget {
  final UserProfile userProfile;
  final List<TrustedContact> contacts;
  final List<Journey> recentJourneys;
  final LatLngPoint currentLocation;
  final double currentHeading;
  final bool isOnline;
  final bool isCovertActive;
  final bool hasActiveJourney;
  final Journey? activeJourney;
  final bool hasLocationPermission;
  final bool isLocationLoading;
  final bool isLiveGpsActive;
  final String? locationStatusMessage;
  final VoidCallback onStartJourneyClick;
  final VoidCallback onViewActiveJourney;
  final VoidCallback onQuickEmergency;
  final VoidCallback onOpenContacts;
  final VoidCallback onOpenScenarios;
  final VoidCallback onOpenSettings;
  final VoidCallback onViewHistory;
  final VoidCallback onToggleTheme;
  final VoidCallback? onRequestLocation;
  final VoidCallback? onRefreshLocation;

  const HomeScreen({
    super.key,
    required this.userProfile,
    required this.contacts,
    required this.recentJourneys,
    this.currentLocation = const LatLngPoint(
      latitude: 28.4595,
      longitude: 77.0266,
      address: 'MG Road, Sector 28, Gurugram',
    ),
    this.currentHeading = 0.0,
    required this.isOnline,
    required this.isCovertActive,
    required this.hasActiveJourney,
    this.activeJourney,
    this.hasLocationPermission = false,
    this.isLocationLoading = false,
    this.isLiveGpsActive = false,
    this.locationStatusMessage,
    required this.onStartJourneyClick,
    required this.onViewActiveJourney,
    required this.onQuickEmergency,
    required this.onOpenContacts,
    required this.onOpenScenarios,
    required this.onOpenSettings,
    required this.onViewHistory,
    required this.onToggleTheme,
    this.onRequestLocation,
    this.onRefreshLocation,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _getTimeGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) return 'Good morning';
    if (hour >= 12 && hour < 17) return 'Good afternoon';
    if (hour >= 17 && hour < 22) return 'Good evening';
    return 'Good night';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.midnightDarkBackground : AppColors.lightBackground,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            // 1. Top Header: User Greeting & Actions (NO letter profile icon)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_getTimeGreeting()},',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppColors.textSecondary : AppColors.lightTextSecondary,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.userProfile.name,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                          color: isDark ? AppColors.textPrimary : AppColors.lightTextPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
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
                              widget.hasActiveJourney
                                  ? 'Protected Escort Active • Monitored'
                                  : (widget.contacts.isNotEmpty
                                      ? '${widget.contacts.length} guardians quietly standing by'
                                      : 'SheMove protection ready'),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: widget.hasActiveJourney
                                    ? AppColors.safeGreen
                                    : (isDark ? AppColors.textMuted : AppColors.lightTextSecondary),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Theme toggle
                    IconButton.filledTonal(
                      onPressed: widget.onToggleTheme,
                      style: IconButton.styleFrom(
                        backgroundColor: isDark
                            ? AppColors.midnightDarkSurfaceVariant
                            : AppColors.lightSurfaceVariant,
                      ),
                      icon: Icon(
                        isDark ? Icons.light_mode : Icons.dark_mode,
                        color: isDark ? AppColors.warningAmber : AppColors.primaryCobalt,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Scenarios sheet button
                    IconButton.filledTonal(
                      onPressed: widget.onOpenScenarios,
                      style: IconButton.styleFrom(
                        backgroundColor: isDark
                            ? AppColors.midnightDarkSurfaceVariant
                            : AppColors.lightSurfaceVariant,
                      ),
                      icon: const Icon(
                        Icons.science,
                        color: AppColors.primaryCobalt,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Settings button
                    IconButton.filledTonal(
                      onPressed: widget.onOpenSettings,
                      style: IconButton.styleFrom(
                        backgroundColor: isDark
                            ? AppColors.midnightDarkSurfaceVariant
                            : AppColors.lightSurfaceVariant,
                      ),
                      icon: Icon(
                        Icons.settings,
                        color: isDark ? AppColors.textSecondary : AppColors.lightTextSecondary,
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Offline or Covert Status Banners
            if (!widget.isOnline) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.warningAmber.withValues(alpha: isDark ? 0.2 : 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.warningAmber),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.signal_cellular_off, color: AppColors.warningAmber, size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Offline Mode: Encrypted SMS & Mesh telemetry enabled',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],

            if (widget.isCovertActive) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.safeGreen.withValues(alpha: isDark ? 0.2 : 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.safeGreen),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.shield, color: AppColors.safeGreen, size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Silent Duress Active: Covert GPS broadcasting to contacts',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: isDark ? AppColors.safeGreenGlow : AppColors.safeGreen,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],

            // 5. Interactive Circular Journey Launcher Card
            CircularJourneyLauncher(
              hasActiveJourney: widget.hasActiveJourney,
              activeJourney: widget.activeJourney,
              onStartJourney: widget.onStartJourneyClick,
              onViewActiveJourney: widget.onViewActiveJourney,
              onQuickEmergency: widget.onQuickEmergency,
              contactsCount: widget.contacts.length,
              isGpsLocked: widget.isLiveGpsActive && widget.hasLocationPermission,
            ),
            const SizedBox(height: 16),

            // Location Permission Banner (if needed)
            if (!widget.hasLocationPermission) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primaryCobalt.withValues(alpha: isDark ? 0.22 : 0.12),
                      AppColors.electricCyan.withValues(alpha: isDark ? 0.14 : 0.06),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: AppColors.primaryCobalt.withValues(alpha: isDark ? 0.45 : 0.35),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primaryCobalt.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.location_on, color: AppColors.primaryCobalt, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Real-Time Location Access Required',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? AppColors.textPrimary : AppColors.lightTextPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'SheMove needs precise GPS permission to display real-time satellite telemetry, track transit safety, and broadcast live coordinates to your emergency circle.',
                                style: TextStyle(
                                  fontSize: 12,
                                  height: 1.4,
                                  color: isDark ? AppColors.textSecondary : AppColors.lightTextSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: FilledButton.icon(
                        onPressed: widget.isLocationLoading ? null : widget.onRequestLocation,
                        icon: widget.isLocationLoading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.my_location, size: 18),
                        label: Text(
                          widget.isLocationLoading ? 'Requesting GPS Permission...' : 'Allow Real-Time Location',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primaryCobalt,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

            // 8. Live Satellite Telemetry Area
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Current Telemetry Area',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppColors.textPrimary : AppColors.lightTextPrimary,
                          ),
                        ),
                        if (widget.isLocationLoading) ...[
                          const SizedBox(width: 8),
                          const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(strokeWidth: 1.5, color: AppColors.primaryCobalt),
                          ),
                        ],
                      ],
                    ),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: (widget.hasLocationPermission ? AppColors.safeGreen : AppColors.warningAmber)
                                .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: (widget.hasLocationPermission ? AppColors.safeGreen : AppColors.warningAmber)
                                  .withValues(alpha: 0.35),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                widget.hasLocationPermission ? Icons.satellite_alt : Icons.location_off,
                                size: 12,
                                color: widget.hasLocationPermission ? AppColors.safeGreen : AppColors.warningAmber,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                widget.hasLocationPermission
                                    ? (widget.isLiveGpsActive ? 'LIVE GPS LOCKED' : 'GPS READY')
                                    : 'PERM REQUIRED',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: widget.hasLocationPermission ? AppColors.safeGreen : AppColors.warningAmber,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (widget.hasLocationPermission && widget.onRefreshLocation != null) ...[
                          const SizedBox(width: 4),
                          IconButton(
                            onPressed: widget.isLocationLoading ? null : widget.onRefreshLocation,
                            icon: const Icon(Icons.refresh, size: 16),
                            visualDensity: VisualDensity.compact,
                            tooltip: 'Refresh GPS Telemetry',
                            color: isDark ? AppColors.textSecondary : AppColors.lightTextSecondary,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SatelliteMapView(
                  location: widget.currentLocation,
                  heading: widget.currentHeading,
                  height: 250,
                  isInteractive: true,
                  showControls: true,
                ),
              ],
            ),
            const SizedBox(height: 18),

            // 9. Trusted Emergency Circle Preview with direct Manage Navigation
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Trusted Emergency Circle',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.safeGreen.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${widget.contacts.length} Active',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppColors.safeGreen,
                              ),
                            ),
                          ),
                        ],
                      ),
                      TextButton(
                        onPressed: widget.onOpenContacts,
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Manage',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primaryCobalt,
                              ),
                            ),
                            SizedBox(width: 2),
                            Icon(Icons.chevron_right, size: 16, color: AppColors.primaryCobalt),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (widget.contacts.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.midnightDarkSurfaceVariant.withValues(alpha: 0.5)
                            : AppColors.lightSurfaceVariant.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: AppColors.primaryCobalt.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.person_add_alt_1,
                            color: isDark ? AppColors.electricCyan : AppColors.primaryCobalt,
                            size: 28,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'No Emergency Contacts Yet',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: isDark ? AppColors.textPrimary : AppColors.lightTextPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Add trusted contacts from your phone to receive automatic SOS alerts.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? AppColors.textSecondary : AppColors.lightTextSecondary,
                            ),
                          ),
                          const SizedBox(height: 10),
                          FilledButton.icon(
                            onPressed: widget.onOpenContacts,
                            icon: const Icon(Icons.contacts, size: 15),
                            label: const Text(
                              'Add from Phone Contacts',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.primaryCobalt,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: widget.contacts.map((contact) {
                          return SizedBox(
                            width: 104,
                            child: InkWell(
                              onTap: widget.onOpenContacts,
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                margin: const EdgeInsets.symmetric(horizontal: 4),
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? AppColors.midnightDarkSurfaceVariant
                                      : AppColors.lightSurfaceVariant,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  children: [
                                    Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        color: AppColors.primaryCobalt.withValues(
                                          alpha: isDark ? 0.25 : 0.15,
                                        ),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Center(
                                        child: Text(
                                          contact.name.isNotEmpty
                                              ? contact.name.substring(0, 1)
                                              : 'C',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.primaryCobalt,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      contact.name.split(' ').first,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      contact.relationship,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 10,
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
                        }).toList(),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 10. Quick Distress Action Card
            Material(
              color: AppColors.emergencyRed.withValues(alpha: isDark ? 0.18 : 0.1),
              borderRadius: BorderRadius.circular(18),
              child: InkWell(
                onTap: widget.onQuickEmergency,
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: AppColors.emergencyRed.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: const BoxDecoration(
                              color: AppColors.emergencyRed,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.warning, color: Colors.white, size: 22),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Quick Distress Action',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: isDark
                                      ? AppColors.emergencyRedBright
                                      : AppColors.emergencyRed,
                                ),
                              ),
                              Text(
                                'Tap for instant emergency escalation',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark
                                      ? AppColors.textSecondary
                                      : AppColors.lightTextSecondary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Icon(
                        Icons.chevron_right,
                        color: isDark ? AppColors.emergencyRedBright : AppColors.emergencyRed,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 11. Recent Protected Journey Summary
            if (widget.recentJourneys.isNotEmpty) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Recent Protected Journey',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  TextButton(
                    onPressed: widget.onViewHistory,
                    child: const Text(
                      'View All',
                      style: TextStyle(color: AppColors.primaryCobalt),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.midnightDarkSurface : AppColors.lightSurface,
                  borderRadius: BorderRadius.circular(16),
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
                        Expanded(
                          child: Text(
                            widget.recentJourneys.first.destinationAddress,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Safely Reached',
                          style: TextStyle(
                            color: AppColors.safeGreen,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'From ${widget.recentJourneys.first.startAddress} • ${widget.recentJourneys.first.transportMode.label} • ${widget.recentJourneys.first.estimatedMinutes} min',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.textSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
