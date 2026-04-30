// lib/screens/reading_settings_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/document.dart';
import '../providers/library_provider.dart';
import '../utils/app_theme.dart';

class ReadingSettingsScreen extends StatelessWidget {
  const ReadingSettingsScreen({super.key});

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
          // Font family
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

          // Font size
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
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: AppColors.accentRed.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8)),
              child: Text('${s.fontSize.round()}px', style: GoogleFonts.dmSans(
                  fontSize: 12, color: AppColors.accentRed, fontWeight: FontWeight.w600)),
            ),
          ])),
          const SizedBox(height: 12),

          // Line spacing
          _Card(title: 'Line Spacing', child: Row(children: [
            Icon(Icons.format_line_spacing, color: AppColors.mutedBrown, size: 18),
            Expanded(child: Slider(
              value: s.lineHeight, min: 1.2, max: 2.4, divisions: 6,
              activeColor: AppColors.accentRed,
              inactiveColor: AppColors.mutedBrown.withValues(alpha: 0.2),
              onChanged: (v) => library.updateSettings(s.copyWith(lineHeight: v)),
            )),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: AppColors.accentRed.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8)),
              child: Text('${s.lineHeight.toStringAsFixed(1)}x', style: GoogleFonts.dmSans(
                  fontSize: 12, color: AppColors.accentRed, fontWeight: FontWeight.w600)),
            ),
          ])),
          const SizedBox(height: 12),

          // Theme
          _Card(title: 'Theme', child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
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

          // Preview
          _Card(title: 'Preview', child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: s.backgroundColor,
                borderRadius: BorderRadius.circular(8)),
            child: Text(
              'Manuscripts don\'t burn. It was not merely a phrase -- it was an axiom believed by all readers of great books.',
              style: GoogleFonts.playfairDisplay(
                  fontSize: s.fontSize * 0.85, height: s.lineHeight, color: s.textColor)),
          )),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final String title;
  final Widget child;
  const _Card({required this.title, required this.child});
  @override
  Widget build(BuildContext context) => Container(
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

class _FontBtn extends StatelessWidget {
  final String label, value, current;
  final VoidCallback onTap;
  const _FontBtn({required this.label, required this.value,
    required this.current, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final sel = value == current;
    return Expanded(child: GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: sel ? AppColors.woodBrown : AppColors.creamLight,
          borderRadius: BorderRadius.circular(10),
        ),
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
  @override
  Widget build(BuildContext context) {
    final sel = value == current;
    return GestureDetector(
      onTap: onTap,
      child: Column(children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 50, height: 50,
          decoration: BoxDecoration(
            color: bg, shape: BoxShape.circle,
            border: Border.all(
                color: sel ? AppColors.accentRed : Colors.transparent, width: 3),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 4, offset: const Offset(0, 2))],
          ),
          child: Center(child: Text('A', style: TextStyle(
              fontSize: 20, fontWeight: FontWeight.w700,
              color: bg.computeLuminance() > 0.5 ? Colors.black87 : Colors.white70))),
        ),
        const SizedBox(height: 4),
        Text(label, style: GoogleFonts.dmSans(
            fontSize: 10,
            color: sel ? AppColors.accentRed : AppColors.mutedBrown,
            fontWeight: sel ? FontWeight.w600 : FontWeight.w400)),
      ]),
    );
  }
}
