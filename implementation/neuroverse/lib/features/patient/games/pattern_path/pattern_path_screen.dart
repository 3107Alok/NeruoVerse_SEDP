import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../../core/models/game_session.dart';
import '../../../../data/local/hive_service.dart' as app_hive;
import '../../../../core/services/adaptive_intelligence_service.dart';
import '../../../../core/services/sync_service.dart';
import '../../../../core/services/voice_service.dart';
import '../common/game_results_screen.dart';
import '../../../../providers/app_provider.dart';
import '../../../../core/localization/app_translations.dart';

class PatternPathScreen extends StatefulWidget {
  final int difficulty;
  const PatternPathScreen({super.key, this.difficulty = 1});

  @override
  State<PatternPathScreen> createState() => _PatternPathScreenState();
}

class _PatternPathScreenState extends State<PatternPathScreen> {
  int _currentDifficulty = 1;
  
  late int _gridSize; // 2 for 2x2, 3 for 3x3, etc.
  late int _sequenceLength;
  
  final List<int> _sequence = [];
  int _userStep = 0;
  
  int _activeTile = -1;
  bool _isPlayingSequence = false;
  
  int _mistakes = 0;
  int _hintsUsed = 0;
  int _hintTile = -1;
  final Stopwatch _stopwatch = Stopwatch();
  VoiceService? _voiceService;
  bool _navigatedToResults = false;

  @override
  void initState() {
    super.initState();
    _currentDifficulty = widget.difficulty;
    _initializeGame();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    try {
      _voiceService = context.read<VoiceService>();
    } catch (_) {
      _voiceService = null;
    }
  }

