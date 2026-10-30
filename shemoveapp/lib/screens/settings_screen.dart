import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/models.dart';
import '../theme/colors.dart';

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
      builder: (ctx) {
        return AlertDialog(
          title: Text(isDuress ? 'Change Discreet Duress PIN' : 'Change Safety PIN'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isDuress
                    ? 'Entering this PIN silently broadcasts distress with live GPS coordinates while appearing routine to an attacker.'
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
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (pinCtrl.text.length == 4) {
                  final updated = isDuress
                      ? widget.userProfile.copyWith(duressPin: pinCtrl.text)
                      : widget.userProfile.copyWith(safetyPin: pinCtrl.text);
                  widget.onUpdateProfile(updated);
                  Navigator.pop(ctx);
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
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Gemini AI Safety Configuration'),
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
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final updated = widget.userProfile.copyWith(geminiApiKey: keyCtrl.text.trim());
                widget.onUpdateProfile(updated);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Gemini API key updated'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              style: FilledButton.styleFrom(backgroundColor: AppColors.primaryViolet),
              child: const Text('Save Key'),
            ),
          ],
        );
      },
    );
  }

  void _showProfileEditDialog() {
    final nameCtrl = TextEditingController(text: widget.userProfile.name);
    final phoneCtrl = TextEditingController(text: widget.userProfile.phone);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Profile'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Full Name'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: phoneCtrl,
              decoration: const InputDecoration(labelText: 'Phone Number'),
              keyboardType: TextInputType.phone,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final updated = widget.userProfile.copyWith(
                name: nameCtrl.text.trim(),
                phone: phoneCtrl.text.trim(),
              );
              widget.onUpdateProfile(updated);
              Navigator.pop(ctx);
            },
            style: FilledButton.styleFrom(backgroundColor: AppColors.primaryViolet),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.midnightDarkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('Settings & Privacy', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        leading: widget.onBack != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: widget.onBack,
              )
            : null,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Profile Header Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: _cardDecoration(isDark),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: AppColors.primaryViolet,
                      child: Text(
                        widget.userProfile.name.isNotEmpty
                            ? widget.userProfile.name[0].toUpperCase()
                            : 'A',
                        style: const TextStyle(fontSize: 22, color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.userProfile.name,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.userProfile.phone,
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark ? AppColors.textSecondary : AppColors.lightTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, color: AppColors.primaryViolet),
                      tooltip: 'Edit Profile',
                      onPressed: _showProfileEditDialog,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // 2. Prototype Scenario Switcher Banner
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: widget.onOpenScenarios,
                  borderRadius: BorderRadius.circular(18),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primaryViolet.withValues(alpha: isDark ? 0.2 : 0.1),
                          (isDark ? AppColors.midnightDarkSurface : AppColors.lightSurface),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppColors.primaryViolet.withValues(alpha: 0.4)),
                    ),
                    child: const Row(
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
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Test missed check-in, duress PIN, and SOS',
                                  style: TextStyle(color: AppColors.primaryViolet, fontSize: 12),
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
              const SizedBox(height: 20),

              // 3. Security & PIN Authentication Section
              _buildSectionHeader('SECURITY & AUTHENTICATION', isDark),
              const SizedBox(height: 8),
              Container(
                decoration: _cardDecoration(isDark),
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.lock_outline, color: AppColors.safeGreen),
                      title: const Text('Routine Safety PIN', style: TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: const Text('Used for daily journey check-ins (1234)'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _showPinDialog(isDuress: false),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.shield_outlined, color: AppColors.emergencyRed),
                      title: const Text('Silent Duress PIN', style: TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: const Text('Covert distress trigger (9999)'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _showPinDialog(isDuress: true),
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      secondary: const Icon(Icons.fingerprint, color: AppColors.primaryViolet),
                      title: const Text('Biometric Authentication', style: TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: const Text('Fast check-in via fingerprint or face lock'),
                      value: _biometric,
                      activeTrackColor: AppColors.primaryViolet,
                      onChanged: (val) {
                        setState(() => _biometric = val);
                        widget.onUpdateProfile(widget.userProfile.copyWith(biometricEnabled: val));
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // 4. Adaptive Check-In Settings
              _buildSectionHeader('CHECK-IN FREQUENCY', isDark),
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
                        const Text('Default Check-In Interval', style: TextStyle(fontWeight: FontWeight.w600)),
                        Text('$_checkInMinutes min', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryViolet)),
                      ],
                    ),
                    Slider(
                      value: _checkInMinutes.toDouble(),
                      min: 5,
                      max: 30,
                      divisions: 5,
                      activeColor: AppColors.primaryViolet,
                      label: '$_checkInMinutes min',
                      onChanged: (val) {
                        setState(() => _checkInMinutes = val.round());
                        widget.onUpdateProfile(widget.userProfile.copyWith(defaultCheckInMinutes: val.round()));
                      },
                    ),
                    const Divider(),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Adaptive Frequency Mode', style: TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: const Text('Tightens check-in intervals during night or irregular transit speeds', style: TextStyle(fontSize: 11)),
                      value: _adaptiveFreq,
                      activeTrackColor: AppColors.primaryViolet,
                      onChanged: (val) {
                        setState(() => _adaptiveFreq = val);
                        widget.onUpdateProfile(widget.userProfile.copyWith(adaptiveFrequencyEnabled: val));
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // 5. Gemini AI Safety Intelligence
              _buildSectionHeader('GEMINI AI SAFETY INTELLIGENCE', isDark),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: _cardDecoration(isDark),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.auto_awesome, color: AppColors.primaryViolet),
                      title: const Text('Gemini API Key', style: TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(
                        widget.userProfile.geminiApiKey.isNotEmpty
                            ? 'Active (${widget.userProfile.geminiApiKey.substring(0, math.min(6, widget.userProfile.geminiApiKey.length))}••••)'
                            : 'Not set (Local intelligence active)',
                        style: TextStyle(
                          fontSize: 12,
                          color: widget.userProfile.geminiApiKey.isNotEmpty ? AppColors.safeGreen : AppColors.textSecondary,
                        ),
                      ),
                      trailing: const Icon(Icons.edit, size: 18, color: AppColors.primaryViolet),
                      onTap: _showGeminiApiKeyDialog,
                    ),
                    const Text(
                      'Powers real-time contextual journey risk analysis and predictive safety timing.',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // 6. Emergency Broadcast SMS Template
              _buildSectionHeader('EMERGENCY BROADCAST SMS', isDark),
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
                        labelText: 'Emergency Broadcast Template',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onChanged: (val) {
                        widget.onUpdateProfile(widget.userProfile.copyWith(emergencyMessage: val));
                      },
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Live GPS tracking link and route info are automatically appended during escalation.',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.0,
        color: isDark ? AppColors.textSecondary : AppColors.lightTextSecondary,
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
