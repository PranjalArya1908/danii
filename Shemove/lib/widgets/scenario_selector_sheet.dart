import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class ScenarioOption {
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color badgeColor;

  const ScenarioOption({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.badgeColor,
  });
}

class ScenarioSelectorSheet extends StatelessWidget {
  final bool isOnline;
  final ValueChanged<String> onSelectScenario;

  const ScenarioSelectorSheet({
    super.key,
    required this.isOnline,
    required this.onSelectScenario,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final scenarios = [
      const ScenarioOption(
        id: 'normal_journey',
        title: '1. Normal Protected Journey',
        subtitle: 'Active journey with live GPS progress & scheduled check-ins',
        icon: Icons.directions_car,
        badgeColor: AppColors.safeGreen,
      ),
      const ScenarioOption(
        id: 'trigger_checkin',
        title: '2. Trigger Safety Check-In',
        subtitle: 'Opens "Are you safe right now?" swipe check-in flow',
        icon: Icons.shield,
        badgeColor: AppColors.primaryViolet,
      ),
      const ScenarioOption(
        id: 'test_duress_pin',
        title: '3. Test Discreet Duress PIN (9999)',
        subtitle: 'Simulates silent distress: appears safe to attacker while alerting contacts',
        icon: Icons.lock,
        badgeColor: AppColors.vibrantLavender,
      ),
      const ScenarioOption(
        id: 'missed_checkin',
        title: '4. Missed Check-In & Escalation',
        subtitle: '45-second amber grace period with auto escalation to contacts',
        icon: Icons.timer,
        badgeColor: AppColors.warningAmber,
      ),
      const ScenarioOption(
        id: 'critical_sos',
        title: '5. Instant Emergency SOS',
        subtitle: 'Emergency screen with live telemetry & contact delivery states',
        icon: Icons.warning,
        badgeColor: AppColors.emergencyRed,
      ),
      const ScenarioOption(
        id: 'safe_arrival',
        title: '6. Safe Destination Reached',
        subtitle: 'Arrival celebration & contact notification confirmation',
        icon: Icons.check_circle,
        badgeColor: AppColors.safeGreen,
      ),
      ScenarioOption(
        id: 'toggle_offline',
        title: isOnline ? '7. Simulate Cellular Network Loss' : '7. Reconnect Cellular Network',
        subtitle: isOnline
            ? 'Switches app to offline encrypted SMS mode'
            : 'Restores live cloud sync',
        icon: isOnline ? Icons.signal_cellular_off : Icons.signal_cellular_alt,
        badgeColor: AppColors.infoBlue,
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.midnightDarkSurface : AppColors.lightSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.only(top: 12, bottom: 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryViolet.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.science,
                    color: AppColors.primaryViolet,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Demo Scenario Switcher',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppColors.textPrimary : AppColors.lightTextPrimary,
                        ),
                      ),
                      Text(
                        'Simulate real-time emergency events',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppColors.textSecondary : AppColors.lightTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),

          // List of scenario items
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: scenarios.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final scenario = scenarios[index];
                return Material(
                  color: isDark
                      ? AppColors.midnightDarkSurfaceVariant
                      : AppColors.lightSurfaceVariant,
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      Navigator.pop(context);
                      onSelectScenario(scenario.id);
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: scenario.badgeColor.withValues(alpha: 0.18),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              scenario.icon,
                              color: scenario.badgeColor,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  scenario.title,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: isDark
                                        ? AppColors.textPrimary
                                        : AppColors.lightTextPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  scenario.subtitle,
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
                          const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

