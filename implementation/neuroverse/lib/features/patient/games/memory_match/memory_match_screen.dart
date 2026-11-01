import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Services & Models
import '../../../../core/models/game_session.dart';
import '../../../../data/local/hive_service.dart' as app_hive;
import '../../../../core/services/adaptive_intelligence_service.dart';
import '../../../../core/services/sync_service.dart';
import '../../../../core/services/voice_service.dart';
import '../common/game_results_screen.dart';
import '../common/ner_illustrations.dart';
import '../../../../providers/app_provider.dart';
import '../../../../core/localization/app_translations.dart';
import '../../../phc_network/data/phc_repository.dart';

class MemoryMatchScreen extends StatefulWidget {
  final int difficulty;
  final String? patientId;
  final String? patientName;
  final void Function(int score, int durationSeconds, double accuracy)? onGameCompleted;

  const MemoryMatchScreen({
    super.key,
    this.difficulty = 1,
    this.patientId,
    this.patientName,
    this.onGameCompleted,
  });

  @override
  State<MemoryMatchScreen> createState() => _MemoryMatchScreenState();
}

class _MemoryMatchScreenState extends State<MemoryMatchScreen> {
  // Complete image pool identical to Memory Recall
  static final List<String> _imagePool = [
    'momos', 'tea_leaves', 'orchid', 'bamboo', 'traditional_house', 'waterfall', 'hills', 'hornbill',
    'red_panda', 'one_horned_rhino', 'traditional_dress', 'bamboo_basket', 'traditional_instrument', 'black_rice', 'local_fruits', 'pine_trees',
    'rhododendron', 'river', 'sunrise', 'handloom_fabric', 'fishing_basket', 'cultural_mask', 'mithun', 'clouds',
    'local_tea_cup', 'chili_peppers', 'ginger', 'lemon', 'banana_leaf', 'rice_field', 'traditional_jewellery', 'handicraft',
    'canoe', 'lotus', 'elephant', 'clouded_leopard', 'maple_leaves', 'toki_bird', 'traditional_hat', 'orange'
  ];

  // Game State
  int _currentDifficulty = 1; 
  late int _totalPairs;
  
  List<String> _cards = [];
  List<bool> _cardFlips = [];
  List<bool> _cardMatches = [];
  
  int _previousIndex = -1;
  bool _flipProcessing = false;
  
  // Metrics
  int _moves = 0;
  int _mistakes = 0;
  int _hintsUsed = 0;
  List<int> _hintCardIndices = [];
  bool _isHintActive = false;
  final Stopwatch _stopwatch = Stopwatch();
  VoiceService? _voiceService;

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

  int _calculatePairsForDifficulty(int diff) {
    switch (diff) {
      case 1:
        return 2; // 4 cards -> 2x2 grid (perfect square)
      case 2:
        return 3; // 6 cards -> 2x3 grid
      case 3:
        return 4; // 8 cards -> 2x4 grid
      case 4:
        return 6; // 12 cards -> 3x4 grid
      default:
        return 8; // 16 cards -> 4x4 grid
    }
  }

  int get _crossAxisCount {
    final count = _cards.length;
    if (count <= 4) return 2; // 2x2
    if (count == 6) return 3; // 2x3 (2 rows of 3)
    if (count == 8) return 4; // 2x4 (2 rows of 4)
    if (count == 10) return 2; // 5x2
    if (count % 4 == 0) return 4; // 12 -> 3x4, 16 -> 4x4
    if (count % 3 == 0) return 3;
    return 2;
  }

  void _initializeGame() {
    _totalPairs = _calculatePairsForDifficulty(_currentDifficulty);
    
    // Pick authentic photos from image pool (exact same photos as Memory Recall)
    final availableItems = List<String>.from(_imagePool)..shuffle();
    final selectedItems = availableItems.take(_totalPairs).toList();
    
    // Duplicate for pairs and shuffle
    _cards = [...selectedItems, ...selectedItems];
    _cards.shuffle();
    
    _cardFlips = List.filled(_cards.length, false);
    _cardMatches = List.filled(_cards.length, false);
    
    _moves = 0;
    _mistakes = 0;
    _hintsUsed = 0;
    _hintCardIndices = [];
    _isHintActive = false;
    _previousIndex = -1;
    _flipProcessing = false;
    
    _stopwatch.reset();
    _stopwatch.start();
    
    // Voice prompt
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
  }

  void _speakInstructions({bool isInitial = false}) {
    if (!mounted) return;
    final appProvider = context.read<AppProvider>();
    final lang = appProvider.voiceLanguage ?? appProvider.userLanguage ?? 'hi';
    final cleanLang = AppTranslations.normalizeLangCode(lang);
    final text = cleanLang == 'en'
        ? "Find all the matching pairs! Tap two cards to match them."
        : AppTranslations.get(cleanLang, 'desc_memory_match');
    context.read<VoiceService>().speakKey(
      'match_find',
      lang: lang,
      fallbackText: text,
    );
  }

