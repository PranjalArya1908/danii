import 'package:flutter/material.dart';
import 'components/safeloop_bottom_bar.dart';
import 'components/scenario_selector_sheet.dart';
import 'models/models.dart';
import 'screens/active_journey_screen.dart';
import 'screens/check_in_modal_screen.dart';
import 'screens/contacts_screen.dart';
import 'screens/emergency_screen.dart';
import 'screens/escalation_warning_screen.dart';
import 'screens/home_screen.dart';
import 'screens/journey_completion_screen.dart';
import 'screens/journey_setup_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/safety_history_screen.dart';
import 'screens/security_setup_screen.dart';
import 'screens/settings_screen.dart';
import 'state/safeloop_controller.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SafeLoopApp());
}

class SafeLoopApp extends StatefulWidget {
  const SafeLoopApp({super.key});

  @override
  State<SafeLoopApp> createState() => _SafeLoopAppState();
}

class _SafeLoopAppState extends State<SafeLoopApp> {
  final SafeLoopController _controller = SafeLoopController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onStateChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onStateChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onStateChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SafeLoop',
      debugShowCheckedModeBanner: false,
      theme: SafeLoopTheme.lightTheme(),
      darkTheme: SafeLoopTheme.darkTheme(),
      themeMode: _controller.userProfile.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: SafeLoopMainScaffold(controller: _controller),
    );
  }
}

class SafeLoopMainScaffold extends StatefulWidget {
  final SafeLoopController controller;

  const SafeLoopMainScaffold({super.key, required this.controller});

  @override
  State<SafeLoopMainScaffold> createState() => _SafeLoopMainScaffoldState();
}

class _SafeLoopMainScaffoldState extends State<SafeLoopMainScaffold> {
  SafeLoopController get c => widget.controller;

  @override
  void initState() {
    super.initState();
    c.addListener(_handleToastAndScenarios);
  }

  @override
  void dispose() {
    c.removeListener(_handleToastAndScenarios);
    super.dispose();
  }

  void _handleToastAndScenarios() {
    if (mounted) {
      setState(() {});
    }
    if (c.toastMessage != null && mounted) {
      final msg = c.toastMessage!;
      c.clearToast();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _openScenarioSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ScenarioSelectorSheet(
        isOnline: c.isOnline,
        onDismiss: () => Navigator.of(ctx).pop(),
        onSelectScenario: (scenarioId) {
          Navigator.of(ctx).pop();
          c.runDemoScenario(scenarioId);
        },
      ),
    );
  }

  bool _onWillPop() {
    if (c.currentScreen == SafeLoopScreen.home || c.currentScreen == SafeLoopScreen.onboarding) {
      return true;
    }

    switch (c.currentScreen) {
      case SafeLoopScreen.journeyPlanner:
      case SafeLoopScreen.activeJourney:
      case SafeLoopScreen.contacts:
      case SafeLoopScreen.history:
      case SafeLoopScreen.settings:
        c.navigateTo(SafeLoopScreen.home);
        return false;
      case SafeLoopScreen.safetyCheckIn:
        if (c.activeJourney != null) {
          c.navigateTo(SafeLoopScreen.activeJourney);
        } else {
          c.navigateTo(SafeLoopScreen.home);
        }
        return false;
      case SafeLoopScreen.escalationWarning:
      case SafeLoopScreen.emergencyActive:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Enter PIN to disarm alert'),
            duration: Duration(seconds: 2),
          ),
        );
        return false;
      case SafeLoopScreen.journeyCompleted:
        c.exitJourneyToHome();
        return false;
      default:
        c.navigateTo(SafeLoopScreen.home);
        return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final showBottomNav = [
      SafeLoopScreen.home,
      SafeLoopScreen.journeyPlanner,
      SafeLoopScreen.activeJourney,
      SafeLoopScreen.contacts,
      SafeLoopScreen.history,
      SafeLoopScreen.settings,
    ].contains(c.currentScreen);

