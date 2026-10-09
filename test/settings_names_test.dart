import 'package:flutter_test/flutter_test.dart';
import 'package:brickcrusher/services/settings_service.dart';

void main() {
  group('profile JSON (order-safe persistence)', () {
    test('encode/decode round-trips the profile', () {
      final profile = {
        'name': 'Smasher',
        'highScore': 1234,
        'highEndless': 500,
        'highAttack': 42,
        'gamesPlayed': 7,
        'levelsCleared': 12,
        'bestCombo': 9,
        'totalBricks': 300,
      };
      final raw = CrusherSettings.encodeProfile(profile);
      final back = CrusherSettings.decodeProfile(raw);
      expect(back['name'], 'Smasher');
      expect(back['highScore'], 1234);
      expect(back['gamesPlayed'], 7);
      expect(back['totalBricks'], 300);
    });

    test('corrupt data falls back to defaults', () {
      final back = CrusherSettings.decodeProfile('not-json{{{');
      expect(back['name'], CrusherSettings.defaultName);
      expect(back['highScore'], 0);
    });

    test('null falls back to defaults', () {
      final back = CrusherSettings.decodeProfile(null);
      expect(back['name'], CrusherSettings.defaultName);
    });

    test('empty name is cleaned to the default', () {
      final raw = CrusherSettings.encodeProfile({
        'name': '   ',
        'highScore': 10,
        'highEndless': 0,
        'highAttack': 0,
        'gamesPlayed': 1,
        'levelsCleared': 0,
        'bestCombo': 0,
        'totalBricks': 5,
      });
      final back = CrusherSettings.decodeProfile(raw);
      expect(back['name'], CrusherSettings.defaultName);
    });
  });
}
