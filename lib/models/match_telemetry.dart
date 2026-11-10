// lib/models/match_telemetry.dart
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'sports_tournament.dart';

/// Supported types of live match events.
enum MatchEventType {
  goal,
  basket,
  threePointer,
  ace,
  point,
  foul,
  yellowCard,
  redCard,
  periodChange;

  String get displayName {
    switch (this) {
      case MatchEventType.goal:
        return 'GOAL! ⚽';
      case MatchEventType.basket:
        return 'BASKET! 🏀 (+2)';
      case MatchEventType.threePointer:
        return '3-POINTER! 🔥 (+3)';
      case MatchEventType.ace:
        return 'SERVICE ACE! 🏐';
      case MatchEventType.point:
        return 'POINT! 🏐';
      case MatchEventType.foul:
        return 'FOUL ⚠️';
      case MatchEventType.yellowCard:
        return 'YELLOW CARD 🟨';
      case MatchEventType.redCard:
        return 'RED CARD 🟥';
      case MatchEventType.periodChange:
        return 'PERIOD UPDATE ⏱️';
    }
  }

  static MatchEventType fromString(String val) {
    switch (val.toLowerCase().trim()) {
      case 'goal':
        return MatchEventType.goal;
      case 'basket':
        return MatchEventType.basket;
      case 'threepointer':
      case 'three_pointer':
        return MatchEventType.threePointer;
      case 'ace':
        return MatchEventType.ace;
      case 'point':
        return MatchEventType.point;
      case 'foul':
        return MatchEventType.foul;
      case 'yellowcard':
      case 'yellow_card':
        return MatchEventType.yellowCard;
      case 'redcard':
      case 'red_card':
        return MatchEventType.redCard;
      case 'periodchange':
      case 'period_change':
      default:
        return MatchEventType.periodChange;
    }
  }
}

/// Represents an immutable chronological event logged during live play.
class LiveMatchEvent {
  final String eventId;
  final String fixtureId;
  final MatchEventType eventType;
  final String houseName;
  final String? playerScholarNo;
  final String? playerName;
  final int? minute;
  final String periodDescription;
  final int scoreAAfter;
  final int scoreBAfter;
  final DateTime timestamp;

  LiveMatchEvent({
    required this.eventId,
    required this.fixtureId,
    required this.eventType,
    required this.houseName,
    this.playerScholarNo,
    this.playerName,
    this.minute,
    required this.periodDescription,
    required this.scoreAAfter,
    required this.scoreBAfter,
    required this.timestamp,
  });

