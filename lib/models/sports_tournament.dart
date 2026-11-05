// lib/models/sports_tournament.dart
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Supported campus inter-house sports.
enum SportType {
  football,
  basketball,
  volleyball,
  trackAndField;

  String get displayName {
    switch (this) {
      case SportType.football:
        return 'Football';
      case SportType.basketball:
        return 'Basketball';
      case SportType.volleyball:
        return 'Volleyball';
      case SportType.trackAndField:
        return 'Track & Field';
    }
  }

  String get emoji {
    switch (this) {
      case SportType.football:
        return '⚽';
      case SportType.basketball:
        return '🏀';
      case SportType.volleyball:
        return '🏐';
      case SportType.trackAndField:
        return '🏃';
    }
  }

  static SportType fromString(String val) {
    switch (val.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '')) {
      case 'football':
      case 'soccer':
        return SportType.football;
      case 'basketball':
        return SportType.basketball;
      case 'volleyball':
        return SportType.volleyball;
      case 'trackandfield':
      case 'athletics':
      case 'track':
        return SportType.trackAndField;
      default:
        return SportType.football;
    }
  }
}

/// Match lifecycle status.
enum MatchStatus {
  upcoming,
  live,
  completed,
  postponed;

  String get displayName {
    switch (this) {
      case MatchStatus.upcoming:
        return 'Upcoming';
      case MatchStatus.live:
        return 'LIVE 🔴';
      case MatchStatus.completed:
        return 'Final';
      case MatchStatus.postponed:
        return 'Postponed';
    }
  }

  static MatchStatus fromString(String val) {
    switch (val.toLowerCase().trim()) {
      case 'live':
        return MatchStatus.live;
      case 'completed':
      case 'final':
        return MatchStatus.completed;
      case 'postponed':
        return MatchStatus.postponed;
      case 'upcoming':
      default:
        return MatchStatus.upcoming;
    }
  }
}

/// Represents an individual sports match fixture between two houses.
class SportsMatchFixture {
  final String fixtureId;
  final String tournamentTitle;
  final SportType sportType;
  final String houseA; // 'ruby', 'sapphire', 'emerald', 'topaz'
  final String houseB;
  final int scoreA;
  final int scoreB;
  final String venue;
  final DateTime scheduledAt;
  final MatchStatus status;
  final String? mvpScholarNo;
  final String? mvpName;
  final bool isCertified;
  final String? certifiedBy;
  final String? refereeScholarNo;
  final DateTime? certifiedAt;
  final String? certificationToken;
  final int? fairPlayRating;
  final String? refereeNotes;

  SportsMatchFixture({
    required this.fixtureId,
    required this.tournamentTitle,
    required this.sportType,
    required this.houseA,
    required this.houseB,
    this.scoreA = 0,
    this.scoreB = 0,
    required this.venue,
    required this.scheduledAt,
    this.status = MatchStatus.upcoming,
    this.mvpScholarNo,
    this.mvpName,
    this.isCertified = false,
    this.certifiedBy,
    this.refereeScholarNo,
    this.certifiedAt,
    this.certificationToken,
    this.fairPlayRating,
    this.refereeNotes,
  });

  bool get isLive => status == MatchStatus.live;
  bool get isCompleted => status == MatchStatus.completed;

  String get formattedScore => '$scoreA - $scoreB';

  String? get winnerHouse {
    if (!isCompleted || scoreA == scoreB) return null;
    return scoreA > scoreB ? houseA.toLowerCase() : houseB.toLowerCase();
  }

  Map<String, dynamic> toMap() {
    return {
      'fixture_id': fixtureId,
      'tournament_title': tournamentTitle,
      'sport_type': sportType.name,
      'house_a': houseA.toLowerCase(),
      'house_b': houseB.toLowerCase(),
      'score_a': scoreA,
      'score_b': scoreB,
      'venue': venue,
      'scheduled_at': scheduledAt.toIso8601String(),
      'status': status.name,
      'mvp_scholar_no': mvpScholarNo,
      'mvp_name': mvpName,
      'is_certified': isCertified,
      'certified_by': certifiedBy,
      'referee_scholar_no': refereeScholarNo,
      'certified_at': certifiedAt?.toIso8601String(),
      'certification_token': certificationToken,
      'fair_play_rating': fairPlayRating,
      'referee_notes': refereeNotes,
    };
  }

