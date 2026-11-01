class FamilyMember {
  final String id;
  final String name;
  final String relation; // Display name e.g. 'Son', 'Wife'
  final String relationKey; // Translation key e.g. 'rel_son', 'rel_wife'
  final String imageBase64; // Base64 encoded JPEG/PNG or asset path
  final bool isDefaultAsset; // true if built-in demo avatar
  final DateTime createdAt;

  const FamilyMember({
    required this.id,
    required this.name,
    required this.relation,
    this.relationKey = '',
    required this.imageBase64,
    this.isDefaultAsset = false,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'relation': relation,
      'relationKey': relationKey,
      'imageBase64': imageBase64,
      'isDefaultAsset': isDefaultAsset,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory FamilyMember.fromMap(Map<String, dynamic> map) {
    return FamilyMember(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      relation: map['relation'] as String? ?? '',
      relationKey: map['relationKey'] as String? ?? '',
      imageBase64: map['imageBase64'] as String? ?? '',
      isDefaultAsset: map['isDefaultAsset'] as bool? ?? false,
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  FamilyMember copyWith({
    String? id,
    String? name,
    String? relation,
    String? relationKey,
    String? imageBase64,
    bool? isDefaultAsset,
    DateTime? createdAt,
  }) {
    return FamilyMember(
      id: id ?? this.id,
      name: name ?? this.name,
      relation: relation ?? this.relation,
      relationKey: relationKey ?? this.relationKey,
      imageBase64: imageBase64 ?? this.imageBase64,
      isDefaultAsset: isDefaultAsset ?? this.isDefaultAsset,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// 8 Pre-configured authentic demo family members for immediate zero-friction gameplay
  static List<FamilyMember> getDefaultDemoMembers() {
    return [
      FamilyMember(
        id: 'demo_1',
        name: 'Rohan',
        relation: 'Son',
        relationKey: 'rel_son',
        imageBase64: 'assets/images/memory_cards/traditional_dress.png',
        isDefaultAsset: true,
        createdAt: DateTime(2026, 1, 1),
      ),
      FamilyMember(
        id: 'demo_2',
        name: 'Sunita',
        relation: 'Wife',
        relationKey: 'rel_wife',
        imageBase64: 'assets/images/memory_cards/handloom_fabric.png',
        isDefaultAsset: true,
        createdAt: DateTime(2026, 1, 2),
      ),
      FamilyMember(
        id: 'demo_3',
        name: 'Priya',
        relation: 'Daughter',
        relationKey: 'rel_daughter',
        imageBase64: 'assets/images/memory_cards/orchid.png',
        isDefaultAsset: true,
        createdAt: DateTime(2026, 1, 3),
      ),
      FamilyMember(
        id: 'demo_4',
        name: 'Aarav',
        relation: 'Grandson',
        relationKey: 'rel_grandson',
        imageBase64: 'assets/images/memory_cards/hornbill.png',
        isDefaultAsset: true,
        createdAt: DateTime(2026, 1, 4),
      ),
      FamilyMember(
        id: 'demo_5',
        name: 'Maya',
        relation: 'Granddaughter',
        relationKey: 'rel_granddaughter',
        imageBase64: 'assets/images/memory_cards/rhododendron.png',
        isDefaultAsset: true,
        createdAt: DateTime(2026, 1, 5),
      ),
      FamilyMember(
        id: 'demo_6',
        name: 'Rajesh',
        relation: 'Brother',
        relationKey: 'rel_brother',
        imageBase64: 'assets/images/memory_cards/traditional_house.png',
        isDefaultAsset: true,
        createdAt: DateTime(2026, 1, 6),
      ),
      FamilyMember(
        id: 'demo_7',
        name: 'Ananya',
        relation: 'Sister',
        relationKey: 'rel_sister',
        imageBase64: 'assets/images/memory_cards/traditional_jewellery.png',
        isDefaultAsset: true,
        createdAt: DateTime(2026, 1, 7),
      ),
      FamilyMember(
        id: 'demo_8',
        name: 'Suresh',
        relation: 'Friend',
        relationKey: 'rel_friend',
        imageBase64: 'assets/images/memory_cards/tea_leaves.png',
        isDefaultAsset: true,
        createdAt: DateTime(2026, 1, 8),
      ),
    ];
  }
}
