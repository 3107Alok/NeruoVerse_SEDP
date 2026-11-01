import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/services/voice_service.dart';
import '../../../../core/localization/app_translations.dart';
import '../../models/phc_patient_model.dart';
import '../../data/phc_repository.dart';

class AshaScreeningDialog extends StatefulWidget {
  final PhcPatientModel patient;

  const AshaScreeningDialog({super.key, required this.patient});

  @override
  State<AshaScreeningDialog> createState() => _AshaScreeningDialogState();
}

class _AshaScreeningDialogState extends State<AshaScreeningDialog> {
  int _currentPhase = 1; // 1: Orientation, 2: Cultural Memory, 3: Number Sequence, 4: Celebration
  int _totalScore = 0;
  final Stopwatch _stopwatch = Stopwatch();

  // Phase 1 State (Orientation)
  String? _selectedTime;
  String? _selectedSeason;

  // Phase 2 State (Cultural Memory)
  bool _showingMemoryTarget = true;
  int _countdown = 4;
  Timer? _countdownTimer;
  final Set<String> _selectedItemKeys = {};
  final List<String> _correctItemKeys = ['game_item_jaapi', 'game_item_dhol', 'game_item_tea'];
  final List<Map<String, String>> _allCulturalItems = [
    {'key': 'game_item_jaapi', 'icon': '👒'},
    {'key': 'game_item_dhol', 'icon': '🪘'},
    {'key': 'game_item_tea', 'icon': '🍃'},
    {'key': 'game_item_fish', 'icon': '🎣'},
    {'key': 'game_item_flower', 'icon': '🌸'},
    {'key': 'game_item_lamp', 'icon': '🪔'},
  ];

  // Phase 3 State (Number Tap)
  int _expectedNumber = 1;
  final List<int> _numbers = [3, 1, 4, 2];
  final Set<int> _tappedNumbers = {};

  @override
  void initState() {
    super.initState();
    _stopwatch.start();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _stopwatch.stop();
    super.dispose();
  }

