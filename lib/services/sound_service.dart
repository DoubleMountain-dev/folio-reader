// lib/services/sound_service.dart
//
// Centralised audio service for Folio Reader.
// Handles: page turn SFX, UI sounds, looping ambience.
// Uses audioplayers package which works in Flutter Web via HTML5 Audio.

import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum PageTurnStyle { paper, click, none }
enum AmbienceTrack { none, cafe, rain, fireplace, forest }

class SoundService {
  // Singleton
  SoundService._();
  static final SoundService instance = SoundService._();

  final AudioPlayer _sfxPlayer      = AudioPlayer();
  final AudioPlayer _sfxPlayer2     = AudioPlayer(); // second channel for overlapping UI sounds
  final AudioPlayer _ambiencePlayer = AudioPlayer();

  // Settings
  bool            sfxEnabled       = true;
  bool            ambienceEnabled  = false;
  double          sfxVolume        = 0.65;
  double          ambienceVolume   = 0.30;
  PageTurnStyle   pageTurnStyle    = PageTurnStyle.paper;
  AmbienceTrack   currentAmbience  = AmbienceTrack.none;

  bool _initialised = false;

  // ── Init ──────────────────────────────────────────────────────────────────

  Future<void> init() async {
    if (_initialised) return;
    _initialised = true;

    await _sfxPlayer.setReleaseMode(ReleaseMode.stop);
    await _sfxPlayer2.setReleaseMode(ReleaseMode.stop);
    await _ambiencePlayer.setReleaseMode(ReleaseMode.loop);

    await _loadPrefs();
  }

  // ── Page turn ─────────────────────────────────────────────────────────────

  Future<void> playPageTurn() async {
    if (!sfxEnabled || pageTurnStyle == PageTurnStyle.none) return;
    final file = pageTurnStyle == PageTurnStyle.paper
        ? 'sounds/page_turn_paper.wav'
        : 'sounds/page_turn_click.wav';
    await _play(_sfxPlayer, file, sfxVolume);
  }

  // ── UI sounds ─────────────────────────────────────────────────────────────

  Future<void> playBookmarkAdd() async {
    if (!sfxEnabled) return;
    await _play(_sfxPlayer2, 'sounds/bookmark_add.wav', sfxVolume * 0.85);
  }

  Future<void> playQuoteSave() async {
    if (!sfxEnabled) return;
    await _play(_sfxPlayer2, 'sounds/quote_save.wav', sfxVolume * 0.85);
  }

  Future<void> playAchievement() async {
    if (!sfxEnabled) return;
    await _play(_sfxPlayer2, 'sounds/achievement.wav', sfxVolume);
  }

  Future<void> playBookOpen() async {
    if (!sfxEnabled) return;
    await _play(_sfxPlayer, 'sounds/book_open.wav', sfxVolume * 0.7);
  }

  Future<void> playBookAdd() async {
    if (!sfxEnabled) return;
    await _play(_sfxPlayer2, 'sounds/book_add.wav', sfxVolume * 0.8);
  }

  // ── Ambience ──────────────────────────────────────────────────────────────

  Future<void> startAmbience(AmbienceTrack track) async {
    if (track == AmbienceTrack.none) { await stopAmbience(); return; }
    currentAmbience = track;
    ambienceEnabled = true;
    final file = _ambienceFile(track);
    await _ambiencePlayer.setVolume(ambienceVolume);
    await _ambiencePlayer.setReleaseMode(ReleaseMode.loop);
    await _ambiencePlayer.play(AssetSource(file));
    await _savePrefs();
  }

  Future<void> stopAmbience() async {
    currentAmbience = AmbienceTrack.none;
    ambienceEnabled = false;
    await _ambiencePlayer.stop();
    await _savePrefs();
  }

  Future<void> setAmbienceVolume(double v) async {
    ambienceVolume = v.clamp(0.0, 1.0);
    await _ambiencePlayer.setVolume(ambienceVolume);
    await _savePrefs();
  }

  Future<void> setSfxVolume(double v) async {
    sfxVolume = v.clamp(0.0, 1.0);
    await _savePrefs();
  }

  Future<void> setPageTurnStyle(PageTurnStyle style) async {
    pageTurnStyle = style;
    await _savePrefs();
  }

  Future<void> setSfxEnabled(bool v) async {
    sfxEnabled = v;
    if (!v) await _sfxPlayer.stop();
    await _savePrefs();
  }

  // ── Persistence ───────────────────────────────────────────────────────────

  Future<void> _savePrefs() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setBool('snd_sfx_enabled',    sfxEnabled);
      await p.setBool('snd_amb_enabled',    ambienceEnabled);
      await p.setDouble('snd_sfx_vol',      sfxVolume);
      await p.setDouble('snd_amb_vol',      ambienceVolume);
      await p.setInt('snd_page_style',      pageTurnStyle.index);
      await p.setInt('snd_ambience_track',  currentAmbience.index);
    } catch (_) {}
  }

  Future<void> _loadPrefs() async {
    try {
      final p = await SharedPreferences.getInstance();
      sfxEnabled      = p.getBool('snd_sfx_enabled')   ?? true;
      ambienceEnabled = p.getBool('snd_amb_enabled')   ?? false;
      sfxVolume       = p.getDouble('snd_sfx_vol')     ?? 0.65;
      ambienceVolume  = p.getDouble('snd_amb_vol')     ?? 0.30;
      final ptIdx     = p.getInt('snd_page_style')     ?? 0;
      final ambIdx    = p.getInt('snd_ambience_track') ?? 0;
      pageTurnStyle   = PageTurnStyle.values[ptIdx.clamp(0, PageTurnStyle.values.length - 1)];
      currentAmbience = AmbienceTrack.values[ambIdx.clamp(0, AmbienceTrack.values.length - 1)];

      // Resume ambience if it was playing
      if (ambienceEnabled && currentAmbience != AmbienceTrack.none) {
        await startAmbience(currentAmbience);
      }
    } catch (_) {}
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Future<void> _play(AudioPlayer player, String asset, double volume) async {
    try {
      await player.setVolume(volume);
      await player.play(AssetSource(asset));
    } catch (_) {
      // Audio not supported or file missing — fail silently
    }
  }

  String _ambienceFile(AmbienceTrack track) {
    switch (track) {
      case AmbienceTrack.cafe:      return 'sounds/ambience/cafe.wav';
      case AmbienceTrack.rain:      return 'sounds/ambience/rain.wav';
      case AmbienceTrack.fireplace: return 'sounds/ambience/fireplace.wav';
      case AmbienceTrack.forest:    return 'sounds/ambience/forest.wav';
      case AmbienceTrack.none:      return '';
    }
  }

  String ambienceLabel(AmbienceTrack t) {
    switch (t) {
      case AmbienceTrack.none:      return 'None';
      case AmbienceTrack.cafe:      return 'Cafe';
      case AmbienceTrack.rain:      return 'Rain';
      case AmbienceTrack.fireplace: return 'Fireplace';
      case AmbienceTrack.forest:    return 'Forest';
    }
  }

  String ambienceEmoji(AmbienceTrack t) {
    switch (t) {
      case AmbienceTrack.none:      return '';
      case AmbienceTrack.cafe:      return '☕';
      case AmbienceTrack.rain:      return '🌧';
      case AmbienceTrack.fireplace: return '🔥';
      case AmbienceTrack.forest:    return '🌲';
    }
  }

  void dispose() {
    _sfxPlayer.dispose();
    _sfxPlayer2.dispose();
    _ambiencePlayer.dispose();
  }
}
