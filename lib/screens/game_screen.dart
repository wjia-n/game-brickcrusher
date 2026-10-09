import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:share_plus/share_plus.dart';
import '../engine/crusher_engine.dart';
import '../services/audio_service.dart';
import '../services/settings_service.dart';
import '../theme/crusher_themes.dart';
import '../theme/workshop.dart';

const _storeUrl =
    'https://play.google.com/store/apps/details?id=com.gameswajiha.brickcrusher';

/// The play screen. The engine owns ALL phases and physics; this screen
/// renders, forwards input, and maps engine events to sounds.
class GameScreen extends StatefulWidget {
  final CrusherAudio audio;
  final CrusherSettings settings;

  const GameScreen({super.key, required this.audio, required this.settings});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final CrusherEngine _engine;
  late final Ticker _ticker;
  Duration _last = Duration.zero;
  bool _runRecorded = false;

  CrusherAudio get _audio => widget.audio;
  CrusherSettings get _s => widget.settings;
  CrusherThemeDef get _t =>
      CrusherThemes.byId(_s.themeId, custom: _s.customTheme);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _engine = CrusherEngine(
      difficulty: CrusherDifficulty.values[_s.difficulty],
      mode: CrusherMode.values[_s.mode],
    );
    _engine.brickColorFor =
        (b) => _t.brickRows[(b.row) % _t.brickRows.length];
    _engine.onEvent = _onEvent;
    _ticker = createTicker(_tick)..start();
    _audio.startGameMusic();
  }

  void _tick(Duration now) {
    if (_last == Duration.zero) {
      _last = now;
      return;
    }
    final dt = min((now - _last).inMicroseconds / 1e6, 1 / 30);
    _last = now;
    _engine.update(dt);
  }

  void _onEvent(CrusherEvent e) {
    switch (e) {
      case CrusherEvent.launch:
        _audio.launch();
      case CrusherEvent.paddleHit:
        _audio.paddle();
      case CrusherEvent.wallHit:
        _audio.wall();
      case CrusherEvent.brickCrack:
        _audio.crack();
      case CrusherEvent.brickBreak:
        _audio.smash();
      case CrusherEvent.combo:
        _audio.combo();
      case CrusherEvent.powerUp:
        _audio.powerUp();
      case CrusherEvent.laserFire:
        _audio.laser();
      case CrusherEvent.lifeLost:
        _audio.lifeLost();
      case CrusherEvent.levelClear:
        _audio.levelClear();
      case CrusherEvent.invalid:
        _audio.invalid();
      case CrusherEvent.win:
        _audio.win();
      case CrusherEvent.lose:
        _audio.lose();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Freeze the engine on interruption; the pause overlay lets the user
    // resume. No silent auto-resume — the user taps Resume.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      _engine.setPaused(true);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker.dispose();
    _engine.dispose();
    super.dispose();
  }

  /// Record the finished run once, then maybe ask for a review.
  Future<void> _maybeRecordAndReview() async {
    if (_runRecorded || !_engine.over) return;
    _runRecorded = true;
    final cleared = (_engine.won &&
            _engine.mode == CrusherMode.campaign)
        ? 5
        : max(0, _engine.level - 1);
    await _s.recordRun(
      score: _engine.score,
      mode: _engine.mode.index,
      victory: _engine.won,
      levels: cleared,
      bestComboRun: _engine.bestCombo,
      bricks: _engine.bricksSmashed,
    );
    // Sensible review moment: every 3rd finished run, graceful when the
    // Play sheet is unavailable (not-from-Play builds, offline, etc).
    if (_s.gamesPlayed % 3 == 0 && mounted) {
      try {
        final review = InAppReview.instance;
        if (await review.isAvailable()) {
          await review.requestReview();
        }
      } catch (_) {}
    }
  }

  void _quitToMenu() {
    _audio.click();
    _audio.startMenuMusic();
    Navigator.of(context).pop();
  }

  String _modeLine() {
    final m = _engine.mode;
    if (m == CrusherMode.scoreAttack) {
      final s = _engine.timeLeft.ceil();
      return '⏱ ${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
    }
    final tag = m == CrusherMode.endless ? 'ENDLESS' : 'CAMPAIGN';
    return '$tag • LV ${_engine.level}';
  }

  int _bestForMode() {
    switch (_engine.mode) {
      case CrusherMode.endless:
        return _s.highEndless;
      case CrusherMode.scoreAttack:
        return _s.highAttack;
      case CrusherMode.campaign:
        return _s.highScore;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = _t;
    return WorkshopBackdrop(
      theme: t,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: ListenableBuilder(
            listenable: _engine,
            builder: (_, _) {
              if (_engine.over) _maybeRecordAndReview();
              return Stack(
                children: [
                  Column(
                    children: [
                      _Hud(engine: _engine, best: _bestForMode(), theme: t),
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            _engine.arena = Size(
                                constraints.maxWidth, constraints.maxHeight);
                            return AnimatedBuilder(
                              animation: _ticker,
                              builder: (_, _) => GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onHorizontalDragUpdate: (d) {
                                  final w = _engine.arena.width;
                                  if (w <= 0) return;
                                  _engine.movePaddle(
                                      _engine.paddleX + d.delta.dx / w);
                                },
                                onTapDown: (_) => _engine.tapAction(),
                                child: CustomPaint(
                                  painter: _CrusherPainter(
                                    engine: _engine,
                                    theme: t,
                                    paddleStyle: PaddleStyles
                                        .all[_s.paddleStyle],
                                    ballStyle:
                                        BallStyles.all[_s.ballStyle],
                                    brickStyle:
                                        BrickStyles.all[_s.brickStyle],
                                  ),
                                  size: Size.infinite,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      _HintBar(engine: _engine, theme: t),
                    ],
                  ),
                  if (_engine.isBanner && !_engine.over)
                    _BannerOverlay(engine: _engine, theme: t),
                  if (_engine.phase == CrusherPhase.paused &&
                      !_engine.over)
                    _PauseOverlay(
                      theme: t,
                      audio: _audio,
                      onResume: () {
                        _audio.click();
                        _engine.setPaused(false);
                      },
                      onRestart: () {
                        _audio.click();
                        _runRecorded = false;
                        _engine.restart();
                      },
                      onQuit: _quitToMenu,
                    ),
                  if (_engine.over)
                    _GameOverOverlay(
                      engine: _engine,
                      best: _bestForMode(),
                      theme: t,
                      audio: _audio,
                      playerName: _s.playerName,
                      onRestart: () {
                        _audio.click();
                        _runRecorded = false;
                        _engine.restart();
                      },
                      onQuit: _quitToMenu,
                    ),
                  // Pause button (top-right, above the play area).
                  if (!_engine.over &&
                      _engine.phase != CrusherPhase.paused)
                    Positioned(
                      top: 6,
                      right: 8,
                      child: GestureDetector(
                        onTap: () {
                          _audio.click();
                          _engine.setPaused(true);
                        },
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: t.bgDeep.withValues(alpha: 0.75),
                            border: Border.all(color: t.accent, width: 2),
                          ),
                          child: Icon(Icons.pause,
                              color: t.accentLight, size: 22),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
/// Score / lives / level / combo / power-up HUD. Every action is visible:
/// score ticks up, combos flash, power-ups count down.
class _Hud extends StatelessWidget {
  final CrusherEngine engine;
  final int best;
  final CrusherThemeDef theme;
  const _Hud({required this.engine, required this.best, required this.theme});

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final isAttack = engine.mode == CrusherMode.scoreAttack;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 34, 60, 4),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isAttack ? _fmtTime(engine.timeLeft) : '❤️ × ${engine.lives}',
                style: Workshop.body(16, theme: t),
              ),
              Column(
                children: [
                  Text('${engine.score}',
                      style: Workshop.display(26, theme: t)),
                  Text('BEST $best',
                      style: Workshop.label(11, theme: t)),
                ],
              ),
              Text(_modeLine(), style: Workshop.label(13, theme: t)),
            ],
          ),
          const SizedBox(height: 2),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: engine.combo >= 2
                    ? Text('🔥 COMBO ×${engine.combo}',
                        key: ValueKey(engine.combo),
                        style: Workshop.label(14,
                            theme: t, color: t.accentLight))
                    : const SizedBox(width: 1, key: ValueKey('none')),
              ),
              Row(
                children: [
                  if (engine.wideT > 0)
                    _PowerChip(
                        theme: t,
                        emoji: '⟷',
                        secs: engine.wideT,
                        color: const Color(0xFFE08D52)),
                  if (engine.slowT > 0)
                    _PowerChip(
                        theme: t,
                        emoji: '🐌',
                        secs: engine.slowT,
                        color: const Color(0xFF9AC6D8)),
                  if (engine.laserT > 0)
                    _PowerChip(
                        theme: t,
                        emoji: '⚡',
                        secs: engine.laserT,
                        color: const Color(0xFFF2CE7E)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _modeLine() {
    if (engine.mode == CrusherMode.scoreAttack) {
      return 'SCORE ATTACK';
    }
    final tag =
        engine.mode == CrusherMode.endless ? 'ENDLESS' : 'LEVEL';
    return '$tag ${engine.level}';
  }

  String _fmtTime(double s) {
    final v = s.ceil();
    return '⏱ ${v ~/ 60}:${(v % 60).toString().padLeft(2, '0')}';
  }
}

class _PowerChip extends StatelessWidget {
  final CrusherThemeDef theme;
  final String emoji;
  final double secs;
  final Color color;
  const _PowerChip(
      {required this.theme,
      required this.emoji,
      required this.secs,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 6),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: color.withValues(alpha: 0.2),
        border: Border.all(color: color, width: 1.5),
      ),
      child: Text('$emoji ${secs.ceil()}s',
          style: Workshop.label(12, theme: theme, color: color)),
    );
  }
}

class _HintBar extends StatelessWidget {
  final CrusherEngine engine;
  final CrusherThemeDef theme;
  const _HintBar({required this.engine, required this.theme});

  @override
  Widget build(BuildContext context) {
    String hint;
    if (engine.phase == CrusherPhase.serving) {
      hint = 'Tap to launch the ball!';
    } else if (engine.laserT > 0) {
      hint = 'Tap to fire the laser • drag to move';
    } else {
      hint = 'Drag to move • catch the falling goodies';
    }
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Text(hint, style: Workshop.body(13, theme: theme)),
    );
  }
}

// ---------------------------------------------------------------------------
class _BannerOverlay extends StatelessWidget {
  final CrusherEngine engine;
  final CrusherThemeDef theme;
  const _BannerOverlay({required this.engine, required this.theme});

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return IgnorePointer(
      child: Container(
        color: Colors.black.withValues(alpha: 0.35),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(engine.banner,
                style: Workshop.display(36, theme: t),
                textAlign: TextAlign.center),
            if (engine.bannerSub.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(engine.bannerSub,
                  style: Workshop.body(16, theme: t),
                  textAlign: TextAlign.center),
            ],
          ],
        ),
      ),
    );
  }
}

class _PauseOverlay extends StatelessWidget {
  final CrusherThemeDef theme;
  final CrusherAudio audio;
  final VoidCallback onResume;
  final VoidCallback onRestart;
  final VoidCallback onQuit;
  const _PauseOverlay({
    required this.theme,
    required this.audio,
    required this.onResume,
    required this.onRestart,
    required this.onQuit,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return Container(
      color: Colors.black.withValues(alpha: 0.55),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          StonePlaque(
            theme: t,
            title: 'Paused',
            subtitle: 'Take a breath, smasher.',
          ),
          const SizedBox(height: 16),
          PlankButton(
              label: '▶  Resume', onTap: onResume, theme: t, width: 260),
          const SizedBox(height: 10),
          PlankButton(
              label: '↻  Restart', onTap: onRestart, theme: t, width: 260),
          const SizedBox(height: 10),
          PlankButton(label: '🏠  Menu', onTap: onQuit, theme: t, width: 260),
        ],
      ),
    );
  }
}

class _GameOverOverlay extends StatelessWidget {
  final CrusherEngine engine;
  final int best;
  final CrusherThemeDef theme;
  final CrusherAudio audio;
  final String playerName;
  final VoidCallback onRestart;
  final VoidCallback onQuit;
  const _GameOverOverlay({
    required this.engine,
    required this.best,
    required this.theme,
    required this.audio,
    required this.playerName,
    required this.onRestart,
    required this.onQuit,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final won = engine.won;
    final isNewBest = engine.score >= best && engine.score > 0;
    final title = won
        ? (engine.mode == CrusherMode.campaign
            ? 'DEMOLITION COMPLETE!'
            : 'TIME UP!')
        : 'GAME OVER';
    return Container(
      color: Colors.black.withValues(alpha: 0.6),
      alignment: Alignment.center,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            StonePlaque(
              theme: t,
              title: '$playerName — $title',
              subtitle: won
                  ? 'The workshop salutes you! 🏆'
                  : 'The bricks win this round!',
            ),
            const SizedBox(height: 14),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: t.bgDeep.withValues(alpha: 0.85),
                border: Border.all(color: t.accent, width: 2),
              ),
              child: Column(
                children: [
                  Text('${engine.score}',
                      style: Workshop.display(44, theme: t)),
                  if (isNewBest)
                    Text('🎉 NEW BEST! 🎉',
                        style: Workshop.label(15, theme: t)),
                  const SizedBox(height: 8),
                  _Stat('Best combo', '×${engine.bestCombo}', t),
                  _Stat('Bricks smashed', '${engine.bricksSmashed}', t),
                  if (engine.mode == CrusherMode.campaign)
                    _Stat('Levels cleared', '${engine.level - 1} / 5', t)
                  else
                    _Stat('Reached level', '${engine.level}', t),
                ],
              ),
            ),
            const SizedBox(height: 14),
            PlankButton(
                label: won ? '▶  Play Again' : '↻  Try Again',
                onTap: onRestart,
                theme: t,
                width: 260),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _RoundIcon(
                  theme: t,
                  icon: Icons.share,
                  label: 'Share',
                  onTap: () async {
                    audio.click();
                    await SharePlus.instance.share(ShareParams(
                        text:
                            'I scored ${engine.score} in Brick Crusher! Can you beat me? $_storeUrl'));
                  },
                ),
                const SizedBox(width: 18),
                _RoundIcon(
                  theme: t,
                  icon: Icons.star_rate,
                  label: 'Rate',
                  onTap: () async {
                    audio.click();
                    try {
                      final review = InAppReview.instance;
                      if (await review.isAvailable()) {
                        await review.requestReview();
                      } else {
                        await review.openStoreListing(appStoreId: null);
                      }
                    } catch (_) {}
                  },
                ),
                const SizedBox(width: 18),
                _RoundIcon(
                  theme: t,
                  icon: Icons.home,
                  label: 'Menu',
                  onTap: onQuit,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final CrusherThemeDef theme;
  const _Stat(this.label, this.value, this.theme);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label: ', style: Workshop.body(14, theme: theme)),
          Text(value, style: Workshop.label(14, theme: theme)),
        ],
      ),
    );
  }
}

