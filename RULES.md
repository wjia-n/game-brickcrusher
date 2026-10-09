# Brick Crusher — Rules (authoritative source of truth)

## 1. Objective
Smash every brick on the board with a bouncing ball. Clear all bricks in a
level to advance. Campaign mode is won by clearing all 5 levels.

## 2. Setup
- The player picks a difficulty tier (Chill, Classic, Wild, Insane) and a
  mode (Campaign, Endless, Score Attack).
- Each run starts with: lives = 3 (2 on Insane), score = 0, level = 1,
  combo = 0. Score Attack runs start with a 120-second clock instead of a
  level target.
- The paddle starts centered; the ball sits on the paddle ("serving").

## 3. Turn order
There are no turns. Play is continuous real-time: the engine runs a
60fps physics loop. Phases: serving → playing → (banner) → serving/playing
→ … → over. Banners (level intro/clear, ball lost) lock input and always
advance on their own timer; a watchdog re-arms any phase found without a
live timer.

## 4. Legal moves
- Drag horizontally to slide the paddle (clamped inside the arena).
- Tap to launch the ball while serving.
- Tap to fire laser bolts while the laser power-up is active.
- Move the paddle to catch falling power-up drops.

## 5. Illegal moves
- Input is locked during banner and paused phases (taps are ignored).
- No input is possible after the run is over.
- The paddle can never leave the arena.

## 6. Captures
Not applicable (no captures in a brick-breaker).

## 7. Special rules
- **Multiball**: caught drops clone every live ball with a deflected
  angle. If caught while serving, it launches the ball first.
- **Wide paddle**: paddle widens to 46% of arena width for 12s.
- **Slow-mo**: ball speed × 0.7 for 12s.
- **Laser**: tapping fires bolts upward for 10s; a bolt damages one brick.
- Power-ups fall at a fixed speed and are caught by paddle overlap; missed
  drops simply fall away.
- **Combo**: each smashed brick without the ball touching the paddle raises
  the combo by 1. The combo breaks (resets to 0) the moment the ball
  touches the paddle or a life is lost.
- **Debris**: smashed bricks burst into physical chunks (purely visual).

## 8. Scoring
- Smashing a brick: 10 × level × brick-hit-points × combo multiplier.
- Combo multiplier = 1 + combo × 0.1, capped at 3×.
- Cracking (not smashing) a multi-hit brick: 2 × level points.
- Level-clear bonus: 50 × level.
- Floating "+N" popups show exactly where points were earned; the HUD
  score always reflects the running total. No silent scoring.

## 9. Winning conditions
- **Campaign**: clear all bricks of level 5 → victory.
- **Score Attack**: survive the 120-second clock (time-up = victory over
  the clock); final score is ranked against the Score Attack best.
- **Endless**: there is no victory — the run ends only when lives run out.

## 10. Draw conditions
Not applicable.

## 11. AI strategy
Not applicable — Brick Crusher is a single-player skill game (no bots).
Difficulty tiers scale ball speed and brick layout complexity:
Chill 300px/s / 3 rows, Classic 375 / 4, Wild 460 / 5, Insane 560 / 6,
plus level scaling (+30px/s and extra rows per level) and more multi-hit
bricks at higher tiers.

## 12. Edge cases
- Ball lost with 0 other balls in flight → lose a life, re-serve (or game
  over at 0 lives). In Score Attack the clock keeps its remaining time.
- Balls can never tunnel through bricks: physics is substepped in ≤6px
  steps.
- A ball faster than the frame budget is normalized to the difficulty
  speed on every paddle bounce.
- App backgrounded mid-run → engine pauses; the user resumes manually.
- Watchdog: a banner or playing phase found without a live timer is
  recovered (dismiss banner / settle the lost life). Stuck states are
  impossible by construction.

## 13. Test cases
- `test/engine_test.dart`: serving→launch→playing transition; brick
  damage/score math; combo reset on paddle touch; life loss and game over;
  level-clear advance; score-attack timer expiry; pause/resume; watchdog
  recovery of a banner without a timer.
- `test/settings_names_test.dart`: profile JSON round-trip
  (encode/decode), corrupt-data fallback, legacy-key migration.
