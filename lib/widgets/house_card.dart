import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class HouseCard extends StatelessWidget {
  final String houseName;
  final String motto;
  final bool isSelected;
  final VoidCallback onTap;

  const HouseCard({
    super.key,
    required this.houseName,
    required this.motto,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = HouseColors.getHouseColor(houseName);
    final darkColor = HouseColors.getHouseDarkColor(houseName);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () {
        AppHaptics.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutBack,
        transform: Matrix4.diagonal3Values(
          isSelected ? 1.05 : 1.0,
          isSelected ? 1.05 : 1.0,
          1.0,
        ),
        transformAlignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isSelected
                ? color
                : Theme.of(context).colorScheme.outline.withValues(alpha: 0.6),
            width: isSelected ? 3 : 1.5,
          ),
          gradient: isSelected
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [color, darkColor],
                )
              : null,
          color: isSelected
              ? null
              : (isDark ? const Color(0xFF1A2338) : const Color(0xFFF8FAFC)),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.45),
                    blurRadius: 24,
                    spreadRadius: 2,
                    offset: const Offset(0, 10),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
        ),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Checkmark in top-right
            Positioned(
              top: 0,
              right: 0,
              child: AnimatedOpacity(
                opacity: isSelected ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 250),
                child: AnimatedScale(
                  scale: isSelected ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.easeOutBack,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.3),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),

            // Centered Mascot Crest, Name & Motto
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Crest / Mascot icon
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: isSelected
                        ? Colors.white.withValues(alpha: 0.22)
                        : (isDark
                              ? const Color(0xFF2A3A52)
                              : const Color(0xFFE2E8F0)),
                    border: Border.all(
                      color: isSelected
                          ? Colors.white.withValues(alpha: 0.35)
                          : color.withValues(alpha: 0.25),
                      width: 1.2,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      HouseColors.getHouseEmoji(houseName),
                      style: const TextStyle(fontSize: 24),
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Name
                Text(
                  houseName,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: isSelected
                        ? Colors.white
                        : Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),

                // Motto
                Text(
                  motto,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                    color: isSelected
                        ? Colors.white.withValues(alpha: 0.85)
                        : Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.55),
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
