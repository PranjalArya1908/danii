import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:safeloop/models/models.dart';
import 'package:safeloop/services/location_service.dart';
import 'package:safeloop/state/safeloop_state.dart';

class FakeLocationService extends LocationService {
  bool serviceEnabled = true;
  LocationPermission permission = LocationPermission.whileInUse;

  @override
  Future<bool> isLocationServiceEnabled() async => serviceEnabled;

  @override
  Future<LocationPermission> checkPermission() async => permission;

  @override
  Future<LocationPermission> requestPermission() async {
    permission = LocationPermission.whileInUse;
    return permission;
  }

  @override
  Future<LocationResult> getCurrentLocation({bool requestIfDenied = false}) async {
    return const LocationResult(
      point: LatLngPoint(
        latitude: 28.5355,
        longitude: 77.3910,
        address: 'Noida Sector 62, Uttar Pradesh',
      ),
      isLive: true,
    );
  }

  @override
  Future<String> reverseGeocode(double latitude, double longitude) async {
    return 'Noida Sector 62, Uttar Pradesh';
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SafeLoopState Logic & Scenario Tests', () {
    late SafeLoopState state;

    setUp(() {
      state = SafeLoopState(locationService: FakeLocationService());
    });

    tearDown(() {
      state.dispose();
    });

    test('Initial state starts in onboarding mode with zero contacts (no dummy data)', () {
      expect(state.currentScreen, SafeLoopScreen.onboarding);
      expect(state.contacts.length, 0);
      expect(state.userProfile.safetyPin, '1234');
      expect(state.userProfile.duressPin, '9999');
      expect(state.isCovertDistressActive, false);
    });

    test('Complete onboarding and setup transitions to home', () {
      state.completeOnboarding();
      expect(state.currentScreen, SafeLoopScreen.setup);

      state.completeSecuritySetup('Priya Sharma', '+91 99887 76655', '5678', true, [
        const TrustedContact(
          id: 'c1',
          name: 'Pooja Sharma',
          phone: '+91 98200 11111',
          relationship: 'Sister',
          isPrimary: true,
        ),
      ]);
      expect(state.currentScreen, SafeLoopScreen.home);
      expect(state.userProfile.name, 'Priya Sharma');
      expect(state.userProfile.safetyPin, '5678');
      expect(state.userProfile.isSetupComplete, true);
      expect(state.contacts.length, 1);
      expect(state.contacts.first.name, 'Pooja Sharma');
    });

    test('Starting a journey initiates active tracking and alerts contacts', () {
      state.addContact('Maya Verma', '+91 98201 12345', 'Sister');
      state.startJourney(
        start: 'Cyber Hub',
        destination: 'Sector 54',
        mode: TransportMode.cab,
        vehicleNo: 'HR 26 1234',
        durationMinutes: 20,
        intervalMinutes: 5,
        geofence: true,
      );

      expect(state.currentScreen, SafeLoopScreen.activeJourney);
      expect(state.activeJourney, isNotNull);
      expect(state.activeJourney?.destinationAddress, 'Sector 54');
      expect(state.hasActiveJourney, true);
      expect(
        state.contacts.every((c) => c.notificationStatus == ContactNotificationStatus.sent),
        true,
      );
    });

    test('Entering discreet Duress PIN (9999) silently activates covert distress mode', () {
      state.addContact('Maya Verma', '+91 98201 12345', 'Sister');
      state.startJourney(
        start: 'Origin',
        destination: 'Destination',
        mode: TransportMode.cab,
        vehicleNo: 'DL 1A 0001',
        durationMinutes: 15,
        intervalMinutes: 5,
        geofence: true,
      );

      state.triggerCheckInDue();
      expect(state.currentScreen, SafeLoopScreen.safetyCheckIn);

      // Enter Duress PIN
      state.handleCheckInSafetyConfirm('9999');

      // Visually returns to active journey screen and shows "Safety confirmed" to deceive attacker
      expect(state.currentScreen, SafeLoopScreen.activeJourney);
      expect(state.toastMessage, 'Safety confirmed');
      // Internally activates covert distress!
      expect(state.isCovertDistressActive, true);
      expect(state.activeJourney?.status, JourneyStatus.covertDuress);
      expect(
        state.contacts.every((c) => c.notificationStatus == ContactNotificationStatus.delivered),
        true,
      );
    });

    test('Disarming emergency with normal PIN clears emergency', () {
      state.triggerEmergencyNow('SOS Test');
      expect(state.currentScreen, SafeLoopScreen.emergencyActive);
      expect(state.activeJourney?.status, JourneyStatus.emergency);

      final success = state.disarmEmergency('1234');
      expect(success, true);
      expect(state.activeJourney?.status, JourneyStatus.active);
      expect(state.isCovertDistressActive, false);
    });

    test('Demo scenarios runner executes correctly', () {
      state.runDemoScenario('critical_sos');
      expect(state.currentScreen, SafeLoopScreen.emergencyActive);

      state.runDemoScenario('safe_arrival');
      expect(state.currentScreen, SafeLoopScreen.journeyCompleted);
      expect(state.history.first.destinationAddress, 'Defence Colony');
    });

    test('Location tracking initializes and requests permissions properly', () async {
      final fakeLocationService = FakeLocationService();
      final localState = SafeLoopState(locationService: fakeLocationService);

      await localState.initLocationTracking();
      expect(localState.hasLocationPermission, true);
      expect(localState.isLiveGpsActive, true);
      expect(localState.currentLocation.address, 'Noida Sector 62, Uttar Pradesh');
      expect(localState.currentLocation.latitude, 28.5355);

      localState.dispose();
    });
  });
}