    return PopScope(
      canPop: c.currentScreen == SafeLoopScreen.home || c.currentScreen == SafeLoopScreen.onboarding,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _onWillPop();
        }
      },
      child: Scaffold(
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: KeyedSubtree(
            key: ValueKey(c.currentScreen),
            child: _buildCurrentScreen(),
          ),
        ),
        bottomNavigationBar: showBottomNav
            ? SafeLoopBottomBar(
                currentScreen: c.currentScreen,
                hasActiveJourney: c.activeJourney != null && c.activeJourney!.status != JourneyStatus.completed,
                onNavigate: (screen) => c.navigateTo(screen),
                onQuickEmergency: () => c.triggerEmergencyNow('Quick SOS Activated from Navigation'),
              )
            : null,
      ),
    );
  }

  Widget _buildCurrentScreen() {
    switch (c.currentScreen) {
      case SafeLoopScreen.onboarding:
        return OnboardingScreen(
          onFinish: () => c.completeOnboarding(),
        );

      case SafeLoopScreen.setup:
        return SecuritySetupScreen(
          initialName: c.userProfile.name,
          initialPhone: c.userProfile.phone,
          onSetupComplete: (name, phone, pin, biometric) {
            c.completeSecuritySetup(name, phone, pin, biometric);
          },
        );

      case SafeLoopScreen.home:
        return HomeScreen(
          userProfile: c.userProfile,
          contacts: c.contacts,
          recentJourneys: c.history,
          currentLocation: c.currentLocation,
          currentHeading: c.currentHeading,
          isOnline: c.isOnline,
          isCovertActive: c.isCovertDistressActive,
          hasActiveJourney: c.activeJourney != null && c.activeJourney!.status != JourneyStatus.completed,
          activeJourney: c.activeJourney,
          hasLocationPermission: c.hasLocationPermission,
          isLocationLoading: c.isLocationLoading,
          isLiveGpsActive: c.isLiveGpsActive,
          onStartJourneyClick: () => c.navigateTo(SafeLoopScreen.journeyPlanner),
          onViewActiveJourney: () => c.navigateTo(SafeLoopScreen.activeJourney),
          onQuickEmergency: () => c.triggerEmergencyNow('Quick SOS Activated from Home Screen'),
          onOpenContacts: () => c.navigateTo(SafeLoopScreen.contacts),
          onOpenScenarios: _openScenarioSheet,
          onOpenSettings: () => c.navigateTo(SafeLoopScreen.settings),
          onViewHistory: () => c.navigateTo(SafeLoopScreen.history),
          onToggleTheme: () => c.toggleTheme(),
          onRequestLocation: () => c.requestLocationPermission(),
          onRefreshLocation: () => c.refreshLocation(),
        );

      case SafeLoopScreen.journeyPlanner:
        return JourneySetupScreen(
          contacts: c.contacts,
          onBack: () => c.navigateTo(SafeLoopScreen.home),
          onStartJourney: (start, dest, mode, vehicleNo, duration, interval, geofence) {
            c.startJourney(
              start: start,
              dest: dest,
              mode: mode,
              vehicleNo: vehicleNo,
              durationMinutes: duration,
              intervalMinutes: interval,
              geofence: geofence,
            );
          },
        );

      case SafeLoopScreen.activeJourney:
        final journey = c.activeJourney;
        if (journey != null) {
          return ActiveJourneyScreen(
            journey: journey,
            checkInSecondsRemaining: c.checkInSecondsRemaining,
            isOnline: c.isOnline,
            isCovertActive: c.isCovertDistressActive,
            currentLocation: c.currentLocation,
            currentHeading: c.currentHeading,
            currentSpeedKmh: c.currentSpeedKmh,
            onModifyDuration: (delta) => c.modifyJourneyDuration(delta),
            onManualCheckIn: () => c.triggerCheckInDue(),
            onTriggerEmergency: () => c.triggerEmergencyNow('Emergency SOS Button 3s Long-Press'),
            onEndJourney: () => c.completeActiveJourney(),
            onBack: () => c.navigateTo(SafeLoopScreen.home),
          );
        } else {
          return JourneySetupScreen(
            contacts: c.contacts,
            onBack: () => c.navigateTo(SafeLoopScreen.home),
            onStartJourney: (start, dest, mode, vehicleNo, duration, interval, geofence) {
              c.startJourney(
                start: start,
                dest: dest,
                mode: mode,
                vehicleNo: vehicleNo,
                durationMinutes: duration,
                intervalMinutes: interval,
                geofence: geofence,
              );
            },
          );
        }

      case SafeLoopScreen.safetyCheckIn:
        return CheckInModalScreen(
          biometricEnabled: c.userProfile.biometricEnabled,
          configuredSafetyPin: c.userProfile.safetyPin,
          configuredDuressPin: c.userProfile.duressPin,
          onConfirmSafeWithPin: (pin, isBiometric) {
            c.handleCheckInSafetyConfirm(pin, isBiometric);
          },
          onNeedHelpRequested: () => c.handleCheckInNeedHelp(),
          onCancelCheckIn: () {
            if (c.activeJourney != null) {
              c.navigateTo(SafeLoopScreen.activeJourney);
            } else {
              c.navigateTo(SafeLoopScreen.home);
            }
          },
        );

      case SafeLoopScreen.escalationWarning:
        return EscalationWarningScreen(
          secondsRemaining: c.escalationSecondsRemaining,
          contacts: c.contacts,
          configuredPin: c.userProfile.safetyPin,
          onCancelWithPin: (pin) => c.cancelEscalationWithPin(pin),
          onBypassAndEscalateNow: () =>
              c.triggerEmergencyNow('User bypassed grace period from warning screen'),
        );

      case SafeLoopScreen.emergencyActive:
        return EmergencyScreen(
          currentLocation: c.currentLocation,
          contacts: c.contacts,
          events: c.events,
          onDisarmEmergency: (pin) => c.disarmEmergency(pin),
        );

      case SafeLoopScreen.journeyCompleted:
        return JourneyCompletionScreen(
          journey: c.activeJourney,
          onCloseJourney: () => c.exitJourneyToHome(),
        );

      case SafeLoopScreen.history:
        return SafetyHistoryScreen(
          journeys: c.history,
          events: c.events,
          selectedJourney: c.selectedHistoryJourney,
          onSelectJourney: (j) => c.selectHistoryJourney(j),
          onBack: () => c.navigateTo(SafeLoopScreen.home),
        );

      case SafeLoopScreen.contacts:
        return ContactsScreen(
          contacts: c.contacts,
          emergencyMessageTemplate: c.userProfile.emergencyMessage,
          onAddContact: (name, phone, rel) => c.addContact(name, phone, rel),
          onRemoveContact: (id) => c.removeContact(id),
          onSetPrimary: (id) => c.setPrimaryContact(id),
          onBack: () => c.navigateTo(SafeLoopScreen.home),
        );

      case SafeLoopScreen.settings:
        return SettingsScreen(
          userProfile: c.userProfile,
          onUpdateProfile: (p) => c.updateProfile(p),
          onOpenScenarios: _openScenarioSheet,
          onBack: () => c.navigateTo(SafeLoopScreen.home),
        );
    }
  }
}
