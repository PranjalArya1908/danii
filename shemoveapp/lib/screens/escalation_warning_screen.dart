import 'package:flutter/material.dart';
import '../components/numeric_pin_pad.dart';
import '../models/models.dart';
import '../theme/colors.dart';

class EscalationWarningScreen extends StatefulWidget {
  final int secondsRemaining;
  final List<TrustedContact> contacts;
  final String configuredPin;
  final bool Function(String pin) onCancelWithPin;
  final VoidCallback onBypassAndEscalateNow;

  const EscalationWarningScreen({
    super.key,
    required this.secondsRemaining,
    required this.contacts,
    required this.configuredPin,
    required this.onCancelWithPin,
    required this.onBypassAndEscalateNow,
  });

  @override
  State<EscalationWarningScreen> createState() => _EscalationWarningScreenState();
}

class _EscalationWarningScreenState extends State<EscalationWarningScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  bool _showPinDialog = false;
  String _enteredPin = '';
  String? _pinError;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.3, end: 0.85).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _onPinChange(String pin) {
    setState(() {
      _enteredPin = pin;
      _pinError = null;
    });

    if (pin.length == 4) {
      final success = widget.onCancelWithPin(pin);
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.midnightDarkBackground : AppColors.lightBackground,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Top Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.warningAmber.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.warningAmber),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.warning, color: AppColors.warningAmber, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'SAFETY CHECK-IN MISSED',
                      style: TextStyle(
                        color: AppColors.warningAmber,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),

              // Central Countdown Gauge
              Column(
                children: [
                  AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      return Container(
                        width: 170,
                        height: 170,
                        decoration: BoxDecoration(
                          color: AppColors.warningAmber.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.warningAmber.withValues(alpha: _pulseAnimation.value),
                            width: 5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.warningAmber
                                  .withValues(alpha: _pulseAnimation.value * 0.3),
                              blurRadius: 20,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${widget.secondsRemaining}',
                                style: const TextStyle(
                                  fontSize: 60,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.warningAmber,
                                  fontFamily: 'monospace',
                                  height: 1.0,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'SECONDS',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.warningAmber,
                                  letterSpacing: 1.0,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'Auto Escalation Initiated',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppColors.textPrimary : AppColors.lightTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Text(
                      'SheMove hasn\'t received your check-in. Emergency alert with live GPS tracking will dispatch automatically to ${widget.contacts.length} trusted contacts.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.4,
                        color: isDark ? AppColors.textSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                  ),
                ],
              ),

              // Actions
              Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      onPressed: () {
                        setState(() {
                          _showPinDialog = true;
                        });
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.safeGreen,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: const Text(
                        'I\'m Safe (Cancel Escalation)',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: OutlinedButton(
                      onPressed: widget.onBypassAndEscalateNow,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.emergencyRed,
                        side: const BorderSide(color: AppColors.emergencyRed, width: 1.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: const Text(
                        'Bypass & Escalate Alert Now',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      bottomSheet: _showPinDialog
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
                        'Enter PIN to Disarm',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => setState(() => _showPinDialog = false),
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