  void _playVoiceInstructions(BuildContext context) {
    final voiceService = context.read<VoiceService>();

    String textToSpeak = '';
    if (_currentPhase == 1) {
      textToSpeak = context.tr('screening_voice_phase1');
    } else if (_currentPhase == 2) {
      textToSpeak = context.tr('screening_voice_phase2');
    } else if (_currentPhase == 3) {
      textToSpeak = context.tr('screening_voice_phase3');
    }

    if (textToSpeak.isNotEmpty) {
      voiceService.speak(textToSpeak);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 2),
          backgroundColor: AppColors.primary,
          content: Row(
            children: [
              const Icon(Icons.volume_up_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text('🔊 "$textToSpeak"', style: const TextStyle(fontSize: 11)),
              ),
            ],
          ),
        ),
      );
    }
  }

  void _startPhase2Timer() {
    _countdown = 4;
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_countdown > 1) {
        setState(() => _countdown--);
      } else {
        t.cancel();
        setState(() => _showingMemoryTarget = false);
      }
    });
  }

  void _completeScreening() {
    _stopwatch.stop();
    final elapsed = _stopwatch.elapsed.inSeconds;

    // Record silently to repository
    PhcRepository().recordScreeningResult(
      patientId: widget.patient.id,
      score: _totalScore,
      durationSeconds: elapsed,
    );

    setState(() => _currentPhase = 4);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 620),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Column(
            children: [
              // Top Game Banner
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF00796B), Color(0xFF004D40)],
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.stars_rounded, color: Colors.amber, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.tr('game_title'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${context.tr('elder_label')}: ${widget.patient.name} (${widget.patient.age} ${context.tr('field_age_yrs')})',
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    if (_currentPhase < 4) ...[
                      IconButton(
                        tooltip: context.tr('voice_guidance'),
                        icon: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: Colors.amber,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.volume_up_rounded, color: Color(0xFF004D40), size: 18),
                        ),
                        onPressed: () => _playVoiceInstructions(context),
                      ),
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          context.tr('game_step_fmt', params: {'step': _currentPhase.toString(), 'total': '3'}),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Dynamic Phase Body
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: _buildPhaseContent(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhaseContent() {
    switch (_currentPhase) {
      case 1:
        return _buildPhase1Orientation();
      case 2:
        return _buildPhase2Memory();
      case 3:
        return _buildPhase3NumberSequence();
      case 4:
      default:
        return _buildPhase4Celebration();
    }
  }

  // -------------------------------------------------------------
  // PHASE 1: ORIENTATION (Time & Season)
  // -------------------------------------------------------------
  Widget _buildPhase1Orientation() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                context.tr('game_phase1_title'),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.volume_up_rounded, color: AppColors.primary, size: 22),
              tooltip: context.tr('voice_guidance'),
              onPressed: () => _playVoiceInstructions(context),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          context.tr('game_ask_elder_picture'),
          style: const TextStyle(fontSize: 13, color: Colors.grey),
        ),
        const SizedBox(height: 16),
        Text(
          context.tr('game_what_time'),
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _buildChoiceCard(
              title: context.tr('game_time_morning'),
              icon: '🌅',
              isSelected: _selectedTime == 'morning',
              onTap: () => setState(() => _selectedTime = 'morning'),
            ),
            const SizedBox(width: 8),
            _buildChoiceCard(
              title: context.tr('game_time_afternoon'),
              icon: '☀️',
              isSelected: _selectedTime == 'afternoon',
              onTap: () => setState(() => _selectedTime = 'afternoon'),
            ),
            const SizedBox(width: 8),
            _buildChoiceCard(
              title: context.tr('game_time_night'),
              icon: '🌙',
              isSelected: _selectedTime == 'night',
              onTap: () => setState(() => _selectedTime = 'night'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          context.tr('game_what_season'),
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _buildChoiceCard(
              title: context.tr('game_season_rainy'),
              icon: '🌧️',
              isSelected: _selectedSeason == 'rainy',
              onTap: () => setState(() => _selectedSeason = 'rainy'),
            ),
            const SizedBox(width: 8),
            _buildChoiceCard(
              title: context.tr('game_season_winter'),
              icon: '❄️',
              isSelected: _selectedSeason == 'winter',
              onTap: () => setState(() => _selectedSeason = 'winter'),
            ),
            const SizedBox(width: 8),
            _buildChoiceCard(
              title: context.tr('game_season_summer'),
              icon: '🌻',
              isSelected: _selectedSeason == 'summer',
              onTap: () => setState(() => _selectedSeason = 'summer'),
            ),
          ],
        ),
        const Spacer(),
        ElevatedButton(
          onPressed: (_selectedTime != null && _selectedSeason != null)
              ? () {
                  _totalScore += 3; // 3 points for orientation
                  setState(() => _currentPhase = 2);
                  _startPhase2Timer();
                }
              : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: Text(context.tr('game_btn_next_step2'), style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildChoiceCard({
    required String title,
    required String icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary.withValues(alpha: 0.1) : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? AppColors.primary : Colors.grey.shade300,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Text(icon, style: const TextStyle(fontSize: 28)),
              const SizedBox(height: 4),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? AppColors.primary : AppColors.textPrimaryLight,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // PHASE 2: CULTURAL OBJECT RECALL
  // -------------------------------------------------------------
  Widget _buildPhase2Memory() {
    if (_showingMemoryTarget) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                context.tr('game_phase2_title'),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
              ),
              IconButton(
                icon: const Icon(Icons.volume_up_rounded, color: AppColors.primary, size: 20),
                tooltip: context.tr('voice_guidance'),
                onPressed: () => _playVoiceInstructions(context),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            context.tr('game_countdown_sub', params: {'count': _countdown.toString()}),
            style: const TextStyle(fontSize: 13, color: Colors.orange, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: _correctItemKeys.map((key) {
              final item = _allCulturalItems.firstWhere((it) => it['key'] == key);
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.amber.shade300, width: 2),
                ),
                child: Column(
                  children: [
                    Text(item['icon']!, style: const TextStyle(fontSize: 40)),
                    const SizedBox(height: 6),
                    Text(context.tr(key), style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      );
    }

    // Recall selection screen
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          context.tr('game_which_3_items'),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
        ),
        const SizedBox(height: 4),
        Text(
          context.tr('game_ask_elder_touch'),
          style: const TextStyle(fontSize: 13, color: Colors.grey),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: GridView.count(
            crossAxisCount: 3,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            children: _allCulturalItems.map((item) {
              final key = item['key']!;
              final isSelected = _selectedItemKeys.contains(key);
              return GestureDetector(
                onTap: () {
                  setState(() {
                    if (isSelected) {
                      _selectedItemKeys.remove(key);
                    } else if (_selectedItemKeys.length < 3) {
                      _selectedItemKeys.add(key);
                    }
                  });
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary.withValues(alpha: 0.12) : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? AppColors.primary : Colors.grey.shade300,
                      width: isSelected ? 2.5 : 1,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(item['icon']!, style: const TextStyle(fontSize: 32)),
                      const SizedBox(height: 4),
                      Text(
                        context.tr(key),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected ? AppColors.primary : AppColors.textPrimaryLight,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        ElevatedButton(
          onPressed: _selectedItemKeys.isNotEmpty
              ? () {
                  // Calculate match score (up to 3 points)
                  int matchCount = 0;
                  for (var key in _selectedItemKeys) {
                    if (_correctItemKeys.contains(key)) matchCount++;
                  }
                  _totalScore += matchCount;
                  setState(() => _currentPhase = 3);
                }
              : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: Text(context.tr('game_btn_final_step'), style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  // -------------------------------------------------------------
  // PHASE 3: NUMBER SEQUENCE TAP (1 -> 2 -> 3 -> 4)
  // -------------------------------------------------------------
  Widget _buildPhase3NumberSequence() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                context.tr('game_phase3_title'),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.volume_up_rounded, color: AppColors.primary, size: 22),
              tooltip: context.tr('voice_guidance'),
              onPressed: () => _playVoiceInstructions(context),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          context.tr('game_phase3_hint_fmt', params: {'next': _expectedNumber.toString()}),
          style: const TextStyle(fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 20),
        Expanded(
          child: GridView.count(
            crossAxisCount: 2,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            children: _numbers.map((n) {
              final isTapped = _tappedNumbers.contains(n);
              return GestureDetector(
                onTap: () {
                  if (n == _expectedNumber) {
                    setState(() {
                      _tappedNumbers.add(n);
                      _expectedNumber++;
                      _totalScore += 1; // 1 point per correct sequence tap (4 total)
                    });
                    if (_expectedNumber > 4) {
                      _completeScreening();
                    }
                  }
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: isTapped
                        ? Colors.green.shade100
                        : const Color(0xFF004D40).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isTapped ? Colors.green : const Color(0xFF00796B),
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      isTapped ? '✓' : '$n',
                      style: TextStyle(
                        fontSize: isTapped ? 36 : 40,
                        fontWeight: FontWeight.bold,
                        color: isTapped ? Colors.green.shade800 : AppColors.primaryDark,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  // -------------------------------------------------------------
  // PHASE 4: CELEBRATION (Zero Test Stress for Elder!)
  // -------------------------------------------------------------
  Widget _buildPhase4Celebration() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text('🎉 🎊 🌸', style: TextStyle(fontSize: 44)),
        const SizedBox(height: 12),
        Text(
          context.tr('game_celebration_title'),
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: AppColors.primaryDark,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          context.tr('game_celebration_sub'),
          style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.star, color: Colors.amber, size: _totalScore >= 5 ? 44 : 36),
            Icon(Icons.star, color: Colors.amber, size: _totalScore >= 8 ? 52 : 36),
            Icon(Icons.star, color: Colors.amber, size: _totalScore >= 5 ? 44 : 36),
          ],
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle_outline, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                context.tr('game_record_saved_fmt', params: {'score': _totalScore.toString()}),
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: () => Navigator.pop(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          child: Text(context.tr('game_return_dashboard'), style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
