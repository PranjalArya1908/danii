import 'package:flutter/material.dart';
import '../components/numeric_pin_pad.dart';
import '../theme/colors.dart';

class SecuritySetupScreen extends StatefulWidget {
  final String initialName;
  final String initialPhone;
  final Function(String name, String phone, String pin, bool biometric) onSetupComplete;

  const SecuritySetupScreen({
    super.key,
    this.initialName = 'Aanya Rao',
    this.initialPhone = '+91 98112 34567',
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
  bool _locationPermissionGranted = true;
  bool _contactsPermissionGranted = true;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _phoneController = TextEditingController(text: widget.initialPhone);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: SafeLoopColors.primaryViolet.withValues(alpha: isDark ? 0.2 : 0.12),
              ),
              child: const Icon(
                Icons.security,
                color: SafeLoopColors.primaryViolet,
                size: 18,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Security Setup',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Center(
              child: Text(
                'Step $_step of 3',
                style: const TextStyle(
                  color: SafeLoopColors.primaryViolet,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_step == 1) ..._buildStep1(theme),
              if (_step == 2) ..._buildStep2(theme),
              if (_step == 3) ..._buildStep3(theme),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildStep1(ThemeData theme) {
    return [
      Text(
        'Your Profile & Verification',
        style: theme.textTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.onSurface,
        ),
      ),
      const SizedBox(height: 6),
      Text(
        'Your name and mobile number will be securely registered with your emergency contacts.',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      const SizedBox(height: 20),
      TextField(
        controller: _nameController,
        decoration: const InputDecoration(
          labelText: 'Full Name',
          prefixIcon: Icon(Icons.person, color: SafeLoopColors.primaryViolet),
        ),
      ),
      const SizedBox(height: 14),
      TextField(
        controller: _phoneController,
        decoration: const InputDecoration(
          labelText: 'Phone Number',
          prefixIcon: Icon(Icons.phone, color: SafeLoopColors.primaryViolet),
        ),
      ),
      const SizedBox(height: 20),
      Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16.0),
          border: Border.all(color: theme.colorScheme.outline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.verified_user, color: SafeLoopColors.safeGreen, size: 20),
                SizedBox(width: 8),
                Text(
                  'Simulated Instant Verification',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Code 7294 automatically matched (prototype mode).',
              style: TextStyle(color: SafeLoopColors.safeGreen, fontSize: 12),
            ),
          ],
        ),
      ),
      const SizedBox(height: 32),
      SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          onPressed: () {
            setState(() {
              _step = 2;
            });
          },
          child: const Text('Continue to PIN Setup'),
        ),
      ),
    ];
  }

  List<Widget> _buildStep2(ThemeData theme) {
    return [
      Text(
        'Create Safety PIN',
        style: theme.textTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.onSurface,
        ),
      ),
      const SizedBox(height: 6),
      Text(
        'This 4-digit PIN is entered to confirm you are safe during check-ins or to cancel warnings.',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      const SizedBox(height: 16),
      NumericPinPad(
        enteredPin: _safetyPin,
        onPinChange: (pin) {
          setState(() {
            _safetyPin = pin;
          });
        },
        showBiometric: false,
      ),
      const SizedBox(height: 16),
      Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16.0),
          border: Border.all(color: theme.colorScheme.outline),
        ),
        child: const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info, color: SafeLoopColors.primaryViolet, size: 22),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Discreet Duress PIN (Configured: 9999)',
                    style: TextStyle(
                      color: SafeLoopColors.primaryViolet,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    "If forced under threat to enter a PIN, typing 9999 visually shows 'Safety Confirmed' so attackers suspect nothing, while secretly dispatching your live distress beacon.",
                    style: TextStyle(
                      color: SafeLoopColors.textSecondary,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 24),
      SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          onPressed: () {
            if (_safetyPin.length < 4) {
              _safetyPin = '1234';
            }
            setState(() {
              _step = 3;
            });
          },
          child: const Text('Continue to Permissions'),
        ),
      ),
    ];
  }

  List<Widget> _buildStep3(ThemeData theme) {
    return [
      Text(
        'Permissions & Biometrics',
        style: theme.textTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.onSurface,
        ),
      ),
      const SizedBox(height: 6),
      Text(
        'SafeLoop requires continuous background location during active journeys to ensure your emergency escalation works seamlessly.',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      const SizedBox(height: 16),
      _buildSwitchCard(
        theme: theme,
        icon: Icons.fingerprint,
        iconColor: SafeLoopColors.primaryViolet,
        title: 'Biometric Authentication',
        subtitle: 'One-tap check-ins with fingerprint',
        value: _biometricEnabled,
        onChanged: (v) => setState(() => _biometricEnabled = v),
        activeTrackColor: SafeLoopColors.primaryViolet,
      ),
      const SizedBox(height: 12),
      _buildSwitchCard(
        theme: theme,
        icon: Icons.location_on,
        iconColor: SafeLoopColors.safeGreen,
        title: 'Precise Journey Location',
        subtitle: 'Only tracked during active journeys',
        value: _locationPermissionGranted,
        onChanged: (v) => setState(() => _locationPermissionGranted = v),
        activeTrackColor: SafeLoopColors.safeGreen,
      ),
      const SizedBox(height: 12),
      _buildSwitchCard(
        theme: theme,
        icon: Icons.contacts,
        iconColor: SafeLoopColors.infoBlue,
        title: 'Trusted Contact Alerts',
        subtitle: 'Dispatches SMS & notifications',
        value: _contactsPermissionGranted,
        onChanged: (v) => setState(() => _contactsPermissionGranted = v),
        activeTrackColor: SafeLoopColors.infoBlue,
      ),
      const SizedBox(height: 24),
      SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          onPressed: () {
            final finalPin = _safetyPin.isNotEmpty ? _safetyPin : '1234';
            widget.onSetupComplete(
              _nameController.text,
              _phoneController.text,
              finalPin,
              _biometricEnabled,
            );
          },
          child: const Text('Complete Setup & Open SafeLoop'),
        ),
      ),
    ];
  }

  Widget _buildSwitchCard({
    required ThemeData theme,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required Color activeTrackColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeTrackColor: activeTrackColor,
            activeThumbColor: Colors.white,
          ),
        ],
      ),
    );
  }
}

