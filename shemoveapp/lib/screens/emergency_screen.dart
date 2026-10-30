import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../components/interactive_map_canvas.dart';
import '../components/numeric_pin_pad.dart';
import '../models/models.dart';
import '../theme/colors.dart';

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
  String _enteredPin = '';
  String? _pinError;

  void _showDisarmDialog(BuildContext context) {
    setState(() {
      _enteredPin = '';
      _pinError = null;
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text(
              'Disarm Emergency Alert',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Enter your security PIN to terminate this active emergency alert and inform contacts that you are safe.',
                    style: TextStyle(fontSize: 13, color: SafeLoopColors.textSecondary),
                  ),
                  const SizedBox(height: 14),
                  NumericPinPad(
                    enteredPin: _enteredPin,
                    onPinChange: (pin) {
                      setDialogState(() {
                        _enteredPin = pin;
                        _pinError = null;
                      });

                      if (pin.length == 4) {
                        final ok = widget.onDisarmEmergency(pin);
                        if (ok) {
                          Navigator.of(dialogCtx).pop();
                        } else {
                          setDialogState(() {
                            _pinError = 'Incorrect PIN';
                            _enteredPin = '';
                          });
                        }
                      }
                    },
                    showBiometric: false,
                    errorMessage: _pinError,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(dialogCtx).pop();
                },
                child: const Text('Cancel'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _makePhoneCall(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);
    final screenBg = isDark ? const Color(0xFF0F0A14) : const Color(0xFFFEF2F2);
    final cardBg = isDark ? const Color(0xFF1E1424) : Colors.white;
    final formattedTimestamp = DateFormat('hh:mm:ss a, dd MMM').format(DateTime.now());

    final primaryContact = widget.contacts.where((c) => c.isPrimary).firstOrNull ??
        widget.contacts.firstOrNull;

    return Scaffold(
      backgroundColor: screenBg,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: SafeLoopColors.emergencyRed.withValues(alpha: isDark ? 0.2 : 0.12),
        title: Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: SafeLoopColors.emergencyRed,
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'EMERGENCY ALERT ACTIVE',
              style: TextStyle(
                color: SafeLoopColors.emergencyRed,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: OutlinedButton(
              onPressed: () => _showDisarmDialog(context),
              style: OutlinedButton.styleFrom(
                foregroundColor: isDark ? Colors.white : SafeLoopColors.emergencyRed,
                side: BorderSide(
                  color: isDark ? Colors.white.withValues(alpha: 0.5) : SafeLoopColors.emergencyRed,
                ),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              ),
              child: const Text('Disarm', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
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
              padding: const EdgeInsets.all(18.0),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(20.0),
                border: Border.all(color: SafeLoopColors.emergencyRed, width: 1.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'LIVE BROADCAST TELEMETRY',
                        style: TextStyle(
                          color: SafeLoopColors.emergencyRed,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                      Text(
                        formattedTimestamp,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.currentLocation.address,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'GPS Coordinates: ${widget.currentLocation.latitude}° N, ${widget.currentLocation.longitude}° E (Accuracy: ±3m)',
                    style: const TextStyle(
                      color: SafeLoopColors.primaryViolet,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Quick Calling Buttons Row
            Row(
              children: [
                // Police (112)
                Expanded(
                  child: SizedBox(
                    height: 54,
                    child: ElevatedButton.icon(
                      onPressed: () => _makePhoneCall('tel:112'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: SafeLoopColors.emergencyRed,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      icon: const Icon(Icons.phone, color: Colors.white),
                      label: const Text(
                        'Call 112 (Police)',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Primary Contact
                Expanded(
                  child: SizedBox(
                    height: 54,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        if (primaryContact != null) {
                          _makePhoneCall('tel:${primaryContact.phone}');
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: SafeLoopColors.primaryViolet,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      icon: const Icon(Icons.call, color: Colors.white),
                      label: Text(
                        'Call ${primaryContact?.name.split(' ').first ?? 'Contact'}',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Map Preview
            SizedBox(
              height: 180,
              child: InteractiveMapCanvas(
                progress: 0.5,
                startLabel: 'Alert Origin',
                destinationLabel: widget.currentLocation.address.length > 24
                    ? widget.currentLocation.address.substring(0, 24)
                    : widget.currentLocation.address,
                speedKmh: 0,
                journeyStatus: JourneyStatus.emergency,
              ),
            ),
            const SizedBox(height: 16),

            // Contact Delivery States Section
            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(20.0),
                border: Border.all(color: theme.colorScheme.outline),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Trusted Contact Notification States',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...widget.contacts.map((contact) {
                    final statusColor = switch (contact.notificationStatus) {
                      ContactNotificationStatus.acknowledged => SafeLoopColors.safeGreen,
                      ContactNotificationStatus.delivered => SafeLoopColors.infoBlue,
                      _ => SafeLoopColors.warningAmber,
                    };

                    final statusLabel = switch (contact.notificationStatus) {
                      ContactNotificationStatus.acknowledged => 'Acknowledged',
                      ContactNotificationStatus.delivered => 'Delivered',
                      ContactNotificationStatus.sent => 'Sent',
                      _ => 'Queued',
                    };

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8.0),
                      padding: const EdgeInsets.all(12.0),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: SafeLoopColors.primaryViolet.withValues(alpha: isDark ? 0.2 : 0.12),
                                ),
                                child: Center(
                                  child: Text(
                                    contact.name.isNotEmpty ? contact.name.substring(0, 1) : 'C',
                                    style: const TextStyle(
                                      color: SafeLoopColors.primaryViolet,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
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
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: theme.colorScheme.onSurface,
                                    ),
                                  ),
                                  Text(
                                    '${contact.relationship} • ${contact.phone}',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                            child: Text(
                              statusLabel,
                              style: TextStyle(
                                color: statusColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
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

            // Incident Timeline
            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(20.0),
                border: Border.all(color: theme.colorScheme.outline),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Incident Broadcast Timeline',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...widget.events.take(4).map((event) {
                    final dotColor = switch (event.severity) {
                      EventSeverity.critical => SafeLoopColors.emergencyRed,
                      EventSeverity.warning => SafeLoopColors.warningAmber,
                      EventSeverity.success => SafeLoopColors.safeGreen,
                      _ => SafeLoopColors.infoBlue,
                    };

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            margin: const EdgeInsets.only(top: 4),
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: dotColor,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  event.title,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                                Text(
                                  event.description,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
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
            const SizedBox(height: 20),

            // Bottom Disarm Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: () => _showDisarmDialog(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  foregroundColor: theme.colorScheme.onSurface,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                icon: Icon(Icons.lock_open, color: theme.colorScheme.onSurface),
                label: Text(
                  'Disarm Emergency with Security PIN',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
