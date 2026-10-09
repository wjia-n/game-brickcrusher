import 'package:flutter/material.dart';

/// Theme, paddle/ball/brick style catalogs for Brick Crusher.
///
/// The "Mason's Workshop" art direction: every theme is a real physical
/// material world (fired clay, quarried stone, worked timber, forged metal).
/// Pseudo-3D comes from bevels, top-light shading, grain and drop shadows —
/// never neon, never flat Material look.
class CrusherThemeDef {
  final String id;
  final String name;
  final Color bg; // arena background
  final Color bgDeep; // vignette edge
  final Color paddleLight; // paddle top-light
  final Color paddleDark; // paddle base
  final Color ballCore;
  final Color ballRim;
  final List<Color> brickRows; // 6 row colors
  final Color brickShade; // mortar / shadow between bricks
  final Color accent;
  final Color accentLight;
  final Color accentDark;
  final Color ink; // text
  final Color muted;

  const CrusherThemeDef({
    required this.id,
    required this.name,
    required this.bg,
    required this.bgDeep,
    required this.paddleLight,
    required this.paddleDark,
    required this.ballCore,
    required this.ballRim,
    required this.brickRows,
    required this.brickShade,
    required this.accent,
    required this.accentLight,
    required this.accentDark,
    required this.ink,
    required this.muted,
  });
}

class CrusherThemes {
  /// First 4 are the FREE starter themes. The rest are PRO.
  static const List<String> freeThemeIds = [
    'terracotta',
    'granite',
    'sandstone',
    'copper',
  ];

  static bool isProTheme(String id) => !freeThemeIds.contains(id);

