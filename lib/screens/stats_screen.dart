// lib/screens/stats_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/library_provider.dart';
import '../models/document.dart';
import '../utils/app_theme.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});
  @override State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> with SingleTickerProviderStateMixin {
  late TabController _tab;
  @override void initState() { super.initState(); _tab = TabController(length: 3, vsync: this); }
  @override void dispose() { _tab.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final lib = context.watch<LibraryProvider>();

    return Scaffold(
      backgroundColor: AppColors.creamLight,
      body: NestedScrollView(
        headerSliverBuilder: (ctx, _) => [
          SliverAppBar(
            pinned: true, backgroundColor: AppColors.woodBrown,
            title: Text('Profile & Stats', style: GoogleFonts.playfairDisplay(
                fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.paperWarm)),
            bottom: TabBar(
              controller: _tab,
              indicatorColor: AppColors.accentRed, indicatorWeight: 2,
              labelColor: AppColors.accentRed,
              unselectedLabelColor: AppColors.paperWarm.withValues(alpha: 0.5),
              labelStyle: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600),
              tabs: const [Tab(text: 'Stats'), Tab(text: 'Achievements'), Tab(text: 'History')],
            ),
          ),
        ],
        body: TabBarView(controller: _tab, children: [
          _StatsTab(lib: lib),
          _AchievementsTab(lib: lib),
          _HistoryTab(lib: lib),
        ]),
      ),
    );
  }
}

// ── Stats Tab ─────────────────────────────────────────────────────────────────
class _StatsTab extends StatelessWidget {
  final LibraryProvider lib;
  const _StatsTab({required this.lib});

