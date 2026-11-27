import 'package:cloud_firestore/cloud_firestore.dart';

import '../services/hierarchy_service.dart';

/// Canonical house identifiers used across the app.
const List<String> kHouseIds = ['ruby', 'sapphire', 'emerald', 'topaz'];

/// Message categories supported by house groups.
const List<String> kHouseGroupCategories = [
  'general',
  'announcement',
  'event',
  'sports',
];

const Map<String, String> kHouseGroupCategoryLabels = {
  'general': 'General',
  'announcement': 'Announcements',
  'event': 'Events',
  'sports': 'Sports',
};

String houseGroupDisplayTitle(String houseId) {
  final id = houseId.trim().toLowerCase();
  if (id.isEmpty) return 'House';
  return '${id[0].toUpperCase()}${id.substring(1)}';
}

String normalizeHouseGroupCategory(String value) {
  final clean = value.trim().toLowerCase();
  return kHouseGroupCategories.contains(clean) ? clean : 'general';
}

String houseGroupCategoryLabel(String value) =>
    kHouseGroupCategoryLabels[normalizeHouseGroupCategory(value)] ?? 'General';

DateTime? _parseDateTime(dynamic raw) {
  if (raw == null) return null;
  if (raw is Timestamp) return raw.toDate();
  if (raw is DateTime) return raw;
  if (raw is String && raw.trim().isNotEmpty) {
    return DateTime.tryParse(raw.trim());
  }
  return null;
}

/// Read-only descriptor for a house group.
///
/// Membership is intentionally **not** stored here. It is derived from the
/// verified `house_name` on the user profile, so a house transfer revokes the
/// old group and grants the new one automatically.
class HouseGroup {
  final String houseId;
  final String name;
  final String description;
  final String lastMessage;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const HouseGroup({
    required this.houseId,
    required this.name,
    required this.description,
    this.lastMessage = '',
    this.createdAt,
    this.updatedAt,
  });

  static HouseGroup defaultsFor(String houseId) {
    final id = houseId.trim().toLowerCase();
    final title = houseGroupDisplayTitle(id);
    return HouseGroup(
      houseId: id,
      name: '$title House Group',
      description:
          'Official $title House channel for announcements, events, and sports updates.',
    );
  }

  String get displayName => name.trim().isNotEmpty ? name.trim() : defaultsFor(houseId).name;

  Map<String, dynamic> toMap() {
    return {
      'house_id': houseId,
      'name': name,
      'description': description,
      'last_message': lastMessage,
      if (createdAt != null) 'created_at': Timestamp.fromDate(createdAt!),
      if (updatedAt != null) 'updated_at': Timestamp.fromDate(updatedAt!),
    };
  }

  factory HouseGroup.fromMap(String houseId, Map<String, dynamic> data) {
    final fallback = defaultsFor(houseId);
    return HouseGroup(
      houseId: (data['house_id'] ?? houseId).toString().toLowerCase(),
      name: (data['name'] ?? fallback.name).toString(),
      description: (data['description'] ?? fallback.description).toString(),
      lastMessage: (data['last_message'] ?? '').toString(),
      createdAt: _parseDateTime(data['created_at']),
      updatedAt: _parseDateTime(data['updated_at']),
    );
  }

