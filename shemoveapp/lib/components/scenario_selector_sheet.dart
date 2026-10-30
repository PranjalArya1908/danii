import 'package:flutter/material.dart';
import '../theme/colors.dart';

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
  final VoidCallback onDismiss;
  final ValueChanged<String> onSelectScenario;

  const ScenarioSelectorSheet({
    super.key,
    required this.isOnline,
    required this.onDismiss,
    required this.onSelectScenario,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final scenarios = [
      const ScenarioOption(
        id: 'normal_journey',
        title: '1. Normal Protected Journey',
        subtitle: 'Active journey with live GPS progress & scheduled check-ins',
        icon: Icons.directions_car,
        badgeColor: SafeLoopColors.safeGreen,
      ),
      const ScenarioOption(
        id: 'trigger_checkin',
        title: '2. Trigger Safety Check-In',
        subtitle: "Opens 'Are you safe right now?' swipe check-in flow",
        icon: Icons.shield,
        badgeColor: SafeLoopColors.primaryViolet,
      ),
      const ScenarioOption(
        id: 'test_duress_pin',
        title: '3. Test Discreet Duress PIN (9999)',
        subtitle: 'Simulates silent distress: appears safe to attacker while alerting contacts',
        icon: Icons.lock,
        badgeColor: SafeLoopColors.vibrantLavender,
      ),
      const ScenarioOption(
        id: 'missed_checkin',
        title: '4. Missed Check-In & Escalation',
        subtitle: '45-second amber grace period with auto escalation to contacts',
        icon: Icons.timer,
        badgeColor: SafeLoopColors.warningAmber,
      ),
      const ScenarioOption(
        id: 'critical_sos',
        title: '5. Instant Emergency SOS',
        subtitle: 'Emergency screen with live telemetry & contact delivery states',
        icon: Icons.warning,
        badgeColor: SafeLoopColors.emergencyRed,
      ),
      const ScenarioOption(
        id: 'safe_arrival',
        title: '6. Safe Destination Reached',
        subtitle: 'Arrival celebration & contact notification confirmation',
        icon: Icons.check_circle,
        badgeColor: SafeLoopColors.safeGreen,
      ),
      ScenarioOption(
        id: 'toggle_offline',
        title: isOnline ? '7. Simulate Cellular Network Loss' : '7. Reconnect Cellular Network',
        subtitle: isOnline
            ? 'Switches app to offline encrypted SMS mode'
            : 'Restores live cloud sync',
        icon: isOnline ? Icons.signal_cellular_off : Icons.signal_cellular_alt,
        badgeColor: SafeLoopColors.infoBlue,
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24.0)),
      ),
      padding: const EdgeInsets.only(left: 20, right: 20, top: 12, bottom: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.outline,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Demo Scenario Selector',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    'Simulate state transitions & safety scenarios',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              IconButton(
                onPressed: onDismiss,
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // List of options
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: scenarios.length,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final item = scenarios[index];
                return Material(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      onSelectScenario(item.id);
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(14.0),
                      child: Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: item.badgeColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              item.icon,
                              color: item.badgeColor,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.title,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  item.subtitle,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.chevron_right,
                            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                            size: 20,
                          ),
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