  void _initializeGame() {
    // Difficulty scaling
    if (_currentDifficulty <= 3) {
      _gridSize = 2; // 2x2
    } else if (_currentDifficulty <= 7) {
      _gridSize = 3; // 3x3
    } else {
      _gridSize = 4; // 4x4
    }
    
    _sequenceLength = 2 + _currentDifficulty; // Level 1 = 3 steps, Level 5 = 7 steps
    
    _sequence.clear();
    final random = Random();
    int totalTiles = _gridSize * _gridSize;
    for (int i = 0; i < _sequenceLength; i++) {
      _sequence.add(random.nextInt(totalTiles));
    }

    _userStep = 0;
    _mistakes = 0;
    _hintsUsed = 0;
    _hintTile = -1;
    _activeTile = -1;
    
    _stopwatch.reset();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final isTest = WidgetsBinding.instance.runtimeType.toString().contains('Test');
      if (isTest) {
        _speakInstructions(isInitial: true);
      } else {
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) {
            _speakInstructions(isInitial: true);
          }
        });
      }
    });
    
    _playSequence();
  }

  void _speakInstructions({bool isInitial = false}) {
    if (!mounted) return;
    final appProvider = context.read<AppProvider>();
    final lang = appProvider.voiceLanguage ?? appProvider.userLanguage ?? 'hi';
    final cleanLang = AppTranslations.normalizeLangCode(lang);
    final text = cleanLang == 'en'
        ? "Watch the pattern closely and repeat the sequence in order!"
        : AppTranslations.get(cleanLang, 'desc_pattern_path');
    context.read<VoiceService>().speakKey(
      'pattern_watch',
      lang: lang,
      fallbackText: text,
    );
  }

  Future<void> _playSequence() async {
    setState(() {
      _isPlayingSequence = true;
    });

    // Wait a moment before starting
    await Future.delayed(const Duration(seconds: 1));

    for (int i = 0; i < _sequence.length; i++) {
      if (!mounted) return;
      
      setState(() {
        _activeTile = _sequence[i];
      });
      
      await Future.delayed(const Duration(milliseconds: 600));
      
      if (!mounted) return;
      
      setState(() {
        _activeTile = -1; // turn off
      });
      
      await Future.delayed(const Duration(milliseconds: 300));
    }

    if (!mounted) return;
    setState(() {
      _isPlayingSequence = false;
    });
    
    _stopwatch.start();
  }

  void _onTileTap(int index) {
    if (_isPlayingSequence) return;

    if (index == _sequence[_userStep]) {
      // Correct tap
      setState(() {
        _activeTile = index;
      });
      
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) {
          setState(() {
            _activeTile = -1;
          });
        }
      });

      _userStep++;

      if (_userStep == _sequenceLength) {
        _stopwatch.stop();
        _handleGameComplete();
      }
    } else {
      // Incorrect tap
      _mistakes++;
      setState(() {
        _isPlayingSequence = true; // Block input
      });
      
      // Show error feedback (blink red or simply restart sequence)
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          _userStep = 0;
          _playSequence(); // Replay the sequence on mistake
        }
      });
    }
  }

  void _useHint() async {
    if (_isPlayingSequence || _userStep >= _sequence.length || _hintTile != -1) return;

    final nextTile = _sequence[_userStep];
    setState(() {
      _hintsUsed++;
      _hintTile = nextTile;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.lightbulb_rounded, color: Colors.amber, size: 20),
            SizedBox(width: 8),
            Text("Hint: Next root bridge stone revealed! 👣", style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        duration: const Duration(milliseconds: 1600),
        backgroundColor: const Color(0xFF00796B),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );

    await Future.delayed(const Duration(milliseconds: 1500));
    if (mounted && _hintTile == nextTile) {
      setState(() {
        _hintTile = -1;
      });
    }
  }

  Future<void> _handleGameComplete() async {
    final int completionTime = _stopwatch.elapsed.inSeconds;
    
    double accuracy = 100 - (_mistakes * 15.0);
    int accuracyInt = accuracy.clamp(0, 100).toInt();
    
    final double avgReactionTime = completionTime * 1000.0 / _sequenceLength;
    final double cogScore = (accuracy * _currentDifficulty) - (completionTime * 0.5) - (_mistakes * 5);
    final String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? 'guest_user';

    final session = GameSession(
      id: const Uuid().v4(),
      gameId: 'pattern_path',
      patientId: currentUserId,
      timestamp: DateTime.now(),
      difficultyLevel: _currentDifficulty,
      score: accuracyInt,
      accuracyPercentage: accuracyInt,
      completionTimeSeconds: completionTime,
      mistakes: _mistakes,
      hintsUsed: _hintsUsed,
      gameCategory: 'Memory & Recognition',
      reactionTimeAverageMs: avgReactionTime,
      cognitiveScore: cogScore > 0 ? cogScore : 0,
    );

    final hiveService = context.read<app_hive.HiveService>();
    final adaptiveService = context.read<AdaptiveIntelligenceService>();
    final syncService = context.read<SyncService>();
    final appProvider = context.read<AppProvider>();

    await hiveService.saveGameSession(session);
    int nextDifficulty = adaptiveService.processSessionAndGetNextDifficulty(session);
    await hiveService.saveQTable(adaptiveService.qLearningService.qTable);
    await hiveService.saveGameDifficulty('pattern_path', nextDifficulty);
    syncService.syncLocalDataToCloud().then((success) {
      if (mounted) {
        appProvider.setSyncStatus(success);
      }
    });

    if (mounted) {
      _navigatedToResults = true;
      appProvider.loadProgress();
      
      final double accuracyScore = accuracyInt / 100.0;
      
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => GameResultsScreen(
            totalChallenges: _sequenceLength, 
            completedChallenges: _sequenceLength,
            accuracy: accuracyScore,
            currentLevel: _currentDifficulty,
            nextLevel: nextDifficulty,
            nextLevelWidget: PatternPathScreen(difficulty: nextDifficulty),
            gameId: 'pattern_path',
            audioKey: 'pattern_win',
          ),
        ),
      );
    }
  }
  
  @override
  void dispose() {
    if (!_navigatedToResults) {
      _voiceService?.stopSpeaking();
    }
    _stopwatch.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          _voiceService?.stopSpeaking();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () {
              _voiceService?.stopSpeaking();
              Navigator.of(context).pop();
            },
          ),
          title: Text(context.tr('pattern_path')),
          actions: [
            if (!_isPlayingSequence)
              Container(
                margin: const EdgeInsets.only(right: 14, top: 8, bottom: 8),
                child: TextButton.icon(
                  onPressed: _useHint,
                  icon: const Icon(Icons.lightbulb_rounded, size: 18, color: Colors.amber),
                  label: Text(context.tr('hint'), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.amber)),
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.amber.withValues(alpha: 0.15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  ),
                ),
              ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Column(
            children: [

              // Instruction Card with Highlighted Sound Button
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E2D2A) : const Color(0xFFE6F4F1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark ? const Color(0xFF2E4D45) : const Color(0xFFB2DFDB),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00796B).withValues(alpha: 0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Highlighted Sound Button
                    InkWell(
                      onTap: () => _speakInstructions(isInitial: false),
                      borderRadius: BorderRadius.circular(24),
                      child: Container(
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00796B),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF00796B).withValues(alpha: 0.35),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.volume_up_rounded, color: Colors.white, size: 20),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isPlayingSequence ? context.tr('watch_pattern') : context.tr('repeat_pattern'),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isDark ? const Color(0xFF80CBC4) : const Color(0xFF004D40),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _isPlayingSequence ? context.tr('memorize_stones') : context.tr('tap_stones_order'),
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark ? Colors.white70 : Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: Center(
                child: AspectRatio(
                  aspectRatio: 1,
                  child: GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: _gridSize,
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 14,
                    ),
                    itemCount: _gridSize * _gridSize,
                    itemBuilder: (context, index) {
                      final bool isActive = index == _activeTile;
                      final bool isHinted = index == _hintTile;

                      return GestureDetector(
                        onTap: () => _onTileTap(index),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          decoration: BoxDecoration(
                            color: isActive
                                ? const Color(0xFF00897B)
                                : isHinted
                                    ? Colors.amber.shade300
                                    : (isDark ? const Color(0xFF162524) : const Color(0xFFE0F2F1)),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isHinted
                                  ? Colors.amber.shade800
                                  : (isActive
                                      ? const Color(0xFF004D40)
                                      : const Color(0xFF00796B).withValues(alpha: 0.35)),
                              width: isActive || isHinted ? 4 : 2.5,
                            ),
                            boxShadow: [
                              if (isActive)
                                BoxShadow(
                                  color: const Color(0xFF00897B).withValues(alpha: 0.6),
                                  blurRadius: 16,
                                  spreadRadius: 3,
                                ),
                              if (isHinted)
                                BoxShadow(
                                  color: Colors.amber.withValues(alpha: 0.6),
                                  blurRadius: 16,
                                  spreadRadius: 3,
                                ),
                              if (!isActive && !isHinted)
                                BoxShadow(
                                  color: const Color(0xFF00796B).withValues(alpha: 0.08),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                            ],
                          ),
                          child: Center(
                            child: isHinted
                                ? const Icon(Icons.lightbulb_rounded, size: 36, color: Colors.amber)
                                : (isActive
                                    ? const Icon(Icons.check_circle_rounded, size: 36, color: Colors.white)
                                    : const Icon(Icons.spa_rounded, size: 30, color: Color(0xFF00796B))),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }
}
