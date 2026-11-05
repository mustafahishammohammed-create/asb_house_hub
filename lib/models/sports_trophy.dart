// lib/models/sports_trophy.dart
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'sports_tournament.dart';

/// Available trophy and recognition tiers.
enum TrophyTier {
  goldCup,
  silverShield,
  bronzePlaque,
  fairPlayShield;

  String get title {
    switch (this) {
      case TrophyTier.goldCup:
        return 'Championship Gold Cup';
      case TrophyTier.silverShield:
        return 'Runners-Up Silver Shield';
      case TrophyTier.bronzePlaque:
        return 'Third Place Bronze Plaque';
      case TrophyTier.fairPlayShield:
        return 'Fair Play & Sportsmanship Shield';
    }
  }

  String get emoji {
    switch (this) {
      case TrophyTier.goldCup:
        return '🏆';
      case TrophyTier.silverShield:
        return '🥈';
      case TrophyTier.bronzePlaque:
        return '🥉';
      case TrophyTier.fairPlayShield:
        return '🎖️';
    }
  }

  int get defaultPoints {
    switch (this) {
      case TrophyTier.goldCup:
        return 100;
      case TrophyTier.silverShield:
        return 50;
      case TrophyTier.bronzePlaque:
        return 25;
      case TrophyTier.fairPlayShield:
        return 20;
    }
  }

  static TrophyTier fromString(String val) {
    switch (val.toLowerCase().trim()) {
      case 'goldcup':
      case 'gold_cup':
        return TrophyTier.goldCup;
      case 'silvershield':
      case 'silver_shield':
        return TrophyTier.silverShield;
      case 'bronzeplaque':
      case 'bronze_plaque':
        return TrophyTier.bronzePlaque;
      case 'fairplayshield':
      case 'fair_play_shield':
      default:
        return TrophyTier.goldCup;
    }
  }
}

/// Official record of a crowned sports tournament championship.
class SportsTrophyRecord {
  final String trophyId;
  final String tournamentTitle;
  final SportType sportType;
  final String winningHouse; // 'ruby', 'sapphire', 'emerald', 'topaz'
  final String runnerUpHouse;
  final int pointsAwarded;
  final int runnerUpPoints;
  final String? mvpScholarNo;
  final String? mvpName;
  final DateTime awardedAt;
  final String commissionerName;
  final TrophyTier trophyTier;

  SportsTrophyRecord({
    required this.trophyId,
    required this.tournamentTitle,
    required this.sportType,
    required this.winningHouse,
    required this.runnerUpHouse,
    this.pointsAwarded = 100,
    this.runnerUpPoints = 50,
    this.mvpScholarNo,
    this.mvpName,
    required this.awardedAt,
    this.commissionerName = 'Principal Office & Sports Department',
    this.trophyTier = TrophyTier.goldCup,
  });

  String get proclamationHeadline =>
      '${winningHouse.toUpperCase()} HOUSE CROWNED ${tournamentTitle.toUpperCase()} CHAMPIONS';

  Map<String, dynamic> toMap() {
    return {
      'trophy_id': trophyId,
      'tournament_title': tournamentTitle,
      'sport_type': sportType.name,
      'winning_house': winningHouse.toLowerCase(),
      'runner_up_house': runnerUpHouse.toLowerCase(),
      'points_awarded': pointsAwarded,
      'runner_up_points': runnerUpPoints,
      'mvp_scholar_no': mvpScholarNo,
      'mvp_name': mvpName,
      'awarded_at': awardedAt.toIso8601String(),
      'commissioner_name': commissionerName,
      'trophy_tier': trophyTier.name,
    };
  }

  factory SportsTrophyRecord.fromMap(Map<String, dynamic> map) {
    DateTime parseDate(dynamic v) {
      if (v is Timestamp) return v.toDate();
      if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
      return DateTime.now();
    }

    return SportsTrophyRecord(
      trophyId: (map['trophy_id'] ?? '').toString(),
      tournamentTitle: (map['tournament_title'] ?? 'Inter-House Championship').toString(),
      sportType: SportType.fromString((map['sport_type'] ?? 'football').toString()),
      winningHouse: (map['winning_house'] ?? 'ruby').toString().toLowerCase(),
      runnerUpHouse: (map['runner_up_house'] ?? 'sapphire').toString().toLowerCase(),
      pointsAwarded: (map['points_awarded'] as num?)?.toInt() ?? 100,
      runnerUpPoints: (map['runner_up_points'] as num?)?.toInt() ?? 50,
      mvpScholarNo: map['mvp_scholar_no']?.toString(),
      mvpName: map['mvp_name']?.toString(),
      awardedAt: parseDate(map['awarded_at']),
      commissionerName: (map['commissioner_name'] ?? 'Principal Office').toString(),
      trophyTier: TrophyTier.fromString((map['trophy_tier'] ?? 'goldCup').toString()),
    );
  }

  String toJson() => jsonEncode(toMap());
  factory SportsTrophyRecord.fromJson(String source) =>
      SportsTrophyRecord.fromMap(jsonDecode(source) as Map<String, dynamic>);
}
