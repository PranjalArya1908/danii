import 'dart:async';
import 'package:flutter/material.dart';
import '../models/models.dart';

class SafeLoopController extends ChangeNotifier {
  UserProfile _userProfile = const UserProfile(
    name: 'Aanya Rao',
    phone: '+91 98112 34567',
    safetyPin: '1234',
    duressPin: '9999',
    biometricEnabled: true,
    defaultCheckInMinutes: 10,
    adaptiveFrequencyEnabled: true,
    isDarkMode: true,
    isSetupComplete: false,
  );

  SafeLoopScreen _currentScreen = SafeLoopScreen.onboarding;
  Journey? _activeJourney;
  List<TrustedContact> _contacts = const [
    TrustedContact(
      id: 'c1',
      name: 'Maya Verma',
      phone: '+91 98201 12345',
      relationship: 'Sister',
      isPrimary: true,
      isVerified: true,
      notificationStatus: ContactNotificationStatus.idle,
    ),
    TrustedContact(
      id: 'c2',
      name: 'Dr. Sameer Rao',
      phone: '+91 98765 88990',
      relationship: 'Father',
      isPrimary: false,
      isVerified: true,
      notificationStatus: ContactNotificationStatus.idle,
    ),
    TrustedContact(
      id: 'c3',
      name: 'Rhea Kapoor',
      phone: '+91 94455 66778',
      relationship: 'Best Friend',
      isPrimary: false,
      isVerified: true,
      notificationStatus: ContactNotificationStatus.idle,
    ),
  ];

  List<Journey> _history = [
    Journey(
      id: 'h1',
      startAddress: 'Cyber City Metro Station, Gate 2',
      destinationAddress: 'Palm Springs Condos, Sector 54',
      transportMode: TransportMode.cab,
      vehicleNumber: 'DL 1Y B 4821',
      estimatedMinutes: 22,
      startTimeMillis: DateTime.now().millisecondsSinceEpoch - 86400000,
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
      startTimeMillis: DateTime.now().millisecondsSinceEpoch - 86400000 * 2,
      progressPercent: 1.0,
      status: JourneyStatus.completed,
      notes: 'Safe arrival verified by Maya Verma.',
    ),
    Journey(
      id: 'h3',
      startAddress: 'Central Library',
      destinationAddress: 'University South Campus',
      transportMode: TransportMode.walking,
      vehicleNumber: '',
      estimatedMinutes: 15,
      startTimeMillis: DateTime.now().millisecondsSinceEpoch - 86400000 * 4,
      progressPercent: 1.0,
      status: JourneyStatus.completed,
      notes: 'Evening walk, companion check-in active.',
    ),
  ];

  List<SafetyEvent> _events = [
    SafetyEvent(
      id: 'ev0',
      timestamp: DateTime.now().millisecondsSinceEpoch - 1000 * 60 * 30,
      title: 'SafeLoop Initialized',
      description: 'Background protection active. GPS telemetry synchronized.',
      severity: EventSeverity.info,
    ),
  ];

  LatLngPoint _currentLocation = const LatLngPoint(
    latitude: 28.4595,
    longitude: 77.0266,
    address: 'MG Road, Sector 28, Gurugram',
  );

  int _checkInSecondsRemaining = 600; // 10 minutes
  int _escalationSecondsRemaining = 45; // 45 seconds grace period
  bool _isOnline = true;
  bool _isCovertDistressActive = false;
  String? _toastMessage;
  bool _showScenarioPicker = false;
  Journey? _selectedHistoryJourney;
  double _currentHeading = 42.0;
  double _currentSpeedKmh = 38.0;
  bool _hasLocationPermission = true;
  bool _isLocationLoading = false;
  bool _isLiveGpsActive = true;
  String? _locationStatusMessage;

  Timer? _journeyTickerTimer;
  Timer? _escalationTickerTimer;

