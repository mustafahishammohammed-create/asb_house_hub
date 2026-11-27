import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Metal finishes inspired by Apple Fitness awards
enum MetalType {
  gold,
  platinum,
  silver,
  bronze,
  roseGold,
  rubyGold,
  sapphireAstral,
  emeraldJade,
  topazSun,
  holographic,
}

/// Geometric medal silhouettes
enum BadgeShape {
  circle,
  hexagon,
  octagon,
  shield,
  diamond,
}

/// Model representing an Apple Fitness style award
class AppleFitnessBadgeData {
  final String id;
  final String title;
  final String category; // 'House Pride', 'Milestones', 'Competitions', 'Special'
  final String desc;
  final String criteria;
  final MetalType metal;
  final BadgeShape shape;
  final IconData icon;
  final String mascotEmoji;
  final bool unlocked;
  final double progress; // 0.0 to 1.0
  final String progressLabel;
  final String earnedDate;
  final int meritPoints;
  final String rarity; // 'COMMON', 'RARE', 'EPIC', 'LEGENDARY'

  const AppleFitnessBadgeData({
    required this.id,
    required this.title,
    required this.category,
    required this.desc,
    required this.criteria,
    required this.metal,
    required this.shape,
    required this.icon,
    this.mascotEmoji = '🏆',
    required this.unlocked,
    this.progress = 1.0,
    this.progressLabel = 'Completed',
    this.earnedDate = 'Term 1, 2026',
    this.meritPoints = 50,
    this.rarity = 'EPIC',
  });
}

/// A standalone 3D metallic Apple Fitness badge renderer with specular glint
class AppleFitnessBadge extends StatelessWidget {
  final AppleFitnessBadgeData badge;
  final double size;
  final double gleamOffset; // 0.0 to 1.0 for shining light beam
  final double tiltX;
  final double tiltY;
  final bool isBack;
  final String recipientName;
  final String scholarNo;
  final String houseName;

  const AppleFitnessBadge({
    super.key,
    required this.badge,
    this.size = 110,
    this.gleamOffset = 0.0,
    this.tiltX = 0.0,
    this.tiltY = 0.0,
    this.isBack = false,
    this.recipientName = 'Student Champion',
    this.scholarNo = 'ASB-2026',
    this.houseName = 'RUBY',
  });

  static Color getGlowColor(MetalType metal) {
    switch (metal) {
      case MetalType.rubyGold:
        return const Color(0xFFFF2A4B);
      case MetalType.sapphireAstral:
        return const Color(0xFF2979FF);
      case MetalType.emeraldJade:
        return const Color(0xFF00E676);
      case MetalType.topazSun:
      case MetalType.gold:
        return const Color(0xFFFFC107);
      case MetalType.platinum:
        return const Color(0xFFB0BEC5);
      case MetalType.holographic:
        return const Color(0xFFD500F9);
      case MetalType.roseGold:
      case MetalType.silver:
      case MetalType.bronze:
        return const Color(0xFFBDBDBD);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          size: Size(size, size),
          painter: _AppleBadgePainter(
            badge: badge,
            gleamOffset: gleamOffset,
            tiltX: tiltX,
            tiltY: tiltY,
            isBack: isBack,
            recipientName: recipientName,
            scholarNo: scholarNo,
            houseName: houseName,
          ),
        ),
      ),
    );
  }
}

class _AppleBadgePainter extends CustomPainter {
  final AppleFitnessBadgeData badge;
  final double gleamOffset;
  final double tiltX;
  final double tiltY;
  final bool isBack;
  final String recipientName;
  final String scholarNo;
  final String houseName;

