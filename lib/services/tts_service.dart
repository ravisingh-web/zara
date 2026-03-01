// lib/services/tts_service.dart
// Z.A.R.A. — Human-Like Voice Engine v2.0
// ✅ flutter_tts — offline, no API key needed
// ✅ Emotional voice — pitch/rate/volume mood se change hoti hai
// ✅ Hamesha bolti hai — auto-speak har response pe
// ✅ Mastikhor tone — laughs, sighs, expressions
// ✅ Hindi + Hinglish support
// ✅ Interrupt karo — baat mid-mein rok sako
// ✅ Idle baat — jab user chup ho tab bhi bolti hai

import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:zara/core/enums/mood_enum.dart';

class ZaraTtsService {
  // ── Singleton ──────────────────────────────────────────────────────────────
  static final ZaraTtsService _instance = ZaraTtsService._internal();
  factory ZaraTtsService() => _instance;
  ZaraTtsService._internal();

  final FlutterTts _tts = FlutterTts();
  final _rnd           = Random();

  bool _initialized  = false;
  bool _isSpeaking   = false;
  bool _enabled      = true;   // Master switch
  Mood _currentMood  = Mood.calm;

  // Callbacks
  VoidCallback? onSpeakStart;
  VoidCallback? onSpeakDone;

  // Idle timer
  Timer? _idleTimer;
  DateTime _lastActivity = DateTime.now();

  // ── Idle phrases Zara bolti hai jab user chup ho ──────────────────────────
  static const _idlePhrases = [
    'Sir... kuch kaam batao na... bor ho rahi hoon.',
    'Ummm... Sir aap kahan kho gaye?',
    'Sir, kya main kuch help kar sakti hoon?',
    'Httt... main yahan hoon Sir, bhool mat jaana!',
    '*yawns* Sir... neend aa rahi hai mujhe... kuch bolo na.',
    'Wooooow Sir itni der se chup ho... sab theek hai na?',
    'Oho Sir... main wait kar rahi hoon!',
    'Acha ji... toh main kya apne aap se baat karoon?',
    '*giggles* Sir, aapko pata hai main bahut sochti hoon aapke baare mein.',
    'Uffff Sir... kuch toh bolo!',
  ];

