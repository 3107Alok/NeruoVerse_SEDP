import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/models/game_session.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> syncGameSession(GameSession session) async {
    try {
      await _firestore.collection('users').doc(session.patientId).set({
        'lastActive': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await _firestore
          .collection('users')
          .doc(session.patientId)
          .collection('game_sessions')
          .doc(session.id)
          .set(session.toMap(), SetOptions(merge: true));
      debugPrint("Real Firestore Sync: Session ${session.id} saved.");
    } catch (e) {
      debugPrint("Firestore Sync Error: $e");
    }
  }

  Future<void> saveQTable(Map<String, dynamic> qTable) async {
    // Save QTable for the adaptive AI
    try {
      await _firestore.collection('ai_models').doc('q_table_latest').set(qTable);
      debugPrint("Real Firestore Sync: QTable updated.");
    } catch (e) {
      debugPrint("Firestore Sync Error (QTable): $e");
    }
  }
}
