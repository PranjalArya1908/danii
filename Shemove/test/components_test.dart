import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:safeloop/models/models.dart';
import 'package:safeloop/screens/active_journey_screen.dart';
import 'package:safeloop/screens/contacts_screen.dart';
import 'package:safeloop/screens/home_screen.dart';
import 'package:safeloop/screens/journey_setup_screen.dart';
import 'package:safeloop/services/location_service.dart';
import 'package:safeloop/services/routing_service.dart';
import 'package:safeloop/state/safeloop_state.dart';
import 'package:safeloop/widgets/satellite_map_view.dart';
import 'package:safeloop/widgets/swipe_action_control.dart';

class FakeLocationService extends LocationService {
  @override
  Future<bool> isLocationServiceEnabled() async => true;

  @override
  Future<LocationPermission> checkPermission() async => LocationPermission.whileInUse;

  @override
  Future<LocationPermission> requestPermission() async => LocationPermission.whileInUse;

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
  testWidgets('SatelliteMapView renders coordinates and satellite badge',
      (WidgetTester tester) async {
    const testLocation = LatLngPoint(
      latitude: 28.4595,
      longitude: 77.0266,
      address: 'MG Road, Sector 28, Gurugram',
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SatelliteMapView(
            location: testLocation,
            height: 250,
          ),
        ),
      ),
    );
    await tester.pump();

