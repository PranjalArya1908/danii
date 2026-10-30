import 'package:flutter/material.dart';
import '../components/circular_journey_launcher.dart';
import '../components/interactive_map_canvas.dart';
import '../models/models.dart';
import '../theme/colors.dart';

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
  final VoidCallback? onOpenContacts;
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
    this.hasLocationPermission = true,
    this.isLocationLoading = false,
    this.isLiveGpsActive = true,
    this.locationStatusMessage,
    required this.onStartJourneyClick,
    required this.onViewActiveJourney,
    required this.onQuickEmergency,
    this.onOpenContacts,
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
              // 1. Top Header: User Greeting & Actions
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
                          color: isDark ? AppColors.warningAmber : AppColors.primaryViolet,
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
                          color: AppColors.primaryViolet,
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
                      const SizedBox(width: 10),
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

              // 2. Interactive Circular Journey Launcher Card (Aegis Core)
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
                        AppColors.primaryViolet.withValues(alpha: isDark ? 0.22 : 0.12),
                        AppColors.electricLavender.withValues(alpha: isDark ? 0.14 : 0.06),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: AppColors.primaryViolet.withValues(alpha: isDark ? 0.45 : 0.35),
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
                              color: AppColors.primaryViolet.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.location_on, color: AppColors.primaryViolet, size: 22),
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
                                  'SheMove needs location permission to monitor route corridors and broadcast live coordinates to your emergency circle.',
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
                            backgroundColor: AppColors.primaryViolet,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // 3. Live Telemetry Map Area
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
                              child: CircularProgressIndicator(strokeWidth: 1.5, color: AppColors.primaryViolet),
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
                  Container(
                    height: 220,
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.midnightDarkSurface : AppColors.lightSurface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isDark ? AppColors.midnightDarkCardBorder : AppColors.lightCardBorder,
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      children: [
                        InteractiveMapCanvas(
                          progress: widget.hasActiveJourney
                              ? (widget.activeJourney?.progressPercent ?? 0.35)
                              : 0.1,
                          speedKmh: widget.hasActiveJourney ? 38 : 0,
                          isOffline: !widget.isOnline,
                          height: 220,
                        ),
                        Positioned(
                          left: 12,
                          bottom: 12,
                          right: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: (isDark ? AppColors.midnightDarkSurface : Colors.white).withValues(alpha: 0.92),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isDark ? AppColors.midnightDarkCardBorder : AppColors.lightCardBorder,
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.place, color: AppColors.primaryViolet, size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    widget.currentLocation.address,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? AppColors.textPrimary : AppColors.lightTextPrimary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${widget.currentLocation.latitude.toStringAsFixed(4)}, ${widget.currentLocation.longitude.toStringAsFixed(4)}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: isDark ? AppColors.textMuted : AppColors.lightTextSecondary,
                                    fontFamily: 'monospace',
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
              const SizedBox(height: 18),

              // 4. Trusted Emergency Circle Preview
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
                        if (widget.onOpenContacts != null)
                          TextButton(
                            onPressed: widget.onOpenContacts,
                            child: const Text('Manage', style: TextStyle(color: AppColors.primaryViolet)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    widget.contacts.isEmpty
                        ? Text(
                            'No emergency contacts configured yet. Add trusted contacts so they can be alerted if an escalation occurs.',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? AppColors.textSecondary : AppColors.lightTextSecondary,
                            ),
                          )
                        : SizedBox(
                            height: 64,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: widget.contacts.length,
                              separatorBuilder: (_, _) => const SizedBox(width: 10),
                              itemBuilder: (context, index) {
                                final contact = widget.contacts[index];
                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? AppColors.midnightDarkSurfaceVariant
                                        : AppColors.lightSurfaceVariant,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: contact.isPrimary
                                          ? AppColors.primaryViolet.withValues(alpha: 0.6)
                                          : (isDark
                                              ? AppColors.midnightDarkCardBorder
                                              : AppColors.lightCardBorder),
                                      width: contact.isPrimary ? 1.5 : 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 18,
                                        backgroundColor: contact.isPrimary
                                            ? AppColors.primaryViolet
                                            : (isDark
                                                ? AppColors.midnightDarkCard
                                                : Colors.grey.shade300),
                                        child: Text(
                                          contact.name.isNotEmpty
                                              ? contact.name[0].toUpperCase()
                                              : '?',
                                          style: TextStyle(
                                            color: contact.isPrimary
                                                ? Colors.white
                                                : (isDark ? Colors.white70 : Colors.black87),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Text(
                                                contact.name,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 13,
                                                ),
                                              ),
                                              if (contact.isPrimary) ...[
                                                const SizedBox(width: 4),
                                                const Icon(
                                                  Icons.star,
                                                  color: AppColors.warningAmber,
                                                  size: 14,
                                                ),
                                              ],
                                            ],
                                          ),
                                          Text(
                                            contact.relationship,
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: isDark
                                                  ? AppColors.textSecondary
                                                  : AppColors.lightTextSecondary,
                                            ),
                                          ),
                                        ],
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
              const SizedBox(height: 16),

              // 5. Quick Distress Action Banner
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: widget.onQuickEmergency,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.emergencyRed.withValues(alpha: isDark ? 0.25 : 0.12),
                          AppColors.emergencyRedBright.withValues(alpha: isDark ? 0.15 : 0.06),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.emergencyRed.withValues(alpha: 0.6),
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
                              decoration: const BoxDecoration(
                                color: AppColors.emergencyRed,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.warning_rounded, color: Colors.white, size: 22),
                            ),
                            const SizedBox(width: 14),
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
                                const SizedBox(height: 2),
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

              // 6. Recent Protected Journey Summary
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
                        style: TextStyle(color: AppColors.primaryViolet),
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
