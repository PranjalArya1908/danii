import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class NumericPinPad extends StatelessWidget {
  final int pinLength;
  final String enteredPin;
  final ValueChanged<String> onPinChange;
  final VoidCallback? onBiometricClick;
  final bool showBiometric;
  final bool isError;
  final String? errorMessage;

  const NumericPinPad({
    super.key,
    this.pinLength = 4,
    required this.enteredPin,
    required this.onPinChange,
    this.onBiometricClick,
    this.showBiometric = true,
    this.isError = false,
    this.errorMessage,
  });

  void _onKeyPress(String key) {
    if (key == 'DEL') {
      if (enteredPin.isNotEmpty) {
        onPinChange(enteredPin.substring(0, enteredPin.length - 1));
      }
    } else if (key == 'BIO') {
      onBiometricClick?.call();
    } else if (key.isNotEmpty) {
      if (enteredPin.length < pinLength) {
        onPinChange(enteredPin + key);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final dotActiveColor = isError ? AppColors.emergencyRed : AppColors.primaryViolet;
    final dotBorderColor = isError
        ? AppColors.emergencyRed
        : (isDark ? AppColors.midnightDarkCardBorder : AppColors.lightCardBorder);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // PIN dot indicators
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 18.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(pinLength, (index) {
              final isFilled = index < enteredPin.length;
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 8.0),
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: isFilled ? dotActiveColor : Colors.transparent,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isFilled ? dotActiveColor : dotBorderColor,
                    width: 2,
                  ),
                ),
              );
            }),
          ),
        ),

        // Optional error message
        if (errorMessage != null) ...[
          Text(
            errorMessage!,
            style: const TextStyle(
              color: AppColors.emergencyRed,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Keypad grid
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            children: [
              _buildRow(['1', '2', '3'], isDark),
              const SizedBox(height: 12),
              _buildRow(['4', '5', '6'], isDark),
              const SizedBox(height: 12),
              _buildRow(['7', '8', '9'], isDark),
              const SizedBox(height: 12),
              _buildRow([showBiometric ? 'BIO' : '', '0', 'DEL'], isDark),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRow(List<String> keys, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: keys.map((key) => _buildKey(key, isDark)).toList(),
    );
  }

  Widget _buildKey(String key, bool isDark) {
    if (key.isEmpty) {
      return const SizedBox(width: 68, height: 68);
    }

    final keyBg = isDark
        ? AppColors.midnightDarkSurfaceVariant
        : AppColors.lightSurfaceVariant;

    Widget content;
    if (key == 'DEL') {
      content = Icon(
        Icons.backspace_outlined,
        color: isDark ? AppColors.textPrimary : AppColors.lightTextPrimary,
        size: 24,
      );
    } else if (key == 'BIO') {
      content = const Icon(
        Icons.fingerprint,
        color: AppColors.primaryViolet,
        size: 32,
      );
    } else {
      content = Text(
        key,
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: isDark ? AppColors.textPrimary : AppColors.lightTextPrimary,
        ),
      );
    }

    return SizedBox(
      width: 68,
      height: 68,
      child: Material(
        color: (key == 'BIO' || key == 'DEL') ? Colors.transparent : keyBg,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _onKeyPress(key),
          child: Center(child: content),
        ),
      ),
    );
  }
}

