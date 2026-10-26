import 'package:flutter/material.dart';

/// PICT. 브랜드 색 — 로고(thepict_logo.png)에서 뽑은 파랑을 기준으로 한다.
abstract final class AppColors {
  static const brand = Color(0xFF0152BD);
  static const brandDark = Color(0xFF003C8C);
  static const brandSoft = Color(0xFFE8F0FB);
  static const brandLine = Color(0xFFB9CEEC);

  static const ink = Color(0xFF111827);
  static const inkSub = Color(0xFF4B5563);
  static const inkMute = Color(0xFF9CA3AF);

  static const canvas = Color(0xFFF4F6FA);
  static const surface = Colors.white;
  static const line = Color(0xFFE3E7EE);

  /// 고정된 칸 — 랜덤 배치 때 움직이지 않는다
  static const pinned = Color(0xFFFFF4D6);
  static const pinnedLine = Color(0xFFF2C14E);

  /// 사용하지 않는 칸 (고장 · 예약)
  static const disabled = Color(0xFFECEEF2);

  static const danger = Color(0xFFDC2626);
}
