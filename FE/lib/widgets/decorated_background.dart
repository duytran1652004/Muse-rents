import 'package:flutter/material.dart';

import '../theme/rents_colors.dart';

class DecoratedBackground extends StatelessWidget {
  const DecoratedBackground({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        gradient: RentsColors.appBackgroundGradient,
      ),
      child: Stack(
        children: [
          const Positioned(
            top: -90,
            right: -50,
            child: _GlowBubble(
              size: 220,
              color: RentsColors.primaryBlueLight,
              opacity: 0.16,
            ),
          ),
          const Positioned(
            top: 140,
            left: -70,
            child: _GlowBubble(
              size: 180,
              color: RentsColors.primaryBlue,
              opacity: 0.08,
            ),
          ),
          Positioned(
            bottom: -110,
            right: -40,
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(120),
                gradient: RadialGradient(
                  colors: [
                    RentsColors.white.withValues(alpha: 0.7),
                    RentsColors.primaryBlueLight.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: padding,
            child: child,
          ),
        ],
      ),
    );
  }
}

class _GlowBubble extends StatelessWidget {
  const _GlowBubble({
    required this.size,
    required this.color,
    required this.opacity,
  });

  final double size;
  final Color color;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color.withValues(alpha: opacity),
            color.withValues(alpha: 0),
          ],
        ),
      ),
    );
  }
}
