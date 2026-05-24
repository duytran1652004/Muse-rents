import 'package:flutter/material.dart';

/// Bảng màu chính của MUSE Rents - White & Blue Premium Theme
class RentsColors {
  // ─── Primary Colors (Logo Match) ───
  static const Color primaryBlue = Color(0xFF0047FF);
  static const Color primaryBlueDark = Color(0xFF002999);
  static const Color primaryBlueLight = Color(0xFF4D80FF);
  
  // ─── Background (Light Theme - Trắng Xanh) ───
  static const Color bgWhite = Color(0xFFFFFFFF);
  static const Color bgLightBlue = Color(0xFFF0F7FF);
  static const Color bgGray = Color(0xFFF5F7FA);
  static const Color surfaceBlue = Color(0xFFFDFEFF);
  static const Color surfaceBlueSoft = Color(0xFFF6FAFF);
  
  // ─── Neutral Colors ───
  static const Color white = Color(0xFFFFFFFF);
  static const Color grayLight = Color(0xFFE9ECEF);
  static const Color grayMedium = Color(0xFFCED4DA);
  static const Color grayDark = Color(0xFF6C757D);
  static const Color black = Color(0xFF212529);

  // ─── Accent Colors ───
  static const Color accentGreen = Color(0xFF2ECC71);
  static const Color accentOrange = Color(0xFFF39C12);
  static const Color accentRed = Color(0xFFE74C3C);

  // ─── Gradients (White & Blue) ───
  static const LinearGradient appBackgroundGradient = LinearGradient(
    colors: [
      Color(0xFFFFFFFF),
      Color(0xFFF0F7FF),
      Color(0xFFDEE9FF),
    ],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primaryBlue, primaryBlueDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const List<Shadow> softShadow = [
    Shadow(color: Color(0x1A000000), blurRadius: 10, offset: Offset(0, 4)),
  ];

  static const List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Color(0x140047FF),
      blurRadius: 18,
      offset: Offset(0, 8),
    ),
  ];

  static const List<BoxShadow> softCardShadow = [
    BoxShadow(
      color: Color(0x0F0047FF),
      blurRadius: 12,
      offset: Offset(0, 5),
    ),
  ];
}