    // Verify Satellite HUD elements are rendered
    expect(find.text('LIVE SATELLITE'), findsOneWidget);
    expect(find.text('Street'), findsOneWidget);
    expect(find.textContaining('28.4595° N'), findsWidgets);
  });

  testWidgets('HomeScreen contacts button triggers onOpenContacts',
      (WidgetTester tester) async {
    bool contactsOpened = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HomeScreen(
            userProfile: const UserProfile(name: 'Aanya Rao'),
            contacts: const [
              TrustedContact(
                id: 'c1',
                name: 'Maya Verma',
                phone: '+91 98201 12345',
                relationship: 'Sister',
              ),
            ],
            recentJourneys: const [],
            isOnline: true,
            isCovertActive: false,
            hasActiveJourney: false,
            onStartJourneyClick: () {},
            onViewActiveJourney: () {},
            onQuickEmergency: () {},
            onOpenContacts: () {
              contactsOpened = true;
            },
            onOpenScenarios: () {},
            onOpenSettings: () {},
            onViewHistory: () {},
            onToggleTheme: () {},
          ),
        ),
      ),
    );
    await tester.pump();

    // Verify Manage button exists on Trusted Emergency Circle
    expect(find.text('Manage'), findsOneWidget);

    // Tap Manage button
    await tester.ensureVisible(find.text('Manage'));
    await tester.tap(find.text('Manage'));
    expect(contactsOpened, true);

    // Verify top bar does not have a contacts button (only theme, science/scenarios, and settings)
    expect(find.byIcon(Icons.science), findsOneWidget);
    expect(find.byIcon(Icons.settings), findsOneWidget);
  });

  testWidgets('HomeScreen displays location permission banner and handles request',
      (WidgetTester tester) async {
    bool locationRequested = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HomeScreen(
            userProfile: const UserProfile(name: 'Aanya Rao'),
            contacts: const [],
            recentJourneys: const [],
            isOnline: true,
            isCovertActive: false,
            hasActiveJourney: false,
            hasLocationPermission: false,
            onRequestLocation: () {
              locationRequested = true;
            },
            onStartJourneyClick: () {},
            onViewActiveJourney: () {},
            onQuickEmergency: () {},
            onOpenContacts: () {},
            onOpenScenarios: () {},
            onOpenSettings: () {},
            onViewHistory: () {},
            onToggleTheme: () {},
          ),
        ),
      ),
    );
    await tester.pump();

    // Verify permission banner is present
    expect(find.text('Real-Time Location Access Required'), findsOneWidget);
    expect(find.text('Allow Real-Time Location'), findsOneWidget);

    // Tap allow button
    await tester.tap(find.text('Allow Real-Time Location'));
    expect(locationRequested, true);
  });

  testWidgets('HomeScreen displays LIVE GPS LOCKED when permission is granted',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HomeScreen(
            userProfile: const UserProfile(name: 'Aanya Rao'),
            contacts: const [],
            recentJourneys: const [],
            isOnline: true,
            isCovertActive: false,
            hasActiveJourney: false,
            hasLocationPermission: true,
            isLiveGpsActive: true,
            currentLocation: const LatLngPoint(
              latitude: 28.5355,
              longitude: 77.3910,
              address: 'Noida Sector 62, Uttar Pradesh',
            ),
            onStartJourneyClick: () {},
            onViewActiveJourney: () {},
            onQuickEmergency: () {},
            onOpenContacts: () {},
            onOpenScenarios: () {},
            onOpenSettings: () {},
            onViewHistory: () {},
            onToggleTheme: () {},
          ),
        ),
      ),
    );
    await tester.pump();

    // Verify GPS LOCKED badge and coordinates
    expect(find.text('LIVE GPS LOCKED'), findsOneWidget);
    expect(find.textContaining('28.5355° N'), findsWidgets);
  });

  testWidgets('HomeScreen displays empty state when contacts list is empty',
      (WidgetTester tester) async {
    bool contactsTapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HomeScreen(
            userProfile: const UserProfile(name: 'Aanya Rao'),
            contacts: const [],
            recentJourneys: const [],
            isOnline: true,
            isCovertActive: false,
            hasActiveJourney: false,
            onStartJourneyClick: () {},
            onViewActiveJourney: () {},
            onQuickEmergency: () {},
            onOpenContacts: () {
              contactsTapped = true;
            },
            onOpenScenarios: () {},
            onOpenSettings: () {},
            onViewHistory: () {},
            onToggleTheme: () {},
          ),
        ),
      ),
    );
    await tester.pump();

    // Verify empty state is displayed
    expect(find.text('No Emergency Contacts Yet'), findsOneWidget);
    expect(find.text('Add from Phone Contacts'), findsOneWidget);

    // Tap Add from Phone Contacts button
    await tester.ensureVisible(find.text('Add from Phone Contacts'));
    await tester.tap(find.text('Add from Phone Contacts'));
    expect(contactsTapped, true);
  });

  testWidgets('CircularJourneyLauncher renders clean orb and headline text, and triggers start',
      (WidgetTester tester) async {
    bool journeyStarted = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HomeScreen(
            userProfile: const UserProfile(name: 'Aanya Rao'),
            contacts: const [
              TrustedContact(id: '1', name: 'Maya', phone: '12345', relationship: 'Sister'),
            ],
            recentJourneys: const [],
            isOnline: true,
            isCovertActive: false,
            hasActiveJourney: false,
            onStartJourneyClick: () {
              journeyStarted = true;
            },
            onViewActiveJourney: () {},
            onQuickEmergency: () {},
            onOpenContacts: () {},
            onOpenScenarios: () {},
            onOpenSettings: () {},
            onViewHistory: () {},
            onToggleTheme: () {},
          ),
        ),
      ),
    );
    await tester.pump();

    // Verify capsule header ribbon and mode buttons are NOT present
    expect(find.text('AEGIS TRANSIT CORE'), findsNothing);
    expect(find.text('Cab'), findsNothing);
    expect(find.text('Configure & Launch'), findsNothing);

    // Verify clean Orb and its text ARE present
    expect(find.text('ACTIVATE'), findsOneWidget);
    expect(find.text('TAP ORB'), findsOneWidget);
    expect(find.text('Start Protected Journey'), findsOneWidget);
    expect(
      find.text('Adaptive check-ins & automatic escalation with live telemetry'),
      findsOneWidget,
    );

    // Tap on the Start Protected Journey text or Orb to initiate journey
    await tester.tap(find.text('Start Protected Journey'));
    expect(journeyStarted, true);
  });

  testWidgets('CircularJourneyLauncher transforms to radar cockpit when journey is active',
      (WidgetTester tester) async {
    bool viewCockpitTapped = false;
    const activeTestJourney = Journey(
      id: 'j_active_123',
      startAddress: 'Connaught Place',
      destinationAddress: 'Cyber Hub, Gurugram',
      transportMode: TransportMode.cab,
      vehicleNumber: 'DL 1Y B 4821',
      progressPercent: 0.42,
      startTimeMillis: 100000,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HomeScreen(
            userProfile: const UserProfile(name: 'Aanya Rao'),
            contacts: const [],
            recentJourneys: const [],
            isOnline: true,
            isCovertActive: false,
            hasActiveJourney: true,
            activeJourney: activeTestJourney,
            onStartJourneyClick: () {},
            onViewActiveJourney: () {
              viewCockpitTapped = true;
            },
            onQuickEmergency: () {},
            onOpenContacts: () {},
            onOpenScenarios: () {},
            onOpenSettings: () {},
            onViewHistory: () {},
            onToggleTheme: () {},
          ),
        ),
      ),
    );
    await tester.pump();

    // Verify active journey radar telemetry
    expect(find.text('ESCORT ACTIVE'), findsOneWidget);
    expect(find.text('JOURNEY IN PROGRESS'), findsOneWidget);
    expect(find.text('42%'), findsOneWidget);
    expect(find.text('VIEW COCKPIT'), findsOneWidget);
    expect(find.text('Cyber Hub, Gurugram'), findsOneWidget);
    expect(find.text('DL 1Y B 4821'), findsOneWidget);
    expect(find.text('Open Live Cockpit'), findsOneWidget);

    // Tap Open Live Cockpit button
    await tester.tap(find.text('Open Live Cockpit'));
    expect(viewCockpitTapped, true);
  });

  testWidgets('JourneySetupScreen dynamically filters suggestions on typing and reveals map, traffic and long journey horizons',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: JourneySetupScreen(
            contacts: const [
              TrustedContact(
                id: 'c1',
                name: 'Maya Verma',
                phone: '+91 98201 12345',
                relationship: 'Sister',
              ),
            ],
            initialStartLocation: 'Connaught Place, Inner Circle',
            onBack: () {},
            onStartJourney: (start, dest, mode, vehicle, duration, interval, geofence, [selectedContacts, waypoints]) {},
          ),
        ),
      ),
    );
    await tester.pump();

    // Verify title and location inputs
    expect(find.text('Plan Protected Journey'), findsOneWidget);
    expect(find.text('Starting Location'), findsOneWidget);
    expect(find.text('Destination Address'), findsOneWidget);

    // Initially, Map is HIDDEN
    expect(find.text('Pick Dest'), findsNothing);
    expect(find.text('Pick Start'), findsNothing);

    // Verify Static popular destination cards are removed
    expect(find.text('POPULAR TRANSIT DESTINATIONS'), findsNothing);

    // Type 'de' into the Destination Address textfield to trigger dynamic autocomplete
    final destField = find.widgetWithText(TextField, 'Destination Address');
    expect(destField, findsOneWidget);
    await tester.enterText(destField, 'de');
    await tester.pump();

    // Dynamic autocomplete shows suggestions starting with 'de'
    expect(find.textContaining('Dehradun'), findsWidgets);
    expect(find.textContaining('Delhi'), findsWidgets);

    // Tap on a destination suggestion (e.g. Dehradun for long journey test)
    await tester.tap(find.textContaining('Dehradun').first);
    await tester.pump();

    // Map now APPEARS with Pick Dest & Pick Start tools
    expect(find.text('Pick Dest'), findsOneWidget);
    expect(find.text('Pick Start'), findsOneWidget);

    // Verify Logical Mode Filtering for 253 km Intercity Journey:
    // Walking & Auto are removed for feasibility; Cab & Bus remain available
    expect(find.text('Cab / Taxi'), findsOneWidget);
    expect(find.text('Public Bus'), findsOneWidget);
    expect(find.text('Walking'), findsNothing);
    expect(find.text('Auto / Rickshaw'), findsNothing);

    // Verify Vehicle input is present for default Cab mode
    expect(find.text('Vehicle / Registration Number'), findsOneWidget);

    // Verify Corridor Geofence sensitivity chips are present and interactive
    expect(find.text('Corridor Geofence Protection'), findsOneWidget);
    expect(find.text('Strict (150m)'), findsOneWidget);
    expect(find.text('Standard (300m)'), findsOneWidget);
    expect(find.text('Flexible (500m)'), findsOneWidget);

    // Verify Estimated Journey Time card and manual adjust chips
    expect(find.text('Estimated Journey Time'), findsOneWidget);

    // Verify quick time booster stepper chips
    expect(find.text('+30m'), findsOneWidget);
    expect(find.text('+1 Hour'), findsOneWidget);
    expect(find.text('+3 Hours'), findsOneWidget);

    // Verify contacts selection card renders contact and relationship pill
    expect(find.text('Escort Guardians for Trip'), findsOneWidget);
    expect(find.text('Maya Verma'), findsOneWidget);
    expect(find.text('Sister'), findsOneWidget);
    expect(find.text('1 of 1 Alerted'), findsOneWidget);

    // Verify animated swipe control is rendered
    expect(find.text('Swipe right to arm journey protection'), findsOneWidget);
  });

  testWidgets('JourneySetupScreen evaluates Metro Line availability when Metro Train mode is chosen',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: JourneySetupScreen(
            contacts: const [],
            initialStartLocation: 'Connaught Place, Central Delhi',
            initialStartPoint: const LatLngPoint(latitude: 28.6315, longitude: 77.2167),
            onBack: () {},
            onStartJourney: (start, dest, mode, vehicle, duration, interval, geofence, [selectedContacts, waypoints]) {},
          ),
        ),
      ),
    );
    await tester.pump();

    // Type 'Hauz' into destination field to filter suggestion
    final destField = find.widgetWithText(TextField, 'Destination Address');
    await tester.enterText(destField, 'Hauz');
    await tester.pump();

    // Select Hauz Khas (Direct Yellow Line from Connaught Place / Rajiv Chowk)
    await tester.tap(find.textContaining('Hauz Khas').last);
    await tester.pump();

    // Switch Transport Mode to Metro Train
    await tester.ensureVisible(find.text('Metro Train'));
    await tester.tap(find.text('Metro Train'));
    await tester.pump();

    // Verify Metro Route is available and identifies Yellow Line corridor
    expect(find.text('METRO ROUTE AVAILABLE'), findsOneWidget);
    expect(find.textContaining('Yellow Line'), findsWidgets);
  });

  testWidgets('SatelliteMapView renders locked Follow Mode and smooth map zoom-in controls',
      (WidgetTester tester) async {
    const testLocation = LatLngPoint(
      latitude: 28.6430,
      longitude: 77.2220,
      address: 'New Delhi Railway Station, Paharganj',
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SatelliteMapView(
            location: testLocation,
            height: 300,
          ),
        ),
      ),
    );
    await tester.pump();

    // Verify Follow Mode is locked by default
    expect(find.text('Follow Locked'), findsOneWidget);

    // Verify Zooming In indicator and Skip button
    expect(find.textContaining('ZOOMING IN'), findsOneWidget);
    expect(find.text('Skip'), findsOneWidget);

    // Tap Skip button to finish zoom-in animation immediately
    await tester.tap(find.text('Skip'));
    await tester.pump();

    // Toggle Follow Mode to Free Mode
    await tester.tap(find.text('Follow Locked'));
    await tester.pump();
    expect(find.text('Free Mode'), findsOneWidget);
  });

  testWidgets('JourneySetupScreen provides clean transport modes and route without train or simulated traffic colors',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: JourneySetupScreen(
            contacts: const [],
            initialStartLocation: 'Connaught Place, Central Delhi',
            initialStartPoint: const LatLngPoint(latitude: 28.6430, longitude: 77.2220),
            onBack: () {},
            onStartJourney: (start, dest, mode, vehicle, duration, interval, geofence, [selectedContacts, waypoints]) {},
          ),
        ),
      ),
    );
    await tester.pump();

    // Type 'Dehradun' to trigger destination selection for intercity distance
    final destField = find.widgetWithText(TextField, 'Destination Address');
    await tester.enterText(destField, 'Dehradun');
    await tester.pump();

    // Select Dehradun
    await tester.tap(find.textContaining('Dehradun').last);
    await tester.pump();

    // Verify 'Other' and 'Train / Railway' transport modes are absent
    expect(find.text('Other'), findsNothing);
    expect(find.text('Train / Railway'), findsNothing);
    expect(find.text('Train'), findsNothing);

    // Verify viable transport modes for 315km journey: Cab / Taxi and Public Bus
    expect(find.text('Cab / Taxi'), findsOneWidget);
    expect(find.text('Public Bus'), findsOneWidget);

    // Verify Walking and Auto are excluded for 315km distance
    expect(find.text('Walking'), findsNothing);
    expect(find.text('Auto / Rickshaw'), findsNothing);

    // Verify simulated real-time traffic legend and banners are not shown
    expect(find.text('HEAVY PEAK TRAFFIC'), findsNothing);
    expect(find.text('MODERATE CONGESTION'), findsNothing);
    expect(find.text('Clear'), findsNothing);
    expect(find.text('Moderate'), findsNothing);
    expect(find.text('Heavy'), findsNothing);
    expect(find.text('Refresh Real-Time Traffic'), findsNothing);

    // Verify clean road route HUD and Corridor Geofence protection
    expect(find.text('Road Route'), findsOneWidget);
    expect(find.textContaining('Corridor'), findsWidgets);
  });

  testWidgets('JourneySetupScreen supports per-trip contact selection, adaptive check-in presets, and interactive swipe',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    List<String>? selectedContactResult;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: JourneySetupScreen(
            contacts: const [
              TrustedContact(
                id: 'c1',
                name: 'Aarav Sharma',
                phone: '+91 98111 22233',
                relationship: 'Brother',
              ),
              TrustedContact(
                id: 'c2',
                name: 'Pooja Nair',
                phone: '+91 98222 33344',
                relationship: 'Friend',
              ),
            ],
            initialStartLocation: 'Connaught Place, New Delhi',
            initialStartPoint: const LatLngPoint(latitude: 28.6315, longitude: 77.2167),
            onBack: () {},
            onStartJourney: (start, dest, mode, vehicle, duration, interval, geofence, [selectedContacts, waypoints]) {
              selectedContactResult = selectedContacts;
            },
          ),
        ),
      ),
    );
    await tester.pump();

    // Type destination to show the journey setup details
    final destField = find.widgetWithText(TextField, 'Destination Address');
    await tester.enterText(destField, 'Gurugram');
    await tester.pump();

    await tester.tap(find.textContaining('Gurugram').last);
    await tester.pump();

    // Verify both contacts are rendered with initial selection (2 of 2 Alerted)
    expect(find.text('Escort Guardians for Trip'), findsOneWidget);
    expect(find.text('2 of 2 Alerted'), findsOneWidget);
    expect(find.text('Aarav Sharma'), findsOneWidget);
    expect(find.text('Pooja Nair'), findsOneWidget);
    expect(find.text('Deselect All'), findsOneWidget);

    // Tap on Pooja Nair to deselect her
    await tester.tap(find.text('Pooja Nair'));
    await tester.pump();

    // Now 1 of 2 Alerted
    expect(find.text('1 of 2 Alerted'), findsOneWidget);

    // Tap "Deselect All" to deselect all contacts
    await tester.tap(find.text('Deselect All'));
    await tester.pump();

    // Warning banner appears indicating local-only mode
    expect(find.text('0 of 2 Alerted'), findsOneWidget);
    expect(find.textContaining('Local Mode: No guardians selected'), findsOneWidget);
    expect(find.text('Select All'), findsOneWidget);

    // Tap "Select All" to re-select all contacts
    await tester.tap(find.text('Select All'));
    await tester.pump();
    expect(find.text('2 of 2 Alerted'), findsOneWidget);

    // Verify adaptive check-in presets are visible
    expect(find.text('Adaptive Check-In Frequency'), findsOneWidget);
    expect(find.text('High Alert'), findsOneWidget);
    expect(find.text('Balanced'), findsOneWidget);
    expect(find.text('Relaxed'), findsOneWidget);

    // Tap "High Alert" (5 min interval)
    await tester.tap(find.text('High Alert'));
    await tester.pump();

    // Verify swipe-to-confirm widget is rendered and arm protection
    expect(find.text('Swipe right to arm journey protection'), findsOneWidget);

    // Drag swipe control right to confirm
    await tester.drag(find.byType(SwipeActionControl), const Offset(500, 0));
    await tester.pump(const Duration(milliseconds: 600));

    // Confirm that the selected contacts were passed to onStartJourney
    expect(selectedContactResult, containsAll(['c1', 'c2']));
  });

  testWidgets('HomeScreen renders clean time-based greeting without emoji or name letter icon, and removes vibe-coded companion tools and tips',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HomeScreen(
            userProfile: const UserProfile(name: 'Aanya Rao'),
            contacts: const [
              TrustedContact(
                id: 'c1',
                name: 'Maya Verma',
                phone: '+91 98201 12345',
                relationship: 'Sister',
              ),
            ],
            recentJourneys: const [],
            isOnline: true,
            isCovertActive: false,
            hasActiveJourney: false,
            onStartJourneyClick: () {},
            onViewActiveJourney: () {},
            onQuickEmergency: () {},
            onOpenContacts: () {},
            onOpenScenarios: () {},
            onOpenSettings: () {},
            onViewHistory: () {},
            onToggleTheme: () {},
          ),
        ),
      ),
    );
    await tester.pump();

    // 1. Verify Greeting displays user name without circle letter avatar
    expect(find.text('Aanya Rao'), findsOneWidget);
    // Profile letter icon (circle avatar with 'A') is removed
    expect(find.widgetWithText(CircleAvatar, 'A'), findsNothing);

    // 2. Verify greeting is strictly time-based and has NO emojis
    final hour = DateTime.now().hour;
    final expectedGreeting = (hour >= 5 && hour < 12)
        ? 'Good morning,'
        : (hour >= 12 && hour < 17)
            ? 'Good afternoon,'
            : (hour >= 17 && hour < 22)
                ? 'Good evening,'
                : 'Good night,';
    expect(find.text(expectedGreeting), findsOneWidget);

    // Verify emoji icons are NOT present after greeting
    expect(find.text('☀️'), findsNothing);
    expect(find.text('🌤️'), findsNothing);
    expect(find.text('✨'), findsNothing);
    expect(find.text('🌙'), findsNothing);

    // 3. Verify Vibe check card ('How are you feeling right now?') is REMOVED
    expect(find.text('How are you feeling right now?'), findsNothing);
    expect(find.text('At Ease'), findsNothing);
    expect(find.text('On The Move'), findsNothing);

    // 4. Verify Quick Companion Escort tools grid is REMOVED
    expect(find.text('Quick Companion Escort'), findsNothing);
    expect(find.text('Discreet Call'), findsNothing);
    expect(find.text('Walk With Me'), findsNothing);
    expect(find.text('Reached Safely'), findsNothing);
    expect(find.text('Log Cab Plate'), findsNothing);

    // 5. Verify SheMove Sisterhood Tip is REMOVED
    expect(find.text('SheMove Sisterhood Tip'), findsNothing);

    // 6. Verify core safety controls remain clean and functional
    expect(find.text('Start Protected Journey'), findsOneWidget);
    expect(find.text('Trusted Emergency Circle'), findsOneWidget);
    expect(find.text('Quick Distress Action'), findsOneWidget);
  });

  test('RoutingService calculates dynamic traffic multipliers and walking vs motor transit physics',
      () async {
    // 1. Verify traffic congestion multipliers across times of day
    final morningPeak = RoutingService.getTrafficCongestionMultiplier(DateTime(2026, 10, 28, 9, 30));
    final eveningPeak = RoutingService.getTrafficCongestionMultiplier(DateTime(2026, 10, 28, 18, 30));
    final middayFlow = RoutingService.getTrafficCongestionMultiplier(DateTime(2026, 10, 28, 14, 0));
    final nightFreeFlow = RoutingService.getTrafficCongestionMultiplier(DateTime(2026, 10, 28, 23, 30));

    expect(morningPeak, 1.45);
    expect(eveningPeak, 1.50);
    expect(middayFlow, 1.20);
    expect(nightFreeFlow, 1.00);

    // 2. Verify walking takes much longer than cab/auto for the same distance
    final routingService = RoutingService();
    const startPoint = LatLng(28.6315, 77.2167); // Connaught Place
    const destPoint = LatLng(28.5915, 77.2167);  // ~4.4 km straight south

    final walkRoute = await routingService.calculateRoadRoute(
      start: startPoint,
      destination: destPoint,
      mode: TransportMode.walking,
    );
    final cabRoute = await routingService.calculateRoadRoute(
      start: startPoint,
      destination: destPoint,
      mode: TransportMode.cab,
    );

    // Walking for ~5km takes around 60-70 mins (~4.6 km/h pedestrian pace)
    // Cab takes significantly less time (~15-25 mins including city traffic)
    expect(walkRoute.durationMinutes, greaterThan(cabRoute.durationMinutes * 2));
    expect(walkRoute.distanceKm, greaterThan(0));
  });

  testWidgets('JourneySetupScreen renders dynamic transit timing metrics and context-aware check-in intelligence',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: JourneySetupScreen(
            contacts: const [
              TrustedContact(
                id: 'c1',
                name: 'Aarav Sharma',
                phone: '+91 98111 22233',
                relationship: 'Brother',
              ),
            ],
            initialStartLocation: 'Connaught Place, New Delhi',
            initialStartPoint: const LatLngPoint(latitude: 28.6315, longitude: 77.2167),
            onBack: () {},
            onStartJourney: (start, dest, mode, vehicle, duration, interval, geofence, [selectedContacts, waypoints]) {},
          ),
        ),
      ),
    );
    await tester.pump();

    // Select destination
    final destField = find.widgetWithText(TextField, 'Destination Address');
    await tester.enterText(destField, 'Hauz Khas');
    await tester.pump();

    await tester.tap(find.textContaining('Hauz Khas').last);
    await tester.pump();

    // Verify dynamic timing metrics breakdown is rendered
    expect(find.text('Route Distance'), findsOneWidget);
    expect(find.text('Avg Speed'), findsOneWidget);
    expect(find.text('Traffic Delay'), findsOneWidget);

    // Verify context-aware smart adaptive check-in banner is rendered
    expect(find.text('Adaptive Check-In Frequency'), findsOneWidget);
    expect(find.textContaining('Smart Safety:'), findsOneWidget);
    expect(find.text('High Alert'), findsOneWidget);
    expect(find.text('Balanced'), findsOneWidget);
    expect(find.text('Relaxed'), findsOneWidget);
  });

  testWidgets(
      'ContactsScreen renders clean unified card without duplicate top bar actions or duplicate buttons',
      (WidgetTester tester) async {
    bool pickTapped = false;
    bool addCalled = false;

    await tester.pumpWidget(
      MaterialApp(
        home: ContactsScreen(
          contacts: const [
            TrustedContact(
              id: 'c1',
              name: 'Pooja Sharma',
              phone: '+91 98201 12345',
              relationship: 'Mother',
              isPrimary: true,
            ),
          ],
          emergencyMessageTemplate: 'Emergency: I have missed check-in.',
          onAddContact: (name, phone, rel) {
            addCalled = true;
          },
          onRemoveContact: (id) {},
          onSetPrimary: (id) {},
          onPickDeviceContact: () async {
            pickTapped = true;
            return null;
          },
        ),
      ),
    );
    await tester.pump();

    // Verify top bar actions do not contain duplicate pick or add icons
    expect(find.byType(AppBar), findsOneWidget);
    final appBar = tester.widget<AppBar>(find.byType(AppBar));
    expect(appBar.actions == null || appBar.actions!.isEmpty, true);

    // Verify no floating action button
    expect(find.byType(FloatingActionButton), findsNothing);

    // Verify unified "Add to Safety Circle" card
    expect(find.text('Add to Safety Circle'), findsOneWidget);
    expect(find.text('Pick from Contacts'), findsOneWidget);
    expect(find.text('Add Manually'), findsOneWidget);

    // Verify contact details rendered
    expect(find.text('Pooja Sharma'), findsOneWidget);
    expect(find.text('PRIMARY'), findsOneWidget);
    expect(find.text('Mother'), findsOneWidget);

    // Tap Pick from Contacts
    await tester.tap(find.text('Pick from Contacts'));
    await tester.pump();
    expect(pickTapped, true);

    // Tap Add Manually opens dialog
    await tester.tap(find.text('Add Manually'));
    await tester.pumpAndSettle();
    expect(find.text('Add Trusted Contact'), findsOneWidget);
    expect(find.text('Add Guardian'), findsOneWidget);

    // Enter details and submit
    await tester.enterText(find.widgetWithText(TextField, 'Contact Name'), 'Riya Sen');
    await tester.enterText(find.widgetWithText(TextField, 'Phone Number'), '+91 99999 88888');
    await tester.tap(find.text('Add Guardian'));
    await tester.pumpAndSettle();
    expect(addCalled, true);
  });

  testWidgets(
      'ActiveJourneyScreen renders reverse countdown timer, time modification chips, live map, speedometer, and animated SOS button',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    int modifiedDelta = 0;
    bool emergencyTriggered = false;
    bool manualCheckInTriggered = false;

    final journey = Journey(
      id: 'j_test',
      startAddress: 'Connaught Place',
      destinationAddress: 'Hauz Khas Village',
      transportMode: TransportMode.cab,
      vehicleNumber: 'DL 1Y B 4821',
      estimatedMinutes: 25,
      startTimeMillis: DateTime.now().millisecondsSinceEpoch,
      progressPercent: 0.25,
      status: JourneyStatus.active,
      checkInIntervalMinutes: 8,
      geofenceEnabled: true,
      contactsNotifiedCount: 2,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ActiveJourneyScreen(
          journey: journey,
          checkInSecondsRemaining: 300,
          isOnline: true,
          isCovertActive: false,
          onModifyDuration: (delta) {
            modifiedDelta = delta;
          },
          onManualCheckIn: () {
            manualCheckInTriggered = true;
          },
          onTriggerEmergency: () {
            emergencyTriggered = true;
          },
          onEndJourney: () {},
          onBack: () {},
        ),
      ),
    );
    await tester.pump();

    // 1. Verify Reverse Countdown Timer & Destination Info
    expect(find.text('JOURNEY PROTECTION REMAINING'), findsOneWidget);
    expect(find.text('Hauz Khas Village'), findsOneWidget);
    expect(find.text('25m total'), findsOneWidget);
    expect(find.text('25% completed'), findsOneWidget);

    // 2. Verify Time Modification Controls & Tap '+5m'
    expect(find.text('Extend Trip:'), findsOneWidget);
    expect(find.text('+5m'), findsOneWidget);
    expect(find.text('+10m'), findsOneWidget);
    expect(find.text('+15m'), findsOneWidget);
    expect(find.text('-5m'), findsOneWidget);

    await tester.tap(find.text('+5m'));
    await tester.pump();
    expect(modifiedDelta, 5);

    // 3. Verify Live Moving Map, Speedometer HUD & Live Route Progress HUD
    expect(find.textContaining('KM/H'), findsOneWidget);
    expect(find.textContaining('Live Covered:'), findsOneWidget);
    expect(find.textContaining('Ahead:'), findsOneWidget);

    // 4. Test clicking 'More' button to open Custom Protection Window modal with zero error
    expect(find.text('More'), findsOneWidget);
    await tester.tap(find.text('More'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Modify Protection Window'), findsOneWidget);
    expect(find.textContaining('Heavy Congestion'), findsOneWidget);

    // Select +15 min from sheet
    await tester.tap(find.textContaining('Heavy Congestion'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(modifiedDelta, 15);

    // 5. Verify Next Check-in Reminder Card
    expect(find.text('Next Adaptive Check-In'), findsOneWidget);
    expect(find.text('Check In Now'), findsOneWidget);
    await tester.tap(find.text('Check In Now'));
    await tester.pump();
    expect(manualCheckInTriggered, true);

    // 6. Verify Improved Animated SOS Hold Button
    expect(find.text('HOLD SOS FOR 3s TO ESCALATE'), findsOneWidget);
    expect(find.text('Instant priority alert to guardians & police'), findsOneWidget);

    // Long press SOS for 3 seconds
    final sosFinder = find.text('HOLD SOS FOR 3s TO ESCALATE');
    final gesture = await tester.startGesture(tester.getCenter(sosFinder));
    await tester.pump(const Duration(milliseconds: 1500));
    expect(find.textContaining('HOLDING SOS'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1600));
    await gesture.up();
    await tester.pump();
    expect(emergencyTriggered, true);
  });

  test(
      'SafeLoopState navigation stack navigates back to journey planner when returning from contacts',
      () {
    final state = SafeLoopState(locationService: FakeLocationService());
    if (state.currentScreen == SafeLoopScreen.onboarding) {
      state.completeOnboarding();
      state.completeSecuritySetup('Aanya Rao', '+91 98112 34567', '1234', true);
    }
    expect(state.currentScreen, SafeLoopScreen.home);

    // Open Journey Planner from Home
    state.navigateTo(SafeLoopScreen.journeyPlanner);
    expect(state.currentScreen, SafeLoopScreen.journeyPlanner);

    // Add contact from Journey Planner
    state.navigateTo(SafeLoopScreen.contacts);
    expect(state.currentScreen, SafeLoopScreen.contacts);

    // Press Back on Contacts: returns to Journey Planner (NOT Home!)
    state.navigateBack();
    expect(state.currentScreen, SafeLoopScreen.journeyPlanner);

    // Press Back on Journey Planner: returns to Home
    state.navigateBack();
    expect(state.currentScreen, SafeLoopScreen.home);
  });

  test(
      'SafeLoopState triggers check-in due with 60s window and escalates to escalationWarning if unanswered',
      () {
    final state = SafeLoopState(locationService: FakeLocationService());
    if (state.currentScreen == SafeLoopScreen.onboarding) {
      state.completeOnboarding();
      state.completeSecuritySetup('Aanya Rao', '+91 98112 34567', '1234', true);
    }
    state.startJourney(
      start: 'Connaught Place',
      destination: 'Hauz Khas',
      mode: TransportMode.cab,
      vehicleNo: 'DL 1Y 1234',
      durationMinutes: 20,
      intervalMinutes: 5,
      geofence: true,
    );
    expect(state.currentScreen, SafeLoopScreen.activeJourney);

    // Trigger check-in due
    state.triggerCheckInDue();
    expect(state.currentScreen, SafeLoopScreen.safetyCheckIn);
    expect(state.checkInWindowSecondsRemaining, 60);

    // Call startEscalationWarning (simulating expiration of 1-minute window)
    state.startEscalationWarning();
    expect(state.currentScreen, SafeLoopScreen.escalationWarning);
    expect(state.escalationSecondsRemaining, 45);
  });
}
