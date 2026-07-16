import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;

/// Renders the XScan launcher icon to PNGs (headless, no Flutter engine).
///   dart run tool/generate_icon.dart
void main() {
  const size = 1024;
  final image = img.Image(width: size, height: size, numChannels: 4);

  // --- Gradient background (indigo -> electric purple, diagonal) ---
  const c1 = [0x6C, 0x63, 0xFF];
  const c2 = [0x8A, 0x2B, 0xE2];
  for (var y = 0; y < size; y++) {
    for (var x = 0; x < size; x++) {
      final t = (x + y) / (2 * size);
      final r = (c1[0] + (c2[0] - c1[0]) * t).round();
      final g = (c1[1] + (c2[1] - c1[1]) * t).round();
      final b = (c1[2] + (c2[2] - c1[2]) * t).round();
      image.setPixelRgba(x, y, r, g, b, 255);
    }
  }

  // --- Rounded-corner mask (squircle-ish) ---
  const radius = 232;
  _applyRoundedMask(image, size, radius);

  final white = img.ColorRgba8(255, 255, 255, 235);
  final whiteX = img.ColorRgba8(255, 255, 255, 255);
  final teal = img.ColorRgba8(0x00, 0xE5, 0xFF, 255);

  // --- Scanner viewfinder brackets ---
  const inset = 232;
  const arm = 118;
  const th = 44;
  final maxc = size - inset;
  // top-left
  _thickLine(image, inset, inset, inset + arm, inset, th, white);
  _thickLine(image, inset, inset, inset, inset + arm, th, white);
  // top-right
  _thickLine(image, maxc - arm, inset, maxc, inset, th, white);
  _thickLine(image, maxc, inset, maxc, inset + arm, th, white);
  // bottom-right
  _thickLine(image, maxc - arm, maxc, maxc, maxc, th, white);
  _thickLine(image, maxc, maxc - arm, maxc, maxc, th, white);
  // bottom-left
  _thickLine(image, inset, maxc, inset + arm, maxc, th, white);
  _thickLine(image, inset, maxc - arm, inset, maxc, th, white);

  // --- Bold X ---
  _thickLine(image, 396, 396, 628, 628, 86, whiteX);
  _thickLine(image, 628, 396, 396, 628, 86, whiteX);

  // --- Neon scan line with soft glow ---
  for (var y = 496; y <= 528; y++) {
    for (var x = 250; x <= 774; x++) {
      final edge = math.min((x - 250), (774 - x)) / 180.0;
      final vfade = 1.0 - (((y - 512).abs()) / 18.0);
      final a = (edge.clamp(0.0, 1.0) * vfade.clamp(0.0, 1.0) * 255).round();
      if (a <= 0) continue;
      _blend(image, x, y, teal, a);
    }
  }

  Directory('assets').createSync(recursive: true);
  File('assets/icon.png').writeAsBytesSync(img.encodePng(image));

  // Foreground for adaptive icon (transparent bg, centered art at ~66%).
  final fg = img.Image(width: size, height: size, numChannels: 4);
  final scaled = img.copyResize(image, width: (size * 0.66).round());
  final offset = ((size - scaled.width) / 2).round();
  img.compositeImage(fg, scaled, dstX: offset, dstY: offset);
  File('assets/icon_foreground.png').writeAsBytesSync(img.encodePng(fg));

  stdout.writeln('Wrote assets/icon.png and assets/icon_foreground.png');
}

void _applyRoundedMask(img.Image image, int size, int radius) {
  for (var y = 0; y < size; y++) {
    for (var x = 0; x < size; x++) {
      var cx = -1, cy = -1;
      if (x < radius && y < radius) {
        cx = radius;
        cy = radius;
      } else if (x >= size - radius && y < radius) {
        cx = size - radius;
        cy = radius;
      } else if (x < radius && y >= size - radius) {
        cx = radius;
        cy = size - radius;
      } else if (x >= size - radius && y >= size - radius) {
        cx = size - radius;
        cy = size - radius;
      }
      if (cx < 0) continue;
      final d = math.sqrt(math.pow(x - cx, 2) + math.pow(y - cy, 2));
      if (d > radius) {
        image.setPixelRgba(x, y, 0, 0, 0, 0);
      } else if (d > radius - 1.5) {
        final p = image.getPixel(x, y);
        _setAlpha(image, x, y, p, ((radius - d) / 1.5 * 255).round());
      }
    }
  }
}

void _setAlpha(img.Image image, int x, int y, img.Pixel p, int a) {
  image.setPixelRgba(x, y, p.r.toInt(), p.g.toInt(), p.b.toInt(), a.clamp(0, 255));
}

/// Draws a rounded, anti-aliased thick line segment.
void _thickLine(
    img.Image image, int x1, int y1, int x2, int y2, int thickness, img.Color color) {
  final half = thickness / 2;
  final minX = math.max(0, math.min(x1, x2) - thickness);
  final maxX = math.min(image.width - 1, math.max(x1, x2) + thickness);
  final minY = math.max(0, math.min(y1, y2) - thickness);
  final maxY = math.min(image.height - 1, math.max(y1, y2) + thickness);
  final dx = (x2 - x1).toDouble();
  final dy = (y2 - y1).toDouble();
  final lenSq = dx * dx + dy * dy;

  for (var y = minY; y <= maxY; y++) {
    for (var x = minX; x <= maxX; x++) {
      double t = lenSq == 0 ? 0 : (((x - x1) * dx + (y - y1) * dy) / lenSq);
      t = t.clamp(0.0, 1.0);
      final px = x1 + t * dx;
      final py = y1 + t * dy;
      final dist = math.sqrt(math.pow(x - px, 2) + math.pow(y - py, 2));
      if (dist <= half - 1) {
        _blend(image, x, y, color, color.a.toInt());
      } else if (dist <= half) {
        final a = ((half - dist) * color.a).round();
        _blend(image, x, y, color, a);
      }
    }
  }
}

void _blend(img.Image image, int x, int y, img.Color src, int alpha) {
  if (alpha <= 0) return;
  final dst = image.getPixel(x, y);
  final a = alpha / 255.0;
  final r = (src.r * a + dst.r * (1 - a)).round();
  final g = (src.g * a + dst.g * (1 - a)).round();
  final b = (src.b * a + dst.b * (1 - a)).round();
  final da = math.max(dst.a.toInt(), alpha);
  image.setPixelRgba(x, y, r, g, b, da);
}
