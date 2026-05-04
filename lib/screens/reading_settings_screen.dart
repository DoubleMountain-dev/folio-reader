// lib/screens/reading_settings_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/document.dart';
import '../providers/library_provider.dart';
import '../services/sound_service.dart';
import '../utils/app_theme.dart';

class ReadingSettingsScreen extends StatefulWidget {
  const ReadingSettingsScreen({super.key});
  @override State<ReadingSettingsScreen> createState() => _ReadingSettingsScreenState();
}

class _ReadingSettingsScreenState extends State<ReadingSettingsScreen> {
  // Local mirror of SoundService state so UI rebuilds on change
  late bool   _sfxEnabled;
  late bool   _ambienceEnabled;
  late double _sfxVolume;
  late double _ambienceVolume;
  late PageTurnStyle  _pageTurnStyle;
  late AmbienceTrack  _ambienceTrack;

  @override
  void initState() {
    super.initState();
    final s = SoundService.instance;
    _sfxEnabled      = s.sfxEnabled;
    _ambienceEnabled = s.ambienceEnabled;
    _sfxVolume       = s.sfxVolume;
    _ambienceVolume  = s.ambienceVolume;
    _pageTurnStyle   = s.pageTurnStyle;
    _ambienceTrack   = s.currentAmbience;
  }

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryProvider>();
    final s = library.settings;

