import 'package:flutter/material.dart';
import '../models/models.dart';
import '../theme/colors.dart';

class SafeLoopBottomBar extends StatelessWidget {
  final SafeLoopScreen currentScreen;
  final bool hasActiveJourney;
  final ValueChanged<SafeLoopScreen> onNavigate;
  final VoidCallback onQuickEmergency;

  const SafeLoopBottomBar({
    super.key,
    required this.currentScreen,
    required this.hasActiveJourney,
    required this.onNavigate,
    required this.onQuickEmergency,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);

    final items = [
      _NavItem(
        screen: SafeLoopScreen.home,
        label: 'Home',
        selectedIcon: Icons.home,
        unselectedIcon: Icons.home_outlined,
      ),
      _NavItem(
        screen: hasActiveJourney ? SafeLoopScreen.activeJourney : SafeLoopScreen.journeyPlanner,
        label: hasActiveJourney ? 'Active' : 'Journey',
        selectedIcon: Icons.directions_walk,
        unselectedIcon: Icons.directions_walk_outlined,
      ),
      _NavItem(
        screen: SafeLoopScreen.contacts,
        label: 'Contacts',
        selectedIcon: Icons.people,
        unselectedIcon: Icons.people_outline,
      ),
      _NavItem(
        screen: SafeLoopScreen.history,
        label: 'History',
        selectedIcon: Icons.history,
        unselectedIcon: Icons.history_outlined,
      ),
      _NavItem(
        screen: SafeLoopScreen.settings,
        label: 'Settings',
        selectedIcon: Icons.settings,
        unselectedIcon: Icons.settings_outlined,
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(color: theme.colorScheme.outline, width: 1.0),
        ),
      ),
      padding: EdgeInsets.only(
        top: 6,
        bottom: MediaQuery.of(context).padding.bottom + 6,
        left: 8,
        right: 8,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: items.map((item) {
          final isSelected = currentScreen == item.screen ||
              (item.screen == SafeLoopScreen.journeyPlanner && currentScreen == SafeLoopScreen.activeJourney) ||
              (item.screen == SafeLoopScreen.activeJourney && currentScreen == SafeLoopScreen.journeyPlanner);

          final contentColor = isSelected
              ? (isDark ? SafeLoopColors.electricLavender : SafeLoopColors.primaryViolet)
              : theme.colorScheme.onSurfaceVariant;

          return InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => onNavigate(item.screen),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected
                          ? SafeLoopColors.primaryViolet.withValues(alpha: isDark ? 0.2 : 0.12)
                          : Colors.transparent,
                    ),
                    child: Icon(
                      isSelected ? item.selectedIcon : item.unselectedIcon,
                      color: contentColor,
                      size: 22,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: contentColor,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _NavItem {
  final SafeLoopScreen screen;
  final String label;
  final IconData selectedIcon;
  final IconData unselectedIcon;

  const _NavItem({
    required this.screen,
    required this.label,
    required this.selectedIcon,
    required this.unselectedIcon,
  });
}