  void _onCardTap(int index) {
    if (_flipProcessing || _cardFlips[index] || _cardMatches[index]) return;

    setState(() {
      _cardFlips[index] = true;
    });

    if (_previousIndex == -1) {
      _previousIndex = index;
    } else {
      _moves++;
      _flipProcessing = true;
      
      if (_cards[_previousIndex] == _cards[index]) {
        // Match found
        _cardMatches[_previousIndex] = true;
        _cardMatches[index] = true;
        _previousIndex = -1;
        _flipProcessing = false;
        
        _checkWinCondition();
      } else {
        // No match
        _mistakes++;
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) {
            setState(() {
              _cardFlips[_previousIndex] = false;
              _cardFlips[index] = false;
              _previousIndex = -1;
              _flipProcessing = false;
            });
          }
        });
      }
    }
  }

  void _useHint() {
    if (_flipProcessing || _isHintActive) return;

    // Find first unmatched pair
    int firstIdx = -1;
    int secondIdx = -1;

    for (int i = 0; i < _cards.length; i++) {
      if (!_cardMatches[i]) {
        for (int j = i + 1; j < _cards.length; j++) {
          if (!_cardMatches[j] && _cards[i] == _cards[j]) {
            firstIdx = i;
            secondIdx = j;
            break;
          }
        }
        if (firstIdx != -1) break;
      }
    }

    if (firstIdx == -1 || secondIdx == -1) return;

    setState(() {
      _hintsUsed++;
      _isHintActive = true;
      _hintCardIndices = [firstIdx, secondIdx];
      _cardFlips[firstIdx] = true;
      _cardFlips[secondIdx] = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.lightbulb_rounded, color: Colors.amber, size: 20),
            SizedBox(width: 8),
            Text("Hint: Here is a matching pair! ✨", style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        duration: const Duration(milliseconds: 1600),
        backgroundColor: const Color(0xFF00796B),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );

    Future.delayed(const Duration(milliseconds: 1800), () {
      if (mounted && _isHintActive) {
        setState(() {
          if (!_cardMatches[firstIdx] && _previousIndex != firstIdx) {
            _cardFlips[firstIdx] = false;
          }
          if (!_cardMatches[secondIdx] && _previousIndex != secondIdx) {
            _cardFlips[secondIdx] = false;
          }
          _hintCardIndices.clear();
          _isHintActive = false;
        });
      }
    });
  }

  void _checkWinCondition() {
    if (!_cardMatches.contains(false)) {
      _stopwatch.stop();
      _handleGameComplete();
    }
  }

  Future<void> _handleGameComplete() async {
    final int completionTime = _stopwatch.elapsed.inSeconds;
    
    // Accuracy calculation: Minimum moves is _totalPairs. 
    // If moves == _totalPairs, accuracy is 100%.
    double accuracy = (_totalPairs / (_moves == 0 ? 1 : _moves)) * 100;
    int accuracyInt = accuracy.clamp(0, 100).toInt();
    
    // 1. Create Session
    final double avgReactionTime = _moves > 0 ? (completionTime * 1000) / _moves : 0;
    // Basic cognitive score calculation (higher is better):
    // Accuracy * difficulty factor - penalty for time and mistakes
    final double cogScore = (accuracy * _currentDifficulty) - (completionTime * 0.1) - (_mistakes * 5);
    
    final String currentUserId = widget.patientId ?? (FirebaseAuth.instance.currentUser?.uid ?? 'guest_user');
    
    final session = GameSession(
      id: const Uuid().v4(),
      gameId: 'memory_match',
      patientId: currentUserId,
      timestamp: DateTime.now(),
      difficultyLevel: _currentDifficulty,
      score: accuracyInt, // using accuracy as score for now
      accuracyPercentage: accuracyInt,
      completionTimeSeconds: completionTime,
      mistakes: _mistakes,
      hintsUsed: _hintsUsed,
      gameCategory: 'Memory & Recognition',
      reactionTimeAverageMs: avgReactionTime,
      cognitiveScore: cogScore > 0 ? cogScore : 0,
    );

    // Get Services
    final hiveService = context.read<app_hive.HiveService>();
    final adaptiveService = context.read<AdaptiveIntelligenceService>();
    final syncService = context.read<SyncService>();
    final appProvider = context.read<AppProvider>();

    // 2. Hive -> Save Immediately
    await hiveService.saveGameSession(session);
    
    // 3 & 4. QLearning -> Update Q-table & Calculate Next Difficulty
    int nextDifficulty = adaptiveService.processSessionAndGetNextDifficulty(session);
    
    // Save Q-Table and Latest Difficulty to Hive
    final qLearningService = adaptiveService.qLearningService;
    await hiveService.saveQTable(qLearningService.qTable);
    if (widget.patientId != null) {
      await hiveService.saveGameDifficultyForPatient(widget.patientId!, 'memory_match', nextDifficulty);
      final int scoreOutOf10 = ((accuracyInt / 10).round()).clamp(1, 10);
      await PhcRepository().recordScreeningResult(
        patientId: widget.patientId!,
        score: scoreOutOf10,
        durationSeconds: completionTime,
      );
      widget.onGameCompleted?.call(scoreOutOf10, completionTime, accuracy);
    } else {
      await hiveService.saveGameDifficulty('memory_match', nextDifficulty);
      // Trigger UI Update for Progress and Dashboard for registered patient accounts
      if (mounted) {
        appProvider.loadProgress();
      }
    }
    
    // 5. Trigger Auto Sync to Cloud immediately after session
    syncService.syncLocalDataToCloud().then((success) {
      if (mounted) {
        appProvider.setSyncStatus(success);
      }
    });
    if (widget.patientId != null) {
      PhcRepository().syncAllOfflineWithCloud();
    }

    // UI Feedback
    if (mounted) {
      final double accuracyScore = accuracyInt / 100.0;
      
      // Push new Game Results Screen
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => GameResultsScreen(
            totalChallenges: _totalPairs, 
            completedChallenges: _totalPairs,
            accuracy: accuracyScore,
            currentLevel: _currentDifficulty,
            nextLevel: nextDifficulty,
            nextLevelWidget: MemoryMatchScreen(
              difficulty: nextDifficulty,
              patientId: widget.patientId,
              patientName: widget.patientName,
              onGameCompleted: widget.onGameCompleted,
            ),
            gameId: 'memory_match',
            audioKey: 'match_win',
            patientId: widget.patientId,
            patientName: widget.patientName,
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _voiceService?.stopSpeaking();
    _stopwatch.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
          title: Text(context.tr('memory_match')),
        actions: [
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
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [

            // Instruction Card with highlighted sound button
            Builder(
              builder: (context) {
                final isDark = Theme.of(context).brightness == Brightness.dark;
                return Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1B2624) : const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isDark ? const Color(0xFF2E4C3E) : const Color(0xFFC8E6C9),
                      width: 1.2,
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
                        child: Text(
                          context.tr('find_matching_pairs'),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF1B3B36),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            Expanded(
              child: GridView.builder(
                physics: const BouncingScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: _crossAxisCount,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.0,
                ),
                itemCount: _cards.length,
                itemBuilder: (context, index) {
                  final bool isFlipped = _cardFlips[index] || _cardMatches[index];
                  final bool isHinted = _hintCardIndices.contains(index);
                  final isDark = Theme.of(context).brightness == Brightness.dark;

                  return GestureDetector(
                    onTap: () => _onCardTap(index),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      decoration: BoxDecoration(
                        color: isFlipped
                            ? (isHinted
                                ? (isDark ? const Color(0xFF332A00) : Colors.amber.shade50)
                                : (_cardMatches[index]
                                    ? (isDark ? const Color(0xFF00382E) : const Color(0xFFE0F2F1))
                                    : (isDark ? const Color(0xFF1E2829) : Colors.white)))
                            : (isDark ? const Color(0xFF00332C) : const Color(0xFF00796B)),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: isHinted
                              ? Colors.amber.shade700
                              : (_cardMatches[index]
                                  ? const Color(0xFF00897B)
                                  : (isFlipped
                                      ? const Color(0xFF00796B).withValues(alpha: 0.5)
                                      : const Color(0xFF004D40))),
                          width: isHinted || _cardMatches[index] ? 3.0 : 2.0,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: isHinted
                                ? Colors.amber.withValues(alpha: 0.35)
                                : (_cardMatches[index]
                                    ? const Color(0xFF00796B).withValues(alpha: 0.3)
                                    : Colors.black.withValues(alpha: 0.1)),
                            blurRadius: isHinted || _cardMatches[index] ? 10 : 4,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: isFlipped
                            ? Stack(
                                fit: StackFit.expand,
                                children: [
                                  Image.asset(
                                    'assets/images/memory_cards/${_cards[index]}.png',
                                    fit: BoxFit.cover,
                                  ),
                                  if (_cardMatches[index])
                                    Positioned(
                                      top: 4,
                                      right: 4,
                                      child: Container(
                                        padding: const EdgeInsets.all(3.5),
                                        decoration: const BoxDecoration(
                                          color: Color(0xFF00796B),
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black26,
                                              blurRadius: 4,
                                            ),
                                          ],
                                        ),
                                        child: const Icon(Icons.check_rounded, size: 16, color: Colors.white),
                                      ),
                                    ),
                                ],
                              )
                            : const Center(
                                child: NerCardBack(size: 52),
                              ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }
}
