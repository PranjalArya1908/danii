import 'package:flutter/material.dart';
import '../models/models.dart';
import '../theme/app_colors.dart';
import '../widgets/interactive_map_canvas.dart';
import '../widgets/numeric_pin_pad.dart';

class EmergencyScreen extends StatefulWidget {
  final LatLngPoint currentLocation;
  final List<TrustedContact> contacts;
  final List<SafetyEvent> events;
  final bool Function(String pin) onDisarmEmergency;

  const EmergencyScreen({
    super.key,
    required this.currentLocation,
    required this.contacts,
    required this.events,
    required this.onDisarmEmergency,
  });

  @override
  State<EmergencyScreen> createState() => _EmergencyScreenState();
}

class _EmergencyScreenState extends State<EmergencyScreen> {
  bool _showDisarmDialog = false;
  String _enteredPin = '';
  String? _pinError;

  void _onPinChange(String pin) {
    setState(() {
      _enteredPin = pin;
      _pinError = null;
    });

    if (pin.length == 4) {
      final success = widget.onDisarmEmergency(pin);
      if (!success) {
        setState(() {
          _pinError = 'Incorrect PIN. Try 1234 or 9999.';
        });
        Future.delayed(const Duration(milliseconds: 900), () {
          if (mounted) {
            setState(() {
              _enteredPin = '';
            });
          }
        });
      }
    }
  }

  String _formatDate(int timestamp) {
    final dt = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final hour = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
    final minute = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $ampm';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryContact = widget.contacts.where((c) => c.isPrimary).firstOrNull ??
        widget.contacts.firstOrNull;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F0A14) : const Color(0xFFFEF2F2),
      appBar: AppBar(
        backgroundColor: AppColors.emergencyRed.withValues(alpha: isDark ? 0.2 : 0.12),
        automaticallyImplyLeading: false,
        title: const Row(
          children: [
            Icon(Icons.warning, color: AppColors.emergencyRed, size: 22),
            SizedBox(width: 8),
            Text(
              'EMERGENCY ALERT ACTIVE',
              style: TextStyle(
                color: AppColors.emergencyRed,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: OutlinedButton(
              onPressed: () => setState(() => _showDisarmDialog = true),
              style: OutlinedButton.styleFrom(
                foregroundColor: isDark ? Colors.white : AppColors.emergencyRed,
                side: BorderSide(
                  color: isDark ? Colors.white54 : AppColors.emergencyRed,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Disarm', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
          children: [
            // High-Contrast Location Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1424) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.emergencyRed, width: 1.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'LIVE BROADCAST TELEMETRY',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.emergencyRed,
                        ),
                      ),
                      Text(
                        'Continuous Sync',
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.currentLocation.address,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'GPS: ${widget.currentLocation.latitude}° N, ${widget.currentLocation.longitude}° E (Accuracy: ±3m)',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.primaryViolet,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Quick Calling Buttons Row
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: FilledButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Dialing Police Services (112)...')),
                        );
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.emergencyRed,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: const Icon(Icons.phone, color: Colors.white, size: 20),
                      label: const Text(
                        'Call 112 (Police)',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: FilledButton.icon(
                      onPressed: () {
                        if (primaryContact != null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Calling ${primaryContact.name}...')),
                          );
                        }
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primaryViolet,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: const Icon(Icons.call, color: Colors.white, size: 20),
                      label: Text(
                        'Call ${primaryContact?.name.split(' ').first ?? 'Circle'}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Map Preview
            InteractiveMapCanvas(
              height: 180,
              progress: 0.5,
              journeyStatus: JourneyStatus.emergency,
              startLabel: 'Alert Origin',
              destinationLabel: widget.currentLocation.address.split(',').first,
              speedKmh: 0,
            ),
            const SizedBox(height: 16),

            // Trusted Contact Delivery States
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.midnightDarkSurface : AppColors.lightSurface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark ? AppColors.midnightDarkCardBorder : AppColors.lightCardBorder,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Trusted Contact Notification States',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  ...widget.contacts.map((contact) {
                    final (statusLabel, statusColor) = switch (contact.notificationStatus) {
                      ContactNotificationStatus.acknowledged => ('ACKNOWLEDGED', AppColors.safeGreen),
                      ContactNotificationStatus.delivered => ('DELIVERED', AppColors.infoBlue),
                      ContactNotificationStatus.sent => ('SENT', AppColors.vibrantLavender),
                      ContactNotificationStatus.sending => ('SENDING...', AppColors.warningAmber),
                      _ => ('PENDING', Colors.grey),
                    };

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.midnightDarkSurfaceVariant
                            : AppColors.lightSurfaceVariant,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: AppColors.primaryViolet.withValues(alpha: 0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    contact.name.substring(0, 1),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primaryViolet,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    contact.name,
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                  ),
                                  Text(
                                    '${contact.relationship} • ${contact.phone}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isDark
                                          ? AppColors.textSecondary
                                          : AppColors.lightTextSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              contact.acknowledgedTimeAgo != null
                                  ? '$statusLabel (${contact.acknowledgedTimeAgo})'
                                  : statusLabel,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: statusColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Live Safety Event Audit Log
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.midnightDarkSurface : AppColors.lightSurface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark ? AppColors.midnightDarkCardBorder : AppColors.lightCardBorder,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Live Event Timeline',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  ...widget.events.take(5).map((ev) {
                    final badgeColor = switch (ev.severity) {
                      EventSeverity.critical => AppColors.emergencyRed,
                      EventSeverity.warning => AppColors.warningAmber,
                      EventSeverity.success => AppColors.safeGreen,
                      _ => AppColors.infoBlue,
                    };

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            margin: const EdgeInsets.only(top: 4),
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: badgeColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      ev.title,
                                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                    ),
                                    Text(
                                      _formatDate(ev.timestamp),
                                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  ev.description,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark
                                        ? AppColors.textSecondary
                                        : AppColors.lightTextSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
      bottomSheet: _showDisarmDialog
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              decoration: BoxDecoration(
                color: isDark ? AppColors.midnightDarkSurface : AppColors.lightSurface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Enter PIN to Disarm Alert',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => setState(() => _showDisarmDialog = false),
                      ),
                    ],
                  ),
                  NumericPinPad(
                    enteredPin: _enteredPin,
                    onPinChange: _onPinChange,
                    showBiometric: false,
                    isError: _pinError != null,
                    errorMessage: _pinError,
                  ),
                ],
              ),
            )
          : null,
    );
  }
}

