// lib/screens/main_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/app_theme.dart';
import 'library_screen.dart';
import 'notes_screen.dart';
import 'stats_screen.dart';
import 'reading_settings_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});
  @override State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _idx = 0;
  final _screens = [
    const LibraryScreen(),
    const NotesScreen(),
    const StatsScreen(),
    const ReadingSettingsScreen(),
  ];

  @override Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _idx, children: _screens),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(color: AppColors.woodBrown, boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, -4))]),
        child: SafeArea(child: SizedBox(height: 60, child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
          _NavItem(icon: Icons.auto_stories, label: 'Library',  selected: _idx == 0, onTap: () => setState(() => _idx = 0)),
          _NavItem(icon: Icons.bookmark_rounded, label: 'Notes', selected: _idx == 1, onTap: () => setState(() => _idx = 1)),
          _NavItem(icon: Icons.bar_chart_rounded, label: 'Stats', selected: _idx == 2, onTap: () => setState(() => _idx = 2)),
          _NavItem(icon: Icons.tune_rounded, label: 'Settings', selected: _idx == 3, onTap: () => setState(() => _idx = 3)),
        ]))),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon; final String label; final bool selected; final VoidCallback onTap;
  const _NavItem({required this.icon, required this.label, required this.selected, required this.onTap});
  @override Widget build(BuildContext context) => GestureDetector(
    onTap: onTap, behavior: HitTestBehavior.opaque,
    child: SizedBox(width: 80, child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      AnimatedContainer(duration: const Duration(milliseconds: 200), padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: selected ? AppColors.accentRed.withValues(alpha: 0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, size: 22, color: selected ? AppColors.accentRed : AppColors.paperWarm.withValues(alpha: 0.5))),
      const SizedBox(height: 2),
      Text(label, style: GoogleFonts.dmSans(fontSize: 10,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          color: selected ? AppColors.accentRed : AppColors.paperWarm.withValues(alpha: 0.5))),
    ])),
  );
}
