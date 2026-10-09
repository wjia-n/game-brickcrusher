import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/foundation.dart';

// ---------------------------------------------------------------------------
// Brick Crusher engine: deterministic rules, all phases owned here.
// The UI renders; a watchdog recovers any phase found without a live timer.
// ---------------------------------------------------------------------------

/// Difficulty tiers: speed + layout complexity scale up.
enum CrusherDifficulty { chill, classic, wild, insane }

/// Game modes: campaign (5 levels), endless (infinite), scoreAttack (2 min).
enum CrusherMode { campaign, endless, scoreAttack }

/// Phases owned entirely by the engine. The UI only renders.
enum CrusherPhase {
  /// Ball sits on the paddle, waiting for a launch tap.
  serving,

  /// Balls in flight, physics live.
  playing,

  /// A banner is up (level intro, life lost, combo milestone): a timer is
  /// armed to move on. Input is locked.
  banner,

  /// User- or lifecycle-paused. Timers are frozen; resume re-arms.
  paused,

  /// Run finished: victory or game over. Terminal.
  over,
}

enum CrusherEvent {
  launch,
  paddleHit,
  wallHit,
  brickCrack,
  brickBreak,
  combo,
  powerUp,
  laserFire,
  lifeLost,
  levelClear,
  invalid,
  win,
  lose,
}

class _Brick {
  final int row, col;
  final int hits0;
  int hits;
  bool alive = true;
  _Brick(this.row, this.col, this.hits, this.hits0);
}

class CrusherBall {
  Offset pos;
  Offset vel;
  CrusherBall(this.pos, this.vel);
}

class CrusherDrop {
  Offset pos;
  final int kind; // 0 multi, 1 wide, 2 slow, 3 laser
  CrusherDrop(this.pos, this.kind);
}

class CrusherBolt {
  Offset pos;
  CrusherBolt(this.pos);
}

/// Floating "+250" score popup. The logical score is applied at once;
/// the UI animates the popup.
class ScorePopup {
  final Offset pos;
  final int points;
  final DateTime bornAt = DateTime.now();
  ScorePopup(this.pos, this.points);
}

/// Brick particle chunk flying out of a smashed brick.
class Debris {
  Offset pos;
  Offset vel;
  final Color color;
  final double size;
  double rot = 0;
  final DateTime bornAt = DateTime.now();
  Debris(this.pos, this.vel, this.color, this.size);
}

const crusherDifficultyNames = ['Chill', 'Classic', 'Wild', 'Insane'];
const crusherModeNames = ['Campaign', 'Endless', 'Score Attack'];

/// Base ball speeds (px/s) per difficulty tier.
const _baseSpeeds = [300.0, 375.0, 460.0, 560.0];

/// Base brick rows per difficulty tier.
const _baseRows = [3, 4, 5, 6];

class CrusherEngine extends ChangeNotifier {
  final CrusherDifficulty difficulty;
  final CrusherMode mode;

  final _rand = Random();

  // ---- run state ----------------------------------------------------------
  CrusherPhase phase = CrusherPhase.serving;
  bool over = false;
  bool won = false; // true = campaign victory
  int level = 1;
  int lives = 3;
  int score = 0;
  int combo = 0;
  int bestCombo = 0;
  int bricksSmashed = 0;
  String banner = '';
  String bannerSub = '';

  // ---- world --------------------------------------------------------------
  final List<_Brick> bricks = [];
  final List<CrusherBall> balls = [];
  final List<CrusherDrop> drops = [];
  final List<CrusherBolt> bolts = [];
  final List<ScorePopup> popups = [];
  final List<Debris> debris = [];

  double paddleX = 0.5; // fraction of arena width
  double wideT = 0;
  double slowT = 0;
  double laserT = 0;

  /// Arena size, set by the UI each frame.
  Size arena = Size.zero;

  // Score Attack countdown (seconds).
  double timeLeft = 120;

