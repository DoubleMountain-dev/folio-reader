// lib/main.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'providers/library_provider.dart';
import 'screens/main_screen.dart';
import 'utils/app_theme.dart';

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;
  runApp(const FolioApp());
}

class FolioApp extends StatelessWidget {
  const FolioApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => LibraryProvider(),
      child: MaterialApp(
        title: 'Folio',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: const MainScreen(),
      ),
    );
  }
}
