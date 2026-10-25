import 'package:flutter/material.dart';

/// Design tokens for the Dr. Tarraf clinic app.
///
/// Warm ivory canvas, deep navy ink (matches the phoenix brand mark) and a
/// restrained champagne-gold accent. Semantic tints are used only for state.
class Tk {
  Tk._();

  // Surfaces
  static const ivory = Color(0xffF7F4EE);
  static const surface = Color(0xffFFFFFF);
  static const surfaceAlt = Color(0xffF0ECE4);
  static const line = Color(0xffE6E0D5);

  // Ink
  static const ink = Color(0xff18223A);
  static const inkSoft = Color(0xff5E6A82);
  static const inkFaint = Color(0xff8A93A6);

  // Accent
  static const gold = Color(0xffA9854F);
  static const goldDeep = Color(0xff7F5F2C);
  static const goldSoft = Color(0xffF3EBDD);

  // Semantic
  static const sage = Color(0xff2E7D6B);
  static const sageSoft = Color(0xffE3F1ED);
  static const amber = Color(0xffB7791F);
  static const amberSoft = Color(0xffFBF1DC);
  static const rose = Color(0xffB4443B);
  static const roseSoft = Color(0xffFBE9E6);
  static const plum = Color(0xff6B58A6);
  static const plumSoft = Color(0xffEEEAF8);

  // Shape & depth
  static const double rSm = 14;
  static const double r = 20;
  static const double rLg = 28;

  static const List<BoxShadow> shadow = [
    BoxShadow(color: Color(0x0F18223A), blurRadius: 24, offset: Offset(0, 8)),
    BoxShadow(color: Color(0x0A18223A), blurRadius: 3, offset: Offset(0, 1)),
  ];
}

/// Text style helper: always carries the Tajawal family explicitly so that
/// copyWith/replacement in themes never silently falls back to a system font.
TextStyle tjw(
  double size,
  FontWeight weight, {
  Color color = Tk.ink,
  double? height,
}) => TextStyle(
  fontFamily: 'Tajawal',
  fontSize: size,
  fontWeight: weight,
  color: color,
  height: height,
);
