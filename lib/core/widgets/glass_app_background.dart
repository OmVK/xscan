import 'package:flutter/material.dart';

/// Atmospheric Glassmorphic Background with central XSCAN Brand Wallpaper.
/// Provides a sleek executive backdrop for frosted glass elements.
class GlassAppBackground extends StatelessWidget {
  final Widget child;

  const GlassAppBackground({
    super.key,
    required this.child,
    bool showLogoWallpaper = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final baseBg = isDark
        ? const Color(0xFF090C15) // Deep executive slate
        : const Color(0xFFF2F5FA);

    return Stack(
      children: [
        // Base Dark Canvas
        Positioned.fill(
          child: Container(color: baseBg),
        ),

        // Central XSCAN Logo Wallpaper Image
        Positioned.fill(
          child: Opacity(
            opacity: isDark ? 0.35 : 0.20,
            child: Image.asset(
              'assets/xscan_wallpaper.png',
              fit: BoxFit.cover,
              alignment: Alignment.center,
              errorBuilder: (_, _, _) => Container(color: baseBg),
            ),
          ),
        ),

        // Subtle Ambient Mesh Glows (Enhances frosted glass refraction around screen edges)
        Positioned(
          top: -100,
          left: -80,
          child: Container(
            width: 340,
            height: 340,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFF00E5FF).withValues(alpha: isDark ? 0.18 : 0.10),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        Positioned(
          bottom: -100,
          right: -80,
          child: Container(
            width: 360,
            height: 360,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFF7C4DFF).withValues(alpha: isDark ? 0.20 : 0.12),
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
