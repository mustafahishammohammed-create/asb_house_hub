import 'package:cloud_firestore/cloud_firestore.dart';

enum BallotPosition {
  all,
  headBoy,
  headGirl,
  houseCaptain,
  viceCaptain,
  culturalSecretary,
  sportsCaptain,
  prefect,
}

extension BallotPositionExt on BallotPosition {
  String get displayName {
    switch (this) {
      case BallotPosition.all:
        return 'All Positions';
      case BallotPosition.headBoy:
        return 'School Head Boy';
      case BallotPosition.headGirl:
        return 'School Head Girl';
      case BallotPosition.houseCaptain:
        return 'House Captain';
      case BallotPosition.viceCaptain:
        return 'House Vice-Captain';
      case BallotPosition.culturalSecretary:
        return 'Cultural Secretary';
      case BallotPosition.sportsCaptain:
        return 'Sports Captain';
      case BallotPosition.prefect:
        return 'Class Prefect';
    }
  }

  static BallotPosition fromString(String? val) {
    final clean = (val ?? '').trim().toLowerCase();
    for (final p in BallotPosition.values) {
      if (p.name.toLowerCase() == clean) return p;
    }
    return BallotPosition.all;
  }
}

enum BallotStatus { upcoming, open, closed, certified }

extension BallotStatusExt on BallotStatus {
  String get displayName {
    switch (this) {
      case BallotStatus.upcoming:
        return 'Upcoming Poll';
      case BallotStatus.open:
        return 'Voting Active';
      case BallotStatus.closed:
        return 'Poll Closed';
      case BallotStatus.certified:
        return 'Certified Results';
    }
  }

  static BallotStatus fromString(String? val) {
    final clean = (val ?? '').trim().toLowerCase();
    if (clean == 'published' || clean == 'active' || clean == 'open') {
      return BallotStatus.open;
    }
    if (clean == 'certified' || clean == 'concluded' || clean == 'finished') {
      return BallotStatus.certified;
    }
    if (clean == 'closed' || clean == 'ended' || clean == 'expired') {
      return BallotStatus.closed;
    }
    for (final s in BallotStatus.values) {
      if (s.name.toLowerCase() == clean) return s;
    }
    return BallotStatus.upcoming;
  }
}

int _safeInt(dynamic val) {
  if (val == null) return 0;
  if (val is num) return val.toInt();
  return int.tryParse(val.toString()) ?? 0;
}

class ElectionCandidate {
  final String id;
  final String scholarNo;
  final String fullName;
  final String houseName;
  final String runningPosition;
  final String manifesto;
  final String avatarUrl;
  final String classLevel;
  final int votesCount;
  final bool isVerified;

  ElectionCandidate({
    this.id = '',
    required this.scholarNo,
    required this.fullName,
    required this.houseName,
    required this.runningPosition,
    required this.manifesto,
    this.avatarUrl = '',
    this.classLevel = '',
    this.votesCount = 0,
    this.isVerified = false,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id.isNotEmpty) 'id': id,
      'scholar_no': scholarNo,
      'full_name': fullName,
      'house_name': houseName,
      'running_position': runningPosition,
      'manifesto': manifesto,
      'avatar_url': avatarUrl,
      'class_level': classLevel,
      'votes_count': votesCount,
      'is_verified': isVerified,
    };
  }

  factory ElectionCandidate.fromMap(Map<String, dynamic> map) {
    return ElectionCandidate(
      id: (map['id'] ?? map['candidate_id'] ?? map['candidateId'] ?? '').toString().trim(),
      scholarNo: (map['scholar_no'] ?? map['scholarNo'] ?? map['id'] ?? '').toString().trim(),
      fullName: (map['full_name'] ?? map['fullName'] ?? map['name'] ?? 'Candidate').toString().trim(),
      houseName: (map['house_name'] ?? map['houseName'] ?? map['house'] ?? '').toString().trim().toLowerCase(),
      runningPosition: (map['running_position'] ?? map['runningPosition'] ?? map['position'] ?? 'House Captain').toString(),
      manifesto: (map['manifesto'] ?? map['statement'] ?? '').toString(),
      avatarUrl: (map['avatar_url'] ?? map['avatarUrl'] ?? '').toString(),
      classLevel: (map['class_level'] ?? map['classLevel'] ?? '').toString(),
      votesCount: _safeInt(map['votes_count'] ?? map['votesCount'] ?? map['count']),
      isVerified: map['is_verified'] == true || map['isVerified'] == true,
    );
  }
}

