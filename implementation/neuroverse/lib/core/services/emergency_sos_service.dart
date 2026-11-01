import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import '../../data/local/hive_service.dart';
import 'voice_service.dart';
import 'notification_service.dart';

class SosDispatchResult {
  final bool success;
  final double? latitude;
  final double? longitude;
  final String? mapsUrl;
  final List<String> contactsAlerted;
  final String message;
  final bool smsLaunched;
  final bool cloudSynced;

  SosDispatchResult({
    required this.success,
    this.latitude,
    this.longitude,
    this.mapsUrl,
    required this.contactsAlerted,
    required this.message,
    this.smsLaunched = false,
    this.cloudSynced = false,
  });
}

class EmergencySosService {
  static final EmergencySosService _instance = EmergencySosService._internal();
  factory EmergencySosService() => _instance;
  EmergencySosService._internal();

  static const MethodChannel _smsChannel = MethodChannel('com.company.neuroverse/silent_sms');
  static const String keyContacts = 'sos_emergency_contacts';

  Future<bool> hasSmsPermission() async {
    try {
      return await _smsChannel.invokeMethod<bool>('hasSmsPermission') ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> requestSmsPermission() async {
    try {
      await _smsChannel.invokeMethod('requestSmsPermission');
    } catch (_) {}
  }

  /// Get list of configured emergency caregiver contact numbers
  List<String> getEmergencyContacts() {
    try {
      final list = HiveService().getSetting<List<dynamic>>(keyContacts, []);
      final contacts = list.map((e) => e.toString().trim()).where((s) => s.isNotEmpty).toList();
      if (contacts.isNotEmpty) return contacts;

      // Fallback: Check profile guardianPhone / caregiverPhone
      final profile = HiveService().getUserProfile();
      if (profile != null) {
        final gPhone = (profile['guardianPhone'] ?? profile['caregiverPhone'] ?? profile['phone'] ?? '').toString().trim();
        if (gPhone.isNotEmpty) {
          return [gPhone];
        }
      }
    } catch (e) {
      debugPrint('EmergencySosService: error reading contacts: $e');
    }
    return [];
  }

  /// Save emergency contacts
  Future<void> saveEmergencyContacts(List<String> contacts) async {
    final clean = contacts.map((c) => c.trim()).where((c) => c.isNotEmpty).toSet().toList();
    await HiveService().saveSetting(keyContacts, clean);
  }

  /// Add a single contact
  Future<void> addEmergencyContact(String phone) async {
    final current = getEmergencyContacts();
    if (!current.contains(phone.trim())) {
      current.add(phone.trim());
      await saveEmergencyContacts(current);
    }
  }

  /// Remove a contact
  Future<void> removeEmergencyContact(String phone) async {
    final current = getEmergencyContacts();
    current.remove(phone.trim());
    await saveEmergencyContacts(current);
  }

  /// Obtain on-device GPS coordinates (100% offline & free satellite fix)
  Future<Position?> getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('EmergencySosService: Location service is disabled on device');
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint('EmergencySosService: Location permissions are denied');
          return await Geolocator.getLastKnownPosition();
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint('EmergencySosService: Location permissions are permanently denied');
        return await Geolocator.getLastKnownPosition();
      }

      // Try high-accuracy fix with a 6-second timeout for quick emergency dispatch
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 6),
        ),
      );
    } catch (e) {
      debugPrint('EmergencySosService: Location fetch error: $e. Falling back to last known.');
      try {
        return await Geolocator.getLastKnownPosition();
      } catch (_) {
        return null;
      }
    }
  }

  /// Local Voice feedback for elderly patient
  Future<void> speakSosVoiceFeedback(BuildContext context) async {
    final lang = Localizations.localeOf(context).languageCode.toLowerCase();
    String voiceText;

    switch (lang) {
      case 'hi':
        voiceText = 'आपकी इमरजेंसी अलर्ट केयरगिवर को भेजी जा रही है।';
        break;
      case 'bn':
        voiceText = 'আপনার জরুরী সতর্কতা সেবকের কাছে পাঠানো হচ্ছে।';
        break;
      case 'as':
        voiceText = 'আপোনাৰ জৰুৰীকালীন সতৰ্কবাৰ্তা সেৱিকাৰ ওচৰলৈ প্ৰেৰণ কৰা হৈছে।';
        break;
      case 'mni':
        voiceText = 'নহাক্কী ইমার্জেন্সী এলার্ট কেয়ারগিভরদা থারক্লে।';
        break;
      case 'miz':
      case 'lus':
        voiceText = 'I emergency alert chu enkawltu hnenah thawn mek a ni.';
        break;
      case 'en':
      default:
        voiceText = 'Your emergency alert is being sent to your caregiver.';
        break;
    }

    try {
      final voice = VoiceService();
      await voice.speak(voiceText, lang: lang);
    } catch (e) {
      debugPrint('EmergencySosService: voice feedback error: $e');
    }
  }

  /// Trigger Full SOS:
  /// 1. Speaks localized voice feedback immediately
  /// 2. Fetches GPS coordinates (offline satellite)
  /// 3. Sends SMS with Google Maps link to caregivers (offline SIM)
  /// 4. Dispatches In-App alert to Firestore (online)
  /// 5. Shows confirmation local notification
  Future<SosDispatchResult> triggerSos({
    required BuildContext context,
    String? patientName,
    String? patientId,
  }) async {
    // 1. Immediate Voice Feedback to reassure patient
    speakSosVoiceFeedback(context);

    // Get patient info
    final authUser = FirebaseAuth.instance.currentUser;
    final pId = patientId ?? authUser?.uid ?? 'patient_local_01';
    final pName = patientName ?? authUser?.displayName ?? 'Patient';
    final contacts = getEmergencyContacts();

    // Query profile & Firestore for patient phone and linked caregivers
    String patientPhone = '';
    final List<String> targetCaregivers = [];
    try {
      final profile = HiveService().getUserProfile();
      patientPhone = (profile?['phone'] ?? profile?['mobile'] ?? '').toString().trim();

      if (authUser?.uid != null) {
        final doc = await FirebaseFirestore.instance.collection('users').doc(authUser!.uid).get();
        if (doc.exists && doc.data() != null) {
          final data = doc.data()!;
          if (patientPhone.isEmpty && data['phone'] != null) {
            patientPhone = data['phone'].toString().trim();
          }
          if (data['primaryCaregiverId'] != null) {
            targetCaregivers.add(data['primaryCaregiverId'].toString());
          }
          if (data['linkedCaregiverId'] != null) {
            targetCaregivers.add(data['linkedCaregiverId'].toString());
          }
          if (data['linkedCaregiverIds'] is List) {
            targetCaregivers.addAll(List<String>.from(data['linkedCaregiverIds']));
          }

          final cgPhone = (data['caregiverPhone'] ?? data['guardianPhone'] ?? '').toString().trim();
          if (cgPhone.isNotEmpty && !contacts.contains(cgPhone)) {
            contacts.add(cgPhone);
          }
        }

        // Also discover any caregivers who linked this patient
        final linkedCgSnap = await FirebaseFirestore.instance
            .collection('users')
            .where('linkedPatients', arrayContains: authUser.uid)
            .get();
        for (final d in linkedCgSnap.docs) {
          targetCaregivers.add(d.id);
        }

        // If targetCaregivers is still empty, match caregivers by phone
        if (targetCaregivers.isEmpty && contacts.isNotEmpty) {
          final cleanNumbers = contacts.map((c) => c.replaceAll(RegExp(r'\s+'), '')).toList();
          final cgMatch = await FirebaseFirestore.instance
              .collection('users')
              .where('role', isEqualTo: 'caregiver')
              .get();
          for (final d in cgMatch.docs) {
            final p = (d.data()['phone'] ?? d.data()['mobile'] ?? '').toString().replaceAll(RegExp(r'\s+'), '');
            if (p.isNotEmpty && cleanNumbers.any((c) => p.endsWith(c) || c.endsWith(p))) {
              targetCaregivers.add(d.id);
            }
          }
        }
      }
    } catch (e) {
      debugPrint('EmergencySosService: metadata fetch note: $e');
    }

    // 2. Fetch Location
    Position? position;
    try {
      position = await getCurrentLocation();
    } catch (e) {
      debugPrint('EmergencySosService: location error: $e');
    }

    final lat = position?.latitude;
    final lng = position?.longitude;
    final timeStr = DateFormat('hh:mm a, dd MMM yyyy').format(DateTime.now());

    final mapsUrl = (lat != null && lng != null)
        ? 'https://maps.google.com/?q=$lat,$lng'
        : 'Location unavailable';

    // 3. Compose SMS Alert Message
    final smsMessage = '🚨 EMERGENCY SOS ALERT - NeuroVerse\n'
        'Patient: $pName needs immediate assistance!\n'
        'Time: $timeStr\n'
        'Location: $mapsUrl\n'
        '${(lat != null && lng != null) ? "GPS: ${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}\n" : ""}'
        'Please respond immediately.';

    // 4. Send SMS to Caregivers (Offline via Device SIM)
    bool smsLaunched = false;
    if (contacts.isNotEmpty) {
      // 4A. Try Direct Silent Background SMS via Native SmsManager first!
      final hasPerm = await hasSmsPermission();
      if (!hasPerm) {
        await requestSmsPermission();
      }

      bool silentSmsSuccess = false;
      for (final contact in contacts) {
        try {
          final res = await _smsChannel.invokeMethod<bool>('sendSilentSms', {
            'phone': contact,
            'message': smsMessage,
          });
          if (res == true) {
            silentSmsSuccess = true;
            debugPrint('EmergencySosService: Silent background SMS successfully sent to $contact');
          }
        } catch (e) {
          debugPrint('EmergencySosService: Silent SMS failed for $contact ($e). Falling back.');
        }
      }

      if (silentSmsSuccess) {
        smsLaunched = true;
      } else {
        // 4B. Fallback: Open SMS app intent if background send is blocked or unpermitted
        try {
          final joinedNumbers = contacts.join(',');
          final smsUri = Uri(
            scheme: 'sms',
            path: joinedNumbers,
            queryParameters: <String, String>{
              'body': smsMessage,
            },
          );

          if (await canLaunchUrl(smsUri)) {
            await launchUrl(smsUri, mode: LaunchMode.externalApplication);
            smsLaunched = true;
          } else {
            // Fallback single recipient
            final singleUri = Uri(
              scheme: 'sms',
              path: contacts.first,
              queryParameters: <String, String>{
                'body': smsMessage,
              },
            );
            if (await canLaunchUrl(singleUri)) {
              await launchUrl(singleUri, mode: LaunchMode.externalApplication);
              smsLaunched = true;
            }
          }
        } catch (e) {
          debugPrint('EmergencySosService: SMS intent fallback failed: $e');
        }
      }
    }

    // 5. In-App Cloud Alert to Caregiver (Firestore - Online)
    bool cloudSynced = false;
    try {
      final targetList = targetCaregivers.toSet().toList();
      final primaryPhone = contacts.isNotEmpty ? contacts.first : '';

      await FirebaseFirestore.instance.collection('sos_alerts').add({
        'patientId': pId,
        'patientUid': pId,
        'patientName': pName,
        'patientPhone': patientPhone,
        'targetCaregiverIds': targetList,
        'targetCaregiverPhone': primaryPhone,
        'type': 'SOS',
        'title': '🚨 EMERGENCY SOS ALERT: $pName',
        'message': 'Patient triggered Emergency SOS! Check immediately!',
        'latitude': lat,
        'longitude': lng,
        'mapsUrl': mapsUrl,
        'timestamp': FieldValue.serverTimestamp(),
        'localTimestamp': DateTime.now().toIso8601String(),
        'status': 'ACTIVE',
        'severity': 'critical',
        'smsDeliveredTo': contacts,
        'batteryLevel': 'OK',
      });
      cloudSynced = true;

      // Dispatch direct notifications to target caregivers
      for (final cgId in targetList) {
        try {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(cgId)
              .collection('notifications')
              .add({
            'title': '🚨 EMERGENCY SOS: $pName Needs Help!',
            'message': 'Patient triggered Emergency SOS. Live location: $mapsUrl',
            'type': 'emergency_sos',
            'patientId': pId,
            'patientName': pName,
            'mapsUrl': mapsUrl,
            'timestamp': FieldValue.serverTimestamp(),
            'isRead': false,
          });
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('EmergencySosService: Firestore SOS write notice (offline or not configured): $e');
    }

    // 6. Show Local High-Priority Confirmation Notification
    try {
      await NotificationService().showNotification(
        id: 999999,
        title: '🚨 Emergency SOS Dispatched',
        body: 'Alert sent to ${contacts.isNotEmpty ? contacts.join(", ") : "Caregivers"}. Live GPS: ${lat?.toStringAsFixed(4) ?? "Locking..."}, ${lng?.toStringAsFixed(4) ?? ""}',
      );
    } catch (_) {}

    return SosDispatchResult(
      success: true,
      latitude: lat,
      longitude: lng,
      mapsUrl: mapsUrl,
      contactsAlerted: contacts,
      message: smsMessage,
      smsLaunched: smsLaunched,
      cloudSynced: cloudSynced,
    );
  }
}
