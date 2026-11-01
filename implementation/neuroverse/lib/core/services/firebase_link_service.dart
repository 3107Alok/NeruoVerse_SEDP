import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'notification_service.dart';

class FirebaseLinkService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final NotificationService _notificationService;

  StreamSubscription? _incomingReqSub;
  StreamSubscription? _acceptedReqSub;
  StreamSubscription? _caregiverDocSub;
  StreamSubscription? _sosAlertsSub;
  final Set<String> _seenSosAlertIds = {};
  Set<String> _linkedPatientIds = {};
  String _userPhone = '';

  FirebaseLinkService(this._notificationService) {
    _listenToLinkRequests();
  }

  // Send a link request (Caregiver -> Patient)
  Future<void> sendLinkRequest(String shareCode, String caregiverName) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final cleanCode = shareCode.trim().toUpperCase();
    // Find the patient by shareCode
    final snapshot = await _firestore.collection('users').where('shareCode', isEqualTo: cleanCode).get();
    
    if (snapshot.docs.isEmpty) {
      throw Exception('No patient found with code "$cleanCode". Please verify the code.');
    }
    
    final patientDoc = snapshot.docs.first;
    final patientUid = patientDoc.id;
    final patientName = (patientDoc.data())['name'] ?? 'Patient';

    // 1. Check if patient is already linked to this caregiver
    final caregiverDoc = await _firestore.collection('users').doc(user.uid).get();
    final linkedPatients = List<String>.from(caregiverDoc.data()?['linkedPatients'] ?? []);
    if (linkedPatients.contains(patientUid)) {
      throw Exception('This patient is already linked to your account.');
    }

    // 2. Check if a request has ALREADY been sent and is currently pending
    final existingPending = await _firestore
        .collection('link_requests')
        .where('caregiverId', isEqualTo: user.uid)
        .where('patientId', isEqualTo: patientUid)
        .where('status', isEqualTo: 'pending')
        .limit(1)
        .get();

    if (existingPending.docs.isNotEmpty) {
      throw Exception('Request Already Sent: A connection request for $patientName is already pending approval.');
    }

    await _firestore.collection('link_requests').add({
      'caregiverId': user.uid,
      'caregiverName': caregiverName,
      'patientId': patientUid,
      'patientName': patientName,
      'shareCode': cleanCode,
      'status': 'pending',
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  // Accept a link request (Patient -> Caregiver)
  Future<void> acceptLinkRequest(String requestId, String caregiverId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    // 1. Update Request
    await _firestore.collection('link_requests').doc(requestId).update({
      'status': 'accepted',
      'acceptedAt': FieldValue.serverTimestamp(),
    });

    // 2. Update Patient Document
    await _firestore.collection('users').doc(user.uid).set({
      'linkedCaregiverId': caregiverId,
      'linkedCaregiverIds': FieldValue.arrayUnion([caregiverId]),
    }, SetOptions(merge: true));

    // 3. Update Caregiver Document
    await _firestore.collection('users').doc(caregiverId).set({
      'linkedPatients': FieldValue.arrayUnion([user.uid]),
    }, SetOptions(merge: true));
  }

  // Reject a link request
  Future<void> rejectLinkRequest(String requestId) async {
    await _firestore.collection('link_requests').doc(requestId).update({
      'status': 'rejected',
    });
  }

  // Background Stream Listener for Notifications
  void _listenToLinkRequests() {
    _auth.authStateChanges().listen((user) {
      _incomingReqSub?.cancel();
      _acceptedReqSub?.cancel();
      _caregiverDocSub?.cancel();
      _sosAlertsSub?.cancel();

      if (user == null) {
        _linkedPatientIds.clear();
        _seenSosAlertIds.clear();
        return;
      }
      
      // 1. Listen for incoming requests (For Patient)
      _incomingReqSub = _firestore
          .collection('link_requests')
          .where('patientId', isEqualTo: user.uid)
          .where('status', isEqualTo: 'pending')
          .snapshots()
          .listen((snapshot) {
        for (var change in snapshot.docChanges) {
          if (change.type == DocumentChangeType.added) {
            final data = change.doc.data();
            if (data != null) {
              _notificationService.showNotification(
                id: change.doc.id.hashCode,
                title: 'New Caregiver Request',
                body: '${data['caregiverName'] ?? 'Someone'} wants to connect as your caregiver.',
              );
            }
          }
        }
      });

      // 2. Listen for accepted requests (For Caregiver)
      _acceptedReqSub = _firestore
          .collection('link_requests')
          .where('caregiverId', isEqualTo: user.uid)
          .where('status', isEqualTo: 'accepted')
          .snapshots()
          .listen((snapshot) {
        for (var change in snapshot.docChanges) {
          if (change.type == DocumentChangeType.modified) {
            _notificationService.showNotification(
              id: change.doc.id.hashCode,
              title: 'Request Accepted',
              body: 'A patient has accepted your connection request.',
            );
          }
        }
      });

      // 3. Keep Caregiver Linked Patients & Phone updated
      _caregiverDocSub = _firestore.collection('users').doc(user.uid).snapshots().listen((doc) {
        if (doc.exists && doc.data() != null) {
          final data = doc.data()!;
          _linkedPatientIds = Set<String>.from(data['linkedPatients'] ?? []);
          _userPhone = (data['phone'] ?? data['mobile'] ?? '').toString().trim();
        }
      });

      // 4. Global Emergency SOS Listener for Caregivers
      _sosAlertsSub = _firestore
          .collection('sos_alerts')
          .where('status', isEqualTo: 'ACTIVE')
          .snapshots()
          .listen((snapshot) {
        for (var change in snapshot.docChanges) {
          if (change.type == DocumentChangeType.added || change.type == DocumentChangeType.modified) {
            final docId = change.doc.id;
            if (_seenSosAlertIds.contains(docId)) continue;

            final data = change.doc.data();
            if (data == null || data['status'] != 'ACTIVE') continue;

            // Check if alert happened in the last 45 minutes
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
            final patientUid = (data['patientUid'] ?? data['patientId'] ?? '').toString();
            final smsDeliveredTo = List<String>.from(data['smsDeliveredTo'] ?? []);
            final targetCaregiverPhone = (data['targetCaregiverPhone'] ?? '').toString().trim();

            final cleanUserPhone = _userPhone.replaceAll(RegExp(r'\s+'), '');
            final isForThisCaregiver = targetCaregivers.contains(user.uid) ||
                _linkedPatientIds.contains(patientUid) ||
                (cleanUserPhone.isNotEmpty &&
                    targetCaregiverPhone.isNotEmpty &&
                    (targetCaregiverPhone.replaceAll(RegExp(r'\s+'), '').endsWith(cleanUserPhone) ||
                        cleanUserPhone.endsWith(targetCaregiverPhone.replaceAll(RegExp(r'\s+'), '')))) ||
                (cleanUserPhone.isNotEmpty &&
                    smsDeliveredTo.any((c) {
                      final clean = c.replaceAll(RegExp(r'\s+'), '');
                      return clean.endsWith(cleanUserPhone) || cleanUserPhone.endsWith(clean);
                    }));

            if (isForThisCaregiver) {
              _seenSosAlertIds.add(docId);
              final pName = data['patientName'] ?? 'Patient';
              final mapsUrl = data['mapsUrl'] ?? '';
              final alertTitle = data['title']?.toString() ?? '🚨 EMERGENCY SOS: $pName Needs Help!';
              final alertBody = data['message']?.toString() ??
                  'Emergency alert dispatched! GPS: ${mapsUrl.isNotEmpty ? mapsUrl : "Location recorded"}. Check immediately!';

              _notificationService.showNotification(
                id: (docId.hashCode).abs() % 1000000,
                title: alertTitle,
                body: alertBody,
                payload: 'sos_alert:$docId',
              );
            }
          }
        }
      });
    });
  }
}
