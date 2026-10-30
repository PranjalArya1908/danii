import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:geolocator/geolocator.dart';
import '../models/models.dart';
import '../services/contacts_service.dart';
import '../services/gemini_service.dart';
import '../services/location_service.dart';

enum SafeLoopScreen {
  onboarding,
  setup,
  home,
  journeyPlanner,
  activeJourney,
  safetyCheckIn,
  escalationWarning,
  emergencyActive,
  journeyCompleted,
  history,
  contacts,
  settings,
}

typedef SheMoveScreen = SafeLoopScreen;

class SafeLoopState extends ChangeNotifier {
  SafeLoopScreen _currentScreen = SafeLoopScreen.home;
  final List<SafeLoopScreen> _screenStack = [SafeLoopScreen.home];
  UserProfile _userProfile = const UserProfile();
  Journey? _activeJourney;
  List<TrustedContact> _contacts = const [];
  List<Journey> _history = const [];
  List<SafetyEvent> _events = const [];
  LatLngPoint _currentLocation = LocationService.defaultFallbackLocation;
  double _currentHeading = 0.0;
  double _currentSpeedKmh = 0.0;
  bool _hasLocationPermission = false;
  bool _isLocationLoading = false;
  bool _isLiveGpsActive = false;
  String? _locationStatusMessage;
  final LocationService _locationService;
  final ContactsService _contactsService;
  StreamSubscription<Position>? _positionSubscription;
  StreamSubscription<CompassEvent>? _compassSubscription;
  int _lastReverseGeocodeMillis = 0;
  double _lastGeocodedLat = 0.0;
  double _lastGeocodedLon = 0.0;
  int _checkInSecondsRemaining = 600;
  int _escalationSecondsRemaining = 45;
  bool _isOnline = true;
  bool _isCovertDistressActive = false;
  String? _toastMessage;
  bool _showScenarioPicker = false;
  Journey? _selectedHistoryJourney;
  Journey? _lastCompletedJourney;

  Timer? _journeyTicker;
  Timer? _escalationTicker;
  Timer? _checkInWindowTicker;
  int _checkInWindowSecondsRemaining = 60;

  SafeLoopState({
    LocationService? locationService,
    ContactsService? contactsService,
  })  : _locationService = locationService ?? LocationService(),
        _contactsService = contactsService ?? ContactsService() {
    _initDefaultData();
    initLocationTracking();
  }

  void _initDefaultData() {
    _userProfile = const UserProfile(
      name: 'Aanya Rao',
      phone: '+91 98112 34567',
      safetyPin: '1234',
      duressPin: '9999',
      biometricEnabled: true,
      defaultCheckInMinutes: 10,
      adaptiveFrequencyEnabled: true,
      isDarkMode: true,
      isSetupComplete: false, // Starts with onboarding for demonstration
    );

    _contacts = const [];

    final now = DateTime.now().millisecondsSinceEpoch;
    _history = [
      Journey(
        id: 'h1',
        startAddress: 'Cyber City Metro Station, Gate 2',
        destinationAddress: 'Palm Springs Condos, Sector 54',
        transportMode: TransportMode.cab,
        vehicleNumber: 'DL 1Y B 4821',
        estimatedMinutes: 22,
        startTimeMillis: now - 86400000 * 1,
        progressPercent: 1.0,
        status: JourneyStatus.completed,
        notes: 'Arrived on time. 2 adaptive check-ins confirmed.',
      ),
      Journey(
        id: 'h2',
        startAddress: 'Tech Hub Tower C',
        destinationAddress: 'Blueberry Cafe, Green Park',
        transportMode: TransportMode.auto,
        vehicleNumber: 'DL 1R Z 3310',
        estimatedMinutes: 18,
        startTimeMillis: now - 86400000 * 2,
        progressPercent: 1.0,
        status: JourneyStatus.completed,
        notes: 'Safe arrival verified by emergency contacts.',
      ),
      Journey(
        id: 'h3',
        startAddress: 'Central Library',
        destinationAddress: 'University South Campus',
        transportMode: TransportMode.walking,
        vehicleNumber: '',
        estimatedMinutes: 15,
        startTimeMillis: now - 86400000 * 4,
        progressPercent: 1.0,
        status: JourneyStatus.completed,
        notes: 'Evening walk, companion check-in active.',
      ),
    ];

    _events = [
      SafetyEvent(
        id: 'ev0',
        timestamp: now - 1000 * 60 * 30,
        title: 'SheMove Initialized',
        description: 'Background protection active. GPS telemetry synchronized.',
        severity: EventSeverity.info,
      ),
    ];

    if (!_userProfile.isSetupComplete) {
      _currentScreen = SafeLoopScreen.onboarding;
    }
  }

