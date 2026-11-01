import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/models/family_member_model.dart';
import '../../../../core/models/game_session.dart';
import '../../../../core/utils/indic_transliteration.dart';
import '../../../../data/local/hive_service.dart' as app_hive;
import '../../../../core/services/adaptive_intelligence_service.dart';
import '../../../../core/services/sync_service.dart';
import '../../../../core/services/voice_service.dart';
import '../../../../providers/app_provider.dart';
import '../../../../core/localization/app_translations.dart';
import '../common/game_results_screen.dart';

class FaceRecallScreen extends StatefulWidget {
  final int difficulty;
  const FaceRecallScreen({super.key, this.difficulty = 1});

  @override
  State<FaceRecallScreen> createState() => _FaceRecallScreenState();
}

class _FaceRecallScreenState extends State<FaceRecallScreen>
    with SingleTickerProviderStateMixin {
  late int _currentDifficulty;

  List<FamilyMember> _allMembers = [];
  FamilyMember? _targetMember;
  List<FamilyMember> _displayedMembers = [];
  String? _previousTargetId;

  bool _isLoading = true;
  bool _isProcessingTap = false;
  String? _selectedMemberId;
  String? _wrongMemberId;
  bool? _isCorrect;
  final Set<String> _dimmedMemberIds = {};

  int _totalMistakes = 0;
  int _score = 0;
  int _hintsUsed = 0;
  final Stopwatch _stopwatch = Stopwatch();

  late AnimationController _feedbackAnimController;
  late Animation<double> _scaleAnim;
  VoiceService? _voiceService;
  bool _navigatedToResults = false;

  @override
  void initState() {
    super.initState();
    _currentDifficulty = widget.difficulty;

    _feedbackAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scaleAnim = Tween<double>(begin: 0.85, end: 1.05).animate(
      CurvedAnimation(parent: _feedbackAnimController, curve: Curves.easeOutBack),
    );

    _loadDataAndStartGame();
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

  @override
  void dispose() {
    if (!_navigatedToResults) {
      _voiceService?.stopSpeaking();
    }
    _stopwatch.stop();
    _feedbackAnimController.dispose();
    super.dispose();
  }

  Future<void> _loadDataAndStartGame() async {
    final hive = context.read<app_hive.HiveService>();
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    // 1. Read from local Hive cache first - if available, start game and voice instantly
    final localMembers = hive
        .getFamilyMembers()
        .where((m) => !m.isDefaultAsset && !m.imageBase64.startsWith('assets/') && m.imageBase64.isNotEmpty)
        .toList();

    if (localMembers.length >= 2) {
      if (mounted) {
        setState(() {
          _allMembers = localMembers;
          _isLoading = false;
        });
        _startNewRound();
        _stopwatch.start();
      }
    }

    // 2. Fetch from cloud Firestore in background to update cache
    if (currentUserId != null) {
      try {
        final snap = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUserId)
            .collection('face_recall_members')
            .get()
            .timeout(const Duration(seconds: 4));

        if (snap.docs.isNotEmpty) {
          final cloudMembers = snap.docs
              .map((d) => FamilyMember.fromMap(d.data()))
              .where((m) => !m.isDefaultAsset && !m.imageBase64.startsWith('assets/') && m.imageBase64.isNotEmpty)
              .toList();
          await hive.saveFamilyMembers(cloudMembers);
          if (localMembers.length < 2 && cloudMembers.length >= 2 && mounted) {
            setState(() {
              _allMembers = cloudMembers;
              _isLoading = false;
            });
            _startNewRound();
            _stopwatch.start();
            return;
          }
        }
      } catch (e) {
        debugPrint("FaceRecall: Cloud family sync error (using local cache): $e");
      }
    }

    if (localMembers.length < 2 && mounted && _allMembers.length < 2) {
      setState(() {
        _allMembers = [];
        _isLoading = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showNoPhotosDialog();
      });
    }
  }

  void _showNoPhotosDialog() {
    try {
      final appProvider = context.read<AppProvider>();
      final lang = appProvider.voiceLanguage ?? appProvider.userLanguage ?? 'hi';
      context.read<VoiceService>().speak(context.tr('no_family_photos_desc'), lang: lang);
    } catch (_) {}

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFD97706).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.photo_library_outlined, color: Color(0xFFD97706), size: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  ctx.tr('no_family_photos_title'),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ),
            ],
          ),
          content: Text(
            ctx.tr('no_family_photos_desc'),
            style: TextStyle(
              fontSize: 15,
              height: 1.4,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                if (mounted) {
                  Navigator.of(context).pop();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD97706),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              child: Text(
                ctx.tr('back_to_home'),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  void _startNewRound() {
    setState(() {
      _isProcessingTap = false;
      _selectedMemberId = null;
      _wrongMemberId = null;
      _isCorrect = null;
      _dimmedMemberIds.clear();

      // Option count based on difficulty & available photos:
      // Level 1-2: 2 photos
      // Level 3-4: 4 photos
      // Level 5-6+: 6 photos (bounded by available photos)
      int desiredOptions = _currentDifficulty <= 2
          ? 2
          : (_currentDifficulty <= 4 ? 4 : 6);
      int optionCount = math.min(desiredOptions, _allMembers.length);

      // Select target member avoiding immediate duplicate
      List<FamilyMember> eligibleTargets = _allMembers
          .where((m) => m.id != _previousTargetId)
          .toList();
      if (eligibleTargets.isEmpty) eligibleTargets = List.from(_allMembers);
      eligibleTargets.shuffle();
      _targetMember = eligibleTargets.first;
      _previousTargetId = _targetMember!.id;

      // Select distractors
      final distractors = _allMembers
          .where((m) => m.id != _targetMember!.id)
          .toList()
        ..shuffle();

      final selectedDistractors = distractors.take(optionCount - 1).toList();

      // Combine and shuffle displayed options
      _displayedMembers = [_targetMember!, ...selectedDistractors]..shuffle();
    });

    // Announce voice prompt after UI renders with slight delay for route/round transition
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) {
        _speakCurrentPrompt();
      }
    });
  }

  static const Map<String, String> _relationNameToKey = {
    'son': 'rel_son',
    'daughter': 'rel_daughter',
    'wife': 'rel_wife',
    'husband': 'rel_husband',
    'grandson': 'rel_grandson',
    'granddaughter': 'rel_granddaughter',
    'brother': 'rel_brother',
    'sister': 'rel_sister',
    'mother': 'rel_mother',
    'father': 'rel_father',
    'friend': 'rel_friend',
    'caregiver': 'rel_caregiver',
  };

  String _getTranslatedRelation(FamilyMember member, [String? targetLang]) {
    final rawLang = targetLang ??
        context.read<AppProvider>().userLanguage ??
        'en';
    final lang = AppTranslations.normalizeLangCode(rawLang);
    final key = member.relationKey.isNotEmpty
        ? member.relationKey
        : (_relationNameToKey[member.relation.toLowerCase().trim()] ?? '');

    if (key.isNotEmpty) {
      final tr = AppTranslations.get(lang, key);
      if (tr.isNotEmpty && tr != key) return tr;
    }
    return member.relation;
  }

  String _getLocalizedName(FamilyMember member, [String? targetLang]) {
    final rawLang = targetLang ??
        context.read<AppProvider>().userLanguage ??
        'en';
    final lang = AppTranslations.normalizeLangCode(rawLang);
    if (lang == 'en') {
      return member.name;
    }
    return IndicTransliteration.transliterate(member.name, lang);
  }

  String _getCurrentPromptText() {
    if (_targetMember == null) return '';
    final rel = _getTranslatedRelation(_targetMember!);
    final name = _getLocalizedName(_targetMember!);
    String template = context.tr('prompt_find_member');
    if (template.isEmpty || template == 'prompt_find_member') {
      template = 'Tap on the photo of your {relation} {name}';
    }
    return template
        .replaceAll('{relation}', rel)
        .replaceAll('{name}', name);
  }

  void _speakCurrentPrompt() {
    if (!mounted || _targetMember == null) return;
    try {
      final appProvider = context.read<AppProvider>();
      final voiceLang = appProvider.voiceLanguage ?? appProvider.userLanguage ?? 'hi';
      final voiceRel = _getTranslatedRelation(_targetMember!, voiceLang);
      final voiceName = _getLocalizedName(_targetMember!, voiceLang);
      String voiceTemplate = AppTranslations.get(voiceLang, 'prompt_find_member');
      if (voiceTemplate.isEmpty || voiceTemplate == 'prompt_find_member') {
        voiceTemplate = 'Tap on the photo of your {relation} {name}';
      }
      final prompt = voiceTemplate
          .replaceAll('{relation}', voiceRel)
          .replaceAll('{name}', voiceName);

      debugPrint("FaceRecall: Speaking prompt in $voiceLang: '$prompt'");
      final voiceService = _voiceService ?? context.read<VoiceService>();
      voiceService.speak(prompt, lang: voiceLang);
    } catch (e) {
      debugPrint("FaceRecall: Voice error: $e");
    }
  }

  void _onMemberTap(FamilyMember member) {
    if (_isProcessingTap || _isCorrect == true) return;

    final appProvider = context.read<AppProvider>();
    final lang = appProvider.voiceLanguage ?? appProvider.userLanguage ?? 'hi';
    final isTarget = member.id == _targetMember?.id;

    if (isTarget) {
      // Correct Tap
      HapticFeedback.heavyImpact();
      _feedbackAnimController.forward(from: 0.0);

      setState(() {
        _isProcessingTap = true;
        _selectedMemberId = member.id;
        _isCorrect = true;
        _score += 100 + (_currentDifficulty * 20);
      });

      // Joyful celebratory voice praise in patient's selected voice language
      final tappedRel = _getTranslatedRelation(member, lang);
      final tappedName = _getLocalizedName(member, lang);
      String praiseTemplate = AppTranslations.get(lang, 'voice_praise_correct');
      if (praiseTemplate.isEmpty || praiseTemplate == 'voice_praise_correct') {
        praiseTemplate = 'Well done! This is {name}.';
      }
      final nameWithRelation = tappedRel.isNotEmpty ? '$tappedRel $tappedName' : tappedName;
      final praiseText = praiseTemplate
          .replaceAll('{name}', nameWithRelation)
          .replaceAll('{relation}', tappedRel);

      final voiceService = _voiceService ?? context.read<VoiceService>();
      voiceService.speak(praiseText, lang: lang);

      // Show correct tap visual celebration & let praise voice complete, then advance to results screen
      Timer(const Duration(milliseconds: 2400), () {
        if (!mounted) return;
        _handleGameComplete();
      });
    } else {
      // Incorrect Tap — block rapid re-tapping the same wrong card for 2s
      HapticFeedback.lightImpact();

      setState(() {
        _isProcessingTap = true;
        _totalMistakes++;
        _wrongMemberId = member.id;
      });

      // Gentle educational guidance in Voice Language
      final tappedRel = _getTranslatedRelation(member, lang);
      final tappedName = _getLocalizedName(member, lang);
      final targetName = _targetMember != null ? _getLocalizedName(_targetMember!, lang) : '';
      String guideTemplate = AppTranslations.get(lang, 'voice_guidance_wrong');
      if (guideTemplate.isEmpty || guideTemplate == 'voice_guidance_wrong') {
        guideTemplate = 'This is {name}, your {relation}. Look for {target}.';
      }
      final guideText = guideTemplate
          .replaceAll('{name}', tappedName)
          .replaceAll('{relation}', tappedRel)
          .replaceAll('{target}', targetName);

      context.read<VoiceService>().speak(guideText, lang: lang);

      // Reset wrong card highlight and allow tapping again after 2 seconds
      Timer(const Duration(milliseconds: 2000), () {
        if (mounted) {
          setState(() {
            _wrongMemberId = null;
            _isProcessingTap = false;
          });
        }
      });
    }
  }



  void _useHint() {
    if (_isProcessingTap || _targetMember == null) return;

    final wrongMembers = _displayedMembers
        .where((m) => m.id != _targetMember!.id && !_dimmedMemberIds.contains(m.id))
        .toList();

    if (wrongMembers.isEmpty) return;

    wrongMembers.shuffle();
    final toDim = wrongMembers.first;

    setState(() {
      _hintsUsed++;
      _dimmedMemberIds.add(toDim.id);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.lightbulb_rounded, color: Colors.amber, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                context.tr('hint_distractions_cleared'),
                style: const TextStyle(fontWeight: FontWeight.bold),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 2),
        backgroundColor: const Color(0xFFD97706),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _handleGameComplete() async {
    _stopwatch.stop();
    final int completionTime = _stopwatch.elapsed.inSeconds;

    double accuracy = _totalMistakes == 0
        ? 100.0
        : math.max(0.0, 100.0 - (_totalMistakes * 25.0));
    int accuracyInt = accuracy.clamp(0.0, 100.0).round();

    final double avgReactionTime = (completionTime > 0 ? completionTime : 1.0) * 1000.0;
    final double cogScore = (accuracy * _currentDifficulty) -
        (completionTime * 0.3) -
        (_totalMistakes * 5);
    final String currentUserId =
        FirebaseAuth.instance.currentUser?.uid ?? 'guest_user';

    final session = GameSession(
      id: const Uuid().v4(),
      gameId: 'face_recall',
      patientId: currentUserId,
      timestamp: DateTime.now(),
      difficultyLevel: _currentDifficulty,
      score: _score,
      accuracyPercentage: accuracyInt,
      completionTimeSeconds: completionTime,
      mistakes: _totalMistakes,
      hintsUsed: _hintsUsed,
      gameCategory: 'Familial & Visual Memory',
      reactionTimeAverageMs: avgReactionTime,
      cognitiveScore: cogScore > 0 ? cogScore : 0,
    );

    final hiveService = context.read<app_hive.HiveService>();
    final adaptiveService = context.read<AdaptiveIntelligenceService>();
    final syncService = context.read<SyncService>();

    await hiveService.saveGameSession(session);
    int nextDifficulty =
        adaptiveService.processSessionAndGetNextDifficulty(session);
    await hiveService.saveQTable(adaptiveService.qLearningService.qTable);
    await hiveService.saveGameDifficulty('face_recall', nextDifficulty);

    syncService.syncLocalDataToCloud().then((success) {
      if (mounted) {
        context.read<AppProvider>().setSyncStatus(success);
      }
    });

    if (mounted) {
      _navigatedToResults = true;
      context.read<AppProvider>().loadProgress();
      final double accuracyScore = accuracyInt / 100.0;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => GameResultsScreen(
            totalChallenges: 1,
            completedChallenges: 1,
            accuracy: accuracyScore,
            currentLevel: _currentDifficulty,
            nextLevel: nextDifficulty,
            nextLevelWidget: FaceRecallScreen(difficulty: nextDifficulty),
            gameId: 'face_recall',
            audioKey: 'face_win',
          ),
        ),
      );
    }
  }

  Widget _buildMemberImage(FamilyMember member) {
    if (member.isDefaultAsset || member.imageBase64.startsWith('assets/')) {
      return Image.asset(
        member.imageBase64,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildFallbackAvatar(member),
      );
    } else if (member.imageBase64.isNotEmpty) {
      try {
        final clean = member.imageBase64.replaceAll(RegExp(r'\s+'), '');
        final bytes = base64Decode(clean);
        return Image.memory(
          bytes,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _buildFallbackAvatar(member),
        );
      } catch (e) {
        return _buildFallbackAvatar(member);
      }
    }
    return _buildFallbackAvatar(member);
  }

  Widget _buildFallbackAvatar(FamilyMember member) {
    return Container(
      color: const Color(0xFFFDE68A),
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.person_rounded,
            size: 48,
            color: const Color(0xFF92400E).withValues(alpha: 0.8),
          ),
          const SizedBox(height: 4),
          Text(
            member.name,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Color(0xFF92400E),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(context.tr('face_recall'))),
        body: const Center(
          child: CircularProgressIndicator(color: Color(0xFFD97706)),
        ),
      );
    }

    if (_allMembers.length < 2) {
      return PopScope(
        canPop: true,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) {
            _voiceService?.stopSpeaking();
          }
        },
        child: Scaffold(
          backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFFBF9F5),
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () {
                _voiceService?.stopSpeaking();
                Navigator.of(context).pop();
              },
            ),
            title: Text(
              context.tr('face_recall'),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(28.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD97706).withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.photo_library_outlined,
                      size: 64,
                      color: Color(0xFFD97706),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    context.tr('no_family_photos_title'),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    context.tr('no_family_photos_desc'),
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.4,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton.icon(
                    onPressed: () {
                      _voiceService?.stopSpeaking();
                      Navigator.of(context).pop();
                    },
                    icon: const Icon(Icons.arrow_back_rounded),
                    label: Text(
                      context.tr('back_to_home'),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD97706),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final promptText = _getCurrentPromptText();

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          _voiceService?.stopSpeaking();
        }
      },
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFFBF9F5),
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () {
              _voiceService?.stopSpeaking();
              Navigator.of(context).pop();
            },
          ),
          title: Text(
            context.tr('face_recall'),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        actions: [
          // Hint Button
          Container(
            margin: const EdgeInsets.only(right: 14, top: 8, bottom: 8),
            child: TextButton.icon(
              onPressed: _useHint,
              icon: const Icon(Icons.lightbulb_rounded, size: 18, color: Colors.amber),
              label: Text(
                context.tr('hint'),
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.amber),
              ),
              style: TextButton.styleFrom(
                backgroundColor: isDark
                    ? Colors.amber.withValues(alpha: 0.15)
                    : Colors.amber.shade50,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 8),

            // Spoken & Written Prompt Banner (with Large Repeat Icon Button)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Material(
                elevation: 1,
                shadowColor: Colors.black12,
                borderRadius: BorderRadius.circular(20),
                color: isDark ? const Color(0xFF261E12) : const Color(0xFFFFFBEB),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isDark ? const Color(0xFF4E3816) : const Color(0xFFFDE68A),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD97706).withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.face_rounded,
                          color: Color(0xFFD97706),
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          promptText,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            height: 1.3,
                            color: isDark ? const Color(0xFFFFE082) : const Color(0xFF92400E),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Large Prominent Repeat Icon Button
                      InkWell(
                        onTap: _speakCurrentPrompt,
                        borderRadius: BorderRadius.circular(24),
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: const Color(0xFFD97706),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFD97706).withValues(alpha: 0.4),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.replay_rounded,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 10),

            // Family Member Photo Grid / Cards
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: _buildCardsGrid(isDark),
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }

  Widget _buildCardsGrid(bool isDark) {
    final count = _displayedMembers.length;
    final int crossAxisCount = count <= 2 ? 2 : (count <= 4 ? 2 : 3);
    final double childAspectRatio = count <= 2 ? 0.85 : (count <= 4 ? 0.88 : 0.80);

    return GridView.builder(
      physics: const BouncingScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        childAspectRatio: childAspectRatio,
      ),
      itemCount: count,
      itemBuilder: (context, index) {
        final member = _displayedMembers[index];
        final isSelected = _selectedMemberId == member.id;
        final isWrong = _wrongMemberId == member.id;
        final isDimmed = _dimmedMemberIds.contains(member.id);

        return _buildMemberCard(
          member: member,
          isSelected: isSelected,
          isWrong: isWrong,
          isDimmed: isDimmed,
          isDark: isDark,
        );
      },
    );
  }

  Widget _buildMemberCard({
    required FamilyMember member,
    required bool isSelected,
    required bool isWrong,
    required bool isDimmed,
    required bool isDark,
  }) {
    Color borderColor = isDark ? Colors.white12 : Colors.grey.shade300;
    double borderWidth = 2.0;

    if (isSelected && _isCorrect == true) {
      borderColor = const Color(0xFF16A34A); // Green checkmark
      borderWidth = 3.5;
    } else if (isWrong) {
      borderColor = const Color(0xFFDC2626); // Red wrong
      borderWidth = 3.5;
    }

    Widget cardContent = AnimatedOpacity(
      duration: const Duration(milliseconds: 250),
      opacity: isDimmed ? 0.28 : 1.0,
      child: Material(
        elevation: isSelected ? 8 : 3,
        shadowColor: Colors.black26,
        borderRadius: BorderRadius.circular(22),
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: borderColor, width: borderWidth),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Photo
              _buildMemberImage(member),

              // Person Name & Relation Badge ONLY revealed on correct tap celebration!
              if (isSelected && _isCorrect == true)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black54,
                          Colors.black87,
                        ],
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Person's Name
                        Text(
                          _getLocalizedName(member),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            shadows: [
                              Shadow(color: Colors.black, blurRadius: 4),
                            ],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        // Relation Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF16A34A).withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            _getTranslatedRelation(member),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Success Checkmark Overlay Animation
              if (isSelected && _isCorrect == true)
                Positioned.fill(
                  child: ScaleTransition(
                    scale: _scaleAnim,
                    child: Container(
                      color: const Color(0xFF16A34A).withValues(alpha: 0.35),
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: const BoxDecoration(
                            color: Color(0xFF16A34A),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black38,
                                blurRadius: 12,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.check_rounded,
                            color: Colors.white,
                            size: 42,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

              // Wrong Choice Overlay Animation
              if (isWrong)
                Positioned.fill(
                  child: Container(
                    color: const Color(0xFFDC2626).withValues(alpha: 0.4),
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: const BoxDecoration(
                          color: Color(0xFFDC2626),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black38,
                              blurRadius: 12,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                          size: 38,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    return InkWell(
      onTap: isDimmed ? null : () => _onMemberTap(member),
      borderRadius: BorderRadius.circular(22),
      child: cardContent,
    );
  }
}
