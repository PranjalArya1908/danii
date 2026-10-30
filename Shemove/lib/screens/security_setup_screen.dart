import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/contacts_service.dart';
import '../theme/app_colors.dart';
import '../widgets/numeric_pin_pad.dart';

class SecuritySetupScreen extends StatefulWidget {
  final String initialName;
  final String initialPhone;
  final bool initialLocationGranted;
  final bool initialContactsGranted;
  final Future<bool> Function()? onRequestLocationPermission;
  final Future<bool> Function()? onRequestContactsPermission;
  final Future<DeviceContactInfo?> Function()? onPickDeviceContact;
  final Function(
    String name,
    String phone,
    String pin,
    bool biometric,
    List<TrustedContact> contacts,
  ) onSetupComplete;

  const SecuritySetupScreen({
    super.key,
    this.initialName = 'Aanya Rao',
    this.initialPhone = '+91 98112 34567',
    this.initialLocationGranted = false,
    this.initialContactsGranted = false,
    this.onRequestLocationPermission,
    this.onRequestContactsPermission,
    this.onPickDeviceContact,
    required this.onSetupComplete,
  });

  @override
  State<SecuritySetupScreen> createState() => _SecuritySetupScreenState();
}

class _SecuritySetupScreenState extends State<SecuritySetupScreen> {
  int _step = 1;
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  String _safetyPin = '';
  bool _biometricEnabled = true;
  bool _locationGranted = false;
  bool _contactsGranted = false;
  final List<TrustedContact> _selectedContacts = [];
  bool _isPickingContact = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _phoneController = TextEditingController(text: widget.initialPhone);
    _locationGranted = widget.initialLocationGranted;
    _contactsGranted = widget.initialContactsGranted;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _pickContactFromPhone() async {
    setState(() => _isPickingContact = true);
    try {
      if (widget.onPickDeviceContact != null) {
        final contact = await widget.onPickDeviceContact!();
        if (contact != null) {
          _promptRelationshipAndAdd(contact.name, contact.phone);
        }
      }
    } finally {
      if (mounted) setState(() => _isPickingContact = false);
    }
  }