  /// Level-clear bonus waiting to be awarded. Kept separate so a banner that
  /// is re-armed after a pause (or recovered by the watchdog) can never
  /// double-award — or silently lose — the bonus.
  int _pendingBonus = 0;

  // ---- timers ---------------------------------------------------------------
  Timer? _timer; // single phase-transition timer
  Timer? _watchdog; // stuck-state recovery
  bool _disposed = false;
  bool _bannerPause = false; // true when banner was entered from pause

  /// UI hook for sounds / haptics. Set by the screen.
  void Function(CrusherEvent event)? onEvent;

  CrusherEngine({
    this.difficulty = CrusherDifficulty.classic,
    this.mode = CrusherMode.campaign,
  }) {
    _buildLevel();
    _watchdog = Timer.periodic(const Duration(seconds: 3), (_) => _recover());
  }

  // ------------------------------------------------------------ derived data
  double get ballSpeed =>
      (_baseSpeeds[difficulty.index] + (level - 1) * 30) *
      (slowT > 0 ? 0.7 : 1.0);

  double get paddleW =>
      arena.width * (wideT > 0 ? 0.46 : 0.30);

  double get paddleY => arena.height - 56;

  double get paddleLeft => paddleX * arena.width - paddleW / 2;

  bool get serving => phase == CrusherPhase.serving;

  bool get isBanner =>
      phase == CrusherPhase.banner || phase == CrusherPhase.paused;

  /// Lives for the current mode/difficulty.
  int get _startLives => difficulty == CrusherDifficulty.insane ? 2 : 3;

  Rect _brickRect(_Brick b) {
    const pad = 4.0;
    final w = arena.width / _cols;
    const top = 72.0;
    const h = 30.0;
    return Rect.fromLTWH(
        b.col * w + pad / 2, top + b.row * (h + pad), w - pad, h);
  }

  int get _cols => 7;

