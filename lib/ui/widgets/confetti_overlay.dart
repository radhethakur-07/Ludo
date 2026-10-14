import 'dart:math';
import 'package:flutter/material.dart';

/// Lightweight animated confetti celebration overlay.
class ConfettiOverlay extends StatefulWidget {
  final Widget child;
  final bool isPlaying;

  const ConfettiOverlay({
    super.key,
    required this.child,
    this.isPlaying = false,
  });

  @override
  State<ConfettiOverlay> createState() => _ConfettiOverlayState();
}

class _ConfettiOverlayState extends State<ConfettiOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<_ConfettiParticle> _particles = [];
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );

    _initParticles();

    if (widget.isPlaying) {
      _controller.repeat();
    }
  }

  void _initParticles() {
    _particles.clear();
    const colors = [
      Color(0xFFE53935), // Red
      Color(0xFF1E8E3E), // Green
      Color(0xFFF9A825), // Yellow
      Color(0xFF1976D2), // Blue
      Color(0xFFFF4081), // Pink
      Color(0xFF7C4DFF), // Purple
      Color(0xFFFFD700), // Gold
    ];

    for (int i = 0; i < 65; i++) {
      _particles.add(
        _ConfettiParticle(
          x: _random.nextDouble(),
          y: -_random.nextDouble() * 0.5,
          speed: 0.15 + _random.nextDouble() * 0.35,
          angle: _random.nextDouble() * 2 * pi,
          rotationSpeed: (_random.nextDouble() - 0.5) * 6,
          size: 6.0 + _random.nextDouble() * 6.0,
          color: colors[_random.nextInt(colors.length)],
        ),
      );
    }
  }

  @override
  void didUpdateWidget(ConfettiOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying && !_controller.isAnimating) {
      _initParticles();
      _controller.repeat();
    } else if (!widget.isPlaying && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (widget.isPlaying)
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  return CustomPaint(
                    painter: _ConfettiPainter(
                      particles: _particles,
                      progress: _controller.value,
                    ),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }
}

class _ConfettiParticle {
  double x;
  double y;
  final double speed;
  double angle;
  final double rotationSpeed;
  final double size;
  final Color color;

  _ConfettiParticle({
    required this.x,
    required this.y,
    required this.speed,
    required this.angle,
    required this.rotationSpeed,
    required this.size,
    required this.color,
  });
}

class _ConfettiPainter extends CustomPainter {
  final List<_ConfettiParticle> particles;
  final double progress;

  _ConfettiPainter({
    required this.particles,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final currentY = ((p.y + progress * p.speed * 2.5) % 1.2) * size.height;
      final currentX = (p.x * size.width) + sin(progress * 4 * pi + p.angle) * 18;
      final rotation = p.angle + progress * p.rotationSpeed * pi;

      canvas.save();
      canvas.translate(currentX, currentY);
      canvas.rotate(rotation);

      final paint = Paint()
        ..color = p.color
        ..style = PaintingStyle.fill;

      // Draw ribbon rectangle
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset.zero,
            width: p.size * 1.5,
            height: p.size * 0.75,
          ),
          const Radius.circular(2),
        ),
        paint,
      );

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) => true;
}
