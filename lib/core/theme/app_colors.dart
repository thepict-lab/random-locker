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

  /// 팀 · 영역 색 — 번호로 고른다 ([Team.color], [LockerArea.color])
  static const team = <Color>[
    Color(0xFF0152BD),
    Color(0xFFE0523F),
    Color(0xFF1E9E6A),
    Color(0xFF8B5CF6),
    Color(0xFFE59A12),
    Color(0xFF0EA5B7),
    Color(0xFFDB2777),
    Color(0xFF64748B),
  ];

  static Color teamColor(int i) => team[i % team.length];

  /// 칸 바탕에 까는 옅은 팀 색
  static Color teamSoft(int i) => Color.alphaBlend(teamColor(i).withValues(alpha: 0.10), Colors.white);
}

/// 팀장 추첨 화면 — lotto-airmix 의 구성(어두운 추첨기 무대 + 노란 강조)을 따른다.
abstract final class DrawColors {
  static const bg = Color(0xFFEEF0F4);
  static const panel = Colors.white;
  static const fg = Color(0xFF141A24);
  static const muted = Color(0xFF5D6778);
  static const line = Color(0xFFD6DBE4);
  static const accent = Color(0xFFFBC400);
  static const accentFg = Color(0xFF1A1400);
  static const stage = Color(0xFF0B0F16);
  static const stageHi = Color(0xFF1A2436);
  static const good = Color(0xFF2E9E5B);
  static const hudText = Color(0xFFE8ECF2);
  static const hudSub = Color(0xFFA9B4C6);

  /// 구슬 색 — 숫자 1 … 10
  static const balls = <Color>[
    Color(0xFFFBC400), // 1
    Color(0xFF69C8F2), // 2
    Color(0xFFFF7272), // 3
    Color(0xFFB4B4B4), // 4
    Color(0xFFB0D840), // 5
    Color(0xFFFF9F43), // 6
    Color(0xFFB794F6), // 7
    Color(0xFFF78FB3), // 8
    Color(0xFF4FD1C5), // 9
    Color(0xFFFFE08A), // 10 — 하나뿐인 금색 구슬
  ];

  static Color ball(int number) => balls[(number - 1).clamp(0, balls.length - 1)];
}
