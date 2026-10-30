import 'package:flutter/material.dart';
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
import 'state/safeloop_state.dart';
import 'theme/app_theme.dart';
import 'widgets/scenario_selector_sheet.dart';

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
  final SafeLoopState _state = SafeLoopState();
  late bool _isDark;

  @override
  void initState() {
    super.initState();
    _isDark = _state.userProfile.isDarkMode;
    _state.addListener(_onThemeChanged);
  }

  void _onThemeChanged() {
    if (_state.userProfile.isDarkMode != _isDark) {
      setState(() {
        _isDark = _state.userProfile.isDarkMode;
      });
    }
  }

  @override
  void dispose() {
    _state.removeListener(_onThemeChanged);
    _state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SheMove',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: _isDark ? ThemeMode.dark : ThemeMode.light,
      home: SafeLoopMainScaffold(state: _state),
    );
  }
}

typedef SheMoveApp = SafeLoopApp;
typedef SheMoveMainScaffold = SafeLoopMainScaffold;

class SafeLoopMainScaffold extends StatefulWidget {
  final SafeLoopState state;

  const SafeLoopMainScaffold({super.key, required this.state});

  @override
  State<SafeLoopMainScaffold> createState() => _SafeLoopMainScaffoldState();
}

class _SafeLoopMainScaffoldState extends State<SafeLoopMainScaffold> {
  @override
  void initState() {
    super.initState();
    widget.state.addListener(_onStateChange);
  }

  @override
  void dispose() {
    widget.state.removeListener(_onStateChange);
    super.dispose();
  }

