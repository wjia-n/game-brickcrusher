import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:share_plus/share_plus.dart';
import '../services/audio_service.dart';
import '../services/iap_service.dart';
import '../services/settings_service.dart';
import '../theme/crusher_themes.dart';
import '../theme/workshop.dart';
import 'custom_theme_screen.dart';
import 'game_screen.dart';
import 'pro_screen.dart';
import 'settings_screen.dart';

const _storeUrl =
    'https://play.google.com/store/apps/details?id=com.gameswajiha.brickcrusher';

/// Main menu — Mason's Workshop edition.
/// Logo, PLAY, difficulty/mode setup, theme + style picker, player rename,
/// tip jar, settings.
class MenuScreen extends StatefulWidget {
  final CrusherAudio audio;
  final CrusherSettings settings;

  const MenuScreen({super.key, required this.audio, required this.settings});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  final StoreService _store = StoreService();

  CrusherSettings get _s => widget.settings;
  CrusherThemeDef get _t =>
      CrusherThemes.byId(_s.themeId, custom: _s.customTheme);

  @override
  void initState() {
    super.initState();
    widget.audio.startMenuMusic();
    _store.init().then((_) {
      if (mounted) setState(() {});
    });
    _store.lastThanks.addListener(_onThanks);
  }

  void _onThanks() {
    final msg = _store.lastThanks.value;
    if (msg == null || !mounted) return;
    widget.audio.win();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: Workshop.body(15, theme: _t)),
        backgroundColor: _t.bgDeep,
        behavior: SnackBarBehavior.floating,
      ),
    );
    _store.lastThanks.value = null;
  }

  
  @override
  void dispose() {
    _store.lastThanks.removeListener(_onThanks);
    _store.dispose();
    super.dispose();
  }

  /// Real in-app review flow: the Play in-app review sheet when available,
  /// otherwise fall back to opening the store listing. No fake dialogs.
  Future<void> _requestReview() async {
    final review = InAppReview.instance;
    try {
      if (await review.isAvailable()) {
        await review.requestReview();
      } else {
        await review.openStoreListing(appStoreId: null);
      }
    } catch (_) {
      // Review UI unavailable on this device/build: stay silent, no fake UI.
    }
  }

  void _play() {
    widget.audio.launch();
    // App-scoped music: keep playing across screens. GameScreen switches
    // to the game track on entry; we switch back to menu music on return.
    Navigator.of(context)
        .push(MaterialPageRoute(
      builder: (_) => GameScreen(
        audio: widget.audio,
        settings: _s,
      ),
    ))
        .then((_) {
      if (mounted) widget.audio.startMenuMusic();
    });
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
            listenable: _s,
            builder: (_, _) => SingleChildScrollView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  // Logo plaque.
                  Container(
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: t.accent, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.6),
                          offset: const Offset(0, 8),
                          blurRadius: 18,
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Image.asset('assets/brickcrusher_logo.png',
                        fit: BoxFit.cover),
                  ),
                  const SizedBox(height: 14),
                  Text('Brick Crusher', style: Workshop.display(40, theme: t)),
                  Text(
                    'THE MASON\'S WORKSHOP EDITION',
                    style: Workshop.label(12, theme: t),
                  ),
                  const SizedBox(height: 22),
                  PlankButton(label: '▶  Smash!', onTap: _play, theme: t, width: 260),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () {
                      widget.audio.click();
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => ProScreen(
                          audio: widget.audio,
                          settings: _s,
                          store: _store,
                        ),
                      ));
                    },
                    child: Container(
                      width: 260,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        gradient: LinearGradient(colors: [
                          t.accent.withValues(alpha: 0.9),
                          t.accentDark,
                        ]),
                        border: Border.all(
                            color: t.accentLight, width: 2.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.5),
                            offset: const Offset(0, 4),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '☕  Tip Jar',
                        style: Workshop.label(17,
                            theme: t, color: t.bgDeep),
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  _ModeCard(theme: t),
                  const SizedBox(height: 14),
                  _StyleCard(theme: t),
                  const SizedBox(height: 14),
                  _PlayerCard(theme: t),
                  const SizedBox(height: 14),
                  _SupportCard(theme: t, store: _store),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _MenuIcon(
                        theme: t,
                        icon: Icons.share,
                        label: 'Share',
                        onTap: () async {
                          widget.audio.click();
                          await SharePlus.instance.share(ShareParams(
                              text:
                                  'Smash bricks with me in Brick Crusher! $_storeUrl'));
                        },
                      ),
                      const SizedBox(width: 22),
                      _MenuIcon(
                        theme: t,
                        icon: Icons.star_rate,
                        label: 'Rate',
                        onTap: () async {
                          widget.audio.click();
                          await _requestReview();
                        },
                      ),
                      const SizedBox(width: 22),
                      _MenuIcon(
                        theme: t,
                        icon: Icons.settings,
                        label: 'Settings',
                        onTap: () async {
                          widget.audio.click();
                          await Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => SettingsScreen(
                              audio: widget.audio,
                              settings: _s,
                            ),
                          ));
                          if (mounted) setState(() {});
                        },
                      ),
                      const SizedBox(width: 26),
                      _MenuIcon(
                        theme: t,
                        icon: Icons.help_outline,
                        label: 'How to Play',
                        onTap: () {
                          widget.audio.click();
                          _showHowTo(context, t);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  if (_s.gamesPlayed > 0)
                    Text(
                      'Best: ${_s.highScore}   •   Games: ${_s.gamesPlayed}   •   Bricks: ${_s.totalBricks}',
                      style: Workshop.label(12, theme: t),
                      textAlign: TextAlign.center,
                    ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset('assets/wajiha_logo.png',
                          width: 22, height: 22, fit: BoxFit.contain),
                      const SizedBox(width: 8),
                      Text('Credits: WAJIHA',
                          style: Workshop.label(12, theme: t)),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showHowTo(BuildContext context, CrusherThemeDef t) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
                colors: [t.bg, t.bgDeep],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter),
            border: Border.all(color: t.accent, width: 3),
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('How to Play', style: Workshop.display(24, theme: t)),
                const SizedBox(height: 12),
                for (final line in [
                  '• Drag to slide the paddle and keep the ball alive.',
                  '• Smash every brick to clear the level.',
                  '• Catch falling goodies: ×2 multiball, wide paddle, slow-mo, laser.',
                  '• Combos multiply your score — don\'t let the ball touch the paddle between smashes!',
                  '• 3 lives (2 on Insane). Lose the ball, lose a life.',
                  '• Campaign: clear 5 levels. Endless: survive forever. Score Attack: 2 minutes, most points wins!',
                ])
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(line, style: Workshop.body(14, theme: t)),
                  ),
                const SizedBox(height: 16),
                Center(
                  child: PlankButton(
                    label: 'Got it!',
                    width: 180,
                    fontSize: 16,
                    theme: t,
                    onTap: () {
                      widget.audio.click();
                      Navigator.of(context).pop();
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
class _MenuIcon extends StatelessWidget {
  final CrusherThemeDef theme;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _MenuIcon(
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
            width: 62,
            height: 62,
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
            child: Icon(icon, color: theme.accentLight, size: 28),
          ),
          const SizedBox(height: 6),
          Text(label, style: Workshop.label(12, theme: theme)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
/// Difficulty tiers + game mode setup.
class _ModeCard extends StatelessWidget {
  final CrusherThemeDef theme;
  const _ModeCard({required this.theme});

  static const difficulties = ['Chill', 'Classic', 'Wild', 'Insane'];
  static const modes = ['Campaign', 'Endless', 'Score Attack'];

  Future<void> _goPro(BuildContext context, _MenuScreenState screen) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ProScreen(
        audio: screen.widget.audio,
        settings: screen._s,
        store: screen._store,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final screen = context.findAncestorStateOfType<_MenuScreenState>()!;
    final s = screen._s;
    final audio = screen.widget.audio;
    return _Card(
      theme: theme,
      title: 'Smash Mode',
      child: Column(
        children: [
          Wrap(
            alignment: WrapAlignment.center,
            children: [
              for (int d = 0; d < 4; d++)
                _Chip(
                  theme: theme,
                  label: '${d > 1 && !s.isPro ? '🔒 ' : ''}${difficulties[d]}',
                  selected: s.difficulty == d,
                  onTap: () async {
                    audio.click();
                    if (d > 1 && !s.isPro) {
                      await _goPro(context, screen);
                      return;
                    }
                    s.setDifficulty(d);
                  },
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${['Gentle ball, fewer bricks', 'The classic crusher pace', 'Faster, tougher walls', 'Brutal speed, 2 lives'][s.difficulty]}',
            style: Workshop.body(12,
                theme: theme, color: theme.ink.withValues(alpha: 0.6)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Wrap(
            alignment: WrapAlignment.center,
            children: [
              for (int m = 0; m < 3; m++)
                _Chip(
                  theme: theme,
                  label: '${m == 2 && !s.isPro ? '🔒 ' : ''}${modes[m]}',
                  selected: s.mode == m,
                  onTap: () async {
                    audio.click();
                    if (m == 2 && !s.isPro) {
                      await _goPro(context, screen);
                      return;
                    }
                    s.setMode(m);
                  },
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${['Clear 5 levels to win', 'Levels forever, how far can you go?', '2 minutes — most points wins'][s.mode]}',
            style: Workshop.body(12,
                theme: theme, color: theme.ink.withValues(alpha: 0.6)),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
/// Theme / appearance picker: 14 themes + custom creator, 8 paddle styles,
/// 8 ball styles, 8 brick styles — with PRO locks.
class _StyleCard extends StatelessWidget {
  final CrusherThemeDef theme;
  const _StyleCard({required this.theme});

  Future<void> _goPro(BuildContext context, _MenuScreenState screen) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ProScreen(
        audio: screen.widget.audio,
        settings: screen._s,
        store: screen._store,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final screen = context.findAncestorStateOfType<_MenuScreenState>()!;
    final s = screen._s;
    final audio = screen.widget.audio;
    final isPro = s.isPro;
    return _Card(
      theme: theme,
      title: 'Workshop Style',
      child: Column(
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: [
              for (final th in CrusherThemes.all)
                _ThemeTile(
                  theme: theme,
                  th: th,
                  selected: s.themeId == th.id,
                  locked: CrusherThemes.isProTheme(th.id) && !isPro,
                  onTap: () {
                    audio.click();
                    if (CrusherThemes.isProTheme(th.id) && !isPro) {
                      _goPro(context, screen);
                      return;
                    }
                    s.setTheme(th.id);
                  },
                ),
              // Custom theme tile (PRO).
              _ThemeTile(
                theme: theme,
                th: s.customTheme,
                selected: s.themeId == 'custom',
                locked: !isPro,
                custom: true,
                onTap: () {
                  audio.click();
                  if (!isPro) {
                    _goPro(context, screen);
                    return;
                  }
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => CustomThemeScreen(
                      audio: audio,
                      settings: s,
                    ),
                  ));
                },
              ),
            ],
          ),
          if (!isPro)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '🔒 ${CrusherThemes.all.length - CrusherThemes.freeThemeIds.length} more themes in PRO',
                style: Workshop.label(12, theme: theme),
              ),
            ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerLeft,
            child: Text('Paddle style:', style: Workshop.body(15, theme: theme)),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: [
              for (int i = 0; i < PaddleStyles.names.length; i++)
                _Chip(
                  theme: theme,
                  label:
                      '${PaddleStyles.isPro(i) && !isPro ? '🔒 ' : ''}${PaddleStyles.names[i]}',
                  selected: s.paddleStyle == i,
                  onTap: () {
                    audio.click();
                    if (PaddleStyles.isPro(i) && !isPro) {
                      _goPro(context, screen);
                      return;
                    }
                    s.setPaddleStyle(i);
                  },
                ),
            ],
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: Text('Ball style:', style: Workshop.body(15, theme: theme)),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: [
              for (int i = 0; i < BallStyles.names.length; i++)
                _Chip(
                  theme: theme,
                  label:
                      '${BallStyles.isPro(i) && !isPro ? '🔒 ' : ''}${BallStyles.names[i]}',
                  selected: s.ballStyle == i,
                  onTap: () {
                    audio.click();
                    if (BallStyles.isPro(i) && !isPro) {
                      _goPro(context, screen);
                      return;
                    }
                    s.setBallStyle(i);
                  },
                ),
            ],
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: Text('Brick style:', style: Workshop.body(15, theme: theme)),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: [
              for (int i = 0; i < BrickStyles.names.length; i++)
                _Chip(
                  theme: theme,
                  label:
                      '${BrickStyles.isPro(i) && !isPro ? '🔒 ' : ''}${BrickStyles.names[i]}',
                  selected: s.brickStyle == i,
                  onTap: () {
                    audio.click();
                    if (BrickStyles.isPro(i) && !isPro) {
                      _goPro(context, screen);
                      return;
                    }
                    s.setBrickStyle(i);
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ThemeTile extends StatelessWidget {
  final CrusherThemeDef theme;
  final CrusherThemeDef th;
  final bool selected;
  final bool locked;
  final bool custom;
  final VoidCallback onTap;
  const _ThemeTile({
    required this.theme,
    required this.th,
    required this.selected,
    required this.locked,
    required this.onTap,
    this.custom = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 96,
            padding:
                const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: th.bgDeep.withValues(alpha: 0.7),
              border: Border.all(
                color: selected
                    ? th.accentLight
                    : th.accent.withValues(alpha: 0.35),
                width: selected ? 3 : 1.5,
              ),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (int i = 0; i < 3; i++)
                      Container(
                        width: 14,
                        height: 14,
                        margin: const EdgeInsets.symmetric(
                            horizontal: 1.5),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(3),
                          color: th.brickRows[i * 2],
                          border: Border.all(
                              color: th.accentLight, width: 1),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  custom ? '🎨 My Creation' : th.name,
                  style: Workshop.label(10, theme: th),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (locked)
            Container(
              width: 96,
              height: 62,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: Colors.black.withValues(alpha: 0.55),
              ),
              child: Icon(Icons.lock,
                  color: theme.accentLight, size: 22),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
/// Rename the player profile.
class _PlayerCard extends StatelessWidget {
  final CrusherThemeDef theme;
  const _PlayerCard({required this.theme});

  @override
  Widget build(BuildContext context) {
    final screen = context.findAncestorStateOfType<_MenuScreenState>()!;
    final s = screen._s;
    return _Card(
      theme: theme,
      title: 'Smasher Name',
      child: Column(
        children: [
          _NameField(
            theme: theme,
            initial: s.playerName,
            onDone: (v) => s.setPlayerName(v),
          ),
          const SizedBox(height: 6),
          Text(
            'Your name shows on victory screens and the scoreboard.',
            style: Workshop.body(12,
                theme: theme, color: theme.ink.withValues(alpha: 0.6)),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _NameField extends StatefulWidget {
  final CrusherThemeDef theme;
  final String initial;
  final ValueChanged<String> onDone;
  const _NameField(
      {required this.theme, required this.initial, required this.onDone});

  @override
  State<_NameField> createState() => _NameFieldState();
}

class _NameFieldState extends State<_NameField> {
  late final TextEditingController _c;
  late final FocusNode _focus;

  @override
  void initState() {
    super.initState();
    _c = TextEditingController(text: widget.initial);
    _focus = FocusNode();
    // Commit the name when the field loses focus.
    _focus.addListener(() {
      if (!_focus.hasFocus) widget.onDone(_c.text);
    });
  }

  @override
  void didUpdateWidget(covariant _NameField old) {
    super.didUpdateWidget(old);
    if (old.initial != widget.initial && _c.text != widget.initial) {
      _c.text = widget.initial;
    }
  }

  @override
  void dispose() {
    _focus.dispose();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: Colors.black.withValues(alpha: 0.3),
        border:
            Border.all(color: widget.theme.accent.withValues(alpha: 0.5)),
      ),
      child: TextField(
        controller: _c,
        focusNode: _focus,
        style: Workshop.body(16, theme: widget.theme),
        maxLength: 16,
        decoration: InputDecoration(
          counterText: '',
          border: InputBorder.none,
          hintText: 'Your smasher name',
          hintStyle: Workshop.body(14,
              theme: widget.theme,
              color: widget.theme.ink.withValues(alpha: 0.4)),
        ),
        // Save on EVERY keystroke (the settings service persists the
        // order-safe JSON profile each time), commit on focus loss above.
        onChanged: widget.onDone,
        onSubmitted: widget.onDone,
        onEditingComplete: () => widget.onDone(_c.text),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
/// Tip jar (IAP).
class _SupportCard extends StatelessWidget {
  final CrusherThemeDef theme;
  final StoreService store;
  const _SupportCard({required this.theme, required this.store});

  @override
  Widget build(BuildContext context) {
    final screen = context.findAncestorStateOfType<_MenuScreenState>()!;
    final audio = screen.widget.audio;
    return _Card(
      theme: theme,
      title: 'Support Wajiha',
      child: Column(
        children: [
          Text(
            'Brick Crusher is 100% free. If it made you smile, a small tip keeps the workshop open!',
            style: Workshop.body(14, theme: theme),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Builder(builder: (_) {
            final tips = [
              store.coffeeProduct,
              store.chocolateProduct,
            ].whereType<ProductDetails>().toList();
            if (!store.storeReady) {
              return Text(
                store.error ?? 'Loading…',
                style: Workshop.body(13,
                    theme: theme,
                    color: theme.ink.withValues(alpha: 0.6)),
                textAlign: TextAlign.center,
              );
            }
            if (tips.isEmpty) {
              return Text('Tips coming soon.',
                  style: Workshop.body(13,
                      theme: theme,
                      color: theme.ink.withValues(alpha: 0.6)));
            }
            return Wrap(
              spacing: 10,
              alignment: WrapAlignment.center,
              children: [
                for (final p in tips)
                  _Chip(
                    theme: theme,
                    label: p.id == StoreService.chocolateId
                        ? '🍫 ${p.price}'
                        : '☕ ${p.price}',
                    selected: false,
                    onTap: () {
                      audio.click();
                      store.buyTip(p);
                    },
                  ),
              ],
            );
          }),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
class _Card extends StatelessWidget {
  final CrusherThemeDef theme;
  final String title;
  final Widget child;
  const _Card(
      {required this.theme, required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            theme.bg.withValues(alpha: 0.85),
            theme.bgDeep.withValues(alpha: 0.9),
          ],
        ),
        border: Border.all(color: theme.accent, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            offset: const Offset(0, 5),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        children: [
          Text(title, style: Workshop.display(20, theme: theme)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final CrusherThemeDef theme;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _Chip(
      {required this.theme,
      required this.label,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: selected
              ? theme.accent.withValues(alpha: 0.85)
              : Colors.black.withValues(alpha: 0.3),
          border: Border.all(
            color: selected
                ? theme.accentLight
                : theme.accent.withValues(alpha: 0.5),
            width: selected ? 2.5 : 1.5,
          ),
        ),
        child: Text(
          label,
          style: Workshop.label(13,
              theme: theme, color: selected ? theme.bgDeep : theme.ink),
        ),
      ),
    );
  }
}