    return Scaffold(
      backgroundColor: AppColors.creamLight,
      appBar: AppBar(
        title: Text('Reading Settings', style: GoogleFonts.playfairDisplay(
            fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.paperWarm)),
        backgroundColor: AppColors.woodBrown,
        iconTheme: const IconThemeData(color: AppColors.paperWarm),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [

          // ── Font Family ────────────────────────────────────────────────────
          _Card(title: 'Font Family', child: Row(children: [
            _FontBtn(label: 'Serif',  value: 'serif',  current: s.fontFamily,
                onTap: () => library.updateSettings(s.copyWith(fontFamily: 'serif'))),
            const SizedBox(width: 8),
            _FontBtn(label: 'Sans',   value: 'sans',   current: s.fontFamily,
                onTap: () => library.updateSettings(s.copyWith(fontFamily: 'sans'))),
            const SizedBox(width: 8),
            _FontBtn(label: 'Mono',   value: 'mono',   current: s.fontFamily,
                onTap: () => library.updateSettings(s.copyWith(fontFamily: 'mono'))),
          ])),
          const SizedBox(height: 12),

          // ── Font Size ──────────────────────────────────────────────────────
          _Card(title: 'Font Size', child: Row(children: [
            Text('A', style: GoogleFonts.playfairDisplay(fontSize: 14, color: AppColors.mutedBrown)),
            Expanded(child: Slider(
              value: s.fontSize, min: 12, max: 26, divisions: 7,
              activeColor: AppColors.accentRed,
              inactiveColor: AppColors.mutedBrown.withValues(alpha: 0.2),
              onChanged: (v) => library.updateSettings(s.copyWith(fontSize: v)),
            )),
            Text('A', style: GoogleFonts.playfairDisplay(
                fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.mutedBrown)),
            const SizedBox(width: 8),
            _Pill('${s.fontSize.round()}px'),
          ])),
          const SizedBox(height: 12),

          // ── Line Spacing ───────────────────────────────────────────────────
          _Card(title: 'Line Spacing', child: Row(children: [
            Icon(Icons.format_line_spacing, color: AppColors.mutedBrown, size: 18),
            Expanded(child: Slider(
              value: s.lineHeight, min: 1.2, max: 2.4, divisions: 6,
              activeColor: AppColors.accentRed,
              inactiveColor: AppColors.mutedBrown.withValues(alpha: 0.2),
              onChanged: (v) => library.updateSettings(s.copyWith(lineHeight: v)),
            )),
            _Pill('${s.lineHeight.toStringAsFixed(1)}x'),
          ])),
          const SizedBox(height: 12),

          // ── Theme ──────────────────────────────────────────────────────────
          _Card(title: 'Theme', child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
            _ThemeDot(label: 'Sepia', value: 'sepia', bg: const Color(0xFFFAF6ED), current: s.theme,
                onTap: () => library.updateSettings(s.copyWith(theme: 'sepia'))),
            _ThemeDot(label: 'White', value: 'light', bg: Colors.white, current: s.theme,
                onTap: () => library.updateSettings(s.copyWith(theme: 'light'))),
            _ThemeDot(label: 'Dark',  value: 'dark',  bg: const Color(0xFF1A1208), current: s.theme,
                onTap: () => library.updateSettings(s.copyWith(theme: 'dark'))),
            _ThemeDot(label: 'Night', value: 'night', bg: const Color(0xFF0D1117), current: s.theme,
                onTap: () => library.updateSettings(s.copyWith(theme: 'night'))),
          ])),
          const SizedBox(height: 12),

          // ── Preview ────────────────────────────────────────────────────────
          _Card(title: 'Preview', child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: s.backgroundColor, borderRadius: BorderRadius.circular(8)),
            child: Text(
              'Manuscripts don\'t burn. It was not merely a phrase -- it was an axiom believed by all readers of great books.',
              style: GoogleFonts.playfairDisplay(
                  fontSize: s.fontSize * 0.85, height: s.lineHeight, color: s.textColor)),
          )),
          const SizedBox(height: 20),

          // ══ SOUNDS ═════════════════════════════════════════════════════════

          _SectionDivider(title: 'Sounds'),
          const SizedBox(height: 12),

          // ── Page Turn ──────────────────────────────────────────────────────
          _Card(title: 'Page Turn Sound', child: Column(children: [
            ...PageTurnStyle.values.map((style) {
              final labels = {
                PageTurnStyle.paper: 'Paper rustle',
                PageTurnStyle.click: 'Soft click',
                PageTurnStyle.none:  'Off',
              };
              final icons = {
                PageTurnStyle.paper: Icons.article_outlined,
                PageTurnStyle.click: Icons.touch_app_outlined,
                PageTurnStyle.none:  Icons.volume_off_outlined,
              };
              final sel = _pageTurnStyle == style;
              return GestureDetector(
                onTap: () async {
                  setState(() => _pageTurnStyle = style);
                  await SoundService.instance.setPageTurnStyle(style);
                  // Preview the sound
                  if (style != PageTurnStyle.none) {
                    await SoundService.instance.playPageTurn();
                  }
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: sel ? AppColors.woodBrown : AppColors.creamLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(children: [
                    Icon(icons[style]!, size: 18,
                        color: sel ? AppColors.paperWarm : AppColors.mutedBrown),
                    const SizedBox(width: 10),
                    Expanded(child: Text(labels[style]!, style: GoogleFonts.dmSans(
                        fontSize: 14,
                        color: sel ? AppColors.paperWarm : AppColors.inkDark,
                        fontWeight: sel ? FontWeight.w500 : FontWeight.w400))),
                    if (sel) Icon(Icons.check, size: 16, color: AppColors.accentRed),
                  ]),
                ),
              );
            }),
          ])),
          const SizedBox(height: 12),

          // ── UI Sounds ──────────────────────────────────────────────────────
          _Card(title: 'UI Sounds', child: Column(children: [
            _ToggleRow(
              icon: Icons.volume_up_outlined,
              label: 'Sound effects',
              subtitle: 'Bookmarks, quotes, achievements',
              value: _sfxEnabled,
              onChanged: (v) async {
                setState(() => _sfxEnabled = v);
                await SoundService.instance.setSfxEnabled(v);
              },
            ),
            if (_sfxEnabled) ...[
              const SizedBox(height: 10),
              Row(children: [
                Icon(Icons.volume_down, size: 18, color: AppColors.mutedBrown),
                Expanded(child: Slider(
                  value: _sfxVolume, min: 0.0, max: 1.0, divisions: 10,
                  activeColor: AppColors.accentRed,
                  inactiveColor: AppColors.mutedBrown.withValues(alpha: 0.2),
                  onChanged: (v) async {
                    setState(() => _sfxVolume = v);
                    await SoundService.instance.setSfxVolume(v);
                  },
                )),
                Icon(Icons.volume_up, size: 18, color: AppColors.mutedBrown),
                const SizedBox(width: 8),
                _Pill('${(_sfxVolume * 100).round()}%'),
              ]),
              const SizedBox(height: 8),
              // Preview buttons
              Row(children: [
                _PreviewBtn(label: 'Bookmark', onTap: () => SoundService.instance.playBookmarkAdd()),
                const SizedBox(width: 8),
                _PreviewBtn(label: 'Quote', onTap: () => SoundService.instance.playQuoteSave()),
                const SizedBox(width: 8),
                _PreviewBtn(label: 'Trophy', onTap: () => SoundService.instance.playAchievement()),
              ]),
            ],
          ])),
          const SizedBox(height: 12),

          // ── Background Ambience ────────────────────────────────────────────
          _Card(title: 'Background Sound', child: Column(children: [
            _ToggleRow(
              icon: Icons.headphones_outlined,
              label: 'Ambient sound',
              subtitle: 'Plays while you read',
              value: _ambienceEnabled,
              onChanged: (v) async {
                setState(() => _ambienceEnabled = v);
                if (v && _ambienceTrack != AmbienceTrack.none) {
                  await SoundService.instance.startAmbience(_ambienceTrack);
                } else {
                  await SoundService.instance.stopAmbience();
                }
              },
            ),
            const SizedBox(height: 12),

            // Track selector
            Wrap(spacing: 8, runSpacing: 8, children: AmbienceTrack.values.map((track) {
              final s = SoundService.instance;
              final sel = _ambienceTrack == track;
              final label = s.ambienceLabel(track);
              final emoji = s.ambienceEmoji(track);
              return GestureDetector(
                onTap: () async {
                  setState(() {
                    _ambienceTrack   = track;
                    _ambienceEnabled = track != AmbienceTrack.none;
                  });
                  if (track == AmbienceTrack.none) {
                    await SoundService.instance.stopAmbience();
                  } else {
                    await SoundService.instance.startAmbience(track);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: sel ? AppColors.woodBrown : AppColors.creamLight,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    track == AmbienceTrack.none ? 'Off' : '$emoji  $label',
                    style: GoogleFonts.dmSans(
                        fontSize: 13,
                        color: sel ? AppColors.paperWarm : AppColors.inkDark,
                        fontWeight: sel ? FontWeight.w500 : FontWeight.w400),
                  ),
                ),
              );
            }).toList()),

            if (_ambienceEnabled && _ambienceTrack != AmbienceTrack.none) ...[
              const SizedBox(height: 12),
              Row(children: [
                Icon(Icons.volume_down, size: 18, color: AppColors.mutedBrown),
                Expanded(child: Slider(
                  value: _ambienceVolume, min: 0.0, max: 1.0, divisions: 10,
                  activeColor: AppColors.accentRed,
                  inactiveColor: AppColors.mutedBrown.withValues(alpha: 0.2),
                  onChanged: (v) async {
                    setState(() => _ambienceVolume = v);
                    await SoundService.instance.setAmbienceVolume(v);
                  },
                )),
                Icon(Icons.volume_up, size: 18, color: AppColors.mutedBrown),
                const SizedBox(width: 8),
                _Pill('${(_ambienceVolume * 100).round()}%'),
              ]),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.spineForest.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(children: [
                  Icon(Icons.info_outline, size: 14, color: AppColors.spineForest),
                  const SizedBox(width: 6),
                  Expanded(child: Text(
                    'For the best experience, use real audio files from freesound.org. '
                    'See DEPLOY_INSTRUCTIONS.md for details.',
                    style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.spineForest, height: 1.4),
                  )),
                ]),
              ),
            ],
          ])),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ─── Reusable widgets ──────────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  final String title;
  final Widget child;
  const _Card({required this.title, required this.child});
  @override Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: AppColors.paperWarm, borderRadius: BorderRadius.circular(14)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title.toUpperCase(), style: GoogleFonts.dmSans(
          fontSize: 10, fontWeight: FontWeight.w600,
          color: AppColors.mutedBrown, letterSpacing: 1.2)),
      const SizedBox(height: 12),
      child,
    ]),
  );
}

