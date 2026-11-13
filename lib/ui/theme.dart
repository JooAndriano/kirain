import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Satu-satunya tempat warna aplikasi didefinisikan.
abstract final class KirainColors {
  static const primary = Color(0xFFFF8A3D);
  static const accent = Color(0xFFFFC93C);

  /// Sama dengan latar gambar logo dan splash Android (res/values/colors.xml).
  static const background = Color(0xFFFCF1D6);
  static const text = Color(0xFF3B2A20);

  static const surface = Color(0xFFFFFFFF);
  static const onPrimary = Color(0xFFFFFFFF);
  static const boxEmpty = Color(0xFFFFE9C7);
  static const boxBorder = Color(0xFFF2C894);
  static const locked = Color(0xFFFFE08A);
  static const tileUsed = Color(0x14000000);
  static const shadow = Color(0x1F3B2A20);
  static const starOff = Color(0xFFE6D9C3);
  static const lockedTile = Color(0xFFE3DFD9);
  static const lockedText = Color(0xFF9E958C);
}

const double kRadius = 16;
const double kMinTap = 48;

const List<BoxShadow> kSoftShadow = [
  BoxShadow(color: KirainColors.shadow, blurRadius: 12, offset: Offset(0, 4)),
];

final BorderRadius kBorderRadius = BorderRadius.circular(kRadius);

ThemeData buildKirainTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: KirainColors.primary,
      primary: KirainColors.primary,
      secondary: KirainColors.accent,
      surface: KirainColors.background,
      onSurface: KirainColors.text,
    ),
    scaffoldBackgroundColor: KirainColors.background,
  );
  final shape = RoundedRectangleBorder(borderRadius: kBorderRadius);
  const minSize = Size(kMinTap, kMinTap);

  return base.copyWith(
    textTheme: GoogleFonts.fredokaTextTheme(
      base.textTheme,
    ).apply(bodyColor: KirainColors.text, displayColor: KirainColors.text),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: KirainColors.primary,
        foregroundColor: KirainColors.onPrimary,
        disabledBackgroundColor: KirainColors.boxEmpty,
        minimumSize: minSize,
        shape: shape,
        elevation: 2,
        shadowColor: KirainColors.shadow,
        textStyle: GoogleFonts.fredoka(fontWeight: FontWeight.w600),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: KirainColors.primary,
        foregroundColor: KirainColors.onPrimary,
        minimumSize: minSize,
        shape: shape,
        textStyle: GoogleFonts.fredoka(fontWeight: FontWeight.w600),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        minimumSize: minSize,
        foregroundColor: KirainColors.text,
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: KirainColors.background,
      shape: shape,
    ),
  );
}