  _AppleBadgePainter({
    required this.badge,
    required this.gleamOffset,
    required this.tiltX,
    required this.tiltY,
    required this.isBack,
    required this.recipientName,
    required this.scholarNo,
    required this.houseName,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.45;
    final isLocked = !badge.unlocked;
    final bounds = Rect.fromCircle(center: center, radius: radius);

    // 1. Drop shadow for elevation
    final shadowPaint = Paint()
      ..color = isLocked
          ? Colors.black.withValues(alpha: 0.35)
          : AppleFitnessBadge.getGlowColor(badge.metal).withValues(alpha: 0.4)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, size.width * 0.08);

    if (badge.shape == BadgeShape.shield) {
      canvas.drawPath(
        _createShapePath(BadgeShape.shield, center.translate(0, size.height * 0.04), radius * 0.95),
        shadowPaint,
      );
    } else {
      canvas.drawCircle(center.translate(0, size.height * 0.04), radius * 0.95, shadowPaint);
    }

    // 2. Build the badge path based on shape
    final path = _createShapePath(badge.shape, center, radius);

    // 3. Outer Rim (Beveled Metallic Frame)
    final rimShader = _createRimGradient(badge.metal, bounds, isLocked, tiltX, tiltY);
    final rimPaint = Paint()
      ..shader = rimShader
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, rimPaint);