  // ------------------------------------------------------------ level build
  void _buildLevel() {
    final rows = _baseRows[difficulty.index] + (level - 1) ~/ 2;
    bricks.clear();
    balls.clear();
    drops.clear();
    bolts.clear();
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < _cols; c++) {
        var hits = 1;
        final hard = difficulty.index >= 2 ? 1 : 2;
        if ((r + c + level) % 3 == 0) hits = 2;
        if (level >= 3 && (r * 3 + c + level) % 7 == 0) hits = 3;
        if (level >= 5 && difficulty.index >= hard && (r * c) % 11 == 0) {
          hits = 4;
        }
        bricks.add(_Brick(r, c, hits, hits));
      }
    }
    paddleX = 0.5;
    wideT = 0;
    slowT = 0;
    laserT = 0;
    combo = 0;
  }

  // ------------------------------------------------------------ phase flow
  /// Enter a banner phase: input locked, a timer moves on. This is what
  /// makes silent/missed transitions impossible — every banner has an armed
  /// timer and the watchdog re-arms any banner found without one.
  void _showBanner(String title, String sub, Duration hold, void Function() next) {
    banner = title;
    bannerSub = sub;
    phase = CrusherPhase.banner;
    notifyListeners();
    _arm(hold, () {
      if (_disposed || over) return;
      next();
    });
  }

  void _arm(Duration d, void Function() fn) {
    if (_disposed || phase == CrusherPhase.paused) return;
    _timer?.cancel();
    _timer = Timer(d, () {
      _timer = null;
      if (!_disposed && phase != CrusherPhase.paused) fn();
    });
  }

  /// Watchdog: recover any phase found without a live phase timer.
  /// Makes stuck states impossible by construction. Respects paused.
  void _recover() {
    if (_disposed || over || phase == CrusherPhase.paused || _timer != null) {
      return;
    }
    if (phase == CrusherPhase.serving) {
      // Serving with no timer is a stable wait state — nothing to recover.
      return;
    }
    if (phase == CrusherPhase.playing) {
      if (balls.isEmpty) {
        _loseLife(); // balls vanished without settling: lose a life cleanly
      }
      return;
    }
    if (phase == CrusherPhase.banner) {
      // Banner with no timer (e.g. app was backgrounded mid-transition):
      // dismiss and continue to the only legal forward state.
      _dismissBanner();
    }
  }

  /// The single forward step a banner can legally take. Order matters:
  /// finished run → level clear → still serving → playing.
  /// Awards any pending level-clear bonus first, so a pause/watchdog
  /// recovery mid-banner can never lose it.
  void _dismissBanner() {
    if (over) return;
    if (bricks.every((b) => !b.alive)) {
      if (_pendingBonus > 0) {
        score += _pendingBonus;
        _pendingBonus = 0;
      }
      _advanceLevel();
    } else if (phase == CrusherPhase.serving || balls.isEmpty) {
      phase = CrusherPhase.serving;
      notifyListeners();
    } else {
      phase = CrusherPhase.playing;
      notifyListeners();
    }
  }

  // ------------------------------------------------------------ player input
  /// Tap: launch from serving, or fire the laser while laser power is up.
  void tapAction() {
    if (over || phase == CrusherPhase.paused) return;
    if (phase == CrusherPhase.banner) return; // input locked during banners
    if (phase == CrusherPhase.serving) {
      _launch();
    } else if (phase == CrusherPhase.playing && laserT > 0) {
      bolts.add(CrusherBolt(Offset(paddleX * arena.width, paddleY - 12)));
      onEvent?.call(CrusherEvent.laserFire);
    }
  }

  void movePaddle(double xFraction) {
    if (over || phase == CrusherPhase.paused) return;
    paddleX = xFraction.clamp(0.0, 1.0);
  }

  void _launch() {
    if (phase != CrusherPhase.serving || arena == Size.zero) return;
    phase = CrusherPhase.playing;
    final s = ballSpeed;
    final a = -pi / 2 + (_rand.nextDouble() - 0.5) * 0.7;
    balls.add(CrusherBall(
      Offset(paddleX * arena.width, paddleY - 14),
      Offset(cos(a) * s, sin(a) * s),
    ));
    onEvent?.call(CrusherEvent.launch);
    notifyListeners();
  }

  // ------------------------------------------------------------ scoring
  void _addScore(int pts, Offset at) {
    score += pts;
    if (at != Offset.zero) {
      popups.add(ScorePopup(at, pts));
    }
    // Score popups expire on their own; watchdog of the UI trims them.
    notifyListeners();
  }

  // ------------------------------------------------------------ collisions
  void _damageBrick(_Brick b, Offset hitAt, Color brickColor) {
    b.hits--;
    if (b.hits <= 0) {
      b.alive = false;
      bricksSmashed++;
      combo++;
      bestCombo = max(bestCombo, combo);
      final mult = (1 + combo * 0.1).clamp(1.0, 3.0);
      final pts = (10 * level * b.hits0 * mult).round();
      _addScore(pts, hitAt);
      onEvent?.call(CrusherEvent.brickBreak);
      // Debris burst: physical brick chunks.
      final r = _brickRect(b);
      for (int i = 0; i < 6; i++) {
        debris.add(Debris(
          Offset(r.center.dx + (_rand.nextDouble() - 0.5) * r.width * 0.6,
              r.center.dy + (_rand.nextDouble() - 0.5) * r.height * 0.6),
          Offset((_rand.nextDouble() - 0.5) * 320,
              -60 - _rand.nextDouble() * 220),
          brickColor,
          4 + _rand.nextDouble() * 7,
        ));
      }
      if (combo > 0 && combo % 10 == 0) {
        onEvent?.call(CrusherEvent.combo);
      }
      if (_rand.nextDouble() < 0.24) {
        drops.add(CrusherDrop(_brickRect(b).center, _rand.nextInt(4)));
      }
      if (bricks.every((x) => !x.alive)) _levelCleared();
    } else {
      _addScore(2 * level, Offset.zero);
      onEvent?.call(CrusherEvent.brickCrack);
    }
  }

  void _levelCleared() {
    onEvent?.call(CrusherEvent.levelClear);
    balls.clear();
    drops.clear();
    bolts.clear();
    if (mode == CrusherMode.campaign && level >= 5) {
      _finish(true);
      return;
    }
    final nextLevel = level + 1;
    final bonus = 50 * level;
    _pendingBonus = bonus;
    _showBanner(
      'LEVEL $level CLEARED!',
      '+$bonus bonus • ${(mode == CrusherMode.endless || mode == CrusherMode.scoreAttack) ? 'keep smashing!' : 'level $nextLevel incoming'}',
      const Duration(milliseconds: 1500),
      () {
        score += _pendingBonus;
        _pendingBonus = 0;
        level = nextLevel;
        _buildLevel();
        phase = CrusherPhase.serving;
        banner = '';
        notifyListeners();
      },
    );
  }

  void _loseLife() {
    if (over) return;
    lives--;
    balls.clear();
    drops.clear();
    bolts.clear();
    combo = 0;
    wideT = 0;
    slowT = 0;
    laserT = 0;
    if (lives <= 0) {
      _finish(false);
      return;
    }
    onEvent?.call(CrusherEvent.lifeLost);
    _showBanner(
      'BALL LOST!',
      '$lives ${lives == 1 ? 'life' : 'lives'} left — steady…',
      const Duration(milliseconds: 1300),
      () {
        phase = CrusherPhase.serving;
        banner = '';
        notifyListeners();
      },
    );
  }

  void _finish(bool victory) {
    over = true;
    won = victory;
    phase = CrusherPhase.over;
    _timer?.cancel();
    banner = '';
    notifyListeners();
    onEvent?.call(victory ? CrusherEvent.win : CrusherEvent.lose);
  }

  // ------------------------------------------------------------ pause
  /// Pause: freeze the phase timer. Resume re-arms the current phase.
  void setPaused(bool v) {
    if (_disposed || over) return;
    if (v && phase != CrusherPhase.paused) {
      _bannerPause = phase == CrusherPhase.banner;
      _timer?.cancel();
      _timer = null;
      phase = CrusherPhase.paused;
      notifyListeners();
    } else if (!v && phase == CrusherPhase.paused) {
      // Resume: banners re-show and re-arm; play/serving continue directly.
      if (_bannerPause) {
        _bannerPause = false;
        final t = banner, s = bannerSub;
        _showBanner(t, s, const Duration(milliseconds: 900), _dismissBanner);
      } else if (bricks.every((b) => !b.alive)) {
        _advanceLevel();
      } else if (balls.isEmpty && !over) {
        phase = CrusherPhase.serving;
        notifyListeners();
      } else {
        phase = CrusherPhase.playing;
        notifyListeners();
      }
    }
  }

  void _advanceLevel() {
    if (over) return;
    level++;
    _buildLevel();
    phase = CrusherPhase.serving;
    banner = '';
    notifyListeners();
  }

  // ------------------------------------------------------------ power-ups
  void _applyPower(int kind) {
    onEvent?.call(CrusherEvent.powerUp);
    switch (kind) {
      case 0: // multiball
        final s = ballSpeed;
        final clones = balls
            .map((b) {
              final a = atan2(b.vel.dy, b.vel.dx) + 0.6;
              return CrusherBall(b.pos, Offset(cos(a) * s, sin(a) * s));
            })
            .toList();
        balls.addAll(clones);
        if (phase == CrusherPhase.serving) _launch();
      case 1:
        wideT = 12;
      case 2:
        slowT = 12;
      case 3:
        laserT = 10;
    }
    notifyListeners();
  }

  // ------------------------------------------------------------ frame update
  /// Called every frame by the UI ticker. Physics only — phase transitions
  /// stay on engine-owned timers.
  void update(double dt) {
    if (_disposed || over) return;
    if (phase == CrusherPhase.paused || phase == CrusherPhase.banner) return;
    if (arena == Size.zero) return;

    wideT = max(0, wideT - dt);
    slowT = max(0, slowT - dt);
    laserT = max(0, laserT - dt);

    // Score-attack countdown.
    if (mode == CrusherMode.scoreAttack && phase == CrusherPhase.playing) {
      timeLeft -= dt;
      if (timeLeft <= 0) {
        timeLeft = 0;
        _finish(true); // time up = victory over the clock
        return;
      }
    }

    // Expire popups / debris (UI reads them; trimming here keeps lists small).
    final now = DateTime.now();
    popups.removeWhere(
        (p) => now.difference(p.bornAt).inMilliseconds > 900);
    debris.removeWhere(
        (d) => now.difference(d.bornAt).inMilliseconds > 700);

    // Debris physics.
    for (final d in debris) {
      d.vel = d.vel + const Offset(0, 900) * dt;
      d.pos = d.pos + d.vel * dt;
      d.rot += dt * 6;
    }

    // Clamp paddle inside the arena.
    final half = paddleW / 2 / arena.width;
    paddleX = paddleX.clamp(half, 1 - half);

    // Falling power-up drops.
    for (var i = drops.length - 1; i >= 0; i--) {
      final d = drops[i];
      d.pos = d.pos + Offset(0, 160 * dt);
      final pr = Rect.fromLTWH(paddleLeft, paddleY, paddleW, 16);
      if (pr.contains(d.pos)) {
        _applyPower(d.kind);
        drops.removeAt(i);
      } else if (d.pos.dy > arena.height) {
        drops.removeAt(i);
      }
    }

    // Laser bolts. Snapshot iteration: _damageBrick can clear the list
    // (level cleared mid-flight); remove() is then a safe no-op.
    for (final b in List.of(bolts)) {
      b.pos = b.pos + Offset(0, -560 * dt);
      var hit = false;
      for (final br in bricks) {
        if (br.alive && _brickRect(br).contains(b.pos)) {
          _damageBrick(br, b.pos, _brickColor(br));
          hit = true;
          break;
        }
      }
      if (hit || b.pos.dy < 0 || phase != CrusherPhase.playing) {
        bolts.remove(b);
      }
    }

    // Balls (substepped so fast balls can't tunnel). Snapshot iteration:
    // a collision can clear the whole list (level cleared → banner), so we
    // never index the live list, and we bail out of the step loop the
    // moment the phase changes.
    if (phase == CrusherPhase.playing) {
      for (final ball in List.of(balls)) {
        var remaining = ballSpeed * dt;
        while (remaining > 0) {
          final step = min(remaining, 6.0);
          final dir = ball.vel / ball.vel.distance;
          ball.pos = ball.pos + dir * step;
          remaining -= step;
          _collide(ball);
          if (phase != CrusherPhase.playing || over) break;
          if (ball.pos.dy - 10 > arena.height) break;
        }
        if (!balls.contains(ball)) continue;
        if (ball.pos.dy - 10 > arena.height) balls.remove(ball);
      }
      // A life is lost ONLY if we are still in the playing phase with no
      // balls — never after a level clear switched us to the banner.
      if (phase == CrusherPhase.playing && balls.isEmpty) _loseLife();
    }
  }

  // Brick color comes from the UI theme; the engine needs it for debris.
  Color Function(_Brick b)? brickColorFor;
  Color _brickColor(_Brick b) =>
      brickColorFor?.call(b) ?? const Color(0xFFC96A3B);

  void _collide(CrusherBall ball) {
    const r = 9.0;
    // Walls.
    if (ball.pos.dx < r) {
      ball.pos = Offset(r, ball.pos.dy);
      ball.vel = Offset(ball.vel.dx.abs(), ball.vel.dy);
      onEvent?.call(CrusherEvent.wallHit);
    } else if (ball.pos.dx > arena.width - r) {
      ball.pos = Offset(arena.width - r, ball.pos.dy);
      ball.vel = Offset(-ball.vel.dx.abs(), ball.vel.dy);
      onEvent?.call(CrusherEvent.wallHit);
    }
    if (ball.pos.dy < r + 56) {
      ball.pos = Offset(ball.pos.dx, r + 56);
      ball.vel = Offset(ball.vel.dx, ball.vel.dy.abs());
      onEvent?.call(CrusherEvent.wallHit);
    }
    // Paddle.
    final pr = Rect.fromLTWH(paddleLeft, paddleY, paddleW, 16);
    if (ball.vel.dy > 0 &&
        ball.pos.dy + r >= pr.top &&
        ball.pos.dy - r <= pr.bottom &&
        ball.pos.dx >= pr.left - r &&
        ball.pos.dx <= pr.right + r) {
      final rel = ((ball.pos.dx - pr.left) / pr.width).clamp(0.02, 0.98);
      final ang = (rel - 0.5) * 1.6;
      final s = ballSpeed;
      ball.vel = Offset(sin(ang) * s, -cos(ang).abs() * s);
      ball.pos = Offset(ball.pos.dx, pr.top - r - 1);
      combo = 0; // combo breaks on paddle touch
      onEvent?.call(CrusherEvent.paddleHit);
    }
    // Bricks.
    for (final b in bricks) {
      if (!b.alive) continue;
      final rect = _brickRect(b);
      final cx = ball.pos.dx.clamp(rect.left, rect.right);
      final cy = ball.pos.dy.clamp(rect.top, rect.bottom);
      final dx = ball.pos.dx - cx, dy = ball.pos.dy - cy;
      if (dx * dx + dy * dy <= r * r) {
        final overlapX = r - dx.abs();
        final overlapY = r - dy.abs();
        if (overlapX < overlapY) {
          ball.vel = Offset(
              dx >= 0 ? ball.vel.dx.abs() : -ball.vel.dx.abs(), ball.vel.dy);
        } else {
          ball.vel = Offset(
              ball.vel.dx, dy >= 0 ? ball.vel.dy.abs() : -ball.vel.dy.abs());
        }
        _damageBrick(b, ball.pos, _brickColor(b));
        break;
      }
    }
  }

  // ------------------------------------------------------------ lifecycle
  /// Start a fresh run with the current difficulty/mode.
  void restart() {
    _timer?.cancel();
    level = 1;
    lives = _startLives;
    score = 0;
    combo = 0;
    bestCombo = 0;
    bricksSmashed = 0;
    timeLeft = 120;
    over = false;
    won = false;
    banner = '';
    bannerSub = '';
    popups.clear();
    debris.clear();
    _pendingBonus = 0;
    _buildLevel();
    phase = CrusherPhase.serving;
    notifyListeners();
  }

  // ------------------------------------------------- public view accessors
  // The painter lives in another library, so it gets read-only views.
  int get brickCount => bricks.length;

  Rect brickRectAt(int i) => _brickRect(bricks[i]);

  int brickRowAt(int i) => bricks[i].row;

  int brickHitsAt(int i) => bricks[i].hits;

  int brickHits0At(int i) => bricks[i].hits0;

  bool brickAliveAt(int i) => bricks[i].alive;

  Color brickThemeColorAt(int i) => _brickColor(bricks[i]);

  // ------------------------------------------------- test hooks
  /// Place a ball directly (tests). Moves serving → playing.
  @visibleForTesting
  void debugPlaceBall(Offset pos, Offset vel) {
    balls.add(CrusherBall(pos, vel));
    if (phase == CrusherPhase.serving) phase = CrusherPhase.playing;
  }

  /// Drop the armed phase timer (tests): simulates a banner/phase that lost
  /// its timer, so the watchdog has to recover it.
  @visibleForTesting
  void debugDropPhaseTimer() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _watchdog?.cancel();
    super.dispose();
  }
}
