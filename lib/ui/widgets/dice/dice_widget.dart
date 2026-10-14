import 'dart:math';
import 'package:flutter/material.dart';
import 'package:duo_ludo/audio/sound_manager.dart';
import 'package:duo_ludo/engine/ludo_models.dart';

/// Animated 3D dice widget with realistic roll rotation and pip faces.
class DiceWidget extends StatefulWidget {
  final int? value;
  final bool canRoll;
  final PlayerColor turnColor;
  final VoidCallback? onRoll;
  final double size;

  const DiceWidget({
    super.key,
    required this.value,
    required this.canRoll,
    required this.turnColor,
    this.onRoll,
    this.size = 64.0,
  });

  @override
  State<DiceWidget> createState() => _DiceWidgetState();
}

class _DiceWidgetState extends State<DiceWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _rollAnimController;
  int _displayValue = 1;

  @override
  void initState() {
    super.initState();
    _displayValue = widget.value ?? 1;
    _rollAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _rollAnimController.addListener(() {
      if (_rollAnimController.isAnimating) {
        // Fast pip flicker during rolling animation
        setState(() {
          _displayValue = Random().nextInt(6) + 1;
        });
      }
    });

    _rollAnimController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _displayValue = widget.value ?? _displayValue;
        });
      }
    });
  }

  @override
  void didUpdateWidget(DiceWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value && widget.value != null) {
      _displayValue = widget.value!;
    }
  }

  @override
  void dispose() {
    _rollAnimController.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (!widget.canRoll || _rollAnimController.isAnimating) return;

    SoundManager().playDiceRoll();
    _rollAnimController.forward(from: 0.0).then((_) {
      SoundManager().playDiceLand();
      if (widget.onRoll != null) {
        widget.onRoll!();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final playerColor = widget.turnColor.primaryColor;

    return GestureDetector(
      onTap: widget.canRoll ? _handleTap : null,
      child: AnimatedBuilder(
        animation: _rollAnimController,
        builder: (context, child) {
          final isRolling = _rollAnimController.isAnimating;
          final angle = isRolling ? _rollAnimController.value * 4 * pi : 0.0;
          final scale = isRolling
              ? 1.0 + (sin(_rollAnimController.value * pi) * 0.25)
              : 1.0;

          return Transform.scale(
            scale: scale,
            child: Transform.rotate(
              angle: angle,
              child: Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    // Glow if ready to roll
                    if (widget.canRoll)
                      BoxShadow(
                        color: playerColor.withOpacity(0.7),
                        blurRadius: 16,
                        spreadRadius: 4,
                      ),
                    BoxShadow(
                      color: Colors.black.withOpacity(0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFFFFF), Color(0xFFE2E8F0)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(
                    color: widget.canRoll
                        ? playerColor
                        : Colors.white.withOpacity(0.8),
                    width: widget.canRoll ? 3 : 2,
                  ),
                ),
                child: Center(
                  child: _buildDiceFace(
                    _displayValue,
                    widget.size,
                    playerColor,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDiceFace(int val, double size, Color dotColor) {
    final pipSize = size * 0.18;

    Widget pip() => Container(
          width: pipSize,
          height: pipSize,
          decoration: BoxDecoration(
            color: dotColor,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: dotColor.withOpacity(0.5),
                blurRadius: 2,
              ),
            ],
          ),
        );

    switch (val) {
      case 1:
        return Center(
          child: Container(
            width: pipSize * 1.4,
            height: pipSize * 1.4,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
            ),
          ),
        );
      case 2:
        return Padding(
          padding: EdgeInsets.all(size * 0.16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(mainAxisAlignment: MainAxisAlignment.start, children: [pip()]),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [pip()]),
            ],
          ),
        );
      case 3:
        return Padding(
          padding: EdgeInsets.all(size * 0.16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(mainAxisAlignment: MainAxisAlignment.start, children: [pip()]),
              Center(child: pip()),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [pip()]),
            ],
          ),
        );
      case 4:
        return Padding(
          padding: EdgeInsets.all(size * 0.16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [pip(), pip()],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [pip(), pip()],
              ),
            ],
          ),
        );
      case 5:
        return Padding(
          padding: EdgeInsets.all(size * 0.16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [pip(), pip()],
              ),
              Center(child: pip()),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [pip(), pip()],
              ),
            ],
          ),
        );
      case 6:
      default:
        return Padding(
          padding: EdgeInsets.all(size * 0.16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [pip(), pip()],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [pip(), pip()],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [pip(), pip()],
              ),
            ],
          ),
        );
    }
  }
}
