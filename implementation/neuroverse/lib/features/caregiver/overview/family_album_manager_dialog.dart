import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/models/family_member_model.dart';
import '../../../../data/local/hive_service.dart';
import '../../../../core/localization/app_translations.dart';
import '../../../../core/utils/indic_transliteration.dart';
import '../../../../providers/app_provider.dart';

class FamilyAlbumManagerDialog extends StatefulWidget {
  final String patientId;
  final String patientName;

  const FamilyAlbumManagerDialog({
    super.key,
    required this.patientId,
    required this.patientName,
  });

  @override
  State<FamilyAlbumManagerDialog> createState() => _FamilyAlbumManagerDialogState();
}

class _FamilyAlbumManagerDialogState extends State<FamilyAlbumManagerDialog> {
  bool _showAddForm = true;

  Future<void> _saveMemberToCloudAndLocal(FamilyMember member) async {

    final messenger = ScaffoldMessenger.of(context);
    final hive = context.read<HiveService>();

    try {
      // 1. Save to Firestore under patient's subcollection
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.patientId)
          .collection('face_recall_members')
          .doc(member.id)
          .set(member.toMap());

      // 2. Cache in local Hive
      final currentMembers = hive.getFamilyMembers().where((m) => !m.isDefaultAsset).toList();
      currentMembers.removeWhere((m) => m.id == member.id);
      currentMembers.add(member);
      await hive.saveFamilyMembers(currentMembers);

      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white),
                const SizedBox(width: 8),
                Text("${member.name} (${member.relation}) added successfully!"),
              ],
            ),
            backgroundColor: const Color(0xFF00796B),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      debugPrint("Error saving family member: $e");
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text("Error saving photo: $e"),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  Future<void> _deleteMember(String memberId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text("Delete Photo?"),
        content: const Text("Are you sure you want to remove this family member photo?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () => Navigator.pop(c, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Delete", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.patientId)
          .collection('face_recall_members')
          .doc(memberId)
          .delete();

      if (mounted) {
        final hive = context.read<HiveService>();
        final current = hive.getFamilyMembers().where((m) => !m.isDefaultAsset).toList();
        current.removeWhere((m) => m.id == memberId);
        await hive.saveFamilyMembers(current);
      }
    } catch (e) {
      debugPrint("Delete member error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;
    final isTablet = size.shortestSide >= 600;

    final dialogWidth = isTablet ? 500.0 : 440.0;
    final maxDialogHeight = (size.height * (isTablet ? 0.82 : 0.88)).clamp(460.0, 720.0);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: isDark ? const Color(0xFF1E2829) : Colors.white,
      insetPadding: EdgeInsets.symmetric(
        horizontal: isTablet ? (size.width * 0.15).clamp(24.0, 100.0) : 16.0,
        vertical: 20.0,
      ),
      child: Container(
        width: double.infinity,
        constraints: BoxConstraints(
          maxWidth: dialogWidth,
          maxHeight: maxDialogHeight,
        ),
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Title Bar
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00796B).withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.people_alt_rounded, color: Color(0xFF00796B), size: 22),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    "Face Recall Album",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const Divider(height: 18),

            // Live Stream of Custom Family Members ONLY (No default demo photos!)
            Flexible(
              fit: FlexFit.loose,
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(widget.patientId)
                    .collection('face_recall_members')
                    .orderBy('createdAt', descending: false)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  final docs = snapshot.data?.docs ?? [];
                  final customMembers = docs
                      .map((d) => FamilyMember.fromMap(d.data() as Map<String, dynamic>))
                      .where((m) => !m.isDefaultAsset && m.imageBase64.isNotEmpty)
                      .toList();

                  // If custom photos exist, sync them to Hive immediately for patient offline use
                  if (customMembers.isNotEmpty) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) {
                        context.read<HiveService>().saveFamilyMembers(customMembers);
                      }
                    });
                  }

                  // If customMembers is empty, ALWAYS show direct upload form.
                  final bool isShowingAdd = customMembers.isEmpty || _showAddForm;

                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // If photos exist, show tab toggle: [ ➕ Add Photo ] | [ 👥 Saved Album (N) ]
                      if (customMembers.isNotEmpty) ...[
                        Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isDark ? Colors.white12 : Colors.grey.shade300,
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => setState(() => _showAddForm = true),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    decoration: BoxDecoration(
                                      color: isShowingAdd ? const Color(0xFF00796B) : Colors.transparent,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    alignment: Alignment.center,
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.add_a_photo_rounded,
                                          size: 16,
                                          color: isShowingAdd ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          "Add Photo",
                                          style: TextStyle(
                                            color: isShowingAdd ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => setState(() => _showAddForm = false),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    decoration: BoxDecoration(
                                      color: !isShowingAdd ? const Color(0xFF00796B) : Colors.transparent,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    alignment: Alignment.center,
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.photo_library_rounded,
                                          size: 16,
                                          color: !isShowingAdd ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          "Saved Album (${customMembers.length})",
                                          style: TextStyle(
                                            color: !isShowingAdd ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // View Content: Direct Add Form vs Saved Grid
                      if (isShowingAdd)
                        Flexible(
                          fit: FlexFit.loose,
                          child: AddFamilyMemberSheet(
                            isEmbedded: true,
                            onSave: (newMember) async {
                              await _saveMemberToCloudAndLocal(newMember);
                              if (mounted) {
                                setState(() {
                                  _showAddForm = false; // View newly added photo in album
                                });
                              }
                            },
                          ),
                        )
                      else
                        SizedBox(
                          height: isTablet ? 460 : 380,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Active Count Banner
                              Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF00796B).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: const Color(0xFF00796B).withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.verified_user_rounded,
                                      size: 18,
                                      color: Color(0xFF00796B),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        "${customMembers.length} personalized photos active for ${widget.patientName}",
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF00796B),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Grid of Custom Family Cards
                              Expanded(
                                child: GridView.builder(
                                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: isTablet ? 3 : 2,
                                    childAspectRatio: 0.88,
                                    crossAxisSpacing: 12,
                                    mainAxisSpacing: 12,
                                  ),
                                  itemCount: customMembers.length,
                                  itemBuilder: (context, index) {
                                    final member = customMembers[index];
                                    final imageBytes = base64Decode(member.imageBase64);

                                    return Container(
                                      decoration: BoxDecoration(
                                        color: isDark ? const Color(0xFF263238) : Colors.grey.shade50,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: isDark ? Colors.white12 : Colors.grey.shade200,
                                        ),
                                      ),
                                      child: Stack(
                                        children: [
                                          Padding(
                                            padding: const EdgeInsets.all(8.0),
                                            child: Column(
                                              children: [
                                                Expanded(
                                                  child: ClipRRect(
                                                    borderRadius: BorderRadius.circular(12),
                                                    child: Image.memory(
                                                      imageBytes,
                                                      fit: BoxFit.cover,
                                                      width: double.infinity,
                                                      errorBuilder: (ctx, err, stack) => const Icon(
                                                        Icons.broken_image_rounded,
                                                        size: 40,
                                                        color: Colors.grey,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(height: 8),
                                                Text(
                                                  member.name,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 13,
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                Container(
                                                  margin: const EdgeInsets.only(top: 2),
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFF00796B).withValues(alpha: 0.12),
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                  child: Text(
                                                    member.relationKey.isNotEmpty
                                                        ? context.tr(member.relationKey)
                                                        : member.relation,
                                                    style: const TextStyle(
                                                      fontSize: 11,
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

                                          // Delete button for custom uploaded photos
                                          Positioned(
                                            top: 6,
                                            right: 6,
                                            child: GestureDetector(
                                              onTap: () => _deleteMember(member.id),
                                              child: Container(
                                                padding: const EdgeInsets.all(5),
                                                decoration: const BoxDecoration(
                                                  color: Colors.black54,
                                                  shape: BoxShape.circle,
                                                ),
                                                child: const Icon(Icons.delete_outline_rounded, size: 16, color: Colors.white),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ),

                              const SizedBox(height: 12),

                              // Add Another Photo Button
                              ElevatedButton.icon(
                                onPressed: () => setState(() => _showAddForm = true),
                                icon: const Icon(Icons.add_photo_alternate_rounded),
                                label: const Text(
                                  "Add Another Family Photo",
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF00796B),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 13),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet or embedded view for adding a new family member with photo cropping and relation selection
class AddFamilyMemberSheet extends StatefulWidget {
  final Future<void> Function(FamilyMember member) onSave;
  final bool isEmbedded;

  const AddFamilyMemberSheet({
    super.key,
    required this.onSave,
    this.isEmbedded = false,
  });

  @override
  State<AddFamilyMemberSheet> createState() => _AddFamilyMemberSheetState();
}

class _AddFamilyMemberSheetState extends State<AddFamilyMemberSheet> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _customRelationController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  String _selectedRelationKey = 'rel_son';
  String _selectedRelation = 'Son';
  String? _pickedBase64;
  Uint8List? _previewBytes;
  Uint8List? _originalImageBytes;

  static const List<Map<String, String>> relationPresets = [
    {'key': 'rel_son', 'label': 'Son'},
    {'key': 'rel_daughter', 'label': 'Daughter'},
    {'key': 'rel_wife', 'label': 'Wife'},
    {'key': 'rel_husband', 'label': 'Husband'},
    {'key': 'rel_grandson', 'label': 'Grandson'},
    {'key': 'rel_granddaughter', 'label': 'Granddaughter'},
    {'key': 'rel_brother', 'label': 'Brother'},
    {'key': 'rel_sister', 'label': 'Sister'},
    {'key': 'rel_mother', 'label': 'Mother'},
    {'key': 'rel_father', 'label': 'Father'},
    {'key': 'rel_friend', 'label': 'Friend'},
    {'key': 'rel_caregiver', 'label': 'Caregiver'},
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _customRelationController.dispose();
    super.dispose();
  }

  Future<void> _pickAndCrop({ImageSource? source, bool reCropOriginal = false}) async {
    try {
      Uint8List? rawBytes = reCropOriginal ? _originalImageBytes : null;

      if (rawBytes == null) {
        final ImageSource? pickedSource = source ??
            await showModalBottomSheet<ImageSource>(
              context: context,
              backgroundColor: Colors.transparent,
              builder: (ctx) {
                final isDark = Theme.of(ctx).brightness == Brightness.dark;
                return Container(
                  padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E2829) : Colors.white,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  child: SafeArea(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade400,
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          "Choose Photo Source",
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 14),
                        ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF00796B).withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.photo_library_rounded, color: Color(0xFF00796B)),
                          ),
                          title: const Text("Choose from Gallery", style: TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: const Text("Pick an existing family picture", style: TextStyle(fontSize: 12)),
                          onTap: () => Navigator.pop(ctx, ImageSource.gallery),
                        ),
                        ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFD97706).withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.camera_alt_rounded, color: Color(0xFFD97706)),
                          ),
                          title: const Text("Take Photo with Camera", style: TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: const Text("Capture face directly right now", style: TextStyle(fontSize: 12)),
                          onTap: () => Navigator.pop(ctx, ImageSource.camera),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );

        if (pickedSource == null) return;

        final XFile? image = await _picker.pickImage(
          source: pickedSource,
          maxWidth: 800,
          maxHeight: 800,
          imageQuality: 80,
        );
        if (image == null) return;
        rawBytes = await image.readAsBytes();
        _originalImageBytes = rawBytes;
      }

      if (!mounted) return;

      // Open interactive passport-size face crop dialog
      final Uint8List? cropped = await showDialog<Uint8List>(
        context: context,
        barrierDismissible: false,
        builder: (c) => PassportPhotoCropperDialog(imageBytes: rawBytes!),
      );

      if (cropped != null && mounted) {
        final base64String = base64Encode(cropped);
        setState(() {
          _previewBytes = cropped;
          _pickedBase64 = base64String;
        });
      }
    } catch (e) {
      debugPrint("Image pick/crop error: $e");
    }
  }

  Future<void> _showRelationPickerModal(BuildContext context) async {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: isDark ? const Color(0xFF1E2829) : Colors.white,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 380, maxHeight: 420),
            padding: const EdgeInsets.fromLTRB(18, 14, 14, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header with Title and Cross (X) Close Button
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00796B).withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.people_alt_rounded, color: Color(0xFF00796B), size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        context.tr('choose_relation'),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      key: const Key('close_relation_picker'),
                      onPressed: () => Navigator.pop(dialogContext),
                      icon: const Icon(Icons.close_rounded),
                      tooltip: "Close",
                      splashRadius: 20,
                    ),
                  ],
                ),
                const Divider(height: 16),

                // Scrollable list of compact relations
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ...relationPresets.map((r) {
                          final isSelected = _selectedRelationKey == r['key'];
                          final translated = context.tr(r['key']!);
                          final label = (translated.isNotEmpty && translated != r['key']) ? translated : r['label']!;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFF00796B).withValues(alpha: 0.12)
                                  : (isDark ? Colors.white.withValues(alpha: 0.04) : Colors.grey.shade50),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? const Color(0xFF00796B)
                                    : (isDark ? Colors.white12 : Colors.grey.shade200),
                                width: isSelected ? 1.5 : 1.0,
                              ),
                            ),
                            child: ListTile(
                              dense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
                              title: Text(
                                "$label (${r['label']})",
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                  color: isSelected
                                      ? const Color(0xFF00796B)
                                      : (isDark ? Colors.white : Colors.black87),
                                ),
                              ),
                              trailing: isSelected
                                  ? const Icon(Icons.check_circle_rounded, color: Color(0xFF00796B), size: 20)
                                  : null,
                              onTap: () {
                                setState(() {
                                  _selectedRelationKey = r['key']!;
                                  _selectedRelation = r['label']!;
                                });
                                Navigator.pop(dialogContext);
                              },
                            ),
                          );
                        }),

                        // 'Other' Option
                        Container(
                          margin: const EdgeInsets.only(bottom: 4),
                          decoration: BoxDecoration(
                            color: _selectedRelationKey == 'rel_other'
                                ? const Color(0xFF00796B).withValues(alpha: 0.12)
                                : (isDark ? Colors.white.withValues(alpha: 0.04) : Colors.grey.shade50),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _selectedRelationKey == 'rel_other'
                                  ? const Color(0xFF00796B)
                                  : (isDark ? Colors.white12 : Colors.grey.shade200),
                              width: _selectedRelationKey == 'rel_other' ? 1.5 : 1.0,
                            ),
                          ),
                          child: ListTile(
                            dense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
                            leading: const Icon(Icons.edit_note_rounded, size: 20, color: Color(0xFF00796B)),
                            title: Builder(builder: (ctx) {
                              final trOther = ctx.tr('other');
                              final otherLabel = (trOther.isNotEmpty && trOther != 'other') ? trOther : 'Other';
                              return Text(
                                otherLabel,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: _selectedRelationKey == 'rel_other' ? FontWeight.bold : FontWeight.w600,
                                  color: _selectedRelationKey == 'rel_other'
                                      ? const Color(0xFF00796B)
                                      : (isDark ? Colors.white : Colors.black87),
                                ),
                              );
                            }),
                            trailing: _selectedRelationKey == 'rel_other'
                                ? const Icon(Icons.check_circle_rounded, color: Color(0xFF00796B), size: 20)
                                : null,
                            onTap: () {
                              setState(() {
                                _selectedRelationKey = 'rel_other';
                              });
                              Navigator.pop(dialogContext);
                            },
                          ),
                        ),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final isOtherSelected = _selectedRelationKey == 'rel_other';
    final canSave = _pickedBase64 != null &&
        _nameController.text.trim().isNotEmpty &&
        (!isOtherSelected || _customRelationController.text.trim().isNotEmpty);

    return Container(
      padding: EdgeInsets.only(
        bottom: widget.isEmbedded ? 0 : (MediaQuery.of(context).viewInsets.bottom + 20),
        left: widget.isEmbedded ? 0 : 20,
        right: widget.isEmbedded ? 0 : 20,
        top: widget.isEmbedded ? 0 : 20,
      ),
      decoration: widget.isEmbedded
          ? null
          : BoxDecoration(
              color: isDark ? const Color(0xFF1E2829) : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              boxShadow: const [
                BoxShadow(color: Colors.black26, blurRadius: 16, offset: Offset(0, -4)),
              ],
            ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header handle for bottom sheet mode
            if (!widget.isEmbedded) ...[
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Direct 1-Tap Photo Action Buttons (Camera & Gallery)
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _pickAndCrop(source: ImageSource.camera),
                    icon: const Icon(Icons.camera_alt_rounded, size: 18),
                    label: const Text("Take Photo", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00796B),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _pickAndCrop(source: ImageSource.gallery),
                    icon: const Icon(Icons.photo_library_rounded, size: 18, color: Color(0xFF00796B)),
                    label: const Text("From Gallery", style: TextStyle(color: Color(0xFF00796B), fontWeight: FontWeight.bold, fontSize: 13.5)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark ? const Color(0xFF1E2829) : const Color(0xFFE6FFFA),
                      foregroundColor: const Color(0xFF00796B),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: Color(0xFF00796B), width: 1.2),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Authentic Centered Passport Size Photo Preview Card
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    key: const Key('family_photo_picker_card'),
                    onTap: () => _pickAndCrop(source: ImageSource.gallery),
                    child: Container(
                      width: 130,
                      height: 160,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF162021) : const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _previewBytes != null
                              ? const Color(0xFF00796B)
                              : (isDark ? Colors.white24 : const Color(0xFFCBD5E1)),
                          width: _previewBytes != null ? 2.5 : 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: _previewBytes != null
                                ? const Color(0xFF00796B).withValues(alpha: 0.18)
                                : Colors.black.withValues(alpha: 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: _previewBytes != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(9),
                              child: Stack(
                                children: [
                                  // Clean, perfectly upright passport face
                                  Image.memory(
                                    _previewBytes!,
                                    width: 130,
                                    height: 160,
                                    fit: BoxFit.cover,
                                  ),
                                  // Passport Badge
                                  Positioned(
                                    top: 4,
                                    left: 4,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(alpha: 0.65),
                                        borderRadius: BorderRadius.circular(5),
                                      ),
                                      child: const Text(
                                        "Passport Face",
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF00796B).withValues(alpha: 0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.person_add_alt_1_rounded, size: 24, color: Color(0xFF00796B)),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  "Passport Size\nFace Photo",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white70 : const Color(0xFF1E2829),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "Tap to choose photo",
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    color: isDark ? Colors.white38 : Colors.grey.shade500,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),

                  // Actions row below passport photo if photo is selected
                  if (_previewBytes != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_originalImageBytes != null)
                          InkWell(
                            onTap: () => _pickAndCrop(reCropOriginal: true),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFF00796B)),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.crop, color: Color(0xFF00796B), size: 13),
                                  SizedBox(width: 4),
                                  Text(
                                    "Re-crop",
                                    style: TextStyle(color: Color(0xFF00796B), fontSize: 11.5, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        if (_originalImageBytes != null) const SizedBox(width: 8),
                        InkWell(
                          onTap: () => _pickAndCrop(source: ImageSource.gallery),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: isDark ? Colors.white24 : Colors.grey.shade400),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.refresh_rounded, color: isDark ? Colors.white70 : Colors.grey.shade700, size: 13),
                                const SizedBox(width: 4),
                                Text(
                                  "Change",
                                  style: TextStyle(
                                    color: isDark ? Colors.white70 : Colors.grey.shade700,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Name input
            TextField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: context.tr('enter_person_name'),
                prefixIcon: const Icon(Icons.person_rounded, color: Color(0xFF00796B)),
                filled: true,
                fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade50,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
            if (_nameController.text.trim().isNotEmpty) ...[
              const SizedBox(height: 6),
              Builder(builder: (ctx) {
                final appProv = context.read<AppProvider>();
                final userLang = appProv.userLanguage ?? 'hi';
                final transliterated = IndicTransliteration.transliterate(
                    _nameController.text.trim(), userLang);
                if (transliterated != _nameController.text.trim()) {
                  return Padding(
                    padding: const EdgeInsets.only(left: 4, top: 2),
                    child: Row(
                      children: [
                        const Icon(Icons.translate_rounded, size: 15, color: Color(0xFF00796B)),
                        const SizedBox(width: 6),
                        Text(
                          "Patient will see: $transliterated",
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF00796B),
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return const SizedBox.shrink();
              }),
            ],
            const SizedBox(height: 14),

            // Compact Relationship Selector Trigger (opens compact scrollable picker with X button)
            InkWell(
              key: const Key('relationship_picker_trigger'),
              onTap: () => _showRelationPickerModal(context),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark ? Colors.white24 : Colors.grey.shade400,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.people_alt_rounded, color: Color(0xFF00796B)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.tr('choose_relation'),
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? Colors.white60 : Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Builder(builder: (ctx) {
                            if (_selectedRelationKey == 'rel_other') {
                              final trOther = ctx.tr('other');
                              final label = (trOther.isNotEmpty && trOther != 'other') ? trOther : 'Other';
                              return Text(
                                label,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              );
                            }
                            final preset = relationPresets.firstWhere(
                              (p) => p['key'] == _selectedRelationKey,
                              orElse: () => {'label': _selectedRelation, 'key': _selectedRelationKey},
                            );
                            final translated = ctx.tr(preset['key']!);
                            final label = (translated.isNotEmpty && translated != preset['key'])
                                ? translated
                                : preset['label']!;
                            return Text(
                              "$label (${preset['label']})",
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                    const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.grey),
                  ],
                ),
              ),
            ),

            // Custom Relation input if 'Other' is chosen
            if (isOtherSelected) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _customRelationController,
                textCapitalization: TextCapitalization.words,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: "Enter Custom Relationship",
                  hintText: "e.g., Uncle, Aunt, Neighbor, Doctor",
                  prefixIcon: const Icon(Icons.edit_note_rounded, color: Color(0xFF00796B)),
                  filled: true,
                  fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade50,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ],

            const SizedBox(height: 20),

            // Save Button
            SizedBox(
              height: 50,
              child: ElevatedButton.icon(
                onPressed: canSave
                    ? () async {
                        final memberName = _nameController.text.trim();
                        final memberRelation = isOtherSelected
                            ? _customRelationController.text.trim()
                            : _selectedRelation;
                        final memberId = const Uuid().v4();

                        final newMember = FamilyMember(
                          id: memberId,
                          name: memberName,
                          relation: memberRelation,
                          relationKey: isOtherSelected ? '' : _selectedRelationKey,
                          imageBase64: _pickedBase64!,
                          isDefaultAsset: false,
                          createdAt: DateTime.now(),
                        );

                        if (!widget.isEmbedded) {
                          Navigator.of(context).pop();
                        } else {
                          _nameController.clear();
                          _customRelationController.clear();
                          setState(() {
                            _pickedBase64 = null;
                            _previewBytes = null;
                            _originalImageBytes = null;
                            _selectedRelationKey = 'rel_son';
                            _selectedRelation = 'Son';
                          });
                        }
                        await widget.onSave(newMember);
                      }
                    : null,
                icon: const Icon(Icons.check_circle_rounded),
                label: const Text(
                  "Save to Patient's Album",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00796B),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: isDark ? Colors.white12 : Colors.grey.shade300,
                  disabledForegroundColor: isDark ? Colors.white38 : Colors.grey.shade500,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),

          ],
        ),
      ),
    );
  }
}

/// Interactive Passport-Size Face Cropping Dialog
class PassportPhotoCropperDialog extends StatefulWidget {
  final Uint8List imageBytes;

  const PassportPhotoCropperDialog({super.key, required this.imageBytes});

  @override
  State<PassportPhotoCropperDialog> createState() => _PassportPhotoCropperDialogState();
}

class _PassportPhotoCropperDialogState extends State<PassportPhotoCropperDialog> {
  final GlobalKey _cropKey = GlobalKey();
  final TransformationController _transformController = TransformationController();
  bool _isCropping = false;

  void _resetTransform() {
    _transformController.value = Matrix4.identity();
  }

  Future<void> _cropAndReturn() async {
    if (_isCropping) return;
    setState(() => _isCropping = true);

    try {
      await Future.delayed(const Duration(milliseconds: 60));
      final boundary = _cropKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary != null) {
        // pixelRatio 1.0 captures the exact 260x260 passport size, keeping byte size under 30 KB
        final ui.Image image = await boundary.toImage(pixelRatio: 1.0);
        final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        if (byteData != null && mounted) {
          Navigator.of(context).pop(byteData.buffer.asUint8List());
          return;
        }
      }
    } catch (e) {
      debugPrint("Crop error: $e");
    } finally {
      if (mounted) setState(() => _isCropping = false);
    }
  }

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E2829) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [
            BoxShadow(color: Colors.black45, blurRadius: 20, offset: Offset(0, 8)),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00796B).withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.crop_rounded, color: Color(0xFF00796B), size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      "Crop Face (Passport Size)",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                    tooltip: "Cancel",
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                "Pinch to zoom and drag to position face inside the passport frame.",
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white70 : Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 14),

              // Passport Cropping Viewport
              Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: 220,
                    height: 260,
                    color: Colors.black,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // The captured boundary
                        RepaintBoundary(
                          key: _cropKey,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: SizedBox(
                              width: 220,
                              height: 260,
                              child: InteractiveViewer(
                                transformationController: _transformController,
                                clipBehavior: Clip.hardEdge,
                                minScale: 0.5,
                                maxScale: 4.0,
                                boundaryMargin: const EdgeInsets.all(200),
                                child: Image.memory(
                                  widget.imageBytes,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                          ),
                        ),

                        // Aesthetic Face Outline & Framing Overlay (IgnorePointer so touches pass through)
                        IgnorePointer(
                          child: CustomPaint(
                            size: const Size(220, 260),
                            painter: _PassportGuidePainter(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Quick reset button
              TextButton.icon(
                onPressed: _resetTransform,
                icon: const Icon(Icons.restart_alt_rounded, size: 18),
                label: const Text("Reset Position"),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF00796B),
                ),
              ),
              const SizedBox(height: 8),

              // Actions Row
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text("Cancel"),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: _isCropping ? null : _cropAndReturn,
                      icon: _isCropping
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Icon(Icons.check_circle_rounded),
                      label: Text(_isCropping ? "Cropping..." : "Crop & Use Face"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00796B),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Custom painter for passport face silhouette guide and framing corners
class _PassportGuidePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // Oval face silhouette guide
    final ovalRect = Rect.fromCenter(
      center: Offset(center.dx, center.dy - 10),
      width: size.width * 0.60,
      height: size.height * 0.68,
    );
    final guidePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    canvas.drawOval(ovalRect, guidePaint);

    // Corner bracket markers for passport framing
    final cornerPaint = Paint()
      ..color = const Color(0xFF2DD4BF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    const cornerLen = 18.0;
    const pad = 12.0;

    // Top-Left
    canvas.drawLine(const Offset(pad, pad), const Offset(pad + cornerLen, pad), cornerPaint);
    canvas.drawLine(const Offset(pad, pad), const Offset(pad, pad + cornerLen), cornerPaint);

    // Top-Right
    canvas.drawLine(Offset(size.width - pad, pad), Offset(size.width - pad - cornerLen, pad), cornerPaint);
    canvas.drawLine(Offset(size.width - pad, pad), Offset(size.width - pad, pad + cornerLen), cornerPaint);

    // Bottom-Left
    canvas.drawLine(Offset(pad, size.height - pad), Offset(pad + cornerLen, size.height - pad), cornerPaint);
    canvas.drawLine(Offset(pad, size.height - pad), Offset(pad, size.height - pad - cornerLen), cornerPaint);

    // Bottom-Right
    canvas.drawLine(Offset(size.width - pad, size.height - pad), Offset(size.width - pad - cornerLen, size.height - pad), cornerPaint);
    canvas.drawLine(Offset(size.width - pad, size.height - pad), Offset(size.width - pad, size.height - pad - cornerLen), cornerPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
