import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/models/game_session.dart';
import '../../../../data/local/hive_service.dart' as app_hive;
import '../../../../core/services/adaptive_intelligence_service.dart';
import '../../../../core/services/sync_service.dart';
import '../../../../core/services/voice_service.dart';
import '../../../../providers/app_provider.dart';
import '../common/game_results_screen.dart';
import '../../../../core/localization/app_translations.dart';
import '../../../phc_network/data/phc_repository.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MemoryRecallScreen extends StatefulWidget {
  final int difficulty;
  final String? patientId;
  final String? patientName;
  final void Function(int score, int durationSeconds, double accuracy)? onGameCompleted;

  const MemoryRecallScreen({
    super.key,
    this.difficulty = 1,
    this.patientId,
    this.patientName,
    this.onGameCompleted,
  });

  @override
  State<MemoryRecallScreen> createState() => _MemoryRecallScreenState();
}

class _MemoryRecallScreenState extends State<MemoryRecallScreen> {
  int _currentDifficulty = 1;
  late int _targetCount;
  
  List<String> _targetItems = [];
  List<String> _options = [];
  final List<String> _selectedItems = [];
  
  bool _isMemorizePhase = true;
  bool _isChecking = false;
  bool _isGameCompleted = false;
  Timer? _autoCheckTimer;
  int _totalMistakes = 0;
  int _attempts = 0;
  static const int _maxAttempts = 3;
  final Stopwatch _stopwatch = Stopwatch();

  int _hintsUsed = 0;
  String? _hintItem;

  // Complete Northeast India themed image pool (40 items)
  static final List<String> _imagePool = [
    'momos', 'tea_leaves', 'orchid', 'bamboo', 'traditional_house', 'waterfall', 'hills', 'hornbill',
    'red_panda', 'one_horned_rhino', 'traditional_dress', 'bamboo_basket', 'traditional_instrument', 'black_rice', 'local_fruits', 'pine_trees',
    'rhododendron', 'river', 'sunrise', 'handloom_fabric', 'fishing_basket', 'cultural_mask', 'mithun', 'clouds',
    'local_tea_cup', 'chili_peppers', 'ginger', 'lemon', 'banana_leaf', 'rice_field', 'traditional_jewellery', 'handicraft',
    'canoe', 'lotus', 'elephant', 'clouded_leopard', 'maple_leaves', 'toki_bird', 'traditional_hat', 'orange'
  ];

  // Track recently used target items across consecutive rounds to avoid repetition
  static final List<String> _recentTargets = [];
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
    // Starting with 1 photo at difficulty 1 as requested, then scaling gradually up to 8
    _targetCount = (1 + (_currentDifficulty - 1)).clamp(1, 8);
    
    // Smart randomization: prioritize images not used in recent rounds
    final availablePool = _imagePool.where((item) => !_recentTargets.contains(item)).toList();
    availablePool.shuffle();

    if (availablePool.length >= _targetCount) {
      _targetItems = availablePool.take(_targetCount).toList();
    } else {
      // If remaining pool is smaller than needed, reset recent history and draw from full pool
      final fullShuffled = List<String>.from(_imagePool)..shuffle();
      _targetItems = fullShuffled.take(_targetCount).toList();
      _recentTargets.clear();
    }

    // Keep recent history to avoid consecutive repetition (up to 20 items)
    _recentTargets.addAll(_targetItems);
    if (_recentTargets.length > 20) {
      _recentTargets.removeRange(0, _recentTargets.length - 20);
    }
    
    // Generate distractors from remaining items in the full pool
    final remainingPool = _imagePool.where((item) => !_targetItems.contains(item)).toList()..shuffle();
    final distractorCount = _targetCount == 1 ? 3 : (_targetCount + 2).clamp(4, 10);
    final distractors = remainingPool.take(distractorCount).toList();
    _options = [..._targetItems, ...distractors];
    _options.shuffle();
    
