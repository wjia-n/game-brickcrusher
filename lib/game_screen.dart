import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:wajiha_game_core/wajiha_game_core.dart';

enum _Power { multi, wide, slow, laser }

class _Brick {
  final int row, col, hits0;
  int hits;
  bool alive = true;
  _Brick(this.row, this.col, this.hits, this.hits0);
}

class _Ball {
  Offset pos;
  Offset vel;
  _Ball(this.pos, this.vel);
}

class _Drop {
  Offset pos;
  final _Power kind;
  _Drop(this.pos, this.kind);
}

class _Bolt {
  Offset pos;
  _Bolt(this.pos);
}

class BrickCrusherScreen extends StatefulWidget {
  final List<Player> players;
  final GameCallbacks callbacks;
  const BrickCrusherScreen({super.key, required this.players, required this.callbacks});

  @override
  State<BrickCrusherScreen> createState() => _BrickCrusherScreenState();
}

class _BrickCrusherScreenState extends State<BrickCrusherScreen> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Duration _last = Duration.zero;
  Size _area = Size.zero;

  double _paddleX = 0.5;
  int _cols = 7, _rows = 4;
  final List<_Brick> _bricks = [];
  final List<_Ball> _balls = [];
  final List<_Drop> _drops = [];
  final List<_Bolt> _bolts = [];

  bool _serving = true;
  bool _over = false;
  int _level = 1, _lives = 3;
  double _wideT = 0, _slowT = 0, _laserT = 0;
  String _banner = '';
  double _bannerT = 0;
  final _rnd = Random();

  static const _palette = [
    Colors.redAccent,
    Colors.orangeAccent,
    Colors.amber,
    Colors.lightGreen,
    Colors.cyan,
    Colors.lightBlue,
  ];

  @override
  void initState() {
    super.initState();
    _buildLevel();
    _ticker = createTicker(_tick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _buildLevel() {
    _rows = 3 + _level;
    _cols = 7;
    _bricks.clear();
    for (var r = 0; r < _rows; r++) {
      for (var c = 0; c < _cols; c++) {
        var hits = 1;
        if ((r + c + _level) % 3 == 0) hits = 2;
        if (_level >= 4 && (r * 3 + c) % 7 == 0) hits = 3;
        _bricks.add(_Brick(r, c, hits, hits));
      }
    }
    _balls.clear();
    _drops.clear();
    _bolts.clear();
    _paddleX = 0.5;
    _serving = true;
    _wideT = 0;
    _slowT = 0;
    _laserT = 0;
    _banner = 'LEVEL $_level';
    _bannerT = 1.6;
  }

  double get _speed => (330 + _level * 40) * (_slowT > 0 ? 0.7 : 1.0);
  double get _paddleW => _area.width * (_wideT > 0 ? 0.44 : 0.28);
  double get _paddleY => _area.height - 44;
  double get _paddleLeft => _paddleX * _area.width - _paddleW / 2;

  Rect _brickRect(_Brick b) {
    final pad = 4.0;
    final w = _area.width / _cols;
    final top = 56.0;
    final h = 26.0;
    return Rect.fromLTWH(b.col * w + pad / 2, top + b.row * (h + pad), w - pad, h);
  }

  void _launch() {
    if (!_serving || _over) return;
    _serving = false;
    final s = _speed;
    final a = -pi / 2 + (_rnd.nextDouble() - 0.5) * 0.8;
    _balls.add(_Ball(
      Offset(_paddleX * _area.width, _paddleY - 12),
      Offset(cos(a) * s, sin(a) * s),
    ));
    Sfx.tap();
  }

  void _addScore(int pts) {
    widget.players[0].score += pts;
    widget.callbacks.refreshHud();
  }

  void _damageBrick(_Brick b) {
    b.hits--;
    if (b.hits <= 0) {
      b.alive = false;
      _addScore(10 * _level * b.hits0);
      Sfx.click();
      if (_rnd.nextDouble() < 0.22) {
        _drops.add(_Drop(_brickRect(b).center, _Power.values[_rnd.nextInt(4)]));
      }
      if (_bricks.every((x) => !x.alive)) _levelCleared();
    } else {
      Sfx.tap();
    }
  }

  void _levelCleared() {
    if (_level >= 5) {
      _finish(true);
    } else {
      _level++;
      _buildLevel();
      Sfx.win();
    }
  }

  void _loseBall() {
    if (_over) return;
    _lives--;
    if (_lives <= 0) {
      _finish(false);
    } else {
      _serving = true;
      _balls.clear();
      Sfx.lose();
    }
  }

  void _finish(bool won) {
    if (_over) return;
    _over = true;
    _ticker.stop();
    final s = widget.players[0].score;
    if (won) {
      Sfx.win();
      widget.callbacks.finish(
        headline: 'Demolition complete! 🏆',
        subline: 'You smashed all 5 levels with $s points.',
      );
    } else {
      Sfx.lose();
      widget.callbacks.finish(
        headline: 'The bricks win this round!',
        subline: 'Final score: $s. One more go?',
      );
    }
  }

  void _tick(Duration now) {
    if (_over || _area == Size.zero) {
      _last = now;
      return;
    }
    final dt = min((now - _last).inMicroseconds / 1e6, 1 / 30);
    _last = now;

    _wideT = max(0, _wideT - dt);
    _slowT = max(0, _slowT - dt);
    _laserT = max(0, _laserT - dt);
    _bannerT = max(0, _bannerT - dt);

    // paddle clamp
    final half = _paddleW / 2 / _area.width;
    _paddleX = _paddleX.clamp(half, 1 - half);

    // drops
    for (var i = _drops.length - 1; i >= 0; i--) {
      final d = _drops[i];
      d.pos = d.pos + Offset(0, 150 * dt);
      final pr = Rect.fromLTWH(_paddleLeft, _paddleY, _paddleW, 14);
      if (pr.contains(d.pos)) {
        _applyPower(d.kind);
        _drops.removeAt(i);
      } else if (d.pos.dy > _area.height) {
        _drops.removeAt(i);
      }
    }

    // bolts
    for (var i = _bolts.length - 1; i >= 0; i--) {
      final b = _bolts[i];
      b.pos = b.pos + Offset(0, -520 * dt);
      var hit = false;
      for (final br in _bricks) {
        if (br.alive && _brickRect(br).contains(b.pos)) {
          _damageBrick(br);
          hit = true;
          break;
        }
      }
      if (hit || b.pos.dy < 0) _bolts.removeAt(i);
    }

    // balls (substepped)
    if (!_serving) {
      for (var i = _balls.length - 1; i >= 0; i--) {
        final ball = _balls[i];
        var remaining = _speed * dt;
        while (remaining > 0) {
          final step = min(remaining, 6.0);
          final dir = ball.vel / ball.vel.distance;
          ball.pos = ball.pos + dir * step;
          remaining -= step;
          _collide(ball);
          if (ball.pos.dy - 8 > _area.height) break;
        }
        if (ball.pos.dy - 8 > _area.height) _balls.removeAt(i);
      }
      if (_balls.isEmpty) _loseBall();
    }

    if (mounted) setState(() {});
  }

  void _collide(_Ball ball) {
    const r = 8.0;
    // walls
    if (ball.pos.dx < r) {
      ball.pos = Offset(r, ball.pos.dy);
      ball.vel = Offset(ball.vel.dx.abs(), ball.vel.dy);
      Sfx.tap();
    } else if (ball.pos.dx > _area.width - r) {
      ball.pos = Offset(_area.width - r, ball.pos.dy);
      ball.vel = Offset(-ball.vel.dx.abs(), ball.vel.dy);
      Sfx.tap();
    }
    if (ball.pos.dy < r + 40) {
      ball.pos = Offset(ball.pos.dx, r + 40);
      ball.vel = Offset(ball.vel.dx, ball.vel.dy.abs());
      Sfx.tap();
    }
    // paddle
    final pr = Rect.fromLTWH(_paddleLeft, _paddleY, _paddleW, 14);
    if (ball.vel.dy > 0 &&
        ball.pos.dy + r >= pr.top &&
        ball.pos.dy - r <= pr.bottom &&
        ball.pos.dx >= pr.left - r &&
        ball.pos.dx <= pr.right + r) {
      final rel = ((ball.pos.dx - pr.left) / pr.width).clamp(0.02, 0.98);
      final ang = (rel - 0.5) * 1.5;
      final s = _speed;
      ball.vel = Offset(sin(ang) * s, -cos(ang).abs() * s);
      ball.pos = Offset(ball.pos.dx, pr.top - r - 1);
      Sfx.move();
    }
    // bricks
    for (final b in _bricks) {
      if (!b.alive) continue;
      final rect = _brickRect(b);
      final cx = ball.pos.dx.clamp(rect.left, rect.right);
      final cy = ball.pos.dy.clamp(rect.top, rect.bottom);
      final dx = ball.pos.dx - cx, dy = ball.pos.dy - cy;
      if (dx * dx + dy * dy <= r * r) {
        // bounce on the shallower axis
        final overlapX = r - dx.abs();
        final overlapY = r - dy.abs();
        if (overlapX < overlapY) {
          ball.vel = Offset(dx >= 0 ? ball.vel.dx.abs() : -ball.vel.dx.abs(), ball.vel.dy);
        } else {
          ball.vel = Offset(ball.vel.dx, dy >= 0 ? ball.vel.dy.abs() : -ball.vel.dy.abs());
        }
        _damageBrick(b);
        break;
      }
    }
  }

  void _applyPower(_Power p) {
    Sfx.win();
    switch (p) {
      case _Power.multi:
        final clones = _balls
            .map((b) {
              final s = _speed;
              final a = atan2(b.vel.dy, b.vel.dx) + 0.5;
              return _Ball(b.pos, Offset(cos(a) * s, sin(a) * s));
            })
            .toList();
        _balls.addAll(clones);
        if (_serving) _launch();
      case _Power.wide:
        _wideT = 12;
      case _Power.slow:
        _slowT = 12;
      case _Power.laser:
        _laserT = 10;
    }
  }

  void _onTapDown(TapDownDetails d) {
    if (_over) return;
    if (_serving) {
      _launch();
    } else if (_laserT > 0 && _area != Size.zero) {
      _bolts.add(_Bolt(Offset(_paddleX * _area.width, _paddleY - 10)));
      Sfx.click();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeController.of(context).theme;
    return Column(
      children: [
        ScoreChips(players: widget.players, activeIndex: 0),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('❤️ × $_lives', style: TextStyle(color: theme.text, fontWeight: FontWeight.bold)),
              Text('LEVEL $_level / 5', style: TextStyle(color: theme.muted, fontWeight: FontWeight.bold)),
              Row(
                children: [
                  if (_wideT > 0) const Text('🟧 ', style: TextStyle(fontSize: 16)),
                  if (_slowT > 0) const Text('🐌 ', style: TextStyle(fontSize: 16)),
                  if (_laserT > 0) const Text('🔫 ', style: TextStyle(fontSize: 16)),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              _area = Size(constraints.maxWidth, constraints.maxHeight);
              return GestureDetector(
                onHorizontalDragUpdate: (d) => _paddleX += d.delta.dx / _area.width,
                onTapDown: _onTapDown,
                child: CustomPaint(
                  painter: _CrusherPainter(
                    bricks: _bricks,
                    brickRect: _brickRect,
                    balls: _balls,
                    drops: _drops,
                    bolts: _bolts,
                    paddleLeft: _area == Size.zero ? 0 : _paddleLeft,
                    paddleW: _area == Size.zero ? 0 : _paddleW,
                    paddleY: _area == Size.zero ? 0 : _paddleY,
                    serving: _serving,
                    paddleX: _paddleX,
                    areaW: _area.width,
                    laser: _laserT > 0,
                    banner: _bannerT > 0 ? _banner : '',
                    bg: theme.background,
                    accent: theme.accent,
                    palette: _palette,
                  ),
                  size: Size.infinite,
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Text(
            _serving ? 'Tap to launch the ball!' : 'Drag to move • catch the falling goodies',
            style: TextStyle(color: theme.muted),
          ),
        ),
      ],
    );
  }
}

class _CrusherPainter extends CustomPainter {
  final List<_Brick> bricks;
  final Rect Function(_Brick) brickRect;
  final List<_Ball> balls;
  final List<_Drop> drops;
  final List<_Bolt> bolts;
  final double paddleLeft, paddleW, paddleY, paddleX, areaW;
  final bool serving, laser;
  final String banner;
  final Color bg, accent;
  final List<Color> palette;

  _CrusherPainter({
    required this.bricks,
    required this.brickRect,
    required this.balls,
    required this.drops,
    required this.bolts,
    required this.paddleLeft,
    required this.paddleW,
    required this.paddleY,
    required this.serving,
    required this.paddleX,
    required this.areaW,
    required this.laser,
    required this.banner,
    required this.bg,
    required this.accent,
    required this.palette,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = bg);

    for (final b in bricks) {
      if (!b.alive) continue;
      final r = brickRect(b);
      final c = palette[(b.row) % palette.length];
      canvas.drawRRect(
        RRect.fromRectAndRadius(r, const Radius.circular(6)),
        Paint()..color = b.hits > 1 ? c.withValues(alpha: 0.45 + 0.2 * b.hits) : c,
      );
      if (b.hits > 1) {
        final tp = TextPainter(
          text: TextSpan(text: '${b.hits}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, r.center - Offset(tp.width / 2, tp.height / 2));
      }
    }

    // paddle
    final pr = RRect.fromRectAndRadius(
      Rect.fromLTWH(paddleLeft, paddleY, paddleW, 14),
      const Radius.circular(7),
    );
    canvas.drawRRect(pr, Paint()..color = accent);
    if (laser) {
      canvas.drawRRect(pr, Paint()..color = Colors.yellow.withValues(alpha: 0.35));
    }

    for (final ball in balls) {
      canvas.drawCircle(ball.pos, 8, Paint()..color = Colors.white);
      canvas.drawCircle(ball.pos, 8, Paint()..color = accent.withValues(alpha: 0.35));
    }
    if (serving) {
      canvas.drawCircle(Offset(paddleX * areaW, paddleY - 12), 8, Paint()..color = Colors.white);
    }

    const labels = {'multi': '×2', 'wide': 'W', 'slow': 'S', 'laser': 'L'};
    const cols = {
      'multi': Colors.green,
      'wide': Colors.orange,
      'slow': Colors.cyan,
      'laser': Colors.yellow,
    };
    for (final d in drops) {
      final key = d.kind.name;
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromCenter(center: d.pos, width: 30, height: 30), const Radius.circular(8)),
        Paint()..color = cols[key]!,
      );
      final tp = TextPainter(
        text: TextSpan(text: labels[key], style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 13)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, d.pos - Offset(tp.width / 2, tp.height / 2));
    }

    for (final b in bolts) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromCenter(center: b.pos, width: 6, height: 18), const Radius.circular(3)),
        Paint()..color = Colors.yellow,
      );
    }

    if (banner.isNotEmpty) {
      final tp = TextPainter(
        text: TextSpan(
          text: banner,
          style: TextStyle(color: accent, fontWeight: FontWeight.w900, fontSize: 34),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset((size.width - tp.width) / 2, size.height * 0.4));
    }
  }

  @override
  bool shouldRepaint(covariant _CrusherPainter old) => true;
}