  // Getters
  SafeLoopScreen get currentScreen => _currentScreen;
  UserProfile get userProfile => _userProfile;
  Journey? get activeJourney => _activeJourney;
  List<TrustedContact> get contacts => _contacts;
  List<Journey> get history => _history;
  List<SafetyEvent> get events => _events;
  LatLngPoint get currentLocation => _currentLocation;
  double get currentHeading => _currentHeading;
  double get currentSpeedKmh => _currentSpeedKmh;
  bool get hasLocationPermission => _hasLocationPermission;
  bool get isLocationLoading => _isLocationLoading;
  bool get isLiveGpsActive => _isLiveGpsActive;
  String? get locationStatusMessage => _locationStatusMessage;
  int get checkInSecondsRemaining => _checkInSecondsRemaining;
  int get checkInWindowSecondsRemaining => _checkInWindowSecondsRemaining;
  int get escalationSecondsRemaining => _escalationSecondsRemaining;
  bool get isOnline => _isOnline;
  bool get isCovertDistressActive => _isCovertDistressActive;
  String? get toastMessage => _toastMessage;
  bool get showScenarioPicker => _showScenarioPicker;
  Journey? get selectedHistoryJourney => _selectedHistoryJourney;
  Journey? get lastCompletedJourney => _lastCompletedJourney;

  bool get hasActiveJourney =>
      _activeJourney != null && _activeJourney!.status != JourneyStatus.completed;

  // Navigation
  void navigateTo(SafeLoopScreen screen) {
    if (screen == SafeLoopScreen.home) {
      _screenStack
        ..clear()
        ..add(SafeLoopScreen.home);
      _currentScreen = SafeLoopScreen.home;
    } else {
      if (_currentScreen != screen) {
        if (_screenStack.isEmpty || _screenStack.last != screen) {
          _screenStack.add(screen);
        }
        _currentScreen = screen;
      }
    }
    notifyListeners();
  }

  void navigateBack() {
    if (_screenStack.length > 1) {
      _screenStack.removeLast();
      _currentScreen = _screenStack.last;
    } else {
      _currentScreen = SafeLoopScreen.home;
      _screenStack
        ..clear()
        ..add(SafeLoopScreen.home);
    }
    notifyListeners();
  }

  void toggleScenarioPicker([bool? show]) {
    _showScenarioPicker = show ?? !_showScenarioPicker;
    notifyListeners();
  }

  void selectHistoryJourney(Journey? journey) {
    _selectedHistoryJourney = journey;
    notifyListeners();
  }

  // Real-Time Location Services
  Future<void> initLocationTracking() async {
    _startCompassStream();
    try {
      final permission = await _locationService.checkPermission();
      if (_locationService.isPermissionGranted(permission)) {
        _hasLocationPermission = true;
        await _fetchCurrentGpsPosition();
        _startLocationStream();
      } else {
        _hasLocationPermission = false;
      }
      notifyListeners();
    } catch (e) {
      debugPrint('SafeLoopState: Error initializing location: $e');
    }
  }

  Future<bool> requestLocationPermission() async {
    _startCompassStream();
    _isLocationLoading = true;
    _locationStatusMessage = 'Requesting GPS access...';
    notifyListeners();

    try {
      final permission = await _locationService.requestPermission();
      if (_locationService.isPermissionGranted(permission)) {
        _hasLocationPermission = true;
        _locationStatusMessage = 'Acquiring satellite lock...';
        notifyListeners();

        await _fetchCurrentGpsPosition();
        _startLocationStream();
        _isLocationLoading = false;
        _locationStatusMessage = null;

        _addSafetyEvent(
          'Real-Time GPS Synchronized',
          'Live satellite telemetry active at ${_currentLocation.address}',
          EventSeverity.success,
          _currentLocation.address,
        );
        notifyListeners();
        return true;
      } else {
        _hasLocationPermission = false;
        _isLocationLoading = false;
        _locationStatusMessage = 'Location permission was denied';
        notifyListeners();
        return false;
      }
    } catch (e) {
      debugPrint('SafeLoopState: Error requesting location permission: $e');
      _isLocationLoading = false;
      _locationStatusMessage = 'Unable to acquire GPS';
      notifyListeners();
      return false;
    }
  }

