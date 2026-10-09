import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/crusher_themes.dart';

/// Persisted settings + profile for Brick Crusher. Survives app restarts.
///
/// The player profile (name, high scores, stats) is persisted as ONE JSON
/// string. Android's SharedPreferences stores StringLists as an unordered
/// StringSet, so StringLists are never used for ordered data. Legacy keys
/// are migrated once and removed.
class CrusherSettings extends ChangeNotifier {
  static const _kMusic = 'bc_music_on';
  static const _kSfx = 'bc_sfx_on';
  static const _kVolume = 'bc_volume';
  static const _kDifficulty = 'bc_difficulty'; // 0..3
  static const _kMode = 'bc_mode'; // 0..2
  static const _kTheme = 'bc_theme_id';
  static const _kPaddle = 'bc_paddle_style';
  static const _kBall = 'bc_ball_style';
  static const _kBrick = 'bc_brick_style';
  static const _kIsPro = 'bc_is_pro';
  static const _kCustomPrefix = 'bc_custom_';
  static const _kCustomId = 'bc_custom_id'; // 1 when user built a custom theme

  /// Order-safe player profile: ONE order-preserving JSON string via
  /// setString. NEVER a StringList — Android stores StringLists as an
  /// unordered StringSet, which scrambles slot order across restarts.
  static const _kProfileJson = 'brickcrusher_player_names_json';

  // Legacy keys (migrated once, then removed).
  static const _kLegacyProfileJson = 'bc_profile_json';
  static const _kLegacyName = 'bc_player_name';
  static const _kLegacyHigh = 'bc_high_score';

  static const defaultName = 'Smasher';

  /// Encode the profile as one JSON string (order-preserving).
  static String encodeProfile(Map<String, dynamic> p) => jsonEncode(p);

  /// Decode the profile; falls back to defaults on missing/corrupt data.
  static Map<String, dynamic> decodeProfile(String? raw) {
    final def = <String, dynamic>{
      'name': defaultName,
      'highScore': 0,
      'highEndless': 0,
      'highAttack': 0,
      'gamesPlayed': 0,
      'levelsCleared': 0,
      'bestCombo': 0,
      'totalBricks': 0,
    };
    if (raw == null) return def;
    try {
      final d = jsonDecode(raw);
      if (d is Map) {
        for (final k in def.keys) {
          if (d[k] is int) def[k] = d[k];
        }
        final n = (d['name'] as String?)?.trim() ?? '';
        def['name'] = n.isEmpty ? defaultName : n;
      }
    } catch (_) {}
    return def;
  }

  bool musicOn = true;
  bool sfxOn = true;
  double volume = 0.8;
  int difficulty = 1; // classic default
  int mode = 0; // campaign default
  String themeId = 'terracotta';
  int paddleStyle = 0;
  int ballStyle = 0;
  int brickStyle = 0;
  bool isPro = false;

  // Player profile fields (persisted inside the JSON profile string).
  String playerName = defaultName;
  int highScore = 0; // campaign best
  int highEndless = 0; // endless best
  int highAttack = 0; // score attack best
  int gamesPlayed = 0;
  int levelsCleared = 0;
  int bestCombo = 0;
  int totalBricks = 0;

  /// Custom theme colors (ARGB ints). Defaults mirror Terracotta Yard.
  Map<String, int> customColors = Map.of(_defaultCustomColors);
  bool hasCustomTheme = false;

  static const Map<String, int> _defaultCustomColors = {
    'bg': 0xFF2B2018,
    'bgDeep': 0xFF171009,
    'paddleLight': 0xFFE0A56B,
    'paddleDark': 0xFF8A4E22,
    'ballCore': 0xFFFFF3D6,
    'ballRim': 0xFFC9963C,
    'brickA': 0xFFC96A3B,
    'brickB': 0xFFB8552F,
    'brickC': 0xFFD97F45,
    'brickD': 0xFFA94A28,
    'brickE': 0xFFE08D52,
    'brickF': 0xFF9C4223,
    'accent': 0xFFD9A441,
    'accentLight': 0xFFF2CE7E,
    'accentDark': 0xFF8F6420,
    'ink': 0xFFF7EBD4,
    'muted': 0xFFC4AE8A,
  };