  // Getters
  UserProfile get userProfile => _userProfile;
  SafeLoopScreen get currentScreen => _currentScreen;
  Journey? get activeJourney => _activeJourney;
  List<TrustedContact> get contacts => _contacts;
  List<Journey> get history => _history;
  List<SafetyEvent> get events => _events;
  LatLngPoint get currentLocation => _currentLocation;
  int get checkInSecondsRemaining => _checkInSecondsRemaining;
  int get escalationSecondsRemaining => _escalationSecondsRemaining;
  bool get isOnline => _isOnline;
  bool get isCovertDistressActive => _isCovertDistressActive;
  String? get toastMessage => _toastMessage;
  bool get showScenarioPicker => _showScenarioPicker;
  Journey? get selectedHistoryJourney => _selectedHistoryJourney;
  double get currentHeading => _currentHeading;
  double get currentSpeedKmh => _currentSpeedKmh;
  bool get hasLocationPermission => _hasLocationPermission;
  bool get isLocationLoading => _isLocationLoading;
  bool get isLiveGpsActive => _isLiveGpsActive;
  String? get locationStatusMessage => _locationStatusMessage;

  void modifyJourneyDuration(int deltaMinutes) {
    if (_activeJourney != null) {
      final newEst = _activeJourney!.estimatedMinutes + deltaMinutes;
      _activeJourney = _activeJourney!.copyWith(estimatedMinutes: newEst);
      _checkInSecondsRemaining += (deltaMinutes * 60);
      _addSafetyEvent(
        'Journey Extended',
        'Added +$deltaMinutes min to ETA due to traffic/transit delay.',
        EventSeverity.info,
      );
      _toastMessage = 'Journey extended by +$deltaMinutes min';
      notifyListeners();
    }
  }

  void refreshLocation() {
    _isLocationLoading = true;
    notifyListeners();
    Future.delayed(const Duration(milliseconds: 600), () {
      _isLocationLoading = false;
      _currentLocation = const LatLngPoint(
        latitude: 28.4595,
        longitude: 77.0266,
        address: 'MG Road, Sector 28, Gurugram',
      );
      _toastMessage = 'GPS telemetry synced';
      notifyListeners();
    });
  }

  void requestLocationPermission() {
    _isLocationLoading = true;
    notifyListeners();
    Future.delayed(const Duration(milliseconds: 600), () {
      _isLocationLoading = false;
      _hasLocationPermission = true;
      _isLiveGpsActive = true;
      _toastMessage = 'Location permission granted';
      notifyListeners();
    });
  }