  void _onStateChange() {
    if (widget.state.toastMessage != null && mounted) {
      final msg = widget.state.toastMessage!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
      widget.state.clearToast();
    }

    if (widget.state.showScenarioPicker && mounted) {
      widget.state.toggleScenarioPicker(false);
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => ScenarioSelectorSheet(
          isOnline: widget.state.isOnline,
          onSelectScenario: (scenarioId) {
            widget.state.runDemoScenario(scenarioId);
          },
        ),
      );
    }
  }

  bool _onWillPop() {
    final current = widget.state.currentScreen;
    if (current == SafeLoopScreen.home || current == SafeLoopScreen.onboarding) {
      return true; // Allow system back to exit
    }

    switch (current) {
      case SafeLoopScreen.escalationWarning:
      case SafeLoopScreen.emergencyActive:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Enter PIN to disarm emergency alert'),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return false;
      case SafeLoopScreen.journeyCompleted:
        widget.state.exitJourneyToHome();
        return false;
      default:
        widget.state.navigateBack();
        return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.state,
      builder: (context, _) {
        final state = widget.state;
        return PopScope(
          canPop: state.currentScreen == SafeLoopScreen.home ||
              state.currentScreen == SafeLoopScreen.onboarding,
          onPopInvokedWithResult: (didPop, result) {
            if (!didPop) {
              _onWillPop();
            }
          },
          child: Scaffold(
            body: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: _buildCurrentScreen(state),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCurrentScreen(SafeLoopState state) {
    switch (state.currentScreen) {
      case SafeLoopScreen.onboarding:
        return OnboardingScreen(
          key: const ValueKey('onboarding'),
          onFinish: () => state.completeOnboarding(),
        );

      case SafeLoopScreen.setup:
        return SecuritySetupScreen(
          key: const ValueKey('setup'),
          initialName: state.userProfile.name,
          initialPhone: state.userProfile.phone,
          initialLocationGranted: state.hasLocationPermission,
          onRequestLocationPermission: () => state.requestLocationPermission(),
          onRequestContactsPermission: () => state.requestContactsPermission(),
          onPickDeviceContact: () => state.contactsService.pickContact(),
          onSetupComplete: (name, phone, pin, biometric, contacts) {
            state.completeSecuritySetup(name, phone, pin, biometric, contacts);
          },
        );

      case SafeLoopScreen.home:
        return HomeScreen(
          key: const ValueKey('home'),
          userProfile: state.userProfile,
          contacts: state.contacts,
          recentJourneys: state.history,
          currentLocation: state.currentLocation,
          currentHeading: state.currentHeading,
          isOnline: state.isOnline,
          isCovertActive: state.isCovertDistressActive,
          hasActiveJourney: state.hasActiveJourney,
          activeJourney: state.activeJourney,
          hasLocationPermission: state.hasLocationPermission,
          isLocationLoading: state.isLocationLoading,
          isLiveGpsActive: state.isLiveGpsActive,
          locationStatusMessage: state.locationStatusMessage,
          onRequestLocation: () => state.requestLocationPermission(),
          onRefreshLocation: () => state.refreshCurrentLocation(),
          onStartJourneyClick: () => state.navigateTo(SafeLoopScreen.journeyPlanner),
          onViewActiveJourney: () => state.navigateTo(SafeLoopScreen.activeJourney),
          onQuickEmergency: () => state.triggerEmergencyNow('Quick SOS Activated from Home Screen'),
          onOpenContacts: () => state.navigateTo(SafeLoopScreen.contacts),
          onOpenScenarios: () => state.toggleScenarioPicker(true),
          onOpenSettings: () => state.navigateTo(SafeLoopScreen.settings),
          onViewHistory: () => state.navigateTo(SafeLoopScreen.history),
          onToggleTheme: () => state.toggleTheme(),
        );

      case SafeLoopScreen.journeyPlanner:
        return JourneySetupScreen(
          key: const ValueKey('journey_planner'),
          contacts: state.contacts,
          initialStartLocation: state.currentLocation.address,
          initialStartPoint: state.currentLocation,
          onBack: () => state.navigateBack(),
          onOpenContacts: () => state.navigateTo(SafeLoopScreen.contacts),
          onStartJourney: (start, dest, mode, vehicleNo, duration, interval, geofence, [selectedContactIds, waypoints]) {
            state.startJourney(
              start: start,
              destination: dest,
              mode: mode,
              vehicleNo: vehicleNo,
              durationMinutes: duration,
              intervalMinutes: interval,
              geofence: geofence,
              selectedContactIds: selectedContactIds,
              waypoints: waypoints,
            );
          },
        );

      case SafeLoopScreen.activeJourney:
        final journey = state.activeJourney;
        if (journey != null) {
          return ActiveJourneyScreen(
            key: const ValueKey('active_journey'),
            journey: journey,
            checkInSecondsRemaining: state.checkInSecondsRemaining,
            isOnline: state.isOnline,
            isCovertActive: state.isCovertDistressActive,
            currentLocation: state.currentLocation,
            currentHeading: state.currentHeading,
            currentSpeedKmh: state.currentSpeedKmh,
            onModifyDuration: (delta) => state.modifyJourneyDuration(delta),
            onManualCheckIn: () => state.triggerCheckInDue(),
            onTriggerEmergency: () =>
                state.triggerEmergencyNow('Emergency SOS Button 3s Long-Press'),
            onEndJourney: () => state.completeActiveJourney(),
            onBack: () => state.navigateTo(SafeLoopScreen.home),
          );
        } else {
          return JourneySetupScreen(
            key: const ValueKey('journey_planner_fallback'),
            contacts: state.contacts,
            initialStartLocation: state.currentLocation.address,
            initialStartPoint: state.currentLocation,
            onBack: () => state.navigateBack(),
            onOpenContacts: () => state.navigateTo(SafeLoopScreen.contacts),
            onStartJourney: (start, dest, mode, vehicleNo, duration, interval, geofence, [selectedContactIds, waypoints]) {
              state.startJourney(
                start: start,
                destination: dest,
                mode: mode,
                vehicleNo: vehicleNo,
                durationMinutes: duration,
                intervalMinutes: interval,
                geofence: geofence,
                selectedContactIds: selectedContactIds,
                waypoints: waypoints,
              );
            },
          );
        }

      case SafeLoopScreen.safetyCheckIn:
        return CheckInModalScreen(
          key: const ValueKey('safety_check_in'),
          biometricEnabled: state.userProfile.biometricEnabled,
          configuredSafetyPin: state.userProfile.safetyPin,
          configuredDuressPin: state.userProfile.duressPin,
          secondsRemaining: state.checkInWindowSecondsRemaining,
          onConfirmSafeWithPin: (pin, isBiometric) {
            state.handleCheckInSafetyConfirm(pin, isBiometric: isBiometric);
          },
          onNeedHelpRequested: () => state.handleCheckInNeedHelp(),
          onCancelCheckIn: () {
            if (state.activeJourney != null) {
              state.navigateTo(SafeLoopScreen.activeJourney);
            } else {
              state.navigateTo(SafeLoopScreen.home);
            }
          },
        );

      case SafeLoopScreen.escalationWarning:
        return EscalationWarningScreen(
          key: const ValueKey('escalation_warning'),
          secondsRemaining: state.escalationSecondsRemaining,
          contacts: state.contacts,
          configuredPin: state.userProfile.safetyPin,
          onCancelWithPin: (pin) => state.cancelEscalationWithPin(pin),
          onBypassAndEscalateNow: () => state.triggerEmergencyNow(
            'User bypassed grace period from warning screen',
          ),
        );

      case SafeLoopScreen.emergencyActive:
        return EmergencyScreen(
          key: const ValueKey('emergency_active'),
          currentLocation: state.currentLocation,
          contacts: state.contacts,
          events: state.events,
          onDisarmEmergency: (pin) => state.disarmEmergency(pin),
        );

      case SafeLoopScreen.journeyCompleted:
        return JourneyCompletionScreen(
          key: const ValueKey('journey_completed'),
          journey: state.activeJourney ?? state.lastCompletedJourney ?? (state.history.isNotEmpty ? state.history.first : null),
          onCloseJourney: () => state.exitJourneyToHome(),
        );

      case SafeLoopScreen.history:
        return SafetyHistoryScreen(
          key: const ValueKey('history'),
          journeys: state.history,
          events: state.events,
          selectedJourney: state.selectedHistoryJourney,
          onSelectJourney: (j) => state.selectHistoryJourney(j),
          onBack: () => state.navigateBack(),
        );

      case SafeLoopScreen.contacts:
        return ContactsScreen(
          key: const ValueKey('contacts'),
          contacts: state.contacts,
          emergencyMessageTemplate: state.userProfile.emergencyMessage,
          onAddContact: (name, phone, rel) => state.addContact(name, phone, rel),
          onRemoveContact: (id) => state.removeContact(id),
          onSetPrimary: (id) => state.setPrimaryContact(id),
          onPickDeviceContact: () => state.contactsService.pickContact(),
          onBack: () => state.navigateBack(),
        );

      case SafeLoopScreen.settings:
        return SettingsScreen(
          key: const ValueKey('settings'),
          userProfile: state.userProfile,
          onUpdateProfile: (profile) => state.updateProfile(profile),
          onOpenScenarios: () => state.toggleScenarioPicker(true),
          onBack: () => state.navigateBack(),
        );
    }
  }
}