class ElectionBallot implements Comparable<ElectionBallot> {
  final String id;
  final String title;
  final BallotPosition position;
  final String houseScope;
  final List<String> eligibleGrades;
  final BallotStatus status;
  final DateTime startTime;
  final DateTime endTime;
  final List<ElectionCandidate> candidates;
  final int totalVotesCast;

  ElectionBallot({
    required this.id,
    required this.title,
    required this.position,
    this.houseScope = '',
    this.eligibleGrades = const [],
    required this.status,
    required this.startTime,
    required this.endTime,
    this.candidates = const [],
    this.totalVotesCast = 0,
  });

  bool get isOpen => status == BallotStatus.open && endTime.millisecondsSinceEpoch > 0;

  bool get isCertified => status == BallotStatus.certified;

  ElectionBallot copyWith({
    String? id,
    String? title,
    BallotPosition? position,
    String? houseScope,
    List<String>? eligibleGrades,
    BallotStatus? status,
    DateTime? startTime,
    DateTime? endTime,
    List<ElectionCandidate>? candidates,
    int? totalVotesCast,
    bool? isCertified,
  }) {
    return ElectionBallot(
      id: id ?? this.id,
      title: title ?? this.title,
      position: position ?? this.position,
      houseScope: houseScope ?? this.houseScope,
      eligibleGrades: eligibleGrades ?? this.eligibleGrades,
      status: (isCertified == true) ? BallotStatus.certified : (status ?? this.status),
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      candidates: candidates ?? this.candidates,
      totalVotesCast: totalVotesCast ?? this.totalVotesCast,
    );
  }

  Duration get timeRemaining => endTime.difference(DateTime.now());

  String get formattedRemaining {
    final rem = timeRemaining;
    if (rem.isNegative) return 'Poll Closed';
    if (rem.inHours > 0) return '${rem.inHours}h ${rem.inMinutes % 60}m remaining';
    return '${rem.inMinutes}m remaining';
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'position': position.name,
      'house_scope': houseScope,
      'eligible_grades': eligibleGrades,
      'status': status.name,
      'start_time': startTime.toIso8601String(),
      'end_time': endTime.toIso8601String(),
      'candidates': candidates.map((c) => c.toMap()).toList(),
      'total_votes_cast': totalVotesCast,
    };
  }

  factory ElectionBallot.fromMap(Map<String, dynamic> map, {String? docId}) {
    DateTime parseDate(dynamic v) {
      if (v is Timestamp) return v.toDate();
      if (v is DateTime) return v;
      if (v is num) return DateTime.fromMillisecondsSinceEpoch(v.toInt());
      if (v is String) return DateTime.tryParse(v) ?? DateTime.fromMillisecondsSinceEpoch(0);
      return DateTime.fromMillisecondsSinceEpoch(0);
    }

    final rawCandidates = map['candidates'];
    final List<ElectionCandidate> candList = [];
    if (rawCandidates is List) {
      for (final item in rawCandidates) {
        if (item is Map) {
          candList.add(ElectionCandidate.fromMap(Map<String, dynamic>.from(item)));
        }
      }
    }

    final rawGrades = map['eligible_grades'];
    final List<String> gradeList = [];
    if (rawGrades is List) {
      for (final g in rawGrades) {
        gradeList.add(g.toString());
      }
    }

    final isCertifiedBool = map['is_certified'] == true || map['isCertified'] == true;
    final parsedStatus = isCertifiedBool
        ? BallotStatus.certified
        : BallotStatusExt.fromString(map['status']?.toString());

    return ElectionBallot(
      id: docId ?? map['id']?.toString() ?? '',
      title: map['title']?.toString() ?? 'Election',
      position: BallotPositionExt.fromString(map['position']?.toString() ?? map['running_position']?.toString()),
      houseScope: map['house_scope']?.toString() ?? map['house']?.toString() ?? '',
      eligibleGrades: gradeList,
      status: parsedStatus,
      startTime: parseDate(map['start_time'] ?? map['opensAt'] ?? map['startMs']),
      endTime: parseDate(map['end_time'] ?? map['closesAt'] ?? map['endMs']),
      candidates: candList,
      totalVotesCast: _safeInt(map['total_votes_cast'] ?? map['totalVotesCast']),
    );
  }

  @override
  int compareTo(ElectionBallot other) => startTime.compareTo(other.startTime);
}