  void navigateTo(SafeLoopScreen screen) {
    _currentScreen = screen;
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

  void completeOnboarding() {
    _currentScreen = SafeLoopScreen.setup;
    notifyListeners();
  }

  void completeSecuritySetup(String name, String phone, String pin, bool biometric) {
    _userProfile = _userProfile.copyWith(
      name: name.trim().isEmpty ? _userProfile.name : name.trim(),
      phone: phone.trim().isEmpty ? _userProfile.phone : phone.trim(),
      safetyPin: pin.trim().isEmpty ? _userProfile.safetyPin : pin.trim(),
      biometricEnabled: biometric,
      isSetupComplete: true,
    );
    _addSafetyEvent('Account Setup Complete', 'Biometric and security PIN registered.', EventSeverity.success);
    _currentScreen = SafeLoopScreen.home;
    notifyListeners();
  }

  void startJourney({
    required String start,
    required String dest,
    required TransportMode mode,
    required String vehicleNo,
    required int durationMinutes,
    required int intervalMinutes,
    required bool geofence,
  }) {
    final newJourney = Journey(
      id: 'j_${DateTime.now().millisecondsSinceEpoch}',
      startAddress: start.trim().isEmpty ? 'Connaught Place Inner Circle' : start.trim(),
      destinationAddress: dest.trim().isEmpty ? 'Hauz Khas Village' : dest.trim(),
      transportMode: mode,
      vehicleNumber: vehicleNo.trim(),
      estimatedMinutes: durationMinutes,
      startTimeMillis: DateTime.now().millisecondsSinceEpoch,
      progressPercent: 0.05,
      status: JourneyStatus.active,
      checkInIntervalMinutes: intervalMinutes,
      geofenceEnabled: geofence,
      contactsNotifiedCount: _contacts.length,
    );

    _activeJourney = newJourney;
    _checkInSecondsRemaining = intervalMinutes * 60;
    _isCovertDistressActive = false;

    // Mark contacts as sent
    _contacts = _contacts.map((c) => c.copyWith(notificationStatus: ContactNotificationStatus.sent)).toList();

    _addSafetyEvent(
      'Protected Journey Started',
      'Mode: ${mode.label}${vehicleNo.isNotEmpty ? ' ($vehicleNo)' : ''}. Route monitoring active.',
      EventSeverity.info,
      start,
    );

    _currentScreen = SafeLoopScreen.activeJourney;
    _startJourneySimulation();
    notifyListeners();
  }

  void _startJourneySimulation() {
    _journeyTickerTimer?.cancel();
    _journeyTickerTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_activeJourney == null || _activeJourney!.status != JourneyStatus.active) {
        timer.cancel();
        return;
      }

      // Increment progress simulation
      final newProgress = (_activeJourney!.progressPercent + 0.005).clamp(0.0, 0.98);
      _currentSpeedKmh = 28.0 + (newProgress * 12.0);
      _currentHeading = (_currentHeading + 1.5) % 360.0;
      _activeJourney = _activeJourney!.copyWith(progressPercent: newProgress);

      final remaining = _checkInSecondsRemaining - 1;
      if (remaining <= 0) {
        _checkInSecondsRemaining = 0;
        timer.cancel();
        triggerCheckInDue();
      } else {
        _checkInSecondsRemaining = remaining;
      }
      notifyListeners();
    });
  }

  void triggerCheckInDue() {
    if (_activeJourney == null) return;
    _activeJourney = _activeJourney!.copyWith(status: JourneyStatus.checkInDue);
    _addSafetyEvent('Safety Check-In Due', 'Adaptive check-in prompt displayed. Awaiting response.', EventSeverity.warning);
    _currentScreen = SafeLoopScreen.safetyCheckIn;
    notifyListeners();
  }

  void handleCheckInSafetyConfirm(String enteredPin, [bool isBiometric = false]) {
    if (_activeJourney == null) return;
    final duressPin = _userProfile.duressPin;
    final normalPin = _userProfile.safetyPin;

    if (isBiometric || enteredPin == normalPin) {
      // Normal verified safe
      _confirmSafeFromCheckIn(verifiedWithDuress: false);
      _currentScreen = SafeLoopScreen.activeJourney;
    } else if (enteredPin == duressPin) {
      // Duress PIN entered: Silent covert distress
      _confirmSafeFromCheckIn(verifiedWithDuress: true);
      _currentScreen = SafeLoopScreen.activeJourney;
    }
    notifyListeners();
  }

  void _confirmSafeFromCheckIn({required bool verifiedWithDuress}) {
    if (_activeJourney == null) return;
    if (verifiedWithDuress) {
      _isCovertDistressActive = true;
      _activeJourney = _activeJourney!.copyWith(status: JourneyStatus.covertDuress);
      _contacts = _contacts.map((c) => c.copyWith(notificationStatus: ContactNotificationStatus.delivered)).toList();
      _addSafetyEvent(
        'Covert Distress Alert Activated',
        'Duress PIN entered silently. Contacts notified with covert tracking link.',
        EventSeverity.critical,
      );
      _toastMessage = 'Safety confirmed'; // Pretend normal confirmation to attacker
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
  }

  void handleCheckInNeedHelp() {
    triggerEmergencyNow('User requested immediate help during safety check-in');
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

    _escalationTickerTimer?.cancel();
    _escalationTickerTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_escalationSecondsRemaining > 0) {
        _escalationSecondsRemaining--;
        notifyListeners();
      } else {
        timer.cancel();
        if (_activeJourney?.status == JourneyStatus.escalating) {
          triggerEmergencyNow('Missed check-in grace period expired');
        }
      }
    });

    _currentScreen = SafeLoopScreen.escalationWarning;
    notifyListeners();
  }

  bool cancelEscalationWithPin(String pin) {
    if (pin == _userProfile.safetyPin) {
      _escalationTickerTimer?.cancel();
      _confirmSafeFromCheckIn(verifiedWithDuress: false);
      _currentScreen = SafeLoopScreen.activeJourney;
      notifyListeners();
      return true;
    } else if (pin == _userProfile.duressPin) {
      _escalationTickerTimer?.cancel();
      _confirmSafeFromCheckIn(verifiedWithDuress: true);
      _currentScreen = SafeLoopScreen.activeJourney;
      notifyListeners();
      return true;
    }
    return false;
  }

  void triggerEmergencyNow([String reason = 'Manual Emergency SOS Activated']) {
    _escalationTickerTimer?.cancel();
    _journeyTickerTimer?.cancel();

    _activeJourney = (_activeJourney ??
            Journey(
              id: 'j_emergency_${DateTime.now().millisecondsSinceEpoch}',
              startAddress: 'Current Location',
              destinationAddress: 'Emergency Response',
              transportMode: TransportMode.walking,
              startTimeMillis: DateTime.now().millisecondsSinceEpoch,
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
      }
      return contact.copyWith(notificationStatus: ContactNotificationStatus.delivered);
    }).toList();

    _addSafetyEvent(
      'CRITICAL EMERGENCY ALERT',
      '$reason. Live GPS coordinates and audio telemetry broadcasted.',
      EventSeverity.critical,
    );

    _currentScreen = SafeLoopScreen.emergencyActive;
    notifyListeners();
  }

  bool disarmEmergency(String pin) {
    if (pin == _userProfile.safetyPin) {
      _escalationTickerTimer?.cancel();
      if (_activeJourney != null) {
        _activeJourney = _activeJourney!.copyWith(status: JourneyStatus.active);
        _checkInSecondsRemaining = _activeJourney!.checkInIntervalMinutes * 60;
        _startJourneySimulation();
        _currentScreen = SafeLoopScreen.activeJourney;
      } else {
        _currentScreen = SafeLoopScreen.home;
      }
      _isCovertDistressActive = false;
      _addSafetyEvent('Emergency Disarmed', 'User successfully disarmed alert with security PIN.', EventSeverity.success);
      _toastMessage = 'Emergency successfully disarmed';
      notifyListeners();
      return true;
    } else if (pin == _userProfile.duressPin) {
      // Fake disarm to attacker
      _toastMessage = 'Alert disarmed';
      _isCovertDistressActive = true;
      _addSafetyEvent('Silent Distress Continued', 'Duress PIN entered on emergency disarm screen.', EventSeverity.critical);
      _currentScreen = _activeJourney != null ? SafeLoopScreen.activeJourney : SafeLoopScreen.home;
      notifyListeners();
      return true;
    }
    return false;
  }

  void completeActiveJourney() {
    _journeyTickerTimer?.cancel();
    _escalationTickerTimer?.cancel();
    if (_activeJourney == null) return;

    final completed = _activeJourney!.copyWith(
      status: JourneyStatus.completed,
      progressPercent: 1.0,
    );

    _history = [completed, ..._history];
    _activeJourney = completed;

    _contacts = _contacts.map((c) => c.copyWith(
          notificationStatus: ContactNotificationStatus.acknowledged,
          acknowledgedTimeAgo: 'Safe arrival',
        )).toList();

    _addSafetyEvent(
      'Destination Reached Safely',
      'Safe arrival confirmed at ${completed.destinationAddress}.',
      EventSeverity.success,
    );

    _currentScreen = SafeLoopScreen.journeyCompleted;
    notifyListeners();
  }

  void exitJourneyToHome() {
    _activeJourney = null;
    _isCovertDistressActive = false;
    _contacts = _contacts.map((c) => c.copyWith(notificationStatus: ContactNotificationStatus.idle)).toList();
    _currentScreen = SafeLoopScreen.home;
    notifyListeners();
  }

  void addContact(String name, String phone, String relationship) {
    final newContact = TrustedContact(
      id: 'c_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      phone: phone,
      relationship: relationship,
      isPrimary: _contacts.isEmpty,
      isVerified: true,
    );
    _contacts = [..._contacts, newContact];
    _addSafetyEvent('Trusted Contact Added', '$name ($relationship) added.', EventSeverity.info);
    notifyListeners();
  }

  void removeContact(String id) {
    final removed = _contacts.where((c) => c.id == id).firstOrNull;
    _contacts = _contacts.where((c) => c.id != id).toList();
    if (removed != null) {
      _addSafetyEvent('Contact Removed', '${removed.name} removed from circle.', EventSeverity.info);
    }
    notifyListeners();
  }

  void setPrimaryContact(String id) {
    _contacts = _contacts.map((c) => c.copyWith(isPrimary: c.id == id)).toList();
    notifyListeners();
  }

  void updateProfile(UserProfile profile) {
    _userProfile = profile;
    notifyListeners();
  }

  void updateLocation(LatLngPoint loc) {
    _currentLocation = loc;
    notifyListeners();
  }

  void toggleTheme() {
    _userProfile = _userProfile.copyWith(isDarkMode: !_userProfile.isDarkMode);
    notifyListeners();
  }

  void toggleOffline([bool? offline]) {
    final newOffline = offline ?? _isOnline;
    _isOnline = !newOffline;
    if (!_isOnline) {
      _addSafetyEvent(
        'Network Offline',
        'Cellular data down. SafeLoop switched to encrypted SMS & offline mesh beacon.',
        EventSeverity.warning,
      );
    } else {
      _addSafetyEvent('Network Reconnected', 'Cloud telemetry re-synchronized.', EventSeverity.success);
    }
    notifyListeners();
  }

  void clearToast() {
    _toastMessage = null;
  }

  void runDemoScenario(String scenarioId) {
    _showScenarioPicker = false;
    switch (scenarioId) {
      case 'normal_journey':
        startJourney(
          start: 'Connaught Place, Radial 3',
          dest: 'Hauz Khas Village',
          mode: TransportMode.cab,
          vehicleNo: 'DL 1Y B 9904',
          durationMinutes: 25,
          intervalMinutes: 8,
          geofence: true,
        );
        break;

      case 'trigger_checkin':
        if (_activeJourney == null) {
          startJourney(
            start: 'Cyber Hub Gate 1',
            dest: 'Golf Course Road',
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
        if (_activeJourney == null) {
          startJourney(
            start: 'Sector 18 Metro',
            dest: 'Botanical Garden',
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
        if (_activeJourney == null) {
          startJourney(
            start: 'Aerocity Hospitality Dist',
            dest: 'Vasant Vihar',
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
        triggerEmergencyNow('One-Touch SOS Emergency Button Held for 3s');
        break;

      case 'safe_arrival':
        if (_activeJourney == null) {
          startJourney(
            start: 'South Extension Part II',
            dest: 'Defence Colony',
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

  void _addSafetyEvent(String title, String desc, EventSeverity severity, [String? location]) {
    final event = SafetyEvent(
      id: 'ev_${DateTime.now().millisecondsSinceEpoch}',
      timestamp: DateTime.now().millisecondsSinceEpoch,
      title: title,
      description: desc,
      severity: severity,
      location: location ?? _currentLocation.address,
    );
    _events = [event, ..._events];
  }

  @override
  void dispose() {
    _journeyTickerTimer?.cancel();
    _escalationTickerTimer?.cancel();
    super.dispose();
  }
}
