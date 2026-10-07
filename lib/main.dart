import 'package:flutter/material.dart';
import 'package:wajiha_game_core/wajiha_game_core.dart';
import 'game_screen.dart';

void main() => runApp(const BrickCrusherApp());

class BrickCrusherApp extends StatelessWidget {
  const BrickCrusherApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GameShell(
      title: 'Brick Crusher',
      tagline: 'Smash every brick, catch the chaos, become the wrecking ball!',
      emoji: '🧱',
      slug: 'brickcrusher',
      howToPlay:
          '• Drag to move the paddle and keep the ball in play.\n• Smash every brick to clear the level — 5 levels total.\n• Catch falling power-ups: multiball, wide paddle, slow-mo, laser.\n• You have 3 lives. Don\'t let the ball(s) drop!',
      playerOptions: const [1],
      supportsBots: false,
      gameBuilder: (ctx, players, cb) => BrickCrusherScreen(players: players, callbacks: cb),
    );
  }
}
