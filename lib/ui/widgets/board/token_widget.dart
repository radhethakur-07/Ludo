import 'package:flutter/material.dart';
import 'package:duo_ludo/engine/ludo_models.dart';
import 'package:duo_ludo/ui/theme/app_theme.dart';

/// 3D polished Ludo pawn/token with glossy specular shine, dimensional drop shadow,
/// colored metallic rim, and pulsating halo for legal moves.
class TokenWidget extends StatefulWidget {
  final LudoToken token;
  final double size;
  final bool isInteractive;
  final VoidCallback? onTap;
  final bool isMoving;

  const TokenWidget({
    super.key,
    required this.token,
    required this.size,
    this.isInteractive = false,
    this.onTap,
    this.isMoving = false,
  });

  @override
  State<TokenWidget> createState() => _TokenWidgetState();
}

class _TokenWidgetState extends State<TokenWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.18).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    if (widget.isInteractive) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(TokenWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isInteractive && !_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
    } else if (!widget.isInteractive && _pulseController.isAnimating) {
      _pulseController.stop();
      _pulseController.value = 0.0;
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.token.owner;
    final primaryColor = color.primaryColor;
    final lightColor = color.lightColor;
    final darkColor = color.darkColor;

    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final scale = widget.isInteractive
            ? _scaleAnimation.value
            : (widget.isMoving ? 1.25 : 1.0);

        return Transform.scale(
          scale: scale,
          child: GestureDetector(
            onTap: widget.isInteractive ? widget.onTap : null,
            child: SizedBox(
              width: widget.size,
              height: widget.size * 1.12, // slightly taller for 3D pawn depth
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  // 1. Drop Shadow underneath
                  Positioned(
                    bottom: 0,
                    child: Container(
                      width: widget.size * 0.85,
                      height: widget.size * 0.35,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.45),
                            blurRadius: widget.isMoving ? 8 : 4,
                            spreadRadius: widget.isMoving ? 1 : 0,
                            offset: Offset(0, widget.isMoving ? 6 : 2),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 2. Pulsing Glow Aura if legal move
                  if (widget.isInteractive)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.gold.withOpacity(0.85),
                              blurRadius: 14,
                              spreadRadius: 3,
                            ),
                          ],
                        ),
                      ),
                    ),

                  // 3. 3D Pawn Piece Body
                  Positioned(
                    top: widget.isMoving ? -4 : 0,
                    child: CustomPaint(
                      size: Size(widget.size, widget.size),
                      painter: _TokenPawnPainter(
                        primaryColor: primaryColor,
                        lightColor: lightColor,
                        darkColor: darkColor,
                        isInteractive: widget.isInteractive,
                      ),
                      child: Container(
                        width: widget.size,
                        height: widget.size,
                        alignment: Alignment.center,
                        child: Text(
                          '${widget.token.id + 1}',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: widget.size * 0.34,
                            fontWeight: FontWeight.w900,
                            shadows: const [
                              Shadow(
                                color: Colors.black54,
                                blurRadius: 3,
                                offset: Offset(0, 1),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Custom painter for the glossy 3D pawn token matching the reference image.
class _TokenPawnPainter extends CustomPainter {
  final Color primaryColor;
  final Color lightColor;
  final Color darkColor;
  final bool isInteractive;

  _TokenPawnPainter({
    required this.primaryColor,
    required this.lightColor,
    required this.darkColor,
    required this.isInteractive,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 1.5;

    // 1. Outer Metallic Rim
    final rimPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white,
          isInteractive ? const Color(0xFFFFD700) : const Color(0xFFCFD8DC),
          darkColor,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, rimPaint);

    // 2. Inner Colored Spherical Dome
    final domeRadius = radius * 0.85;
    final domePaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.35, -0.4),
        radius: 0.9,
        colors: [
          lightColor,
          primaryColor,
          darkColor,
        ],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: domeRadius));
    canvas.drawCircle(center, domeRadius, domePaint);

    // 3. Specular Gloss Reflection Arc (Top-Left Highlight)
    final highlightPaint = Paint()
      ..color = Colors.white.withOpacity(0.65)
      ..style = PaintingStyle.fill;
    final highlightPath = Path()
      ..addOval(
        Rect.fromCenter(
          center: Offset(center.dx - domeRadius * 0.28, center.dy - domeRadius * 0.35),
          width: domeRadius * 0.55,
          height: domeRadius * 0.28,
        ),
      );
    canvas.drawPath(highlightPath, highlightPaint);
  }

  @override
  bool shouldRepaint(covariant _TokenPawnPainter oldDelegate) =>
      oldDelegate.primaryColor != primaryColor ||
      oldDelegate.isInteractive != isInteractive;
}
