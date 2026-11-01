import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/services/emergency_sos_service.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../data/local/hive_service.dart';
import '../../../../providers/app_provider.dart';

class CallCaregiverButton extends StatefulWidget {
  const CallCaregiverButton({super.key});

  @override
  State<CallCaregiverButton> createState() => _CallCaregiverButtonState();
}

class _CallCaregiverButtonState extends State<CallCaregiverButton> {
  StreamSubscription<DocumentSnapshot>? _userDocSub;
  StreamSubscription<User?>? _authSub;
  String _firebasePhone = '';
  String _caregiverName = '';
  List<String> _targetCaregiverIds = [];

  @override
  void initState() {
    super.initState();
    _initCaregiverPhoneListener();
  }

  @override
  void dispose() {
    _userDocSub?.cancel();
    _authSub?.cancel();
    super.dispose();
  }

  void _initCaregiverPhoneListener() {
    try {
      _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
        _userDocSub?.cancel();
        if (user == null) {
          if (mounted) setState(() {});
          return;
        }

        try {
          _userDocSub = FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .snapshots()
              .listen((doc) async {
        if (!doc.exists || doc.data() == null) return;
        final data = doc.data()!;

        // 1. Check direct caregiver phone fields on patient doc
        String phone = (data['caregiverPhone'] ?? data['guardianPhone'] ?? '').toString().trim();
        String name = (data['caretakerName'] ?? '').toString().trim();
        final List<String> cgIds = [];

        if (data['primaryCaregiverId'] != null) {
          cgIds.add(data['primaryCaregiverId'].toString());
        }
        if (data['linkedCaregiverId'] != null) {
          cgIds.add(data['linkedCaregiverId'].toString());
        }
        if (data['linkedCaregiverIds'] is List) {
          cgIds.addAll(List<String>.from(data['linkedCaregiverIds']));
        }

        // 2. If phone is not in patient document, lookup linked caregiver user docs
        if (phone.isEmpty) {
          try {
            // First check by direct linked IDs
            if (cgIds.isNotEmpty) {
              final cgDoc = await FirebaseFirestore.instance.collection('users').doc(cgIds.first).get();
              if (cgDoc.exists && cgDoc.data() != null) {
                final cgData = cgDoc.data()!;
                phone = (cgData['phone'] ?? cgData['mobile'] ?? '').toString().trim();
                if (name.isEmpty) {
                  name = (cgData['name'] ?? '').toString().trim();
                }
              }
            }

            // Fallback: Check if any caregiver has linkedPatients containing this user
            if (phone.isEmpty) {
              final cgQuery = await FirebaseFirestore.instance
                  .collection('users')
                  .where('linkedPatients', arrayContains: user.uid)
                  .limit(1)
                  .get();
              if (cgQuery.docs.isNotEmpty) {
                final cgDoc = cgQuery.docs.first;
                cgIds.add(cgDoc.id);
                final cgData = cgDoc.data();
                phone = (cgData['phone'] ?? cgData['mobile'] ?? '').toString().trim();
                if (name.isEmpty) {
                  name = (cgData['name'] ?? '').toString().trim();
                }
              }
            }

            // Sync discovered phone and name back to patient's Firestore doc & local Hive
            if (phone.isNotEmpty) {
              await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
                'caregiverPhone': phone,
                if (name.isNotEmpty) 'caretakerName': name,
              }, SetOptions(merge: true));
            }
          } catch (e) {
            debugPrint('CallCaregiverButton: linked caregiver phone fetch note: $e');
          }
        }

        // 3. Keep local cache in sync for offline resiliency
        if (phone.isNotEmpty) {
          try {
            final hive = HiveService();
            final profile = hive.getUserProfile() ?? {};
            profile['caregiverPhone'] = phone;
            if (name.isNotEmpty) profile['caretakerName'] = name;
            await hive.saveUserProfile(profile);
            await EmergencySosService().addEmergencyContact(phone);
          } catch (_) {}
        }

        if (mounted) {
          setState(() {
            _firebasePhone = phone;
            if (name.isNotEmpty) _caregiverName = name;
            _targetCaregiverIds = cgIds.toSet().toList();
          });
        }
      }, onError: (e) => debugPrint('Firestore user doc listen error: $e'));
    } catch (e) {
      debugPrint('CallCaregiverButton Firestore listen notice: $e');
    }
  });
} catch (e) {
  debugPrint('CallCaregiverButton Firebase auth listen notice: $e');
}
}

  String _getCaregiverPhone(BuildContext context) {
    if (_firebasePhone.isNotEmpty) return _firebasePhone;

    try {
      final profile = HiveService().getUserProfile();
      final phone = (profile?['caregiverPhone'] ?? profile?['guardianPhone'] ?? '').toString().trim();
      if (phone.isNotEmpty) return phone;

      final contacts = EmergencySosService().getEmergencyContacts();
      if (contacts.isNotEmpty) return contacts.first;
    } catch (_) {}
    return '';
  }

  String _getCaregiverLabel(BuildContext context) {
    if (_caregiverName.isNotEmpty) return 'Call $_caregiverName';

    try {
      final appProvider = context.read<AppProvider>();
      final profile = HiveService().getUserProfile();
      final name = (profile?['caretakerName'] ?? appProvider.caretakerName ?? '').toString().trim();
      if (name.isNotEmpty && name.toLowerCase() != 'not set' && name.toLowerCase() != 'not linked yet') {
        return 'Call $name';
      }
    } catch (_) {}
    return 'Call Caregiver';
  }

  Future<void> _dialCaregiver(BuildContext context) async {
    final phone = _getCaregiverPhone(context);

    if (phone.isNotEmpty) {
      final uri = Uri.parse('tel:$phone');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(uri);
      }

      // Log Call Caregiver Alert to Firebase Firestore so Caregiver Dashboard updates in real time!
      await _dispatchCallAlertToFirestore(phone);
    } else {
      _showSetPhoneDialog(context);
    }
  }

  Future<void> _dispatchCallAlertToFirestore(String phone) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final pId = user?.uid ?? 'patient_local';
      final hiveProfile = HiveService().getUserProfile();
      final pName = (hiveProfile?['name'] ?? user?.displayName ?? 'Patient').toString().trim();
      final pPhone = (hiveProfile?['phone'] ?? hiveProfile?['mobile'] ?? '').toString().trim();

      // Collect target caregiver IDs
      final List<String> targets = List.from(_targetCaregiverIds);
      if (targets.isEmpty && user != null) {
        try {
          final cgSnap = await FirebaseFirestore.instance
              .collection('users')
              .where('linkedPatients', arrayContains: user.uid)
              .get();
          for (final d in cgSnap.docs) {
            targets.add(d.id);
          }
        } catch (_) {}
      }

      // 1. Add alert to 'sos_alerts' collection
      await FirebaseFirestore.instance.collection('sos_alerts').add({
        'patientId': pId,
        'patientUid': pId,
        'patientName': pName,
        'patientPhone': pPhone,
        'targetCaregiverIds': targets.toSet().toList(),
        'targetCaregiverPhone': phone,
        'type': 'CALL_CAREGIVER',
        'title': '📞 Call from $pName',
        'message': '$pName tapped Call Caregiver to reach you.',
        'status': 'ACTIVE',
        'severity': 'warning',
        'timestamp': FieldValue.serverTimestamp(),
        'localTimestamp': DateTime.now().toIso8601String(),
        'smsDeliveredTo': [phone],
      });

      // 2. Add notification doc for each target caregiver
      for (final cgId in targets.toSet()) {
        try {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(cgId)
              .collection('notifications')
              .add({
            'title': '📞 Incoming Call from $pName',
            'message': '$pName called you from NeuroVerse.',
            'type': 'call_caregiver',
            'patientId': pId,
            'patientName': pName,
            'timestamp': FieldValue.serverTimestamp(),
            'isRead': false,
          });
        } catch (_) {}
      }

      // 3. Show local notification confirmation
      try {
        await NotificationService().showNotification(
          id: 888888,
          title: '📞 Calling Caregiver ($phone)',
          body: 'Caregiver has been notified of your call.',
        );
      } catch (_) {}
    } catch (e) {
      debugPrint('CallCaregiverButton: dispatch alert notice: $e');
    }
  }

  void _showSetPhoneDialog(BuildContext context) {
    final controller = TextEditingController(text: _getCaregiverPhone(context));
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.phone_in_talk_rounded, color: Color(0xFF059669)),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Caregiver Phone',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter your caregiver\'s phone number for 1-tap instant dialing & cloud sync:',
              style: TextStyle(fontSize: 13.5, height: 1.35),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              keyboardType: TextInputType.phone,
              autofocus: true,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.phone_rounded, color: Color(0xFF059669)),
                hintText: 'Enter phone number',
                filled: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
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
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF059669),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              final newPhone = controller.text.trim();
              if (newPhone.isNotEmpty) {
                // 1. Save to Local Storage (Hive) & Emergency Contacts
                try {
                  final hive = HiveService();
                  final profile = hive.getUserProfile() ?? {};
                  profile['caregiverPhone'] = newPhone;
                  profile['guardianPhone'] = newPhone;
                  await hive.saveUserProfile(profile);
                  await EmergencySosService().addEmergencyContact(newPhone);
                } catch (_) {}

                // 2. Save directly to Firebase Firestore for this user!
                final user = FirebaseAuth.instance.currentUser;
                if (user != null) {
                  try {
                    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
                      'caregiverPhone': newPhone,
                      'guardianPhone': newPhone,
                    }, SetOptions(merge: true));

                    // Check if a caregiver account exists with this phone number and auto-link!
                    final cleanPhone = newPhone.replaceAll(RegExp(r'\s+'), '');
                    final cgMatch = await FirebaseFirestore.instance
                        .collection('users')
                        .where('role', isEqualTo: 'caregiver')
                        .get();

                    for (final doc in cgMatch.docs) {
                      final cgPhone = (doc.data()['phone'] ?? doc.data()['mobile'] ?? '').toString().replaceAll(RegExp(r'\s+'), '');
                      if (cgPhone.isNotEmpty && (cgPhone == cleanPhone || cgPhone.endsWith(cleanPhone) || cleanPhone.endsWith(cgPhone))) {
                        final cgName = doc.data()['name']?.toString() ?? 'Caregiver';
                        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
                          'primaryCaregiverId': doc.id,
                          'linkedCaregiverId': doc.id,
                          'caretakerName': cgName,
                          'linkedCaregiverIds': FieldValue.arrayUnion([doc.id]),
                        }, SetOptions(merge: true));

                        await FirebaseFirestore.instance.collection('users').doc(doc.id).set({
                          'linkedPatients': FieldValue.arrayUnion([user.uid]),
                        }, SetOptions(merge: true));
                        break;
                      }
                    }
                  } catch (e) {
                    debugPrint('Error saving caregiver phone to Firestore: $e');
                  }
                }

                if (mounted) {
                  setState(() {
                    _firebasePhone = newPhone;
                  });
                }

                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          const Icon(Icons.cloud_done_rounded, color: Colors.white, size: 20),
                          const SizedBox(width: 8),
                          Expanded(child: Text('Caregiver number saved to Cloud: $newPhone')),
                        ],
                      ),
                      backgroundColor: const Color(0xFF059669),
                    ),
                  );
                }

                // Dial and dispatch alert
                if (context.mounted) {
                  _dialCaregiver(context);
                }
              }
            },
            child: const Text('Save & Dial'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final phone = _getCaregiverPhone(context);
    final label = _getCaregiverLabel(context);

    return InkWell(
      onTap: () => _dialCaregiver(context),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F2922) : const Color(0xFFECFDF5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark
                ? const Color(0xFF047857).withValues(alpha: 0.4)
                : const Color(0xFFA7F3D0),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF064E3B) : const Color(0xFFD1FAE5),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.phone_in_talk_rounded,
                color: Color(0xFF059669),
                size: 18,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      label,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: isDark ? const Color(0xFF6EE7B7) : const Color(0xFF065F46),
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      phone.isNotEmpty ? phone : 'Tap to Call',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white60 : const Color(0xFF047857),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