  factory SportsMatchFixture.fromMap(Map<String, dynamic> map) {
    DateTime parseDate(dynamic v) {
      if (v is Timestamp) return v.toDate();
      if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
      return DateTime.now();
    }

    return SportsMatchFixture(
      fixtureId: (map['fixture_id'] ?? '').toString(),
      tournamentTitle: (map['tournament_title'] ?? 'Inter-House League').toString(),
      sportType: SportType.fromString((map['sport_type'] ?? 'football').toString()),
      houseA: (map['house_a'] ?? 'ruby').toString().toLowerCase(),
      houseB: (map['house_b'] ?? 'sapphire').toString().toLowerCase(),
      scoreA: (map['score_a'] as num?)?.toInt() ?? 0,
      scoreB: (map['score_b'] as num?)?.toInt() ?? 0,
      venue: (map['venue'] ?? 'ASB Main Sports Complex').toString(),
      scheduledAt: parseDate(map['scheduled_at']),
      status: MatchStatus.fromString((map['status'] ?? 'upcoming').toString()),
      mvpScholarNo: map['mvp_scholar_no']?.toString(),
      mvpName: map['mvp_name']?.toString(),
      isCertified: map['is_certified'] == true,
      certifiedBy: map['certified_by']?.toString(),
      refereeScholarNo: map['referee_scholar_no']?.toString(),
      certifiedAt: map['certified_at'] != null ? parseDate(map['certified_at']) : null,
      certificationToken: map['certification_token']?.toString(),
      fairPlayRating: (map['fair_play_rating'] as num?)?.toInt(),
      refereeNotes: map['referee_notes']?.toString(),
    );
  }

  String toJson() => jsonEncode(toMap());
  factory SportsMatchFixture.fromJson(String source) =>
      SportsMatchFixture.fromMap(jsonDecode(source) as Map<String, dynamic>);
}

/// Standings record for each house within a sport league.
class HouseLeagueStanding {
  final String houseName;
  int matchesPlayed;
  int won;
  int drawn;
  int lost;
  int goalsFor;
  int goalsAgainst;

  HouseLeagueStanding({
    required this.houseName,
    this.matchesPlayed = 0,
    this.won = 0,
    this.drawn = 0,
    this.lost = 0,
    this.goalsFor = 0,
    this.goalsAgainst = 0,
  });

  int get goalDifference => goalsFor - goalsAgainst;

  /// 3 Points for Win, 1 Point for Draw, 0 for Loss.
  int get points => (won * 3) + (drawn * 1);

  Map<String, dynamic> toMap() => {
        'house_name': houseName,
        'matches_played': matchesPlayed,
        'won': won,
        'drawn': drawn,
        'lost': lost,
        'goals_for': goalsFor,
        'goals_against': goalsAgainst,
      };

  factory HouseLeagueStanding.fromMap(Map<String, dynamic> map) {
    return HouseLeagueStanding(
      houseName: (map['house_name'] ?? 'ruby').toString().toLowerCase(),
      matchesPlayed: (map['matches_played'] as num?)?.toInt() ?? 0,
      won: (map['won'] as num?)?.toInt() ?? 0,
      drawn: (map['drawn'] as num?)?.toInt() ?? 0,
      lost: (map['lost'] as num?)?.toInt() ?? 0,
      goalsFor: (map['goals_for'] as num?)?.toInt() ?? 0,
      goalsAgainst: (map['goals_against'] as num?)?.toInt() ?? 0,
    );
  }

  /// Calculates real-time standings from a roster of match fixtures.
  static List<HouseLeagueStanding> calculateStandings(
    List<SportsMatchFixture> fixtures,
  ) {
    final Map<String, HouseLeagueStanding> map = {
      'ruby': HouseLeagueStanding(houseName: 'ruby'),
      'sapphire': HouseLeagueStanding(houseName: 'sapphire'),
      'emerald': HouseLeagueStanding(houseName: 'emerald'),
      'topaz': HouseLeagueStanding(houseName: 'topaz'),
    };

    for (final f in fixtures) {
      if (!f.isCompleted) continue;
      final hA = map[f.houseA.toLowerCase()];
      final hB = map[f.houseB.toLowerCase()];
      if (hA == null || hB == null) continue;

      hA.matchesPlayed++;
      hB.matchesPlayed++;
      hA.goalsFor += f.scoreA;
      hA.goalsAgainst += f.scoreB;
      hB.goalsFor += f.scoreB;
      hB.goalsAgainst += f.scoreA;

      if (f.scoreA > f.scoreB) {
        hA.won++;
        hB.lost++;
      } else if (f.scoreB > f.scoreA) {
        hB.won++;
        hA.lost++;
      } else {
        hA.drawn++;
        hB.drawn++;
      }
    }

    final list = map.values.toList();
    list.sort((a, b) {
      final pDiff = b.points.compareTo(a.points);
      if (pDiff != 0) return pDiff;
      final gdDiff = b.goalDifference.compareTo(a.goalDifference);
      if (gdDiff != 0) return gdDiff;
      return b.goalsFor.compareTo(a.goalsFor);
    });
    return list;
  }
}
