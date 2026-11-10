import 'package:flutter/material.dart';

/// Design tokens mirrored from the original product's look: near-black
/// canvas, teal accent, translucent glass tiles, generous rounding.
class CA {
  static const canvas = Color(0xFF0B0F1A);
  static const canvasAlt = Color(0xFF111726);
  static const accent = Color(0xFF5EF2D6);
  static const accentDeep = Color(0xFF2BB9A3);
  static const danger = Color(0xFFFF7A85);
  static const good = Color(0xFF6EE7A0);
  static const ink = Color(0xFFFFFFFF);

  static const dim = Color(0xB3FFFFFF);
  static const glass = Color(0x1FFFFFFF);
  static const edge = Color(0x29FFFFFF);

  /// Minimum readable text on the car screen.
  static const minText = 12.0;

  static ThemeData dark() {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: canvas,
      colorScheme: base.colorScheme.copyWith(
        primary: accent,
        secondary: accentDeep,
        surface: canvasAlt,
        error: danger,
        onPrimary: canvas,
      ),
      cardTheme: CardThemeData(
        color: canvasAlt,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: edge),
        ),
      ),
      textTheme: base.textTheme.apply(
        bodyColor: ink,
        displayColor: ink,
      ),
    );
  }

  /// Glassy tile decoration used by every widget.
  static BoxDecoration tile({double radius = 18, Color? outline}) => BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xBD161C2C), Color(0xD10D111C)],
        ),
        border: Border.all(color: outline ?? edge),
      );
}
