import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:neuroverse_app/providers/app_provider.dart';
import 'package:neuroverse_app/data/local/hive_service.dart';
import 'package:neuroverse_app/core/models/family_member_model.dart';
import 'package:neuroverse_app/features/caregiver/overview/family_album_manager_dialog.dart';

class FakeHiveService extends HiveService {
  final List<FamilyMember> _members = [];

  @override
  List<FamilyMember> getFamilyMembers() => _members;

  @override
  Future<void> saveFamilyMembers(List<FamilyMember> members) async {
    _members.clear();
    _members.addAll(members);
  }
}

// 10x10 transparent 1-pixel PNG bytes for test cropper
Uint8List createDummyPngBytes() {
  const base64Png =
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==';
  return base64Decode(base64Png);
}

void main() {
  group('Family Album & Passport Cropper Tests', () {
    testWidgets('PassportPhotoCropperDialog renders face guide, zoom viewer, and action buttons', (tester) async {
      final dummyBytes = createDummyPngBytes();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PassportPhotoCropperDialog(imageBytes: dummyBytes),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Crop Face (Passport Size)'), findsOneWidget);
      expect(find.text('Pinch to zoom and drag to position face inside the passport frame.'), findsOneWidget);
      expect(find.byType(InteractiveViewer), findsOneWidget);
      expect(find.text('Reset Position'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Crop & Use Face'), findsOneWidget);
    });

    testWidgets('Add member sheet renders compact relationship selector with modal and close button', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final fakeHive = FakeHiveService();
      final appProvider = AppProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<HiveService>.value(value: fakeHive),
            ChangeNotifierProvider<AppProvider>.value(value: appProvider),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: AddFamilyMemberSheet(
                onSave: (member) async {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify direct photo action buttons and passport photo picker exist
      expect(find.text('Take Photo'), findsOneWidget);
      expect(find.text('From Gallery'), findsOneWidget);
      expect(find.text('Passport Size\nFace Photo'), findsOneWidget);
      expect(find.byType(TextField), findsWidgets);

      // Verify compact relationship selector trigger is present
      final relationTrigger = find.byKey(const Key('relationship_picker_trigger'));
      expect(relationTrigger, findsOneWidget);

      // Initially custom relation field is NOT shown
      expect(find.text('Enter Custom Relationship'), findsNothing);

      // 1. Open relation picker modal
      await tester.tap(relationTrigger);
      await tester.pumpAndSettle();

      // Verify Cross (X) close button exists in the compact dialog
      final closeButton = find.byKey(const Key('close_relation_picker'));
      expect(closeButton, findsOneWidget);

      // Tap close button to test dismissal
      await tester.tap(closeButton);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('close_relation_picker')), findsNothing);

      // 2. Re-open and select 'Other'
      await tester.tap(relationTrigger);
      await tester.pumpAndSettle();

      final otherOption = find.text('Other').last;
      await tester.ensureVisible(otherOption);
      await tester.pumpAndSettle();
      await tester.tap(otherOption);
      await tester.pumpAndSettle();

      // Modal is closed and custom relation text field MUST appear!
      expect(find.text('Enter Custom Relationship'), findsOneWidget);
    });
  });
}
