import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/models.dart';
import '../theme/app_colors.dart';

class SettingsScreen extends StatefulWidget {
  final UserProfile userProfile;
  final ValueChanged<UserProfile> onUpdateProfile;
  final VoidCallback onOpenScenarios;
  final VoidCallback? onBack;

  const SettingsScreen({
    super.key,
    required this.userProfile,
    required this.onUpdateProfile,
    required this.onOpenScenarios,
    this.onBack,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late bool _biometric;
  late bool _adaptiveFreq;
  late int _checkInMinutes;
  late TextEditingController _smsController;

  @override
  void initState() {
    super.initState();
    _biometric = widget.userProfile.biometricEnabled;
    _adaptiveFreq = widget.userProfile.adaptiveFrequencyEnabled;
    _checkInMinutes = widget.userProfile.defaultCheckInMinutes;
    _smsController = TextEditingController(text: widget.userProfile.emergencyMessage);
  }

  @override
  void dispose() {
    _smsController.dispose();
    super.dispose();
  }

  void _showPinDialog({required bool isDuress}) {
    final pinCtrl = TextEditingController(
      text: isDuress ? widget.userProfile.duressPin : widget.userProfile.safetyPin,
    );

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(isDuress ? 'Change Discreet Duress PIN' : 'Change Safety PIN'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isDuress
                    ? 'Entering this PIN silently broadcasts distress while appearing to confirm safety to an attacker.'
                    : 'This 4-digit PIN authenticates normal check-ins.',
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: pinCtrl,
                keyboardType: TextInputType.number,
                maxLength: 4,
                decoration: InputDecoration(
                  labelText: isDuress ? 'Duress PIN (e.g. 9999)' : 'Safety PIN (e.g. 1234)',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (pinCtrl.text.length == 4) {
                  final updated = isDuress
                      ? widget.userProfile.copyWith(duressPin: pinCtrl.text)
                      : widget.userProfile.copyWith(safetyPin: pinCtrl.text);
                  widget.onUpdateProfile(updated);
                  Navigator.pop(context);
                }
              },
              style: FilledButton.styleFrom(backgroundColor: AppColors.primaryViolet),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _showGeminiApiKeyDialog() {
    final keyCtrl = TextEditingController(text: widget.userProfile.geminiApiKey);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Gemini API Configuration'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Enter your Google Gemini API key to activate AI-driven route risk intelligence and adaptive check-ins.',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: keyCtrl,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'API Key',
                  hintText: 'Paste Gemini API Key here',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final updated = widget.userProfile.copyWith(geminiApiKey: keyCtrl.text.trim());
                widget.onUpdateProfile(updated);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      keyCtrl.text.trim().isNotEmpty
                          ? 'Gemini API Key configured successfully'
                          : 'Gemini API Key cleared. Local model active.',
                    ),
                    behavior: SnackBarBehavior.floating,
                    backgroundColor: AppColors.primaryCobalt,
                  ),
                );
              },
              style: FilledButton.styleFrom(backgroundColor: AppColors.primaryCobalt),
              child: const Text('Save'),
            ),
          ],
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
        leading: widget.onBack != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: widget.onBack,
              )
            : null,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Settings & Privacy',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            Text(
              'Customize security parameters & privacy',
              style: TextStyle(
                fontSize: 11,
                color: isDark ? AppColors.textSecondary : AppColors.lightTextSecondary,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
          children: [
            // Prototype Scenario Switcher Card
            Container(
              decoration: BoxDecoration(
                color: AppColors.primaryViolet.withValues(alpha: isDark ? 0.15 : 0.08),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.primaryViolet),
              ),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(18),
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: widget.onOpenScenarios,
                  child: const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.science, color: AppColors.primaryViolet, size: 24),
                            SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Prototype Scenario Switcher',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: AppColors.primaryViolet,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Test duress PIN, missed check-ins, SOS & offline mode',
                                  style: TextStyle(fontSize: 11, color: Colors.grey),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Icon(Icons.chevron_right, color: AppColors.primaryViolet),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),


            // Appearance Section
            _buildSectionHeader('Appearance', isDark),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: _cardDecoration(isDark),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.dark_mode, size: 20, color: AppColors.primaryViolet),
                      SizedBox(width: 12),
                      Text('Dark Theme Mode', style: TextStyle(fontWeight: FontWeight.w600)),
                    ],
                  ),
                  Switch(
                    value: widget.userProfile.isDarkMode,
                    activeTrackColor: AppColors.primaryViolet,
                    onChanged: (val) {
                      widget.onUpdateProfile(widget.userProfile.copyWith(isDarkMode: val));
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),


            // Security PINs Section
            _buildSectionHeader('Security & PINs', isDark),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: _cardDecoration(isDark),
              child: Column(
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.lock, color: AppColors.primaryViolet),
                    title: const Text('Safety Check-In PIN', style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text('Current: •••• (${widget.userProfile.safetyPin})'),
                    trailing: const Icon(Icons.edit, size: 18, color: AppColors.primaryViolet),
                    onTap: () => _showPinDialog(isDuress: false),
                  ),
                  const Divider(),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.security, color: AppColors.vibrantLavender),
                    title: const Text('Discreet Duress PIN', style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text('Current: •••• (${widget.userProfile.duressPin}) • Silent Alert'),
                    trailing: const Icon(Icons.edit, size: 18, color: AppColors.primaryViolet),
                    onTap: () => _showPinDialog(isDuress: true),
                  ),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.fingerprint, color: AppColors.safeGreen, size: 22),
                          SizedBox(width: 12),
                          Text('Biometric Authentication', style: TextStyle(fontWeight: FontWeight.w600)),
                        ],
                      ),
                      Switch(
                        value: _biometric,
                        activeTrackColor: AppColors.safeGreen,
                        onChanged: (val) {
                          setState(() => _biometric = val);
                          widget.onUpdateProfile(widget.userProfile.copyWith(biometricEnabled: val));
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),


            // Adaptive Protection Section
            _buildSectionHeader('Adaptive Protection Guardian', isDark),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: _cardDecoration(isDark),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Default Check-In Interval',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        '$_checkInMinutes min',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryViolet),
                      ),
                    ],
                  ),
                  Slider(
                    value: _checkInMinutes.toDouble(),
                    min: 5,
                    max: 30,
                    divisions: 5,
                    activeColor: AppColors.primaryViolet,
                    onChanged: (val) {
                      setState(() => _checkInMinutes = val.round());
                      widget.onUpdateProfile(
                        widget.userProfile.copyWith(defaultCheckInMinutes: val.round()),
                      );
                    },
                  ),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Adaptive Frequency Mode', style: TextStyle(fontWeight: FontWeight.w600)),
                          Text('Adjusts check-ins based on speed & night hours', style: TextStyle(fontSize: 11, color: Colors.grey)),
                        ],
                      ),
                      Switch(
                        value: _adaptiveFreq,
                        activeTrackColor: AppColors.primaryViolet,
                        onChanged: (val) {
                          setState(() => _adaptiveFreq = val);
                          widget.onUpdateProfile(
                            widget.userProfile.copyWith(adaptiveFrequencyEnabled: val),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Gemini AI Safety Intelligence Section
            _buildSectionHeader('Gemini AI Safety Intelligence', isDark),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: _cardDecoration(isDark),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.auto_awesome, color: AppColors.primaryCobalt),
                    title: const Text('Gemini API Key', style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      widget.userProfile.geminiApiKey.isNotEmpty
                          ? 'Active (${widget.userProfile.geminiApiKey.substring(0, math.min(6, widget.userProfile.geminiApiKey.length))}••••)'
                          : 'Not set (Local intelligence active)',
                      style: TextStyle(
                        fontSize: 12,
                        color: widget.userProfile.geminiApiKey.isNotEmpty
                            ? AppColors.safeGreen
                            : (isDark ? AppColors.textSecondary : AppColors.lightTextSecondary),
                      ),
                    ),
                    trailing: const Icon(Icons.edit, size: 18, color: AppColors.primaryCobalt),
                    onTap: () => _showGeminiApiKeyDialog(),
                  ),
                  const Text(
                    'Powers contextual journey risk prediction and safety check-in timing.',
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Emergency SMS Message Template
            _buildSectionHeader('Emergency SMS Template', isDark),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: _cardDecoration(isDark),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _smsController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'Emergency Broadcast Message',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onChanged: (val) {
                      widget.onUpdateProfile(widget.userProfile.copyWith(emergencyMessage: val));
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: isDark ? AppColors.textPrimary : AppColors.lightTextPrimary,
      ),
    );
  }

  BoxDecoration _cardDecoration(bool isDark) {
    return BoxDecoration(
      color: isDark ? AppColors.midnightDarkSurface : AppColors.lightSurface,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(
        color: isDark ? AppColors.midnightDarkCardBorder : AppColors.lightCardBorder,
      ),
    );
  }
}