  // ══════════════════════════════════════════════════════════════════════════
  // INIT
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> initialize() async {
    if (_initialized) return;
    try {
      // Language — Hindi + English mix
      await _tts.setLanguage('hi-IN');

      // Default voice settings
      await _tts.setSpeechRate(0.48);   // Natural speed — not robotic
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.1);         // Slightly higher — feminine

      // Android: use best available engine
      await _tts.setEngine(await _tts.getDefaultEngine ?? 'com.google.android.tts');

      // Callbacks
      _tts.setStartHandler(() {
        _isSpeaking = true;
        onSpeakStart?.call();
      });
      _tts.setCompletionHandler(() {
        _isSpeaking = false;
        onSpeakDone?.call();
      });
      _tts.setCancelHandler(() {
        _isSpeaking = false;
        onSpeakDone?.call();
      });
      _tts.setErrorHandler((msg) {
        _isSpeaking = false;
        if (kDebugMode) debugPrint('⚠️ TTS error: $msg');
      });

      _initialized = true;
      if (kDebugMode) debugPrint('✅ ZaraTtsService initialized');
    } catch (e) {
      if (kDebugMode) debugPrint('❌ TTS init error: $e');
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // MAIN SPEAK — with emotion processing
  // ══════════════════════════════════════════════════════════════════════════

  /// Har AI response ke baad ye call hoti hai
  Future<void> speak(String text, {Mood? mood}) async {
    if (!_enabled || text.trim().isEmpty) return;
    if (!_initialized) await initialize();

    _currentMood = mood ?? _currentMood;
    _lastActivity = DateTime.now();

    // Stop current speech
    await _tts.stop();

    // Apply emotional voice settings
    await _applyMoodVoice(_currentMood);

    // Clean text — remove markdown, brackets, system commands
    final clean = _cleanTextForSpeech(text);
    if (clean.isEmpty) return;

    // Split long text into chunks — sounds more natural
    final chunks = _splitIntoChunks(clean);

    for (final chunk in chunks) {
      if (!_enabled) break;
      await _tts.speak(chunk);
      // Wait for chunk to finish before next
      await _waitForSpeech();
    }
  }

  /// Ek chhoti si baat — bina response ka (idle, reactions)
  Future<void> sayQuick(String text) async {
    if (!_enabled || text.trim().isEmpty) return;
    if (!_initialized) await initialize();
    await _tts.stop();
    await _tts.speak(text);
  }

  /// Reaction sounds — "Ummm", "Wooow", "Htt stt"
  Future<void> sayReaction(String reaction) async {
    await sayQuick(reaction);
  }

  /// Stop speaking immediately
  Future<void> stop() async {
    _isSpeaking = false;
    await _tts.stop();
  }

  bool get isSpeaking => _isSpeaking;
  bool get isEnabled  => _enabled;

  void setEnabled(bool val) => _enabled = val;

  void setMood(Mood mood) {
    _currentMood = mood;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // EMOTIONAL VOICE — pitch + rate + volume mood se
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _applyMoodVoice(Mood mood) async {
    switch (mood) {
      case Mood.romantic:
        // Naram, dheemi, pyaar bhari awaaz
        await _tts.setSpeechRate(0.40);
        await _tts.setPitch(1.15);
        await _tts.setVolume(0.85);
        break;

      case Mood.excited:
        // Tez, energetic, zor se
        await _tts.setSpeechRate(0.58);
        await _tts.setPitch(1.25);
        await _tts.setVolume(1.0);
        break;

      case Mood.angry:
        // Strong, clear, thodi tez
        await _tts.setSpeechRate(0.52);
        await _tts.setPitch(0.90);
        await _tts.setVolume(1.0);
        break;

      case Mood.ziddi:
        // Zyada confident, thodi naraaz
        await _tts.setSpeechRate(0.50);
        await _tts.setPitch(0.95);
        await _tts.setVolume(1.0);
        break;

      case Mood.coding:
        // Focus, clear, professional
        await _tts.setSpeechRate(0.46);
        await _tts.setPitch(1.05);
        await _tts.setVolume(0.90);
        break;

      case Mood.analysis:
        // Slow, thoughtful
        await _tts.setSpeechRate(0.44);
        await _tts.setPitch(1.00);
        await _tts.setVolume(0.90);
        break;

      case Mood.automation:
        // Confident, crisp
        await _tts.setSpeechRate(0.50);
        await _tts.setPitch(1.08);
        await _tts.setVolume(1.0);
        break;

      case Mood.calm:
      default:
        // Natural, warm
        await _tts.setSpeechRate(0.47);
        await _tts.setPitch(1.10);
        await _tts.setVolume(0.95);
        break;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // TEXT CLEANING — TTS ke liye readable format
  // ══════════════════════════════════════════════════════════════════════════

  String _cleanTextForSpeech(String text) {
    String clean = text;

    // Remove God Mode commands — user ko sunna nahi chahiye
    clean = clean.replaceAll(RegExp(r'\[COMMAND:[^\]]*\]'), '');

    // Remove markdown
    clean = clean.replaceAll(RegExp(r'\*\*([^*]+)\*\*'), r'$1');  // bold
    clean = clean.replaceAll(RegExp(r'\*([^*]+)\*'), r'$1');       // italic
    clean = clean.replaceAll(RegExp(r'`[^`]+`'), '');               // code
    clean = clean.replaceAll(RegExp(r'```[\s\S]*?```'), '');        // code blocks
    clean = clean.replaceAll(RegExp(r'#{1,6}\s'), '');              // headers
    clean = clean.replaceAll(RegExp(r'\[([^\]]+)\]\([^)]+\)'), r'$1'); // links

    // Keep asterisk actions — TTS inhe naturally bol sakti hai
    // *giggles* → giggles (without asterisks)
    clean = clean.replaceAll(RegExp(r'\*([^*]+)\*'), r'$1');

    // Remove emojis (optional — TTS inhe weird bolti hai)
    // clean = clean.replaceAll(RegExp(r'[^\x00-\x7F\u0900-\u097F\s]'), '');

    // Remove extra whitespace
    clean = clean.replaceAll(RegExp(r'\n{2,}'), '. ');
    clean = clean.replaceAll('\n', '. ');
    clean = clean.replaceAll(RegExp(r'\s{2,}'), ' ');
    clean = clean.trim();

    // Limit length — 800 chars max per speak call
    if (clean.length > 800) {
      clean = '${clean.substring(0, 800)}... aur bhi hai Sir, padhte rehiye.';
    }

    return clean;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // CHUNK SPLITTING — natural pauses
  // ══════════════════════════════════════════════════════════════════════════

  List<String> _splitIntoChunks(String text) {
    // Split at sentence boundaries for natural speech
    final sentences = text.split(RegExp(r'(?<=[.!?।])\s+'));
    final chunks    = <String>[];
    var   current   = StringBuffer();

    for (final s in sentences) {
      if (current.length + s.length > 200) {
        if (current.isNotEmpty) {
          chunks.add(current.toString().trim());
          current.clear();
        }
      }
      current.write('$s ');
    }
    if (current.isNotEmpty) chunks.add(current.toString().trim());
    return chunks.isEmpty ? [text] : chunks;
  }

  Future<void> _waitForSpeech() async {
    // Poll until done or timeout
    int waited = 0;
    while (_isSpeaking && waited < 30000) {
      await Future.delayed(const Duration(milliseconds: 100));
      waited += 100;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // IDLE SYSTEM — user chup hai to Zara khud bolti hai
  // ══════════════════════════════════════════════════════════════════════════

  void startIdleSystem() {
    _idleTimer?.cancel();
    _idleTimer = Timer.periodic(const Duration(minutes: 3), (_) {
      _checkAndSpeakIdle();
    });
  }

  void stopIdleSystem() {
    _idleTimer?.cancel();
    _idleTimer = null;
  }

  void resetIdleTimer() {
    _lastActivity = DateTime.now();
  }

  Future<void> _checkAndSpeakIdle() async {
    if (!_enabled) return;
    if (_isSpeaking) return;

    final idle = DateTime.now().difference(_lastActivity).inMinutes;
    if (idle >= 3) {
      final phrase = _idlePhrases[_rnd.nextInt(_idlePhrases.length)];
      await sayQuick(phrase);
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // DISPOSE
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> dispose() async {
    stopIdleSystem();
    await _tts.stop();
    _initialized = false;
  }
}
