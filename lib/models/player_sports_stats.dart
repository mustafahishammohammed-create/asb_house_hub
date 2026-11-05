// lib/models/player_sports_stats.dart
import 'dart:convert';
import 'sports_tournament.dart';

/// Accolade categories for individual player recognition.
enum SportAccoladeType {
  goldenBoot,
  scoringChampion,
  aceLeader,
  trackVictor,
  matchMvp;

  String get title {
    switch (this) {
      case SportAccoladeType.goldenBoot:
        return 'Golden Boot Leader';
      case SportAccoladeType.scoringChampion:
        return 'Scoring Champion';
      case SportAccoladeType.aceLeader:
        return 'Service Ace Specialist';
      case SportAccoladeType.trackVictor:
        return 'Track & Field Victor';
      case SportAccoladeType.matchMvp:
        return 'Match Day MVP';
    }
  }

  String get emoji {
    switch (this) {
      case SportAccoladeType.goldenBoot:
        return '⚽ 👟';
      case SportAccoladeType.scoringChampion:
        return '🏀 👑';
      case SportAccoladeType.aceLeader:
        return '🏐 ⚡';
      case SportAccoladeType.trackVictor:
        return '🏃 🥇';
      case SportAccoladeType.matchMvp:
        return '🏅 ⭐';
    }
  }

  static SportAccoladeType forSport(SportType sport) {
    switch (sport) {
      case SportType.football:
        return SportAccoladeType.goldenBoot;
      case SportType.basketball:
        return SportAccoladeType.scoringChampion;
      case SportType.volleyball:
        return SportAccoladeType.aceLeader;
      case SportType.trackAndField:
        return SportAccoladeType.trackVictor;
    }
  }
}

/// Encapsulates a scholar's athletic performance across the season.
class PlayerSportsStats {
  final String scholarNo;
  final String studentName;
  final String houseName;
  final SportType sportType;
  final int goalsScored;
  final int basketsScored;
  final int acesScored;
  final int trackPoints;
  final int mvpAwardsCount;
  final int matchesPlayed;

  PlayerSportsStats({
    required this.scholarNo,
    required this.studentName,
    required this.houseName,
    required this.sportType,
    this.goalsScored = 0,
    this.basketsScored = 0,
    this.acesScored = 0,
    this.trackPoints = 0,
    this.mvpAwardsCount = 0,
    this.matchesPlayed = 0,
  });

  int get primaryStat {
    switch (sportType) {
      case SportType.football:
        return goalsScored;
      case SportType.basketball:
        return basketsScored;
      case SportType.volleyball:
        return acesScored;
      case SportType.trackAndField:
        return trackPoints;
    }
  }

  String get statLabel {
    switch (sportType) {
      case SportType.football:
        return 'Goals';
      case SportType.basketball:
        return 'Baskets';
      case SportType.volleyball:
        return 'Aces';
      case SportType.trackAndField:
        return 'Points';
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'scholar_no': scholarNo,
      'student_name': studentName,
      'house_name': houseName.toLowerCase(),
      'sport_type': sportType.name,
      'goals_scored': goalsScored,
      'baskets_scored': basketsScored,
      'aces_scored': acesScored,
      'track_points': trackPoints,
      'mvp_awards_count': mvpAwardsCount,
      'matches_played': matchesPlayed,
    };
  }

  factory PlayerSportsStats.fromMap(Map<String, dynamic> map) {
    return PlayerSportsStats(
      scholarNo: (map['scholar_no'] ?? '').toString(),
      studentName: (map['student_name'] ?? 'Scholar').toString(),
      houseName: (map['house_name'] ?? 'ruby').toString().toLowerCase(),
      sportType: SportType.fromString((map['sport_type'] ?? 'football').toString()),
      goalsScored: (map['goals_scored'] as num?)?.toInt() ?? 0,
      basketsScored: (map['baskets_scored'] as num?)?.toInt() ?? 0,
      acesScored: (map['aces_scored'] as num?)?.toInt() ?? 0,
      trackPoints: (map['track_points'] as num?)?.toInt() ?? 0,
      mvpAwardsCount: (map['mvp_awards_count'] as num?)?.toInt() ?? 0,
      matchesPlayed: (map['matches_played'] as num?)?.toInt() ?? 0,
    );
  }

  String toJson() => jsonEncode(toMap());
  factory PlayerSportsStats.fromJson(String source) =>
      PlayerSportsStats.fromMap(jsonDecode(source) as Map<String, dynamic>);

  static List<PlayerSportsStats> sortTopPerformers(
    List<PlayerSportsStats> list,
    SportType sport,
  ) {
    final filtered = list.where((p) => p.sportType == sport).toList();
    filtered.sort((a, b) {
      final statDiff = b.primaryStat.compareTo(a.primaryStat);
      if (statDiff != 0) return statDiff;
      return b.mvpAwardsCount.compareTo(a.mvpAwardsCount);
    });
    return filtered;
  }
}
