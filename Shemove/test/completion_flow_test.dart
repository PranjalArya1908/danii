import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safeloop/main.dart';
import 'package:safeloop/models/models.dart';
import 'package:safeloop/state/safeloop_state.dart';
import 'package:safeloop/screens/home_screen.dart';
import 'package:safeloop/services/location_service.dart';

class FakeLocationService extends LocationService {
  @override
  Future<LocationResult> getCurrentLocation({bool requestIfDenied = false}) async {
    return const LocationResult(
      point: LatLngPoint(
        latitude: 28.6315,
        longitude: 77.2167,
        address: 'Connaught Place, New Delhi',
      ),
      isLive: true,
    );
  }

  @override
  Future<String> reverseGeocode(double lat, double lon) async {
    return 'Connaught Place, New Delhi';
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Journey Completion to Home transition renders HomeScreen completely without errors', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final state = SafeLoopState(locationService: FakeLocationService());
    state.completeOnboarding();
    state.completeSecuritySetup('Aanya Rao', '+91 98112 34567', '1234', true);

    await tester.pumpWidget(
      MaterialApp(
        home: SafeLoopMainScaffold(state: state),
      ),
    );
    await tester.pump();

    // Start a journey
    state.startJourney(
      start: 'Connaught Place',
      destination: 'Hauz Khas',
      mode: TransportMode.cab,
      vehicleNo: 'DL 1Y 1234',
      durationMinutes: 20,
      intervalMinutes: 5,
      geofence: true,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // End journey
    state.completeActiveJourney();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Return to SheMove Home'), findsOneWidget);

    // Tap 'Return to SheMove Home'
    await tester.tap(find.text('Return to SheMove Home'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Verify HomeScreen widgets
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text('Aanya Rao'), findsOneWidget);
    expect(find.text('Recent Protected Journey'), findsOneWidget);
    expect(find.text('Hauz Khas'), findsOneWidget);
  });
}
