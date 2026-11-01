import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/localization/app_translations.dart';
import '../../../../core/services/emergency_sos_service.dart';
import '../../../../data/local/hive_service.dart';
import '../../../../providers/app_provider.dart';

class SosEmergencyButton extends StatefulWidget {
  final VoidCallback? onSosTriggered;

  const SosEmergencyButton({super.key, this.onSosTriggered});

  @override
  State<SosEmergencyButton> createState() => _SosEmergencyButtonState();
}

class _SosEmergencyButtonState extends State<SosEmergencyButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pressController;
  late Animation<double> _progressAnimation;
  bool _isHolding = false;
  bool _isDispatched = false;

  @override
  void initState() {
    super.initState();
    // 2-second hold requirement for accidental tap prevention
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _progressAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pressController, curve: Curves.linear),
    )..addListener(() {
        final progress = _progressAnimation.value;
        if (progress > 0.3 && progress < 0.35) {
          HapticFeedback.lightImpact();
        } else if (progress > 0.6 && progress < 0.65) {
          HapticFeedback.mediumImpact();
        } else if (progress > 0.9 && progress < 0.95) {
          HapticFeedback.selectionClick();
        }
      });

    _pressController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _triggerEmergencySos();
      }
    });
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    if (_isDispatched) return;
    setState(() {
      _isHolding = true;
    });
    HapticFeedback.mediumImpact();
    _pressController.forward(from: 0.0);
  }

  void _onTapUp(TapUpDetails details) {
    if (_pressController.isAnimating && !_isDispatched) {
      _cancelHold();
    }
  }

  void _onTapCancel() {
    if (_pressController.isAnimating && !_isDispatched) {
      _cancelHold();
    }
  }

  void _cancelHold() {
    setState(() {
      _isHolding = false;
    });
    _pressController.reverse();
    HapticFeedback.lightImpact();

    // Reassure elderly user if quick tap occurred
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Row(
          children: [
            const Icon(Icons.info_outline_rounded, color: Colors.amber, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                context.tr('sos_hold_hint'),
                style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _triggerEmergencySos() async {
    HapticFeedback.heavyImpact();
    setState(() {
      _isHolding = false;
      _isDispatched = true;
    });

    final appProvider = context.read<AppProvider>();
    final patientName = appProvider.userName ?? 'Patient';

    // Show immediate progress / dispatch modal
    _showSosConfirmationModal(context, patientName);

    // Call service to get GPS, send SMS and Firestore alert
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    await EmergencySosService().triggerSos(
      context: context,
      patientName: patientName,
      patientId: currentUid ?? 'patient_${patientName.toLowerCase().replaceAll(" ", "_")}',
    );

    widget.onSosTriggered?.call();

    // Reset dispatched state after 5 seconds
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() {
          _isDispatched = false;
          _pressController.reset();
        });
      }
    });
  }

  void _showSosConfirmationModal(BuildContext context, String patientName) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final profile = HiveService().getUserProfile();
        final rawCgName = (profile?['caretakerName'] ?? '').toString().trim();
        final caregiverName = (rawCgName.isNotEmpty && rawCgName.toLowerCase() != 'not set' && rawCgName.toLowerCase() != 'not linked yet')
            ? rawCgName
            : 'Caregiver';
        final caregiverPhone = (profile?['caregiverPhone'] ?? profile?['guardianPhone'] ?? '').toString().trim();

        final contacts = EmergencySosService().getEmergencyContacts();
        final List<Map<String, String>> displayList = [];

        if (caregiverPhone.isNotEmpty) {
          displayList.add({'name': caregiverName, 'phone': caregiverPhone});
        }
        for (final c in contacts) {
          if (!displayList.any((e) => e['phone'] == c)) {
            displayList.add({'name': caregiverName, 'phone': c});
          }
        }

        final isDark = Theme.of(ctx).brightness == Brightness.dark;

        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Colors.red.withValues(alpha: 0.2),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Grab Handle
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 18),

              // Emergency Header Icon
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFEF4444), width: 2),
                ),
                child: const Icon(
                  Icons.emergency_rounded,
                  color: Color(0xFFDC2626),
                  size: 38,
                ),
              ),
              const SizedBox(height: 14),

              Text(
                context.tr('sos_dispatched_title'),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFDC2626),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),

              Text(
                context.tr('sos_dispatched_desc'),
                style: TextStyle(
                  fontSize: 13.5,
                  color: isDark ? Colors.white70 : const Color(0xFF4B5563),
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),

              // Caregiver Details Card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF262626) : const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? Colors.white12 : const Color(0xFFE5E7EB),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.contact_phone_rounded, size: 16, color: Color(0xFFDC2626)),
                        const SizedBox(width: 8),
                        Text(
                          displayList.isNotEmpty
                              ? 'Caregiver Details:'
                              : 'No Emergency Contacts Configured',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (displayList.isEmpty)
                      InkWell(
                        onTap: () {
                          Navigator.pop(ctx);
                          _showAddContactDialog(context);
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  context.tr('sos_contacts_empty'),
                                  style: const TextStyle(fontSize: 12, color: Colors.orange),
                                ),
                              ),
                              const Icon(Icons.add_circle_outline, color: Color(0xFFDC2626), size: 18),
                            ],
                          ),
                        ),
                      )
                    else
                      ...displayList.map(
                        (cg) => Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E2824) : Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isDark ? const Color(0xFF047857).withValues(alpha: 0.3) : const Color(0xFFA7F3D0),
                              width: 1.2,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF064E3B) : const Color(0xFFD1FAE5),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.person_rounded,
                                  color: Color(0xFF059669),
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      cg['name'] ?? 'Caregiver',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                        color: isDark ? Colors.white : const Color(0xFF1F2937),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      cg['phone'] ?? '',
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w600,
                                        color: isDark ? const Color(0xFF6EE7B7) : const Color(0xFF047857),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              InkWell(
                                onTap: () => launchUrl(Uri.parse('tel:')),
                                borderRadius: BorderRadius.circular(14),
                                child: Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF059669),
                                    borderRadius: BorderRadius.circular(14),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF059669).withValues(alpha: 0.35),
                                        blurRadius: 8,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.phone_in_talk_rounded,
                                    color: Colors.white,
                                    size: 26,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 22),

              // Single 'OK' Action Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDC2626),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 2,
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text(
                    'OK',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAddContactDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.emergency_rounded, color: Color(0xFFDC2626)),
            SizedBox(width: 8),
            Text('Add Caregiver Phone', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter phone number that will receive SMS and alerts on emergency button press:',
              style: TextStyle(fontSize: 13, height: 1.3),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              keyboardType: TextInputType.phone,
              autofocus: true,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.phone_rounded),
                hintText: 'Enter phone number',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
            onPressed: () async {
              final phone = controller.text.trim();
              if (phone.isNotEmpty) {
                await EmergencySosService().addEmergencyContact(phone);
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Added $phone to Emergency Contacts!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              }
            },
            child: const Text('Save Number', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: _progressAnimation,
      builder: (context, child) {
        final progress = _progressAnimation.value;

        return GestureDetector(
          onTapDown: _onTapDown,
          onTapUp: _onTapUp,
          onTapCancel: _onTapCancel,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            decoration: BoxDecoration(
              // High contrast Emergency Red theme
              gradient: LinearGradient(
                colors: _isHolding
                    ? [const Color(0xFF991B1B), const Color(0xFF7F1D1D)]
                    : isDark
                        ? [const Color(0xFF2E0C0C), const Color(0xFF1E0606)]
                        : [const Color(0xFFFEF2F2), const Color(0xFFFEE2E2)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _isHolding
                    ? const Color(0xFFEF4444)
                    : isDark
                        ? const Color(0xFFDC2626).withValues(alpha: 0.5)
                        : const Color(0xFFFECACA),
                width: _isHolding ? 2 : 1.2,
              ),
              boxShadow: _isHolding
                  ? [
                      BoxShadow(
                        color: const Color(0xFFDC2626).withValues(alpha: 0.4),
                        blurRadius: 14,
                        spreadRadius: 2,
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
            ),
            child: Stack(
              children: [
                // Background fill progress indicator when holding
                if (_isHolding)
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: progress,
                        child: Container(
                          color: const Color(0xFFDC2626).withValues(alpha: 0.35),
                        ),
                      ),
                    ),
                  ),

                Row(
                  children: [
                    // SOS Icon badge with pulsing hold indicator
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        if (_isHolding)
                          SizedBox(
                            width: 36,
                            height: 36,
                            child: CircularProgressIndicator(
                              value: progress,
                              strokeWidth: 3,
                              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                              backgroundColor: Colors.white24,
                            ),
                          ),
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: _isHolding
                                ? Colors.white
                                : const Color(0xFFDC2626),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.emergency_rounded,
                            color: _isHolding
                                ? const Color(0xFFDC2626)
                                : Colors.white,
                            size: 18,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 10),

                    // Label and subtext
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  context.tr('sos_button_title'),
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 14,
                                    letterSpacing: 0.3,
                                    color: _isHolding
                                        ? Colors.white
                                        : isDark
                                            ? const Color(0xFFF87171)
                                            : const Color(0xFFB91C1C),
                                  ),
                                ),
                                if (_isHolding) ...[
                                  const SizedBox(width: 4),
                                  const Text('🚨', style: TextStyle(fontSize: 11)),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 2),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              _isHolding
                                  ? 'HOLD (${((1 - progress) * 2).toStringAsFixed(1)}s)'
                                  : context.tr('sos_hold_hint'),
                              maxLines: 1,
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                color: _isHolding
                                    ? Colors.white.withValues(alpha: 0.9)
                                    : isDark
                                        ? Colors.white70
                                        : const Color(0xFF991B1B),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
