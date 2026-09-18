import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class PillSelector extends StatelessWidget {
  final String label;
  final List<String> options;
  final String? selectedValue;
  final ValueChanged<String> onSelected;

  const PillSelector({
    super.key,
    required this.label,
    required this.options,
    required this.selectedValue,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.6),
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: options.map((opt) {
            final isActive = selectedValue == opt;
            return GestureDetector(
              onTap: () => onSelected(opt),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutBack,
                transform: Matrix4.diagonal3Values(
                  isActive ? 1.08 : 1.0,
                  isActive ? 1.08 : 1.0,
                  1.0,
                ),
                transformAlignment: Alignment.center,
                height: 52,
                constraints: const BoxConstraints(minWidth: 54),
                padding: const EdgeInsets.symmetric(horizontal: 22),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(9999),
                  border: Border.all(
                    color: isActive
                        ? Colors.transparent
                        : Theme.of(
                            context,
                          ).colorScheme.outline.withValues(alpha: 0.5),
                    width: isActive ? 0 : 2,
                  ),
                  gradient: isActive
                      ? const LinearGradient(
                          colors: [HouseColors.ruby, HouseColors.rubyDark],
                        )
                      : null,
                  color: isActive
                      ? null
                      : (isDark
                            ? const Color(0xFF1A2338)
                            : const Color(0xFFF8FAFC)),
                  boxShadow: isActive
                      ? [
                          BoxShadow(
                            color: HouseColors.ruby.withValues(alpha: 0.45),
                            blurRadius: 16,
                            spreadRadius: 1,
                            offset: const Offset(0, 6),
                          ),
                        ]
                      : [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                ),
                alignment: Alignment.center,
                child: AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 200),
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: isActive ? 16 : 15,
                    fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                    color: isActive
                        ? Colors.white
                        : Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                  child: Text(opt),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