class _SectionDivider extends StatelessWidget {
  final String title;
  const _SectionDivider({required this.title});
  @override Widget build(BuildContext context) => Row(children: [
    Container(width: 28, height: 1.5, color: AppColors.accentRed.withValues(alpha: 0.5)),
    const SizedBox(width: 10),
    Text(title.toUpperCase(), style: GoogleFonts.dmSans(
        fontSize: 12, fontWeight: FontWeight.w600,
        color: AppColors.accentRed, letterSpacing: 1.5)),
    const SizedBox(width: 10),
    Expanded(child: Container(height: 1.5, color: AppColors.accentRed.withValues(alpha: 0.5))),
  ]);
}

class _Pill extends StatelessWidget {
  final String text;
  const _Pill(this.text);
  @override Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: AppColors.accentRed.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(8)),
    child: Text(text, style: GoogleFonts.dmSans(
        fontSize: 12, color: AppColors.accentRed, fontWeight: FontWeight.w600)),
  );
}

class _FontBtn extends StatelessWidget {
  final String label, value, current;
  final VoidCallback onTap;
  const _FontBtn({required this.label, required this.value,
    required this.current, required this.onTap});
  @override Widget build(BuildContext context) {
    final sel = value == current;
    return Expanded(child: GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: sel ? AppColors.woodBrown : AppColors.creamLight,
          borderRadius: BorderRadius.circular(10)),
        child: Column(children: [
          Text('Aa', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700,
              color: sel ? AppColors.paperWarm : AppColors.inkDark)),
          const SizedBox(height: 4),
          Text(label, style: GoogleFonts.dmSans(fontSize: 10,
              color: sel ? AppColors.paperWarm : AppColors.mutedBrown)),
        ]),
      ),
    ));
  }
}