  HouseGroup copyWith({
    String? name,
    String? description,
    String? lastMessage,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return HouseGroup(
      houseId: houseId,
      name: name ?? this.name,
      description: description ?? this.description,
      lastMessage: lastMessage ?? this.lastMessage,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// A message posted in a house group.
class HouseGroupMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String senderRole;
  final String senderHouse;
  final String text;
  final String category;
  final String attachmentUrl;
  final bool isPinned;
  final bool isHidden;
  final String moderatedBy;
  final DateTime? timestamp;

  HouseGroupMessage({
    this.id = '',
    required this.senderId,
    required this.senderName,
    this.senderRole = 'Student Member',
    required this.senderHouse,
    this.text = '',
    String category = 'general',
    this.attachmentUrl = '',
    this.isPinned = false,
    this.isHidden = false,
    this.moderatedBy = '',
    this.timestamp,
  }) : category = normalizeHouseGroupCategory(category);

  bool get hasAttachment => attachmentUrl.trim().isNotEmpty;
  bool get hasText => text.trim().isNotEmpty;
  bool get isAnnouncement => normalizeHouseGroupCategory(category) == 'announcement';
  String get categoryLabel => houseGroupCategoryLabel(category);
  String get previewText {
    if (hasText) return text.trim();
    return hasAttachment ? 'Photo attachment' : '';
  }

  Map<String, dynamic> toMap() {
    return {
      'sender_id': senderId,
      'sender_name': senderName,
      'sender_role': senderRole,
      'sender_house': senderHouse.toLowerCase().trim(),
      'text': text.trim(),
      'category': normalizeHouseGroupCategory(category),
      'attachment_url': attachmentUrl.trim(),
      'is_pinned': isPinned,
      'is_hidden': isHidden,
      'moderated_by': moderatedBy,
      if (timestamp != null) 'timestamp': Timestamp.fromDate(timestamp!),
    };
  }

  factory HouseGroupMessage.fromMap(String id, Map<String, dynamic> data) {
    return HouseGroupMessage(
      id: id,
      senderId: (data['sender_id'] ?? '').toString(),
      senderName: (data['sender_name'] ?? 'House Member').toString(),
      senderRole: (data['sender_role'] ?? 'Student Member').toString(),
      senderHouse: (data['sender_house'] ?? '').toString().toLowerCase(),
      text: (data['text'] ?? '').toString(),
      category: normalizeHouseGroupCategory((data['category'] ?? 'general').toString()),
      attachmentUrl: (data['attachment_url'] ?? '').toString(),
      isPinned: data['is_pinned'] == true,
      isHidden: data['is_hidden'] == true,
      moderatedBy: (data['moderated_by'] ?? '').toString(),
      timestamp: _parseDateTime(data['timestamp']),
    );
  }

  HouseGroupMessage copyWith({
    String? id,
    String? senderId,
    String? senderName,
    String? senderRole,
    String? senderHouse,
    String? text,
    String? category,
    String? attachmentUrl,
    bool? isPinned,
    bool? isHidden,
    String? moderatedBy,
    DateTime? timestamp,
  }) {
    return HouseGroupMessage(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      senderRole: senderRole ?? this.senderRole,
      senderHouse: senderHouse ?? this.senderHouse,
      text: text ?? this.text,
      category: category ?? this.category,
      attachmentUrl: attachmentUrl ?? this.attachmentUrl,
      isPinned: isPinned ?? this.isPinned,
      isHidden: isHidden ?? this.isHidden,
      moderatedBy: moderatedBy ?? this.moderatedBy,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}

/// Client-side mirror of the house-group rules. Kept pure so tests can verify
/// every authorised role without a Firebase emulator.
///
/// Authorised senders:
/// - house captain / vice-captain (`isCaptain`)
/// - sports captain/vice, head boy/girl, council (`isCouncil`)
/// - teachers, faculty, principal, staff (`isAdmin`)
///
/// Regular students and prefects are read-only.
class HouseGroupAccess {
  static String resolveHouse(Map<String, dynamic>? profile) {
    if (profile == null) return '';
    final raw = profile['house_name'] ??
        profile['houseName'] ??
        profile['house'] ??
        profile['house_id'];
    final clean = (raw ?? '').toString().trim().toLowerCase();
    if (clean.isEmpty) return '';
    for (final house in kHouseIds) {
      if (clean == house || clean.contains(house)) return house;
    }
    return '';
  }

  static String roleOf(Map<String, dynamic>? profile) =>
      (profile?['role'] ?? '').toString().trim();

  static String scholarOf(Map<String, dynamic>? profile) =>
      (profile?['scholar_no'] ?? profile?['scholarNo'] ?? '').toString().trim();

  static String nameOf(Map<String, dynamic>? profile) =>
      (profile?['full_name'] ?? profile?['name'] ?? 'House Member')
          .toString()
          .trim();

  static bool isSeniorAdmin(Map<String, dynamic>? profile) {
    if (profile == null) return false;
    return HierarchyService.isSeniorAdmin(
      scholarNo: scholarOf(profile),
      role: roleOf(profile),
      fullName: nameOf(profile),
    );
  }

  static bool isAuthorizedSender(Map<String, dynamic>? profile) {
    if (profile == null) return false;
    final scholarNo = scholarOf(profile);
    final role = roleOf(profile);
    final name = nameOf(profile);
    // Deliberately excludes prefects: HierarchyService.isAdmin() includes
    // them, but prefects are read-only in house groups, matching the rules.
    return HierarchyService.isSuperAdmin(
          scholarNo: scholarNo,
          role: role,
          fullName: name,
        ) ||
        HierarchyService.isTeacherOrFaculty(
          scholarNo: scholarNo,
          role: role,
          fullName: name,
        ) ||
        HierarchyService.isCaptain(
          scholarNo: scholarNo,
          role: role,
          fullName: name,
        ) ||
        HierarchyService.isCouncil(
          scholarNo: scholarNo,
          role: role,
          fullName: name,
        );
  }

  static bool isSameHouse(Map<String, dynamic>? profile, String houseId) {
    final target = houseId.trim().toLowerCase();
    return target.isNotEmpty && resolveHouse(profile) == target;
  }

  static bool canView(Map<String, dynamic>? profile, String houseId) {
    if (profile == null) return false;
    return isSameHouse(profile, houseId) || isSeniorAdmin(profile);
  }

  static bool canSend(Map<String, dynamic>? profile, String houseId) {
    return isSameHouse(profile, houseId) && isAuthorizedSender(profile);
  }

  static bool canModerate(Map<String, dynamic>? profile, String houseId) {
    return isSeniorAdmin(profile) || canSend(profile, houseId);
  }

  static bool canAttach(Map<String, dynamic>? profile, String houseId) =>
      canSend(profile, houseId);
}
