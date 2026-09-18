import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

enum PasswordStrength { none, weak, fair, good, strong }

class StrengthMeter extends StatelessWidget {
  final String password;

  const StrengthMeter({super.key, required this.password});

  PasswordStrength get strength {
    if (password.isEmpty) return PasswordStrength.none;
    int score = 0;
    if (password.length >= 6) {
      score++;
    }
    if (password.length >= 8) {
      score++;
    }
    if (RegExp(r'[a-z]').hasMatch(password) &&
        RegExp(r'[A-Z]').hasMatch(password)) {
      score++;
    }
    if (RegExp(r'[0-9]').hasMatch(password) ||
        RegExp(r'[^a-zA-Z0-9]').hasMatch(password)) {
      score++;
    }

    switch (score) {
      case 0:
        return PasswordStrength.none;
      case 1:
        return PasswordStrength.weak;
      case 2:
        return PasswordStrength.fair;
      case 3:
        return PasswordStrength.good;
      default:
        return PasswordStrength.strong;
    }
  }

  Color _segmentColor(int index, PasswordStrength s) {
    if (s == PasswordStrength.none) return Colors.transparent;
    final level = s.index; // 1=weak, 2=fair, 3=good, 4=strong
    if (index >= level) return const Color(0xFFE2E8F0);
    switch (s) {
      case PasswordStrength.weak:
        return HouseColors.ruby;
      case PasswordStrength.fair:
        return HouseColors.topaz;
      case PasswordStrength.good:
        return const Color(0xFF84CC16);
      case PasswordStrength.strong:
        return HouseColors.emerald;
      default:
        return const Color(0xFFE2E8F0);
    }
  }

  String get label {
    switch (strength) {
      case PasswordStrength.none:
        return 'Enter a password';
      case PasswordStrength.weak:
        return 'Weak';
      case PasswordStrength.fair:
        return 'Fair';
      case PasswordStrength.good:
        return 'Good';
      case PasswordStrength.strong:
        return 'Strong';
    }
  }

  Color get labelColor {
    switch (strength) {
      case PasswordStrength.none:
        return const Color(0xFF94A3B8);
      case PasswordStrength.weak:
        return HouseColors.ruby;
      case PasswordStrength.fair:
        return HouseColors.topaz;
      case PasswordStrength.good:
        return const Color(0xFF84CC16);
      case PasswordStrength.strong:
        return HouseColors.emerald;
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = strength;
    return Row(
      children: [
        Expanded(
          child: Row(
            children: List.generate(4, (i) {
              final segColor = _segmentColor(i, s);
              final isColored =
                  segColor != const Color(0xFFE2E8F0) &&
                  segColor != Colors.transparent;
              return Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  height: 6,
                  margin: EdgeInsets.only(right: i < 3 ? 5 : 0),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(9999),
                    color: segColor,
                    boxShadow: isColored && s == PasswordStrength.strong
                        ? [
                            BoxShadow(
                              color: segColor.withValues(alpha: 0.5),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                ),
              );
            }),
          ),
        ),
        const SizedBox(width: 12),
        AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 200),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: labelColor,
          ),
          child: Text(label),
        ),
      ],
    );
  }
}
