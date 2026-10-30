import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/models.dart';
import '../theme/colors.dart';

class JourneyCompletionScreen extends StatefulWidget {
  final Journey? journey;
  final VoidCallback onCloseJourney;

  const JourneyCompletionScreen({
    super.key,
    required this.journey,
    required this.onCloseJourney,
  });

  @override
  State<JourneyCompletionScreen> createState() => _JourneyCompletionScreenState();
}

class _JourneyCompletionScreenState extends State<JourneyCompletionScreen> {
  bool _concernReported = false;

  void _showConcernDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Report Route Safety Issue', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Help protect other women by tagging any hazards along this path:',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            ...[
              'Dim / Broken Streetlights',
              'Isolated / Unstaffed Stretch',
              'Suspicious Vehicle Following',
              'Safe & Well-Lit Route',
            ].map((tag) {
              return Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 8.0),
                child: Material(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () {
                      Navigator.of(ctx).pop();
                      setState(() {
                        _concernReported = true;
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Text(tag, style: const TextStyle(fontWeight: FontWeight.w500)),
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.midnightDarkBackground : AppColors.lightBackground,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final destText = (widget.journey != null && widget.journey!.destinationAddress.isNotEmpty)
                ? widget.journey!.destinationAddress
                : 'Destination';
            final modeText = widget.journey != null ? widget.journey!.transportMode.label : 'Cab / Taxi';
            final startText = (widget.journey != null && widget.journey!.startAddress.isNotEmpty)
                ? widget.journey!.startAddress
                : 'Origin';
            final durationText = '${widget.journey?.estimatedMinutes ?? 25} minutes';

            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: math.max(0.0, constraints.maxHeight - 40.0),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // 1. Celebration Emblem & Title
                    Column(
                      children: [
                        const SizedBox(height: 24),
                        Container(
                          width: 90,
                          height: 90,
                          decoration: BoxDecoration(
                            color: AppColors.safeGreen.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Center(
                            child: Icon(Icons.check_circle, color: AppColors.safeGreen, size: 54),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'You\'ve Arrived Safely',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppColors.textPrimary : AppColors.lightTextPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Safe arrival verified at $destText.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark ? AppColors.textSecondary : AppColors.lightTextSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // 2. Journey Summary Card
                    Container(
                      padding: const EdgeInsets.all(18),
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
                          const Text(
                            'Journey Summary',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 14),
                          _buildRow(
                            icon: Icons.directions,
                            label: 'Transit Mode',
                            value: modeText,
                            isDark: isDark,
                          ),
                          const Divider(height: 18),
                          _buildRow(
                            icon: Icons.timer,
                            label: 'Duration',
                            value: durationText,
                            isDark: isDark,
                          ),
                          const Divider(height: 18),
                          _buildRow(
                            icon: Icons.my_location,
                            label: 'Origin',
                            value: startText,
                            isDark: isDark,
                          ),
                          const Divider(height: 18),
                          _buildRow(
                            icon: Icons.location_on,
                            label: 'Destination',
                            value: destText,
                            isDark: isDark,
                          ),
                          const Divider(height: 18),
                          const Row(
                            children: [
                              Icon(Icons.check, color: AppColors.safeGreen, size: 18),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Trusted Circle notified of safe arrival',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.safeGreen,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 3. Route Hazard Feedback Button
                    if (!_concernReported)
                      TextButton.icon(
                        onPressed: () => _showConcernDialog(context),
                        icon: const Icon(Icons.flag_outlined, size: 18, color: AppColors.primaryViolet),
                        label: const Text(
                          'Tag Route Safety Issue / Hazard',
                          style: TextStyle(color: AppColors.primaryViolet, fontWeight: FontWeight.w600),
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.safeGreen.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle_outline, color: AppColors.safeGreen, size: 16),
                            SizedBox(width: 6),
                            Text(
                              'Thank you for reporting safety feedback',
                              style: TextStyle(color: AppColors.safeGreen, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 20),

                    // 4. Return to Home button
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton(
                        onPressed: () {
                          try {
                            widget.onCloseJourney();
                          } catch (e) {
                            debugPrint('Error navigating to home from completion: $e');
                          }
                          if (context.mounted && Navigator.of(context).canPop()) {
                            Navigator.of(context).pop();
                          }
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primaryViolet,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: const Text(
                          'Return to Home',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildRow({
    required IconData icon,
    required String label,
    required String value,
    required bool isDark,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: Colors.grey),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? AppColors.textSecondary : AppColors.lightTextSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.end,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
        ),
      ],
    );
  }
}