  /// Builds the user-designed custom theme from stored colors.
  CrusherThemeDef get customTheme {
    int c(String k) => customColors[k] ?? 0xFF000000;
    Color col(String k) => Color(c(k));
    return CrusherThemeDef(
      id: 'custom',
      name: 'My Creation',
      bg: col('bg'),
      bgDeep: col('bgDeep'),
      paddleLight: col('paddleLight'),
      paddleDark: col('paddleDark'),
      ballCore: col('ballCore'),
      ballRim: col('ballRim'),
      brickRows: [
        col('brickA'),
        col('brickB'),
        col('brickC'),
        col('brickD'),
        col('brickE'),
        col('brickF')
      ],
      brickShade: col('bgDeep'),
      accent: col('accent'),
      accentLight: col('accentLight'),
      accentDark: col('accentDark'),
      ink: col('ink'),
      muted: col('muted'),
    );
  }

  SharedPreferences? _prefs;

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    final p = _prefs!;
    musicOn = p.getBool(_kMusic) ?? true;
    sfxOn = p.getBool(_kSfx) ?? true;
    volume = p.getDouble(_kVolume) ?? 0.8;
    difficulty = (p.getInt(_kDifficulty) ?? 1).clamp(0, 3);
    mode = (p.getInt(_kMode) ?? 0).clamp(0, 2);
    // Profile: prefer the order-safe JSON key; migrate legacy keys once.
    final raw = p.getString(_kProfileJson) ?? p.getString(_kLegacyProfileJson);
    if (raw == null) {
      final legacyName = p.getString(_kLegacyName);
      final legacyHigh = p.getInt(_kLegacyHigh);
      if (legacyName != null || legacyHigh != null) {
        playerName = (legacyName ?? '').trim().isEmpty
            ? defaultName
            : legacyName!.trim();
        highScore = legacyHigh ?? 0;
        // Persist the migrated profile immediately under the new key.
        await _saveProfile();
      }
    } else {
      final prof = decodeProfile(raw);
      playerName = prof['name'] as String;
      highScore = prof['highScore'] as int;
      highEndless = prof['highEndless'] as int;
      highAttack = prof['highAttack'] as int;
      gamesPlayed = prof['gamesPlayed'] as int;
      levelsCleared = prof['levelsCleared'] as int;
      bestCombo = prof['bestCombo'] as int;
      totalBricks = prof['totalBricks'] as int;
    }
    await p.remove(_kLegacyProfileJson);
    await p.remove(_kLegacyName);
    await p.remove(_kLegacyHigh);
    themeId = p.getString(_kTheme) ?? 'terracotta';
    paddleStyle = (p.getInt(_kPaddle) ?? 0).clamp(0, PaddleStyles.all.length - 1);
    ballStyle = (p.getInt(_kBall) ?? 0).clamp(0, BallStyles.all.length - 1);
    brickStyle = (p.getInt(_kBrick) ?? 0).clamp(0, BrickStyles.all.length - 1);
    isPro = p.getBool(_kIsPro) ?? false;
    hasCustomTheme = p.getInt(_kCustomId) == 1;
    for (final k in _defaultCustomColors.keys) {
      customColors[k] =
          p.getInt('$_kCustomPrefix$k') ?? _defaultCustomColors[k]!;
    }
    _enforceFreeLimits(silent: true);
    notifyListeners();
  }

  Future<void> _saveProfile() async {
    final p = _prefs;
    if (p == null) return;
    await p.setString(
        _kProfileJson,
        encodeProfile({
          'name': playerName,
          'highScore': highScore,
          'highEndless': highEndless,
          'highAttack': highAttack,
          'gamesPlayed': gamesPlayed,
          'levelsCleared': levelsCleared,
          'bestCombo': bestCombo,
          'totalBricks': totalBricks,
        }));
  }

  Future<void> _save() async {
    final p = _prefs;
    if (p == null) return;
    await p.setBool(_kMusic, musicOn);
    await p.setBool(_kSfx, sfxOn);
    await p.setDouble(_kVolume, volume);
    await p.setInt(_kDifficulty, difficulty);
    await p.setInt(_kMode, mode);
    await _saveProfile();
    await p.setString(_kTheme, themeId);
    await p.setInt(_kPaddle, paddleStyle);
    await p.setInt(_kBall, ballStyle);
    await p.setInt(_kBrick, brickStyle);
    await p.setBool(_kIsPro, isPro);
    await p.setInt(_kCustomId, hasCustomTheme ? 1 : 0);
    for (final e in customColors.entries) {
      await p.setInt('$_kCustomPrefix${e.key}', e.value);
    }
  }

  /// Free-tier limits: clamp pro-only choices back when not Pro.
  void _enforceFreeLimits({bool silent = false}) {
    if (isPro) return;
    var changed = false;
    if (themeId == 'custom' || CrusherThemes.isProTheme(themeId)) {
      themeId = 'terracotta';
      changed = true;
    }
    if (PaddleStyles.isPro(paddleStyle)) {
      paddleStyle = 0;
      changed = true;
    }
    if (BallStyles.isPro(ballStyle)) {
      ballStyle = 0;
      changed = true;
    }
    if (BrickStyles.isPro(brickStyle)) {
      brickStyle = 0;
      changed = true;
    }
    if (difficulty > 1) {
      difficulty = 1;
      changed = true;
    }
    if (mode == 2) {
      mode = 0; // score attack is a Pro mode
      changed = true;
    }
    if (changed && !silent) {
      notifyListeners();
      _save();
    }
  }

  Future<void> setPro(bool v) async {
    isPro = v;
    if (!v) _enforceFreeLimits();
    notifyListeners();
    await _save();
  }

  Future<void> setCustomColor(String key, int argb) async {
    if (!isPro) return; // custom theme creator is a Pro feature
    if (!_defaultCustomColors.containsKey(key)) return;
    customColors[key] = argb;
    hasCustomTheme = true;
    notifyListeners();
    await _save();
  }

  Future<void> resetCustomColors() async {
    customColors = Map.of(_defaultCustomColors);
    notifyListeners();
    await _save();
  }

  Future<void> setMusic(bool v) async {
    musicOn = v;
    notifyListeners();
    await _save();
  }

  Future<void> setSfx(bool v) async {
    sfxOn = v;
    notifyListeners();
    await _save();
  }

  Future<void> setVolume(double v) async {
    volume = v.clamp(0.0, 1.0);
    notifyListeners();
    await _save();
  }

  Future<void> setPlayerName(String name) async {
    final clean = name.trim();
    playerName = clean.isEmpty ? defaultName : clean;
    notifyListeners();
    await _save();
  }

  Future<void> setDifficulty(int v) async {
    v = v.clamp(0, 3);
    if (!isPro && v > 1) return; // Wild & Insane are Pro
    difficulty = v;
    notifyListeners();
    await _save();
  }

  Future<void> setMode(int v) async {
    v = v.clamp(0, 2);
    if (!isPro && v == 2) return; // Score Attack is Pro
    mode = v;
    notifyListeners();
    await _save();
  }

  Future<void> setTheme(String id) async {
    if (!isPro && (id == 'custom' || CrusherThemes.isProTheme(id))) return;
    themeId = id;
    notifyListeners();
    await _save();
  }

  Future<void> setPaddleStyle(int v) async {
    v = v.clamp(0, PaddleStyles.all.length - 1);
    if (!isPro && PaddleStyles.isPro(v)) return;
    paddleStyle = v;
    notifyListeners();
    await _save();
  }

  Future<void> setBallStyle(int v) async {
    v = v.clamp(0, BallStyles.all.length - 1);
    if (!isPro && BallStyles.isPro(v)) return;
    ballStyle = v;
    notifyListeners();
    await _save();
  }

  Future<void> setBrickStyle(int v) async {
    v = v.clamp(0, BrickStyles.all.length - 1);
    if (!isPro && BrickStyles.isPro(v)) return;
    brickStyle = v;
    notifyListeners();
    await _save();
  }

  /// Record a finished run: high scores per mode, lifetime stats.
  Future<void> recordRun({
    required int score,
    required int mode,
    required bool victory,
    required int levels,
    required int bestComboRun,
    required int bricks,
  }) async {
    gamesPlayed++;
    levelsCleared += levels;
    if (bestComboRun > bestCombo) bestCombo = bestComboRun;
    totalBricks += bricks;
    if (mode == 1) {
      if (score > highEndless) highEndless = score;
    } else if (mode == 2) {
      if (score > highAttack) highAttack = score;
    } else {
      if (score > highScore) highScore = score;
    }
    notifyListeners();
    await _save();
  }
}