  Future<void> refreshCurrentLocation() async {
    _isLocationLoading = true;
    notifyListeners();
    await _fetchCurrentGpsPosition();
    _isLocationLoading = false;
    notifyListeners();
  }

  Future<void> _fetchCurrentGpsPosition() async {
    final result = await _locationService.getCurrentLocation();
    if (result.isLive) {
      _currentLocation = result.point;
      _isLiveGpsActive = true;
      _locationStatusMessage = null;
    } else if (result.error != null) {
      _locationStatusMessage = result.error;
    }
  }

  void _startLocationStream() {
    try {
      _positionSubscription?.cancel();
      final stream = _locationService.getPositionStream(distanceFilterMeters: 2);
      if (stream != null) {
        _positionSubscription = stream.listen((position) {
          // 1. Immediately reflect coordinates, speed and movement heading in state
          _currentLocation = LatLngPoint(
            latitude: position.latitude,
            longitude: position.longitude,
            address: _currentLocation.address,
          );
          if (position.heading > 0) {
            _currentHeading = position.heading;
          }
          _currentSpeedKmh = position.speed >= 0 ? position.speed * 3.6 : 0.0;
          _isLiveGpsActive = true;

          // If journey is active and has waypoints, update progress directly from live GPS
          if (_activeJourney != null && _activeJourney!.status == JourneyStatus.active) {
            if (_activeJourney!.waypoints.length >= 2) {
              final gpsProg = _computeGpsProgress(_activeJourney!.waypoints);
              _activeJourney = _activeJourney!.copyWith(progressPercent: gpsProg);
            }
          }
          notifyListeners();

          // 2. Throttle reverse geocoding in background so stream is never blocked
          _maybeUpdateAddress(position.latitude, position.longitude);
        }, onError: (err) {
          debugPrint('SafeLoopState: Location stream error: $err');
        });
      }
    } catch (e) {
      debugPrint('SafeLoopState: Error starting location stream: $e');
    }
  }

  void _startCompassStream() {
    _compassSubscription?.cancel();
    try {
      final stream = FlutterCompass.events;
      if (stream != null) {
        _compassSubscription = stream.listen((event) {
          if (event.heading != null) {
            final newHeading = (event.heading! % 360 + 360) % 360;
            if ((newHeading - _currentHeading).abs() > 0.5) {
              _currentHeading = newHeading;
              notifyListeners();
            }
          }
        }, onError: (err) {
          debugPrint('SafeLoopState: Compass stream error: $err');
        });
      }
    } catch (e) {
      debugPrint('SafeLoopState: Error subscribing to compass events: $e');
    }
  }

