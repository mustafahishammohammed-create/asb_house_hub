import 'package:flutter/material.dart';

/// Accessible Cooldown & Anti-Spam HUD Banner complying with WCAG 2.1 AA,
/// WCAG 4.1.3 (Live Regions), WCAG 2.5.5 (48dp Touch Targets), and
/// WCAG 1.4.4 (200% font scale elasticity).
class GamificationCooldownBanner extends StatelessWidget {
  final String activityTitle;
  final String formattedRemaining;
  final Duration remainingDuration;
  final VoidCallback? onDismiss;
  final VoidCallback? onRetry;
  final VoidCallback? onScheduleReminder;
  final bool isRapidThrottle;

  const GamificationCooldownBanner({
    super.key,
    required this.activityTitle,
    required this.formattedRemaining,
    required this.remainingDuration,
    this.onDismiss,
    this.onRetry,
    this.onScheduleReminder,
    this.isRapidThrottle = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // WCAG 1.4.3 High Contrast Color Palettes
    // Dark: Amber #FBBF24 on Slate #1E293B (Ratio > 7:1)
    // Light: Deep Amber #B45309 on Light Slate #F1F5F9 (Ratio > 5.5:1)
    final containerBg = isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);
    final borderColor = isDark ? const Color(0xFFFBBF24) : const Color(0xFFB45309);
    final primaryTextColor = isDark ? const Color(0xFFFBBF24) : const Color(0xFFB45309);
    final subtitleColor = isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155);

    final semanticLabel = isRapidThrottle
        ? 'Rapid action debounce active. Please wait $formattedRemaining before submitting again.'
        : 'Daily challenge on cooldown. Next round unlocks in $formattedRemaining. Try again tomorrow.';

    return Semantics(
      container: true,
      liveRegion: true,
      label: semanticLabel,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: containerBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: borderColor.withValues(alpha: 0.6), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Header Row with Icon & Time (Responsive for high font scaling & narrow viewports)
                if (constraints.maxWidth < 380) ...[
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: borderColor.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Icon(
                            isRapidThrottle ? Icons.hourglass_top_rounded : Icons.lock_clock_rounded,
                            color: primaryTextColor,
                            size: 24,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isRapidThrottle ? 'Cooldown Active' : 'Daily Challenge Cooldown',
                              style: TextStyle(
                                color: primaryTextColor,
                                fontWeight: FontWeight.w900,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              activityTitle,
                              style: TextStyle(
                                color: subtitleColor,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: borderColor.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: borderColor.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.timer_outlined, size: 14, color: primaryTextColor),
                        const SizedBox(width: 4),
                        Text(
                          formattedRemaining,
                          style: TextStyle(
                            color: primaryTextColor,
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: borderColor.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Icon(
                            isRapidThrottle ? Icons.hourglass_top_rounded : Icons.lock_clock_rounded,
                            color: primaryTextColor,
                            size: 24,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isRapidThrottle ? 'Cooldown Active' : 'Daily Challenge Cooldown',
                              style: TextStyle(
                                color: primaryTextColor,
                                fontWeight: FontWeight.w900,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              activityTitle,
                              style: TextStyle(
                                color: subtitleColor,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Formatted Countdown Chip
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: borderColor.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: borderColor.withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.timer_outlined, size: 14, color: primaryTextColor),
                            const SizedBox(width: 4),
                            Text(
                              formattedRemaining,
                              style: TextStyle(
                                color: primaryTextColor,
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),

                // Cooldown explanation message (elastic under font scaling)
                Text(
                  isRapidThrottle
                      ? 'Submissions are rate-limited to prevent automated spam and packet replay. Unlocks shortly.'
                      : 'To preserve fairness across all four houses, daily challenges award points once every 24 hours. Next session unlocks at the scheduled rollover.',
                  style: TextStyle(
                    color: subtitleColor,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 14),

                // Accessible Action Buttons with >= 48x48dp touch targets
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  alignment: WrapAlignment.end,
                  children: [
                    if (onScheduleReminder != null)
                      ConstrainedBox(
                        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                        child: OutlinedButton.icon(
                          onPressed: onScheduleReminder,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: primaryTextColor,
                            side: BorderSide(color: borderColor.withValues(alpha: 0.5)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                          icon: const Icon(Icons.notifications_active_outlined, size: 16),
                          label: const Text('Remind Me', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                        ),
                      ),
                    if (onRetry != null)
                      ConstrainedBox(
                        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                        child: ElevatedButton.icon(
                          onPressed: onRetry,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: borderColor,
                            foregroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            elevation: 0,
                          ),
                          icon: const Icon(Icons.refresh_rounded, size: 16),
                          label: const Text('Check Status', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
                        ),
                      ),
                    if (onDismiss != null)
                      ConstrainedBox(
                        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                        child: TextButton(
                          onPressed: onDismiss,
                          style: TextButton.styleFrom(
                            foregroundColor: subtitleColor,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                          child: const Text('Dismiss', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
