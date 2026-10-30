import 'package:flutter/material.dart';
import '../state/safeloop_state.dart';
import '../theme/app_colors.dart';

class SafeLoopBottomBar extends StatelessWidget {
  final SafeLoopScreen currentScreen;
  final bool hasActiveJourney;
  final ValueChanged<SafeLoopScreen> onNavigate;

  const SafeLoopBottomBar({
    super.key,
    required this.currentScreen,
    required this.hasActiveJourney,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final items = [
      (
        screen: SafeLoopScreen.home,
        label: 'Home',
        selectedIcon: Icons.home,
        unselectedIcon: Icons.home_outlined,
      ),
      (
        screen: hasActiveJourney ? SafeLoopScreen.activeJourney : SafeLoopScreen.journeyPlanner,
        label: hasActiveJourney ? 'Active' : 'Journey',
        selectedIcon: Icons.directions_walk,
        unselectedIcon: Icons.directions_walk_outlined,
      ),
      (
        screen: SafeLoopScreen.contacts,
        label: 'Contacts',
        selectedIcon: Icons.people,
        unselectedIcon: Icons.people_outline,
      ),
      (
        screen: SafeLoopScreen.history,
        label: 'History',
        selectedIcon: Icons.history,
        unselectedIcon: Icons.history_outlined,
      ),
      (
        screen: SafeLoopScreen.settings,
        label: 'Settings',
        selectedIcon: Icons.settings,
        unselectedIcon: Icons.settings_outlined,
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.midnightDarkSurface : AppColors.lightSurface,
        border: Border(
          top: BorderSide(
            color: isDark ? AppColors.midnightDarkCardBorder : AppColors.lightCardBorder,
            width: 1,
          ),
        ),
      ),
      padding: EdgeInsets.only(
        top: 6,
        bottom: MediaQuery.paddingOf(context).bottom + 6,
        left: 8,
        right: 8,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: items.map((item) {
          final isSelected = currentScreen == item.screen ||
              (item.screen == SafeLoopScreen.journeyPlanner &&
                  currentScreen == SafeLoopScreen.activeJourney);

          final activeColor = isDark ? AppColors.electricLavender : AppColors.primaryViolet;
          final inactiveColor =
              isDark ? AppColors.textSecondary : AppColors.lightTextSecondary;

          return InkWell(
            onTap: () => onNavigate(item.screen),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primaryViolet.withValues(alpha: isDark ? 0.2 : 0.12)
                          : Colors.transparent,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isSelected ? item.selectedIcon : item.unselectedIcon,
                      color: isSelected ? activeColor : inactiveColor,
                      size: 22,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      color: isSelected ? activeColor : inactiveColor,
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

typedef SheMoveBottomBar = SafeLoopBottomBar;

