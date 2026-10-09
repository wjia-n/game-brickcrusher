import 'package:flutter/material.dart';
import '../services/audio_service.dart';
import '../services/settings_service.dart';
import '../theme/crusher_themes.dart';
import '../theme/workshop.dart';

/// Custom theme creator (PRO): pick physical-material colors for every
/// surface of the game. Changes apply live.
class CustomThemeScreen extends StatefulWidget {
  final CrusherAudio audio;
  final CrusherSettings settings;
  const CustomThemeScreen(
      {super.key, required this.audio, required this.settings});

  @override
  State<CustomThemeScreen> createState() => _CustomThemeScreenState();
}

class _CustomThemeScreenState extends State<CustomThemeScreen> {
  static const keyLabels = {
    'bg': 'Wall base',
    'bgDeep': 'Wall deep',
    'paddleLight': 'Paddle light',
    'paddleDark': 'Paddle dark',
    'ballCore': 'Ball core',
    'ballRim': 'Ball rim',
    'brickA': 'Brick row 1',
    'brickB': 'Brick row 2',
    'brickC': 'Brick row 3',
    'brickD': 'Brick row 4',
    'brickE': 'Brick row 5',
    'brickF': 'Brick row 6',
    'accent': 'Accent metal',
    'accentLight': 'Accent light',
    'accentDark': 'Accent dark',
    'ink': 'Text',
    'muted': 'Muted text',
  };

  /// Physical-material swatch palette: clays, stones, timbers, metals.
  static const swatches = [
    0xFFC96A3B, 0xFFB8552F, 0xFFD97F45, 0xFF8A4E22, // clays
    0xFF7C8590, 0xFF59616B, 0xFF3E4450, 0xFF23262B, // stones
    0xFFE0B96E, 0xFFC99A4E, 0xFF9C7433, 0xFF5C3A21, // sands & woods
    0xFF7C9A52, 0xFF587238, 0xFF5E8CA3, 0xFF406274, // moss & slate
    0xFFD9A441, 0xFFF2CE7E, 0xFFC0C6D4, 0xFF78818D, // metals
    0xFFF7EBD4, 0xFFC4AE8A, 0xFF171009, 0xFF0C0A07, // lights & darks
  ];

  CrusherSettings get _s => widget.settings;

  @override
  void initState() {
    super.initState();
    // Wear the custom theme while designing it.
    _s.setTheme('custom');
  }

  CrusherThemeDef get _t =>
      CrusherThemes.byId(_s.themeId, custom: _s.customTheme);

  @override
  Widget build(BuildContext context) {
    final t = _t;
    return WorkshopBackdrop(
      theme: t,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: t.accentLight),
            onPressed: () {
              widget.audio.click();
              Navigator.of(context).pop();
            },
          ),
          title: Text('🎨 My Creation', style: Workshop.display(22, theme: t)),
          centerTitle: true,
          actions: [
            IconButton(
              icon: Icon(Icons.refresh, color: t.accentLight),
              tooltip: 'Reset colors',
              onPressed: () {
                widget.audio.click();
                _s.resetCustomColors();
                setState(() {});
              },
            ),
          ],
        ),
        body: ListenableBuilder(
          listenable: _s,
          builder: (_, _) => ListView(
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            children: [
              Text(
                'Tap a swatch to repaint that surface. Everything updates live.',
                style: Workshop.body(14, theme: t),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              for (final key in keyLabels.keys)
                _ColorRow(
                  theme: t,
                  label: keyLabels[key]!,
                  current: Color(_s.customColors[key]!),
                  onPick: (argb) {
                    widget.audio.click();
                    _s.setCustomColor(key, argb);
                  },
                ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _ColorRow extends StatelessWidget {
  final CrusherThemeDef theme;
  final String label;
  final Color current;
  final ValueChanged<int> onPick;
  const _ColorRow(
      {required this.theme,
      required this.label,
      required this.current,
      required this.onPick});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: current,
                  border: Border.all(color: Colors.white54, width: 2),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.5),
                        offset: const Offset(0, 2),
                        blurRadius: 4),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(label, style: Workshop.body(14, theme: theme)),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final argb in _CustomThemeScreenState.swatches)
                GestureDetector(
                  onTap: () => onPick(argb),
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(argb),
                      border: Border.all(
                        color: current.value == argb
                            ? Colors.white
                            : Colors.white24,
                        width: current.value == argb ? 3 : 1.5,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