  void _promptRelationshipAndAdd(String name, String phone) {
    String selectedRel = 'Sister';
    final relationships = [
      'Sister',
      'Father',
      'Mother',
      'Brother',
      'Partner',
      'Best Friend',
      'Family',
      'Colleague',
      'Other',
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? AppColors.midnightDarkSurface : AppColors.lightSurface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppColors.primaryViolet.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              name.isNotEmpty ? name.substring(0, 1) : 'C',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primaryViolet,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                phone,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDark ? AppColors.textSecondary : AppColors.lightTextSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'What is their relationship to you?',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: relationships.map((rel) {
                        final isSelected = selectedRel == rel;
                        return ChoiceChip(
                          label: Text(rel),
                          selected: isSelected,
                          onSelected: (val) {
                            if (val) {
                              setSheetState(() => selectedRel = rel);
                            }
                          },
                          selectedColor: AppColors.primaryViolet.withValues(alpha: 0.25),
                          labelStyle: TextStyle(
                            color: isSelected
                                ? AppColors.primaryViolet
                                : (isDark ? AppColors.textSecondary : AppColors.lightTextSecondary),
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _addContactToCircle(name, phone, selectedRel);
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primaryViolet,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: const Text('Add to Emergency Circle',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _addContactToCircle(String name, String phone, String relationship) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final newContact = TrustedContact(
      id: 'c_$now',
      name: name,
      phone: phone,
      relationship: relationship,
      isPrimary: _selectedContacts.isEmpty,
      isVerified: true,
    );
    setState(() {
      _selectedContacts.add(newContact);
    });
  }

  void _showManualAddDialog() {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    String rel = 'Family';
    final relationships = [
      'Sister',
      'Father',
      'Mother',
      'Partner',
      'Best Friend',
      'Family',
      'Colleague',
      'Other'
    ];

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDState) {
            return AlertDialog(
              title: const Text('Enter Emergency Contact'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Full Name'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: phoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: 'Mobile Number'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: rel,
                    decoration: const InputDecoration(labelText: 'Relationship'),
                    items: relationships
                        .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setDState(() => rel = val);
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    if (nameCtrl.text.trim().isNotEmpty && phoneCtrl.text.trim().isNotEmpty) {
                      Navigator.pop(ctx);
                      _addContactToCircle(nameCtrl.text.trim(), phoneCtrl.text.trim(), rel);
                    }
                  },
                  style: FilledButton.styleFrom(backgroundColor: AppColors.primaryViolet),
                  child: const Text('Add Contact'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.midnightDarkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.primaryViolet.withValues(alpha: isDark ? 0.2 : 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.security, color: AppColors.primaryViolet, size: 20),
            ),
            const SizedBox(width: 10),
            const Text(
              'Security Setup',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 18.0),
            child: Center(
              child: Text(
                'Step $_step of 4',
                style: const TextStyle(
                  color: AppColors.primaryViolet,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_step == 1) _buildStep1(isDark),
              if (_step == 2) _buildStep2(isDark),
              if (_step == 3) _buildStep3(isDark),
              if (_step == 4) _buildStep4(isDark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep1(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Your Profile & Verification',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: isDark ? AppColors.textPrimary : AppColors.lightTextPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Your name and mobile number will be securely registered with your emergency contacts.',
          style: TextStyle(
            fontSize: 14,
            color: isDark ? AppColors.textSecondary : AppColors.lightTextSecondary,
          ),
        ),
        const SizedBox(height: 24),

        // Name input
        TextField(
          controller: _nameController,
          decoration: const InputDecoration(
            labelText: 'Full Name',
            prefixIcon: Icon(Icons.person, color: AppColors.primaryViolet),
          ),
        ),
        const SizedBox(height: 16),

        // Phone input
        TextField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            labelText: 'Mobile Number',
            prefixIcon: Icon(Icons.phone, color: AppColors.primaryViolet),
          ),
        ),
        const SizedBox(height: 32),

        // Next button
        SizedBox(
          width: double.infinity,
          height: 52,
          child: FilledButton(
            onPressed: () {
              if (_nameController.text.trim().isNotEmpty) {
                setState(() {
                  _step = 2;
                });
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primaryViolet,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: const Text(
              'Continue to Security PIN',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStep2(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Safety & Duress PINs',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: isDark ? AppColors.textPrimary : AppColors.lightTextPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Create a 4-digit PIN to confirm safety during check-ins.',
          style: TextStyle(
            fontSize: 14,
            color: isDark ? AppColors.textSecondary : AppColors.lightTextSecondary,
          ),
        ),
        const SizedBox(height: 20),

        // PIN display
        Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(4, (index) {
              final isFilled = index < _safetyPin.length;
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 8),
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isFilled
                      ? AppColors.primaryViolet
                      : (isDark ? AppColors.midnightDarkCardBorder : AppColors.lightCardBorder),
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 16),

        // Duress PIN info note
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.warningAmber.withValues(alpha: isDark ? 0.2 : 0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.warningAmber),
          ),
          child: Row(
            children: [
              const Icon(Icons.info, color: AppColors.warningAmber, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Default Duress PIN is set to 9999. Entering 9999 silently alerts your emergency circle while pretending everything is safe.',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.textPrimary : AppColors.lightTextPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Numeric Keypad
        NumericPinPad(
          enteredPin: _safetyPin,
          onPinChange: (newPin) {
            setState(() {
              _safetyPin = newPin;
            });
          },
          showBiometric: false,
        ),
        const SizedBox(height: 20),

        // Next button
        SizedBox(
          width: double.infinity,
          height: 52,
          child: FilledButton(
            onPressed: () async {
              if (_safetyPin.length < 4) {
                _safetyPin = '1234';
              }
              setState(() {
                _step = 3;
              });
              if (!_locationGranted && widget.onRequestLocationPermission != null) {
                final granted = await widget.onRequestLocationPermission!();
                if (mounted) setState(() => _locationGranted = granted);
              }
              if (!_contactsGranted && widget.onRequestContactsPermission != null) {
                final cGranted = await widget.onRequestContactsPermission!();
                if (mounted) setState(() => _contactsGranted = cGranted);
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primaryViolet,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: const Text(
              'Continue to Permissions',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStep3(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Permissions & Biometrics',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: isDark ? AppColors.textPrimary : AppColors.lightTextPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'SheMove requires location and contacts permission to monitor journeys and dispatch emergency distress telemetry.',
          style: TextStyle(
            fontSize: 14,
            color: isDark ? AppColors.textSecondary : AppColors.lightTextSecondary,
          ),
        ),
        const SizedBox(height: 20),

        // Biometric toggle
        _buildPermissionCard(
          icon: Icons.fingerprint,
          iconColor: AppColors.primaryViolet,
          title: 'Biometric Authentication',
          subtitle: 'One-tap check-ins with fingerprint',
          value: _biometricEnabled,
          onChanged: (val) => setState(() => _biometricEnabled = val),
          isDark: isDark,
        ),
        const SizedBox(height: 12),

        // Precise Location toggle
        _buildPermissionCard(
          icon: Icons.location_on,
          iconColor: AppColors.safeGreen,
          title: 'Precise Journey Location',
          subtitle: _locationGranted
              ? 'Real-time GPS active & synchronized'
              : 'Permission required for live tracking',
          value: _locationGranted,
          onChanged: (val) async {
            if (val && widget.onRequestLocationPermission != null) {
              final granted = await widget.onRequestLocationPermission!();
              if (mounted) {
                setState(() => _locationGranted = granted);
              }
            } else {
              setState(() => _locationGranted = val);
            }
          },
          isDark: isDark,
        ),
        const SizedBox(height: 12),

        // Contacts toggle
        _buildPermissionCard(
          icon: Icons.contacts,
          iconColor: AppColors.infoBlue,
          title: 'Trusted Contact Alerts',
          subtitle: _contactsGranted
              ? 'Address book access enabled'
              : 'Permission required to pick phone contacts',
          value: _contactsGranted,
          onChanged: (val) async {
            if (val && widget.onRequestContactsPermission != null) {
              final granted = await widget.onRequestContactsPermission!();
              if (mounted) {
                setState(() => _contactsGranted = granted);
              }
            } else {
              setState(() => _contactsGranted = val);
            }
          },
          isDark: isDark,
        ),
        const SizedBox(height: 36),

        // Continue to Contacts Button
        SizedBox(
          width: double.infinity,
          height: 52,
          child: FilledButton(
            onPressed: () {
              setState(() {
                _step = 4;
              });
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primaryViolet,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Continue to Add Contacts',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                SizedBox(width: 8),
                Icon(Icons.arrow_forward, size: 18),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStep4(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Emergency Contacts',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: isDark ? AppColors.textPrimary : AppColors.lightTextPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Select trusted people from your phone address book to be alerted with your live GPS route when emergency triggers.',
          style: TextStyle(
            fontSize: 14,
            color: isDark ? AppColors.textSecondary : AppColors.lightTextSecondary,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 20),

        // Pick from Phone Contacts Primary Action Button
        SizedBox(
          width: double.infinity,
          height: 52,
          child: FilledButton.icon(
            onPressed: _isPickingContact ? null : _pickContactFromPhone,
            icon: _isPickingContact
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.contact_phone_rounded, size: 20),
            label: Text(
              _isPickingContact ? 'Opening Address Book...' : 'Pick from Phone Contacts',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primaryViolet,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ),
        const SizedBox(height: 10),

        // Manual Add option
        Center(
          child: TextButton.icon(
            onPressed: _showManualAddDialog,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Or Enter Contact Manually'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primaryViolet,
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Selected Contacts Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Your Emergency Circle',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.textPrimary : AppColors.lightTextPrimary,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: (_selectedContacts.isNotEmpty ? AppColors.safeGreen : AppColors.warningAmber)
                    .withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${_selectedContacts.length} Added',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: _selectedContacts.isNotEmpty ? AppColors.safeGreen : AppColors.warningAmber,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Selected Contacts List
        if (_selectedContacts.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? AppColors.midnightDarkSurface : AppColors.lightSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? AppColors.midnightDarkCardBorder : AppColors.lightCardBorder,
              ),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.group_add_outlined,
                  size: 40,
                  color: isDark ? AppColors.textSecondary : AppColors.lightTextSecondary,
                ),
                const SizedBox(height: 8),
                Text(
                  'No contacts in your circle yet',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: isDark ? AppColors.textPrimary : AppColors.lightTextPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Add at least 1 primary contact to ensure emergency dispatches reach your loved ones.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.textSecondary : AppColors.lightTextSecondary,
                  ),
                ),
              ],
            ),
          )
        else
          ..._selectedContacts.asMap().entries.map((entry) {
            final idx = entry.key;
            final contact = entry.value;
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? AppColors.midnightDarkSurface : AppColors.lightSurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: contact.isPrimary
                      ? AppColors.primaryViolet.withValues(alpha: 0.5)
                      : (isDark ? AppColors.midnightDarkCardBorder : AppColors.lightCardBorder),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppColors.primaryViolet.withValues(alpha: isDark ? 0.25 : 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        contact.name.isNotEmpty ? contact.name.substring(0, 1) : 'C',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryViolet,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              contact.name,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            if (contact.isPrimary) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: AppColors.safeGreen.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'PRIMARY',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.safeGreen,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${contact.phone} • ${contact.relationship}',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? AppColors.textSecondary : AppColors.lightTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20),
                    color: AppColors.emergencyRed,
                    onPressed: () {
                      setState(() {
                        _selectedContacts.removeAt(idx);
                        if (_selectedContacts.isNotEmpty && contact.isPrimary) {
                          _selectedContacts[0] = _selectedContacts[0].copyWith(isPrimary: true);
                        }
                      });
                    },
                  ),
                ],
              ),
            );
          }),

        const SizedBox(height: 28),

        // Complete Setup Button
        SizedBox(
          width: double.infinity,
          height: 52,
          child: FilledButton(
            onPressed: () {
              widget.onSetupComplete(
                _nameController.text,
                _phoneController.text,
                _safetyPin.isNotEmpty ? _safetyPin : '1234',
                _biometricEnabled,
                _selectedContacts,
              );
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primaryViolet,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: Text(
              _selectedContacts.isNotEmpty
                  ? 'Complete Setup & Enter SheMove'
                  : 'Skip for Now & Enter SheMove',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPermissionCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.midnightDarkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.midnightDarkCardBorder : AppColors.lightCardBorder,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 26),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.textSecondary : AppColors.lightTextSecondary,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeTrackColor: iconColor,
          ),
        ],
      ),
    );
  }
}