  static const List<CrusherThemeDef> all = [
    // --- free -----------------------------------------------------------
    CrusherThemeDef(
      id: 'terracotta',
      name: 'Terracotta Yard',
      bg: Color(0xFF2B2018),
      bgDeep: Color(0xFF171009),
      paddleLight: Color(0xFFE0A56B),
      paddleDark: Color(0xFF8A4E22),
      ballCore: Color(0xFFFFF3D6),
      ballRim: Color(0xFFC9963C),
      brickRows: [
        Color(0xFFC96A3B),
        Color(0xFFB8552F),
        Color(0xFFD97F45),
        Color(0xFFA94A28),
        Color(0xFFE08D52),
        Color(0xFF9C4223),
      ],
      brickShade: Color(0xFF241207),
      accent: Color(0xFFD9A441),
      accentLight: Color(0xFFF2CE7E),
      accentDark: Color(0xFF8F6420),
      ink: Color(0xFFF7EBD4),
      muted: Color(0xFFC4AE8A),
    ),
    CrusherThemeDef(
      id: 'granite',
      name: 'Granite Quarry',
      bg: Color(0xFF23262B),
      bgDeep: Color(0xFF131518),
      paddleLight: Color(0xFFB9C2CC),
      paddleDark: Color(0xFF59616B),
      ballCore: Color(0xFFF4F7FA),
      ballRim: Color(0xFF7E8894),
      brickRows: [
        Color(0xFF7C8590),
        Color(0xFF6B7480),
        Color(0xFF8E98A4),
        Color(0xFF5D6672),
        Color(0xFFA3ADB8),
        Color(0xFF525B66),
      ],
      brickShade: Color(0xFF121417),
      accent: Color(0xFFC9D2DC),
      accentLight: Color(0xFFEAF0F6),
      accentDark: Color(0xFF78818D),
      ink: Color(0xFFF2F4F6),
      muted: Color(0xFFA8B0BA),
    ),
    CrusherThemeDef(
      id: 'sandstone',
      name: 'Sandstone Dunes',
      bg: Color(0xFF2E2419),
      bgDeep: Color(0xFF171106),
      paddleLight: Color(0xFFF0D49A),
      paddleDark: Color(0xFF9C7433),
      ballCore: Color(0xFFFFF8E3),
      ballRim: Color(0xFFD9B968),
      brickRows: [
        Color(0xFFE0B96E),
        Color(0xFFCFA55B),
        Color(0xFFF0CE8E),
        Color(0xFFBC9249),
        Color(0xFFEDC77F),
        Color(0xFFA9833F),
      ],
      brickShade: Color(0xFF231806),
      accent: Color(0xFFC99A4E),
      accentLight: Color(0xFFF0D194),
      accentDark: Color(0xFF8A6428),
      ink: Color(0xFFFBF3DE),
      muted: Color(0xFFD3BE93),
    ),
    CrusherThemeDef(
      id: 'copper',
      name: 'Copper Forge',
      bg: Color(0xFF261B16),
      bgDeep: Color(0xFF120C08),
      paddleLight: Color(0xFFE8A87C),
      paddleDark: Color(0xFF7E3F1D),
      ballCore: Color(0xFFFFF0D9),
      ballRim: Color(0xFFC97B3D),
      brickRows: [
        Color(0xFFC97B3D),
        Color(0xFFA85F2B),
        Color(0xFFDE9157),
        Color(0xFF935122),
        Color(0xFFE8A26A),
        Color(0xFF84461E),
      ],
      brickShade: Color(0xFF1E1008),
      accent: Color(0xFFE09A52),
      accentLight: Color(0xFFF7C68C),
      accentDark: Color(0xFF8F5A24),
      ink: Color(0xFFF9EDDA),
      muted: Color(0xFFCBA684),
    ),
    // --- pro ------------------------------------------------------------
    CrusherThemeDef(
      id: 'ocean',
      name: 'Ocean Slate',
      bg: Color(0xFF1B2730),
      bgDeep: Color(0xFF0D1419),
      paddleLight: Color(0xFF9AC6D8),
      paddleDark: Color(0xFF3D6B7E),
      ballCore: Color(0xFFF2FAFE),
      ballRim: Color(0xFF6FA3B8),
      brickRows: [
        Color(0xFF5E8CA3),
        Color(0xFF4C7489),
        Color(0xFF719FB6),
        Color(0xFF406274),
        Color(0xFF86B3C7),
        Color(0xFF365262),
      ],
      brickShade: Color(0xFF0B1216),
      accent: Color(0xFF7FB8CC),
      accentLight: Color(0xFFBFE2EF),
      accentDark: Color(0xFF446F80),
      ink: Color(0xFFEAF6FA),
      muted: Color(0xFF9DBDCB),
    ),
    CrusherThemeDef(
      id: 'forest',
      name: 'Forest Moss',
      bg: Color(0xFF22301D),
      bgDeep: Color(0xFF111806),
      paddleLight: Color(0xFFB7C97E),
      paddleDark: Color(0xFF5C7038),
      ballCore: Color(0xFFF6F9E6),
      ballRim: Color(0xFF8FA052),
      brickRows: [
        Color(0xFF7C9A52),
        Color(0xFF688441),
        Color(0xFF8FAE60),
        Color(0xFF587238),
        Color(0xFFA3C06F),
        Color(0xFF4B6230),
      ],
      brickShade: Color(0xFF0E1306),
      accent: Color(0xFFA9BE6E),
      accentLight: Color(0xFFD6E4A8),
      accentDark: Color(0xFF657A38),
      ink: Color(0xFFF0F5E2),
      muted: Color(0xFFB3C48C),
    ),
    CrusherThemeDef(
      id: 'cherry',
      name: 'Cherry Timber',
      bg: Color(0xFF2C1C14),
      bgDeep: Color(0xFF150D07),
      paddleLight: Color(0xFFE8A07A),
      paddleDark: Color(0xFF8A3E22),
      ballCore: Color(0xFFFFF1DE),
      ballRim: Color(0xFFCE7B4A),
      brickRows: [
        Color(0xFFB05434),
        Color(0xFF97452A),
        Color(0xFFC46440),
        Color(0xFF843A23),
        Color(0xFFD2754E),
        Color(0xFF74311E),
      ],
      brickShade: Color(0xFF1A0E06),
      accent: Color(0xFFD08355),
      accentLight: Color(0xFFF2B889),
      accentDark: Color(0xFF8A4E26),
      ink: Color(0xFFF9EADA),
      muted: Color(0xFFCEA88A),
    ),
    CrusherThemeDef(
      id: 'marble',
      name: 'Marble Hall',
      bg: Color(0xFF26262C),
      bgDeep: Color(0xFF121216),
      paddleLight: Color(0xFFE8E4DA),
      paddleDark: Color(0xFF8A857A),
      ballCore: Color(0xFFFFFFFF),
      ballRim: Color(0xFFB0ABA0),
      brickRows: [
        Color(0xFFD8D2C4),
        Color(0xFFC4BDAE),
        Color(0xFFE6E0D2),
        Color(0xFFB3AC9D),
        Color(0xFFF0EADD),
        Color(0xFFA39C8D),
      ],
      brickShade: Color(0xFF101014),
      accent: Color(0xFFD9C98A),
      accentLight: Color(0xFFF5E9BE),
      accentDark: Color(0xFF8A7A45),
      ink: Color(0xFFFBF8F0),
      muted: Color(0xFFC9C2B2),
    ),
    CrusherThemeDef(
      id: 'bamboo',
      name: 'Bamboo Grove',
      bg: Color(0xFF24301B),
      bgDeep: Color(0xFF101606),
      paddleLight: Color(0xFFDCCB7E),
      paddleDark: Color(0xFF7A6A30),
      ballCore: Color(0xFFFFFBEA),
      ballRim: Color(0xFFB3A052),
      brickRows: [
        Color(0xFFC9B45F),
        Color(0xFFAC984D),
        Color(0xFFDEC974),
        Color(0xFF968340),
        Color(0xFFEADB8A),
        Color(0xFF847236),
      ],
      brickShade: Color(0xFF101405),
      accent: Color(0xFFCDBE6E),
      accentLight: Color(0xFFEFE3A4),
      accentDark: Color(0xFF7E6F35),
      ink: Color(0xFFFAF5E2),
      muted: Color(0xFFC9BB8C),
    ),
    CrusherThemeDef(
      id: 'charcoal',
      name: 'Charcoal Kiln',
      bg: Color(0xFF1E1B17),
      bgDeep: Color(0xFF0C0A07),
      paddleLight: Color(0xFF9A938A),
      paddleDark: Color(0xFF4A443C),
      ballCore: Color(0xFFF5F2EC),
      ballRim: Color(0xFF7E786E),
      brickRows: [
        Color(0xFF6E675C),
        Color(0xFF5D564C),
        Color(0xFF7F786C),
        Color(0xFF4E4840),
        Color(0xFF918A7D),
        Color(0xFF423D36),
      ],
      brickShade: Color(0xFF0A0806),
      accent: Color(0xFFE08A4E),
      accentLight: Color(0xFFF5B87E),
      accentDark: Color(0xFF8A5224),
      ink: Color(0xFFF5F0E6),
      muted: Color(0xFFB0A894),
    ),
    CrusherThemeDef(
      id: 'sunset',
      name: 'Sunset Kiln',
      bg: Color(0xFF2E1D1A),
      bgDeep: Color(0xFF140B09),
      paddleLight: Color(0xFFF0A878),
      paddleDark: Color(0xFF7E3E24),
      ballCore: Color(0xFFFFF4E2),
      ballRim: Color(0xFFD9834A),
      brickRows: [
        Color(0xFFD97A45),
        Color(0xFFB85F33),
        Color(0xFFEA8E55),
        Color(0xFFA0512A),
        Color(0xFFF4A168),
        Color(0xFF8E4423),
      ],
      brickShade: Color(0xFF1C0E07),
      accent: Color(0xFFF0A45E),
      accentLight: Color(0xFFFAD09A),
      accentDark: Color(0xFF96602A),
      ink: Color(0xFFFBEFDC),
      muted: Color(0xFFD8B088),
    ),
    CrusherThemeDef(
      id: 'frost',
      name: 'Winter Stone',
      bg: Color(0xFF20282E),
      bgDeep: Color(0xFF0F1417),
      paddleLight: Color(0xFFC4DCE8),
      paddleDark: Color(0xFF5E7E8E),
      ballCore: Color(0xFFFFFFFF),
      ballRim: Color(0xFF9ABCCB),
      brickRows: [
        Color(0xFF9ABCCB),
        Color(0xFF84A8B8),
        Color(0xFFAED0DE),
        Color(0xFF7193A4),
        Color(0xFFC2DEEA),
        Color(0xFF608090),
      ],
      brickShade: Color(0xFF0D1214),
      accent: Color(0xFF8FBFD4),
      accentLight: Color(0xFFC6E6F2),
      accentDark: Color(0xFF4E7384),
      ink: Color(0xFFF0F7FA),
      muted: Color(0xFFA9C4D0),
    ),
    CrusherThemeDef(
      id: 'rose',
      name: 'Rose Clay',
      bg: Color(0xFF2C2024),
      bgDeep: Color(0xFF140E10),
      paddleLight: Color(0xFFE8A8A8),
      paddleDark: Color(0xFF8A4E52),
      ballCore: Color(0xFFFFF2F0),
      ballRim: Color(0xFFCE7E7E),
      brickRows: [
        Color(0xFFC47E7E),
        Color(0xFFA96868),
        Color(0xFFD69292),
        Color(0xFF945858),
        Color(0xFFE2A6A6),
        Color(0xFF844A4A),
      ],
      brickShade: Color(0xFF180D0E),
      accent: Color(0xFFE09A9A),
      accentLight: Color(0xFFF5C6C6),
      accentDark: Color(0xFF8A5A5A),
      ink: Color(0xFFFBEAEA),
      muted: Color(0xFFD4ACAC),
    ),
    CrusherThemeDef(
      id: 'olive',
      name: 'Olive Grove',
      bg: Color(0xFF262B1B),
      bgDeep: Color(0xFF111406),
      paddleLight: Color(0xFFC4BE7E),
      paddleDark: Color(0xFF6E6838),
      ballCore: Color(0xFFFFFBEA),
      ballRim: Color(0xFFA39A52),
      brickRows: [
        Color(0xFFA39A52),
        Color(0xFF8A8244),
        Color(0xFFB7AF64),
        Color(0xFF756E39),
        Color(0xFFCBC47A),
        Color(0xFF635E31),
      ],
      brickShade: Color(0xFF101205),
      accent: Color(0xFFB8AE62),
      accentLight: Color(0xFFE2D896),
      accentDark: Color(0xFF6E6834),
      ink: Color(0xFFFAF5E0),
      muted: Color(0xFFC4B98A),
    ),
  ];