class _RoundIcon extends StatelessWidget {
  final CrusherThemeDef theme;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _RoundIcon(
      {required this.theme,
      required this.icon,
      required this.label,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [theme.bg, theme.bgDeep],
              ),
              border: Border.all(color: theme.accent, width: 2.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.55),
                  offset: const Offset(0, 4),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Icon(icon, color: theme.accentLight, size: 26),
          ),
          const SizedBox(height: 6),
          Text(label, style: Workshop.label(12, theme: theme)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
/// Pseudo-3D painter: real material response — top-light bevels, drop
/// shadows, mortar gaps. Every style parameter comes from the catalogs.
class _CrusherPainter extends CustomPainter {
  final CrusherEngine engine;
  final CrusherThemeDef t;
  final PaddleStyleDef paddleStyle;
  final BallStyleDef ballStyle;
  final BrickStyleDef brickStyle;

  _CrusherPainter({
    required this.engine,
    required this.t,
    required this.paddleStyle,
    required this.ballStyle,
    required this.brickStyle,
  });

  Color _shade(Color c, double amt) {
    final hsl = HSLColor.fromColor(c);
    return hsl
        .withLightness((hsl.lightness + amt).clamp(0.0, 1.0))
        .toColor();
  }

  void _paintBricks(Canvas canvas) {
    for (var i = 0; i < engine.brickCount; i++) {
      if (!engine.brickAliveAt(i)) continue;
      final rect = engine.brickRectAt(i);
      final base = engine.brickThemeColorAt(i);
      final hits = engine.brickHitsAt(i);
      // Drop shadow.
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            rect.shift(const Offset(0, 3)),
            Radius.circular(brickStyle.radius)),
        Paint()..color = Colors.black.withValues(alpha: 0.35),
      );
      // Body with top-light bevel.
      final rr =
          RRect.fromRectAndRadius(rect, Radius.circular(brickStyle.radius));
      canvas.drawRRect(rr, Paint()..color = base);
      final bevel = brickStyle.bevel;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
              rect.left + bevel,
              rect.top + bevel,
              rect.width - bevel * 2,
              rect.height / 2 - bevel),
          Radius.circular(max(1, brickStyle.radius - bevel)),
        ),
        Paint()..color = _shade(base, 0.14),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(rect.left + bevel, rect.top + rect.height / 2,
              rect.width - bevel * 2, rect.height / 2 - bevel),
          Radius.circular(max(1, brickStyle.radius - bevel)),
        ),
        Paint()..color = _shade(base, -0.12),
      );
      // Surface pattern.
      final pat = Paint()
        ..color = _shade(base, -0.25)
        ..strokeWidth = 1.5;
      if (brickStyle.pattern == 1) {
        // cross mortar
        canvas.drawLine(rect.centerLeft, rect.centerRight, pat);
        canvas.drawLine(rect.topCenter, rect.bottomCenter, pat);
      } else if (brickStyle.pattern == 2) {
        // diagonal
        canvas.drawLine(rect.topLeft + const Offset(4, 4),
            rect.bottomRight - const Offset(4, 4), pat);
      } else if (brickStyle.pattern == 3) {
        // inner panel
        canvas.drawRRect(
          RRect.fromRectAndRadius(
              rect.deflate(6), const Radius.circular(3)),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..color = _shade(base, -0.22),
        );
      }
      // Multi-hit counter.
      if (hits > 1) {
        final tp = TextPainter(
          text: TextSpan(
              text: '$hits',
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                  shadows: [
                    Shadow(color: Colors.black, offset: Offset(0, 1))
                  ])),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, rect.center - Offset(tp.width / 2, tp.height / 2));
      }
    }
  }

  void _paintPaddle(Canvas canvas) {
    final w = engine.paddleW;
    final left = engine.paddleLeft;
    final y = engine.paddleY;
    const h = 16.0;
    final rect = Rect.fromLTWH(left, y, w, h);
    final radius = h * paddleStyle.radius;
    // Shadow.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          rect.shift(const Offset(0, 4)), Radius.circular(radius)),
      Paint()..color = Colors.black.withValues(alpha: 0.4),
    );
    // Body: vertical gradient, light on top.
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(radius)),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [t.paddleLight, t.paddleDark],
        ).createShader(rect),
    );
    // Bevel strip.
    final bh = h * paddleStyle.bevel;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(rect.left + 3, rect.top + 2, rect.width - 6, bh),
        Radius.circular(radius / 2),
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.28),
    );
    // End caps.
    if (paddleStyle.caps == 1) {
      for (final cx in [rect.left + 6, rect.right - 6]) {
        canvas.drawCircle(
            Offset(cx, rect.center.dy),
            5,
            Paint()
              ..shader = RadialGradient(colors: [
                t.accentLight,
                t.accentDark
              ]).createShader(Rect.fromCircle(
                  center: Offset(cx, rect.center.dy), radius: 5)));
      }
    } else if (paddleStyle.caps == 2) {
      final tip = Paint()..color = t.accentDark;
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(rect.left - 5, y + 2, 8, h - 4),
              const Radius.circular(3)),
          tip);
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(rect.right - 3, y + 2, 8, h - 4),
              const Radius.circular(3)),
          tip);
    }
    if (engine.laserT > 0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(radius)),
        Paint()..color = const Color(0xFFF2CE7E).withValues(alpha: 0.3),
      );
    }
  }

  void _paintBalls(Canvas canvas) {
    const r = 9.0;
    for (final ball in engine.balls) {
      _paintBall(canvas, ball.pos, r);
    }
    if (engine.phase == CrusherPhase.serving && engine.arena != Size.zero) {
      _paintBall(
          canvas,
          Offset(engine.paddleX * engine.arena.width, engine.paddleY - 14),
          r);
    }
  }

  void _paintBall(Canvas canvas, Offset c, double r) {
    canvas.drawCircle(
        c + const Offset(0, 2), r, Paint()..color = Colors.black.withValues(alpha: 0.35));
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.35, -0.4),
          radius: 1.1,
          colors: [t.ballCore, t.ballRim],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
    // Style highlight.
    canvas.drawCircle(
      c + Offset(-r * 0.3, -r * 0.35),
      r * ballStyle.highlight,
      Paint()..color = Colors.white.withValues(alpha: 0.75),
    );
    if (ballStyle.rings == 1) {
      canvas.drawCircle(
        c,
        r * 0.62,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = t.ballRim.withValues(alpha: 0.8),
      );
    } else if (ballStyle.rings == 2) {
      canvas.drawCircle(
          c + Offset(r * 0.35, r * 0.3),
          r * 0.22,
          Paint()..color = Colors.white.withValues(alpha: 0.5));
    }
  }

  void _paintDrops(Canvas canvas) {
    const labels = ['×2', 'W', 'S', '⚡'];
    const cols = [
      Color(0xFF7FB069),
      Color(0xFFE08D52),
      Color(0xFF9AC6D8),
      Color(0xFFF2CE7E),
    ];
    for (final d in engine.drops) {
      final rect =
          Rect.fromCenter(center: d.pos, width: 32, height: 32);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            rect.shift(const Offset(0, 3)), const Radius.circular(9)),
        Paint()..color = Colors.black.withValues(alpha: 0.35),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(9)),
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_shade(cols[d.kind], 0.15), _shade(cols[d.kind], -0.15)],
          ).createShader(rect),
      );
      final tp = TextPainter(
        text: TextSpan(
            text: labels[d.kind],
            style: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w900,
                fontSize: 14)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, d.pos - Offset(tp.width / 2, tp.height / 2));
    }
  }

  void _paintBolts(Canvas canvas) {
    for (final b in engine.bolts) {
      final rect = Rect.fromCenter(center: b.pos, width: 6, height: 20);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(3)),
        Paint()..color = const Color(0xFFF2CE7E),
      );
    }
  }

  void _paintPopups(Canvas canvas) {
    final now = DateTime.now();
    for (final p in engine.popups) {
      final age = now.difference(p.bornAt).inMilliseconds / 900;
      final pos = p.pos + Offset(0, -46 * age);
      final tp = TextPainter(
        text: TextSpan(
          text: '+${p.points}',
          style: TextStyle(
            color: t.accentLight.withValues(alpha: 1 - age),
            fontWeight: FontWeight.w900,
            fontSize: 17,
            shadows: const [
              Shadow(color: Colors.black, offset: Offset(0, 1))
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, pos - Offset(tp.width / 2, tp.height / 2));
    }
  }

  void _paintDebris(Canvas canvas) {
    final now = DateTime.now();
    for (final d in engine.debris) {
      final age = now.difference(d.bornAt).inMilliseconds / 700;
      canvas.save();
      canvas.translate(d.pos.dx, d.pos.dy);
      canvas.rotate(d.rot);
      canvas.drawRect(
        Rect.fromCenter(center: Offset.zero, width: d.size, height: d.size * 0.7),
        Paint()..color = d.color.withValues(alpha: 1 - age * 0.5),
      );
      canvas.restore();
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = t.bg,
    );
    _paintBricks(canvas);
    _paintDebris(canvas);
    _paintPaddle(canvas);
    _paintBalls(canvas);
    _paintDrops(canvas);
    _paintBolts(canvas);
    _paintPopups(canvas);
  }

  @override
  bool shouldRepaint(covariant _CrusherPainter old) => true;
}