  @override Widget build(BuildContext context) {
    final finished = lib.finishedBooks.length;
    final goal = lib.goal;
    final progress = (finished / goal.targetBooks).clamp(0.0, 1.0);

    return ListView(padding: const EdgeInsets.all(16), children: [
      // Reading goal card
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: AppColors.woodBrown, borderRadius: BorderRadius.circular(16)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('${goal.year} Reading Goal', style: GoogleFonts.playfairDisplay(
                fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.paperWarm)),
            IconButton(icon: const Icon(Icons.edit, color: AppColors.accentRed, size: 18),
                onPressed: () => _editGoal(context)),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Text('$finished', style: GoogleFonts.playfairDisplay(
                fontSize: 48, fontWeight: FontWeight.w700, color: AppColors.accentRed)),
            Text(' / ${goal.targetBooks} books', style: GoogleFonts.dmSans(
                fontSize: 18, color: AppColors.paperWarm.withValues(alpha: 0.7))),
          ]),
          const SizedBox(height: 12),
          ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(
            value: progress, minHeight: 8,
            backgroundColor: AppColors.paperWarm.withValues(alpha: 0.2),
            valueColor: const AlwaysStoppedAnimation(AppColors.accentRed))),
          const SizedBox(height: 8),
          Text('${(progress * 100).round()}% of goal reached',
              style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.paperWarm.withValues(alpha: 0.6))),
        ]),
      ),
      const SizedBox(height: 16),

      // Reading streak
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: AppColors.paperWarm, borderRadius: BorderRadius.circular(14)),
        child: Row(children: [
          Container(width: 52, height: 52, decoration: BoxDecoration(
              color: AppColors.goldAccent.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: const Center(child: Text('🔥', style: TextStyle(fontSize: 26)))),
          const SizedBox(width: 16),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Reading Streak', style: GoogleFonts.dmSans(
                fontSize: 12, color: AppColors.mutedBrown, fontWeight: FontWeight.w500)),
            Text('${lib.readingStreakDays} days in a row',
                style: GoogleFonts.playfairDisplay(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.goldAccent)),
          ]),
        ]),
      ),
      const SizedBox(height: 12),

      // Pages stats grid
      Text('PAGES READ', style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w600,
          color: AppColors.mutedBrown, letterSpacing: 1.2)),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(child: _StatCard(value: '${lib.pagesReadToday}',    label: 'Today',     color: AppColors.spineForest)),
        const SizedBox(width: 10),
        Expanded(child: _StatCard(value: '${lib.pagesReadThisWeek}', label: 'This Week',  color: AppColors.spineNavy)),
        const SizedBox(width: 10),
        Expanded(child: _StatCard(value: '${lib.pagesReadThisMonth}',label: 'This Month', color: AppColors.spineCrimson)),
      ]),
      const SizedBox(height: 16),

      // Library stats
      Text('LIBRARY', style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w600,
          color: AppColors.mutedBrown, letterSpacing: 1.2)),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(child: _StatCard(value: '${lib.collections.length}', label: 'Total Books',   color: AppColors.woodBrown)),
        const SizedBox(width: 10),
        Expanded(child: _StatCard(value: '$finished',                  label: 'Finished',       color: AppColors.spineAmber)),
        const SizedBox(width: 10),
        Expanded(child: _StatCard(value: '${lib.currentlyReading.length}', label: 'Reading Now', color: AppColors.spinePlum)),
      ]),
      const SizedBox(height: 16),

      // Collections management
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('COLLECTIONS', style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w600,
            color: AppColors.mutedBrown, letterSpacing: 1.2)),
        TextButton.icon(icon: const Icon(Icons.add, size: 16, color: AppColors.accentRed),
          label: Text('New', style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.accentRed)),
          onPressed: () => _addCollection(context)),
      ]),
      if (lib.bookCollections.isEmpty)
        Padding(padding: const EdgeInsets.only(bottom: 8),
          child: Text('No collections yet. Create one to organise your books.',
              style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.mutedBrown)))
      else
        ...lib.bookCollections.map((col) {
          final color = Color(int.parse(col.color.replaceFirst('#', '0xFF')));
          final count = lib.collections.where((b) => b.collectionId == col.id).length;
          return Container(margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(color: AppColors.paperWarm, borderRadius: BorderRadius.circular(10)),
            child: Row(children: [
              Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 12),
              Expanded(child: Text(col.name, style: GoogleFonts.dmSans(
                  fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.inkDark))),
              Text('$count books', style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.mutedBrown)),
              IconButton(icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.mutedBrown),
                onPressed: () => context.read<LibraryProvider>().deleteCollection(col.id)),
            ]),
          );
        }),
      const SizedBox(height: 32),
    ]);
  }

  void _editGoal(BuildContext context) {
    int target = context.read<LibraryProvider>().goal.targetBooks;
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: Text('Set Reading Goal', style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.w700)),
      content: StatefulBuilder(builder: (ctx2, setState) => Column(mainAxisSize: MainAxisSize.min, children: [
        Text('Books to read in ${DateTime.now().year}',
            style: GoogleFonts.dmSans(fontSize: 14, color: AppColors.mutedBrown)),
        const SizedBox(height: 16),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          IconButton(onPressed: () => setState(() { if (target > 1) target--; }),
              icon: const Icon(Icons.remove_circle_outline, color: AppColors.accentRed)),
          Text('$target', style: GoogleFonts.playfairDisplay(fontSize: 36, fontWeight: FontWeight.w700, color: AppColors.accentRed)),
          IconButton(onPressed: () => setState(() => target++),
              icon: const Icon(Icons.add_circle_outline, color: AppColors.accentRed)),
        ]),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () { context.read<LibraryProvider>().setGoal(target); Navigator.pop(ctx); },
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.accentRed, foregroundColor: Colors.white),
          child: const Text('Save')),
      ],
    ));
  }

  void _addCollection(BuildContext context) {
    String name = '';
    String color = '#2D3561';
    final colors = ['#2D3561', '#1B4332', '#6B2D3E', '#7B3F00', '#4A1942', '#2C3E50'];
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: Text('New Collection', style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.w700)),
      content: StatefulBuilder(builder: (ctx2, setState) => Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(onChanged: (v) => name = v,
          decoration: InputDecoration(hintText: 'Collection name', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)))),
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: colors.map((c) {
            final col = Color(int.parse(c.replaceFirst('#', '0xFF')));
            final sel = color == c;
            return GestureDetector(onTap: () => setState(() => color = c),
              child: Container(width: 32, height: 32, decoration: BoxDecoration(color: col, shape: BoxShape.circle,
                  border: Border.all(color: sel ? Colors.white : Colors.transparent, width: 3),
                  boxShadow: sel ? [BoxShadow(color: col.withValues(alpha: 0.5), blurRadius: 8)] : null)));
          }).toList()),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () {
            if (name.trim().isNotEmpty) context.read<LibraryProvider>().addCollection(name.trim(), color);
            Navigator.pop(ctx);
          },
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.accentRed, foregroundColor: Colors.white),
          child: const Text('Create')),
      ],
    ));
  }
}

// ── Achievements Tab ──────────────────────────────────────────────────────────
class _AchievementsTab extends StatelessWidget {
  final LibraryProvider lib;
  const _AchievementsTab({required this.lib});