  static CrusherThemeDef byId(String id, {CrusherThemeDef? custom}) {
    if (id == 'custom' && custom != null) return custom;
    for (final t in all) {
      if (t.id == id) return t;
    }
    return all[0];
  }
}

// ---------------------------------------------------------------------------
// Paddle styles: drawn shape parameters (pseudo-3D bevels, end caps).
class PaddleStyleDef {
  final String name;
  final double radius; // corner radius as fraction of paddle height
  final double bevel; // bevel strip height fraction (0..0.5)
  final int caps; // 0 none, 1 rounded knobs, 2 angled tips
  final bool pro;
  const PaddleStyleDef(this.name, this.radius, this.bevel, this.caps,
      {this.pro = false});
}

class PaddleStyles {
  static const List<PaddleStyleDef> all = [
    PaddleStyleDef('Classic Plank', 0.35, 0.35, 0),
    PaddleStyleDef('Rounded Board', 0.5, 0.3, 1),
    PaddleStyleDef('Steel Beam', 0.08, 0.42, 2),
    PaddleStyleDef('Marble Slab', 0.18, 0.25, 0, pro: true),
    PaddleStyleDef('Bamboo Rod', 0.5, 0.45, 1, pro: true),
    PaddleStyleDef('Sport Blade', 0.28, 0.38, 2, pro: true),
    PaddleStyleDef('Twin Knob', 0.4, 0.3, 1, pro: true),
    PaddleStyleDef('Flat Chisel', 0.05, 0.2, 2, pro: true),
  ];
  static List<String> get names => [for (final s in all) s.name];
  static bool isPro(int i) => all[i].pro;
}

