import 'package:flutter/material.dart';

enum TransportMode {
  walking('Walking', Icons.directions_walk),
  cab('Cab / Taxi', Icons.local_taxi),
  auto('Auto / Rickshaw', Icons.electric_rickshaw),
  bus('Public Bus', Icons.directions_bus),
  metro('Metro Train', Icons.subway);

  final String label;
  final IconData icon;
  const TransportMode(this.label, this.icon);
}

enum JourneyStatus {
  idle,
  planning,
  active,
  checkInDue,
  escalating,
  emergency,
  covertDuress,
  completed,
}

enum SafetyLevel {
  safe,
  adaptiveMonitoring,
  checkInPending,
  missedWarning,
  emergencyActive,
  covertAlert,
}

class LatLngPoint {
  final double latitude;
  final double longitude;
  final String address;

  const LatLngPoint({
    required this.latitude,
    required this.longitude,
    this.address = '',
  });

  LatLngPoint copyWith({
    double? latitude,
    double? longitude,
    String? address,
  }) {
    return LatLngPoint(
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      address: address ?? this.address,
    );
  }
}

class Waypoint {
  final LatLngPoint point;
  final int timestamp;
  final double speedKmh;

  const Waypoint({
    required this.point,
    required this.timestamp,
    this.speedKmh = 0.0,
  });
}

class Journey {
  final String id;
  final String startAddress;
  final String destinationAddress;
  final TransportMode transportMode;
  final String vehicleNumber;
  final int estimatedMinutes;
  final int startTimeMillis;
  final double progressPercent;
  final JourneyStatus status;
  final int checkInIntervalMinutes;
  final bool geofenceEnabled;
  final int contactsNotifiedCount;
  final List<LatLngPoint> waypoints;
  final String notes;

  const Journey({
    required this.id,
    required this.startAddress,
    required this.destinationAddress,
    required this.transportMode,
    this.vehicleNumber = '',
    this.estimatedMinutes = 25,
    required this.startTimeMillis,
    this.progressPercent = 0.0,
    this.status = JourneyStatus.active,
    this.checkInIntervalMinutes = 10,
    this.geofenceEnabled = true,
    this.contactsNotifiedCount = 2,
    this.waypoints = const [],
    this.notes = '',
  });

  Journey copyWith({
    String? id,
    String? startAddress,
    String? destinationAddress,
    TransportMode? transportMode,
    String? vehicleNumber,
    int? estimatedMinutes,
    int? startTimeMillis,
    double? progressPercent,
    JourneyStatus? status,
    int? checkInIntervalMinutes,
    bool? geofenceEnabled,
    int? contactsNotifiedCount,
    List<LatLngPoint>? waypoints,
    String? notes,
  }) {
    return Journey(
      id: id ?? this.id,
      startAddress: startAddress ?? this.startAddress,
      destinationAddress: destinationAddress ?? this.destinationAddress,
      transportMode: transportMode ?? this.transportMode,
      vehicleNumber: vehicleNumber ?? this.vehicleNumber,
      estimatedMinutes: estimatedMinutes ?? this.estimatedMinutes,
      startTimeMillis: startTimeMillis ?? this.startTimeMillis,
      progressPercent: progressPercent ?? this.progressPercent,
      status: status ?? this.status,
      checkInIntervalMinutes: checkInIntervalMinutes ?? this.checkInIntervalMinutes,
      geofenceEnabled: geofenceEnabled ?? this.geofenceEnabled,
      contactsNotifiedCount: contactsNotifiedCount ?? this.contactsNotifiedCount,
      waypoints: waypoints ?? this.waypoints,
      notes: notes ?? this.notes,
    );
  }
}

enum ContactNotificationStatus {
  idle,
  sending,
  sent,
  delivered,
  acknowledged,
}

class TrustedContact {
  final String id;
  final String name;
  final String phone;
  final String relationship;
  final bool isPrimary;
  final bool isVerified;
  final ContactNotificationStatus notificationStatus;
  final String? acknowledgedTimeAgo;

  const TrustedContact({
    required this.id,
    required this.name,
    required this.phone,
    required this.relationship,
    this.isPrimary = false,
    this.isVerified = true,
    this.notificationStatus = ContactNotificationStatus.idle,
    this.acknowledgedTimeAgo,
  });

  TrustedContact copyWith({
    String? id,
    String? name,
    String? phone,
    String? relationship,
    bool? isPrimary,
    bool? isVerified,
    ContactNotificationStatus? notificationStatus,
    String? acknowledgedTimeAgo,
  }) {
    return TrustedContact(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      relationship: relationship ?? this.relationship,
      isPrimary: isPrimary ?? this.isPrimary,
      isVerified: isVerified ?? this.isVerified,
      notificationStatus: notificationStatus ?? this.notificationStatus,
      acknowledgedTimeAgo: acknowledgedTimeAgo ?? this.acknowledgedTimeAgo,
    );
  }
}

enum EventSeverity {
  info,
  success,
  warning,
  critical,
}

class SafetyEvent {
  final String id;
  final int timestamp;
  final String title;
  final String description;
  final EventSeverity severity;
  final String location;

  const SafetyEvent({
    required this.id,
    required this.timestamp,
    required this.title,
    required this.description,
    required this.severity,
    this.location = 'Connaught Place, New Delhi',
  });
}

class UserProfile {
  final String name;
  final String phone;
  final String safetyPin;
  final String duressPin;
  final bool biometricEnabled;
  final int defaultCheckInMinutes;
  final bool adaptiveFrequencyEnabled;
  final String emergencyMessage;
  final bool isDarkMode;
  final bool isSetupComplete;
  final String geminiApiKey;

  const UserProfile({
    this.name = 'Aanya Rao',
    this.phone = '+91 98112 34567',
    this.safetyPin = '1234',
    this.duressPin = '9999',
    this.biometricEnabled = true,
    this.defaultCheckInMinutes = 10,
    this.adaptiveFrequencyEnabled = true,
    this.emergencyMessage =
        'SheMove Alert: I have not completed my safety check-in. Here is my live GPS location & route info: https://shemove.app/track/live',
    this.isDarkMode = true,
    this.isSetupComplete = false,
    this.geminiApiKey = '',
  });

  UserProfile copyWith({
    String? name,
    String? phone,
    String? safetyPin,
    String? duressPin,
    bool? biometricEnabled,
    int? defaultCheckInMinutes,
    bool? adaptiveFrequencyEnabled,
    String? emergencyMessage,
    bool? isDarkMode,
    bool? isSetupComplete,
    String? geminiApiKey,
  }) {
    return UserProfile(
      name: name ?? this.name,
      phone: phone ?? this.phone,
      safetyPin: safetyPin ?? this.safetyPin,
      duressPin: duressPin ?? this.duressPin,
      biometricEnabled: biometricEnabled ?? this.biometricEnabled,
      defaultCheckInMinutes: defaultCheckInMinutes ?? this.defaultCheckInMinutes,
      adaptiveFrequencyEnabled: adaptiveFrequencyEnabled ?? this.adaptiveFrequencyEnabled,
      emergencyMessage: emergencyMessage ?? this.emergencyMessage,
      isDarkMode: isDarkMode ?? this.isDarkMode,
      isSetupComplete: isSetupComplete ?? this.isSetupComplete,
      geminiApiKey: geminiApiKey ?? this.geminiApiKey,
    );
  }
}