  String get commentaryText {
    final playerStr = playerName != null && playerName!.isNotEmpty
        ? ' by $playerName'
        : '';
    final minStr = minute != null ? ' ($minute\')' : '';
    final houseDisplay = houseName.isNotEmpty
        ? '${houseName[0].toUpperCase()}${houseName.substring(1)} House'
        : 'House';

    switch (eventType) {
      case MatchEventType.goal:
        return '⚽ GOAL for $houseDisplay$playerStr!$minStr [$scoreAAfter - $scoreBAfter]';
      case MatchEventType.basket:
        return '🏀 2-Point Basket for $houseDisplay$playerStr! [$scoreAAfter - $scoreBAfter]';
      case MatchEventType.threePointer:
        return '🔥 3-POINTER for $houseDisplay$playerStr! [$scoreAAfter - $scoreBAfter]';
      case MatchEventType.ace:
        return '🏐 Service Ace by $houseDisplay$playerStr! [$scoreAAfter - $scoreBAfter]';
      case MatchEventType.point:
        return '🏐 Point scored by $houseDisplay$playerStr! [$scoreAAfter - $scoreBAfter]';
      case MatchEventType.foul:
        return '⚠️ Foul called against $houseDisplay$playerStr$minStr';
      case MatchEventType.yellowCard:
        return '🟨 Yellow Card issued to $houseDisplay$playerStr$minStr';
      case MatchEventType.redCard:
        return '🟥 Red Card issued to $houseDisplay$playerStr$minStr';
      case MatchEventType.periodChange:
        return '⏱️ $periodDescription commenced [$scoreAAfter - $scoreBAfter]';
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'event_id': eventId,
      'fixture_id': fixtureId,
      'event_type': eventType.name,
      'house_name': houseName.toLowerCase(),
      'player_scholar_no': playerScholarNo,
      'player_name': playerName,
      'minute': minute,
      'period_description': periodDescription,
      'score_a_after': scoreAAfter,
      'score_b_after': scoreBAfter,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory LiveMatchEvent.fromMap(Map<String, dynamic> map) {
    DateTime parseDate(dynamic v) {
      if (v is Timestamp) return v.toDate();
      if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
      return DateTime.now();
    }

    return LiveMatchEvent(
      eventId: (map['event_id'] ?? '').toString(),
      fixtureId: (map['fixture_id'] ?? '').toString(),
      eventType: MatchEventType.fromString((map['event_type'] ?? 'goal').toString()),
      houseName: (map['house_name'] ?? 'ruby').toString().toLowerCase(),
      playerScholarNo: map['player_scholar_no']?.toString(),
      playerName: map['player_name']?.toString(),
      minute: (map['minute'] as num?)?.toInt(),
      periodDescription: (map['period_description'] ?? 'Live Play').toString(),
      scoreAAfter: (map['score_a_after'] as num?)?.toInt() ?? 0,
      scoreBAfter: (map['score_b_after'] as num?)?.toInt() ?? 0,
      timestamp: parseDate(map['timestamp']),
    );
  }

  String toJson() => jsonEncode(toMap());
  factory LiveMatchEvent.fromJson(String source) =>
      LiveMatchEvent.fromMap(jsonDecode(source) as Map<String, dynamic>);
}

/// Provides sport-specific periods and dynamic clock formatting.
class LiveMatchClock {
  static List<String> getPeriodsForSport(SportType sport) {
    switch (sport) {
      case SportType.football:
        return ['1st Half', 'Halftime', '2nd Half', 'Extra Time', 'Full Time'];
      case SportType.basketball:
        return ['Q1', 'Q2', 'Halftime', 'Q3', 'Q4', 'Overtime', 'Final'];
      case SportType.volleyball:
        return ['Set 1', 'Set 2', 'Set 3', 'Set 4', 'Set 5', 'Match Final'];
      case SportType.trackAndField:
        return ['Heats', 'Semi-Finals', 'Finals'];
    }
  }

  /// Returns recommended duration in minutes for the given period.
  static int getDefaultDurationMinutes({
    required SportType sport,
    required String period,
  }) {
    final p = period.toLowerCase();
    if (p.contains('halftime') || p.contains('break') || p.contains('interval')) {
      return 5;
    }
    switch (sport) {
      case SportType.football:
        return 20;
      case SportType.basketball:
        return 10;
      case SportType.volleyball:
        return 15;
      case SportType.trackAndField:
        return 5;
    }
  }

  /// Checks if period is a halftime or interval break.
  static bool isBreakPeriod(String period) {
    final p = period.toLowerCase();
    return p.contains('halftime') || p.contains('break') || p.contains('interval');
  }

  /// Checks if period is the final concluding period of standard play.
  static bool isFinalPeriod({
    required SportType sport,
    required String period,
  }) {
    final p = period.toLowerCase();
    switch (sport) {
      case SportType.football:
        return p == '2nd half' || p == 'full time' || p == 'extra time';
      case SportType.basketball:
        return p == 'q4' || p == 'final' || p == 'overtime';
      case SportType.volleyball:
        return p == 'set 3' || p == 'set 5' || p == 'match final';
      case SportType.trackAndField:
        return p == 'finals';
    }
  }

  /// Formats seconds into MM:SS string.
  static String formatSeconds(int totalSeconds) {
    if (totalSeconds < 0) totalSeconds = 0;
    final m = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  static String formatClock({
    required SportType sport,
    required String currentPeriod,
    int elapsedMinutes = 0,
    int elapsedSeconds = 0,
  }) {
    final m = elapsedMinutes.toString().padLeft(2, '0');
    final s = elapsedSeconds.toString().padLeft(2, '0');

    switch (sport) {
      case SportType.football:
        return '$currentPeriod • $m:$s';
      case SportType.basketball:
        return '$currentPeriod • $m:$s Remaining';
      case SportType.volleyball:
        return '$currentPeriod in progress';
      case SportType.trackAndField:
        return '$currentPeriod Track Time';
    }
  }
}
