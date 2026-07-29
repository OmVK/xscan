import 'package:flutter/material.dart';

/// Atmospheric Executive Aurora Mesh Background for XScan.
/// Features floating organic gradient mesh orbs behind frosted glass panels,
/// replacing static image overlays for an authentic, premium aesthetic.
class GlassAppBackground extends StatelessWidget {
  final Widget child;
  final bool showLogoWallpaper;

  const GlassAppBackground({
    super.key,
    required this.child,
    this.showLogoWallpaper = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final baseBg = isDark
        ? const Color(0xFF0B0F19) // Deep Executive Obsidian Slate
        : const Color(0xFFF4F7FB); // Crisp Porcelain

    return Stack(
      children: [
        // Base Canvas
        Positioned.fill(
          child: Container(color: baseBg),
        ),

        // Aurora Mesh Glow 1: Top-Left Cyan/Teal Flare
        Positioned(
          top: -120,
          left: -100,
          child: Container(
            width: 420,
            height: 420,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFF00E5FF).withValues(alpha: isDark ? 0.22 : 0.14),
                  const Color(0xFF00B894).withValues(alpha: isDark ? 0.08 : 0.04),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
          ),
        ),

        // Aurora Mesh Glow 2: Top-Right Deep Sapphire
        Positioned(
          top: -60,
          right: -120,
          child: Container(
            width: 380,
            height: 380,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFF2979FF).withValues(alpha: isDark ? 0.18 : 0.10),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),

        // Aurora Mesh Glow 3: Bottom-Right Electric Violet
        Positioned(
          bottom: -130,
          right: -90,
          child: Container(
            width: 450,
            height: 450,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFF7C4DFF).withValues(alpha: isDark ? 0.24 : 0.15),
                  const Color(0xFF651FFF).withValues(alpha: isDark ? 0.10 : 0.05),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.4, 1.0],
              ),
            ),
          ),
        ),

        // Aurora Mesh Glow 4: Center-Left Amber Glow Accent
        Positioned(
          top: MediaQuery.of(context).size.height * 0.45,
          left: -140,
          child: Container(
            width: 320,
            height: 320,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFFFF9100).withValues(alpha: isDark ? 0.09 : 0.05),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),

        // Foreground Content Page
        Positioned.fill(child: child),
      ],
    );
  }
}
