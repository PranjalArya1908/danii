import 'package:flutter/material.dart';
import '../models/models.dart';
import '../theme/app_colors.dart';
import '../widgets/interactive_map_canvas.dart';

class SafetyHistoryScreen extends StatefulWidget {
  final List<Journey> journeys;
  final List<SafetyEvent> events;
  final Journey? selectedJourney;
  final ValueChanged<Journey?> onSelectJourney;
  final VoidCallback? onBack;

  const SafetyHistoryScreen({
    super.key,
    required this.journeys,
    required this.events,
    required this.selectedJourney,
    required this.onSelectJourney,
    this.onBack,
  });

  @override
  State<SafetyHistoryScreen> createState() => _SafetyHistoryScreenState();
}

class _SafetyHistoryScreenState extends State<SafetyHistoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _formatDate(int timestamp) {
    final dt = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final day = dt.day.toString().padLeft(2, '0');
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final month = months[dt.month - 1];
    final hour = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
    final minute = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$day $month, $hour:$minute $ampm';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.midnightDarkBackground : AppColors.lightBackground,
      appBar: AppBar(
        leading: widget.onBack != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: widget.onBack,
              )
            : null,
        title: const Text(
          'Safety & Journey History',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primaryViolet,
          labelColor: AppColors.primaryViolet,
          unselectedLabelColor: isDark ? AppColors.textSecondary : AppColors.lightTextSecondary,
          tabs: [
            Tab(text: 'Protected Journeys (${widget.journeys.length})'),
            Tab(text: 'Security Log (${widget.events.length})'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildJourneysTab(isDark),
          _buildEventsTab(isDark),
        ],
      ),
    );
  }

  Widget _buildJourneysTab(bool isDark) {
    if (widget.journeys.isEmpty) {
      return const Center(child: Text('No past journeys recorded yet.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      itemCount: widget.journeys.length,
      itemBuilder: (context, index) {
        final journey = widget.journeys[index];
        final isSelected = widget.selectedJourney?.id == journey.id;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: isDark ? AppColors.midnightDarkSurface : AppColors.lightSurface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isSelected
                  ? AppColors.primaryViolet
                  : (isDark ? AppColors.midnightDarkCardBorder : AppColors.lightCardBorder),
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(18),
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () {
                widget.onSelectJourney(isSelected ? null : journey);
              },
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              journey.transportMode.icon,
                              color: AppColors.primaryViolet,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              journey.transportMode.label,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.primaryViolet,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.safeGreen.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Safely Reached',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppColors.safeGreen,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      journey.destinationAddress,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'From ${journey.startAddress} • ${_formatDate(journey.startTimeMillis)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.textSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                    if (journey.notes.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        journey.notes,
                        style: TextStyle(
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                          color: isDark ? AppColors.textSecondary : AppColors.lightTextSecondary,
                        ),
                      ),
                    ],

                    // Expanded map replay preview
                    if (isSelected) ...[
                      const SizedBox(height: 14),
                      InteractiveMapCanvas(
                        height: 160,
                        progress: 1.0,
                        journeyStatus: JourneyStatus.completed,
                        startLabel: journey.startAddress.split(',').first,
                        destinationLabel: journey.destinationAddress.split(',').first,
                        speedKmh: 0,
                        isReplay: true,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEventsTab(bool isDark) {
    if (widget.events.isEmpty) {
      return const Center(child: Text('No security events recorded.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      itemCount: widget.events.length,
      itemBuilder: (context, index) {
        final ev = widget.events[index];
        final (badgeColor, badgeText) = switch (ev.severity) {
          EventSeverity.critical => (AppColors.emergencyRed, 'CRITICAL'),
          EventSeverity.warning => (AppColors.warningAmber, 'WARNING'),
          EventSeverity.success => (AppColors.safeGreen, 'CONFIRMED'),
          _ => (AppColors.infoBlue, 'INFO'),
        };

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
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
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: badgeColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          badgeText,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: badgeColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        ev.title,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ],
                  ),
                  Text(
                    _formatDate(ev.timestamp),
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                ev.description,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? AppColors.textSecondary : AppColors.lightTextSecondary,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.location_on, size: 12, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    ev.location,
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