  @override Widget build(BuildContext context) {
    final unlocked = lib.achievements.where((a) => a.unlocked).toList();
    final locked   = lib.achievements.where((a) => !a.unlocked).toList();

    return ListView(padding: const EdgeInsets.all(16), children: [
      if (unlocked.isNotEmpty) ...[
        Text('UNLOCKED (${unlocked.length})', style: GoogleFonts.dmSans(fontSize: 11,
            fontWeight: FontWeight.w600, color: AppColors.mutedBrown, letterSpacing: 1.2)),
        const SizedBox(height: 8),
        ...unlocked.map((a) => _AchievCard(achievement: a)),
        const SizedBox(height: 16),
      ],
      Text('LOCKED (${locked.length})', style: GoogleFonts.dmSans(fontSize: 11,
          fontWeight: FontWeight.w600, color: AppColors.mutedBrown, letterSpacing: 1.2)),
      const SizedBox(height: 8),
      ...locked.map((a) => _AchievCard(achievement: a)),
    ]);
  }
}

class _AchievCard extends StatelessWidget {
  final Achievement achievement;
  const _AchievCard({required this.achievement});
  @override Widget build(BuildContext context) {
    final a = achievement;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: a.unlocked ? AppColors.paperWarm : AppColors.creamLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: a.unlocked ? AppColors.goldAccent.withValues(alpha: 0.5) : Colors.transparent, width: 1.5),
      ),
      child: Row(children: [
        Text(a.unlocked ? a.emoji : '🔒', style: TextStyle(fontSize: a.unlocked ? 28 : 22)),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(a.title, style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w600,
              color: a.unlocked ? AppColors.inkDark : AppColors.mutedBrown)),
          Text(a.description, style: GoogleFonts.dmSans(fontSize: 12,
              color: a.unlocked ? AppColors.mutedBrown : AppColors.mutedBrown.withValues(alpha: 0.6))),
          if (a.unlocked && a.unlockedAt != null)
            Text('Unlocked ${_formatDate(a.unlockedAt!)}',
                style: GoogleFonts.dmSans(fontSize: 10, color: AppColors.goldAccent)),
        ])),
        if (a.unlocked) const Icon(Icons.verified, color: AppColors.goldAccent, size: 20),
      ]),
    );
  }

  String _formatDate(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inDays > 6) return '${d.day}.${d.month}.${d.year}';
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    return 'today';
  }
}

// ── History Tab ───────────────────────────────────────────────────────────────
class _HistoryTab extends StatelessWidget {
  final LibraryProvider lib;
  const _HistoryTab({required this.lib});

  @override Widget build(BuildContext context) {
    final history = lib.history;
    if (history.isEmpty) return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.history, size: 56, color: AppColors.mutedBrown.withValues(alpha: 0.3)),
      const SizedBox(height: 16),
      Text('No reading history yet', style: GoogleFonts.playfairDisplay(
          fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.mutedBrown)),
    ]));

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: history.length,
      separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFE8E0D0), indent: 16, endIndent: 16),
      itemBuilder: (_, i) {
        final entry = history[i];
        final diff = DateTime.now().difference(entry.openedAt);
        String timeStr;
        if (diff.inDays > 0) timeStr = '${diff.inDays}d ago';
        else if (diff.inHours > 0) timeStr = '${diff.inHours}h ago';
        else timeStr = 'just now';

        return ListTile(
          leading: Container(width: 40, height: 40,
            decoration: BoxDecoration(color: AppColors.creamLight, borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.menu_book_rounded, color: AppColors.mutedBrown, size: 20)),
          title: Text(entry.bookTitle, style: GoogleFonts.dmSans(
              fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.inkDark), maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(timeStr, style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.mutedBrown)),
          trailing: Text('${entry.openedAt.hour.toString().padLeft(2, "0")}:${entry.openedAt.minute.toString().padLeft(2, "0")}',
              style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.mutedBrown)),
        );
      },
    );
  }
}

// ─── Widgets ──────────────────────────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final String value, label;
  final Color color;
  const _StatCard({required this.value, required this.label, required this.color});
  @override Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: AppColors.paperWarm, borderRadius: BorderRadius.circular(12)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(value, style: GoogleFonts.playfairDisplay(fontSize: 26, fontWeight: FontWeight.w700, color: color)),
      const SizedBox(height: 2),
      Text(label, style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.mutedBrown)),
    ]),
  );
}
