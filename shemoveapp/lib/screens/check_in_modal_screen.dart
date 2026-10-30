import 'package:flutter/material.dart';
import '../components/numeric_pin_pad.dart';
import '../components/swipe_action_control.dart';
import '../theme/colors.dart';

class CheckInModalScreen extends StatefulWidget {
  final bool biometricEnabled;
  final String configuredSafetyPin;
  final String configuredDuressPin;
  final int secondsRemaining;
  final Function(String pin, bool isBiometric) onConfirmSafeWithPin;
  final VoidCallback onNeedHelpRequested;
  final VoidCallback onCancelCheckIn;

  const CheckInModalScreen({
    super.key,
    this.biometricEnabled = true,
    this.configuredSafetyPin = '1234',
    this.configuredDuressPin = '9999',
    this.secondsRemaining = 60,
    required this.onConfirmSafeWithPin,
    required this.onNeedHelpRequested,
    required this.onCancelCheckIn,
  });

  @override
  State<CheckInModalScreen> createState() => _CheckInModalScreenState();
}

class _CheckInModalScreenState extends State<CheckInModalScreen>
    with SingleTickerProviderStateMixin {
  int _checkInStep = 1;
  String _enteredPin = '';
  String? _pinError;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.94, end: 1.06).animate(
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
      if (pin == widget.configuredSafetyPin || pin == widget.configuredDuressPin) {
        widget.onConfirmSafeWithPin(pin, false);
      } else {
        setState(() {
          _pinError = 'Incorrect PIN. Enter Safety or Duress PIN';
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

  void _onBiometric() {
    widget.onConfirmSafeWithPin(widget.configuredSafetyPin, true);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.midnightDarkBackground : AppColors.lightBackground,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Header & Close
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.primaryViolet.withValues(alpha: isDark ? 0.2 : 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'SheMove Adaptive Check-In',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryViolet,
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      // Response Countdown Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: (widget.secondsRemaining <= 15
                                  ? AppColors.emergencyRed
                                  : AppColors.warningAmber)
                              .withValues(alpha: isDark ? 0.2 : 0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: widget.secondsRemaining <= 15
                                ? AppColors.emergencyRed
                                : AppColors.warningAmber,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.timer_outlined,
                              size: 13,
                              color: widget.secondsRemaining <= 15
                                  ? AppColors.emergencyRed
                                  : AppColors.warningAmber,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${widget.secondsRemaining}s',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: widget.secondsRemaining <= 15
                                    ? AppColors.emergencyRed
                                    : AppColors.warningAmber,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: widget.onCancelCheckIn,
                        icon: const Icon(Icons.close),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                ],
              ),

              // Content based on Step
              if (_checkInStep == 1) _buildStep1(isDark) else _buildStep2(isDark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep1(bool isDark) {
    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Spacer(),
          // Pulsing shield emblem
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _pulseAnimation.value,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: AppColors.primaryViolet.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Container(
                      width: 76,
                      height: 76,
                      decoration: const BoxDecoration(
                        color: AppColors.primaryViolet,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.shield, color: Colors.white, size: 42),
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 32),

          Text(
            'Are you safe right now?',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: isDark ? AppColors.textPrimary : AppColors.lightTextPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Text(
              'A routine check-in for your journey. Please respond within ${widget.secondsRemaining}s before automated escalation initiates.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? AppColors.textSecondary : AppColors.lightTextSecondary,
              ),
            ),
          ),
          const Spacer(),

          // Actions
          Column(
            children: [
              SwipeActionControl(
                label: 'Swipe right to confirm safe',
                sliderColor: AppColors.safeGreen,
                onConfirmed: () {
                  setState(() {
                    _checkInStep = 2;
                  });
                },
              ),
              const SizedBox(height: 14),

              // Need Help button
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppColors.emergencyRed.withValues(alpha: isDark ? 0.2 : 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.emergencyRed.withValues(alpha: 0.5),
                  ),
                ),
                child: TextButton.icon(
                  onPressed: widget.onNeedHelpRequested,
                  icon: const Icon(Icons.warning, color: AppColors.emergencyRed, size: 20),
                  label: const Text(
                    'I Need Help (Escalate Alert)',
                    style: TextStyle(
                      color: AppColors.emergencyRed,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStep2(bool isDark) {
    return Expanded(
      child: Column(
        children: [
          const SizedBox(height: 16),
          Text(
            'Enter Security PIN',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: isDark ? AppColors.textPrimary : AppColors.lightTextPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Enter your 4-digit code to authenticate (${widget.secondsRemaining}s remaining)',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: widget.secondsRemaining <= 15
                  ? AppColors.emergencyRed
                  : (isDark ? AppColors.textSecondary : AppColors.lightTextSecondary),
            ),
          ),
          const SizedBox(height: 16),

          NumericPinPad(
            enteredPin: _enteredPin,
            onPinChange: _onPinChange,
            showBiometric: widget.biometricEnabled,
            onBiometricClick: _onBiometric,
            isError: _pinError != null,
            errorMessage: _pinError,
          ),
        ],
      ),
    );
  }
}
