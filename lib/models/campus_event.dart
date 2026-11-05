import 'package:cloud_firestore/cloud_firestore.dart';

enum EventCategory { all, cultural, sports, academic, arts, tech }

extension EventCategoryExt on EventCategory {
  String get displayName {
    switch (this) {
      case EventCategory.all:
        return 'All Events';
      case EventCategory.cultural:
        return 'Cultural';
      case EventCategory.sports:
        return 'Sports';
      case EventCategory.academic:
        return 'Academic';
      case EventCategory.arts:
        return 'Arts';
      case EventCategory.tech:
        return 'Technology';
    }
  }

  static EventCategory fromString(String? val) {
    final clean = (val ?? '').trim().toLowerCase();
    for (final c in EventCategory.values) {
      if (c.name.toLowerCase() == clean) return c;
    }
    return EventCategory.all;
  }
}

class CampusEvent implements Comparable<CampusEvent> {
  final String id;
  final String title;
  final String description;
  final EventCategory category;
  final String houseScope; // 'All' or specific house: 'ruby', 'sapphire', etc.
  final DateTime startTime;
  final DateTime endTime;
  final String venue;
  final int pointsAwarded;
  final double pointsMultiplier;
  final String bannerUrl; // Supports Base64 data URIs and HTTPS URLs
  final bool isLive;

  CampusEvent({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    this.houseScope = 'All',
    required this.startTime,
    required this.endTime,
    required this.venue,
    this.pointsAwarded = 0,
    this.pointsMultiplier = 1.0,
    this.bannerUrl = '',
    this.isLive = false,
  });

  bool get isOngoing {
    final now = DateTime.now();
    return now.isAfter(startTime) && now.isBefore(endTime);
  }

  bool get isUpcoming => DateTime.now().isBefore(startTime);

  Duration get timeRemaining => endTime.difference(DateTime.now());

  String get formattedRemaining {
    final rem = timeRemaining;
    if (rem.isNegative) return 'Concluded';
    if (rem.inHours > 0) return '${rem.inHours}h ${rem.inMinutes % 60}m remaining';
    return '${rem.inMinutes}m remaining';
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'category': category.name,
      'house_scope': houseScope,
      'start_time': startTime.toIso8601String(),
      'end_time': endTime.toIso8601String(),
      'venue': venue,
      'points_awarded': pointsAwarded,
      'points_multiplier': pointsMultiplier,
      'banner_url': bannerUrl,
      'is_live': isLive,
    };
  }

  factory CampusEvent.fromMap(Map<String, dynamic> map, {String? docId}) {
    DateTime parseDate(dynamic v) {
      if (v is Timestamp) return v.toDate();
      if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
      return DateTime.now();
    }

    return CampusEvent(
      id: docId ?? map['id']?.toString() ?? '',
      title: map['title']?.toString() ?? 'Event',
      description: map['description']?.toString() ?? '',
      category: EventCategoryExt.fromString(map['category']?.toString()),
      houseScope: map['house_scope']?.toString() ?? 'All',
      startTime: parseDate(map['start_time']),
      endTime: parseDate(map['end_time']),
      venue: map['venue']?.toString() ?? 'Campus Grounds',
      pointsAwarded: (map['points_awarded'] as num?)?.toInt() ?? 0,
      pointsMultiplier: (map['points_multiplier'] as num?)?.toDouble() ?? 1.0,
      bannerUrl: map['banner_url']?.toString() ?? '',
      isLive: map['is_live'] == true,
    );
  }

  @override
  int compareTo(CampusEvent other) => startTime.compareTo(other.startTime);
}