    _selectedItems.clear();
    _isMemorizePhase = true;
    _isChecking = false;
    _isGameCompleted = false;
    _autoCheckTimer?.cancel();
    _totalMistakes = 0;
    _attempts = 0;
    _hintsUsed = 0;
    _hintItem = null;

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
    try {
      final appProvider = context.read<AppProvider>();
      final lang = appProvider.voiceLanguage ?? appProvider.userLanguage ?? 'hi';
      final cleanLang = AppTranslations.normalizeLangCode(lang);
      final key = _isMemorizePhase ? 'memorize_images' : 'select_images';
      final fallback = cleanLang == 'en'
          ? (_isMemorizePhase ? "Memorize these images." : "Select the images you saw.")
          : AppTranslations.get(cleanLang, key).replaceAll(':', '').trim();
      context.read<VoiceService>().speakKey(
        _isMemorizePhase ? 'recall_images' : 'select_images',
        lang: lang,
        fallbackText: fallback.isNotEmpty ? fallback : "Memorize these images.",
      );
    } catch (e) {
      debugPrint("MemoryRecall voice prompt error: $e");
    }
  }

  void _onReadyPressed() {
    if (!_isMemorizePhase) return;
    setState(() {
      _isMemorizePhase = false;
    });
    _stopwatch.reset();
    _stopwatch.start();
  }

  void _onItemTap(String item) {
    if (_isMemorizePhase || _isGameCompleted || _isChecking) return;
    
    setState(() {
      if (_selectedItems.contains(item)) {
        _selectedItems.remove(item);
      } else {
        if (_selectedItems.length < _targetCount) {
          _selectedItems.add(item);
        }
      }
    });

    _autoCheckTimer?.cancel();
    // Automatically check answers once the user has selected all required cards!
    if (_selectedItems.length == _targetCount) {
      _autoCheckTimer = Timer(const Duration(milliseconds: 280), () {
        if (mounted && !_isMemorizePhase && !_isGameCompleted && !_isChecking && _selectedItems.length == _targetCount) {
          _checkResults();
        }
      });
    }
  }

  void _checkResults() {
    _autoCheckTimer?.cancel();
    if (_isMemorizePhase || _selectedItems.isEmpty || _isGameCompleted || _isChecking) return;
    _isChecking = true;
    
    int correctCount = 0;
    int currentMistakes = 0;

    for (String item in _selectedItems) {
      if (_targetItems.contains(item)) {
        correctCount++;
      } else {
        currentMistakes++;
      }
    }

    _totalMistakes += currentMistakes;
    _attempts++;

    final bool allTargetsFound = (correctCount == _targetCount && currentMistakes == 0);
    final bool maxAttemptsReached = (_attempts >= _maxAttempts);

    if (allTargetsFound || maxAttemptsReached) {
      _isGameCompleted = true;
      _stopwatch.stop();
      _handleGameComplete(correctCount: correctCount);
    } else {
      _isChecking = false;
      // Keep correct items selected so the patient doesn't feel frustrated!
      // Only remove the incorrect distractors.
      setState(() {
        _selectedItems.removeWhere((item) => !_targetItems.contains(item));
      });

      final int remainingToFind = _targetCount - correctCount;
      final int attemptsRemaining = _maxAttempts - _attempts;

      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.info_outline_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  correctCount > 0
                      ? "$correctCount of $_targetCount correct! Find the remaining $remainingToFind. ($attemptsRemaining attempt${attemptsRemaining > 1 ? 's' : ''} left)"
                      : "Not quite right. Try again! ($attemptsRemaining attempt${attemptsRemaining > 1 ? 's' : ''} left)",
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          duration: const Duration(seconds: 3),
          backgroundColor: const Color(0xFFD97706),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  void _useHint() {
    if (_isMemorizePhase) return;
    
    // Find an unselected target item
    final unselected = _targetItems.where((w) => !_selectedItems.contains(w)).toList();
    if (unselected.isEmpty) return;

    final hintItem = unselected.first;
    setState(() {
      _hintsUsed++;
      _hintItem = hintItem;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.lightbulb_rounded, color: Colors.amber, size: 20),
            SizedBox(width: 8),
            Text("Hint: Look for the highlighted card!", style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        duration: const Duration(seconds: 2),
        backgroundColor: const Color(0xFF00796B),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );

    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && _hintItem == hintItem) {
        setState(() {
          _hintItem = null;
        });
      }
    });
  }

  Future<void> _handleGameComplete({required int correctCount}) async {
    final int completionTime = _stopwatch.elapsed.inSeconds > 0
        ? _stopwatch.elapsed.inSeconds
        : 1;
    
    // Base accuracy: percentage of target items correctly identified
    final double baseAccuracy = (_targetCount > 0)
        ? (correctCount / _targetCount) * 100.0
        : 0.0;

    // Deduct penalties for mistakes and hints
    // Mistakes: -10% per distractor selected across all attempts
    // Hints: -8% per hint used
    final double penalty = (_totalMistakes * 10.0) + (_hintsUsed * 8.0);
    final double finalAccuracy = (baseAccuracy - penalty).clamp(15.0, 100.0);
    final int accuracyInt = finalAccuracy.round();

    // Reaction time per attempt
    final double avgReactionTime = _attempts > 0
        ? (completionTime * 1000.0) / _attempts
        : (completionTime * 1000.0);

    // Standard NeuroVerse cognitive score
    final double cogScore = (finalAccuracy * _currentDifficulty) - (completionTime * 0.1) - (_totalMistakes * 5.0);
    final String currentUserId = widget.patientId ?? (FirebaseAuth.instance.currentUser?.uid ?? 'guest_user');
    
    final session = GameSession(
      id: const Uuid().v4(),
      gameId: 'memory_recall',
      patientId: currentUserId,
      timestamp: DateTime.now(),
      difficultyLevel: _currentDifficulty,
      score: accuracyInt,
      accuracyPercentage: accuracyInt,
      completionTimeSeconds: completionTime,
      mistakes: _totalMistakes,
      hintsUsed: _hintsUsed,
      gameCategory: 'Memory & Recognition',
      reactionTimeAverageMs: avgReactionTime,
      cognitiveScore: cogScore > 0 ? cogScore : 0.0,
    );

    final hiveService = context.read<app_hive.HiveService>();
    final adaptiveService = context.read<AdaptiveIntelligenceService>();
    final syncService = context.read<SyncService>();

    await hiveService.saveGameSession(session);
    int nextDifficulty = adaptiveService.processSessionAndGetNextDifficulty(session);
    await hiveService.saveQTable(adaptiveService.qLearningService.qTable);
    if (widget.patientId != null) {
      await hiveService.saveGameDifficultyForPatient(widget.patientId!, 'memory_recall', nextDifficulty);
      final int scoreOutOf10 = ((accuracyInt / 10).round()).clamp(1, 10);
      await PhcRepository().recordScreeningResult(
        patientId: widget.patientId!,
        score: scoreOutOf10,
        durationSeconds: completionTime,
      );
      widget.onGameCompleted?.call(scoreOutOf10, completionTime, finalAccuracy);
    } else {
      await hiveService.saveGameDifficulty('memory_recall', nextDifficulty);
      if (mounted) {
        context.read<AppProvider>().loadProgress();
      }
    }

    // 5. Trigger Auto Sync to Cloud immediately after session
    syncService.syncLocalDataToCloud().then((success) {
      if (mounted) {
        context.read<AppProvider>().setSyncStatus(success);
      }
    });
    if (widget.patientId != null) {
      PhcRepository().syncAllOfflineWithCloud();
    }

    if (mounted) {
      _navigatedToResults = true;
      final double accuracyScore = accuracyInt / 100.0;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => GameResultsScreen(
            totalChallenges: _targetCount, 
            completedChallenges: correctCount,
            accuracy: accuracyScore,
            currentLevel: _currentDifficulty,
            nextLevel: nextDifficulty,
            nextLevelWidget: MemoryRecallScreen(
              difficulty: nextDifficulty,
              patientId: widget.patientId,
              patientName: widget.patientName,
              onGameCompleted: widget.onGameCompleted,
            ),
            gameId: 'memory_recall',
            audioKey: 'talk_praise',
            patientId: widget.patientId,
            patientName: widget.patientName,
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _autoCheckTimer?.cancel();
    if (!_navigatedToResults) {
      _voiceService?.stopSpeaking();
    }
    _stopwatch.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

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
          title: Text(context.tr('memory_recall')),
        actions: [
          if (!_isMemorizePhase)
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
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [

            // Instruction Card with highlighted sound button and selection counter
            Builder(
              builder: (context) {
                final isDark = Theme.of(context).brightness == Brightness.dark;
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
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
                          _isMemorizePhase ? context.tr('memorize_images') : context.tr('select_images'),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF1B3B36),
                          ),
                        ),
                      ),
                      if (!_isMemorizePhase) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00796B).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF00796B).withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            "${_selectedItems.length}/$_targetCount",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: Color(0xFF00796B),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
            if (_isMemorizePhase) ...[
              // Calm observation prompt badge
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 4, bottom: 16),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00796B).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF00796B).withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.remove_red_eye_outlined, color: Color(0xFF00796B), size: 20),
                      const SizedBox(width: 8),
                      Text(
                        context.tr('take_your_time'),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF00796B),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    child: Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      alignment: WrapAlignment.center,
                      children: _targetItems.map((item) {
                        final double cardWidth = _targetCount == 1 ? 220 : (_targetCount <= 4 ? 135 : 105);
                        return Container(
                          width: cardWidth,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: const Color(0xFF00796B).withValues(alpha: 0.35),
                              width: 2.0,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF00796B).withValues(alpha: 0.12),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(18),
                            child: AspectRatio(
                              aspectRatio: 1.15,
                              child: Image.asset(
                                'assets/images/memory_cards/$item.png',
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: _onReadyPressed,
                  icon: const Icon(Icons.arrow_forward_rounded),
                  label: Text(
                    context.tr('im_ready'),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00796B),
                    foregroundColor: Colors.white,
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ] else ...[
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 1.12,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: _options.length,
                  itemBuilder: (context, index) {
                    final item = _options[index];
                    final isSelected = _selectedItems.contains(item);
                    final isHinted = _hintItem == item;
                    
                    return GestureDetector(
                      onTap: () => _onItemTap(item),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF00796B).withValues(alpha: 0.08)
                              : isHinted
                                  ? Colors.amber.shade50
                                  : (isDark ? const Color(0xFF1E2829) : Colors.white),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFF00796B)
                                : isHinted
                                    ? Colors.amber.shade700
                                    : (isDark ? Colors.white12 : Colors.grey.shade300),
                            width: isSelected || isHinted ? 3.5 : 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: isSelected
                                  ? const Color(0xFF00796B).withValues(alpha: 0.25)
                                  : isHinted
                                      ? Colors.amber.withValues(alpha: 0.3)
                                      : (isDark ? Colors.black26 : Colors.black.withValues(alpha: 0.06)),
                              blurRadius: isSelected || isHinted ? 12 : 6,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Stack(
                          children: [
                            // Card image with padding and rounded corners
                            Positioned.fill(
                              child: Padding(
                                padding: const EdgeInsets.all(6.0),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(14),
                                  child: Image.asset(
                                    'assets/images/memory_cards/$item.png',
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                            ),

                            // Selected checkmark badge
                            if (isSelected)
                              Positioned(
                                top: 8,
                                right: 8,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF00796B),
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black26,
                                        blurRadius: 4,
                                        offset: Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.check_rounded,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                ),
                              ),

                            // Hint lightbulb badge
                            if (isHinted && !isSelected)
                              Positioned(
                                top: 8,
                                right: 8,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.shade700,
                                    shape: BoxShape.circle,
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Colors.black26,
                                        blurRadius: 4,
                                        offset: Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.lightbulb_rounded,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: _selectedItems.length == _targetCount ? _checkResults : null,
                  icon: const Icon(Icons.check_circle_rounded),
                  label: Text(
                    _selectedItems.length == _targetCount
                        ? context.tr('check_selection')
                        : "${context.tr('select_images')} (${_selectedItems.length}/$_targetCount)",
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00796B),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: isDark ? Colors.white12 : Colors.grey.shade300,
                    disabledForegroundColor: isDark ? Colors.white38 : Colors.grey.shade500,
                    elevation: _selectedItems.length == _targetCount ? 3 : 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    ),
    );
  }
}
