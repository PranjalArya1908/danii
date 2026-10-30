import 'package:flutter/material.dart';
import '../theme/colors.dart';

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // PIN Dot indicators
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 18.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(pinLength, (i) {
              final isFilled = i < enteredPin.length;
              Color dotColor;
              Color borderColor;

              if (isError) {
                dotColor = SafeLoopColors.emergencyRed;
                borderColor = SafeLoopColors.emergencyRed;
              } else if (isFilled) {
                dotColor = SafeLoopColors.primaryViolet;
                borderColor = SafeLoopColors.primaryViolet;
              } else {
                dotColor = Colors.transparent;
                borderColor = theme.colorScheme.outline;
              }

              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 8.0),
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: dotColor,
                  border: Border.all(color: borderColor, width: 2.0),
                ),
              );
            }),
          ),
        ),

        if (errorMessage != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: Text(
              errorMessage!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: SafeLoopColors.emergencyRed,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

        // Keypad Grid
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            children: [
              _buildRow(['1', '2', '3'], context),
              const SizedBox(height: 12),
              _buildRow(['4', '5', '6'], context),
              const SizedBox(height: 12),
              _buildRow(['7', '8', '9'], context),
              const SizedBox(height: 12),
              _buildRow([showBiometric ? 'BIO' : '', '0', 'DEL'], context),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRow(List<String> keys, BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: keys.map((key) => _buildKey(key, context)).toList(),
    );
  }

  Widget _buildKey(String key, BuildContext context) {
    final theme = Theme.of(context);
    final isNotEmpty = key.isNotEmpty;
    final isSpecial = key == 'BIO' || key == 'DEL';

    return SizedBox(
      width: 68,
      height: 68,
      child: isNotEmpty
          ? Material(
              color: isSpecial && key == 'BIO'
                  ? Colors.transparent
                  : theme.colorScheme.surfaceContainerHighest,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () {
                  if (key == 'DEL') {
                    if (enteredPin.isNotEmpty) {
                      onPinChange(enteredPin.substring(0, enteredPin.length - 1));
                    }
                  } else if (key == 'BIO') {
                    onBiometricClick?.call();
                  } else {
                    if (enteredPin.length < pinLength) {
                      onPinChange(enteredPin + key);
                    }
                  }
                },
                child: Center(
                  child: key == 'DEL'
                      ? Icon(
                          Icons.backspace,
                          size: 22,
                          color: theme.colorScheme.onSurfaceVariant,
                        )
                      : key == 'BIO'
                          ? const Icon(
                              Icons.fingerprint,
                              size: 36,
                              color: SafeLoopColors.primaryViolet,
                            )
                          : Text(
                              key,
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                ),
              ),
            )
          : const SizedBox.shrink(),
    );
  }
}