// ---------------------------------------------------------------------------
// Ball styles: drawn highlight / ring parameters.
class BallStyleDef {
  final String name;
  final double highlight; // highlight dot radius fraction
  final int rings; // 0 none, 1 equator band, 2 two dots
  final bool pro;
  const BallStyleDef(this.name, this.highlight, this.rings, {this.pro = false});
}

class BallStyles {
  static const List<BallStyleDef> all = [
    BallStyleDef('Marble', 0.32, 0),
    BallStyleDef('Chrome', 0.4, 1),
    BallStyleDef('Pearl', 0.28, 2),
    BallStyleDef('Wooden Orb', 0.24, 1, pro: true),
    BallStyleDef('Copper Shot', 0.36, 1, pro: true),
    BallStyleDef('Glass Eye', 0.44, 0, pro: true),
    BallStyleDef('Ruby Core', 0.3, 2, pro: true),
    BallStyleDef('Slate Ball', 0.22, 0, pro: true),
  ];
  static List<String> get names => [for (final s in all) s.name];
  static bool isPro(int i) => all[i].pro;
}

// ---------------------------------------------------------------------------
// Brick styles: drawn bevel + surface pattern parameters.
class BrickStyleDef {
  final String name;
  final double radius; // corner radius px
  final double bevel; // bevel inset px
  final int pattern; // 0 plain, 1 cross mortar, 2 diagonal, 3 inner panel
  final bool pro;
  const BrickStyleDef(this.name, this.radius, this.bevel, this.pattern,
      {this.pro = false});
}

class BrickStyles {
  static const List<BrickStyleDef> all = [
    BrickStyleDef('Fired Brick', 5, 3, 0),
    BrickStyleDef('Ashlar Stone', 3, 4, 1),
    BrickStyleDef('Clay Tile', 8, 2, 3),
    BrickStyleDef('Plank Block', 4, 3, 2, pro: true),
    BrickStyleDef('Metal Plate', 2, 5, 0, pro: true),
    BrickStyleDef('Marble Block', 7, 2, 3, pro: true),
    BrickStyleDef('Herringbone', 4, 3, 2, pro: true),
    BrickStyleDef('Rubble Chunk', 10, 4, 1, pro: true),
  ];
  static List<String> get names => [for (final s in all) s.name];
  static bool isPro(int i) => all[i].pro;
}
