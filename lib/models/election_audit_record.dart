// lib/models/election_audit_record.dart
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';

class ElectionAuditRecord {
  final String ballotId;
  final String ballotTitle;
  final int totalEligibleVoters;
  final int totalVotesCast;
  final Map<String, int> houseTurnoutBreakdown; // 'ruby': 120, 'sapphire': 110, etc.
  final Map<String, int> gradeTurnoutBreakdown; // 'Grade 10': 95, 'Grade 11': 105, etc.
  final String? winningCandidateScholarNo;
  final String? winningCandidateName;
  final String? winningCandidateHouse;
  final bool isCertified;
  final String? certifiedBy;
  final DateTime? certifiedAt;
  final bool integrityCheckPassed;

  ElectionAuditRecord({
    required this.ballotId,
    required this.ballotTitle,
    required this.totalEligibleVoters,
    required this.totalVotesCast,
    this.houseTurnoutBreakdown = const {},
    this.gradeTurnoutBreakdown = const {},
    this.winningCandidateScholarNo,
    this.winningCandidateName,
    this.winningCandidateHouse,
    this.isCertified = false,
    this.certifiedBy,
    this.certifiedAt,
    this.integrityCheckPassed = true,
  });

  double get turnoutPercentage {
    if (totalEligibleVoters <= 0) return 0.0;
    return ((totalVotesCast * 100.0) / totalEligibleVoters).clamp(0.0, 100.0);
  }

  bool get hasMetQuorum => turnoutPercentage >= 50.0;

  Map<String, dynamic> toMap() {
    return {
      'ballot_id': ballotId,
      'ballot_title': ballotTitle,
      'total_eligible_voters': totalEligibleVoters,
      'total_votes_cast': totalVotesCast,
      'house_turnout_breakdown': houseTurnoutBreakdown,
      'grade_turnout_breakdown': gradeTurnoutBreakdown,
      'winning_candidate_scholar_no': winningCandidateScholarNo,
      'winning_candidate_name': winningCandidateName,
      'winning_candidate_house': winningCandidateHouse,
      'is_certified': isCertified,
      'certified_by': certifiedBy,
      'certified_at': certifiedAt?.toIso8601String(),
      'integrity_check_passed': integrityCheckPassed,
    };
  }

  factory ElectionAuditRecord.fromMap(Map<String, dynamic> map) {
    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      if (v is Timestamp) return v.toDate();
      if (v is String) return DateTime.tryParse(v);
      return null;
    }

    int safeInt(dynamic v) {
      if (v == null) return 0;
      if (v is num) return v.toInt();
      return int.tryParse(v.toString()) ?? 0;
    }

    Map<String, int> parseMap(dynamic raw) {
      if (raw is Map) {
        return raw.map((k, v) => MapEntry(k.toString().toLowerCase(), safeInt(v)));
      }
      return {};
    }

    return ElectionAuditRecord(
      ballotId: (map['ballot_id'] ?? '').toString(),
      ballotTitle: (map['ballot_title'] ?? 'Election Audit').toString(),
      totalEligibleVoters: safeInt(map['total_eligible_voters']),
      totalVotesCast: safeInt(map['total_votes_cast']),
      houseTurnoutBreakdown: parseMap(map['house_turnout_breakdown']),
      gradeTurnoutBreakdown: parseMap(map['grade_turnout_breakdown']),
      winningCandidateScholarNo: map['winning_candidate_scholar_no']?.toString(),
      winningCandidateName: map['winning_candidate_name']?.toString(),
      winningCandidateHouse: map['winning_candidate_house']?.toString(),
      isCertified: map['is_certified'] == true,
      certifiedBy: map['certified_by']?.toString(),
      certifiedAt: parseDate(map['certified_at']),
      integrityCheckPassed: map['integrity_check_passed'] != false,
    );
  }

  String toJson() => jsonEncode(toMap());
  factory ElectionAuditRecord.fromJson(String source) =>
      ElectionAuditRecord.fromMap(jsonDecode(source) as Map<String, dynamic>);
}
