import 'package:fake_async/fake_async.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:brickcrusher/engine/crusher_engine.dart';

CrusherEngine _make({
  CrusherDifficulty difficulty = CrusherDifficulty.chill,
  CrusherMode mode = CrusherMode.campaign,
}) {
  final e = CrusherEngine(difficulty: difficulty, mode: mode);
  e.arena = const Size(400, 700);
  return e;
}

void main() {
  group('engine phases', () {
    test('starts serving with a full brick wall', () {
      final e = _make();
      expect(e.phase, CrusherPhase.serving);
      expect(e.lives, 3);
      expect(e.level, 1);
      expect(e.score, 0);
      expect(e.brickCount, greaterThan(0));
      e.dispose();
    });

    test('tap launches the ball into playing', () {
      final e = _make();
      e.tapAction();
      expect(e.phase, CrusherPhase.playing);
      expect(e.balls.length, 1);
      e.dispose();
    });

    test('paddle stays clamped inside the arena', () {
      final e = _make();
      e.movePaddle(-5);
      expect(e.paddleX, greaterThanOrEqualTo(0));
      e.movePaddle(99);
      expect(e.paddleX, lessThanOrEqualTo(1));
      e.dispose();
    });

    test('pause freezes and resumes', () {
      final e = _make();
      e.tapAction();
      e.setPaused(true);
      expect(e.phase, CrusherPhase.paused);
      e.setPaused(false);
      expect(e.phase, CrusherPhase.playing);
      e.dispose();
    });
  });

  group('bricks, scoring and combo', () {
    test('ball smashes a 1-hit brick, scores, raises combo', () {
      final e = _make();
      final rect = e.brickRectAt(0);
      expect(e.brickHitsAt(0), 1); // chill level 1: row 0 col 0 is 1-hit
      e.debugPlaceBall(rect.center, const Offset(0, 50));
      e.update(1 / 60);
      expect(e.brickAliveAt(0), isFalse);
      expect(e.score, greaterThan(0));
      expect(e.combo, 1);
      expect(e.bricksSmashed, 1);
      e.dispose();
    });

    test('combo resets when the ball touches the paddle', () {
      final e = _make();
      final rect = e.brickRectAt(0);
      e.debugPlaceBall(rect.center, const Offset(0, 50));
      e.update(1 / 60);
      expect(e.combo, 1);
      // Drop the ball onto the paddle.
      final px = e.paddleX * e.arena.width;
      e.balls.clear();
      e.debugPlaceBall(Offset(px, e.paddleY - 12), const Offset(0, 200));
      e.update(1 / 60);
      expect(e.combo, 0);
      e.dispose();
    });
  });

  group('lives and banners', () {
    test('losing the last ball costs a life and re-serves', () {
      final e = _make();
      fakeAsync((async) {
        e.tapAction();
        e.balls.clear();
        e.debugPlaceBall(
            const Offset(200, 800), const Offset(0, 200)); // below arena
        e.update(1 / 60);
        expect(e.lives, 2);
        expect(e.phase, CrusherPhase.banner);
        async.elapse(const Duration(seconds: 2));
        expect(e.phase, CrusherPhase.serving);
      });
      e.dispose();
    });

    test('watchdog recovers a banner that lost its timer', () {
      final e = _make();
      fakeAsync((async) {
        e.tapAction();
        e.balls.clear();
        e.debugPlaceBall(
            const Offset(200, 800), const Offset(0, 200));
        e.update(1 / 60);
        expect(e.phase, CrusherPhase.banner);
        e.debugDropPhaseTimer(); // simulate the lost timer
        async.elapse(const Duration(seconds: 4)); // watchdog fires
        expect(e.phase, CrusherPhase.serving);
      });
      e.dispose();
    });

    test('three lost lives ends the run', () {
      final e = _make();
      fakeAsync((async) {
        for (var i = 0; i < 3; i++) {
          e.balls.clear();
          if (e.phase == CrusherPhase.serving) e.tapAction();
          e.debugPlaceBall(
              const Offset(200, 800), const Offset(0, 200));
          e.update(1 / 60);
          async.elapse(const Duration(seconds: 2));
        }
        expect(e.over, isTrue);
        expect(e.phase, CrusherPhase.over);
        expect(e.won, isFalse);
      });
      e.dispose();
    });
  });

  group('score attack', () {
    test('clock expiry finishes the run as a win', () {
      final e = _make(mode: CrusherMode.scoreAttack);
      e.tapAction();
      e.update(120.5);
      expect(e.over, isTrue);
      expect(e.won, isTrue);
      e.dispose();
    });
  });
}
