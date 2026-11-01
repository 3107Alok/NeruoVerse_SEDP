import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/game_session.dart';
import '../models/family_member_model.dart';
import '../../data/local/hive_service.dart';
import '../../data/remote/firestore_service.dart';

class SyncService {
  final HiveService _hiveService;
  final FirestoreService _firestoreService = FirestoreService();

  SyncService(this._hiveService);

  /// Synchronizes local game sessions, QTable, and Face Recall photos to/from Firebase Firestore.
  /// Returns true if successful, false if offline or error.
  Future<bool> syncLocalDataToCloud([String? targetPatientId]) async {
    debugPrint("Starting sync process...");
    try {
      // 1. Sync Game Sessions
      List<GameSession> allSessions = _hiveService.getAllGameSessions();
      for (var session in allSessions) {
        await _firestoreService.syncGameSession(session);
      }
      
      // 2. Sync QTable
      Map<String, dynamic> qTable = _hiveService.loadQTable();
      if (qTable.isNotEmpty) {
        await _firestoreService.saveQTable(qTable);
      }

      // 3. Bi-Directional Sync for Family Photos (Face Recall Album)
      final uid = targetPatientId ?? FirebaseAuth.instance.currentUser?.uid;
      if (uid != null && uid.isNotEmpty) {
        // Fetch cloud photos
        final photoSnap = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('face_recall_members')
            .get()
            .timeout(const Duration(seconds: 5));

        final cloudMembers = photoSnap.docs
            .map((d) => FamilyMember.fromMap(d.data()))
            .where((m) => !m.isDefaultAsset && m.imageBase64.isNotEmpty)
            .toList();

        // Get local cached members
        final localMembers = _hiveService
            .getFamilyMembers()
            .where((m) => !m.isDefaultAsset && m.imageBase64.isNotEmpty)
            .toList();

        // Upload any local photos not present in cloud
        final cloudIds = cloudMembers.map((m) => m.id).toSet();
        for (var local in localMembers) {
          if (!cloudIds.contains(local.id)) {
            await FirebaseFirestore.instance
                .collection('users')
                .doc(uid)
                .collection('face_recall_members')
                .doc(local.id)
                .set(local.toMap(), SetOptions(merge: true));
            cloudMembers.add(local);
          }
        }

        // Cache combined photos in Hive
        if (cloudMembers.isNotEmpty) {
          await _hiveService.saveFamilyMembers(cloudMembers);
          debugPrint("SyncService: Saved ${cloudMembers.length} family photos in Hive cache.");
        }
      }

      debugPrint("Sync complete successfully.");
      return true;
    } catch (e) {
      debugPrint("Sync failed: $e");
      return false;
    }
  }

  /// Restores game sessions and family photos from Firestore to local Hive on login.
  Future<bool> restoreDataFromCloud(String patientId) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(patientId)
          .collection('game_sessions')
          .orderBy('timestamp', descending: true)
          .get()
          .timeout(const Duration(seconds: 5));

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final session = GameSession.fromMap(data);
        await _hiveService.saveGameSession(session);
      }
      debugPrint("Successfully restored ${snapshot.docs.length} sessions from cloud.");

      // Restore family photos (Face Recall Album)
      final photoSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(patientId)
          .collection('face_recall_members')
          .get()
          .timeout(const Duration(seconds: 5));

      if (photoSnap.docs.isNotEmpty) {
        final members = photoSnap.docs
            .map((d) => FamilyMember.fromMap(d.data()))
            .where((m) => !m.isDefaultAsset && m.imageBase64.isNotEmpty)
            .toList();
        if (members.isNotEmpty) {
          await _hiveService.saveFamilyMembers(members);
          debugPrint("Successfully restored ${members.length} family photos from cloud.");
        }
      }

      return true;
    } catch (e) {
      debugPrint("Cloud restore skipped or failed: $e");
      return false;
    }
  }
}