    // Outer Rim Rim-highlight stroke
    final strokePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: isLocked
            ? [Colors.white24, Colors.transparent, Colors.white10]
            : [Colors.white.withValues(alpha: 0.8), Colors.transparent, Colors.white.withValues(alpha: 0.4)],
      ).createShader(bounds)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.5, size.width * 0.02);
    canvas.drawPath(path, strokePaint);

    // 4. Inner Recessed Plate (Coin / Shield Inset)
    final innerRadius = radius * 0.78;
    final innerBounds = Rect.fromCircle(center: center, radius: innerRadius);
    final innerPath = _createShapePath(badge.shape, center, innerRadius);

    // Inner shadow for chamfer depth
    final chamferPaint = Paint()
      ..color = Colors.black.withValues(alpha: isLocked ? 0.6 : 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.025;
    canvas.drawPath(innerPath, chamferPaint);

    // Inner face fill
    final faceShader = _createFaceGradient(badge.metal, innerBounds, isLocked, isBack, tiltX, tiltY);
    final facePaint = Paint()
      ..shader = faceShader
      ..style = PaintingStyle.fill;
    canvas.drawPath(innerPath, facePaint);

    // Inner grooved concentric rim / lathe track
    final groovePaint = Paint()
      ..color = isLocked ? Colors.white10 : Colors.white.withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    if (badge.shape == BadgeShape.shield) {
      canvas.drawPath(_createShapePath(BadgeShape.shield, center, innerRadius * 0.88), groovePaint);

      // Regal Center Spine Ridge for Forged Shield
      final spinePaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: isLocked ? 0.15 : 0.55),
            Colors.white.withValues(alpha: isLocked ? 0.05 : 0.2),
            Colors.black.withValues(alpha: 0.35),
          ],
        ).createShader(bounds)
        ..strokeWidth = math.max(1.2, size.width * 0.012)
        ..style = PaintingStyle.stroke;
      canvas.drawLine(
        Offset(center.dx, center.dy - innerRadius * 0.88),
        Offset(center.dx, center.dy + innerRadius * 1.05),
        spinePaint,
      );
    } else {
      canvas.drawCircle(center, innerRadius * 0.85, groovePaint);
      canvas.drawCircle(center, innerRadius * 0.68, groovePaint);
    }

    final opticalCenter = badge.shape == BadgeShape.shield
        ? Offset(center.dx, center.dy - size.height * 0.035)
        : center;

    if (isBack) {
      // BACK OF THE BADGE: House Grand Engraving
      _paintEngravedBack(canvas, size, opticalCenter, innerRadius);
    } else {
      // FRONT OF THE BADGE: 3D Emblem / Iconography
      if (isLocked) {
        _paintLockedEmblem(canvas, opticalCenter, size);
      } else {
        _paintUnlockedEmblem(canvas, opticalCenter, size);
      }

      // Specular Gleam Sweep (Dynamic animated light glint across the medal)
      if (!isLocked && gleamOffset >= 0.0 && gleamOffset <= 1.0) {
        _paintSpecularGlint(canvas, center, radius, path, bounds, gleamOffset);
      }
    }
  }

  Path _createShapePath(BadgeShape shape, Offset c, double r) {
    final path = Path();
    switch (shape) {
      case BadgeShape.circle:
        path.addOval(Rect.fromCircle(center: c, radius: r));
        break;

      case BadgeShape.hexagon:
        for (int i = 0; i < 6; i++) {
          final angle = (i * 60 - 30) * math.pi / 180;
          final x = c.dx + r * math.cos(angle);
          final y = c.dy + r * math.sin(angle);
          if (i == 0) {
            path.moveTo(x, y);
          } else {
            path.lineTo(x, y);
          }
        }
        path.close();
        break;

      case BadgeShape.octagon:
        for (int i = 0; i < 8; i++) {
          final angle = (i * 45 - 22.5) * math.pi / 180;
          final x = c.dx + r * math.cos(angle);
          final y = c.dy + r * math.sin(angle);
          if (i == 0) {
            path.moveTo(x, y);
          } else {
            path.lineTo(x, y);
          }
        }
        path.close();
        break;

      case BadgeShape.diamond:
        path.moveTo(c.dx, c.dy - r * 1.08);
        path.lineTo(c.dx + r * 0.95, c.dy);
        path.lineTo(c.dx, c.dy + r * 1.08);
        path.lineTo(c.dx - r * 0.95, c.dy);
        path.close();
        break;

      case BadgeShape.shield:
        // Majestic heraldic tournament shield with crown shoulders and tapered gothic tip
        path.moveTo(c.dx, c.dy - r * 0.96);
        path.cubicTo(c.dx + r * 0.32, c.dy - r * 0.98, c.dx + r * 0.68, c.dy - r * 0.92, c.dx + r * 0.88, c.dy - r * 0.76);
        path.cubicTo(c.dx + r * 0.96, c.dy - r * 0.35, c.dx + r * 0.90, c.dy + r * 0.18, c.dx + r * 0.60, c.dy + r * 0.68);
        path.cubicTo(c.dx + r * 0.35, c.dy + r * 0.96, c.dx + r * 0.12, c.dy + r * 1.08, c.dx, c.dy + r * 1.15);
        path.cubicTo(c.dx - r * 0.12, c.dy + r * 1.08, c.dx - r * 0.35, c.dy + r * 0.96, c.dx - r * 0.60, c.dy + r * 0.68);
        path.cubicTo(c.dx - r * 0.90, c.dy + r * 0.18, c.dx - r * 0.96, c.dy - r * 0.35, c.dx - r * 0.88, c.dy - r * 0.76);
        path.cubicTo(c.dx - r * 0.68, c.dy - r * 0.92, c.dx - r * 0.32, c.dy - r * 0.98, c.dx, c.dy - r * 0.96);
        path.close();
        break;
    }
    return path;
  }

  Shader _createRimGradient(
    MetalType metal,
    Rect bounds,
    bool isLocked,
    double tx,
    double ty,
  ) {
    if (isLocked) {
      return const SweepGradient(
        colors: [
          Color(0xFF2C3545),
          Color(0xFF141A24),
          Color(0xFF384457),
          Color(0xFF1B232E),
          Color(0xFF2C3545),
        ],
      ).createShader(bounds);
    }

    final shiftAngle = (tx * 0.5 + ty * 0.5);

    switch (metal) {
      case MetalType.gold:
      case MetalType.rubyGold:
        return SweepGradient(
          startAngle: shiftAngle,
          endAngle: shiftAngle + math.pi * 2,
          colors: const [
            Color(0xFFFFDF73),
            Color(0xFFC78F1A),
            Color(0xFFFFF4BF),
            Color(0xFF996700),
            Color(0xFFFFDF73),
          ],
        ).createShader(bounds);

      case MetalType.platinum:
      case MetalType.sapphireAstral:
        return SweepGradient(
          startAngle: shiftAngle,
          endAngle: shiftAngle + math.pi * 2,
          colors: const [
            Color(0xFFFFFFFF),
            Color(0xFF9EABB8),
            Color(0xFFE2E8F0),
            Color(0xFF6B7A8D),
            Color(0xFFFFFFFF),
          ],
        ).createShader(bounds);

      case MetalType.roseGold:
        return const SweepGradient(
          colors: [
            Color(0xFFFFD1DC),
            Color(0xFFC47D68),
            Color(0xFFFFECE6),
            Color(0xFFA65842),
            Color(0xFFFFD1DC),
          ],
        ).createShader(bounds);

      case MetalType.emeraldJade:
        return const SweepGradient(
          colors: [
            Color(0xFFE6C875),
            Color(0xFF8C6D23),
            Color(0xFFFFF0B8),
            Color(0xFF664D0F),
            Color(0xFFE6C875),
          ],
        ).createShader(bounds);

      case MetalType.topazSun:
        return const SweepGradient(
          colors: [
            Color(0xFFFFE680),
            Color(0xFFE68A00),
            Color(0xFFFFF7CC),
            Color(0xFFB35900),
            Color(0xFFFFE680),
          ],
        ).createShader(bounds);

      case MetalType.holographic:
        return const SweepGradient(
          colors: [
            Color(0xFFFF6B6B),
            Color(0xFFFFD93D),
            Color(0xFF6BCB77),
            Color(0xFF4D96FF),
            Color(0xFF9D4EDD),
            Color(0xFFFF6B6B),
          ],
        ).createShader(bounds);

      case MetalType.silver:
      case MetalType.bronze:
        return const SweepGradient(
          colors: [
            Color(0xFFE0E0E0),
            Color(0xFF757575),
            Color(0xFFF5F5F5),
            Color(0xFF616161),
            Color(0xFFE0E0E0),
          ],
        ).createShader(bounds);
    }
  }

  Shader _createFaceGradient(
    MetalType metal,
    Rect bounds,
    bool isLocked,
    bool isBack, [
    double tx = 0.0,
    double ty = 0.0,
  ]) {
    final lightCenter = Alignment(
      (-0.25 + ty * 0.55).clamp(-0.85, 0.85),
      (-0.25 - tx * 0.55).clamp(-0.85, 0.85),
    );

    if (isLocked) {
      return RadialGradient(
        center: lightCenter,
        colors: const [
          Color(0xFF1E2533),
          Color(0xFF10141D),
        ],
      ).createShader(bounds);
    }

    if (isBack) {
      // Brushed steel or warm gold engraved back
      return RadialGradient(
        center: Alignment(
          (-0.20 + ty * 0.45).clamp(-0.8, 0.8),
          (-0.20 - tx * 0.45).clamp(-0.8, 0.8),
        ),
        radius: 1.3,
        colors: const [
          Color(0xFF2A364F),
          Color(0xFF141C2A),
          Color(0xFF0C111A),
        ],
      ).createShader(bounds);
    }

    switch (metal) {
      case MetalType.rubyGold:
        return RadialGradient(
          center: lightCenter,
          radius: 1.3,
          colors: const [
            Color(0xFFFF3B56),
            Color(0xFFD31027),
            Color(0xFF66000E),
          ],
        ).createShader(bounds);

      case MetalType.sapphireAstral:
        return RadialGradient(
          center: lightCenter,
          radius: 1.3,
          colors: const [
            Color(0xFF42A5F5),
            Color(0xFF0D47A1),
            Color(0xFF061842),
          ],
        ).createShader(bounds);

      case MetalType.emeraldJade:
        return RadialGradient(
          center: lightCenter,
          radius: 1.3,
          colors: const [
            Color(0xFF4CAF50),
            Color(0xFF1B5E20),
            Color(0xFF08260B),
          ],
        ).createShader(bounds);

      case MetalType.topazSun:
        return RadialGradient(
          center: lightCenter,
          radius: 1.3,
          colors: const [
            Color(0xFFFFD54F),
            Color(0xFFFF8F00),
            Color(0xFF5E2B00),
          ],
        ).createShader(bounds);

      case MetalType.gold:
        return RadialGradient(
          center: Alignment(
            (-0.30 + ty * 0.55).clamp(-0.85, 0.85),
            (-0.30 - tx * 0.55).clamp(-0.85, 0.85),
          ),
          radius: 1.4,
          colors: const [
            Color(0xFFFFEDB3),
            Color(0xFFD49B28),
            Color(0xFF6B4700),
          ],
        ).createShader(bounds);

      case MetalType.platinum:
        return RadialGradient(
          center: lightCenter,
          radius: 1.3,
          colors: const [
            Color(0xFFFFFFFF),
            Color(0xFFB0BEC5),
            Color(0xFF37474F),
          ],
        ).createShader(bounds);

      case MetalType.roseGold:
        return RadialGradient(
          center: lightCenter,
          radius: 1.3,
          colors: const [
            Color(0xFFFFE0E6),
            Color(0xFFD88A75),
            Color(0xFF5A2A1E),
          ],
        ).createShader(bounds);

      case MetalType.holographic:
        return RadialGradient(
          center: lightCenter,
          radius: 1.0,
          colors: const [
            Color(0xFF7000FF),
            Color(0xFF00D2FF),
            Color(0xFF0A0E27),
          ],
        ).createShader(bounds);

      case MetalType.silver:
      case MetalType.bronze:
        return RadialGradient(
          center: lightCenter,
          radius: 1.0,
          colors: const [
            Color(0xFFEEEEEE),
            Color(0xFF9E9E9E),
            Color(0xFF212121),
          ],
        ).createShader(bounds);
    }
  }

  void _paintUnlockedEmblem(Canvas canvas, Offset center, Size size) {
    final iconSize = size.width * 0.32;

    // Drop shadow under icon
    final textPainterShadow = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(badge.icon.codePoint),
        style: TextStyle(
          fontSize: iconSize,
          fontFamily: badge.icon.fontFamily,
          package: badge.icon.fontPackage,
          color: Colors.black.withValues(alpha: 0.65),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainterShadow.paint(
      canvas,
      Offset(center.dx - textPainterShadow.width / 2, center.dy - textPainterShadow.height / 2 + size.width * 0.02),
    );

    // Foreground 3D Embossed Icon
    final textPainter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(badge.icon.codePoint),
        style: TextStyle(
          fontSize: iconSize,
          fontFamily: badge.icon.fontFamily,
          package: badge.icon.fontPackage,
          color: Colors.white,
          shadows: [
            Shadow(
              color: Colors.white.withValues(alpha: 0.8),
              blurRadius: 10,
              offset: const Offset(0, -1),
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(
      canvas,
      Offset(center.dx - textPainter.width / 2, center.dy - textPainter.height / 2),
    );
  }

  void _paintLockedEmblem(Canvas canvas, Offset center, Size size) {
    final iconSize = size.width * 0.28;

    // Subtle debossed lock
    final textPainter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(Icons.lock_rounded.codePoint),
        style: TextStyle(
          fontSize: iconSize,
          fontFamily: Icons.lock_rounded.fontFamily,
          package: Icons.lock_rounded.fontPackage,
          color: const Color(0xFF4A5568).withValues(alpha: 0.85),
          shadows: const [
            Shadow(
              color: Colors.black,
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(
      canvas,
      Offset(center.dx - textPainter.width / 2, center.dy - textPainter.height / 2),
    );
  }

  void _paintEngravedBack(Canvas canvas, Size size, Offset center, double innerRadius) {
    // Watermark Mascot Insignia on the back plate
    final watermarkSize = innerRadius * 0.85;
    final watermarkPainter = TextPainter(
      text: TextSpan(
        text: badge.mascotEmoji,
        style: TextStyle(
          fontSize: watermarkSize,
          color: Colors.white.withValues(alpha: 0.08),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    watermarkPainter.paint(
      canvas,
      Offset(center.dx - watermarkPainter.width / 2, center.dy - watermarkPainter.height / 2),
    );

    // Engraved Typography on the back plate
    final titlePainter = TextPainter(
      text: TextSpan(
        text: badge.title.toUpperCase(),
        style: TextStyle(
          color: Colors.amber.shade200,
          fontWeight: FontWeight.w900,
          fontSize: (size.width * 0.052).clamp(10.0, 15.0),
          letterSpacing: 0.8,
          shadows: [
            Shadow(
              color: Colors.black.withValues(alpha: 0.9),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: innerRadius * 1.6);

    titlePainter.paint(
      canvas,
      Offset(center.dx - titlePainter.width / 2, center.dy - innerRadius * 0.65),
    );

    // Thin etched divider
    final dividerPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.22)
      ..strokeWidth = 1.0;
    canvas.drawLine(
      Offset(center.dx - innerRadius * 0.45, center.dy - innerRadius * 0.35),
      Offset(center.dx + innerRadius * 0.45, center.dy - innerRadius * 0.35),
      dividerPaint,
    );

    // Conferred details
    final bodySpan = TextSpan(
      style: TextStyle(
        color: Colors.white70,
        height: 1.35,
        fontWeight: FontWeight.w600,
      ),
      children: [
        TextSpan(
          text: 'CONFERRED UPON\n',
          style: TextStyle(
            color: Colors.grey.shade400,
            fontSize: (size.width * 0.038).clamp(8.0, 11.0),
            letterSpacing: 0.6,
          ),
        ),
        TextSpan(
          text: '$recipientName\n',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: (size.width * 0.052).clamp(11.0, 15.0),
            letterSpacing: 0.3,
            shadows: [
              Shadow(
                color: Colors.black.withValues(alpha: 0.8),
                blurRadius: 2,
                offset: const Offset(0, 1),
              ),
            ],
          ),
        ),
        TextSpan(
          text: '${houseName.toUpperCase()} HOUSE • #$scholarNo\n',
          style: TextStyle(
            color: Colors.amber.shade300,
            fontSize: (size.width * 0.040).clamp(8.5, 12.0),
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
        TextSpan(
          text: '${badge.earnedDate}\n',
          style: TextStyle(
            color: Colors.grey.shade400,
            fontSize: (size.width * 0.036).clamp(8.0, 11.0),
          ),
        ),
        TextSpan(
          text: '+${badge.meritPoints} MERITS',
          style: TextStyle(
            color: Colors.greenAccent,
            fontWeight: FontWeight.w900,
            fontSize: (size.width * 0.048).clamp(10.0, 14.0),
            letterSpacing: 0.8,
            shadows: [
              Shadow(
                color: Colors.green.withValues(alpha: 0.5),
                blurRadius: 4,
                offset: const Offset(0, 0),
              ),
            ],
          ),
        ),
      ],
    );

    final bodyPainter = TextPainter(
      text: bodySpan,
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: innerRadius * 1.6);

    bodyPainter.paint(
      canvas,
      Offset(center.dx - bodyPainter.width / 2, center.dy - innerRadius * 0.28),
    );
  }

  void _paintSpecularGlint(Canvas canvas, Offset center, double radius, Path clipPath, Rect bounds, double progress) {
    if (progress < 0.0 || progress > 1.0) return;

    canvas.save();
    canvas.clipPath(clipPath);

    // Full off-screen to off-screen sweep range:
    // At 0.0, the rightmost gradient stop is safely off to the left.
    // At 1.0, the leftmost gradient stop is safely off to the right.
    final sweepX = -2.6 + (progress * 5.2);
    final glintPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment(sweepX - 0.75, -1.5),
        end: Alignment(sweepX + 0.75, 1.5),
        colors: [
          Colors.transparent,
          Colors.white.withValues(alpha: 0.12), // Leading whisper glint
          Colors.transparent,
          Colors.white.withValues(alpha: 0.08), // Primary beam outer glow
          Colors.white.withValues(alpha: 0.38), // Primary beam shoulder
          Colors.white.withValues(alpha: 0.82), // Intense specular white core
          Colors.white.withValues(alpha: 0.38), // Primary beam shoulder
          Colors.white.withValues(alpha: 0.08), // Primary beam outer glow
          Colors.transparent,
        ],
        stops: const [
          0.0,
          0.12,
          0.22,
          0.34,
          0.47,
          0.50,
          0.53,
          0.66,
          1.0,
        ],
      ).createShader(bounds)
      ..blendMode = BlendMode.screen;

    canvas.drawRect(bounds.inflate(radius * 0.3), glintPaint);

    // Specular micro-sparkle (lens flare) at the high-relief apex during sweep midpoint
    if (progress >= 0.42 && progress <= 0.58) {
      final intensity = 1.0 - ((progress - 0.50).abs() / 0.08);
      final curvedIntensity = Curves.easeOutCubic.transform(intensity.clamp(0.0, 1.0));
      final apexPoint = Offset(center.dx, center.dy - radius * 0.45);
      _paintApexSparkle(canvas, apexPoint, radius, curvedIntensity);
    }

    canvas.restore();
  }

  void _paintApexSparkle(Canvas canvas, Offset flarePoint, double radius, double intensity) {
    if (intensity <= 0.01) return;

    // 1. Soft radial bloom behind sparkle
    final bloomPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white.withValues(alpha: 0.55 * intensity),
          Colors.white.withValues(alpha: 0.18 * intensity),
          Colors.transparent,
        ],
        stops: const [0.0, 0.45, 1.0],
      ).createShader(Rect.fromCircle(center: flarePoint, radius: radius * 0.35))
      ..blendMode = BlendMode.screen;
    canvas.drawCircle(flarePoint, radius * 0.35, bloomPaint);

    // 2. Crisp 4-pointed micro-star (horizontal and vertical diamond rays)
    final starPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.85 * intensity)
      ..style = PaintingStyle.fill
      ..blendMode = BlendMode.screen;

    final hLen = radius * 0.32 * intensity;
    final vLen = radius * 0.42 * intensity;
    final thickness = math.max(1.0, radius * 0.035 * intensity);

    final starPath = Path()
      ..moveTo(flarePoint.dx, flarePoint.dy - vLen)
      ..lineTo(flarePoint.dx + thickness, flarePoint.dy - thickness)
      ..lineTo(flarePoint.dx + hLen, flarePoint.dy)
      ..lineTo(flarePoint.dx + thickness, flarePoint.dy + thickness)
      ..lineTo(flarePoint.dx, flarePoint.dy + vLen)
      ..lineTo(flarePoint.dx - thickness, flarePoint.dy + thickness)
      ..lineTo(flarePoint.dx - hLen, flarePoint.dy)
      ..lineTo(flarePoint.dx - thickness, flarePoint.dy - thickness)
      ..close();

    canvas.drawPath(starPath, starPaint);

    // 3. Hot diamond center pin
    final centerPin = Paint()
      ..color = Colors.white.withValues(alpha: 0.95 * intensity)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(flarePoint, math.max(1.2, radius * 0.03 * intensity), centerPin);
  }



  @override
  bool shouldRepaint(covariant _AppleBadgePainter oldDelegate) {
    return oldDelegate.gleamOffset != gleamOffset ||
        oldDelegate.tiltX != tiltX ||
        oldDelegate.tiltY != tiltY ||
        oldDelegate.isBack != isBack ||
        oldDelegate.badge.unlocked != badge.unlocked ||
        oldDelegate.badge.progress != badge.progress ||
        oldDelegate.badge.title != badge.title ||
        oldDelegate.recipientName != recipientName ||
        oldDelegate.scholarNo != scholarNo ||
        oldDelegate.houseName != houseName;
  }
}