  void _maybeUpdateAddress(double lat, double lon) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final distApprox = ((lat - _lastGeocodedLat).abs() + (lon - _lastGeocodedLon).abs());
    if (now - _lastReverseGeocodeMillis > 15000 || distApprox > 0.001) {
      _lastReverseGeocodeMillis = now;
      _lastGeocodedLat = lat;
      _lastGeocodedLon = lon;
      _locationService.reverseGeocode(lat, lon).then((addr) {
        if (addr.isNotEmpty && addr != _currentLocation.address) {
          _currentLocation = LatLngPoint(
            latitude: _currentLocation.latitude,
            longitude: _currentLocation.longitude,
            address: addr,
          );
          notifyListeners();
        }
      }).catchError((_) {});
    }
  }

  ContactsService get contactsService => _contactsService;

  Future<bool> requestContactsPermission() async {
    return await _contactsService.requestPermission();
  }

  Future<TrustedContact?> pickContactFromDevice({String relationship = 'Family'}) async {
    final picked = await _contactsService.pickContact();
    if (picked != null) {
      final now = DateTime.now().millisecondsSinceEpoch;
      final newContact = TrustedContact(
        id: 'c_${picked.id}_$now',
        name: picked.name,
        phone: picked.phone,
        relationship: relationship,
        isPrimary: _contacts.isEmpty,
        isVerified: true,
      );
      _contacts = [..._contacts, newContact];
      _addSafetyEvent(
        'Trusted Contact Added',
        '${picked.name} ($relationship) added from device address book.',
        EventSeverity.info,
      );
      notifyListeners();
      return newContact;
    }
    return null;
  }

  void completeOnboarding() {
    _screenStack
      ..clear()
      ..add(SafeLoopScreen.setup);
    _currentScreen = SafeLoopScreen.setup;
    notifyListeners();
  }

  void completeSecuritySetup(
    String name,
    String phone,
    String pin,
    bool biometric, [
    List<TrustedContact>? initialContacts,
  ]) {
    _userProfile = _userProfile.copyWith(
      name: name.trim().isNotEmpty ? name.trim() : _userProfile.name,
      phone: phone.trim().isNotEmpty ? phone.trim() : _userProfile.phone,
      safetyPin: pin.trim().isNotEmpty ? pin.trim() : _userProfile.safetyPin,
      biometricEnabled: biometric,
      isSetupComplete: true,
    );
    if (initialContacts != null && initialContacts.isNotEmpty) {
      _contacts = initialContacts;
    }
    _addSafetyEvent(
      'Account Setup Complete',
      'Profile registered with ${_contacts.length} trusted emergency contact(s).',
      EventSeverity.success,
    );
    _screenStack
      ..clear()
      ..add(SafeLoopScreen.home);
    _currentScreen = SafeLoopScreen.home;
    notifyListeners();
  }

  // Start Journey
  void startJourney({
    required String start,
    required String destination,
    required TransportMode mode,
    required String vehicleNo,
    required int durationMinutes,
    required int intervalMinutes,
    required bool geofence,
    List<String>? selectedContactIds,
    List<LatLngPoint>? waypoints,
  }) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final notifiedCount = selectedContactIds != null
        ? selectedContactIds.length
        : _contacts.length;

    double initialProgress = 0.0;
    if (waypoints != null && waypoints.length >= 2) {
      initialProgress = _computeGpsProgress(waypoints);
    }

    final newJourney = Journey(
      id: 'j_$now',
      startAddress: start.trim().isNotEmpty ? start.trim() : 'Connaught Place Inner Circle',
      destinationAddress:
          destination.trim().isNotEmpty ? destination.trim() : 'Hauz Khas Village',
      transportMode: mode,
      vehicleNumber: vehicleNo.trim(),
      estimatedMinutes: durationMinutes,
      startTimeMillis: now,
      progressPercent: initialProgress,
      status: JourneyStatus.active,
      checkInIntervalMinutes: intervalMinutes,
      geofenceEnabled: geofence,
      contactsNotifiedCount: notifiedCount,
      waypoints: waypoints ?? const [],
    );

    _activeJourney = newJourney;
    _checkInSecondsRemaining = intervalMinutes * 60;
    _isCovertDistressActive = false;

    _contacts = _contacts.map((c) {
      final isSelected = selectedContactIds == null || selectedContactIds.contains(c.id);
      return c.copyWith(
        notificationStatus: isSelected
            ? ContactNotificationStatus.sent
            : ContactNotificationStatus.idle,
      );
    }).toList();

    _addSafetyEvent(
      'Protected Journey Started',
      'Mode: ${mode.label}${vehicleNo.isNotEmpty ? " ($vehicleNo)" : ""}. Route monitoring active. $notifiedCount guardian(s) alerted.',
      EventSeverity.info,
      start,
    );

    _startJourneySimulation();
    _screenStack
      ..clear()
      ..add(SafeLoopScreen.home)
      ..add(SafeLoopScreen.activeJourney);
    _currentScreen = SafeLoopScreen.activeJourney;
    notifyListeners();
  }

  void _startJourneySimulation() {
    _journeyTicker?.cancel();
    _journeyTicker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_activeJourney == null || _activeJourney!.status != JourneyStatus.active) {
        timer.cancel();
        return;
      }

      // Check-in timer countdown
      final remaining = _checkInSecondsRemaining - 1;
      if (remaining <= 0) {
        _checkInSecondsRemaining = 0;
        triggerCheckInDue();
        timer.cancel();
      } else {
        _checkInSecondsRemaining = remaining;
      }
      notifyListeners();
    });
  }

  /// Compute journey progress (0.0-1.0) by snapping current GPS position to nearest route segment.
  double _computeGpsProgress(List<LatLngPoint> waypoints) {
    if (waypoints.length < 2) return 0.05;

    final gpsLat = _currentLocation.latitude;
    final gpsLon = _currentLocation.longitude;

    // Compute cumulative distances along waypoint chain
    final cumulativeDistances = <double>[0.0];
    double totalDist = 0.0;
    for (int i = 1; i < waypoints.length; i++) {
      final dLat = waypoints[i].latitude - waypoints[i - 1].latitude;
      final dLon = waypoints[i].longitude - waypoints[i - 1].longitude;
      totalDist += _haversineApprox(dLat, dLon, waypoints[i - 1].latitude);
      cumulativeDistances.add(totalDist);
    }

    if (totalDist < 0.0001) return 0.05;

    // Find the nearest segment and project GPS onto it
    double bestDist = double.infinity;
    double bestProgress = 0.0;

    for (int i = 0; i < waypoints.length - 1; i++) {
      final ax = waypoints[i].latitude;
      final ay = waypoints[i].longitude;
      final bx = waypoints[i + 1].latitude;
      final by = waypoints[i + 1].longitude;

      // Project GPS point onto segment [A, B]
      final dx = bx - ax;
      final dy = by - ay;
      final segLenSq = dx * dx + dy * dy;
      double t = 0.0;
      if (segLenSq > 0) {
        t = ((gpsLat - ax) * dx + (gpsLon - ay) * dy) / segLenSq;
        t = t.clamp(0.0, 1.0);
      }

      final projLat = ax + t * dx;
      final projLon = ay + t * dy;
      final dist = _haversineApprox(gpsLat - projLat, gpsLon - projLon, gpsLat);

      if (dist < bestDist) {
        bestDist = dist;
        final segStart = cumulativeDistances[i];
        final segEnd = cumulativeDistances[i + 1];
        final segDist = segStart + t * (segEnd - segStart);
        bestProgress = segDist / totalDist;
      }
    }

    return bestProgress.clamp(0.01, 0.98);
  }

  /// Quick haversine-like distance approximation in degrees-to-km.
  double _haversineApprox(double dLat, double dLon, double refLat) {
    const kmPerDegLat = 111.32;
    final kmPerDegLon = 111.32 * (refLat * 3.14159265 / 180.0).abs().clamp(0.0, 1.5707) == 0
        ? 111.32
        : 111.32 * _cosApprox(refLat * 3.14159265 / 180.0);
    final dy = dLat * kmPerDegLat;
    final dx = dLon * kmPerDegLon;
    return (dy * dy + dx * dx); // Squared distance is fine for comparison
  }

  double _cosApprox(double rad) {
    // Simple cos approximation for latitude scaling
    final x = rad.abs();
    if (x > 1.5707) return 0.0;
    return 1.0 - x * x / 2.0 + x * x * x * x / 24.0;
  }

  void modifyJourneyDuration(int deltaMinutes) {
    if (_activeJourney == null) return;
    final current = _activeJourney!;
    final newMinutes = (current.estimatedMinutes + deltaMinutes).clamp(5, 360);
    _activeJourney = current.copyWith(estimatedMinutes: newMinutes);
    _addSafetyEvent(
      'Protection Window Adjusted',
      'Protection window adjusted by ${deltaMinutes >= 0 ? "+$deltaMinutes" : "$deltaMinutes"} min. Total: $newMinutes min.',
      EventSeverity.info,
    );
    notifyListeners();
  }

  void triggerCheckInDue() {
    if (_activeJourney == null) return;
    _activeJourney = _activeJourney!.copyWith(status: JourneyStatus.checkInDue);
    _checkInWindowSecondsRemaining = 60; // 1-minute window to respond

    _addSafetyEvent(
      'Safety Check-In Due',
      'Adaptive check-in prompt displayed. 60-second response window active before escalation.',
      EventSeverity.warning,
    );
    if (!_screenStack.contains(SafeLoopScreen.safetyCheckIn)) {
      _screenStack.add(SafeLoopScreen.safetyCheckIn);
    }
    _currentScreen = SafeLoopScreen.safetyCheckIn;

    // Start 1-minute check-in countdown ticker. If not answered within 60s, escalate!
    _checkInWindowTicker?.cancel();
    _checkInWindowTicker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_checkInWindowSecondsRemaining > 0) {
        _checkInWindowSecondsRemaining--;
        notifyListeners();
      } else {
        timer.cancel();
        if (_activeJourney?.status == JourneyStatus.checkInDue) {
          startEscalationWarning();
        }
      }
    });

    notifyListeners();
  }

  void handleCheckInSafetyConfirm(String enteredPin, {bool isBiometric = false}) {
    if (isBiometric || enteredPin == _userProfile.safetyPin) {
      confirmSafeFromCheckIn(verifiedWithDuress: false);
      _screenStack.remove(SafeLoopScreen.safetyCheckIn);
      _currentScreen = SafeLoopScreen.activeJourney;
    } else if (enteredPin == _userProfile.duressPin) {
      confirmSafeFromCheckIn(verifiedWithDuress: true);
      _screenStack.remove(SafeLoopScreen.safetyCheckIn);
      _currentScreen = SafeLoopScreen.activeJourney;
    }
    notifyListeners();
  }

  void confirmSafeFromCheckIn({bool verifiedWithDuress = false}) {
    _checkInWindowTicker?.cancel();
    if (_activeJourney == null) return;

    if (verifiedWithDuress) {
      _isCovertDistressActive = true;
      _activeJourney = _activeJourney!.copyWith(status: JourneyStatus.covertDuress);
      _contacts = _contacts
          .map((c) => c.copyWith(notificationStatus: ContactNotificationStatus.delivered))
          .toList();

      _addSafetyEvent(
        'Covert Distress Alert Activated',
        'Duress PIN entered silently. Contacts notified with covert tracking link.',
        EventSeverity.critical,
      );
      _toastMessage = 'Safety confirmed'; // Pretend normal confirmation
    } else {
      _activeJourney = _activeJourney!.copyWith(status: JourneyStatus.active);
      _checkInSecondsRemaining = _activeJourney!.checkInIntervalMinutes * 60;

      _addSafetyEvent(
        'Safety Confirmed',
        'User authenticated successfully. Protection timer reset.',
        EventSeverity.success,
      );
      _toastMessage = 'Journey safety confirmed';
      _startJourneySimulation();
    }
    notifyListeners();
  }

  void handleCheckInNeedHelp() {
    _checkInWindowTicker?.cancel();
    triggerFullEmergency('User requested immediate help during safety check-in');
  }

  void startEscalationWarning() {
    if (_activeJourney == null) return;
    _activeJourney = _activeJourney!.copyWith(status: JourneyStatus.escalating);
    _escalationSecondsRemaining = 45;

    _addSafetyEvent(
      'Check-In Missed: Escalation Initiated',
      'Grace period timer active. Contacts will be notified if not cancelled.',
      EventSeverity.warning,
    );

    _escalationTicker?.cancel();
    _escalationTicker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_escalationSecondsRemaining > 0) {
        _escalationSecondsRemaining--;
        notifyListeners();
      } else {
        timer.cancel();
        if (_activeJourney?.status == JourneyStatus.escalating) {
          triggerFullEmergency('Missed check-in grace period expired');
        }
      }
    });

    _screenStack.remove(SafeLoopScreen.safetyCheckIn);
    if (!_screenStack.contains(SafeLoopScreen.escalationWarning)) {
      _screenStack.add(SafeLoopScreen.escalationWarning);
    }
    _currentScreen = SafeLoopScreen.escalationWarning;
    notifyListeners();
  }

  bool cancelEscalationWithPin(String pin) {
    if (pin == _userProfile.safetyPin) {
      _escalationTicker?.cancel();
      confirmSafeFromCheckIn(verifiedWithDuress: false);
      _screenStack.remove(SafeLoopScreen.escalationWarning);
      _currentScreen = SafeLoopScreen.activeJourney;
      notifyListeners();
      return true;
    } else if (pin == _userProfile.duressPin) {
      _escalationTicker?.cancel();
      confirmSafeFromCheckIn(verifiedWithDuress: true);
      _screenStack.remove(SafeLoopScreen.escalationWarning);
      _currentScreen = SafeLoopScreen.activeJourney;
      notifyListeners();
      return true;
    }
    return false;
  }

  void triggerEmergencyNow([String reason = 'Manual SOS Activated']) {
    triggerFullEmergency(reason);
  }

  void triggerFullEmergency([String reason = 'Manual SOS Activated']) {
    _journeyTicker?.cancel();
    _escalationTicker?.cancel();
    _checkInWindowTicker?.cancel();

    final now = DateTime.now().millisecondsSinceEpoch;
    _activeJourney = (_activeJourney ??
            Journey(
              id: 'j_emergency_$now',
              startAddress: 'Current Location',
              destinationAddress: 'Emergency Response',
              transportMode: TransportMode.walking,
              startTimeMillis: now,
              status: JourneyStatus.emergency,
            ))
        .copyWith(status: JourneyStatus.emergency);

    _contacts = _contacts.asMap().entries.map((entry) {
      final idx = entry.key;
      final contact = entry.value;
      if (idx == 0) {
        return contact.copyWith(
          notificationStatus: ContactNotificationStatus.acknowledged,
          acknowledgedTimeAgo: 'Just now',
        );
      } else {
        return contact.copyWith(
          notificationStatus: ContactNotificationStatus.delivered,
        );
      }
    }).toList();

    _addSafetyEvent(
      'CRITICAL EMERGENCY ALERT',
      '$reason. Live GPS coordinates and audio telemetry broadcasted.',
      EventSeverity.critical,
    );

    _screenStack.remove(SafeLoopScreen.safetyCheckIn);
    _screenStack.remove(SafeLoopScreen.escalationWarning);
    if (!_screenStack.contains(SafeLoopScreen.emergencyActive)) {
      _screenStack.add(SafeLoopScreen.emergencyActive);
    }
    _currentScreen = SafeLoopScreen.emergencyActive;
    notifyListeners();
  }

  bool disarmEmergency(String pinEntered) {
    if (pinEntered == _userProfile.safetyPin) {
      _escalationTicker?.cancel();
      _screenStack.remove(SafeLoopScreen.emergencyActive);
      if (_activeJourney != null) {
        _activeJourney = _activeJourney!.copyWith(status: JourneyStatus.active);
        _checkInSecondsRemaining = _activeJourney!.checkInIntervalMinutes * 60;
        _startJourneySimulation();
        _currentScreen = SafeLoopScreen.activeJourney;
      } else {
        _activeJourney = null;
        _screenStack
          ..clear()
          ..add(SafeLoopScreen.home);
        _currentScreen = SafeLoopScreen.home;
      }
      _isCovertDistressActive = false;
      _addSafetyEvent(
        'Emergency Disarmed',
        'User successfully disarmed alert with security PIN.',
        EventSeverity.success,
      );
      _toastMessage = 'Emergency successfully disarmed';
      notifyListeners();
      return true;
    } else if (pinEntered == _userProfile.duressPin) {
      _toastMessage = 'Alert disarmed';
      _isCovertDistressActive = true;
      _addSafetyEvent(
        'Silent Distress Continued',
        'Duress PIN entered on emergency disarm screen.',
        EventSeverity.critical,
      );
      _screenStack.remove(SafeLoopScreen.emergencyActive);
      _currentScreen = SafeLoopScreen.activeJourney;
      notifyListeners();
      return true;
    }
    return false;
  }

  void completeActiveJourney() {
    _journeyTicker?.cancel();
    _escalationTicker?.cancel();
    _checkInWindowTicker?.cancel();
    if (_activeJourney == null) return;

    final completed = _activeJourney!.copyWith(
      status: JourneyStatus.completed,
      progressPercent: 1.0,
    );

    _history = [completed, ..._history];
    _activeJourney = completed;
    _lastCompletedJourney = completed;

    _contacts = _contacts
        .map((c) => c.copyWith(
              notificationStatus: ContactNotificationStatus.acknowledged,
              acknowledgedTimeAgo: 'Safe arrival',
            ))
        .toList();

    _addSafetyEvent(
      'Destination Reached Safely',
      'Safe arrival confirmed at ${completed.destinationAddress}.',
      EventSeverity.success,
    );

    _screenStack
      ..clear()
      ..add(SafeLoopScreen.home)
      ..add(SafeLoopScreen.journeyCompleted);
    _currentScreen = SafeLoopScreen.journeyCompleted;
    notifyListeners();
  }

  void exitJourneyToHome() {
    _activeJourney = null;
    _isCovertDistressActive = false;
    _contacts = _contacts
        .map((c) => c.copyWith(notificationStatus: ContactNotificationStatus.idle))
        .toList();
    _screenStack
      ..clear()
      ..add(SafeLoopScreen.home);
    _currentScreen = SafeLoopScreen.home;
    notifyListeners();
  }

  void addContact(String name, String phone, String relationship) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final newC = TrustedContact(
      id: 'c_$now',
      name: name,
      phone: phone,
      relationship: relationship,
      isPrimary: _contacts.isEmpty,
      isVerified: true,
    );
    _contacts = [..._contacts, newC];
    _addSafetyEvent(
      'Trusted Contact Added',
      '$name ($relationship) added.',
      EventSeverity.info,
    );
    notifyListeners();
  }

  void removeContact(String id) {
    final removed = _contacts.where((c) => c.id == id).firstOrNull;
    _contacts = _contacts.where((c) => c.id != id).toList();
    if (removed != null) {
      _addSafetyEvent(
        'Contact Removed',
        '${removed.name} removed from circle.',
        EventSeverity.info,
      );
    }
    notifyListeners();
  }

  void setPrimaryContact(String id) {
    _contacts = _contacts.map((c) => c.copyWith(isPrimary: c.id == id)).toList();
    notifyListeners();
  }

  void updateProfile(UserProfile profile) {
    _userProfile = profile;
    if (profile.geminiApiKey.isNotEmpty) {
      GeminiSafetyService.setApiKey(profile.geminiApiKey);
    }
    notifyListeners();
  }

  void toggleTheme() {
    _userProfile = _userProfile.copyWith(isDarkMode: !_userProfile.isDarkMode);
    notifyListeners();
  }

  void toggleOffline([bool? offline]) {
    final newOnline = offline != null ? !offline : !_isOnline;
    _isOnline = newOnline;
    if (!_isOnline) {
      _addSafetyEvent(
        'Network Offline',
        'Cellular data down. SheMove switched to encrypted SMS & offline mesh beacon.',
        EventSeverity.warning,
      );
    } else {
      _addSafetyEvent(
        'Network Reconnected',
        'Cloud telemetry re-synchronized.',
        EventSeverity.success,
      );
    }
    notifyListeners();
  }

  void clearToast() {
    _toastMessage = null;
    notifyListeners();
  }

  void _addSafetyEvent(
    String title,
    String desc,
    EventSeverity severity, [
    String? location,
  ]) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final event = SafetyEvent(
      id: 'ev_$now',
      timestamp: now,
      title: title,
      description: desc,
      severity: severity,
      location: location ?? _currentLocation.address,
    );
    _events = [event, ..._events];
  }

  // Demo Scenarios Handler
  void runDemoScenario(String scenarioId) {
    _showScenarioPicker = false;
    switch (scenarioId) {
      case 'normal_journey':
        startJourney(
          start: 'Connaught Place, Radial 3',
          destination: 'Hauz Khas Village',
          mode: TransportMode.cab,
          vehicleNo: 'DL 1Y B 9904',
          durationMinutes: 25,
          intervalMinutes: 8,
          geofence: true,
        );
        break;
      case 'trigger_checkin':
        if (_activeJourney == null || _activeJourney!.status == JourneyStatus.emergency || _activeJourney!.status == JourneyStatus.completed) {
          startJourney(
            start: 'Cyber Hub Gate 1',
            destination: 'Golf Course Road',
            mode: TransportMode.auto,
            vehicleNo: 'HR 26 AZ 4512',
            durationMinutes: 15,
            intervalMinutes: 5,
            geofence: true,
          );
        }
        triggerCheckInDue();
        break;
      case 'missed_checkin':
        if (_activeJourney == null || _activeJourney!.status == JourneyStatus.emergency || _activeJourney!.status == JourneyStatus.completed) {
          startJourney(
            start: 'Sector 18 Metro',
            destination: 'Botanical Garden',
            mode: TransportMode.walking,
            vehicleNo: '',
            durationMinutes: 20,
            intervalMinutes: 5,
            geofence: true,
          );
        }
        startEscalationWarning();
        break;
      case 'test_duress_pin':
        if (_activeJourney == null || _activeJourney!.status == JourneyStatus.emergency || _activeJourney!.status == JourneyStatus.completed) {
          startJourney(
            start: 'Aerocity Hospitality Dist',
            destination: 'Vasant Vihar',
            mode: TransportMode.cab,
            vehicleNo: 'DL 1Z 7721',
            durationMinutes: 18,
            intervalMinutes: 5,
            geofence: true,
          );
        }
        triggerCheckInDue();
        break;
      case 'critical_sos':
        triggerFullEmergency('One-Touch SOS Emergency Button Held for 3s');
        break;
      case 'safe_arrival':
        if (_activeJourney == null || _activeJourney!.status == JourneyStatus.emergency || _activeJourney!.status == JourneyStatus.completed) {
          startJourney(
            start: 'South Extension Part II',
            destination: 'Defence Colony',
            mode: TransportMode.cab,
            vehicleNo: 'DL 1T 5500',
            durationMinutes: 12,
            intervalMinutes: 5,
            geofence: true,
          );
        }
        completeActiveJourney();
        break;
      case 'toggle_offline':
        toggleOffline(!_isOnline);
        break;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _journeyTicker?.cancel();
    _escalationTicker?.cancel();
    _checkInWindowTicker?.cancel();
    _positionSubscription?.cancel();
    _compassSubscription?.cancel();
    super.dispose();
  }
}

typedef SheMoveState = SafeLoopState;
