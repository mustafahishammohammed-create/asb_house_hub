// lib/models/election_gazette.dart
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';

class CertifiedElectionResult {
  final String ballotId;
  final String ballotTitle;
  final String runningPosition;
  final String winnerScholarNo;
  final String winnerName;
  final String winnerHouse;
  final String winnerAvatarUrl;
  final int totalVotesReceived;
  final int victoryMarginVotes;
  final int housePointsAwarded;
  final String commissionerName;
  final String commissionerRole;
  final DateTime certifiedAt;
  final String proclamationText;

  CertifiedElectionResult({
    required this.ballotId,
    required this.ballotTitle,
    required this.runningPosition,
    required this.winnerScholarNo,
    required this.winnerName,
    required this.winnerHouse,
    this.winnerAvatarUrl = '',
    required this.totalVotesReceived,
    required this.victoryMarginVotes,
    required this.housePointsAwarded,
    required this.commissionerName,
    this.commissionerRole = 'Chief Electoral Commissioner',
    required this.certifiedAt,
    required this.proclamationText,
  });

  Map<String, dynamic> toMap() {
    return {
      'ballot_id': ballotId,
      'ballot_title': ballotTitle,
      'running_position': runningPosition,
      'winner_scholar_no': winnerScholarNo,
      'winner_name': winnerName,
      'winner_house': winnerHouse,
      'winner_avatar_url': winnerAvatarUrl,
      'total_votes_received': totalVotesReceived,
      'victory_margin_votes': victoryMarginVotes,
      'house_points_awarded': housePointsAwarded,
      'commissioner_name': commissionerName,
      'commissioner_role': commissionerRole,
      'certified_at': certifiedAt.toIso8601String(),
      'proclamation_text': proclamationText,
    };
  }

  factory CertifiedElectionResult.fromMap(Map<String, dynamic> map) {
    DateTime parseDate(dynamic v) {
      if (v is Timestamp) return v.toDate();
      if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
      return DateTime.now();
    }

    return CertifiedElectionResult(
      ballotId: (map['ballot_id'] ?? '').toString(),
      ballotTitle: (map['ballot_title'] ?? 'Election Proclamation').toString(),
      runningPosition: (map['running_position'] ?? 'Council Appointment').toString(),
      winnerScholarNo: (map['winner_scholar_no'] ?? '').toString(),
      winnerName: (map['winner_name'] ?? 'Candidate').toString(),
      winnerHouse: (map['winner_house'] ?? '').toString().toLowerCase(),
      winnerAvatarUrl: (map['winner_avatar_url'] ?? '').toString(),
      totalVotesReceived: (map['total_votes_received'] as num?)?.toInt() ?? 0,
      victoryMarginVotes: (map['victory_margin_votes'] as num?)?.toInt() ?? 0,
      housePointsAwarded: (map['house_points_awarded'] as num?)?.toInt() ?? 0,
      commissionerName: (map['commissioner_name'] ?? 'Principal Office').toString(),
      commissionerRole: (map['commissioner_role'] ?? 'Chief Electoral Commissioner').toString(),
      certifiedAt: parseDate(map['certified_at']),
      proclamationText: (map['proclamation_text'] ?? '').toString(),
    );
  }

  String toJson() => jsonEncode(toMap());
  factory CertifiedElectionResult.fromJson(String source) =>
      CertifiedElectionResult.fromMap(jsonDecode(source) as Map<String, dynamic>);
}
