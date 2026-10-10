import 'dart:math';
import 'package:flutter/material.dart';

class ConfettiOverlay extends StatefulWidget {
  final Widget child;
  final bool show;

  const ConfettiOverlay({super.key, required this.child, required this.show});

  @override
  State<ConfettiOverlay> createState() => _ConfettiOverlayState();
}

class _ConfettiOverlayState extends State<ConfettiOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<ConfettiParticle> _particles = [];
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );
    // Use addListener only to update particle positions — no setState needed;
    // AnimatedBuilder will rebuild only the canvas layer.
    _controller.addListener(_updateParticles);

    if (widget.show) {
      _startConfetti();
    }
  }

  void _updateParticles() {
    for (var p in _particles) {
      p.update();
    }
  }

  @override
  void didUpdateWidget(ConfettiOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.show && !oldWidget.show) {
      _startConfetti();
    } else if (!widget.show && oldWidget.show) {
      _controller.stop();
      _particles.clear();
    }
  }

  void _startConfetti() {
    _particles.clear();
    final colors = [
      const Color(0xFFDC2626), // Ruby
      const Color(0xFF2563EB), // Sapphire
      const Color(0xFF059669), // Emerald
      const Color(0xFFB45309), // Topaz (WCAG AA compliant)
      Colors.amber,
      Colors.purpleAccent,
      Colors.pinkAccent,
    ];

    for (int i = 0; i < 70; i++) {
      _particles.add(
        ConfettiParticle(
          x: _random.nextDouble(),
          y: -0.1 - _random.nextDouble() * 0.5,
          vx: (_random.nextDouble() - 0.5) * 0.015,
          vy: 0.008 + _random.nextDouble() * 0.015,
          size: 8 + _random.nextDouble() * 8,
          color: colors[_random.nextInt(colors.length)],
          rotation: _random.nextDouble() * pi * 2,
          vRotation: (_random.nextDouble() - 0.5) * 0.2,
        ),
      );
    }

    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.removeListener(_updateParticles);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        // AnimatedBuilder rebuilds only the RepaintBoundary+CustomPaint layer
        // on each animation frame — no parent setState, no full tree rebuild.
        AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            if (!_controller.isAnimating && _particles.isEmpty) {
              return const SizedBox.shrink();
            }
            return ExcludeSemantics(
              child: IgnorePointer(
                child: RepaintBoundary(
                  child: CustomPaint(
                    size: Size.infinite,
                    painter: _ConfettiPainter(_particles),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class ConfettiParticle {
  static final Random _rng = Random();
  double x;
  double y;
  double vx;
  double vy;
  double size;
  Color color;
  double rotation;
  double vRotation;

  ConfettiParticle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.size,
    required this.color,
    required this.rotation,
    required this.vRotation,
  });

  void update() {
    x += vx;
    y += vy;
    rotation += vRotation;
    // flutter side-to-side
    vx += (_rng.nextDouble() - 0.5) * 0.002;
  }
}

class _ConfettiPainter extends CustomPainter {
  final List<ConfettiParticle> particles;

  _ConfettiPainter(this.particles);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    for (var p in particles) {
      if (p.y > 1.2 || p.x < -0.2 || p.x > 1.2) continue;

      final px = p.x * size.width;
      final py = p.y * size.height;

      canvas.save();
      canvas.translate(px, py);
      canvas.rotate(p.rotation);

      paint.color = p.color;
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset.zero,
          width: p.size,
          height: p.size * 0.6,
        ),
        paint,
      );

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
