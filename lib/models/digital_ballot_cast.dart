import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';

class BallotCastReceipt {
  final String receiptId;
  final String ballotId;
  final String ballotTitle;
  final String candidateScholarNo;
  final String candidateName;
  final String candidateHouse;
  final String runningPosition;
  final String anonymizedVoterHash;
  final String signatureProofToken;
  final DateTime timestamp;

  BallotCastReceipt({
    required this.receiptId,
    required this.ballotId,
    required this.ballotTitle,
    required this.candidateScholarNo,
    required this.candidateName,
    required this.candidateHouse,
    required this.runningPosition,
    required this.anonymizedVoterHash,
    required this.signatureProofToken,
    required this.timestamp,
  });

  String get formattedReceiptNumber =>
      'ASB-VOTE-${signatureProofToken.length >= 8 ? signatureProofToken.substring(0, 8).toUpperCase() : signatureProofToken.toUpperCase()}';

  Map<String, dynamic> toMap() {
    return {
      'receipt_id': receiptId,
      'ballot_id': ballotId,
      'ballot_title': ballotTitle,
      'candidate_scholar_no': candidateScholarNo,
      'candidate_name': candidateName,
      'candidate_house': candidateHouse,
      'running_position': runningPosition,
      'anonymized_voter_hash': anonymizedVoterHash,
      'signature_proof_token': signatureProofToken,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory BallotCastReceipt.fromMap(Map<String, dynamic> map) {
    DateTime parseDate(dynamic v) {
      if (v is Timestamp) return v.toDate();
      if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
      return DateTime.now();
    }

    return BallotCastReceipt(
      receiptId: (map['receipt_id'] ?? '').toString(),
      ballotId: (map['ballot_id'] ?? '').toString(),
      ballotTitle: (map['ballot_title'] ?? 'Election Ballot').toString(),
      candidateScholarNo: (map['candidate_scholar_no'] ?? '').toString(),
      candidateName: (map['candidate_name'] ?? 'Candidate').toString(),
      candidateHouse: (map['candidate_house'] ?? '').toString().toLowerCase(),
      runningPosition: (map['running_position'] ?? 'Council').toString(),
      anonymizedVoterHash: (map['anonymized_voter_hash'] ?? '').toString(),
      signatureProofToken: (map['signature_proof_token'] ?? '').toString(),
      timestamp: parseDate(map['timestamp']),
    );
  }

  String toJson() => jsonEncode(toMap());
  factory BallotCastReceipt.fromJson(String source) =>
      BallotCastReceipt.fromMap(jsonDecode(source) as Map<String, dynamic>);
}

class BallotLiveTally {
  final String ballotId;
  final int totalVotes;
  final Map<String, int> candidateVotes;
  final bool isCertified;
  final String? certifiedBy;
  final DateTime? certifiedAt;

  BallotLiveTally({
    required this.ballotId,
    required this.totalVotes,
    required this.candidateVotes,
    this.isCertified = false,
    this.certifiedBy,
    this.certifiedAt,
  });

  double getCandidatePercentage(String candidateScholarNo) {
    if (totalVotes <= 0) return 0.0;
    final votes = candidateVotes[candidateScholarNo] ?? 0;
    return (votes / totalVotes) * 100.0;
  }
}
