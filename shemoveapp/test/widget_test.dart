import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shemoveapp/main.dart';
import 'package:shemoveapp/models/models.dart';
import 'package:shemoveapp/state/safeloop_controller.dart';

void main() {
  group('SafeLoop Models & Controller Tests', () {
    test('Initial controller state is correct', () {
      final controller = SafeLoopController();
      expect(controller.userProfile.name, 'Aanya Rao');
      expect(controller.userProfile.isSetupComplete, false);
      expect(controller.currentScreen, SafeLoopScreen.onboarding);
      expect(controller.contacts.length, 3);
      expect(controller.history.length, 3);
      expect(controller.events.isNotEmpty, true);
      expect(controller.isOnline, true);
      expect(controller.isCovertDistressActive, false);
      controller.dispose();
    });

    test('Complete onboarding transitions to setup', () {
      final controller = SafeLoopController();
      controller.completeOnboarding();
      expect(controller.currentScreen, SafeLoopScreen.setup);
      controller.dispose();
    });

    test('Complete security setup transitions to home and updates profile', () {
      final controller = SafeLoopController();
      controller.completeSecuritySetup('Priya Sharma', '+91 98765 43210', '5678', true);
      expect(controller.userProfile.name, 'Priya Sharma');
      expect(controller.userProfile.phone, '+91 98765 43210');
      expect(controller.userProfile.safetyPin, '5678');
      expect(controller.userProfile.isSetupComplete, true);
      expect(controller.currentScreen, SafeLoopScreen.home);
      controller.dispose();
    });

    test('Start protected journey creates active journey and ticks progress', () {
      final controller = SafeLoopController();
      controller.startJourney(
        start: 'Sector 29, Gurugram',
        dest: 'Cyber City',
        mode: TransportMode.cab,
        vehicleNo: 'HR 26 DQ 1234',
        durationMinutes: 20,
        intervalMinutes: 5,
        geofence: true,
      );

      expect(controller.activeJourney != null, true);
      expect(controller.activeJourney!.startAddress, 'Sector 29, Gurugram');
      expect(controller.activeJourney!.destinationAddress, 'Cyber City');
      expect(controller.activeJourney!.status, JourneyStatus.active);
      expect(controller.currentScreen, SafeLoopScreen.activeJourney);
      expect(controller.checkInSecondsRemaining, 5 * 60);
      controller.dispose();
    });

    test('Covert duress PIN sets covert distress flag and shows success toast', () {
      final controller = SafeLoopController();
      controller.startJourney(
        start: 'A',
        dest: 'B',
        mode: TransportMode.cab,
        vehicleNo: '',
        durationMinutes: 10,
        intervalMinutes: 5,
        geofence: true,
      );

      controller.triggerCheckInDue();
      expect(controller.currentScreen, SafeLoopScreen.safetyCheckIn);

      // Enter duress PIN '9999'
      controller.handleCheckInSafetyConfirm('9999');
      expect(controller.isCovertDistressActive, true);
      expect(controller.activeJourney!.status, JourneyStatus.covertDuress);
      expect(controller.toastMessage, 'Safety confirmed');
      controller.dispose();
    });

    test('Normal PIN resets check-in timer without duress', () {
      final controller = SafeLoopController();
      controller.startJourney(
        start: 'A',
        dest: 'B',
        mode: TransportMode.cab,
        vehicleNo: '',
        durationMinutes: 10,
        intervalMinutes: 5,
        geofence: true,
      );

      controller.triggerCheckInDue();
      // Enter standard safety PIN '1234'
      controller.handleCheckInSafetyConfirm('1234');
      expect(controller.isCovertDistressActive, false);
      expect(controller.activeJourney!.status, JourneyStatus.active);
      expect(controller.checkInSecondsRemaining, 5 * 60);
      controller.dispose();
    });

    test('Demo scenarios trigger appropriately', () {
      final controller = SafeLoopController();
      controller.runDemoScenario('critical_sos');
      expect(controller.currentScreen, SafeLoopScreen.emergencyActive);
      expect(controller.activeJourney!.status, JourneyStatus.emergency);

      // Disarm emergency with safety PIN
      final disarmed = controller.disarmEmergency('1234');
      expect(disarmed, true);
      controller.dispose();
    });

    test('Add and remove trusted contacts', () {
      final controller = SafeLoopController();
      controller.addContact('Kavita Rao', '+91 99887 76655', 'Mother');
      expect(controller.contacts.any((c) => c.name == 'Kavita Rao'), true);

      final added = controller.contacts.firstWhere((c) => c.name == 'Kavita Rao');
      controller.setPrimaryContact(added.id);
      expect(controller.contacts.firstWhere((c) => c.id == added.id).isPrimary, true);

      controller.removeContact(added.id);
      expect(controller.contacts.any((c) => c.id == added.id), false);
      controller.dispose();
    });
  });

  group('SafeLoop Widget Tests', () {
    testWidgets('App renders onboarding on initial launch and navigates through setup',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(const SafeLoopApp());
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('SafeLoop'), findsOneWidget);
      expect(find.text('Skip'), findsOneWidget);
      expect(find.text('Protected Journeys'), findsOneWidget);

      // Tap Skip to go to Setup
      await tester.tap(find.text('Skip'));
      await tester.pump(const Duration(milliseconds: 300));

      // Step 1: Profile & Verification
      expect(find.text('Security Setup'), findsOneWidget);
      expect(find.text('Your Profile & Verification'), findsOneWidget);
      expect(find.text('Continue to PIN Setup'), findsOneWidget);

      // Tap Continue to PIN Setup
      await tester.ensureVisible(find.text('Continue to PIN Setup'));
      await tester.tap(find.text('Continue to PIN Setup'));
      await tester.pump(const Duration(milliseconds: 300));

      // Step 2: PIN Setup
      expect(find.text('Create Safety PIN'), findsOneWidget);
      expect(find.text('Continue to Permissions'), findsOneWidget);

      // Tap Continue to Permissions
      await tester.ensureVisible(find.text('Continue to Permissions'));
      await tester.tap(find.text('Continue to Permissions'));
      await tester.pump(const Duration(milliseconds: 300));

      // Step 3: Permissions
      expect(find.text('Permissions & Biometrics'), findsOneWidget);
      expect(find.text('Complete Setup & Open SafeLoop'), findsOneWidget);

      // Tap Complete Setup
      await tester.ensureVisible(find.text('Complete Setup & Open SafeLoop'));
      await tester.tap(find.text('Complete Setup & Open SafeLoop'));
      await tester.pump(const Duration(milliseconds: 300));

      // Landed on Home screen!
      expect(find.text('Start Protected Journey'), findsOneWidget);
      expect(find.text('Current Telemetry Area'), findsOneWidget);
      expect(find.text('Trusted Emergency Circle'), findsOneWidget);
    });

    testWidgets('Home screen navigation and bottom bar works', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final controller = SafeLoopController();
      controller.completeSecuritySetup('Aanya Rao', '+91 98112 34567', '1234', true);

      await tester.pumpWidget(
        MaterialApp(
          home: SafeLoopMainScaffold(controller: controller),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Contacts'), findsAtLeast(1));
      expect(find.text('History'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);

      // Tap Contacts in bottom bar
      await tester.tap(find.text('Contacts').last);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Trusted Contacts'), findsOneWidget);

      // Tap History in bottom bar
      await tester.tap(find.text('History').last);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Safety & Journey History'), findsOneWidget);

      // Tap Settings in bottom bar
      await tester.tap(find.text('Settings').last);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Settings & Privacy'), findsOneWidget);
      expect(find.text('Prototype Scenario Switcher'), findsOneWidget);

      controller.dispose();
    });
  });
}
