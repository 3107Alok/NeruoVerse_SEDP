import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/services/smart_alerts_service.dart';
import '../../auth/auth_screen.dart';
import 'package:provider/provider.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../../../data/local/hive_service.dart';
import '../../../../providers/app_provider.dart';
import '../../../../core/services/firebase_link_service.dart';
import '../../../../core/services/sync_service.dart';
import '../../../../core/services/voice_service.dart';
import '../../../../core/widgets/about_neuroverse_dialog.dart';
import '../../../../core/services/notification_service.dart';
import '../../patient/games/common/ner_illustrations.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../../../../core/models/reminder_model.dart';
import '../../../../core/services/reminder_service.dart';
import 'family_album_manager_dialog.dart';
import '../../../../core/widgets/privacy_policy_dialog.dart';
import 'package:url_launcher/url_launcher.dart';

class CaregiverMainScreen extends StatefulWidget {
  final List<String>? initialPatients;
  final int? initialPendingCount;
  final int? initialTabIndex;
  final Map<String, Map<String, dynamic>>? mockPatientDetails;
  final List<Map<String, dynamic>>? mockRequests;
  final Map<String, List<Map<String, dynamic>>>? mockSessions;
  final List<SmartAlert>? mockAlerts;

  const CaregiverMainScreen({
    super.key,
    this.initialPatients,
    this.initialPendingCount,
    this.initialTabIndex,
    this.mockPatientDetails,
    this.mockRequests,
    this.mockSessions,
    this.mockAlerts,
  });

  @override
  State<CaregiverMainScreen> createState() => _CaregiverMainScreenState();
}

