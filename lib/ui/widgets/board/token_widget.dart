import 'package:flutter/material.dart';
import 'package:duo_ludo/engine/ludo_models.dart';
import 'package:duo_ludo/ui/theme/app_theme.dart';

/// Animated 3D-styled token piece with pulsing halo for legal moves.
class TokenWidget extends StatefulWidget {
  final LudoToken token;
  final double size;
  final bool isInteractive;
  final VoidCallback? onTap;

  const TokenWidget({
    super.key,
    required this.token,
    required this.size,
    this.isInteractive = false,
    this.onTap,
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
      duration: const Duration(milliseconds: 900),
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
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
    final isRed = widget.token.owner == PlayerColor.red;
    final primaryColor = isRed ? AppTheme.redPrimary : AppTheme.greenPrimary;
    final secondaryColor =
        isRed ? AppTheme.redSecondary : AppTheme.greenSecondary;
    final lightColor = isRed ? AppTheme.redLight : AppTheme.greenLight;

    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final scale = widget.isInteractive ? _scaleAnimation.value : 1.0;

        return Transform.scale(
          scale: scale,
          child: GestureDetector(
            onTap: widget.isInteractive ? widget.onTap : null,
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  // Outer Glow if legal move
                  if (widget.isInteractive)
                    BoxShadow(
                      color: AppTheme.gold.withOpacity(0.8),
                      blurRadius: 10,
                      spreadRadius: 3,
                    ),
                  // Drop shadow for 3D piece depth
                  BoxShadow(
                    color: Colors.black.withOpacity(0.45),
                    blurRadius: 4,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Outer border ring
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: widget.isInteractive
                            ? AppTheme.gold
                            : Colors.white.withOpacity(0.9),
                        width: widget.isInteractive ? 2.5 : 1.8,
                      ),
                      gradient: RadialGradient(
                        center: const Alignment(-0.3, -0.4),
                        radius: 0.9,
                        colors: [
                          lightColor,
                          primaryColor,
                          secondaryColor,
                        ],
                      ),
                    ),
                  ),
                  // Inner glossy dome
                  Container(
                    width: widget.size * 0.55,
                    height: widget.size * 0.55,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.25),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.4),
                        width: 1,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        '${widget.token.id + 1}',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: widget.size * 0.32,
                          fontWeight: FontWeight.bold,
                          shadows: const [
                            Shadow(
                              color: Colors.black45,
                              blurRadius: 2,
                              offset: Offset(0, 1),
                            ),
                          ],
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