class _ThemeDot extends StatelessWidget {
  final String label, value, current;
  final Color bg;
  final VoidCallback onTap;
  const _ThemeDot({required this.label, required this.value,
    required this.bg, required this.current, required this.onTap});
  @override Widget build(BuildContext context) {
    final sel = value == current;
    return GestureDetector(
      onTap: onTap,
      child: Column(children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 50, height: 50,
          decoration: BoxDecoration(
            color: bg, shape: BoxShape.circle,
            border: Border.all(color: sel ? AppColors.accentRed : Colors.transparent, width: 3),
            boxShadow: [BoxShadow(
                color: Colors.black.withValues(alpha: 0.1), blurRadius: 4, offset: const Offset(0, 2))]),
          child: Center(child: Text('A', style: TextStyle(
              fontSize: 20, fontWeight: FontWeight.w700,
              color: bg.computeLuminance() > 0.5 ? Colors.black87 : Colors.white70))),
        ),
        const SizedBox(height: 4),
        Text(label, style: GoogleFonts.dmSans(fontSize: 10,
            color: sel ? AppColors.accentRed : AppColors.mutedBrown,
            fontWeight: sel ? FontWeight.w600 : FontWeight.w400)),
      ]),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final IconData icon;
  final String label, subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _ToggleRow({required this.icon, required this.label, required this.subtitle,
    required this.value, required this.onChanged});
  @override Widget build(BuildContext context) => Row(children: [
    Container(width: 36, height: 36,
      decoration: BoxDecoration(color: AppColors.creamLight, borderRadius: BorderRadius.circular(8)),
      child: Icon(icon, size: 18, color: AppColors.mutedBrown)),
    const SizedBox(width: 12),
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: GoogleFonts.dmSans(
          fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.inkDark)),
      Text(subtitle, style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.mutedBrown)),
    ])),
    Switch(value: value, onChanged: onChanged, activeColor: AppColors.accentRed),
  ]);
}

class _PreviewBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _PreviewBtn({required this.label, required this.onTap});
  @override Widget build(BuildContext context) => Expanded(
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.creamLight,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.mutedBrown.withValues(alpha: 0.2)),
        ),
        child: Center(child: Text('▶  $label', style: GoogleFonts.dmSans(
            fontSize: 12, color: AppColors.mutedBrown, fontWeight: FontWeight.w500))),
      ),
    ),
  );
}