class _CaregiverMainScreenState extends State<CaregiverMainScreen> with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  final List<int> _tabHistory = [];

  void _switchTab(int index) {
    if (_currentIndex == index) return;
    if (index == 0) {
      _tabHistory.clear();
    } else {
      _tabHistory.remove(index);
      _tabHistory.add(_currentIndex);
    }
    setState(() => _currentIndex = index);
  }
  final Set<String> _expandedPatientIds = {};
  bool _hasInitializedPatientsExpansion = false;
  late final SmartAlertsService _alertsService = SmartAlertsService();
  late AnimationController _syncController;
  StreamSubscription<QuerySnapshot>? _adminAnnouncementsSub;
  StreamSubscription<DocumentSnapshot>? _caregiverStatusSub;
  StreamSubscription<QuerySnapshot>? _sosAlertsSub;
  final Set<String> _seenAnnouncementIds = {};
  final Set<String> _dialogShownSosAlertIds = {};
  bool _isFirstAnnouncementBatch = true;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialTabIndex ?? 0;
    _syncController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _initAdminAnnouncementsListener();
    _listenToCaregiverSuspension();
    _initSosAlertsListener();
  }

  @override
  void dispose() {
    _caregiverStatusSub?.cancel();
    _adminAnnouncementsSub?.cancel();
    _sosAlertsSub?.cancel();
    _syncController.dispose();
    super.dispose();
  }

  void _listenToCaregiverSuspension() {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        _caregiverStatusSub = FirebaseFirestore.instance.collection('users').doc(uid).snapshots().listen((doc) async {
          if (doc.exists && doc.data() != null) {
            final isSuspended = doc.data()?['isSuspended'] == true;
            if (isSuspended) {
              await FirebaseAuth.instance.signOut();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    backgroundColor: Colors.red,
                    content: Text('Your account has been suspended by the administrator.'),
                    duration: Duration(seconds: 5),
                  ),
                );
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const AuthScreen()),
                  (route) => false,
                );
              }
            }
          }
        }, onError: (_) {});
      }
    } catch (_) {}
  }

  void _initAdminAnnouncementsListener() {
    try {
      _adminAnnouncementsSub = FirebaseFirestore.instance
          .collection('announcements')
          .orderBy('createdAt', descending: true)
          .limit(10)
          .snapshots()
          .listen((snapshot) {
        if (_isFirstAnnouncementBatch) {
          for (final doc in snapshot.docs) {
            _seenAnnouncementIds.add(doc.id);
          }
          _isFirstAnnouncementBatch = false;
          return;
        }

        for (final change in snapshot.docChanges) {
          if (change.type == DocumentChangeType.added) {
            final doc = change.doc;
            if (!_seenAnnouncementIds.contains(doc.id)) {
              _seenAnnouncementIds.add(doc.id);
              final data = doc.data();
              if (data != null) {
                final target = data['target'] as String? ?? 'all';
                if (target == 'all' || target == 'caregiver') {
                  final title = data['title'] as String? ?? 'System Announcement';
                  final body = data['message'] as String? ?? 'New announcement from Administrator.';
                  NotificationService().showNotification(
                    id: (doc.id.hashCode).abs() % 100000,
                    title: title,
                    body: body,
                  );
                }
              }
            }
          }
        }
      }, onError: (_) {});
    } catch (_) {}
  }

  void _initSosAlertsListener() {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      _sosAlertsSub = FirebaseFirestore.instance
          .collection('sos_alerts')
          .where('status', isEqualTo: 'ACTIVE')
          .snapshots()
          .listen((snapshot) async {
        // Fetch latest linked patients & caregiver's phone
        Set<String> linkedPatientUids = {};
        String caregiverPhone = '';
        try {
          final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
          if (userDoc.exists && userDoc.data() != null) {
            final uData = userDoc.data()!;
            linkedPatientUids = Set<String>.from(uData['linkedPatients'] ?? []);
            caregiverPhone = (uData['phone'] ?? uData['mobile'] ?? '').toString().trim();
          }
        } catch (_) {}

        for (final change in snapshot.docChanges) {
          if (change.type == DocumentChangeType.added || change.type == DocumentChangeType.modified) {
            final doc = change.doc;
            final docId = doc.id;
            if (_dialogShownSosAlertIds.contains(docId)) continue;

            final data = doc.data();
            if (data == null || data['status'] != 'ACTIVE') continue;

            // Only show for alerts triggered within the last 45 minutes
            final ts = data['timestamp'];
            DateTime? alertTime;
            if (ts is Timestamp) {
              alertTime = ts.toDate();
            } else if (data['localTimestamp'] != null) {
              alertTime = DateTime.tryParse(data['localTimestamp'].toString());
            }
            final isRecent = alertTime == null ||
                DateTime.now().difference(alertTime).inMinutes.abs() < 45;
            if (!isRecent) continue;

            final targetCaregivers = List<String>.from(data['targetCaregiverIds'] ?? []);
            final pUid = (data['patientUid'] ?? data['patientId'] ?? '').toString();
            final targetPhone = (data['targetCaregiverPhone'] ?? '').toString().trim();
            final smsList = List<String>.from(data['smsDeliveredTo'] ?? []);

            final cleanCgPhone = caregiverPhone.replaceAll(RegExp(r'\s+'), '');
            final isLinked = targetCaregivers.contains(uid) ||
                linkedPatientUids.contains(pUid) ||
                (cleanCgPhone.isNotEmpty &&
                    targetPhone.isNotEmpty &&
                    (targetPhone.replaceAll(RegExp(r'\s+'), '').endsWith(cleanCgPhone) ||
                        cleanCgPhone.endsWith(targetPhone.replaceAll(RegExp(r'\s+'), '')))) ||
                (cleanCgPhone.isNotEmpty &&
                    smsList.any((c) {
                      final clean = c.replaceAll(RegExp(r'\s+'), '');
                      return clean.endsWith(cleanCgPhone) || cleanCgPhone.endsWith(clean);
                    }));

            if (isLinked) {
              _dialogShownSosAlertIds.add(docId);
              final pName = data['patientName'] ?? 'Patient';
              final pPhone = (data['patientPhone'] ?? '').toString();
              final mapsUrl = (data['mapsUrl'] ?? '').toString();
              final alertType = (data['type'] ?? 'SOS').toString();
              final customTitle = data['title']?.toString();
              final customMessage = data['message']?.toString();
              final lat = (data['latitude'] as num?)?.toDouble();
              final lng = (data['longitude'] as num?)?.toDouble();
              final timeStr = alertTime != null
                  ? DateFormat('hh:mm a, dd MMM').format(alertTime)
                  : 'Just now';

              if (mounted) {
                _showIncomingSosDialog(
                  alertId: docId,
                  patientName: pName,
                  patientPhone: pPhone,
                  mapsUrl: mapsUrl,
                  lat: lat,
                  lng: lng,
                  timeStr: timeStr,
                  alertType: alertType,
                  customTitle: customTitle,
                  customMessage: customMessage,
                );
              }
            }
          }
        }
      }, onError: (_) {});
    } catch (_) {}
  }

  void _showIncomingSosDialog({
    required String alertId,
    required String patientName,
    required String patientPhone,
    required String mapsUrl,
    required double? lat,
    required double? lng,
    required String timeStr,
    String alertType = 'SOS',
    String? customTitle,
    String? customMessage,
  }) {
    final isCall = alertType == 'CALL_CAREGIVER';

    // Strip live location URLs or raw links from customMessage since dedicated Map button is displayed below
    String? cleanMessage = customMessage;
    if (cleanMessage != null) {
      cleanMessage = cleanMessage
          .replaceAll(RegExp(r'Live Location:\s*https?://\S+', caseSensitive: false), '')
          .replaceAll(RegExp(r'https?://\S+', caseSensitive: false), '')
          .replaceAll(RegExp(r'\s{2,}'), ' ')
          .trim();
      if (cleanMessage.isEmpty) {
        cleanMessage = null;
      }
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          backgroundColor: isCall ? const Color(0xFF042017) : const Color(0xFF2B0A0A),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isCall ? const Color(0xFF059669) : Colors.red.shade700,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isCall ? Icons.phone_in_talk_rounded : Icons.emergency_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  customTitle ?? (isCall ? '📞 INCOMING CALL' : '🚨 EMERGENCY SOS'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isCall
                        ? const Color(0xFF059669).withValues(alpha: 0.18)
                        : Colors.red.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isCall
                          ? const Color(0xFF059669).withValues(alpha: 0.35)
                          : Colors.red.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isCall ? Icons.phone_callback_rounded : Icons.person,
                        color: isCall ? const Color(0xFF6EE7B7) : Colors.redAccent,
                        size: 22,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          cleanMessage ??
                              (isCall
                                  ? '$patientName tapped Call Caregiver to reach you!'
                                  : '$patientName needs immediate help!'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Triggered at: $timeStr',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
                if (lat != null && lng != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'GPS Lock: ${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}',
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
                const SizedBox(height: 16),
                if (patientPhone.isNotEmpty)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final uri = Uri(scheme: 'tel', path: patientPhone);
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri);
                        }
                      },
                      icon: const Icon(Icons.phone, color: Colors.white),
                      label: Text(
                        'Call Back: $patientName ($patientPhone)',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isCall ? const Color(0xFF059669) : const Color(0xFF1B5E20),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                if (mapsUrl.isNotEmpty && mapsUrl.startsWith('http')) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final uri = Uri.parse(mapsUrl);
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        }
                      },
                      icon: const Icon(Icons.map_rounded, color: Colors.white),
                      label: const Text(
                        'Open Location in Google Maps',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1565C0),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
          actions: [
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () async {
                  try {
                    await FirebaseFirestore.instance.collection('sos_alerts').doc(alertId).update({
                      'status': 'RESOLVED',
                      'resolvedAt': FieldValue.serverTimestamp(),
                    });
                  } catch (_) {}
                  if (ctx.mounted) Navigator.of(ctx).pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: isCall ? const Color(0xFF059669) : Colors.red.shade800,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 2,
                ),
                child: const Text(
                  'OK',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  String _getTimeGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) {
      return 'Good morning';
    } else if (hour >= 12 && hour < 17) {
      return 'Good afternoon';
    } else if (hour >= 17 && hour < 21) {
      return 'Good evening';
    } else {
      return 'Good night';
    }
  }

  String _getTimeGreetingEmoji() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) {
      return '🌅';
    } else if (hour >= 12 && hour < 17) {
      return '☀️';
    } else if (hour >= 17 && hour < 21) {
      return '🌇';
    } else {
      return '🌙';
    }
  }

  DateTime? _parseDateTime(dynamic val) {
    if (val == null) return null;
    if (val is Timestamp) return val.toDate();
    if (val is DateTime) return val;
    if (val is String) return DateTime.tryParse(val);
    if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
    return null;
  }

  Widget _buildCurrentTab() {
    switch (_currentIndex) {
      case 0:
        return _buildOverviewTab();
      case 1:
        return _buildPatientsTab();
      case 2:
        return _buildAlertsTab();
      case 3:
        return _buildProfileTab();
      default:
        return _buildOverviewTab();
    }
  }

  Widget _buildNavItem({
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required int index,
  }) {
    final isSelected = _currentIndex == index;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmall = screenWidth < 360;
    const primaryColor = Color(0xFF00796B);
    final unselectedColor = isDark ? Colors.white54 : Colors.grey.shade600;

    return InkWell(
      onTap: () => _switchTab(index),
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: isSmall ? 6 : (screenWidth < 380 ? 10 : 14),
                vertical: isSmall ? 2 : 3.5,
              ),
              decoration: BoxDecoration(
                color: isSelected
                    ? primaryColor.withValues(alpha: 0.15)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                isSelected ? activeIcon : icon,
                color: isSelected ? primaryColor : unselectedColor,
                size: isSmall ? 19 : 22,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? primaryColor : unselectedColor,
                fontSize: isSmall ? 9.5 : (screenWidth < 380 ? 10.5 : 11),
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // AESTHETIC APP BAR
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);
    final isDataSynced = context.watch<AppProvider>().isDataSynced;
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmall = screenWidth < 360;

    return PopScope(
      canPop: _currentIndex == 0 && _tabHistory.isEmpty,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) return;
        if (_tabHistory.isNotEmpty) {
          final prevTab = _tabHistory.removeLast();
          setState(() => _currentIndex = prevTab);
        } else if (_currentIndex != 0) {
          setState(() => _currentIndex = 0);
        }
      },
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
      extendBody: false,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                'assets/images/app_icon.jpg',
                width: 30,
                height: 30,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: const Color(0xFF00796B),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.psychology_rounded, size: 20, color: Colors.white),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'NeuroVerse',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                      letterSpacing: 0.3,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Care Together. Grow Together.',
                    style: TextStyle(
                      fontSize: 9.8,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white60 : Colors.grey.shade600,
                      letterSpacing: -0.2,
                    ),
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.visible,
                  ),
                ],
              ),
            ),
          ],
        ),
        centerTitle: false,
        backgroundColor: theme.cardColor,
        elevation: 0,
        foregroundColor: isDark ? Colors.white : Colors.black87,
        actions: [
          // Sync Button with Center Checkmark / Exclamation
          IconButton(
            icon: Container(
              padding: EdgeInsets.all(isSmall ? 3.5 : 4.5),
              decoration: BoxDecoration(
                color: isDataSynced
                    ? (isDark ? const Color(0xFF122822) : const Color(0xFFE0F2F1))
                    : (isDark ? const Color(0xFF2A1B1B) : const Color(0xFFFFEBEE)),
                shape: BoxShape.circle,
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  RotationTransition(
                    turns: _syncController,
                    child: Icon(
                      Icons.sync_rounded,
                      size: isSmall ? 25 : 28,
                      color: isDataSynced
                          ? (isDark ? const Color(0xFF80CBC4) : const Color(0xFF00796B))
                          : (isDark ? const Color(0xFFEF5350) : const Color(0xFFDC2626)),
                    ),
                  ),
                  Icon(
                    isDataSynced ? Icons.check_rounded : Icons.priority_high_rounded,
                    size: isSmall ? 10 : 11.5,
                    color: isDataSynced
                        ? (isDark ? const Color(0xFF34D399) : const Color(0xFF047857))
                        : (isDark ? const Color(0xFFF87171) : const Color(0xFFDC2626)),
                    shadows: [
                      Shadow(
                        color: (isDataSynced
                                ? (isDark ? const Color(0xFF34D399) : const Color(0xFF047857))
                                : (isDark ? const Color(0xFFF87171) : const Color(0xFFDC2626)))
                            .withValues(alpha: 0.5),
                        blurRadius: 0.8,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            tooltip: 'Cloud Sync',
            onPressed: () async {
              if (_syncController.isAnimating) return;
              
              if (isDataSynced) {
                _showAlreadySyncedDialog(context);
                return;
              }

              _triggerForceSync();
            },
          ),
          IconButton(
            icon: Container(
              padding: EdgeInsets.all(isSmall ? 5 : 7),
              decoration: BoxDecoration(
                color: isDark ? Colors.white10 : const Color(0xFFE0F2F1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.notifications_none_rounded,
                size: isSmall ? 18 : 20,
                color: isDark ? Colors.white70 : const Color(0xFF1B3B36),
              ),
            ),
            tooltip: 'Smart Alerts',
            onPressed: () {
              _switchTab(2); // Jump to Alerts Tab!
            },
          ),
          IconButton(
            icon: Container(
              padding: EdgeInsets.all(isSmall ? 5 : 7),
              decoration: BoxDecoration(
                color: isDark ? Colors.white10 : const Color(0xFFE0F2F1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.settings_outlined, color: const Color(0xFF00796B), size: isSmall ? 18 : 20),
            ),
            tooltip: 'Settings',
            onPressed: _openSettingsSheet,
          ),
          SizedBox(width: isSmall ? 4 : 8),
        ],
      ),
      body: SafeArea(
        top: false,
        bottom: false,
        child: _buildCurrentTab(),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: theme.cardColor,
          border: Border(
            top: BorderSide(
              color: isDark ? Colors.white12 : Colors.grey.shade300,
              width: 1,
            ),
          ),
          boxShadow: isDark
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: isSmall ? 56 : 60,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(child: _buildNavItem(icon: Icons.home_outlined, activeIcon: Icons.home_rounded, label: 'Overview', index: 0)),
                Expanded(child: _buildNavItem(icon: Icons.people_outline_rounded, activeIcon: Icons.people_rounded, label: 'Patients', index: 1)),
                Expanded(child: _buildNavItem(icon: Icons.notifications_none_rounded, activeIcon: Icons.notifications_rounded, label: 'Alerts', index: 2)),
                Expanded(child: _buildNavItem(icon: Icons.person_outline_rounded, activeIcon: Icons.person_rounded, label: 'Profile', index: 3)),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

  // 1. OVERVIEW TAB
  Widget _buildOverviewTab() {
    if (widget.initialPatients != null) {
      return _buildOverviewContent(widget.initialPatients!, 'mock_caregiver_uid');
    }

    String? uid;
    try {
      uid = FirebaseAuth.instance.currentUser?.uid;
    } catch (_) {
      uid = null;
    }
    final currentUid = uid;
    if (currentUid == null) return const Center(child: Text("Not logged in"));

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(currentUid).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final data = snapshot.data!.data() as Map<String, dynamic>?;
        final patients = List<String>.from(data?['linkedPatients'] ?? []);
        return _buildOverviewContent(patients, currentUid);
      },
    );
  }

  Widget _buildOverviewContent(List<String> patients, String currentUid) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final screenWidth = MediaQuery.of(context).size.width;
    final isSmall = screenWidth < 360;
    final bottomInset = MediaQuery.of(context).padding.bottom;

        return ListView(
          padding: EdgeInsets.fromLTRB(
            isSmall ? 12.0 : 16.0,
            12.0,
            isSmall ? 12.0 : 16.0,
            28.0 + bottomInset,
          ),
          children: [
            // Top Caregiver Greeting & Connection Card (Matches Patient Home Aesthetic)
            Container(
              margin: const EdgeInsets.only(top: 4, bottom: 20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1B2E27) : const Color(0xFFE8F5ED),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isDark ? const Color(0xFF2E4C3E) : const Color(0xFFC8E6C9),
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: RepaintBoundary(
                        child: AnimatedNerLandscape(
                          isDark: isDark,
                          duration: const Duration(seconds: 14),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      _getTimeGreetingEmoji(),
                                      style: const TextStyle(fontSize: 16),
                                    ),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        '${_getTimeGreeting()},',
                                        style: TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w600,
                                          color: isDark ? Colors.white70 : const Color(0xFF2E7D32),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Caregiver Hub',
                                  style: TextStyle(
                                    fontSize: isSmall ? 19 : (screenWidth < 380 ? 21 : 23),
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : const Color(0xFF1B3B36),
                                    letterSpacing: -0.3,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF00796B).withValues(alpha: isDark ? 0.25 : 0.12),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: const Color(0xFF00796B).withValues(alpha: 0.3),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.people_alt_rounded, size: 13, color: Color(0xFF00796B)),
                                      const SizedBox(width: 4),
                                      Flexible(
                                        child: Text(
                                          '${patients.length} connected patient${patients.length == 1 ? '' : 's'}',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF00796B),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 9),
                                Text(
                                  'Your care and support make a difference 🩵',
                                  style: TextStyle(
                                    fontSize: isSmall ? 10.8 : (screenWidth < 380 ? 11.4 : 12.0),
                                    color: isDark ? Colors.white70 : const Color(0xFF3D6158),
                                    fontWeight: FontWeight.w500,
                                    letterSpacing: -0.1,
                                  ),
                                  maxLines: 1,
                                  softWrap: false,
                                  overflow: TextOverflow.visible,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Transform.translate(
                            offset: const Offset(0, -10),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                SizedBox(
                                  width: (screenWidth * 0.18).clamp(52.0, 72.0),
                                  height: (screenWidth * 0.13).clamp(38.0, 52.0),
                                  child: const CustomPaint(
                                    painter: _CaregiverIllustrationPainter(),
                                  ),
                                ),
                                const SizedBox(height: 5),
                                InkWell(
                                  onTap: _showAddPatientDialog,
                                  borderRadius: BorderRadius.circular(20),
                                  child: Container(
                                    padding: EdgeInsets.symmetric(horizontal: isSmall ? 9 : 12, vertical: isSmall ? 4.5 : 6),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF00796B),
                                      borderRadius: BorderRadius.circular(20),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFF00796B).withValues(alpha: 0.25),
                                          blurRadius: 6,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.person_add_rounded, size: 13, color: Colors.white),
                                        SizedBox(width: 4),
                                        Text(
                                          'Link Patient',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 4 Aesthetic Stat Cards (100% Live & Real Firestore Telemetry)
            _buildLiveStatCards(patients, currentUid),
            const SizedBox(height: 18),

            if (patients.isNotEmpty) ...[
              _buildSendPatientNotificationActionCard(patients),
              const SizedBox(height: 18),
            ],

            // Sessions Section Header
            Builder(
              builder: (context) {
                final isDark = Theme.of(context).brightness == Brightness.dark;
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        'Recent Cognitive Sessions',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF1B3B36),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (patients.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: () => _switchTab(1),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1B2E27) : const Color(0xFFE0F2F1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(Icons.location_on_rounded, size: 13, color: Color(0xFF00796B)),
                              SizedBox(width: 4),
                              Text(
                                'Live Tracking',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF00796B)),
                              ),
                              SizedBox(width: 2),
                              Icon(Icons.chevron_right_rounded, size: 14, color: Color(0xFF00796B)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
            const SizedBox(height: 14),

            if (patients.isEmpty)
              Builder(
                builder: (context) {
                  final isDark = Theme.of(context).brightness == Brightness.dark;
                  return Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
                      boxShadow: isDark
                          ? null
                          : [
                              BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 3)),
                            ],
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00796B).withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.person_add_alt_1_rounded, size: 36, color: Color(0xFF00796B)),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'No Patients Connected Yet',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF1B3B36)),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Ask your patient for their 6-character Connect Code from their profile tab to link accounts and receive real-time updates.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : Colors.grey.shade600, height: 1.4),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _showAddPatientDialog,
                          icon: const Icon(Icons.add_link_rounded, size: 18),
                          label: const Text('Connect Patient Now', style: TextStyle(fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00796B),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              )
            else
              _buildRecentSessionsTimeline(patients),
          ],
        );
  }

  Widget _buildLiveStatCards(List<String> patients, String uid) {
    if (widget.initialPendingCount != null || widget.initialPatients != null) {
      final screenWidth = MediaQuery.of(context).size.width;
      final isSmall = screenWidth < 360;
      final gap = isSmall ? 8.0 : 12.0;
      final pendingCount = widget.initialPendingCount ?? 0;

      return Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildCaregiverStatCard(
                  title: 'Linked Patients',
                  value: '${patients.length}',
                  subtitle: patients.isEmpty ? 'Tap to connect patient' : 'Tap to view details',
                  icon: Icons.people_rounded,
                  color: const Color(0xFF00796B),
                  badge: '${patients.length} ${patients.isEmpty ? "Active" : "Live"}',
                  onTap: () => _showLinkedPatientsSheet(patients),
                ),
              ),
              SizedBox(width: gap),
              Expanded(
                child: _buildCaregiverStatCard(
                  title: 'Pending Requests',
                  value: '$pendingCount',
                  subtitle: pendingCount > 0 ? 'Awaiting patient approval' : 'Tap to view sent requests',
                  icon: Icons.assignment_outlined,
                  color: const Color(0xFFE65100),
                  badge: pendingCount > 0 ? '$pendingCount Sent' : '0 Sent',
                  onTap: _showSentRequestsSheet,
                ),
              ),
            ],
          ),
          SizedBox(height: gap),
          Row(
            children: [
              Expanded(
                child: _buildCaregiverStatCard(
                  title: 'Daily Sessions',
                  value: '0 Today',
                  subtitle: 'No plays yet today',
                  icon: Icons.bar_chart_rounded,
                  color: const Color(0xFF1976D2),
                  badge: 'Today',
                ),
              ),
              SizedBox(width: gap),
              Expanded(
                child: _buildCaregiverStatCard(
                  title: 'Avg Accuracy',
                  value: 'N/A',
                  subtitle: 'No data recorded',
                  icon: Icons.track_changes_rounded,
                  color: const Color(0xFF2E7D32),
                  badge: 'Real-time',
                ),
              ),
            ],
          ),
        ],
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('link_requests')
          .where('caregiverId', isEqualTo: uid)
          .snapshots(),
      builder: (context, requestSnap) {
        final screenWidth = MediaQuery.of(context).size.width;
        final isSmall = screenWidth < 360;
        final gap = isSmall ? 8.0 : 12.0;

        final requestDocs = requestSnap.data?.docs ?? [];
        final pendingDocs = requestDocs.where((d) {
          final data = d.data() as Map<String, dynamic>;
          return (data['status'] ?? 'pending').toString().toLowerCase() == 'pending';
        }).toList();
        final pendingCount = pendingDocs.length;

        if (patients.isEmpty) {
          return Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildCaregiverStatCard(
                      title: 'Linked Patients',
                      value: '0',
                      subtitle: 'Tap to connect patient',
                      icon: Icons.people_rounded,
                      color: const Color(0xFF00796B),
                      badge: '0 Active',
                      onTap: () => _showLinkedPatientsSheet(patients),
                    ),
                  ),
                  SizedBox(width: gap),
                  Expanded(
                    child: _buildCaregiverStatCard(
                      title: 'Pending Requests',
                      value: '$pendingCount',
                      subtitle: pendingCount > 0 ? 'Awaiting patient approval' : 'Tap to view sent requests',
                      icon: Icons.assignment_outlined,
                      color: const Color(0xFFE65100),
                      badge: pendingCount > 0 ? '$pendingCount Sent' : '0 Sent',
                      onTap: _showSentRequestsSheet,
                    ),
                  ),
                ],
              ),
              SizedBox(height: gap),
              Row(
                children: [
                  Expanded(
                    child: _buildCaregiverStatCard(
                      title: 'Daily Sessions',
                      value: '0 Today',
                      subtitle: 'No plays yet today',
                      icon: Icons.bar_chart_rounded,
                      color: const Color(0xFF1976D2),
                      badge: 'Today',
                    ),
                  ),
                  SizedBox(width: gap),
                  Expanded(
                    child: _buildCaregiverStatCard(
                      title: 'Avg Accuracy',
                      value: 'N/A',
                      subtitle: 'No data recorded',
                      icon: Icons.track_changes_rounded,
                      color: const Color(0xFF2E7D32),
                      badge: 'Real-time',
                    ),
                  ),
                ],
              ),
            ],
          );
        }

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(patients.first)
              .collection('game_sessions')
              .snapshots(),
          builder: (context, sessionSnap) {
            final docs = sessionSnap.data?.docs ?? [];
            
            // 1. Calculate Real Sessions Today
            final now = DateTime.now();
            final todayDocs = docs.where((d) {
              final data = d.data() as Map<String, dynamic>;
              final date = _parseDateTime(data['timestamp']);
              if (date == null) return false;
              return date.year == now.year && date.month == now.month && date.day == now.day;
            }).toList();

            final todayCount = todayDocs.length;

            // 2. Calculate Real Overall Accuracy
            double avgAccuracy = 0;
            if (docs.isNotEmpty) {
              double totalAcc = 0;
              for (var d in docs) {
                final data = d.data() as Map<String, dynamic>;
                totalAcc += (data['accuracyPercentage'] as num?)?.toDouble() ?? 0;
              }
              avgAccuracy = (totalAcc / docs.length).roundToDouble();
            }

            return Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildCaregiverStatCard(
                        title: 'Linked Patients',
                        value: '${patients.length}',
                        subtitle: 'Tap to view details',
                        icon: Icons.people_rounded,
                        color: const Color(0xFF00796B),
                        badge: '${patients.length} Live',
                        onTap: () => _showLinkedPatientsSheet(patients),
                      ),
                    ),
                    SizedBox(width: gap),
                    Expanded(
                      child: _buildCaregiverStatCard(
                        title: 'Pending Requests',
                        value: '$pendingCount',
                        subtitle: pendingCount > 0 ? 'Awaiting patient approval' : 'Tap to view sent requests',
                        icon: Icons.assignment_outlined,
                        color: const Color(0xFFE65100),
                        badge: pendingCount > 0 ? '$pendingCount Sent' : '0 Sent',
                        onTap: _showSentRequestsSheet,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: gap),
                Row(
                  children: [
                    Expanded(
                      child: _buildCaregiverStatCard(
                        title: 'Daily Sessions',
                        value: '$todayCount Today',
                        subtitle: todayCount > 0 ? '$todayCount game${todayCount > 1 ? "s" : ""} played' : 'No plays yet today',
                        icon: Icons.bar_chart_rounded,
                        color: const Color(0xFF1976D2),
                        badge: todayCount > 0 ? 'Active' : 'Today',
                      ),
                    ),
                    SizedBox(width: gap),
                    Expanded(
                      child: _buildCaregiverStatCard(
                        title: 'Avg Accuracy',
                        value: docs.isNotEmpty ? '${avgAccuracy.toInt()}%' : 'N/A',
                        subtitle: docs.isNotEmpty ? 'Across ${docs.length} sessions' : 'Awaiting gameplay',
                        icon: Icons.track_changes_rounded,
                        color: const Color(0xFF2E7D32),
                        badge: 'Real-time',
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _formatSessionTimestamp(dynamic timestamp) {
    DateTime? dt = _parseDateTime(timestamp);
    if (dt == null) return 'Recent';
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24 && dt.day == now.day) {
      return '${diff.inHours}h ago';
    } else if (diff.inDays < 2) {
      return 'Yesterday';
    } else {
      return '${dt.day}/${dt.month}';
    }
  }

  Widget _buildSendPatientNotificationActionCard(List<String> patients) {
    if (patients.isEmpty) return const SizedBox.shrink();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 2),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF132A26) : const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF00796B).withValues(alpha: isDark ? 0.35 : 0.25),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00796B).withValues(alpha: isDark ? 0.12 : 0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showSendPatientNotificationSheet(patients),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00796B).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.notifications_active_rounded,
                    color: Color(0xFF00796B),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Send Patient Game Reminder',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: const BoxDecoration(
                    color: Color(0xFF00796B),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.send_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showSendPatientNotificationSheet(List<String> patients) {
    if (patients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No connected patients found to send reminders.'),
          backgroundColor: Color(0xFFE65100),
        ),
      );
      return;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selectedPatientIds = Set<String>.from(patients);

    final presetTitles = [
      '🎮 Time for Daily Brain Training!',
      '🧠 Play Memory & Pattern Games',
      '🎯 Complete Today\'s Cognitive Target',
      '⚡ Quick 5-Minute Brain Workout',
      '🌟 Great Job! Play One More Round',
      '🧘 Mind Rest & Breathing Session',
      '💧 Hydration & Health Check-in',
      '✏️ Custom Reminder...',
    ];

    final defaultMessages = {
      '🎮 Time for Daily Brain Training!':
          'Hello! Please take 5 minutes to complete your daily brain exercises on NeuroVerse to keep your cognitive score active.',
      '🧠 Play Memory & Pattern Games':
          'Let\'s keep your memory sharp! Open the Game Hub and play a round of Memory Cards or Pattern Matrix.',
      '🎯 Complete Today\'s Cognitive Target':
          'You are close to your daily cognitive goal! Complete today\'s game session to keep your streak going.',
      '⚡ Quick 5-Minute Brain Workout':
          'A quick 5-minute brain workout will boost your focus and reaction speed today.',
      '🌟 Great Job! Play One More Round':
          'You did great in your recent session! Try playing one more round to beat your personal best.',
      '🧘 Mind Rest & Breathing Session':
          'Take a relaxing break! Do a gentle breathing exercise and rest your eyes before continuing.',
      '💧 Hydration & Health Check-in':
          'Friendly health reminder: Please stay hydrated, take any prescribed medications, and have a good rest.',
      '✏️ Custom Reminder...': '',
    };

    String selectedTitle = presetTitles.first;
    final customTitleController = TextEditingController();
    final messageController = TextEditingController(text: defaultMessages[selectedTitle]);
    bool isSending = false;
    bool isHighPriority = true;

    // Reminder Type Selection
    ReminderType selectedReminderType = ReminderType.dailyActivity;

    // Sub-type inside Medicine
    String selectedMedicineSubType = 'Medicine 💊';

    // Medicine Fields
    final medicineNameController = TextEditingController();
    final doseQuantityController = TextEditingController(text: '1 tablet');
    MealTiming selectedMealTiming = MealTiming.afterMeal;
    DateTime medicineStartDate = DateTime.now();
    TimeOfDay medicineReminderTime = const TimeOfDay(hour: 8, minute: 0);
    int medicineRepeatGapHours = 8;
    DateTime medicineEndDate = DateTime.now().add(const Duration(days: 7));

    // Doctor Appointment Fields
    final doctorNameController = TextEditingController();
    final hospitalNameController = TextEditingController();
    DateTime appointmentDate = DateTime.now().add(const Duration(days: 1));
    TimeOfDay appointmentTime = const TimeOfDay(hour: 10, minute: 0);
    final appointmentNotesController = TextEditingController();

    // Hydration Fields
    final waterQuantityController = TextEditingController(text: '250 ml');
    DateTime hydrationStartDate = DateTime.now();
    TimeOfDay hydrationFirstReminderTime = const TimeOfDay(hour: 8, minute: 0);
    int hydrationRepeatGapHours = 2;
    DateTime hydrationEndDate = DateTime.now().add(const Duration(days: 7));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetCtx, setSheetState) {
            final mq = MediaQuery.of(sheetCtx);
            final parentMq = MediaQuery.of(context);
            final bottomInset = mq.viewPadding.bottom > 0
                ? mq.viewPadding.bottom
                : (parentMq.viewPadding.bottom > 0
                    ? parentMq.viewPadding.bottom
                    : (mq.padding.bottom > 0 ? mq.padding.bottom : parentMq.padding.bottom));
            final keyboardInset = mq.viewInsets.bottom;
            final screenH = mq.size.height;
            final screenW = mq.size.width;
            final isSmall = screenW < 360;

            final sheetBg = isDark ? const Color(0xFF152321) : Colors.white;
            final cardBg = isDark ? const Color(0xFF1B2B28) : const Color(0xFFF8FAFC);
            final cardBorder = isDark ? const Color(0xFF2B3F3B) : const Color(0xFFE2ECE8);
            final titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
            final subtitleColor = isDark ? Colors.white60 : const Color(0xFF64748B);
            final sectionHeaderColor = isDark ? const Color(0xFF80CBC4) : const Color(0xFF00796B);

            return ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 540,
                maxHeight: screenH * 0.90,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: sheetBg,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.18),
                      blurRadius: 28,
                      offset: const Offset(0, -6),
                    ),
                  ],
                ),
                child: Padding(
                  padding: EdgeInsets.only(bottom: keyboardInset),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 1. Drag Handle & Modern Header Banner
                      Padding(
                        padding: EdgeInsets.fromLTRB(isSmall ? 16 : 20, 10, isSmall ? 12 : 16, 12),
                        child: Column(
                          children: [
                            Center(
                              child: Container(
                                width: 38,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.white24 : const Color(0xFFCBD5E1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFF00897B), Color(0xFF004D40)],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(14),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF00796B).withValues(alpha: isDark ? 0.35 : 0.25),
                                        blurRadius: 10,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: const Center(
                                    child: Icon(Icons.send_rounded, color: Colors.white, size: 21),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Send Patient Notification',
                                        style: TextStyle(
                                          fontSize: isSmall ? 16 : 17.5,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: -0.3,
                                          color: titleColor,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 3),
                                      Row(
                                        children: [
                                          Container(
                                            width: 6.5,
                                            height: 6.5,
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF10B981),
                                              shape: BoxShape.circle,
                                              boxShadow: [
                                                BoxShadow(
                                                  color: const Color(0xFF10B981).withValues(alpha: 0.5),
                                                  blurRadius: 4,
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Flexible(
                                            child: Text(
                                              'Direct reminder to linked patients',
                                              style: TextStyle(
                                                fontSize: 11.5,
                                                fontWeight: FontWeight.w500,
                                                color: subtitleColor,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  decoration: BoxDecoration(
                                    color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.04),
                                    shape: BoxShape.circle,
                                  ),
                                  child: IconButton(
                                    icon: Icon(Icons.close_rounded, size: 20, color: isDark ? Colors.white70 : const Color(0xFF64748B)),
                                    padding: const EdgeInsets.all(8),
                                    constraints: const BoxConstraints(),
                                    onPressed: () => Navigator.pop(sheetContext),
                                    tooltip: 'Close',
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Divider(height: 1, color: isDark ? const Color(0xFF243330) : const Color(0xFFE8EFEF)),

                      // 2. Scrollable Body with Natural Height (Zero Excess Blank Space)
                      Flexible(
                        child: SafeArea(
                          top: false,
                          bottom: true,
                          minimum: EdgeInsets.only(bottom: bottomInset > 0 ? bottomInset : 10),
                          child: ListView(
                            shrinkWrap: true,
                            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                            padding: EdgeInsets.fromLTRB(
                              isSmall ? 16 : 20,
                              14,
                              isSmall ? 16 : 20,
                              6,
                            ),
                            children: [
                              // Patient Selection Section
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Flexible(
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Flexible(
                                          child: Text(
                                            'SELECT PATIENT(S)',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              letterSpacing: 0.8,
                                              color: sectionHeaderColor,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 7.5, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF00796B).withValues(alpha: isDark ? 0.22 : 0.10),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(
                                              color: const Color(0xFF00796B).withValues(alpha: isDark ? 0.35 : 0.20),
                                              width: 0.9,
                                            ),
                                          ),
                                          child: Text(
                                            '${selectedPatientIds.length}/${patients.length}',
                                            style: const TextStyle(
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFF00796B),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (patients.length > 1)
                                    TextButton(
                                      style: TextButton.styleFrom(
                                        visualDensity: VisualDensity.compact,
                                        foregroundColor: const Color(0xFF00796B),
                                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                                      ),
                                      onPressed: () {
                                        setSheetState(() {
                                          if (selectedPatientIds.length == patients.length) {
                                            selectedPatientIds.clear();
                                          } else {
                                            selectedPatientIds.addAll(patients);
                                          }
                                        });
                                      },
                                      child: Text(
                                        selectedPatientIds.length == patients.length
                                            ? 'Deselect All'
                                            : 'Select All',
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 7),
                              Container(
                                constraints: const BoxConstraints(maxHeight: 165),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: cardBorder, width: 1.15),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: isDark ? 0.20 : 0.03),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Material(
                                  color: cardBg,
                                  borderRadius: BorderRadius.circular(16),
                                  clipBehavior: Clip.antiAlias,
                                  child: ListView.separated(
                                    shrinkWrap: true,
                                    itemCount: patients.length,
                                    separatorBuilder: (_, _) => Divider(
                                      height: 1,
                                      color: isDark ? const Color(0xFF263935) : const Color(0xFFE8EFEF),
                                    ),
                                    itemBuilder: (context, idx) {
                                      final pid = patients[idx];
                                      final isChecked = selectedPatientIds.contains(pid);

                                      return FutureBuilder<DocumentSnapshot?>(
                                        future: (() async {
                                          try {
                                            return await FirebaseFirestore.instance.collection('users').doc(pid).get();
                                          } catch (_) {
                                            return null;
                                          }
                                        })(),
                                        builder: (context, snap) {
                                          final pData = snap.data?.data() as Map<String, dynamic>?;
                                          final pName = widget.mockPatientDetails?[pid]?['name'] ?? pData?['name'] ?? 'Patient ${idx + 1}';
                                          final pCode = widget.mockPatientDetails?[pid]?['connectCode'] ?? pData?['connectCode'] ?? '';

                                          return Material(
                                            color: isChecked
                                                ? const Color(0xFF00796B).withValues(alpha: isDark ? 0.08 : 0.04)
                                                : Colors.transparent,
                                            child: CheckboxListTile(
                                              value: isChecked,
                                              activeColor: const Color(0xFF00796B),
                                              checkColor: Colors.white,
                                              checkboxShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4.5)),
                                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                                              dense: true,
                                              title: Text(
                                                pName,
                                                style: TextStyle(
                                                  fontSize: 13.5,
                                                  fontWeight: FontWeight.w700,
                                                  color: titleColor,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              subtitle: pCode.isNotEmpty
                                                  ? Text(
                                                      'Code: $pCode',
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        fontWeight: FontWeight.w500,
                                                        color: subtitleColor,
                                                      ),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    )
                                                  : null,
                                              secondary: Container(
                                                width: 36,
                                                height: 36,
                                                decoration: BoxDecoration(
                                                  gradient: isChecked
                                                      ? const LinearGradient(
                                                          colors: [Color(0xFF00897B), Color(0xFF004D40)],
                                                          begin: Alignment.topLeft,
                                                          end: Alignment.bottomRight,
                                                        )
                                                      : null,
                                                  color: isChecked
                                                      ? null
                                                      : const Color(0xFF00796B).withValues(alpha: isDark ? 0.20 : 0.10),
                                                  shape: BoxShape.circle,
                                                  border: Border.all(
                                                    color: const Color(0xFF00796B).withValues(alpha: isChecked ? 0.4 : 0.25),
                                                    width: 1,
                                                  ),
                                                ),
                                                child: Center(
                                                  child: Text(
                                                    pName.isNotEmpty ? pName[0].toUpperCase() : 'P',
                                                    style: TextStyle(
                                                      fontSize: 13,
                                                      fontWeight: FontWeight.w800,
                                                      color: isChecked ? Colors.white : const Color(0xFF00796B),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              onChanged: (val) {
                                                setSheetState(() {
                                                  if (val == true) {
                                                    selectedPatientIds.add(pid);
                                                  } else {
                                                    selectedPatientIds.remove(pid);
                                                  }
                                                });
                                              },
                                            ),
                                          );
                                        },
                                      );
                                    },
                                  ),
                                ),
                              ),
                               const SizedBox(height: 14),

                              // 2. Reminder Type Selector
                              Text(
                                'REMINDER TYPE',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.8,
                                  color: sectionHeaderColor,
                                ),
                              ),
                              const SizedBox(height: 7),
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: cardBg,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: cardBorder, width: 1.15),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: InkWell(
                                        onTap: () => setSheetState(() => selectedReminderType = ReminderType.dailyActivity),
                                        borderRadius: BorderRadius.circular(10),
                                        child: Container(
                                          height: 33,
                                          decoration: BoxDecoration(
                                            color: selectedReminderType == ReminderType.dailyActivity
                                                ? const Color(0xFF00796B)
                                                : Colors.transparent,
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: Center(
                                            child: Text(
                                              'Daily Activities',
                                              style: TextStyle(
                                                fontSize: 11.5,
                                                fontWeight: selectedReminderType == ReminderType.dailyActivity ? FontWeight.bold : FontWeight.w500,
                                                color: selectedReminderType == ReminderType.dailyActivity
                                                    ? Colors.white
                                                    : (isDark ? Colors.white70 : const Color(0xFF4A6B63)),
                                              ),
                                              maxLines: 1,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: selectedReminderType == ReminderType.medicine
                                          ? Container(
                                              height: 33,
                                              padding: const EdgeInsets.symmetric(horizontal: 4),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF00796B),
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                              child: DropdownButtonHideUnderline(
                                                child: DropdownButton<String>(
                                                  value: selectedMedicineSubType,
                                                  isExpanded: true,
                                                  isDense: true,
                                                  alignment: Alignment.center,
                                                  icon: const Icon(
                                                    Icons.arrow_drop_down_rounded,
                                                    color: Colors.white,
                                                    size: 18,
                                                  ),
                                                  dropdownColor: isDark ? const Color(0xFF1B2B28) : Colors.white,
                                                  borderRadius: BorderRadius.circular(12),
                                                  selectedItemBuilder: (BuildContext context) {
                                                    return [
                                                      Center(
                                                        child: Text(
                                                          'Medicine 💊',
                                                          style: const TextStyle(
                                                            fontSize: 11.5,
                                                            fontWeight: FontWeight.bold,
                                                            color: Colors.white,
                                                          ),
                                                          maxLines: 1,
                                                          overflow: TextOverflow.ellipsis,
                                                        ),
                                                      ),
                                                      Center(
                                                        child: Text(
                                                          'Doctor Appt 🩺',
                                                          style: const TextStyle(
                                                            fontSize: 11.5,
                                                            fontWeight: FontWeight.bold,
                                                            color: Colors.white,
                                                          ),
                                                          maxLines: 1,
                                                          overflow: TextOverflow.ellipsis,
                                                        ),
                                                      ),
                                                    ];
                                                  },
                                                  items: [
                                                    DropdownMenuItem<String>(
                                                      value: 'Medicine 💊',
                                                      child: Text(
                                                        'Medicine 💊',
                                                        style: TextStyle(
                                                          fontSize: 13,
                                                          fontWeight: FontWeight.w600,
                                                          color: isDark ? Colors.white : Colors.black87,
                                                        ),
                                                      ),
                                                    ),
                                                    DropdownMenuItem<String>(
                                                      value: 'Doctor Appointment 🩺',
                                                      child: Text(
                                                        'Doctor Appointment 🩺',
                                                        style: TextStyle(
                                                          fontSize: 13,
                                                          fontWeight: FontWeight.w600,
                                                          color: isDark ? Colors.white : Colors.black87,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                  onChanged: (val) {
                                                    if (val == null) return;
                                                    setSheetState(() => selectedMedicineSubType = val);
                                                  },
                                                ),
                                              ),
                                            )
                                          : InkWell(
                                              onTap: () => setSheetState(() => selectedReminderType = ReminderType.medicine),
                                              borderRadius: BorderRadius.circular(10),
                                              child: Container(
                                                height: 33,
                                                decoration: BoxDecoration(
                                                  color: Colors.transparent,
                                                  borderRadius: BorderRadius.circular(10),
                                                ),
                                                child: Center(
                                                  child: Text(
                                                    'Medicine 💊',
                                                    style: TextStyle(
                                                      fontSize: 11.5,
                                                      fontWeight: FontWeight.w500,
                                                      color: isDark ? Colors.white70 : const Color(0xFF4A6B63),
                                                    ),
                                                    maxLines: 1,
                                                  ),
                                                ),
                                              ),
                                            ),
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: InkWell(
                                        onTap: () => setSheetState(() => selectedReminderType = ReminderType.hydration),
                                        borderRadius: BorderRadius.circular(10),
                                        child: Container(
                                          height: 33,
                                          decoration: BoxDecoration(
                                            color: selectedReminderType == ReminderType.hydration
                                                ? const Color(0xFF00796B)
                                                : Colors.transparent,
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: Center(
                                            child: Text(
                                              'Hydration 💧',
                                              style: TextStyle(
                                                fontSize: 11.5,
                                                fontWeight: selectedReminderType == ReminderType.hydration ? FontWeight.bold : FontWeight.w500,
                                                color: selectedReminderType == ReminderType.hydration
                                                    ? Colors.white
                                                    : (isDark ? Colors.white70 : const Color(0xFF4A6B63)),
                                              ),
                                              maxLines: 1,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 14),

                              if (selectedReminderType == ReminderType.dailyActivity) ...[
                                // Preset Notification Title / Dropdown Section
                                Text(
                                  'NOTIFICATION TITLE / PRESET',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.8,
                                    color: sectionHeaderColor,
                                  ),
                                ),
                                const SizedBox(height: 7),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: cardBg,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: cardBorder, width: 1.15),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.02),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: selectedTitle,
                                      isExpanded: true,
                                      icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF00796B), size: 22),
                                      dropdownColor: isDark ? const Color(0xFF1B2B28) : Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                      items: presetTitles.map((title) {
                                        return DropdownMenuItem<String>(
                                          value: title,
                                          child: Text(
                                            title,
                                            style: TextStyle(
                                              fontSize: 13.5,
                                              fontWeight: FontWeight.w600,
                                              color: titleColor,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        );
                                      }).toList(),
                                      onChanged: (val) {
                                        if (val == null) return;
                                        setSheetState(() {
                                          selectedTitle = val;
                                          if (val != '✏️ Custom Reminder...') {
                                            messageController.text = defaultMessages[val] ?? '';
                                          }
                                        });
                                      },
                                    ),
                                  ),
                                ),
                                if (selectedTitle == '✏️ Custom Reminder...') ...[
                                  const SizedBox(height: 10),
                                  TextField(
                                    controller: customTitleController,
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w600,
                                      color: titleColor,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: 'Enter custom reminder title...',
                                      hintStyle: TextStyle(fontSize: 13, color: subtitleColor),
                                      filled: true,
                                      fillColor: cardBg,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(14),
                                        borderSide: BorderSide(color: cardBorder, width: 1.15),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(14),
                                        borderSide: BorderSide(color: cardBorder, width: 1.15),
                                      ),
                                      focusedBorder: const OutlineInputBorder(
                                        borderRadius: BorderRadius.all(Radius.circular(14)),
                                        borderSide: BorderSide(color: Color(0xFF00796B), width: 1.6),
                                      ),
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 14),

                                // Message Body Section
                                Text(
                                  'MESSAGE BODY',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.8,
                                    color: sectionHeaderColor,
                                  ),
                                ),
                                const SizedBox(height: 7),
                                TextField(
                                  controller: messageController,
                                  maxLines: 3,
                                  style: TextStyle(
                                    fontSize: 13,
                                    height: 1.45,
                                    color: titleColor,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: 'Write a motivating message for the patient...',
                                    hintStyle: TextStyle(
                                      fontSize: 12.5,
                                      color: subtitleColor,
                                    ),
                                    filled: true,
                                    fillColor: cardBg,
                                    contentPadding: const EdgeInsets.all(14),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: BorderSide(color: cardBorder, width: 1.15),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: BorderSide(color: cardBorder, width: 1.15),
                                    ),
                                    focusedBorder: const OutlineInputBorder(
                                      borderRadius: BorderRadius.all(Radius.circular(14)),
                                      borderSide: BorderSide(color: Color(0xFF00796B), width: 1.6),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 14),

                                // High Priority Notification Card
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: isHighPriority
                                        ? (isDark ? const Color(0xFF2E1C12) : const Color(0xFFFFF7ED))
                                        : cardBg,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: isHighPriority
                                          ? (isDark ? const Color(0xFF5C331C) : const Color(0xFFFED7AA))
                                          : cardBorder,
                                      width: 1.15,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: isHighPriority
                                            ? const Color(0xFFEA580C).withValues(alpha: isDark ? 0.20 : 0.08)
                                            : Colors.black.withValues(alpha: isDark ? 0.15 : 0.02),
                                        blurRadius: isHighPriority ? 8 : 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: isHighPriority
                                              ? const Color(0xFFEA580C).withValues(alpha: isDark ? 0.25 : 0.15)
                                              : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
                                          borderRadius: BorderRadius.circular(10),
                                          border: isHighPriority
                                              ? Border.all(color: const Color(0xFFEA580C).withValues(alpha: 0.3), width: 1)
                                              : null,
                                        ),
                                        child: Icon(
                                          Icons.bolt_rounded,
                                          size: 19,
                                          color: isHighPriority ? const Color(0xFFEA580C) : subtitleColor,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'High Priority Notification',
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w700,
                                                color: isHighPriority
                                                    ? (isDark ? const Color(0xFFFDBA74) : const Color(0xFFC2410C))
                                                    : titleColor,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              'Delivers immediate heads-up alert to patient device',
                                              style: TextStyle(
                                                fontSize: 10.5,
                                                fontWeight: FontWeight.w500,
                                                color: subtitleColor,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Switch.adaptive(
                                        value: isHighPriority,
                                        activeThumbColor: const Color(0xFF00796B),
                                        activeTrackColor: const Color(0xFF00796B).withValues(alpha: 0.4),
                                        onChanged: (val) {
                                          setSheetState(() => isHighPriority = val);
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ] else if (selectedReminderType == ReminderType.medicine) ...[
                                if (!selectedMedicineSubType.contains('Doctor')) ...[
                                  // Medicine Form Fields
                                  Text(
                                    'MEDICINE NAME',
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: sectionHeaderColor),
                                  ),
                                  const SizedBox(height: 6),
                                  TextField(
                                    controller: medicineNameController,
                                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: titleColor),
                                    decoration: InputDecoration(
                                      hintText: 'e.g. Metformin, Aspirin, Blood Pressure...',
                                      hintStyle: TextStyle(fontSize: 13, color: subtitleColor),
                                      filled: true,
                                      fillColor: cardBg,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: cardBorder, width: 1.15)),
                                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: cardBorder, width: 1.15)),
                                      focusedBorder: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(14)), borderSide: BorderSide(color: Color(0xFF00796B), width: 1.6)),
                                    ),
                                  ),
                                  const SizedBox(height: 12),

                                  Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text('DOSE / QUANTITY', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: sectionHeaderColor)),
                                            const SizedBox(height: 6),
                                            TextField(
                                              controller: doseQuantityController,
                                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: titleColor),
                                              decoration: InputDecoration(
                                                hintText: 'e.g. 1 tablet, 5 ml',
                                                hintStyle: TextStyle(fontSize: 12.5, color: subtitleColor),
                                                filled: true,
                                                fillColor: cardBg,
                                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: cardBorder, width: 1.15)),
                                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: cardBorder, width: 1.15)),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text('MEAL TIMING', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: sectionHeaderColor)),
                                            const SizedBox(height: 6),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                                              decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: cardBorder, width: 1.15)),
                                              child: DropdownButtonHideUnderline(
                                                child: DropdownButton<MealTiming>(
                                                  value: selectedMealTiming,
                                                  isExpanded: true,
                                                  dropdownColor: isDark ? const Color(0xFF1B2B28) : Colors.white,
                                                  items: const [
                                                    DropdownMenuItem(value: MealTiming.afterMeal, child: Text('After Meal', style: TextStyle(fontSize: 12.5))),
                                                    DropdownMenuItem(value: MealTiming.beforeMeal, child: Text('Before Meal', style: TextStyle(fontSize: 12.5))),
                                                    DropdownMenuItem(value: MealTiming.withMeal, child: Text('With Meal', style: TextStyle(fontSize: 12.5))),
                                                    DropdownMenuItem(value: MealTiming.noMeal, child: Text('No Meal', style: TextStyle(fontSize: 12.5))),
                                                  ],
                                                  onChanged: (val) {
                                                    if (val != null) setSheetState(() => selectedMealTiming = val);
                                                  },
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),

                                  // Start Date & End Date Pickers
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text('START DATE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: sectionHeaderColor)),
                                            const SizedBox(height: 6),
                                            InkWell(
                                              onTap: () async {
                                                final picked = await showDatePicker(
                                                  context: sheetContext,
                                                  initialDate: medicineStartDate,
                                                  firstDate: DateTime.now().subtract(const Duration(days: 1)),
                                                  lastDate: DateTime.now().add(const Duration(days: 365)),
                                                );
                                                if (picked != null) setSheetState(() => medicineStartDate = picked);
                                              },
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                                decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: cardBorder, width: 1.15)),
                                                child: Row(
                                                  children: [
                                                    const Icon(Icons.calendar_today_rounded, size: 16, color: Color(0xFF00796B)),
                                                    const SizedBox(width: 8),
                                                    Expanded(
                                                      child: Text(
                                                        DateFormat('MMM d, yyyy').format(medicineStartDate),
                                                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: titleColor),
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text('END DATE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: sectionHeaderColor)),
                                            const SizedBox(height: 6),
                                            InkWell(
                                              onTap: () async {
                                                final picked = await showDatePicker(
                                                  context: sheetContext,
                                                  initialDate: medicineEndDate,
                                                  firstDate: medicineStartDate,
                                                  lastDate: DateTime.now().add(const Duration(days: 365)),
                                                );
                                                if (picked != null) setSheetState(() => medicineEndDate = picked);
                                              },
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                                decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: cardBorder, width: 1.15)),
                                                child: Row(
                                                  children: [
                                                    const Icon(Icons.event_available_rounded, size: 16, color: Color(0xFF00796B)),
                                                    const SizedBox(width: 8),
                                                    Expanded(
                                                      child: Text(
                                                        DateFormat('MMM d, yyyy').format(medicineEndDate),
                                                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: titleColor),
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),

                                  // Reminder Time & Repeat Gap
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text('REMINDER TIME', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: sectionHeaderColor)),
                                            const SizedBox(height: 6),
                                            InkWell(
                                              onTap: () async {
                                                final picked = await showTimePicker(
                                                  context: sheetContext,
                                                  initialTime: medicineReminderTime,
                                                );
                                                if (picked != null) setSheetState(() => medicineReminderTime = picked);
                                              },
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                                decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: cardBorder, width: 1.15)),
                                                child: Row(
                                                  children: [
                                                    const Icon(Icons.access_time_rounded, size: 16, color: Color(0xFF00796B)),
                                                    const SizedBox(width: 8),
                                                    Expanded(
                                                      child: Text(
                                                        medicineReminderTime.format(context),
                                                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: titleColor),
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text('REPEAT GAP', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: sectionHeaderColor)),
                                            const SizedBox(height: 6),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                                              decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: cardBorder, width: 1.15)),
                                              child: DropdownButtonHideUnderline(
                                                child: DropdownButton<int>(
                                                  value: medicineRepeatGapHours,
                                                  isExpanded: true,
                                                  dropdownColor: isDark ? const Color(0xFF1B2B28) : Colors.white,
                                                  items: const [
                                                    DropdownMenuItem(value: 4, child: Text('Every 4 hours', style: TextStyle(fontSize: 12.5))),
                                                    DropdownMenuItem(value: 6, child: Text('Every 6 hours', style: TextStyle(fontSize: 12.5))),
                                                    DropdownMenuItem(value: 8, child: Text('Every 8 hours', style: TextStyle(fontSize: 12.5))),
                                                    DropdownMenuItem(value: 12, child: Text('Every 12 hours', style: TextStyle(fontSize: 12.5))),
                                                    DropdownMenuItem(value: 24, child: Text('Every 24h (Daily)', style: TextStyle(fontSize: 12.5))),
                                                  ],
                                                  onChanged: (val) {
                                                    if (val != null) setSheetState(() => medicineRepeatGapHours = val);
                                                  },
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  ] else if (selectedMedicineSubType.contains('Doctor')) ...[
                                  // Doctor Appointment Form Fields
                                  Text(
                                    'DOCTOR NAME',
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: sectionHeaderColor),
                                  ),
                                  const SizedBox(height: 6),
                                  TextField(
                                    controller: doctorNameController,
                                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: titleColor),
                                    decoration: InputDecoration(
                                      hintText: 'e.g. Dr. Sarah Jenkins, Cardiologist',
                                      hintStyle: TextStyle(fontSize: 13, color: subtitleColor),
                                      filled: true,
                                      fillColor: cardBg,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: cardBorder, width: 1.15)),
                                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: cardBorder, width: 1.15)),
                                      focusedBorder: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(14)), borderSide: BorderSide(color: Color(0xFF00796B), width: 1.6)),
                                    ),
                                  ),
                                  const SizedBox(height: 12),

                                  Text(
                                    'HOSPITAL / CLINIC NAME',
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: sectionHeaderColor),
                                  ),
                                  const SizedBox(height: 6),
                                  TextField(
                                    controller: hospitalNameController,
                                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: titleColor),
                                    decoration: InputDecoration(
                                      hintText: 'e.g. City General Hospital, Room 304',
                                      hintStyle: TextStyle(fontSize: 13, color: subtitleColor),
                                      filled: true,
                                      fillColor: cardBg,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: cardBorder, width: 1.15)),
                                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: cardBorder, width: 1.15)),
                                      focusedBorder: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(14)), borderSide: BorderSide(color: Color(0xFF00796B), width: 1.6)),
                                    ),
                                  ),
                                  const SizedBox(height: 12),

                                  // Row: APPOINTMENT DATE & APPOINTMENT TIME
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text('APPOINTMENT DATE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: sectionHeaderColor)),
                                            const SizedBox(height: 6),
                                            InkWell(
                                              onTap: () async {
                                                final picked = await showDatePicker(
                                                  context: sheetContext,
                                                  initialDate: appointmentDate,
                                                  firstDate: DateTime.now().subtract(const Duration(days: 1)),
                                                  lastDate: DateTime.now().add(const Duration(days: 365)),
                                                );
                                                if (picked != null) setSheetState(() => appointmentDate = picked);
                                              },
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                                decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: cardBorder, width: 1.15)),
                                                child: Row(
                                                  children: [
                                                    const Icon(Icons.calendar_today_rounded, size: 16, color: Color(0xFF00796B)),
                                                    const SizedBox(width: 8),
                                                    Expanded(
                                                      child: Text(
                                                        DateFormat('MMM d, yyyy').format(appointmentDate),
                                                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: titleColor),
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text('APPOINTMENT TIME', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: sectionHeaderColor)),
                                            const SizedBox(height: 6),
                                            InkWell(
                                              onTap: () async {
                                                final picked = await showTimePicker(
                                                  context: sheetContext,
                                                  initialTime: appointmentTime,
                                                );
                                                if (picked != null) setSheetState(() => appointmentTime = picked);
                                              },
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                                decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: cardBorder, width: 1.15)),
                                                child: Row(
                                                  children: [
                                                    const Icon(Icons.access_time_rounded, size: 16, color: Color(0xFF00796B)),
                                                    const SizedBox(width: 8),
                                                    Expanded(
                                                      child: Text(
                                                        appointmentTime.format(context),
                                                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: titleColor),
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),

                                  Text(
                                    'OPTIONAL NOTES / DETAILS',
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: sectionHeaderColor),
                                  ),
                                  const SizedBox(height: 6),
                                  TextField(
                                    controller: appointmentNotesController,
                                    maxLines: 2,
                                    style: TextStyle(fontSize: 13, height: 1.4, color: titleColor),
                                    decoration: InputDecoration(
                                      hintText: 'e.g. Bring previous scan reports, fasting required...',
                                      hintStyle: TextStyle(fontSize: 12.5, color: subtitleColor),
                                      filled: true,
                                      fillColor: cardBg,
                                      contentPadding: const EdgeInsets.all(12),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: cardBorder, width: 1.15)),
                                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: cardBorder, width: 1.15)),
                                      focusedBorder: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(14)), borderSide: BorderSide(color: Color(0xFF00796B), width: 1.6)),
                                    ),
                                  ),
                                ],
                              ] else if (selectedReminderType == ReminderType.hydration) ...[
                                // Hydration Form Fields
                                Text(
                                  'WATER QUANTITY',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: sectionHeaderColor),
                                ),
                                const SizedBox(height: 6),
                                TextField(
                                  controller: waterQuantityController,
                                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: titleColor),
                                  decoration: InputDecoration(
                                    hintText: 'e.g. 250 ml, 1 glass, 500 ml',
                                    hintStyle: TextStyle(fontSize: 13, color: subtitleColor),
                                    filled: true,
                                    fillColor: cardBg,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: cardBorder, width: 1.15)),
                                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: cardBorder, width: 1.15)),
                                    focusedBorder: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(14)), borderSide: BorderSide(color: Color(0xFF00796B), width: 1.6)),
                                  ),
                                ),
                                const SizedBox(height: 12),

                                // Start Date & End Date Pickers
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('START DATE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: sectionHeaderColor)),
                                          const SizedBox(height: 6),
                                          InkWell(
                                            onTap: () async {
                                              final picked = await showDatePicker(
                                                context: sheetContext,
                                                initialDate: hydrationStartDate,
                                                firstDate: DateTime.now().subtract(const Duration(days: 1)),
                                                lastDate: DateTime.now().add(const Duration(days: 365)),
                                              );
                                              if (picked != null) setSheetState(() => hydrationStartDate = picked);
                                            },
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                              decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: cardBorder, width: 1.15)),
                                              child: Row(
                                                children: [
                                                  const Icon(Icons.calendar_today_rounded, size: 16, color: Color(0xFF0288D1)),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: Text(
                                                      DateFormat('MMM d, yyyy').format(hydrationStartDate),
                                                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: titleColor),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('END DATE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: sectionHeaderColor)),
                                          const SizedBox(height: 6),
                                          InkWell(
                                            onTap: () async {
                                              final picked = await showDatePicker(
                                                context: sheetContext,
                                                initialDate: hydrationEndDate,
                                                firstDate: hydrationStartDate,
                                                lastDate: DateTime.now().add(const Duration(days: 365)),
                                              );
                                              if (picked != null) setSheetState(() => hydrationEndDate = picked);
                                            },
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                              decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: cardBorder, width: 1.15)),
                                              child: Row(
                                                children: [
                                                  const Icon(Icons.event_available_rounded, size: 16, color: Color(0xFF0288D1)),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: Text(
                                                      DateFormat('MMM d, yyyy').format(hydrationEndDate),
                                                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: titleColor),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),

                                // First Reminder Time & Repeat Gap
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('FIRST REMINDER TIME', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: sectionHeaderColor)),
                                          const SizedBox(height: 6),
                                          InkWell(
                                            onTap: () async {
                                              final picked = await showTimePicker(
                                                context: sheetContext,
                                                initialTime: hydrationFirstReminderTime,
                                              );
                                              if (picked != null) setSheetState(() => hydrationFirstReminderTime = picked);
                                            },
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                              decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: cardBorder, width: 1.15)),
                                              child: Row(
                                                children: [
                                                  const Icon(Icons.access_time_rounded, size: 16, color: Color(0xFF0288D1)),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: Text(
                                                      hydrationFirstReminderTime.format(context),
                                                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: titleColor),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('REPEAT GAP', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: sectionHeaderColor)),
                                          const SizedBox(height: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                                            decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: cardBorder, width: 1.15)),
                                            child: DropdownButtonHideUnderline(
                                              child: DropdownButton<int>(
                                                value: hydrationRepeatGapHours,
                                                isExpanded: true,
                                                dropdownColor: isDark ? const Color(0xFF1B2B28) : Colors.white,
                                                items: const [
                                                  DropdownMenuItem(value: 1, child: Text('Every 1 hour', style: TextStyle(fontSize: 12.5))),
                                                  DropdownMenuItem(value: 2, child: Text('Every 2 hours', style: TextStyle(fontSize: 12.5))),
                                                  DropdownMenuItem(value: 3, child: Text('Every 3 hours', style: TextStyle(fontSize: 12.5))),
                                                  DropdownMenuItem(value: 4, child: Text('Every 4 hours', style: TextStyle(fontSize: 12.5))),
                                                ],
                                                onChanged: (val) {
                                                  if (val != null) setSheetState(() => hydrationRepeatGapHours = val);
                                                },
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              const SizedBox(height: 16),

                              // Send Notification / Schedule Reminder Primary CTA Button
                              Container(
                                width: double.infinity,
                                height: 52,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  gradient: isSending || selectedPatientIds.isEmpty
                                      ? null
                                      : const LinearGradient(
                                          colors: [Color(0xFF00897B), Color(0xFF004D40)],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                  boxShadow: isSending || selectedPatientIds.isEmpty
                                      ? null
                                      : [
                                          BoxShadow(
                                            color: const Color(0xFF00796B).withValues(alpha: 0.35),
                                            blurRadius: 14,
                                            offset: const Offset(0, 5),
                                          ),
                                        ],
                                ),
                                child: ElevatedButton.icon(
                                  onPressed: isSending
                                      ? null
                                      : () async {
                                          if (selectedPatientIds.isEmpty) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(
                                                content: Text('Please select at least one patient to notify.'),
                                                backgroundColor: Color(0xFFE65100),
                                              ),
                                            );
                                            return;
                                          }

                                          setSheetState(() => isSending = true);

                                          try {
                                            final user = FirebaseAuth.instance.currentUser;
                                            final cgUid = user?.uid ?? 'caregiver';
                                            final cgName = user?.displayName ?? 'Your Caregiver';

                                            if (selectedReminderType == ReminderType.dailyActivity) {
                                              final finalTitle = selectedTitle == '✏️ Custom Reminder...'
                                                  ? (customTitleController.text.trim().isNotEmpty
                                                      ? customTitleController.text.trim()
                                                      : 'Caregiver Reminder')
                                                  : selectedTitle;

                                              final finalBody = messageController.text.trim().isNotEmpty
                                                  ? messageController.text.trim()
                                                  : 'Please complete your daily cognitive exercises.';

                                              for (final pid in selectedPatientIds) {
                                                await FirebaseFirestore.instance
                                                    .collection('users')
                                                    .doc(pid)
                                                    .collection('notifications')
                                                    .add({
                                                  'title': finalTitle,
                                                  'body': finalBody,
                                                  'senderName': cgName,
                                                  'senderId': cgUid,
                                                  'senderRole': 'caregiver',
                                                  'type': 'game_reminder',
                                                  'isHighPriority': isHighPriority,
                                                  'isRead': false,
                                                  'createdAt': FieldValue.serverTimestamp(),
                                                });
                                              }
                                            } else if (selectedReminderType == ReminderType.medicine) {
                                              if (selectedMedicineSubType.contains('Doctor')) {
                                                final docName = doctorNameController.text.trim().isNotEmpty
                                                    ? doctorNameController.text.trim()
                                                    : 'Doctor';
                                                final hospName = hospitalNameController.text.trim().isNotEmpty
                                                    ? hospitalNameController.text.trim()
                                                    : 'Hospital / Clinic';
                                                final notes = appointmentNotesController.text.trim();

                                                final apptDt = DateTime(
                                                  appointmentDate.year,
                                                  appointmentDate.month,
                                                  appointmentDate.day,
                                                  appointmentTime.hour,
                                                  appointmentTime.minute,
                                                );

                                                final formattedDate = DateFormat('EEE, MMM d, yyyy').format(apptDt);
                                                final formattedTime = appointmentTime.format(sheetContext);
                                                final bodyText = 'Appointment with $docName at $hospName on $formattedDate at $formattedTime.${notes.isNotEmpty ? '\nNotes: $notes' : ''}';

                                                for (final pid in selectedPatientIds) {
                                                  final docRef = await FirebaseFirestore.instance
                                                      .collection('users')
                                                      .doc(pid)
                                                      .collection('notifications')
                                                      .add({
                                                    'title': 'Doctor Appointment: $docName',
                                                    'body': bodyText,
                                                    'doctorName': docName,
                                                    'hospitalName': hospName,
                                                    'appointmentDate': appointmentDate.toIso8601String(),
                                                    'appointmentTime': '${appointmentTime.hour}:${appointmentTime.minute}',
                                                    'appointmentDateTime': apptDt.toIso8601String(),
                                                    'notes': notes,
                                                    'senderName': cgName,
                                                    'senderId': cgUid,
                                                    'senderRole': 'caregiver',
                                                    'type': 'doctor_appointment',
                                                    'isHighPriority': true,
                                                    'isRead': false,
                                                    'createdAt': FieldValue.serverTimestamp(),
                                                  });

                                                  // One-time exact reminder alarm at the appointment date/time
                                                  final int notifId = (docRef.id.hashCode ^ apptDt.millisecondsSinceEpoch).abs() % 100000000;
                                                  await NotificationService().scheduleExactAlarm(
                                                    id: notifId,
                                                    title: 'Doctor Appointment: $docName 🩺',
                                                    body: 'Appointment at $hospName at $formattedTime.',
                                                    scheduledDate: apptDt,
                                                    payload: 'appointment:${docRef.id}',
                                                  );
                                                }
                                              } else {
                                                final medName = medicineNameController.text.trim().isNotEmpty
                                                    ? medicineNameController.text.trim()
                                                    : 'Prescribed Medicine';

                                                final startDt = DateTime(
                                                  medicineStartDate.year,
                                                  medicineStartDate.month,
                                                  medicineStartDate.day,
                                                  medicineReminderTime.hour,
                                                  medicineReminderTime.minute,
                                                );
                                                final endDt = DateTime(
                                                  medicineEndDate.year,
                                                  medicineEndDate.month,
                                                  medicineEndDate.day,
                                                  23,
                                                  59,
                                                  59,
                                                );

                                                for (final pid in selectedPatientIds) {
                                                  final reminderId = const Uuid().v4();
                                                  final reminder = ReminderModel(
                                                    id: reminderId,
                                                    patientId: pid,
                                                    caregiverId: cgUid,
                                                    caregiverName: cgName,
                                                    type: ReminderType.medicine,
                                                    title: medName,
                                                    medicineName: medName,
                                                    doseQuantity: doseQuantityController.text.trim().isNotEmpty
                                                        ? doseQuantityController.text.trim()
                                                        : '1 dose',
                                                    mealTiming: selectedMealTiming,
                                                    startDateTime: startDt,
                                                    endDateTime: endDt,
                                                    repeatGapHours: medicineRepeatGapHours,
                                                    isActive: true,
                                                    createdAt: DateTime.now(),
                                                  );
                                                  await ReminderService().saveReminder(reminder);
                                                }
                                              }
                                            } else if (selectedReminderType == ReminderType.hydration) {
                                              final startDt = DateTime(
                                                hydrationStartDate.year,
                                                hydrationStartDate.month,
                                                hydrationStartDate.day,
                                                hydrationFirstReminderTime.hour,
                                                hydrationFirstReminderTime.minute,
                                              );
                                              final endDt = DateTime(
                                                hydrationEndDate.year,
                                                hydrationEndDate.month,
                                                hydrationEndDate.day,
                                                23,
                                                59,
                                                59,
                                              );

                                              for (final pid in selectedPatientIds) {
                                                final reminderId = const Uuid().v4();
                                                final reminder = ReminderModel(
                                                  id: reminderId,
                                                  patientId: pid,
                                                  caregiverId: cgUid,
                                                  caregiverName: cgName,
                                                  type: ReminderType.hydration,
                                                  title: 'Hydration Reminder',
                                                  waterQuantity: waterQuantityController.text.trim().isNotEmpty
                                                      ? waterQuantityController.text.trim()
                                                      : '250 ml',
                                                  startDateTime: startDt,
                                                  endDateTime: endDt,
                                                  repeatGapHours: hydrationRepeatGapHours,
                                                  isActive: true,
                                                  createdAt: DateTime.now(),
                                                );
                                                await ReminderService().saveReminder(reminder);
                                              }
                                            }

                                            if (sheetContext.mounted) {
                                              Navigator.pop(sheetContext);
                                            }

                                            if (mounted) {
                                              _showNotificationSuccessDialog(context, selectedPatientIds.length);
                                            }
                                          } catch (e) {
                                            setSheetState(() => isSending = false);
                                            if (mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(
                                                  content: Text('Failed to save reminder: $e'),
                                                  backgroundColor: Colors.redAccent,
                                                ),
                                              );
                                            }
                                          }
                                        },
                                  icon: isSending
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.2,
                                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                          ),
                                        )
                                      : const Icon(Icons.send_rounded, size: 19, color: Colors.white),
                                  label: Text(
                                    isSending
                                        ? 'Saving Schedule...'
                                        : (selectedReminderType == ReminderType.dailyActivity
                                            ? 'Send Notification (${selectedPatientIds.length})'
                                            : (selectedReminderType == ReminderType.medicine
                                                ? (selectedMedicineSubType.contains('Doctor')
                                                    ? 'Schedule Doctor Appointment (${selectedPatientIds.length})'
                                                    : 'Schedule Medicine (${selectedPatientIds.length})')
                                                : 'Schedule Hydration (${selectedPatientIds.length})')),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14.5,
                                      letterSpacing: 0.2,
                                      color: Colors.white,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: selectedPatientIds.isEmpty
                                        ? (isDark ? const Color(0xFF263D38) : const Color(0xFF80CBC4))
                                        : (isSending ? const Color(0xFF00796B) : Colors.transparent),
                                    disabledBackgroundColor: isDark ? const Color(0xFF263D38) : const Color(0xFF80CBC4),
                                    disabledForegroundColor: Colors.white70,
                                    shadowColor: Colors.transparent,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showNotificationSuccessDialog(BuildContext parentContext, int count) {
    bool isClosed = false;
    Timer? autoRedirectTimer;

    showDialog(
      context: parentContext,
      barrierDismissible: true,
      builder: (dialogCtx) {
        final isDark = Theme.of(dialogCtx).brightness == Brightness.dark;

        autoRedirectTimer = Timer(const Duration(milliseconds: 2400), () {
          if (!isClosed && dialogCtx.mounted) {
            isClosed = true;
            Navigator.of(dialogCtx).pop();
            if (mounted) {
              _switchTab(0);
            }
          }
        });

        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 32),
          child: Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1B2425) : Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: const Color(0xFF00796B).withValues(alpha: isDark ? 0.4 : 0.25),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.15),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(
                  alignment: Alignment.topRight,
                  child: InkWell(
                    onTap: () {
                      if (!isClosed) {
                        isClosed = true;
                        autoRedirectTimer?.cancel();
                        Navigator.of(dialogCtx).pop();
                        if (mounted) {
                          _switchTab(0);
                        }
                      }
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white10 : Colors.grey.shade100,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: isDark ? Colors.white70 : Colors.black54,
                      ),
                    ),
                  ),
                ),
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: const Color(0xFF00796B).withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF00796B).withValues(alpha: 0.35),
                      width: 2,
                    ),
                  ),
                  child: const Icon(
                    Icons.check_circle_rounded,
                    color: Color(0xFF00796B),
                    size: 38,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Sent Successfully!',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF1B3B36),
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Your reminder has been sent to $count connected patient${count == 1 ? '' : 's'}.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13.5,
                    color: isDark ? Colors.white70 : Colors.grey.shade700,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00796B).withValues(alpha: isDark ? 0.2 : 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00796B)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Redirecting to Home...',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? const Color(0xFF80CBC4) : const Color(0xFF00796B),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ).then((_) {
      isClosed = true;
      autoRedirectTimer?.cancel();
    });
  }

  Widget _buildRecentSessionsTimeline(List<String> patients) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (patients.isEmpty) {
      return const SizedBox.shrink();
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: patients.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final pid = patients[index];
        final isExpanded = _expandedPatientIds.contains(pid);

        if (widget.initialPatients != null) {
          final mockP = widget.mockPatientDetails?[pid];
          final name = mockP?['name'] ?? 'Patient ${index + 1}';
          final connectCode = mockP?['shareCode'] ?? mockP?['connectCode'] ?? '';
          return _buildPatientTimelineCard(
            pid: pid,
            index: index,
            name: name,
            connectCode: connectCode,
            isDark: isDark,
            isExpanded: isExpanded,
          );
        }

        return FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance.collection('users').doc(pid).get(),
          builder: (context, snapshot) {
            final data = snapshot.data?.data() as Map<String, dynamic>?;
            final name = data?['name'] ?? 'Patient ${index + 1}';
            final connectCode = data?['connectCode'] ?? '';

            return _buildPatientTimelineCard(
              pid: pid,
              index: index,
              name: name,
              connectCode: connectCode,
              isDark: isDark,
              isExpanded: isExpanded,
            );
          },
        );
      },
    );
  }

  Widget _buildPatientTimelineCard({
    required String pid,
    required int index,
    required String name,
    required String connectCode,
    required bool isDark,
    required bool isExpanded,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isExpanded
              ? const Color(0xFF00796B)
              : (isDark ? Colors.white12 : Colors.grey.shade200),
          width: isExpanded ? 1.8 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: isExpanded
                ? const Color(0xFF00796B).withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.03),
            blurRadius: isExpanded ? 10 : 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Clickable Patient Card Header (Dropdown Trigger)
          InkWell(
            onTap: () {
              setState(() {
                if (isExpanded) {
                  _expandedPatientIds.remove(pid);
                } else {
                  _expandedPatientIds.add(pid);
                }
              });
            },
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: const Color(0xFF00796B).withValues(alpha: 0.12),
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : 'P',
                      style: const TextStyle(
                        color: Color(0xFF00796B),
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                name,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (connectCode.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF00796B).withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '#$connectCode',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF00796B),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          isExpanded ? 'Showing recent cognitive tasks' : 'Tap to view recent cognitive tasks',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: isExpanded ? const Color(0xFF00796B) : (isDark ? Colors.white54 : Colors.grey.shade600),
                            fontWeight: isExpanded ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  AnimatedRotation(
                    duration: const Duration(milliseconds: 200),
                    turns: isExpanded ? 0.5 : 0.0,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: isExpanded
                            ? const Color(0xFF00796B).withValues(alpha: 0.12)
                            : (isDark ? Colors.white10 : Colors.grey.shade100),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 20,
                        color: isExpanded ? const Color(0xFF00796B) : Colors.grey,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 2. Dropdown Content (Patient's Real-time Cognitive Sessions)
          if (isExpanded) ...[
            const Divider(height: 1, thickness: 1),
            Padding(
              padding: const EdgeInsets.all(14.0),
              child: widget.initialPatients != null
                  ? _buildSessionsListFromData(
                      isDark: isDark,
                      name: name,
                      sessions: widget.mockSessions?[pid] ?? [],
                    )
                  : StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('users')
                          .doc(pid)
                          .collection('game_sessions')
                          .orderBy('timestamp', descending: true)
                          .limit(6)
                          .snapshots(),
                      builder: (context, sessionSnap) {
                        if (sessionSnap.connectionState == ConnectionState.waiting) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(16.0),
                              child: SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFF00796B)),
                              ),
                            ),
                          );
                        }

                        final docs = sessionSnap.data?.docs ?? [];
                        final sessionMaps = docs.map((d) => d.data() as Map<String, dynamic>).toList();
                        return _buildSessionsListFromData(
                          isDark: isDark,
                          name: name,
                          sessions: sessionMaps,
                        );
                      },
                    ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSessionsListFromData({
    required bool isDark,
    required String name,
    required List<Map<String, dynamic>> sessions,
  }) {
    if (sessions.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 14.0, horizontal: 8.0),
        child: Column(
          children: [
            Icon(Icons.history_toggle_off_rounded, size: 36, color: isDark ? Colors.white38 : Colors.grey.shade400),
            const SizedBox(height: 8),
            Text(
              'No Sessions Recorded Yet',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'When $name completes brain exercises, their tasks and scores will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: sessions.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final data = sessions[index];
        final gameId = data['gameId'] ?? 'game';
        final accuracy = (data['accuracyPercentage'] as num?)?.toInt() ?? 0;
        final level = (data['difficultyLevel'] as num?)?.toInt() ?? 1;
        final durationSec = (data['completionTimeSeconds'] as num?)?.toInt() ?? 0;
        final dateStr = _formatSessionTimestamp(data['timestamp']);

        GameHubVisual? visual;
        IconData fallbackIcon;
        String gameTitle;
        Color accentColor;
        Color cardBg;
        Color borderColor;

        if (gameId == 'face_recall') {
          visual = GameHubVisual.faceRecall;
          fallbackIcon = Icons.family_restroom_rounded;
          gameTitle = 'Face Recall';
          accentColor = const Color(0xFFD97706);
          cardBg = const Color(0xFFFFFBEB);
          borderColor = const Color(0xFFFDE68A);
        } else if (gameId == 'memory_match') {
          visual = GameHubVisual.memoryMatch;
          fallbackIcon = Icons.psychology_rounded;
          gameTitle = 'Memory Match';
          accentColor = const Color(0xFFD81B60);
          cardBg = const Color(0xFFFFF5F7);
          borderColor = const Color(0xFFFED7E2);
        } else if (gameId == 'pattern_path') {
          visual = GameHubVisual.patternPath;
          fallbackIcon = Icons.extension_rounded;
          gameTitle = 'Pattern Path';
          accentColor = const Color(0xFF16A34A);
          cardBg = const Color(0xFFF0FDF4);
          borderColor = const Color(0xFFBBF7D0);
        } else if (gameId == 'memory_recall') {
          visual = GameHubVisual.memoryRecall;
          fallbackIcon = Icons.history_edu_rounded;
          gameTitle = 'Memory Recall';
          accentColor = const Color(0xFF2563EB);
          cardBg = const Color(0xFFF0F4F8);
          borderColor = const Color(0xFFD1E2EE);
        } else {
          visual = null;
          fallbackIcon = Icons.sports_esports_rounded;
          gameTitle = (data['gameCategory'] ?? 'Cognitive Task').toString();
          accentColor = const Color(0xFF00796B);
          cardBg = const Color(0xFFE0F2F1);
          borderColor = const Color(0xFFB2DFDB);
        }

        Color accTextColor;
        Color accBgColor;
        if (accuracy >= 80) {
          accTextColor = const Color(0xFF2E7D32);
          accBgColor = isDark ? const Color(0xFF1B2E24) : const Color(0xFFE8F5E9);
        } else if (accuracy >= 50) {
          accTextColor = const Color(0xFFE65100);
          accBgColor = isDark ? const Color(0xFF2E1F12) : const Color(0xFFFFF3E0);
        } else {
          accTextColor = const Color(0xFFC62828);
          accBgColor = isDark ? const Color(0xFF2E1416) : const Color(0xFFFFEBEE);
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF232B2B) : const Color(0xFFF8FAF9),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? Colors.white10 : const Color(0xFFE8EEEC),
            ),
          ),
          child: Row(
            children: [
              // Game Visual Container (Exact Patient UI identity)
              Container(
                width: 44,
                height: 44,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF263238) : cardBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? Colors.white12 : borderColor,
                    width: 1.2,
                  ),
                ),
                child: Center(
                  child: visual != null
                      ? GameHubIllustration(visual: visual, size: 36)
                      : Icon(fallbackIcon, color: accentColor, size: 22),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          gameTitle,
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: accBgColor,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '$accuracy%',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: accTextColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Text(
                          'Level $level',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white70 : Colors.grey.shade700,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text('•', style: TextStyle(color: Colors.grey.shade400, fontSize: 10)),
                        const SizedBox(width: 5),
                        Text(
                          '${durationSec}s',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.white60 : Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            dateStr,
                            textAlign: TextAlign.end,
                            style: TextStyle(
                              fontSize: 10.5,
                              color: isDark ? Colors.white38 : Colors.grey.shade500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCaregiverStatCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    String? badge,
    VoidCallback? onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmall = screenWidth < 360;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: EdgeInsets.all(isSmall ? 10.0 : 13.0),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
              width: 1.1,
            ),
            boxShadow: isDark
                ? null
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: EdgeInsets.all(isSmall ? 6 : 7),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: isDark ? 0.22 : 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: color, size: isSmall ? 17 : 19),
                  ),
                  if (badge != null)
                    Flexible(
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: isSmall ? 5 : 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: isDark ? 0.18 : 0.10),
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: Text(
                          badge,
                          style: TextStyle(
                            fontSize: isSmall ? 9.5 : 10.5,
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                ],
              ),
              SizedBox(height: isSmall ? 7 : 9),
              Text(
                title,
                style: TextStyle(
                  fontSize: isSmall ? 11 : 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white70 : const Color(0xFF2C3E50),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: isSmall ? 17 : (screenWidth < 380 ? 19 : 21),
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF1B3B36),
                  letterSpacing: -0.3,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 3),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: isSmall ? 9.5 : 10.5,
                        color: isDark ? Colors.white54 : Colors.grey.shade600,
                        fontWeight: FontWeight.normal,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (onTap != null) ...[
                    const SizedBox(width: 3),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: isSmall ? 12 : 14,
                      color: isDark ? Colors.white38 : Colors.grey.shade400,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLinkedPatientsSheet(List<String> patients) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);
    final screenHeight = MediaQuery.of(context).size.height;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: isDark
                ? null
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.10),
                      blurRadius: 20,
                      offset: const Offset(0, -4),
                    ),
                  ],
          ),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          constraints: BoxConstraints(
            maxHeight: screenHeight * 0.75,
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Drag Handle
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Title Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00796B).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.people_alt_rounded, color: Color(0xFF00796B), size: 18),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Linked Patients',
                          style: TextStyle(
                            fontSize: 16.5,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF1B3B36),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00796B).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${patients.length} Active',
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF00796B),
                            ),
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      icon: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white10 : Colors.grey.shade100,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.close_rounded, size: 16, color: isDark ? Colors.white70 : Colors.grey.shade700),
                      ),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Divider(height: 1, color: isDark ? Colors.white12 : Colors.grey.shade200),
                const SizedBox(height: 10),

                // Content: If Empty or List
                Expanded(
                  child: patients.isEmpty
                      ? Center(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF00796B).withValues(alpha: 0.08),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.person_add_alt_1_rounded,
                                    size: 32,
                                    color: Color(0xFF00796B),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'No Linked Patients Yet',
                                  style: TextStyle(
                                    fontSize: 15.5,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : const Color(0xFF1B3B36),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Connect a patient using their 6-character Connect Code to view real-time cognitive activity and health updates.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? Colors.white60 : Colors.grey.shade600,
                                    height: 1.35,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton.icon(
                                  onPressed: () {
                                    Navigator.pop(ctx);
                                    _showAddPatientDialog();
                                  },
                                  icon: const Icon(Icons.add_link_rounded, size: 16),
                                  label: const Text('Connect Patient Now', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF00796B),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    elevation: 0,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      itemCount: patients.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final patientId = patients[index];
                        final mockData = widget.mockPatientDetails?[patientId];
                        if (mockData != null) {
                          return _buildPatientCardFromData(
                            context: context,
                            ctx: ctx,
                            index: index,
                            isDark: isDark,
                            name: mockData['name'] ?? 'Patient ${index + 1}',
                            code: mockData['shareCode'] ?? 'N/A',
                            age: mockData['age']?.toString() ?? '',
                            gender: mockData['gender'] ?? '',
                          );
                        }

                        return FutureBuilder<DocumentSnapshot>(
                          future: FirebaseFirestore.instance.collection('users').doc(patientId).get(),
                          builder: (context, snap) {
                            if (!snap.hasData) {
                              return Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF232B2B) : Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Center(
                                  child: SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00796B)),
                                  ),
                                ),
                              );
                            }

                            final data = snap.data?.data() as Map<String, dynamic>?;
                            final name = data?['name'] ?? 'Patient ${index + 1}';
                            final code = data?['shareCode'] ?? 'N/A';
                            final age = data?['age'] ?? '';
                            final gender = data?['gender'] ?? '';

                            return _buildPatientCardFromData(
                              context: context,
                              ctx: ctx,
                              index: index,
                              isDark: isDark,
                              name: name,
                              code: code,
                              age: age.toString(),
                              gender: gender.toString(),
                            );
                          },
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPatientCardFromData({
    required BuildContext context,
    required BuildContext ctx,
    required int index,
    required bool isDark,
    required String name,
    required String code,
    required String age,
    required String gender,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF232B2B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white12 : const Color(0xFFE0F2F1),
          width: 1.1,
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: const Color(0xFF00796B).withValues(alpha: 0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Row(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: const Color(0xFF00796B),
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : 'P',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
                ),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: const Color(0xFF4CAF50),
                    shape: BoxShape.circle,
                    border: Border.all(color: isDark ? const Color(0xFF232B2B) : Colors.white, width: 1.5),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: isDark ? Colors.white : const Color(0xFF1B3B36),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1B2E24) : const Color(0xFFE8F5E9),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        'Active',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: isDark ? const Color(0xFF81C784) : const Color(0xFF2E7D32),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00796B).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        'Code: $code',
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF00796B)),
                      ),
                    ),
                    if (age.isNotEmpty || gender.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          '${age.isNotEmpty ? "$age yrs" : ""}${age.isNotEmpty && gender.isNotEmpty ? " • " : ""}${gender.isNotEmpty ? gender : ""}',
                          style: TextStyle(
                            fontSize: 10.5,
                            color: isDark ? Colors.white54 : Colors.grey.shade600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _switchTab(1);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00796B),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('View ›', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(dynamic ts) {
    final dt = _parseDateTime(ts);
    if (dt == null) return 'Just now';
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  void _showSentRequestsSheet() {
    String? uid;
    if (widget.initialPatients != null) {
      uid = 'test_caregiver_uid';
    } else {
      try {
        uid = FirebaseAuth.instance.currentUser?.uid;
      } catch (_) {
        uid = null;
      }
    }
    if (uid == null) return;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);
    final screenHeight = MediaQuery.of(context).size.height;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: isDark
                ? null
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.10),
                      blurRadius: 20,
                      offset: const Offset(0, -4),
                    ),
                  ],
          ),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          constraints: BoxConstraints(
            maxHeight: screenHeight * 0.75,
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE65100).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.pending_actions_rounded, color: Color(0xFFE65100), size: 18),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Pending Requests',
                          style: TextStyle(
                            fontSize: 16.5,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF1B3B36),
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      icon: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white10 : Colors.grey.shade100,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.close_rounded, size: 16, color: isDark ? Colors.white70 : Colors.grey.shade700),
                      ),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Divider(height: 1, color: isDark ? Colors.white12 : Colors.grey.shade200),
                const SizedBox(height: 10),
                Expanded(
                  child: widget.mockRequests != null
                      ? _buildRequestsListFromData(
                          ctx: ctx,
                          isDark: isDark,
                          items: widget.mockRequests!,
                        )
                      : StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('link_requests')
                              .where('caregiverId', isEqualTo: uid)
                              .snapshots(),
                          builder: (context, snap) {
                            if (snap.connectionState == ConnectionState.waiting) {
                              return const Center(child: CircularProgressIndicator(color: Color(0xFF00796B)));
                            }

                            final docs = snap.data?.docs ?? [];
                            final items = docs.map((d) {
                              final m = Map<String, dynamic>.from(d.data() as Map<String, dynamic>);
                              m['id'] = d.id;
                              return m;
                            }).toList();

                            return _buildRequestsListFromData(
                              ctx: ctx,
                              isDark: isDark,
                              items: items,
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRequestsListFromData({
    required BuildContext ctx,
    required bool isDark,
    required List<Map<String, dynamic>> items,
  }) {
    if (items.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFE65100).withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.mail_outline_rounded, size: 32, color: Color(0xFFE65100)),
              ),
              const SizedBox(height: 12),
              Text(
                'No Requests Sent Yet',
                style: TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF1B3B36),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'When you send a connection request to a patient using their Connect Code, it will appear here with its real-time status.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white60 : Colors.grey.shade600,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  _showAddPatientDialog();
                },
                icon: const Icon(Icons.person_add_alt_1_rounded, size: 16),
                label: const Text('Send Connection Request', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00796B),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final sortedDocs = List<Map<String, dynamic>>.from(items);
    sortedDocs.sort((a, b) {
      bool isCritical(Map<String, dynamic> doc) {
        final t = (doc['type'] ?? '').toString().toLowerCase();
        final title = (doc['title'] ?? '').toString().toLowerCase();
        final sev = (doc['severity'] ?? '').toString().toLowerCase();
        return sev == 'critical' || t.contains('sos') || t.contains('emergency') || title.contains('sos') || title.contains('emergency') || title.contains('🚨');
      }

      final critA = isCritical(a);
      final critB = isCritical(b);
      if (critA != critB) {
        return critA ? -1 : 1; // Critical alerts/notifications on top
      }

      final aTime = _parseDateTime(a['timestamp']);
      final bTime = _parseDateTime(b['timestamp']);
      if (aTime == null && bTime == null) return 0;
      if (aTime == null) return 1;
      if (bTime == null) return -1;
      return bTime.compareTo(aTime);
    });

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: sortedDocs.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final data = sortedDocs[index];
        final docId = data['id']?.toString() ?? '';
        final status = (data['status'] ?? 'pending').toString().toLowerCase();
        final patientId = data['patientId']?.toString() ?? '';
        final fallbackName = data['patientName'] ?? 'Patient';
        final code = data['shareCode'] ?? 'N/A';
        final dateStr = _formatTimestamp(data['timestamp']);

        Color badgeBg;
        Color badgeFg;
        String statusLabel;
        IconData statusIcon;

        if (status == 'accepted') {
          badgeBg = isDark ? const Color(0xFF1B2E24) : const Color(0xFFE8F5E9);
          badgeFg = isDark ? const Color(0xFF81C784) : const Color(0xFF2E7D32);
          statusLabel = 'Accepted ✅';
          statusIcon = Icons.check_circle_rounded;
        } else if (status == 'rejected') {
          badgeBg = isDark ? const Color(0xFF2E1416) : const Color(0xFFFFEBEE);
          badgeFg = isDark ? const Color(0xFFEF9A9A) : const Color(0xFFC62828);
          statusLabel = 'Declined ❌';
          statusIcon = Icons.cancel_rounded;
        } else {
          badgeBg = isDark ? const Color(0xFF2E1F12) : const Color(0xFFFFF3E0);
          badgeFg = isDark ? const Color(0xFFFFB74D) : const Color(0xFFE65100);
          statusLabel = 'Pending ⏳';
          statusIcon = Icons.hourglass_top_rounded;
        }

        final mockP = widget.mockPatientDetails?[patientId];
        if (mockP != null || data['patientDetails'] != null) {
          final pData = mockP ?? (data['patientDetails'] as Map<String, dynamic>);
          return _buildRequestCard(
            context: context,
            isDark: isDark,
            docId: docId,
            status: status,
            patientName: pData['name'] ?? fallbackName,
            code: code,
            age: pData['age']?.toString() ?? '',
            gender: pData['gender']?.toString() ?? '',
            language: pData['language']?.toString() ?? '',
            dateStr: dateStr,
            badgeBg: badgeBg,
            badgeFg: badgeFg,
            statusLabel: statusLabel,
            statusIcon: statusIcon,
          );
        }

        return FutureBuilder<DocumentSnapshot>(
          future: patientId.isNotEmpty
              ? FirebaseFirestore.instance.collection('users').doc(patientId).get()
              : null,
          builder: (context, patientSnap) {
            final pData = patientSnap.data?.data() as Map<String, dynamic>?;
            final patientName = pData?['name'] ?? fallbackName;
            final age = pData?['age']?.toString() ?? '';
            final gender = pData?['gender']?.toString() ?? '';
            final language = pData?['language']?.toString() ?? '';

            return _buildRequestCard(
              context: context,
              isDark: isDark,
              docId: docId,
              status: status,
              patientName: patientName,
              code: code,
              age: age,
              gender: gender,
              language: language,
              dateStr: dateStr,
              badgeBg: badgeBg,
              badgeFg: badgeFg,
              statusLabel: statusLabel,
              statusIcon: statusIcon,
            );
          },
        );
      },
    );
  }

  Widget _buildRequestCard({
    required BuildContext context,
    required bool isDark,
    required String docId,
    required String status,
    required String patientName,
    required String code,
    required String age,
    required String gender,
    required String language,
    required String dateStr,
    required Color badgeBg,
    required Color badgeFg,
    required String statusLabel,
    required IconData statusIcon,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF232B2B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white12 : const Color(0xFFE0F2F1),
          width: 1.1,
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: const Color(0xFF00796B).withValues(alpha: 0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 17,
                      backgroundColor: const Color(0xFF00796B),
                      child: Text(
                        patientName.isNotEmpty ? patientName[0].toUpperCase() : 'P',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        patientName,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: isDark ? Colors.white : const Color(0xFF1B3B36),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, size: 11, color: badgeFg),
                    const SizedBox(width: 3.5),
                    Text(
                      statusLabel,
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: badgeFg),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Wrap(
            spacing: 5,
            runSpacing: 4,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                decoration: BoxDecoration(
                  color: const Color(0xFF00796B).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  'Code: $code',
                  style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF00796B)),
                ),
              ),
              if (age.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white10 : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    '$age yrs',
                    style: TextStyle(fontSize: 10.5, color: isDark ? Colors.white70 : Colors.grey.shade700),
                  ),
                ),
              if (gender.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white10 : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    gender,
                    style: TextStyle(fontSize: 10.5, color: isDark ? Colors.white70 : Colors.grey.shade700),
                  ),
                ),
              if (language.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white10 : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    language,
                    style: TextStyle(fontSize: 10.5, color: isDark ? Colors.white70 : Colors.grey.shade700),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 7),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.access_time_rounded, size: 11, color: isDark ? Colors.white38 : Colors.grey.shade500),
                  const SizedBox(width: 4),
                  Text(
                    'Sent $dateStr',
                    style: TextStyle(fontSize: 10.5, color: isDark ? Colors.white38 : Colors.grey.shade500),
                  ),
                ],
              ),
              if (status == 'pending')
                InkWell(
                  onTap: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (c) => AlertDialog(
                        title: const Text('Cancel Request?'),
                        content: Text('Do you want to cancel the connection request sent to $patientName?'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('No')),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(c, true),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                            child: const Text('Cancel Request'),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true && docId.isNotEmpty) {
                      await FirebaseFirestore.instance.collection('link_requests').doc(docId).delete();
                    }
                  },
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.red.shade900.withValues(alpha: 0.25) : Colors.red.shade50,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.close_rounded, size: 12, color: isDark ? Colors.red.shade300 : Colors.red.shade700),
                        const SizedBox(width: 3),
                        Text(
                          'Cancel',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.red.shade300 : Colors.red.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsSectionHeader(String title, Color subtitleColor) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 6, top: 2),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: subtitleColor,
        ),
      ),
    );
  }

  Widget _buildSettingsCardGroup({
    required Color cardBg,
    required Color cardBorder,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder, width: 1.1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: children,
        ),
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required String title,
    String? subtitle,
    required Color titleColor,
    required Color subtitleColor,
    Widget? trailing,
    VoidCallback? onTap,
    EdgeInsetsGeometry? contentPadding,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: contentPadding ?? const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: titleColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: subtitleColor,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 8),
                trailing,
              ],
            ],
          ),
        ),
      ),
    );
  }


  void _openSettingsSheet() {
    User? user;
    try {
      user = FirebaseAuth.instance.currentUser;
    } catch (_) {
      user = null;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final provider = context.watch<AppProvider>();
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final mediaQuery = MediaQuery.of(ctx);
            final screenHeight = mediaQuery.size.height;
            final screenWidth = mediaQuery.size.width;
            final viewInsetsBottom = mediaQuery.viewInsets.bottom;
            final viewPaddingBottom = mediaQuery.viewPadding.bottom;
            final isSmall = screenWidth < 360;

            const primaryColor = Color(0xFF00796B);
            final titleColor = isDark ? Colors.white : const Color(0xFF1B3B36);
            final subtitleColor = isDark ? Colors.white60 : const Color(0xFF4A6B63);
            final sheetBg = isDark ? const Color(0xFF182220) : Colors.white;
            final cardBg = isDark ? const Color(0xFF141C1A) : const Color(0xFFF7FAF9);
            final cardBorder = isDark ? const Color(0xFF2B3A36) : const Color(0xFFE2ECE8);
            final dividerColor = isDark ? const Color(0xFF243330) : const Color(0xFFEAEFEF);

            final userName = provider.userName?.trim().isNotEmpty == true
                ? provider.userName!.trim()
                : 'Caregiver User';
            final userInitial = userName.isNotEmpty ? userName[0].toUpperCase() : 'C';

            return Padding(
              padding: EdgeInsets.only(bottom: viewInsetsBottom),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 540,
                  maxHeight: screenHeight * 0.88,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: sheetBg,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.12),
                        blurRadius: 24,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 1. Drag Handle & Header
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          isSmall ? 16 : 20,
                          14,
                          isSmall ? 16 : 20,
                          10,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Center(
                              child: Container(
                                width: 44,
                                height: 5,
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.white24 : const Color(0xFFD1E0DC),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: primaryColor.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: const Icon(
                                          Icons.settings_rounded,
                                          color: Color(0xFF00796B),
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Caregiver Settings',
                                              style: TextStyle(
                                                fontSize: isSmall ? 17 : 18.5,
                                                fontWeight: FontWeight.bold,
                                                color: titleColor,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            Text(
                                              'Preferences & account options',
                                              style: TextStyle(
                                                fontSize: isSmall ? 11.5 : 12.5,
                                                color: subtitleColor,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: Icon(
                                    Icons.close_rounded,
                                    color: isDark ? Colors.white70 : Colors.grey.shade600,
                                  ),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: () => Navigator.pop(ctx),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Divider(height: 1, color: dividerColor),

                      // 2. Scrollable Settings Body
                      Flexible(
                        child: ListView(
                          shrinkWrap: true,
                          padding: EdgeInsets.fromLTRB(
                            isSmall ? 16 : 20,
                            14,
                            isSmall ? 16 : 20,
                            0,
                          ),
                          children: [
                            // Profile Summary Card
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: cardBg,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: cardBorder, width: 1.1),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: const LinearGradient(
                                        colors: [Color(0xFF00796B), Color(0xFF004D40)],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: primaryColor.withValues(alpha: 0.2),
                                          blurRadius: 8,
                                          offset: const Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      userInitial,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                        fontSize: 20,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          userName,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                            color: titleColor,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          user?.email ?? 'Logged in caregiver',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: subtitleColor,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  InkWell(
                                    onTap: () {
                                      Navigator.pop(ctx);
                                      _switchTab(3);
                                    },
                                    borderRadius: BorderRadius.circular(10),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: primaryColor.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: primaryColor.withValues(alpha: 0.25),
                                          width: 1,
                                        ),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.mode_edit_outline_rounded,
                                            size: 14,
                                            color: Color(0xFF00796B),
                                          ),
                                          SizedBox(width: 4),
                                          Text(
                                            'Edit',
                                            style: TextStyle(
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF00796B),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Section 1: PREFERENCES
                            _buildSettingsSectionHeader('PREFERENCES', subtitleColor),
                            _buildSettingsCardGroup(
                              cardBg: cardBg,
                              cardBorder: cardBorder,
                              children: [
                                // 1. Dark Mode
                                _buildSettingsTile(
                                  icon: provider.isDarkMode ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                                  iconColor: provider.isDarkMode ? const Color(0xFFD97706) : const Color(0xFF00796B),
                                  iconBgColor: (provider.isDarkMode ? const Color(0xFFD97706) : const Color(0xFF00796B)).withValues(alpha: 0.1),
                                  title: 'Dark Mode',
                                  subtitle: provider.isDarkMode ? 'Dark theme enabled' : 'Light theme enabled',
                                  titleColor: titleColor,
                                  subtitleColor: subtitleColor,
                                  trailing: Switch.adaptive(
                                    value: provider.isDarkMode,
                                    activeThumbColor: const Color(0xFF00796B),
                                    activeTrackColor: const Color(0xFF00796B).withValues(alpha: 0.5),
                                    onChanged: (val) {
                                      provider.setDarkMode(val);
                                      setSheetState(() {});
                                      setState(() {});
                                    },
                                  ),
                                  onTap: () {
                                    provider.setDarkMode(!provider.isDarkMode);
                                    setSheetState(() {});
                                    setState(() {});
                                  },
                                ),
                                Divider(height: 1, thickness: 1, color: dividerColor),

                                // 2. Sound & Audio Effects
                                _buildSettingsTile(
                                  icon: provider.isAudioEffectsEnabled ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                                  iconColor: provider.isAudioEffectsEnabled ? const Color(0xFF00796B) : (isDark ? Colors.white38 : const Color(0xFF94A3B8)),
                                  iconBgColor: (provider.isAudioEffectsEnabled ? const Color(0xFF00796B) : Colors.grey).withValues(alpha: 0.1),
                                  title: 'Sound & Audio Effects',
                                  subtitle: provider.isAudioEffectsEnabled ? 'In-game sound cues and voice prompt feedback' : 'Sound & audio effects muted',
                                  titleColor: titleColor,
                                  subtitleColor: subtitleColor,
                                  trailing: Switch.adaptive(
                                    value: provider.isAudioEffectsEnabled,
                                    activeThumbColor: const Color(0xFF00796B),
                                    activeTrackColor: const Color(0xFF00796B).withValues(alpha: 0.5),
                                    onChanged: (val) {
                                      provider.setAudioEffectsEnabled(val);
                                      final voiceService = ctx.read<VoiceService>();
                                      voiceService.setAudioEnabled(val);
                                      setSheetState(() {});
                                      if (val) {
                                        HapticFeedback.mediumImpact();
                                        SystemSound.play(SystemSoundType.click);
                                        voiceService.playAudioTestCue(lang: provider.userLanguage ?? 'en');
                                      } else {
                                        HapticFeedback.lightImpact();
                                        voiceService.stopGameAudio();
                                      }
                                    },
                                  ),
                                  onTap: () {
                                    final val = !provider.isAudioEffectsEnabled;
                                    provider.setAudioEffectsEnabled(val);
                                    final voiceService = ctx.read<VoiceService>();
                                    voiceService.setAudioEnabled(val);
                                    setSheetState(() {});
                                    if (val) {
                                      HapticFeedback.mediumImpact();
                                      SystemSound.play(SystemSoundType.click);
                                      voiceService.playAudioTestCue(lang: provider.userLanguage ?? 'en');
                                    } else {
                                      HapticFeedback.lightImpact();
                                      voiceService.stopGameAudio();
                                    }
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // Section 2: CARE & NOTIFICATIONS
                            _buildSettingsSectionHeader('CARE & NOTIFICATIONS', subtitleColor),
                            _buildSettingsCardGroup(
                              cardBg: cardBg,
                              cardBorder: cardBorder,
                              children: [
                                // 1. Critical Alerts
                                _buildSettingsTile(
                                  icon: Icons.notifications_active_outlined,
                                  iconColor: const Color(0xFF00796B),
                                  iconBgColor: const Color(0xFF00796B).withValues(alpha: 0.1),
                                  title: 'Critical Alerts',
                                  subtitle: 'Notify immediately on significant accuracy drops',
                                  titleColor: titleColor,
                                  subtitleColor: subtitleColor,
                                  trailing: Switch.adaptive(
                                    value: provider.criticalAlerts,
                                    activeThumbColor: const Color(0xFF00796B),
                                    activeTrackColor: const Color(0xFF00796B).withValues(alpha: 0.5),
                                    onChanged: (val) {
                                      provider.setCriticalAlerts(val);
                                      setSheetState(() {});
                                    },
                                  ),
                                  onTap: () {
                                    provider.setCriticalAlerts(!provider.criticalAlerts);
                                    setSheetState(() {});
                                  },
                                ),
                                Divider(height: 1, thickness: 1, color: dividerColor),

                                // 2. Inactivity Reminders
                                _buildSettingsTile(
                                  icon: Icons.alarm_on_rounded,
                                  iconColor: const Color(0xFF00796B),
                                  iconBgColor: const Color(0xFF00796B).withValues(alpha: 0.1),
                                  title: 'Inactivity Reminders',
                                  subtitle: 'Alert when patient misses daily exercises',
                                  titleColor: titleColor,
                                  subtitleColor: subtitleColor,
                                  trailing: Switch.adaptive(
                                    value: provider.inactivityReminders,
                                    activeThumbColor: const Color(0xFF00796B),
                                    activeTrackColor: const Color(0xFF00796B).withValues(alpha: 0.5),
                                    onChanged: (val) {
                                      provider.setInactivityReminders(val);
                                      setSheetState(() {});
                                    },
                                  ),
                                  onTap: () {
                                    provider.setInactivityReminders(!provider.inactivityReminders);
                                    setSheetState(() {});
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // Section 3: APPLICATION INFO
                            _buildSettingsSectionHeader('APPLICATION INFO', subtitleColor),
                            _buildSettingsCardGroup(
                              cardBg: cardBg,
                              cardBorder: cardBorder,
                              children: [
                                // About NeuroVerse
                                _buildSettingsTile(
                                  icon: Icons.info_outline_rounded,
                                  iconColor: const Color(0xFF00796B),
                                  iconBgColor: const Color(0xFF00796B).withValues(alpha: 0.1),
                                  title: 'About NeuroVerse',
                                  subtitle: 'Mission, clinical capabilities & Q-learning model',
                                  titleColor: titleColor,
                                  subtitleColor: subtitleColor,
                                  trailing: Icon(
                                    Icons.chevron_right_rounded,
                                    size: 20,
                                    color: isDark ? Colors.white38 : Colors.grey.shade400,
                                  ),
                                  onTap: () {
                                    Navigator.pop(ctx);
                                    showAboutNeuroVerseDialog(context);
                                  },
                                ),
                                Divider(height: 1, thickness: 1, color: dividerColor),

                                // Privacy Policy
                                _buildSettingsTile(
                                  icon: Icons.privacy_tip_outlined,
                                  iconColor: const Color(0xFF00796B),
                                  iconBgColor: const Color(0xFF00796B).withValues(alpha: 0.1),
                                  title: 'Privacy Policy',
                                  subtitle: 'Data protection, consent & clinical privacy',
                                  titleColor: titleColor,
                                  subtitleColor: subtitleColor,
                                  trailing: Icon(
                                    Icons.chevron_right_rounded,
                                    size: 20,
                                    color: isDark ? Colors.white38 : Colors.grey.shade400,
                                  ),
                                  onTap: () {
                                    Navigator.pop(ctx);
                                    showPrivacyPolicyDialog(context);
                                  },
                                ),
                                Divider(height: 1, thickness: 1, color: dividerColor),

                                // Version
                                _buildSettingsTile(
                                  icon: Icons.verified_outlined,
                                  iconColor: const Color(0xFF64748B),
                                  iconBgColor: const Color(0xFF64748B).withValues(alpha: 0.1),
                                  title: 'Version',
                                  titleColor: titleColor,
                                  subtitleColor: subtitleColor,
                                  trailing: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF00796B).withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Text(
                                      'Prototype',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF00796B),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // Section 4: ACCOUNT
                            _buildSettingsSectionHeader('ACCOUNT', subtitleColor),
                            _buildSettingsCardGroup(
                              cardBg: isDark ? const Color(0xFF241616) : const Color(0xFFFFF7F7),
                              cardBorder: isDark ? const Color(0xFF422222) : const Color(0xFFFED7D7),
                              children: [

                                // 7. Logout
                                _buildSettingsTile(
                                  icon: Icons.logout_rounded,
                                  iconColor: const Color(0xFFDC2626),
                                  iconBgColor: const Color(0xFFDC2626).withValues(alpha: 0.1),
                                  title: 'Logout',
                                  titleColor: const Color(0xFFDC2626),
                                  subtitleColor: subtitleColor,
                                  trailing: const Icon(
                                    Icons.chevron_right_rounded,
                                    size: 20,
                                    color: Color(0xFFDC2626),
                                  ),
                                  onTap: () async {
                                    final hive = context.read<HiveService>();
                                    final appProvider = context.read<AppProvider>();
                                    final nav = Navigator.of(context);
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (c) => AlertDialog(
                                        title: const Text('Logout?'),
                                        content: const Text('Are you sure you want to log out of your Caregiver account?'),
                                        actions: [
                                          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
                                          ElevatedButton(
                                            onPressed: () => Navigator.pop(c, true),
                                            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                                            child: const Text('Logout'),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (confirm == true) {
                                      nav.pop();
                                      try {
                                        await GoogleSignIn().signOut();
                                      } catch (_) {}
                                      await FirebaseAuth.instance.signOut();
                                      await hive.saveUserProfile({});
                                      appProvider.clearUserProfile();
                                      appProvider.clearProgress();
                                      nav.pushAndRemoveUntil(
                                        MaterialPageRoute(builder: (context) => const AuthScreen()),
                                        (route) => false,
                                      );
                                    }
                                  },
                                ),
                              ],
                            ),

                            // Extra comfortable bottom spacing respecting system navigation
                            const SizedBox(height: 14),
                            SizedBox(height: viewPaddingBottom > 0 ? viewPaddingBottom : 12.0),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }



  // 2. PATIENTS TAB (Live Telemetry & Detail View)
  Widget _buildPatientsTab() {
    final initialPatients = widget.initialPatients;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final bottomInset = MediaQuery.of(context).viewPadding.bottom;

    if (initialPatients != null) {
      return _buildPatientsContent(
        patients: initialPatients,
        isDark: isDark,
        theme: theme,
        screenWidth: screenWidth,
        bottomInset: bottomInset,
      );
    }

    String? uid;
    try {
      uid = FirebaseAuth.instance.currentUser?.uid;
    } catch (_) {
      uid = null;
    }
    if (uid == null) return const Center(child: Text("Not logged in"));

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final data = snapshot.data!.data() as Map<String, dynamic>?;
        final patients = List<String>.from(data?['linkedPatients'] ?? []);
        return _buildPatientsContent(
          patients: patients,
          isDark: isDark,
          theme: theme,
          screenWidth: screenWidth,
          bottomInset: bottomInset,
        );
      },
    );
  }

  Widget _buildPatientsContent({
    required List<String> patients,
    required bool isDark,
    required ThemeData theme,
    required double screenWidth,
    required double bottomInset,
  }) {
    final isSmall = screenWidth < 360;

    // Auto-expand the first patient once when loaded if none expanded yet
    if (!_hasInitializedPatientsExpansion && patients.isNotEmpty) {
      _hasInitializedPatientsExpansion = true;
      _expandedPatientIds.add(patients.first);
    }

    return ListView(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        28.0 + bottomInset,
      ),
      children: [
        // 1. Header: Icon, "Your Patients", Subtitle & Caregiver Illustration
        _buildPatientsHeader(
          isDark: isDark,
          isSmall: isSmall,
          screenWidth: screenWidth,
        ),
        const SizedBox(height: 16),

        // 2. Empty State or List of Patient Cards
        if (patients.isEmpty)
          _buildPatientsEmptyState(
            isDark: isDark,
            isSmall: isSmall,
          )
        else
          ...patients.map((patientId) => _buildPatientTelemetryCard(
                patientId: patientId,
                isDark: isDark,
                isSmall: isSmall,
                screenWidth: screenWidth,
              )),
      ],
    );
  }

  Widget _buildPatientsHeader({
    required bool isDark,
    required bool isSmall,
    required double screenWidth,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Left: Icon + Title + Subtitle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: isSmall ? 38 : 44,
                      height: isSmall ? 38 : 44,
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF004D40).withValues(alpha: 0.35)
                            : const Color(0xFFE0F2F1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.people_alt_rounded,
                        color: const Color(0xFF00796B),
                        size: isSmall ? 20 : 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Text(
                        'Your Patients',
                        style: TextStyle(
                          fontSize: isSmall ? 19 : 22,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                          letterSpacing: -0.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        'Stay informed. Support their journey.',
                        style: TextStyle(
                          fontSize: isSmall ? 10.5 : 11.6,
                          color: isDark ? Colors.white60 : const Color(0xFF64748B),
                          fontWeight: FontWeight.w400,
                          letterSpacing: -0.2,
                        ),
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.visible,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text('🩵', style: TextStyle(fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          // Right: Vector Illustration of Caregiver & Patient
          SizedBox(
            width: (screenWidth * 0.26).clamp(72.0, 102.0),
            height: (screenWidth * 0.18).clamp(50.0, 72.0),
            child: const CustomPaint(
              painter: _CaregiverIllustrationPainter(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPatientsEmptyState({
    required bool isDark,
    required bool isSmall,
  }) {
    return Container(
      margin: const EdgeInsets.only(top: 24),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF004D40).withValues(alpha: 0.3)
                  : const Color(0xFFE0F2F1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.people_alt_outlined,
              size: 32,
              color: Color(0xFF00796B),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            "No patients connected yet.",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "Link with your patients using their 6-character connect code to monitor their live performance.",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white60 : const Color(0xFF64748B),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _showAddPatientDialog,
            icon: const Icon(Icons.link_rounded, size: 18),
            label: const Text(
              'Connect Patient',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00796B),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddPatientPhoneDialog(String patientId, String patientName) {
    final phoneController = TextEditingController();
    bool isSaving = false;
    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return AlertDialog(
            backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                const Icon(Icons.phone_in_talk_rounded, color: Color(0xFF00796B)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Call $patientName',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'No phone number has been added for $patientName yet. Add their contact number below to enable 1-tap emergency & direct calling.',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: 'Patient Phone Number',
                    hintText: 'Enter phone number',
                    prefixIcon: const Icon(Icons.phone_android_rounded, color: Color(0xFF00796B)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF00796B), width: 1.8),
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: isSaving
                    ? null
                    : () async {
                        final entered = phoneController.text.trim();
                        if (entered.isEmpty) return;
                        setDialogState(() => isSaving = true);
                        try {
                          await FirebaseFirestore.instance
                              .collection('users')
                              .doc(patientId)
                              .set({'phone': entered}, SetOptions(merge: true));
                          if (dialogCtx.mounted) {
                            Navigator.pop(dialogCtx);
                            setState(() {});
                            final uri = Uri.parse('tel:$entered');
                            if (await canLaunchUrl(uri)) {
                              await launchUrl(uri, mode: LaunchMode.externalApplication);
                            }
                          }
                        } catch (e) {
                          setDialogState(() => isSaving = false);
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00796B),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text('Save & Call'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPatientTelemetryCard({
    required String patientId,
    required bool isDark,
    required bool isSmall,
    required double screenWidth,
  }) {
    if (widget.initialPatients != null) {
      final pData = widget.mockPatientDetails?[patientId];
      final pName = pData?['name'] ?? 'Unknown Patient';
      final pAge = pData?['age']?.toString() ?? '';
      final pPhone = pData?['phone']?.toString().trim() ?? '';
      final pCode = pData?['shareCode'] ??
          (patientId.length >= 6
              ? patientId.substring(0, 6).toUpperCase()
              : patientId.toUpperCase());
      return _buildPatientTelemetryCardBody(
        patientId: patientId,
        pName: pName,
        pAge: pAge,
        pCode: pCode,
        pPhone: pPhone,
        isDark: isDark,
        isSmall: isSmall,
        screenWidth: screenWidth,
      );
    }

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(patientId).get(),
      builder: (context, pSnap) {
        if (!pSnap.hasData) {
          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                width: 1.2,
              ),
            ),
            child: const Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 14),
                Text(
                  'Loading patient details...',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ],
            ),
          );
        }
        final pData = pSnap.data!.data() as Map<String, dynamic>?;
        final pName = pData?['name'] ?? 'Unknown Patient';
        final pAge = pData?['age']?.toString() ?? '';
        final pPhone = pData?['phone']?.toString().trim() ?? '';
        final pCode = pData?['shareCode'] ??
            (patientId.length >= 6
                ? patientId.substring(0, 6).toUpperCase()
                : patientId.toUpperCase());

        return _buildPatientTelemetryCardBody(
          patientId: patientId,
          pName: pName,
          pAge: pAge,
          pCode: pCode,
          pPhone: pPhone,
          isDark: isDark,
          isSmall: isSmall,
          screenWidth: screenWidth,
        );
      },
    );
  }

  Widget _buildPatientTelemetryCardBody({
    required String patientId,
    required String pName,
    required String pAge,
    required String pCode,
    String pPhone = '',
    required bool isDark,
    required bool isSmall,
    required double screenWidth,
  }) {
    final isExpanded = _expandedPatientIds.contains(patientId);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Patient Header Row (Tappable to expand / collapse)
          InkWell(
            onTap: () {
              setState(() {
                if (isExpanded) {
                  _expandedPatientIds.remove(patientId);
                } else {
                  _expandedPatientIds.add(patientId);
                }
              });
            },
            borderRadius: BorderRadius.circular(22),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Circular Avatar with Patient Initial
                  Container(
                    width: isSmall ? 44 : 50,
                    height: isSmall ? 44 : 50,
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF004D40).withValues(alpha: 0.35)
                          : const Color(0xFFE0F2F1),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      pName.isNotEmpty ? pName[0].toUpperCase() : 'P',
                      style: TextStyle(
                        fontSize: isSmall ? 18 : 22,
                        fontWeight: FontWeight.w800,
                        color: isDark ? const Color(0xFF80CBC4) : const Color(0xFF004D40),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  // Name and Code/Age
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          pName,
                          style: TextStyle(
                            fontSize: isSmall ? 16 : 18,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                            letterSpacing: -0.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Code: $pCode${pAge.isNotEmpty ? '  •  $pAge yrs' : ''}',
                          style: TextStyle(
                            fontSize: isSmall ? 11.5 : 13,
                            color: isDark ? Colors.white60 : const Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Call Patient Button
                  InkWell(
                    onTap: () async {
                      if (pPhone.isNotEmpty) {
                        final uri = Uri.parse('tel:$pPhone');
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        } else {
                          await launchUrl(uri);
                        }
                      } else {
                        _showAddPatientPhoneDialog(patientId, pName);
                      }
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: const Color(0xFF00796B).withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFF00796B).withValues(alpha: 0.25),
                          width: 1,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.phone_in_talk_rounded,
                        size: 19,
                        color: Color(0xFF00796B),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Expand / Collapse Chevron Button
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF334155).withValues(alpha: 0.6)
                          : const Color(0xFFF1F5F9),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      isExpanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      size: 22,
                      color: isDark ? Colors.white70 : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 2. Expanded Content: Live Performance Analytics & Family Album
          if (isExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    child: OutlinedButton.icon(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (_) => FamilyAlbumManagerDialog(
                            patientId: patientId,
                            patientName: pName,
                          ),
                        );
                      },
                      icon: const Icon(Icons.people_alt_rounded, color: Color(0xFFD97706), size: 20),
                      label: const Text(
                        "Face Recall: Manage Family & Friends Photos",
                        style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFD97706)),
                      ),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: const Color(0xFFD97706).withValues(alpha: 0.08),
                        side: const BorderSide(color: Color(0xFFD97706), width: 1.5),
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                  _buildPatientTelemetryDetails(
                    patientId: patientId,
                    patientName: pName,
                    isDark: isDark,
                    isSmall: isSmall,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPatientTelemetryDetails({
    required String patientId,
    required String patientName,
    required bool isDark,
    required bool isSmall,
  }) {
    if (widget.initialPatients != null) {
      final sessionMaps = widget.mockSessions?[patientId] ?? [];
      return _buildTelemetrySubCardsFromDocs(
        sessionMaps: sessionMaps,
        patientName: patientName,
        isDark: isDark,
        isSmall: isSmall,
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(patientId)
          .collection('game_sessions')
          .orderBy('timestamp', descending: true)
          .limit(10)
          .snapshots(),
      builder: (context, sSnap) {
        if (sSnap.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final docs = sSnap.data?.docs ?? [];
        final sessionMaps =
            docs.map((d) => d.data() as Map<String, dynamic>).toList();
        return _buildTelemetrySubCardsFromDocs(
          sessionMaps: sessionMaps,
          patientName: patientName,
          isDark: isDark,
          isSmall: isSmall,
        );
      },
    );
  }

  Widget _buildTelemetrySubCardsFromDocs({
    required List<Map<String, dynamic>> sessionMaps,
    required String patientName,
    required bool isDark,
    required bool isSmall,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header: Bar chart icon + "Live Performance Analytics" + "• Live Data" Badge
        Row(
          children: [
            const Icon(
              Icons.bar_chart_rounded,
              size: 20,
              color: Color(0xFF00897B),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                'Live Performance Analytics',
                style: TextStyle(
                  fontSize: isSmall ? 13 : 14.5,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            // Live Data Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF14532D).withValues(alpha: 0.4)
                    : const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF22C55E).withValues(alpha: 0.3)
                      : const Color(0xFFA7F3D0).withValues(alpha: 0.6),
                  width: 0.8,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Color(0xFF16A34A),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'Live Data',
                    style: TextStyle(
                      fontSize: isSmall ? 9.5 : 10.5,
                      fontWeight: FontWeight.w700,
                      color: isDark ? const Color(0xFF4ADE80) : const Color(0xFF166534),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        if (sessionMaps.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              "No game sessions recorded for this patient yet.",
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white54 : const Color(0xFF64748B),
              ),
            ),
          )
        else ...[
          // Metric Calculations
          () {
            double totalAcc = 0;
            int maxLevel = 1;
            for (var m in sessionMaps) {
              totalAcc += (m['accuracyPercentage'] ?? 0);
              final lvl = (m['difficultyLevel'] ?? 1) as int;
              if (lvl > maxLevel) maxLevel = lvl;
            }
            final avgAcc = (totalAcc / sessionMaps.length).round();

            // Performance Trend based on real consecutive data
            String trendText = 'Stable';
            IconData trendIcon = Icons.trending_flat_rounded;
            Color trendColor = const Color(0xFF00796B);
            if (sessionMaps.length >= 2) {
              final latest = sessionMaps[0]['accuracyPercentage'] ?? 0;
              final previous = sessionMaps[1]['accuracyPercentage'] ?? 0;
              if (latest > previous) {
                trendText = 'Improving (+${latest - previous}%)';
                trendIcon = Icons.trending_up_rounded;
                trendColor = const Color(0xFF16A34A);
              } else if (latest < previous) {
                trendText = 'Attention Needed (-${previous - latest}%)';
                trendIcon = Icons.trending_down_rounded;
                trendColor = const Color(0xFFEA580C);
              } else {
                trendText = 'Stable';
                trendIcon = Icons.trending_flat_rounded;
                trendColor = (latest == 0) ? const Color(0xFFEA580C) : const Color(0xFF00796B);
              }
            } else if (sessionMaps.isNotEmpty && (sessionMaps[0]['accuracyPercentage'] ?? 0) == 0) {
              trendColor = const Color(0xFFEA580C);
            }

            // Relative time for last session
            String lastPlayed = 'Recently';
            final firstTime = sessionMaps[0]['timestamp'];
            final firstDt = _parseDateTime(firstTime);
            if (firstDt != null) {
              final diff = DateTime.now().difference(firstDt);
              if (diff.inMinutes < 60) {
                lastPlayed = '${diff.inMinutes}m ago';
              } else if (diff.inHours < 24) {
                lastPlayed = '${diff.inHours}h ago';
              } else {
                lastPlayed = '${diff.inDays}d ago';
              }
            }

            return Column(
              children: [
                // 1. Trend Direction Sub-Card (Interactive with Graph & Details)
                _buildAnalyticsSubCard(
                  isDark: isDark,
                  isSmall: isSmall,
                  bgColor: isDark
                      ? const Color(0xFF0F291E).withValues(alpha: 0.5)
                      : const Color(0xFFF0FDF4),
                  borderColor: isDark
                      ? const Color(0xFF065F46).withValues(alpha: 0.5)
                      : const Color(0xFFDCFCE7),
                  iconBgColor: isDark
                      ? const Color(0xFF064E3B).withValues(alpha: 0.6)
                      : const Color(0xFFDCFCE7),
                  icon: trendIcon,
                  iconColor: trendColor,
                  title: 'Trend Direction',
                  subtitleWidget: Text(
                    trendText,
                    style: TextStyle(
                      fontSize: isSmall ? 11.5 : 12.5,
                      fontWeight: FontWeight.w700,
                      color: trendColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4.5),
                    decoration: BoxDecoration(
                      color: trendColor.withValues(alpha: isDark ? 0.22 : 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: trendColor.withValues(alpha: 0.35),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.show_chart_rounded, size: 14, color: trendColor),
                        const SizedBox(width: 4),
                        Text(
                          'View Graph',
                          style: TextStyle(
                            fontSize: isSmall ? 10 : 11,
                            fontWeight: FontWeight.bold,
                            color: trendColor,
                          ),
                        ),
                        const SizedBox(width: 2),
                        Icon(Icons.chevron_right_rounded, size: 14, color: trendColor),
                      ],
                    ),
                  ),
                  onTap: () {
                    _showTrendDetailsSheet(
                      context: context,
                      patientName: patientName,
                      sessionMaps: sessionMaps,
                      trendText: trendText,
                      trendColor: trendColor,
                      trendIcon: trendIcon,
                      avgAcc: avgAcc,
                      isDark: isDark,
                    );
                  },
                ),
                const SizedBox(height: 10),

                // 2. Overall Accuracy Sub-Card
                _buildAnalyticsSubCard(
                  isDark: isDark,
                  isSmall: isSmall,
                  bgColor: isDark
                      ? const Color(0xFF0C2340).withValues(alpha: 0.5)
                      : const Color(0xFFF0F7FF),
                  borderColor: isDark
                      ? const Color(0xFF1E3A8A).withValues(alpha: 0.5)
                      : const Color(0xFFDBEAFE),
                  iconBgColor: isDark
                      ? const Color(0xFF1E3A8A).withValues(alpha: 0.4)
                      : const Color(0xFFDBEAFE),
                  icon: Icons.bar_chart_rounded,
                  iconColor: const Color(0xFF1976D2),
                  title: 'Overall Accuracy',
                  subtitleWidget: Text.rich(
                    TextSpan(
                      text: '$avgAcc% ',
                      style: TextStyle(
                        fontSize: isSmall ? 11.5 : 12.5,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                      children: [
                        TextSpan(
                          text: 'across last ${sessionMaps.length} exercises (Max Level: $maxLevel)',
                          style: TextStyle(
                            fontSize: isSmall ? 11 : 12,
                            fontWeight: FontWeight.w400,
                            color: isDark ? Colors.white60 : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // 3. Last Activity Sub-Card
                _buildAnalyticsSubCard(
                  isDark: isDark,
                  isSmall: isSmall,
                  bgColor: isDark
                      ? const Color(0xFF2E1B07).withValues(alpha: 0.4)
                      : const Color(0xFFFFFBEB),
                  borderColor: isDark
                      ? const Color(0xFF78350F).withValues(alpha: 0.4)
                      : const Color(0xFFFEF3C7),
                  iconBgColor: isDark
                      ? const Color(0xFF78350F).withValues(alpha: 0.4)
                      : const Color(0xFFFEF3C7),
                  icon: Icons.calendar_today_rounded,
                  iconColor: const Color(0xFFD97706),
                  title: 'Last Activity',
                  subtitleWidget: Text.rich(
                    TextSpan(
                      text: '$lastPlayed ',
                      style: TextStyle(
                        fontSize: isSmall ? 11.5 : 12.5,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                      children: [
                        TextSpan(
                          text: '(${sessionMaps.length} total sessions recorded)',
                          style: TextStyle(
                            fontSize: isSmall ? 11 : 12,
                            fontWeight: FontWeight.w400,
                            color: isDark ? Colors.white60 : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }(),
        ],
      ],
    );
  }

  Widget _buildAnalyticsSubCard({
    required bool isDark,
    required bool isSmall,
    required Color bgColor,
    required Color borderColor,
    required Color iconBgColor,
    required IconData icon,
    required Color iconColor,
    required String title,
    required Widget subtitleWidget,
    VoidCallback? onTap,
    Widget? trailing,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.0),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isSmall ? 10 : 14,
              vertical: isSmall ? 10 : 12,
            ),
            child: Row(
              children: [
                Container(
                  width: isSmall ? 34 : 40,
                  height: isSmall ? 34 : 40,
                  decoration: BoxDecoration(
                    color: iconBgColor,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    icon,
                    size: isSmall ? 18 : 22,
                    color: iconColor,
                  ),
                ),
                SizedBox(width: isSmall ? 10 : 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: isSmall ? 12.5 : 13.5,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      subtitleWidget,
                    ],
                  ),
                ),
                ?trailing,
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 3. ALERTS TAB (Live Smart Alerts for all patients)
  Widget _buildAlertsTab() {
    if (widget.initialPatients != null && widget.initialPatients!.isEmpty) {
      return _buildAlertsScaffold(
        alerts: const [],
        isNoPatients: true,
      );
    }

    if (widget.mockAlerts != null) {
      return _buildAlertsScaffold(
        alerts: widget.mockAlerts!,
        isNoPatients: false,
      );
    }

    String? uid;
    try {
      uid = FirebaseAuth.instance.currentUser?.uid;
    } catch (_) {
      uid = null;
    }
    if (uid == null) return const Center(child: Text("Not logged in"));

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF00796B)),
          );
        }
        final data = snapshot.data!.data() as Map<String, dynamic>?;
        final patients = List<String>.from(data?['linkedPatients'] ?? []);
        final caregiverPhone = (data?['phone'] ?? data?['mobile'] ?? '').toString().trim();

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('sos_alerts')
              .where('status', isEqualTo: 'ACTIVE')
              .snapshots(),
          builder: (context, sosSnap) {
            final rawSosDocs = sosSnap.data?.docs ?? [];

            return FutureBuilder<List<SmartAlert>>(
              future: _fetchAllPatientAlerts(
                patients,
                caregiverPhone: caregiverPhone,
                rawSosDocs: rawSosDocs,
              ),
              builder: (context, aSnap) {
                if (aSnap.connectionState == ConnectionState.waiting && !aSnap.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(color: Color(0xFF00796B)),
                  );
                }
                final alerts = aSnap.data ?? [];
                final hasAnyLinked = patients.isNotEmpty || alerts.isNotEmpty;

                return _buildAlertsScaffold(
                  alerts: alerts,
                  isNoPatients: !hasAnyLinked,
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildAlertsScaffold({
    required List<SmartAlert> alerts,
    required bool isNoPatients,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomInset = MediaQuery.of(context).viewPadding.bottom;
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmall = screenWidth < 360;

    final titleColor = isDark ? Colors.white : const Color(0xFF1B3B36);
    final subtitleColor = isDark ? Colors.white60 : const Color(0xFF4A6B63);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            20,
            16,
            20,
            28.0 + bottomInset,
          ),
          children: [
            // Top Header: Title, subtitle & Live status indicator
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Smart Alerts',
                        style: TextStyle(
                          fontSize: isSmall ? 21 : 24,
                          fontWeight: FontWeight.bold,
                          color: titleColor,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Cognitive monitoring & telemetry updates',
                        style: TextStyle(
                          fontSize: isSmall ? 12 : 13.5,
                          color: subtitleColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF102820) : const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFF00796B).withValues(alpha: 0.25),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: Color(0xFF10B981),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'Live',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isDark ? const Color(0xFF80CBC4) : const Color(0xFF00796B),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Content body: Empty state or Alert cards
            if (isNoPatients)
              _buildNoLinkedPatientsState(isDark: isDark, isSmall: isSmall)
            else if (alerts.isEmpty)
              _buildAllClearState(isDark: isDark, isSmall: isSmall)
            else
              ...alerts.map((alert) => _buildAlertCard(
                    alert: alert,
                    isDark: isDark,
                    isSmall: isSmall,
                  )),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertCard({
    required SmartAlert alert,
    required bool isDark,
    required bool isSmall,
  }) {
    final sev = alert.severity.toLowerCase().trim();
    final isCritical = sev == 'critical';
    final isWarning = sev == 'warning';

    final Color severityColor = isCritical
        ? const Color(0xFFDC2626)
        : (isWarning ? const Color(0xFFD97706) : const Color(0xFF00796B));

    final IconData alertIcon = isCritical
        ? Icons.warning_rounded
        : (isWarning ? Icons.info_outline_rounded : Icons.notifications_active_rounded);

    final String severityLabel = isCritical
        ? 'CRITICAL'
        : (isWarning ? 'WARNING' : 'INFO');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1B2422) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? severityColor.withValues(alpha: 0.35)
              : severityColor.withValues(alpha: 0.22),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black26
                : severityColor.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: Severity badge & formatted timestamp
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                decoration: BoxDecoration(
                  color: severityColor.withValues(alpha: isDark ? 0.20 : 0.10),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(alertIcon, size: 12, color: severityColor),
                    const SizedBox(width: 4.5),
                    Text(
                      severityLabel,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: severityColor,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.schedule_rounded,
                    size: 13,
                    color: isDark ? Colors.white38 : Colors.grey.shade500,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${alert.timestamp.day}/${alert.timestamp.month}/${alert.timestamp.year}',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white38 : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Content row: Icon box + Title & Message
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: severityColor.withValues(alpha: isDark ? 0.22 : 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(alertIcon, color: severityColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      alert.title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: isDark ? Colors.white : const Color(0xFF1B3B36),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      alert.message,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.35,
                        color: isDark ? Colors.white70 : const Color(0xFF4A6B63),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (alert.id != null) ...[
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (alert.patientPhone != null && alert.patientPhone!.isNotEmpty)
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF059669),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: () async {
                      final uri = Uri.parse('tel:${alert.patientPhone}');
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri);
                      }
                    },
                    icon: const Icon(Icons.phone_rounded, size: 14),
                    label: const Text('Call Patient', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                if (alert.mapsUrl != null && alert.mapsUrl!.isNotEmpty && alert.mapsUrl!.startsWith('http')) ...[
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF1565C0),
                      side: const BorderSide(color: Color(0xFF1565C0)),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: () async {
                      final uri = Uri.parse(alert.mapsUrl!);
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                      }
                    },
                    icon: const Icon(Icons.map_rounded, size: 14),
                    label: const Text('Map', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                ],
                const SizedBox(width: 8),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: isDark ? Colors.white60 : Colors.grey.shade700,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: () async {
                    try {
                      await FirebaseFirestore.instance.collection('sos_alerts').doc(alert.id).update({
                        'status': 'RESOLVED',
                        'resolvedAt': FieldValue.serverTimestamp(),
                      });
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('${alert.title} marked resolved.'),
                            backgroundColor: const Color(0xFF00796B),
                          ),
                        );
                      }
                    } catch (e) {
                      debugPrint('Error resolving alert: $e');
                    }
                  },
                  icon: const Icon(Icons.check_circle_outline_rounded, size: 15),
                  label: const Text('Resolve', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNoLinkedPatientsState({required bool isDark, required bool isSmall}) {
    return Container(
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1B2422) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF2B3A36) : const Color(0xFFE2ECE8),
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black26 : Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF25332F) : const Color(0xFFE0F2F1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.notifications_none_rounded,
              size: 38,
              color: Color(0xFF00796B),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            "No linked patients for alert monitoring.",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: isSmall ? 15 : 16,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF1B3B36),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Once you link a patient under your care, cognitive activity alerts and telemetry updates will appear here automatically.",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: isDark ? Colors.white60 : const Color(0xFF4A6B63),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAllClearState({required bool isDark, required bool isSmall}) {
    return Container(
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1B2422) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF1E3A2F) : const Color(0xFFD1E7DD),
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black26 : const Color(0xFF10B981).withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E3A2F) : const Color(0xFFE8F5E9),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle_outline_rounded,
              size: 38,
              color: Color(0xFF10B981),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            "All patients are performing stably! No active alerts.",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: isSmall ? 15 : 16,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF1B3B36),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Telemetry and activity trends are within expected baseline parameters across all monitored sessions.",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: isDark ? Colors.white60 : const Color(0xFF4A6B63),
            ),
          ),
        ],
      ),
    );
  }

  Future<List<SmartAlert>> _fetchAllPatientAlerts(
    List<String> patients, {
    String? caregiverPhone,
    List<QueryDocumentSnapshot>? rawSosDocs,
  }) async {
    List<SmartAlert> all = [];

    // 1. Fetch Active SOS Alerts for linked patients from Firestore
    try {
      final currentUid = FirebaseAuth.instance.currentUser?.uid;
      final List<QueryDocumentSnapshot> docs;
      if (rawSosDocs != null) {
        docs = rawSosDocs;
      } else {
        final sosSnap = await FirebaseFirestore.instance
            .collection('sos_alerts')
            .where('status', isEqualTo: 'ACTIVE')
            .get();
        docs = sosSnap.docs;
      }

      final cleanCgPhone = (caregiverPhone ?? '').replaceAll(RegExp(r'\s+'), '');

      for (final doc in docs) {
        final data = doc.data() as Map<String, dynamic>;
        final pId = (data['patientUid'] ?? data['patientId'] ?? '').toString();
        final targetCaregivers = List<String>.from(data['targetCaregiverIds'] ?? []);
        final targetPhone = (data['targetCaregiverPhone'] ?? '').toString().trim();
        final smsList = List<String>.from(data['smsDeliveredTo'] ?? []);

        final isLinked = patients.contains(pId) ||
            (currentUid != null && targetCaregivers.contains(currentUid)) ||
            (cleanCgPhone.isNotEmpty &&
                targetPhone.isNotEmpty &&
                (targetPhone.replaceAll(RegExp(r'\s+'), '').endsWith(cleanCgPhone) ||
                    cleanCgPhone.endsWith(targetPhone.replaceAll(RegExp(r'\s+'), '')))) ||
            (cleanCgPhone.isNotEmpty &&
                smsList.any((c) {
                  final clean = c.replaceAll(RegExp(r'\s+'), '');
                  return clean.endsWith(cleanCgPhone) || cleanCgPhone.endsWith(clean);
                }));

        if (isLinked) {
          final pName = data['patientName'] ?? 'Patient';
          final mapsUrl = (data['mapsUrl'] ?? '').toString();
          final pPhone = (data['patientPhone'] ?? '').toString();
          final alertType = (data['type'] ?? 'SOS').toString();
          final isCall = alertType == 'CALL_CAREGIVER';

          DateTime alertDate = DateTime.now();
          final ts = data['timestamp'];
          if (ts is Timestamp) {
            alertDate = ts.toDate();
          } else if (data['localTimestamp'] != null) {
            alertDate = DateTime.tryParse(data['localTimestamp'].toString()) ?? DateTime.now();
          }

          final title = data['title']?.toString() ??
              (isCall ? '📞 Call from $pName' : '🚨 EMERGENCY SOS ALERT: $pName');
          final rawMsg = data['message']?.toString();
          String cleanMsg = rawMsg ??
              (isCall
                  ? ' tapped Call Caregiver to reach you.'
                  : 'Patient triggered Emergency SOS! Check on  immediately!');
          cleanMsg = cleanMsg
              .replaceAll(RegExp(r'Live Location:\s*https?://\S+', caseSensitive: false), '')
              .replaceAll(RegExp(r'https?://\S+', caseSensitive: false), '')
              .replaceAll(RegExp(r'\s{2,}'), ' ')
              .trim();
          final severity = (data['severity'] ?? (isCall ? 'warning' : 'critical')).toString();

          all.add(SmartAlert(
            id: doc.id,
            type: alertType,
            title: title,
            message: cleanMsg,
            severity: severity,
            timestamp: alertDate,
            patientId: pId,
            patientPhone: pPhone,
            mapsUrl: mapsUrl,
          ));
        }
      }
    } catch (e) {
      debugPrint('CaregiverMainScreen: SOS alerts fetch note: $e');
    }

    // 2. Fetch cognitive metrics & game alerts
    for (final p in patients) {
      final mockName = widget.mockPatientDetails?[p]?['name'] as String?;
      final mockPatientSessions = widget.mockSessions?[p];
      final pAlerts = await _alertsService.generateAlertsForPatient(
        p,
        patientName: mockName,
        mockSessions: mockPatientSessions,
      );
      all.addAll(pAlerts);
    }
    all.sort((a, b) {
      int getSeverityWeight(String sev) {
        final s = sev.toLowerCase().trim();
        if (s == 'critical') return 3;
        if (s == 'warning') return 2;
        return 1; // info
      }

      final weightA = getSeverityWeight(a.severity);
      final weightB = getSeverityWeight(b.severity);

      if (weightA != weightB) {
        return weightB.compareTo(weightA); // Critical notifications and alerts on top!
      }
      return b.timestamp.compareTo(a.timestamp); // Newer first within same severity
    });
    return all;
  }

  String _getCaregiverInitials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return 'C';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  // 4. PROFILE TAB (Caregiver Account Details & Settings)
  Widget _buildProfileTab() {
    User? user;
    try {
      user = FirebaseAuth.instance.currentUser;
    } catch (_) {
      user = null;
    }

    if (user != null) {
      return StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
        builder: (context, snapshot) {
          final firestoreData = snapshot.data?.data() as Map<String, dynamic>?;
          return _buildProfileTabContent(user, firestoreData);
        },
      );
    }
    return _buildProfileTabContent(null, null);
  }

  Widget _buildProfileTabContent(User? user, Map<String, dynamic>? firestoreData) {
    final appProvider = context.watch<AppProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomInset = MediaQuery.of(context).viewPadding.bottom;
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmall = screenWidth < 360;

    final name = (firestoreData?['name']?.toString().trim() ?? '').isNotEmpty
        ? firestoreData!['name'].toString().trim()
        : (appProvider.userName?.trim().isNotEmpty == true
            ? appProvider.userName!.trim()
            : 'Caregiver');
    final age = (firestoreData?['age']?.toString().trim() ?? '').isNotEmpty
        ? firestoreData!['age'].toString().trim()
        : (appProvider.userAge?.trim().isNotEmpty == true
            ? appProvider.userAge!.trim()
            : 'Not set');
    final rawGender = (firestoreData?['gender']?.toString().trim() ?? '').isNotEmpty
        ? firestoreData!['gender'].toString().trim()
        : (appProvider.userGender?.trim() ?? '');
    final gender = rawGender.isNotEmpty
        ? (rawGender[0].toUpperCase() + rawGender.substring(1).toLowerCase())
        : 'Not set';

    final hiveProfile = context.read<HiveService>().getUserProfile();
    final caregiverPhone = (firestoreData?['phone']?.toString().trim() ?? '').isNotEmpty
        ? firestoreData!['phone'].toString().trim()
        : (hiveProfile?['phone']?.toString().trim() ?? '');

    // Auto-heal local Hive cache if phone was missing locally
    if (caregiverPhone.isNotEmpty && (hiveProfile?['phone'] == null || hiveProfile!['phone'].toString().trim().isEmpty)) {
      try {
        final existing = Map<String, dynamic>.from(hiveProfile ?? {});
        existing['phone'] = caregiverPhone;
        context.read<HiveService>().saveUserProfile(existing);
      } catch (_) {}
    }

    const primaryColor = Color(0xFF00796B);
    final titleColor = isDark ? Colors.white : const Color(0xFF1B3B36);
    final subtitleColor = isDark ? Colors.white60 : const Color(0xFF4A6B63);
    final cardBg = isDark ? const Color(0xFF1B2422) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF2B3A36) : const Color(0xFFE2ECE8);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540),
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            20,
            16,
            20,
            28.0 + bottomInset,
          ),
          children: [
            // 1. Top Header: Title, subtitle & Edit Profile button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'My Profile',
                        style: TextStyle(
                          fontSize: isSmall ? 21 : 24,
                          fontWeight: FontWeight.bold,
                          color: titleColor,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Account details & care connection',
                        style: TextStyle(
                          fontSize: isSmall ? 12 : 13.5,
                          color: subtitleColor,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _openCaregiverEditProfileSheet(caregiverPhone),
                  icon: const Icon(
                    Icons.mode_edit_outline_rounded,
                    size: 16,
                    color: Color(0xFF00796B),
                  ),
                  label: const Text(
                    'Edit Profile',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13.5,
                      color: Color(0xFF00796B),
                    ),
                  ),
                  style: TextButton.styleFrom(
                    backgroundColor: primaryColor.withValues(alpha: 0.08),
                    side: BorderSide(
                      color: primaryColor.withValues(alpha: 0.25),
                      width: 1.2,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // 2. Hero Avatar & Identification Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: cardBorder,
                  width: 1.2,
                ),
                boxShadow: isDark
                    ? null
                    : [
                        BoxShadow(
                          color: primaryColor.withValues(alpha: 0.05),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
              ),
              child: Row(
                children: [
                  Container(
                    width: isSmall ? 54 : 62,
                    height: isSmall ? 54 : 62,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFF00796B), Color(0xFF004D40)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: primaryColor.withValues(alpha: 0.25),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      _getCaregiverInitials(name),
                      style: TextStyle(
                        fontSize: isSmall ? 20 : 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: TextStyle(
                            fontSize: isSmall ? 16.5 : 18.5,
                            fontWeight: FontWeight.bold,
                            color: titleColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          user?.email ?? 'No email associated',
                          style: TextStyle(
                            fontSize: isSmall
                                ? ((user?.email?.length ?? 0) > 22 ? 10.5 : 11.5)
                                : ((user?.email?.length ?? 0) > 22 ? 11.5 : 12.5),
                            color: subtitleColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
                          decoration: BoxDecoration(
                            color: primaryColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: primaryColor.withValues(alpha: 0.18),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.verified_user_rounded,
                                size: 12.5,
                                color: Color(0xFF00796B),
                              ),
                              const SizedBox(width: 5),
                              Flexible(
                                child: Text(
                                  'Verified Caregiver Account',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF00796B),
                                    letterSpacing: 0.2,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 3. Personal Details Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: cardBorder,
                  width: 1.2,
                ),
                boxShadow: isDark
                    ? null
                    : [
                        BoxShadow(
                          color: primaryColor.withValues(alpha: 0.04),
                          blurRadius: 14,
                          offset: const Offset(0, 3),
                        ),
                      ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: primaryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.badge_outlined,
                          size: 19,
                          color: Color(0xFF00796B),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Personal Details',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: titleColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildCaregiverDetailRow(
                    icon: Icons.email_outlined,
                    iconColor: const Color(0xFF4F46E5),
                    label: 'Email',
                    value: user?.email ?? 'Not set',
                  ),
                  const Divider(height: 22),
                  _buildCaregiverDetailRow(
                    icon: Icons.cake_outlined,
                    iconColor: const Color(0xFFE11D48),
                    label: 'Age',
                    value: age.isNotEmpty && age != 'Not set' ? '$age years' : 'Not set',
                  ),
                  const Divider(height: 22),
                  _buildCaregiverDetailRow(
                    icon: Icons.people_outline_rounded,
                    iconColor: const Color(0xFF0284C7),
                    label: 'Gender',
                    value: gender,
                  ),
                  const Divider(height: 22),
                  _buildCaregiverDetailRow(
                    icon: Icons.phone_android_rounded,
                    iconColor: const Color(0xFF0D9488),
                    label: 'Mobile',
                    value: caregiverPhone.isNotEmpty ? caregiverPhone : 'Not set',
                    trailing: caregiverPhone.isEmpty
                        ? InkWell(
                            onTap: () => _openCaregiverEditProfileSheet(caregiverPhone),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: primaryColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                '+ Add',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF00796B),
                                ),
                              ),
                            ),
                          )
                        : null,
                  ),
                  const Divider(height: 22),
                  _buildCaregiverDetailRow(
                    icon: Icons.shield_outlined,
                    iconColor: const Color(0xFF00796B),
                    label: 'Role',
                    value: 'Primary Caregiver',
                    trailing: Container(
                      margin: const EdgeInsets.only(left: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E4631) : const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Active',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF16A34A),
                            ),
                          ),
                          SizedBox(width: 3),
                          Icon(Icons.check_circle_rounded, size: 11, color: Color(0xFF16A34A)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 4. Settings & Care Management Card
            Container(
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: cardBorder,
                  width: 1.2,
                ),
                boxShadow: isDark
                    ? null
                    : [
                        BoxShadow(
                          color: primaryColor.withValues(alpha: 0.04),
                          blurRadius: 14,
                          offset: const Offset(0, 3),
                        ),
                      ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 16, 18, 6),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: primaryColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.tune_rounded,
                              size: 19,
                              color: Color(0xFF00796B),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Settings & Care Management',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: titleColor,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Material(
                      color: Colors.transparent,
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: primaryColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.person_add_alt_1_rounded,
                            color: Color(0xFF00796B),
                            size: 20,
                          ),
                        ),
                        title: Text(
                          'Connect Patient',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: titleColor,
                          ),
                        ),
                        subtitle: Text(
                          'Link patient using 6-character Connect Code',
                          style: TextStyle(fontSize: 12.5, color: subtitleColor),
                        ),
                        trailing: Icon(
                          Icons.chevron_right_rounded,
                          color: isDark ? Colors.white38 : Colors.grey.shade400,
                        ),
                        onTap: _showAddPatientDialog,
                      ),
                    ),
                    const Divider(height: 1),
                    Material(
                      color: Colors.transparent,
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD97706).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.settings_outlined,
                            color: Color(0xFFD97706),
                            size: 20,
                          ),
                        ),
                        title: Text(
                          'Settings & Preferences',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: titleColor,
                          ),
                        ),
                        subtitle: Text(
                          'Dark mode, notifications & sync',
                          style: TextStyle(fontSize: 12.5, color: subtitleColor),
                        ),
                        trailing: Icon(
                          Icons.chevron_right_rounded,
                          color: isDark ? Colors.white38 : Colors.grey.shade400,
                        ),
                        onTap: _openSettingsSheet,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // 5. Logout Button (Matching Patient UI styling)
            OutlinedButton.icon(
              onPressed: () async {
                final hive = context.read<HiveService>();
                final appProvider = context.read<AppProvider>();
                final nav = Navigator.of(context);
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (c) => AlertDialog(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    title: const Row(
                      children: [
                        Icon(Icons.logout_rounded, color: Color(0xFFDC2626), size: 22),
                        SizedBox(width: 8),
                        Text('Log Out?'),
                      ],
                    ),
                    content: const Text(
                      'Are you sure you want to log out of your Caregiver account?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(c, false),
                        child: const Text('Cancel'),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(c, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFDC2626),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Log Out'),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  try {
                    await GoogleSignIn().signOut();
                  } catch (_) {}
                  await FirebaseAuth.instance.signOut();
                  await hive.saveUserProfile({});
                  appProvider.clearUserProfile();
                  appProvider.clearProgress();
                  nav.pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => const AuthScreen()),
                    (route) => false,
                  );
                }
              },
              icon: const Icon(
                Icons.logout_rounded,
                color: Color(0xFFDC2626),
                size: 18,
              ),
              label: const Text(
                'Log Out of Caregiver Account',
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFDC2626),
                ),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: BorderSide(
                  color: const Color(0xFFDC2626).withValues(alpha: 0.35),
                  width: 1.2,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                backgroundColor: const Color(0xFFDC2626).withValues(alpha: 0.04),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildCaregiverDetailRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    Widget? trailing,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isEmail = label.toLowerCase().contains('email');
    final double valueFontSize = isEmail
        ? (value.length > 26 ? 11.5 : (value.length > 20 ? 12.5 : 13.5))
        : 14.5;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: 18),
        ),
        const SizedBox(width: 12),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: isDark ? Colors.white70 : const Color(0xFF4A6B63),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            mainAxisSize: MainAxisSize.max,
            children: [
              Flexible(
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: valueFontSize,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF1B3B36),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                ),
              ),
              ?trailing,
            ],
          ),
        ),
      ],
    );
  }

  void _openCaregiverEditProfileSheet([String? currentPhone]) {
    final provider = context.read<AppProvider>();
    final nameController = TextEditingController(text: provider.userName ?? '');
    final ageController = TextEditingController(text: provider.userAge ?? '');
    final hiveProfile = context.read<HiveService>().getUserProfile();
    final initialPhone = (currentPhone != null && currentPhone.trim().isNotEmpty)
        ? currentPhone.trim()
        : (hiveProfile?['phone']?.toString().trim() ?? '');
    final phoneController = TextEditingController(text: initialPhone);
    final rawGender = provider.userGender?.trim() ?? 'Female';
    String selectedGender = 'Female';
    if (rawGender.toLowerCase() == 'male') {
      selectedGender = 'Male';
    } else if (rawGender.toLowerCase() == 'other') {
      selectedGender = 'Other';
    } else {
      selectedGender = 'Female';
    }
    final formKey = GlobalKey<FormState>();
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final mediaQuery = MediaQuery.of(ctx);
            final screenHeight = mediaQuery.size.height;
            final screenWidth = mediaQuery.size.width;
            final viewInsetsBottom = mediaQuery.viewInsets.bottom;
            final viewPaddingBottom = mediaQuery.viewPadding.bottom;
            final isSmall = screenWidth < 360;

            const primaryColor = Color(0xFF00796B);
            final titleColor = isDark ? Colors.white : const Color(0xFF1B3B36);
            final subtitleColor = isDark ? Colors.white60 : const Color(0xFF4A6B63);
            final inputBg = isDark ? const Color(0xFF141C1A) : const Color(0xFFF7FAF9);
            final inputBorder = isDark ? Colors.white.withValues(alpha: 0.15) : const Color(0xFFD1E0DC);
            final sheetBg = isDark ? const Color(0xFF182220) : Colors.white;

            return Padding(
              padding: EdgeInsets.only(bottom: viewInsetsBottom),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 540,
                  maxHeight: screenHeight * 0.88,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: sheetBg,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.12),
                        blurRadius: 24,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                        // 1. Drag Handle & Header (Fixed at top)
                        Padding(
                          padding: EdgeInsets.fromLTRB(
                            isSmall ? 16 : 20,
                            14,
                            isSmall ? 16 : 20,
                            10,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Center(
                                child: Container(
                                  width: 44,
                                  height: 5,
                                  decoration: BoxDecoration(
                                    color: isDark ? Colors.white24 : const Color(0xFFD1E0DC),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: primaryColor.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: const Icon(
                                            Icons.badge_outlined,
                                            color: Color(0xFF00796B),
                                            size: 20,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Edit Caregiver Profile',
                                                style: TextStyle(
                                                  fontSize: isSmall ? 17 : 18.5,
                                                  fontWeight: FontWeight.bold,
                                                  color: titleColor,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              Text(
                                                'Update your personal information',
                                                style: TextStyle(
                                                  fontSize: isSmall ? 11.5 : 12.5,
                                                  color: subtitleColor,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: Icon(
                                      Icons.close_rounded,
                                      color: isDark ? Colors.white70 : Colors.grey.shade600,
                                    ),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    onPressed: () => Navigator.pop(ctx),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1),

                        // 2. Scrollable Form Content (Flexible in middle)
                        Flexible(
                          child: SingleChildScrollView(
                            padding: EdgeInsets.fromLTRB(
                              isSmall ? 16 : 20,
                              14,
                              isSmall ? 16 : 20,
                              14,
                            ),
                            child: Form(
                              key: formKey,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Hero Avatar Card Preview (Identical to EditProfileScreen)
                                  Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF141C1A) : const Color(0xFFF7FAF9),
                                      borderRadius: BorderRadius.circular(18),
                                      border: Border.all(
                                        color: isDark ? const Color(0xFF2B3A36) : const Color(0xFFE2ECE8),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 50,
                                          height: 50,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            gradient: const LinearGradient(
                                              colors: [Color(0xFF00796B), Color(0xFF004D40)],
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: primaryColor.withValues(alpha: 0.2),
                                                blurRadius: 10,
                                                offset: const Offset(0, 3),
                                              ),
                                            ],
                                          ),
                                          alignment: Alignment.center,
                                          child: Text(
                                            _getCaregiverInitials(nameController.text),
                                            style: const TextStyle(
                                              fontSize: 22,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                nameController.text.trim().isNotEmpty
                                                    ? nameController.text.trim()
                                                    : 'Caregiver',
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                  color: titleColor,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 2),
                                              Row(
                                                children: [
                                                  const Icon(
                                                    Icons.verified_user_rounded,
                                                    size: 13,
                                                    color: Color(0xFF00796B),
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Flexible(
                                                    child: Text(
                                                      'Verified Caregiver',
                                                      style: const TextStyle(
                                                        fontSize: 12,
                                                        fontWeight: FontWeight.w600,
                                                        color: Color(0xFF00796B),
                                                      ),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 18),

                                  // Personal Information Section Heading (Matching Settings & Care Management)
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: primaryColor.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Icon(
                                          Icons.badge_outlined,
                                          size: 19,
                                          color: Color(0xFF00796B),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          'Personal Information',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: titleColor,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 14),

                                  // Form Fields (Full Name)
                                  Row(
                                    children: [
                                      Text(
                                        'Full Name',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13.5,
                                          color: titleColor,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      const Text(
                                        '*',
                                        style: TextStyle(
                                          color: Color(0xFFDC2626),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  TextFormField(
                                    controller: nameController,
                                    textCapitalization: TextCapitalization.words,
                                    style: TextStyle(
                                      color: titleColor,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: 'Enter full name',
                                      hintStyle: TextStyle(
                                        color: isDark ? Colors.white38 : Colors.grey.shade400,
                                        fontSize: 14,
                                      ),
                                      prefixIcon: const Icon(
                                        Icons.person_outline_rounded,
                                        color: Color(0xFF00796B),
                                        size: 20,
                                      ),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                      filled: true,
                                      fillColor: inputBg,
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(14),
                                        borderSide: BorderSide(color: inputBorder),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(14),
                                        borderSide: const BorderSide(color: Color(0xFF00796B), width: 1.8),
                                      ),
                                      errorBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(14),
                                        borderSide: const BorderSide(color: Color(0xFFDC2626)),
                                      ),
                                      focusedErrorBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(14),
                                        borderSide: const BorderSide(color: Color(0xFFDC2626), width: 1.8),
                                      ),
                                    ),
                                    validator: (v) => v == null || v.trim().isEmpty ? 'Please enter your name' : null,
                                    onChanged: (_) => setModalState(() {}),
                                  ),
                                  const SizedBox(height: 16),

                                  // Form Fields (Age)
                                  Row(
                                    children: [
                                      Text(
                                        'Age',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13.5,
                                          color: titleColor,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      const Text(
                                        '*',
                                        style: TextStyle(
                                          color: Color(0xFFDC2626),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  TextFormField(
                                    controller: ageController,
                                    keyboardType: TextInputType.number,
                                    style: TextStyle(
                                      color: titleColor,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: 'Enter age',
                                      hintStyle: TextStyle(
                                        color: isDark ? Colors.white38 : Colors.grey.shade400,
                                        fontSize: 14,
                                      ),
                                      prefixIcon: const Icon(
                                        Icons.cake_outlined,
                                        color: Color(0xFF00796B),
                                        size: 20,
                                      ),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                      filled: true,
                                      fillColor: inputBg,
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(14),
                                        borderSide: BorderSide(color: inputBorder),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(14),
                                        borderSide: const BorderSide(color: Color(0xFF00796B), width: 1.8),
                                      ),
                                      errorBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(14),
                                        borderSide: const BorderSide(color: Color(0xFFDC2626)),
                                      ),
                                      focusedErrorBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(14),
                                        borderSide: const BorderSide(color: Color(0xFFDC2626), width: 1.8),
                                      ),
                                    ),
                                    validator: (v) => v == null || v.trim().isEmpty ? 'Please enter age' : null,
                                  ),
                                  const SizedBox(height: 16),

                                  // Form Fields (Mobile Number)
                                  Text(
                                    'Mobile Number',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13.5,
                                      color: titleColor,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  TextFormField(
                                    controller: phoneController,
                                    keyboardType: TextInputType.phone,
                                    style: TextStyle(
                                      color: titleColor,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: 'Enter mobile number (+91...)',
                                      hintStyle: TextStyle(
                                        color: isDark ? Colors.white38 : Colors.grey.shade400,
                                        fontSize: 14,
                                      ),
                                      prefixIcon: const Icon(
                                        Icons.phone_android_rounded,
                                        color: Color(0xFF00796B),
                                        size: 20,
                                      ),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                      filled: true,
                                      fillColor: inputBg,
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(14),
                                        borderSide: BorderSide(color: inputBorder),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(14),
                                        borderSide: const BorderSide(color: Color(0xFF00796B), width: 1.8),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),

                                  // Form Fields (Gender)
                                  Text(
                                    'Gender',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13.5,
                                      color: titleColor,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  DropdownButtonFormField<String>(
                                    initialValue: ['Male', 'Female', 'Other'].contains(selectedGender)
                                        ? selectedGender
                                        : 'Female',
                                    items: ['Male', 'Female', 'Other'].map((String v) {
                                      return DropdownMenuItem<String>(
                                        value: v,
                                        child: Text(
                                          v,
                                          style: TextStyle(
                                            color: titleColor,
                                            fontSize: 15,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                    onChanged: (newVal) {
                                      if (newVal != null) {
                                        setModalState(() => selectedGender = newVal);
                                      }
                                    },
                                    dropdownColor: isDark ? const Color(0xFF1E2826) : Colors.white,
                                    decoration: InputDecoration(
                                      prefixIcon: const Icon(
                                        Icons.people_outline_rounded,
                                        color: Color(0xFF00796B),
                                        size: 20,
                                      ),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                      filled: true,
                                      fillColor: inputBg,
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(14),
                                        borderSide: BorderSide(color: inputBorder),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(14),
                                        borderSide: const BorderSide(color: Color(0xFF00796B), width: 1.8),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                ],
                              ),
                            ),
                          ),
                        ),

                        // 3. Pinned Bottom Action Bar (Fixed at bottom - ALWAYS visible & accessible)
                        Container(
                          padding: EdgeInsets.fromLTRB(
                            isSmall ? 16 : 20,
                            12,
                            isSmall ? 16 : 20,
                            viewInsetsBottom > 0
                                ? 12
                                : (viewPaddingBottom > 0 ? viewPaddingBottom + 4 : 14),
                          ),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF141C1A) : const Color(0xFFF9FBFB),
                            border: Border(
                              top: BorderSide(
                                color: isDark ? const Color(0xFF243330) : const Color(0xFFE5ECE9),
                                width: 1,
                              ),
                            ),
                          ),
                          child: SafeArea(
                            top: false,
                            bottom: false,
                            child: Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: isSaving ? null : () => Navigator.pop(ctx),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      side: BorderSide(
                                        color: isDark ? Colors.white24 : const Color(0xFFD1E0DC),
                                        width: 1.2,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                    child: Text(
                                      'Cancel',
                                      style: TextStyle(
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.bold,
                                        color: isDark ? Colors.white70 : Colors.grey.shade700,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  flex: 2,
                                  child: ElevatedButton(
                                    onPressed: isSaving
                                        ? null
                                        : () async {
                                            if (formKey.currentState!.validate()) {
                                              setModalState(() => isSaving = true);
                                              final updatedName = nameController.text.trim();
                                              final updatedAge = ageController.text.trim();
                                              final updatedPhone = phoneController.text.trim();

                                              provider.setUserProfile(
                                                updatedName,
                                                updatedAge,
                                                selectedGender,
                                                provider.userLanguage ?? 'English',
                                              );

                                              try {
                                                final hive = ctx.read<HiveService>();
                                                final existing = hive.getUserProfile() ?? {};
                                                existing.addAll({
                                                  'name': updatedName,
                                                  'age': updatedAge,
                                                  'gender': selectedGender,
                                                  'phone': updatedPhone,
                                                  'language': provider.userLanguage ?? 'English',
                                                  'role': 'caregiver',
                                                });
                                                await hive.saveUserProfile(existing);
                                              } catch (e) {
                                                debugPrint('Error saving caregiver profile to Hive: $e');
                                              }

                                              try {
                                                final uid = FirebaseAuth.instance.currentUser?.uid;
                                                if (uid != null) {
                                                  await FirebaseFirestore.instance.collection('users').doc(uid).set({
                                                    'name': updatedName,
                                                    'age': updatedAge,
                                                    'gender': selectedGender,
                                                    'phone': updatedPhone,
                                                  }, SetOptions(merge: true));
                                                }
                                              } catch (e) {
                                                debugPrint('Error saving caregiver profile to Firestore: $e');
                                              }

                                              if (ctx.mounted) {
                                                Navigator.pop(ctx);
                                                setState(() {});
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(
                                                    content: const Row(
                                                      children: [
                                                        Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                                                        SizedBox(width: 8),
                                                        Text('Caregiver profile updated! ✨'),
                                                      ],
                                                    ),
                                                    backgroundColor: const Color(0xFF00796B),
                                                    behavior: SnackBarBehavior.floating,
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius: BorderRadius.circular(12),
                                                    ),
                                                  ),
                                                );
                                              }
                                            }
                                          },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF00796B),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                    child: isSaving
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(Icons.save_rounded, size: 18),
                                              SizedBox(width: 8),
                                              Flexible(
                                                child: Text(
                                                  'Save Changes',
                                                  style: TextStyle(
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
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
                ),
              );
            },
          );
        },
      );
    }

  void _showAddPatientDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => const AnimatedLinkPatientDialog(),
    );
  }

  void _triggerForceSync() {
    _syncController.repeat();
    showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const _CaregiverSyncDialog(),
    ).then((result) {
      if (mounted) {
        _syncController.stop();
        _syncController.reset();
        setState(() {});
      }
    });
  }

  void _showAlreadySyncedDialog(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogCtx) {
        // Auto-close after 2.3 seconds
        Future.delayed(const Duration(milliseconds: 2300), () {
          if (dialogCtx.mounted && Navigator.canPop(dialogCtx)) {
            Navigator.pop(dialogCtx);
          }
        });

        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 30, 24, 24),
                child: SizedBox(
                  width: double.infinity,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00796B).withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.cloud_done_rounded,
                          color: Color(0xFF00796B),
                          size: 40,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Data Already Synced',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Everything is up to date ☁️',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.white60 : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                top: 10,
                right: 10,
                child: InkWell(
                  onTap: () {
                    if (dialogCtx.mounted && Navigator.canPop(dialogCtx)) {
                      Navigator.pop(dialogCtx);
                    }
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white10 : Colors.grey.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: isDark ? Colors.white70 : Colors.grey.shade700,
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
}

class AnimatedLinkPatientDialog extends StatefulWidget {
  const AnimatedLinkPatientDialog({super.key});

  @override
  State<AnimatedLinkPatientDialog> createState() => _AnimatedLinkPatientDialogState();
}

class _AnimatedLinkPatientDialogState extends State<AnimatedLinkPatientDialog> {
  final TextEditingController _codeController = TextEditingController();
  bool _isLoading = false;
  bool _isSuccess = false;
  String? _errorMessage;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _handleSendRequest() async {
    final code = _codeController.text.trim().toUpperCase();
    if (code.isEmpty) {
      setState(() => _errorMessage = 'Please enter the 6-character code');
      return;
    }
    if (code.length < 6) {
      setState(() => _errorMessage = 'Connect Code must be 6 characters');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final caregiverName = context.read<AppProvider>().userName ?? 'Your Caregiver';
      await context.read<FirebaseLinkService>().sendLinkRequest(code, caregiverName);

      if (mounted) {
        setState(() {
          _isLoading = false;
          _isSuccess = true;
        });

        // Show tick and success message smoothly, then auto-close
        await Future.delayed(const Duration(milliseconds: 1600));
        if (mounted) {
          Navigator.of(context).pop();
        }
      }
    } on FirebaseException catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          if (e.code == 'permission-denied') {
            _errorMessage = 'Permission Denied: Please allow "link_requests" in Firebase Console rules.';
          } else {
            _errorMessage = 'Firebase Error: ${e.message ?? e.code}';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: theme.cardColor,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOutCubic,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            transitionBuilder: (Widget child, Animation<double> animation) {
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.18, 0),
                    end: Offset.zero,
                  ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
                  child: child,
                ),
              );
            },
            child: _isSuccess ? _buildSuccessView() : _buildFormView(),
          ),
        ),
      ),
    );
  }

  Widget _buildFormView() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      key: const ValueKey('form_view'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF00796B).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.person_add_alt_1_rounded, color: Color(0xFF00796B), size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Connect Patient',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF1B3B36),
                    ),
                  ),
                  Text(
                    'Link via 6-character code',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: isDark ? Colors.white60 : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white10 : Colors.grey.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.close_rounded, size: 16, color: isDark ? Colors.white70 : Colors.grey.shade700),
              ),
              onPressed: () => Navigator.of(context).pop(),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1B2E27) : const Color(0xFFE0F2F1).withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFB2DFDB)),
          ),
          child: Row(
            children: [
              const Icon(Icons.lightbulb_outline_rounded, size: 16, color: Color(0xFF00796B)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Ask your patient for the Connect Code found in their Profile tab.',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: isDark ? Colors.white70 : const Color(0xFF004D40),
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        TextField(
          controller: _codeController,
          textCapitalization: TextCapitalization.characters,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: 6,
            color: Color(0xFF00796B),
          ),
          decoration: InputDecoration(
            hintText: 'e.g. A1B2C3',
            hintStyle: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.normal,
              letterSpacing: 1,
              color: isDark ? Colors.white30 : Colors.grey.shade400,
            ),
            filled: true,
            fillColor: isDark ? const Color(0xFF263238) : const Color(0xFFF8FAF9),
            contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: isDark ? Colors.white12 : Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: isDark ? Colors.white12 : Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFF00796B), width: 2),
            ),
          ),
        ),
        if (_errorMessage != null) ...[
          const SizedBox(height: 12),
          Builder(
            builder: (context) {
              final isAlreadySent = _errorMessage!.toLowerCase().contains('already sent') ||
                  _errorMessage!.toLowerCase().contains('already linked');
              final bgColor = isAlreadySent
                  ? (isDark ? const Color(0xFF2E1F12) : Colors.amber.shade50)
                  : (isDark ? const Color(0xFF2E1416) : Colors.red.shade50);
              final borderColor = isAlreadySent
                  ? (isDark ? Colors.amber.shade700 : Colors.amber.shade300)
                  : (isDark ? Colors.red.shade700 : Colors.red.shade200);
              final iconColor = isAlreadySent
                  ? (isDark ? Colors.amber.shade300 : Colors.amber.shade900)
                  : (isDark ? Colors.red.shade300 : Colors.red);
              final textColor = isAlreadySent
                  ? (isDark ? Colors.amber.shade200 : Colors.amber.shade900)
                  : (isDark ? Colors.red.shade200 : Colors.red.shade800);

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderColor),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      isAlreadySent ? Icons.schedule_send_rounded : Icons.error_outline_rounded,
                      color: iconColor,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(fontSize: 12, color: textColor, fontWeight: FontWeight.w600, height: 1.3),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  side: BorderSide(color: isDark ? Colors.white24 : Colors.grey.shade300),
                ),
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    color: isDark ? Colors.white70 : Colors.grey.shade700,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleSendRequest,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00796B),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.send_rounded, size: 16),
                          SizedBox(width: 6),
                          Text('Send Request', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSuccessView() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      key: const ValueKey('success_view'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 12),
        TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0.2, end: 1.0),
          duration: const Duration(milliseconds: 650),
          curve: Curves.elasticOut,
          builder: (context, scale, child) {
            return Transform.scale(
              scale: scale,
              child: child,
            );
          },
          child: Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1B2E24) : const Color(0xFFE8F5E9),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF81C784), width: 2.5),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF4CAF50).withValues(alpha: 0.22),
                  blurRadius: 18,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: const Icon(
              Icons.check_rounded,
              size: 48,
              color: Color(0xFF2E7D32),
            ),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'Request Sent! 🤝',
          style: TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : const Color(0xFF1B3B36),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Connection request sent to patient.\nThey can accept it from their notification drawer to complete linking.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12.5,
            color: isDark ? Colors.white60 : Colors.grey.shade600,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

class _CaregiverSyncDialog extends StatefulWidget {
  const _CaregiverSyncDialog();

  @override
  State<_CaregiverSyncDialog> createState() => _CaregiverSyncDialogState();
}

class _CaregiverSyncDialogState extends State<_CaregiverSyncDialog> with SingleTickerProviderStateMixin {
  late AnimationController _spinController;
  bool _isDone = false;
  String _title = "Syncing with Cloud...";
  String _subtitle = "Refreshing caregiver telemetry & patient data";

  @override
  void initState() {
    super.initState();
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
    _startSync();
  }

  @override
  void dispose() {
    _spinController.dispose();
    super.dispose();
  }

  Future<void> _startSync() async {
    final hive = context.read<HiveService>();
    final syncService = SyncService(hive);
    final success = await syncService.syncLocalDataToCloud();
    if (mounted) {
      if (success) {
        context.read<AppProvider>().setSyncStatus(true);
        setState(() {
          _isDone = true;
          _title = "Synced Successfully!";
          _subtitle = "Caregiver data is updated and saved securely.";
        });
        await Future.delayed(const Duration(milliseconds: 1400));
        if (mounted) Navigator.of(context).pop(true);
      } else {
        setState(() {
          _title = "Sync Failed";
          _subtitle = "Check your internet connection and try again.";
        });
        await Future.delayed(const Duration(milliseconds: 1800));
        if (mounted) Navigator.of(context).pop(false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              transitionBuilder: (Widget child, Animation<double> animation) {
                return ScaleTransition(scale: animation, child: child);
              },
              child: _isDone
                  ? Container(
                      key: const ValueKey('done'),
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check_circle_rounded, color: Colors.green, size: 56),
                    )
                  : Stack(
                      key: const ValueKey('syncing'),
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 80,
                          height: 80,
                          child: CircularProgressIndicator(
                            strokeWidth: 4,
                            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF00796B)),
                            backgroundColor: const Color(0xFF00796B).withValues(alpha: 0.15),
                          ),
                        ),
                        RotationTransition(
                          turns: _spinController,
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFF00796B).withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.sync_rounded,
                              color: Color(0xFF00796B),
                              size: 32,
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: 20),
            Text(
              _title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white60 : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}


  // --- Interactive Trend Analytics Sheet with Visual Chart ---
  void _showTrendDetailsSheet({
    required BuildContext context,
    required String patientName,
    required List<Map<String, dynamic>> sessionMaps,
    required String trendText,
    required Color trendColor,
    required IconData trendIcon,
    required int avgAcc,
    required bool isDark,
  }) => showCaregiverTrendDetailsSheet(
    context: context,
    patientName: patientName,
    sessionMaps: sessionMaps,
    trendText: trendText,
    trendColor: trendColor,
    trendIcon: trendIcon,
    avgAcc: avgAcc,
    isDark: isDark,
  );

  void showCaregiverTrendDetailsSheet({
    required BuildContext context,
    required String patientName,
    required List<Map<String, dynamic>> sessionMaps,
    required String trendText,
    required Color trendColor,
    required IconData trendIcon,
    required int avgAcc,
    required bool isDark,
  }) {
    final mediaQuery = MediaQuery.of(context);
    final screenH = mediaQuery.size.height;
    final screenW = mediaQuery.size.width;
    final isSmall = screenW < 360;
    final sheetBg = isDark ? const Color(0xFF131A18) : Colors.white;
    final cardBg = isDark ? const Color(0xFF1A2422) : const Color(0xFFF8FAFA);
    final cardBorder = isDark ? const Color(0xFF293B37) : const Color(0xFFE2ECE8);
    final titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subtitleColor = isDark ? Colors.white60 : const Color(0xFF64748B);

    // Extract chronological accuracy values (oldest to newest for proper trend direction)
    // Limit to latest 7 sessions for clean spacing on any screen width
    final recentSessions = sessionMaps.take(7).toList();
    final List<double> chartAccuracies = [
      for (var s in recentSessions.reversed)
        ((s['accuracyPercentage'] ?? 0) as num).toDouble(),
    ];

    double maxAcc = 0;
    for (var a in chartAccuracies) {
      if (a > maxAcc) maxAcc = a;
    }

    final dynamicInsight = _buildDynamicCognitiveInsight(
      patientName: patientName,
      trendText: trendText,
      avgAcc: avgAcc,
      maxAcc: maxAcc,
      sessionMaps: sessionMaps,
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final mq = MediaQuery.of(ctx);
        final parentMq = MediaQuery.of(context);
        final bottomInset = mq.viewPadding.bottom > 0
            ? mq.viewPadding.bottom
            : (parentMq.viewPadding.bottom > 0
                ? parentMq.viewPadding.bottom
                : (mq.padding.bottom > 0 ? mq.padding.bottom : parentMq.padding.bottom));

        return ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 560,
            maxHeight: screenH * 0.90,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: sheetBg,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.16),
                  blurRadius: 28,
                  offset: const Offset(0, -6),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 1. Drag Handle & Modern Header Banner
                Padding(
                  padding: EdgeInsets.fromLTRB(isSmall ? 16 : 20, 12, isSmall ? 12 : 16, 12),
                  child: Column(
                    children: [
                      Center(
                        child: Container(
                          width: 42,
                          height: 4.5,
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white24 : const Color(0xFFCFDCD8),
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: trendColor.withValues(alpha: isDark ? 0.20 : 0.12),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: trendColor.withValues(alpha: isDark ? 0.35 : 0.25),
                                width: 1.2,
                              ),
                            ),
                            child: Center(
                              child: Icon(trendIcon, color: trendColor, size: 22),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Performance Trend & Graph',
                                  style: TextStyle(
                                    fontSize: isSmall ? 16 : 17.5,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.3,
                                    color: titleColor,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2.5),
                                Text(
                                  'Real-time cognitive trajectory • $patientName',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w500,
                                    color: subtitleColor,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.04),
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              icon: Icon(Icons.close_rounded, size: 20, color: isDark ? Colors.white70 : const Color(0xFF64748B)),
                              padding: const EdgeInsets.all(8),
                              constraints: const BoxConstraints(),
                              onPressed: () => Navigator.pop(ctx),
                              tooltip: 'Close',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: isDark ? const Color(0xFF243330) : const Color(0xFFE8EFEF)),

                // 2. Scrollable Body
                Flexible(
                  child: SafeArea(
                    top: false,
                    bottom: true,
                    minimum: const EdgeInsets.only(bottom: 16),
                    child: ListView(
                      padding: EdgeInsets.fromLTRB(
                        isSmall ? 16 : 20,
                        16,
                        isSmall ? 16 : 20,
                        8.0 + (bottomInset > 0 ? 4.0 : 0.0),
                      ),
                      children: [
                        // 3 Summary Metric Badges
                        Row(
                          children: [
                            Expanded(
                              child: _buildTrendStatBadge(
                                title: 'Current Trend',
                                value: trendText.split('(').first.trim(),
                                badgeColor: trendColor,
                                isDark: isDark,
                                icon: trendIcon,
                              ),
                            ),
                            SizedBox(width: isSmall ? 6 : 8),
                            Expanded(
                              child: _buildTrendStatBadge(
                                title: 'Avg Accuracy',
                                value: '$avgAcc%',
                                badgeColor: const Color(0xFF00897B),
                                isDark: isDark,
                                icon: Icons.speed_rounded,
                              ),
                            ),
                            SizedBox(width: isSmall ? 6 : 8),
                            Expanded(
                              child: _buildTrendStatBadge(
                                title: 'Peak Score',
                                value: '${maxAcc.round()}%',
                                badgeColor: const Color(0xFF2563EB),
                                isDark: isDark,
                                icon: Icons.emoji_events_rounded,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Visual Performance Chart Card
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: cardBorder, width: 1.1),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.03),
                                blurRadius: 12,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF00796B).withValues(alpha: isDark ? 0.2 : 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(Icons.insights_rounded, size: 16, color: Color(0xFF00796B)),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Session Accuracy',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w800,
                                            color: titleColor,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 1),
                                        Text(
                                          'Chronological accuracy (%) across last ${chartAccuracies.length} exercises',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: subtitleColor,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: trendColor.withValues(alpha: isDark ? 0.2 : 0.12),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: trendColor.withValues(alpha: 0.3), width: 1),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          width: 6,
                                          height: 6,
                                          decoration: BoxDecoration(
                                            color: trendColor,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 5),
                                        Text(
                                          trendText,
                                          style: TextStyle(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.bold,
                                            color: trendColor,
                                          ),
                                          maxLines: 1,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              // Chart Canvas
                              ClipRect(
                                child: SizedBox(
                                  width: double.infinity,
                                  height: 165,
                                  child: CustomPaint(
                                    painter: _TrendPerformanceChartPainter(
                                      accuracies: chartAccuracies,
                                      lineColor: trendColor,
                                      isDark: isDark,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // AI Clinical Interpretation Card (Dynamic based on Trend & Performance)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: trendColor.withValues(alpha: isDark ? 0.12 : 0.07),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: trendColor.withValues(alpha: isDark ? 0.35 : 0.28),
                              width: 1.1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: trendColor.withValues(alpha: isDark ? 0.22 : 0.14),
                                      borderRadius: BorderRadius.circular(9),
                                    ),
                                    child: Icon(Icons.psychology_alt_rounded, size: 18, color: trendColor),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Cognitive Assessment Insight',
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w800,
                                        color: trendColor,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                    decoration: BoxDecoration(
                                      color: trendColor.withValues(alpha: isDark ? 0.2 : 0.12),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.auto_awesome_rounded, size: 10, color: trendColor),
                                        const SizedBox(width: 3),
                                        Text(
                                          'AI Telemetry',
                                          style: TextStyle(
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 0.3,
                                            color: trendColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                dynamicInsight,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  height: 1.45,
                                  color: isDark ? Colors.white70 : const Color(0xFF1E293B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),

                        // Recent Sessions List Section Header
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                'Recent Sessions Breakdown',
                                style: TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w800,
                                  color: titleColor,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (sessionMaps.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '${sessionMaps.take(5).length} latest',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w600,
                                    color: subtitleColor,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Session Cards (with GameHubIllustration)
                        if (sessionMaps.isEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1B2624) : Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isDark ? const Color(0xFF2B3D39) : const Color(0xFFE2ECE8),
                                width: 1.15,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: isDark ? 0.20 : 0.03),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFF1F5F9),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(Icons.history_rounded, size: 32, color: subtitleColor),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    'No recorded sessions yet',
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w700,
                                      color: titleColor,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Completed cognitive exercises will appear here with game breakdowns.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontSize: 11.5, color: subtitleColor, height: 1.35),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          ...sessionMaps.take(5).map((s) {
                            final acc = (s['accuracyPercentage'] ?? 0) as num;
                            final lvl = s['difficultyLevel'] ?? 1;
                            final gameId = (s['gameId'] ?? 'game').toString();
                            final durationSec = (s['completionTimeSeconds'] as num?)?.toInt();
                            final dateStr = _formatTrendSessionTimestamp(s['timestamp']);

                            GameHubVisual? visual;
                            IconData fallbackIcon;
                            String gameTitle;
                            Color accentColor;
                            Color iconBg;
                            Color iconBorder;

                            if (gameId == 'face_recall') {
                              visual = GameHubVisual.faceRecall;
                              fallbackIcon = Icons.family_restroom_rounded;
                              gameTitle = 'Face Recall';
                              accentColor = const Color(0xFFD97706);
                              iconBg = isDark ? const Color(0xFF2E2314) : const Color(0xFFFFFBEB);
                              iconBorder = isDark ? Colors.white12 : const Color(0xFFFDE68A);
                            } else if (gameId == 'memory_match') {
                              visual = GameHubVisual.memoryMatch;
                              fallbackIcon = Icons.psychology_rounded;
                              gameTitle = 'Memory Match';
                              accentColor = const Color(0xFFD81B60);
                              iconBg = isDark ? const Color(0xFF2E1420) : const Color(0xFFFFF5F7);
                              iconBorder = isDark ? Colors.white12 : const Color(0xFFFED7E2);
                            } else if (gameId == 'pattern_path') {
                              visual = GameHubVisual.patternPath;
                              fallbackIcon = Icons.extension_rounded;
                              gameTitle = 'Pattern Path';
                              accentColor = const Color(0xFF16A34A);
                              iconBg = isDark ? const Color(0xFF122E1F) : const Color(0xFFF0FDF4);
                              iconBorder = isDark ? Colors.white12 : const Color(0xFFBBF7D0);
                            } else if (gameId == 'memory_recall') {
                              visual = GameHubVisual.memoryRecall;
                              fallbackIcon = Icons.history_edu_rounded;
                              gameTitle = 'Memory Recall';
                              accentColor = const Color(0xFF2563EB);
                              iconBg = isDark ? const Color(0xFF142238) : const Color(0xFFF0F4F8);
                              iconBorder = isDark ? Colors.white12 : const Color(0xFFD1E2EE);
                            } else {
                              visual = null;
                              fallbackIcon = Icons.sports_esports_rounded;
                              gameTitle = (s['gameCategory'] ?? gameId.replaceAll('_', ' ')).toString();
                              gameTitle = gameTitle
                                  .split(' ')
                                  .map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '')
                                  .join(' ');
                              accentColor = const Color(0xFF00796B);
                              iconBg = isDark ? const Color(0xFF122824) : const Color(0xFFE0F2F1);
                              iconBorder = isDark ? Colors.white12 : const Color(0xFFB2DFDB);
                            }

                            Color accTextColor;
                            Color accBgColor;
                            Color accBorderColor;
                            if (acc >= 75) {
                              accTextColor = const Color(0xFF16A34A);
                              accBgColor = isDark ? const Color(0xFF132D1F) : const Color(0xFFE8F5E9);
                              accBorderColor = isDark ? const Color(0xFF1D5235) : const Color(0xFFC8E6C9);
                            } else if (acc >= 50) {
                              accTextColor = const Color(0xFFD97706);
                              accBgColor = isDark ? const Color(0xFF2E2010) : const Color(0xFFFFF3E0);
                              accBorderColor = isDark ? const Color(0xFF523919) : const Color(0xFFFFE0B2);
                            } else {
                              accTextColor = const Color(0xFFDC2626);
                              accBgColor = isDark ? const Color(0xFF2E1214) : const Color(0xFFFFEBEE);
                              accBorderColor = isDark ? const Color(0xFF571E24) : const Color(0xFFFFCDD2);
                            }

                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1B2624) : Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isDark ? const Color(0xFF2B3D39) : const Color(0xFFE2ECE8),
                                  width: 1.15,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: isDark ? 0.20 : 0.03),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  // Game Visual Container (Exact GameHubVisual illustration)
                                  Container(
                                    width: 46,
                                    height: 46,
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: iconBg,
                                      borderRadius: BorderRadius.circular(13),
                                      border: Border.all(color: iconBorder, width: 1.2),
                                    ),
                                    child: Center(
                                      child: visual != null
                                          ? GameHubIllustration(visual: visual, size: 36)
                                          : Icon(fallbackIcon, color: accentColor, size: 22),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          gameTitle,
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: -0.2,
                                            color: titleColor,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                              decoration: BoxDecoration(
                                                color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFF1F5F9),
                                                borderRadius: BorderRadius.circular(5),
                                              ),
                                              child: Text(
                                                'Level $lvl',
                                                style: TextStyle(
                                                  fontSize: 10.5,
                                                  fontWeight: FontWeight.w700,
                                                  color: isDark ? Colors.white70 : const Color(0xFF475569),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            if (durationSec != null && durationSec > 0) ...[
                                              Icon(
                                                Icons.timer_outlined,
                                                size: 11.5,
                                                color: subtitleColor,
                                              ),
                                              const SizedBox(width: 3),
                                              Text(
                                                '${durationSec}s',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w500,
                                                  color: subtitleColor,
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                            ],
                                            Expanded(
                                              child: Text(
                                                dateStr,
                                                style: TextStyle(
                                                  fontSize: 10.5,
                                                  fontWeight: FontWeight.w500,
                                                  color: subtitleColor,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4.5),
                                    decoration: BoxDecoration(
                                      color: accBgColor,
                                      borderRadius: BorderRadius.circular(9),
                                      border: Border.all(color: accBorderColor, width: 1.0),
                                    ),
                                    child: Text(
                                      '${acc.round()}%',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: -0.2,
                                        color: accTextColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        // Comfortable trailing breathing room ensuring the last card is never obscured
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _buildDynamicCognitiveInsight({
    required String patientName,
    required String trendText,
    required int avgAcc,
    required double maxAcc,
    required List<Map<String, dynamic>> sessionMaps,
  }) {
    if (sessionMaps.isEmpty) {
      return 'No cognitive sessions recorded yet for $patientName. Encourage completing 10-15 minutes of daily brain exercises to start tracking baseline cognitive trajectory.';
    }

    final isImproving = trendText.contains('Improving') || trendText.contains('+');
    final isAttention = trendText.contains('Attention') || trendText.contains('Declining') || trendText.contains('-');
    final latestAcc = sessionMaps.isNotEmpty ? ((sessionMaps.first['accuracyPercentage'] ?? 0) as num).round() : avgAcc;

    if (sessionMaps.length < 3) {
      return '$patientName is establishing an early cognitive baseline with an average accuracy of $avgAcc% (Peak: ${maxAcc.round()}%). Complete at least 3-5 sessions across the week to unlock comprehensive predictive trends.';
    }

    if (isImproving) {
      if (avgAcc >= 80) {
        return '$patientName is showing outstanding cognitive neuroplasticity! Accuracy has reached $avgAcc% (Peak: ${maxAcc.round()}%), demonstrating heightened pattern retention, sharper working memory, and quicker visual reaction times. Continue daily reinforcement!';
      } else if (avgAcc >= 60) {
        return 'Solid upward cognitive trajectory detected for $patientName. Session accuracy has improved to $latestAcc%, reflecting better focus and adaptability. Consistent 10-15 minute daily exercises will solidify these cognitive gains.';
      } else {
        return '$patientName is making positive incremental recovery. While baseline accuracy is currently $avgAcc%, recent sessions reflect steady upward momentum. Gentle positive encouragement helps build mental stamina.';
      }
    } else if (isAttention) {
      if (avgAcc < 50) {
        return 'Recent sessions indicate cognitive fatigue or task difficulty overload (Avg: $avgAcc%, Latest: $latestAcc%). We recommend scheduling short 5-minute sessions during peak morning alertness, ensuring calm hydration and zero distractions.';
      } else {
        return 'A minor dip in accuracy was observed in recent exercises for $patientName. This is normal during neuro-rehab cycles. Consider revisiting familiar game levels to boost confidence before increasing difficulty.';
      }
    } else {
      // Stable baseline
      if (avgAcc >= 75) {
        return '$patientName maintains a remarkably stable and resilient cognitive performance at $avgAcc% accuracy (Peak: ${maxAcc.round()}%). Working memory and visual processing remain steady across all sessions.';
      } else {
        return '$patientName is maintaining a consistent cognitive baseline around $avgAcc%. To stimulate new neural pathways and promote progress, try introducing diverse cognitive games such as image recall and spatial orientation.';
      }
    }
  }

  String _formatTrendSessionTimestamp(dynamic timestamp) {
    DateTime? dt;
    if (timestamp == null) return 'Recent';
    if (timestamp is Timestamp) {
      dt = timestamp.toDate();
    } else if (timestamp is DateTime) {
      dt = timestamp;
    } else if (timestamp is String) {
      dt = DateTime.tryParse(timestamp);
    } else if (timestamp is int) {
      dt = DateTime.fromMillisecondsSinceEpoch(timestamp);
    }

    if (dt == null) return 'Recent';
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24 && dt.day == now.day) {
      return '${diff.inHours}h ago';
    } else if (diff.inDays < 2) {
      return 'Yesterday';
    } else {
      return '${dt.day}/${dt.month}';
    }
  }

  Widget _buildTrendStatBadge({
    required String title,
    required String value,
    required Color badgeColor,
    required bool isDark,
    IconData? icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: isDark ? 0.12 : 0.07),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: badgeColor.withValues(alpha: isDark ? 0.32 : 0.22), width: 1.1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 12, color: badgeColor),
                const SizedBox(width: 4),
              ],
              Expanded(
                child: Text(
                  title.toUpperCase(),
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                    color: isDark ? Colors.white60 : const Color(0xFF64748B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w800,
                color: badgeColor,
              ),
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }


class _CaregiverIllustrationPainter extends CustomPainter {
  const _CaregiverIllustrationPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Soft mint background glow/circle
    final bgPaint = Paint()
      ..color = const Color(0xFFE0F2F1).withValues(alpha: 0.55)
      ..style = PaintingStyle.fill;
    canvas.drawOval(
      Rect.fromCenter(center: Offset(w * 0.58, h * 0.60), width: w * 0.76, height: h * 0.65),
      bgPaint,
    );

    // Floating teal/mint heart balloons
    _drawHeart(canvas, Offset(w * 0.78, h * 0.20), w * 0.11, const Color(0xFF80CBC4));
    _drawHeart(canvas, Offset(w * 0.94, h * 0.32), w * 0.13, const Color(0xFF4DB6AC));
    _drawHeart(canvas, Offset(w * 0.60, h * 0.12), w * 0.08, const Color(0xFF81C784));
    _drawHeart(canvas, Offset(w * 0.35, h * 0.22), w * 0.07, const Color(0xFF26A69A));

    // Elderly Patient (Left)
    // Body / Cardigan (soft sage green)
    final patientBody = Path()
      ..moveTo(w * 0.22, h * 0.98)
      ..quadraticBezierTo(w * 0.24, h * 0.72, w * 0.38, h * 0.68)
      ..quadraticBezierTo(w * 0.52, h * 0.72, w * 0.54, h * 0.98)
      ..close();
    canvas.drawPath(patientBody, Paint()..color = const Color(0xFF81C784));

    // Patient Head
    final patientHeadCenter = Offset(w * 0.38, h * 0.56);
    canvas.drawCircle(patientHeadCenter, w * 0.15, Paint()..color = const Color(0xFFFFCCBC));

    // Patient Silver/Grey Hair
    final patientHair = Path()
      ..addArc(Rect.fromCircle(center: patientHeadCenter, radius: w * 0.155), -3.14, 3.14)
      ..close();
    canvas.drawPath(patientHair, Paint()..color = const Color(0xFFCFD8DC));
    // Hair bun
    canvas.drawCircle(Offset(w * 0.28, h * 0.46), w * 0.07, Paint()..color = const Color(0xFFB0BEC5));

    // Patient Glasses (Round wireframe)
    final glassPaint = Paint()
      ..color = const Color(0xFF607D8B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    canvas.drawCircle(Offset(w * 0.35, h * 0.56), w * 0.045, glassPaint);
    canvas.drawCircle(Offset(w * 0.44, h * 0.56), w * 0.045, glassPaint);
    canvas.drawLine(Offset(w * 0.395, h * 0.56), Offset(w * 0.405, h * 0.56), glassPaint);

    // Patient smile
    final pSmile = Path()
      ..addArc(Rect.fromCircle(center: Offset(w * 0.395, h * 0.62), radius: w * 0.03), 0.2, 2.7);
    canvas.drawPath(pSmile, glassPaint);

    // Caregiver (Right)
    // Body / Top (Assam Emerald Teal)
    final cgBody = Path()
      ..moveTo(w * 0.48, h * 0.98)
      ..quadraticBezierTo(w * 0.52, h * 0.64, w * 0.68, h * 0.62)
      ..quadraticBezierTo(w * 0.84, h * 0.66, w * 0.88, h * 0.98)
      ..close();
    canvas.drawPath(cgBody, Paint()..color = const Color(0xFF00796B));

    // Caregiver Head
    final cgHeadCenter = Offset(w * 0.68, h * 0.48);
    canvas.drawCircle(cgHeadCenter, w * 0.15, Paint()..color = const Color(0xFFFFD180));

    // Caregiver Hair (Dark brown, styled)
    final cgHair = Path()
      ..addArc(Rect.fromCircle(center: cgHeadCenter, radius: w * 0.16), -3.2, 3.4)
      ..quadraticBezierTo(w * 0.84, h * 0.58, w * 0.82, h * 0.70)
      ..lineTo(w * 0.78, h * 0.65)
      ..close();
    canvas.drawPath(cgHair, Paint()..color = const Color(0xFF3E2723));

    // Caregiver Face details
    final cgEyePaint = Paint()..color = const Color(0xFF3E2723);
    canvas.drawCircle(Offset(w * 0.64, h * 0.48), 1.5, cgEyePaint);
    canvas.drawCircle(Offset(w * 0.72, h * 0.48), 1.5, cgEyePaint);
    final cgSmile = Path()
      ..addArc(Rect.fromCircle(center: Offset(w * 0.68, h * 0.53), radius: w * 0.035), 0.2, 2.7);
    canvas.drawPath(cgSmile, Paint()..color = const Color(0xFFD84315)..style = PaintingStyle.stroke..strokeWidth = 1.4);

    // Supportive embrace arm
    final armPath = Path()
      ..moveTo(w * 0.55, h * 0.76)
      ..quadraticBezierTo(w * 0.42, h * 0.82, w * 0.35, h * 0.80);
    canvas.drawPath(
      armPath,
      Paint()
        ..color = const Color(0xFF00695C)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round,
    );
  }

  void _drawHeart(Canvas canvas, Offset center, double size, Color color) {
    final path = Path();
    final w = size;
    final h = size;
    path.moveTo(center.dx, center.dy + h * 0.35);
    path.cubicTo(center.dx - w * 0.55, center.dy - h * 0.25, center.dx - w * 0.55, center.dy - h * 0.70, center.dx, center.dy - h * 0.40);
    path.cubicTo(center.dx + w * 0.55, center.dy - h * 0.70, center.dx + w * 0.55, center.dy - h * 0.25, center.dx, center.dy + h * 0.35);
    path.close();
    canvas.drawPath(path, Paint()..color = color..style = PaintingStyle.fill);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}


class _TrendPerformanceChartPainter extends CustomPainter {
  final List<double> accuracies;
  final Color lineColor;
  final bool isDark;

  _TrendPerformanceChartPainter({
    required this.accuracies,
    required this.lineColor,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (accuracies.isEmpty) {
      final textSpan = TextSpan(
        text: 'No session data recorded yet',
        style: TextStyle(
          color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      );
      final tp = TextPainter(text: textSpan, textDirection: TextDirection.ltr);
      tp.layout();
      tp.paint(canvas, Offset((size.width - tp.width) / 2, (size.height - tp.height) / 2));
      return;
    }

    final double left = 32.0;
    final double right = size.width - 12.0;
    final double top = 20.0;
    final double bottom = size.height - 24.0;
    final double chartW = right - left;
    final double chartH = bottom - top;

    final gridPaint = Paint()
      ..color = (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05))
      ..strokeWidth = 1.0;

    // Horizontal guideline steps (0%, 25%, 50%, 75%, 100%) aligned to chart coordinates
    const steps = [0.0, 0.25, 0.50, 0.75, 1.0];
    for (var step in steps) {
      final y = bottom - (chartH * step);
      canvas.drawLine(Offset(left, y), Offset(right, y), gridPaint);

      if (step > 0 && step <= 1.0) {
        final labelSpan = TextSpan(
          text: '${(step * 100).toInt()}%',
          style: TextStyle(
            color: isDark ? Colors.white30 : const Color(0xFF94A3B8),
            fontSize: 8.0,
            fontWeight: FontWeight.w600,
          ),
        );
        final ltp = TextPainter(text: labelSpan, textDirection: TextDirection.ltr);
        ltp.layout();
        ltp.paint(canvas, Offset(left - ltp.width - 4, y - (ltp.height / 2)));
      }
    }

    final List<Offset> points = [];
    final int count = accuracies.length;
    final double dx = count > 1 ? chartW / (count - 1) : chartW / 2;

    for (int i = 0; i < count; i++) {
      final acc = accuracies[i].clamp(0.0, 100.0);
      final x = count > 1 ? left + (i * dx) : left + (chartW / 2);
      final y = bottom - (chartH * (acc / 100.0));
      points.add(Offset(x, y));
    }

    // Gradient Fill under the line
    if (points.length > 1) {
      final path = Path();
      path.moveTo(points.first.dx, bottom);
      path.lineTo(points.first.dx, points.first.dy);

      for (int i = 0; i < points.length - 1; i++) {
        final p0 = points[i];
        final p1 = points[i + 1];
        final midX = (p0.dx + p1.dx) / 2;
        path.cubicTo(midX, p0.dy, midX, p1.dy, p1.dx, p1.dy);
      }

      path.lineTo(points.last.dx, bottom);
      path.close();

      final fillPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            lineColor.withValues(alpha: isDark ? 0.35 : 0.25),
            lineColor.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromLTRB(left, top, right, bottom));
      canvas.drawPath(path, fillPaint);
    }

    // Stroke Path
    final strokePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    if (points.length == 1) {
      canvas.drawCircle(points.first, 6, strokePaint);
    } else {
      final linePath = Path();
      linePath.moveTo(points.first.dx, points.first.dy);
      for (int i = 0; i < points.length - 1; i++) {
        final p0 = points[i];
        final p1 = points[i + 1];
        final midX = (p0.dx + p1.dx) / 2;
        linePath.cubicTo(midX, p0.dy, midX, p1.dy, p1.dx, p1.dy);
      }
      canvas.drawPath(linePath, strokePaint);
    }

    // Draw Points & Value Badges with glowing halos
    final haloPaint = Paint()..color = lineColor.withValues(alpha: 0.20);
    final dotPaint = Paint()..color = isDark ? const Color(0xFF141C1A) : Colors.white;
    final dotBorderPaint = Paint()
      ..color = lineColor
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < points.length; i++) {
      final pt = points[i];
      // Soft glowing halo
      canvas.drawCircle(pt, 7.5, haloPaint);
      // Center fill
      canvas.drawCircle(pt, 4.5, dotPaint);
      // Border ring
      canvas.drawCircle(pt, 4.5, dotBorderPaint);

      // Value text above dot
      final textSpan = TextSpan(
        text: '${accuracies[i].round()}%',
        style: TextStyle(
          color: isDark ? Colors.white : const Color(0xFF0F172A),
          fontSize: 9.5,
          fontWeight: FontWeight.bold,
        ),
      );
      final tp = TextPainter(text: textSpan, textDirection: TextDirection.ltr);
      tp.layout();
      tp.paint(canvas, Offset(pt.dx - (tp.width / 2), pt.dy - 16));

      // X axis session label below dot
      final xSpan = TextSpan(
        text: 'S${i + 1}',
        style: TextStyle(
          color: isDark ? Colors.white54 : const Color(0xFF64748B),
          fontSize: 9.0,
          fontWeight: FontWeight.w600,
        ),
      );
      final xtp = TextPainter(text: xSpan, textDirection: TextDirection.ltr);
      xtp.layout();
      xtp.paint(canvas, Offset(pt.dx - (xtp.width / 2), bottom + 4));
    }
  }

  @override
  bool shouldRepaint(covariant _TrendPerformanceChartPainter oldDelegate) {
    return oldDelegate.accuracies != accuracies || oldDelegate.lineColor != lineColor;
  }
}
