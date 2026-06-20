import 'dart:io';
import 'dart:math' as math;
import 'package:image/image.dart' as img;

void main() {
  const size = 1024;
  final output = File('assets/icon.png');

  final image = img.Image(width: size, height: size);

  // Fill with transparent background
  img.fill(image, color: img.ColorRgba8(0, 0, 0, 0));

  // Rounded square background in indigo
  final bgColor = img.ColorRgba8(99, 102, 241, 255);
  _drawRoundedRect(image, 0, 0, size, size, 180, bgColor);

  // Draw shadow/glow effect
  final glowColor = img.ColorRgba8(99, 102, 241, 60);
  _drawRoundedRect(image, 20, 20, size - 40, size - 40, 160, glowColor);

  // Document body (white)
  final docWhite = img.ColorRgba8(255, 255, 255, 255);
  final docGray = img.ColorRgba8(240, 240, 245, 255);

  // Document - main body
  final docLeft = 280;
  final docTop = 360;
  final docW = 464;
  final docH = 520;
  final docRadius = 40;

  // Draw document body
  _drawRoundedRect(image, docLeft, docTop, docW, docH, docRadius, docWhite);

  // Document fold corner (top-right triangle)
  final foldSize = 120;
  final foldPoints = [
    (docLeft + docW - foldSize, docTop),
    (docLeft + docW, docTop + foldSize),
    (docLeft + docW, docTop),
  ];
  _fillTriangle(image, foldPoints, docGray);

  // Fold crease line
  _drawLine(
    image,
    docLeft + docW - foldSize,
    docTop,
    docLeft + docW,
    docTop + foldSize,
    img.ColorRgba8(220, 220, 228, 255),
    3,
  );

  // Horizontal lines on document (text)
  final lineColor = img.ColorRgba8(220, 220, 228, 255);
  final lineStartX = docLeft + 48;
  final lineEndX = docLeft + docW - 48;
  var lineY = docTop + 80;
  for (var i = 0; i < 5; i++) {
    final shorten = i == 0 ? 0 : (i * 40);
    _drawLine(
      image,
      lineStartX,
      lineY,
      lineEndX - shorten,
      lineY,
      lineColor,
      6,
    );
    lineY += 48;
  }

  // Thicker bottom lines (like signature/form fields)
  lineY += 16;
  _drawLine(image, lineStartX, lineY, lineStartX + 200, lineY, lineColor, 8);

  // Sparkle/star above document
  _drawSparkle(
    image,
    docLeft + docW - 60,
    docTop - 80,
    60,
    img.ColorRgba8(255, 200, 50, 255),
  );

  // Small decorative dots
  final dotColor = img.ColorRgba8(255, 255, 255, 120);
  _drawDot(image, docLeft - 60, docTop + 40, 12, dotColor);
  _drawDot(image, docLeft - 40, docTop + 80, 8, dotColor);
  _drawDot(image, docLeft + docW + 50, docTop + docH - 60, 10, dotColor);

  // Write output
  final png = img.encodePng(image);
  output.writeAsBytesSync(png);
  stderr.writeln('Icon generated: ${output.path}');
}

void _drawRoundedRect(
  img.Image image,
  int x,
  int y,
  int w,
  int h,
  int radius,
  img.ColorRgba8 color,
) {
  // Main body
  for (var py = y + radius; py < y + h - radius; py++) {
    for (var px = x + radius; px < x + w - radius; px++) {
      image.setPixel(px, py, color);
    }
  }

  // Top rectangle
  for (var py = y; py < y + radius; py++) {
    for (var px = x + radius; px < x + w - radius; px++) {
      image.setPixel(px, py, color);
    }
  }

  // Bottom rectangle
  for (var py = y + h - radius; py < y + h; py++) {
    for (var px = x + radius; px < x + w - radius; px++) {
      image.setPixel(px, py, color);
    }
  }

  // Left rectangle
  for (var py = y + radius; py < y + h - radius; py++) {
    for (var px = x; px < x + radius; px++) {
      image.setPixel(px, py, color);
    }
  }

  // Right rectangle
  for (var py = y + radius; py < y + h - radius; py++) {
    for (var px = x + w - radius; px < x + w; px++) {
      image.setPixel(px, py, color);
    }
  }

  // Rounded corners
  final r2 = radius * radius;
  for (var py = y; py < y + radius; py++) {
    for (var px = x; px < x + radius; px++) {
      final dx = (px - (x + radius)).abs();
      final dy = (py - (y + radius)).abs();
      if (dx * dx + dy * dy <= r2) {
        image.setPixel(px, py, color);
      }
    }
  }
  for (var py = y; py < y + radius; py++) {
    for (var px = x + w - radius; px < x + w; px++) {
      final dx = (px - (x + w - radius)).abs();
      final dy = (py - (y + radius)).abs();
      if (dx * dx + dy * dy <= r2) {
        image.setPixel(px, py, color);
      }
    }
  }
  for (var py = y + h - radius; py < y + h; py++) {
    for (var px = x; px < x + radius; px++) {
      final dx = (px - (x + radius)).abs();
      final dy = (py - (y + h - radius)).abs();
      if (dx * dx + dy * dy <= r2) {
        image.setPixel(px, py, color);
      }
    }
  }
  for (var py = y + h - radius; py < y + h; py++) {
    for (var px = x + w - radius; px < x + w; px++) {
      final dx = (px - (x + w - radius)).abs();
      final dy = (py - (y + h - radius)).abs();
      if (dx * dx + dy * dy <= r2) {
        image.setPixel(px, py, color);
      }
    }
  }
}

void _fillTriangle(
  img.Image image,
  List<(int, int)> points,
  img.ColorRgba8 color,
) {
  // Simple triangle fill using scanline approach
  final minY = points.map((p) => p.$2).reduce(math.min);
  final maxY = points.map((p) => p.$2).reduce(math.max);

  for (var py = minY; py <= maxY; py++) {
    final intersections = <int>[];
    for (var i = 0; i < 3; i++) {
      final p1 = points[i];
      final p2 = points[(i + 1) % 3];
      if (p1.$2 == p2.$2) continue;
      final t = (py - p1.$2) / (p2.$2 - p1.$2);
      if (t >= 0 && t <= 1) {
        final ix = p1.$1 + (t * (p2.$1 - p1.$1)).round();
        intersections.add(ix);
      }
    }
    if (intersections.length >= 2) {
      intersections.sort();
      for (var px = intersections[0]; px <= intersections[1]; px++) {
        if (px >= 0 && px < image.width && py >= 0 && py < image.height) {
          image.setPixel(px, py, color);
        }
      }
    }
  }
}

void _drawLine(
  img.Image image,
  int x1,
  int y1,
  int x2,
  int y2,
  img.ColorRgba8 color,
  int thickness,
) {
  final dx = (x2 - x1).abs();
  final dy = (y2 - y1).abs();
  final sx = x1 < x2 ? 1 : -1;
  final sy = y1 < y2 ? 1 : -1;
  var err = dx - dy;
  var cx = x1;
  var cy = y1;

  while (true) {
    for (var t = 0; t < thickness; t++) {
      for (var s = 0; s < thickness; s++) {
        final px = cx + t - thickness ~/ 2;
        final py = cy + s - thickness ~/ 2;
        if (px >= 0 && px < image.width && py >= 0 && py < image.height) {
          image.setPixel(px, py, color);
        }
      }
    }
    if (cx == x2 && cy == y2) break;
    final e2 = 2 * err;
    if (e2 > -dy) {
      err -= dy;
      cx += sx;
    }
    if (e2 < dx) {
      err += dx;
      cy += sy;
    }
  }
}

void _drawSparkle(
  img.Image image,
  int cx,
  int cy,
  int size,
  img.ColorRgba8 color,
) {
  // Draw a 4-pointed star
  final outer = size;
  final inner = (size * 0.4).round();

  const points = 4;
  for (var i = 0; i < points * 2; i++) {
    final angle = (math.pi * i / points) - math.pi / 2;
    final r = i.isEven ? outer : inner;
    final px = cx + (r * math.cos(angle)).round();
    final py = cy + (r * math.sin(angle)).round();

    // Draw a small circle at each point
    _fillCircle(image, px, py, i.isEven ? 8 : 5, color);
  }

  // Center glow
  _fillCircle(image, cx, cy, 12, color);
  _fillCircle(image, cx, cy, 6, img.ColorRgba8(255, 255, 255, 255));

  // Small sparkle rays
  for (var i = 0; i < 4; i++) {
    final angle = (math.pi * i / 4);
    final dx = (24 * math.cos(angle)).round();
    final dy = (24 * math.sin(angle)).round();
    _drawLine(image, cx, cy, cx + dx, cy + dy, color, 3);
    _drawLine(image, cx, cy, cx - dx, cy - dy, color, 3);
  }
}

void _fillCircle(
  img.Image image,
  int cx,
  int cy,
  int radius,
  img.ColorRgba8 color,
) {
  final r2 = radius * radius;
  for (var py = cy - radius; py <= cy + radius; py++) {
    for (var px = cx - radius; px <= cx + radius; px++) {
      final dx = px - cx;
      final dy = py - cy;
      if (dx * dx + dy * dy <= r2) {
        if (px >= 0 && px < image.width && py >= 0 && py < image.height) {
          image.setPixel(px, py, color);
        }
      }
    }
  }
}

void _drawDot(
  img.Image image,
  int cx,
  int cy,
  int radius,
  img.ColorRgba8 color,
) {
  _fillCircle(image, cx, cy, radius, color);
}
