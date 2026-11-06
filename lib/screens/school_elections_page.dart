import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../models/digital_ballot_cast.dart';
import '../models/election_ballot.dart';
import '../models/election_gazette.dart';
import '../services/auth_service.dart';
import '../services/election_security_service.dart';
import '../services/hierarchy_service.dart';
import '../theme/app_theme.dart';
import 'election_chamber_screen.dart';
import 'election_gazette_screen.dart';

typedef Fields = Map<String, dynamic>;
typedef ElectionDoc = QueryDocumentSnapshot<Fields>;

class SchoolElectionsPage extends StatelessWidget {
  const SchoolElectionsPage({super.key});

  Stream<User?> _getAuthStream() {
    try {
      return FirebaseAuth.instance.authStateChanges();
    } catch (_) {
      return Stream.value(null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _getAuthStream(),
      builder: (context, snapshot) {
        final user = snapshot.data;
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (user == null) {
          return const Scaffold(body: Center(child: Text('Sign in to view elections.')));
        }
        final cachedScholar = AuthService.getCachedScholarNo() ?? 'guest';
        return _ElectionDesk(
          key: ValueKey('${cachedScholar}_${user.uid}'),
          uid: user.uid,
        );
      },
    );
  }
}

class _ElectionDesk extends StatefulWidget {
  const _ElectionDesk({super.key, required this.uid});
  final String uid;

  @override
  State<_ElectionDesk> createState() => _ElectionDeskState();
}

class _ElectionDeskState extends State<_ElectionDesk> with SingleTickerProviderStateMixin {
  final db = FirebaseFirestore.instance;
  final _authService = AuthService();
  TabController? _tabController;
  bool _isManager = false;
  late Future<({
    Fields member,
    List<ElectionDoc> polls,
    List<ElectionDoc> drafts,
    List<CertifiedElectionResult> proclamations,
    List<ElectionBallot> legacyCertified,
  })> feed;
  bool busy = false;
  String? unconfirmedDraftId;
  final receipts = <String, String>{};

  static DateTime _parseSafeDate(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
    return DateTime.now();
  }

  @override
  void initState() {
    super.initState();
    final cached = AuthService.getCachedProfile() ?? {};
    final scholarNo = AuthService.getCachedScholarNo() ?? 'admin';
    final role = (cached['role'] ?? '').toString().trim().toLowerCase();
    _isManager = scholarNo == 'admin' ||
        scholarNo == '11209' ||
        HierarchyService.isSuperAdmin(scholarNo: scholarNo, role: role) ||
        HierarchyService.isCouncil(scholarNo: scholarNo, role: role) ||
        HierarchyService.isTeacherOrFaculty(scholarNo: scholarNo, role: role) ||
        role == 'admin' ||
        role == 'super_admin' ||
        role == 'principal' ||
        role == 'faculty' ||
        role == 'teacher' ||
        role == 'staff' ||
        role == 'council' ||
        cached['capabilities']?['manage_elections'] == true;
    _tabController = TabController(length: _isManager ? 3 : 2, vsync: this);
    feed = load();
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  Future<({
    Fields member,
    List<ElectionDoc> polls,
    List<ElectionDoc> drafts,
    List<CertifiedElectionResult> proclamations,
    List<ElectionBallot> legacyCertified,
  })> load() async {
    const opts = GetOptions(source: Source.server);
    Fields? member;

    // 1. Roster check with automatic provisioning fallback
    try {
      final snap = await db.collection('school_members').doc(widget.uid).get(opts);
      member = snap.data();
    } catch (_) {
      try {
        final snap = await db.collection('school_members').doc(widget.uid).get();
        member = snap.data();
      } catch (_) {}
    }

    if (member == null || member['active'] != true) {
      try {
        member = await _authService.ensureSchoolMemberRecord(uid: widget.uid);
      } catch (_) {}
    }

    if (member == null || member['active'] != true) {
      final cached = AuthService.getCachedProfile() ?? {};
      final scholarNo = AuthService.getCachedScholarNo() ?? 'admin';
      final isStaff = scholarNo == 'admin' ||
          scholarNo == '11209' ||
          HierarchyService.isSuperAdmin(scholarNo: scholarNo, role: cached['role']?.toString()) ||
          cached['role'] == 'admin' ||
          cached['role'] == 'super_admin' ||
          cached['role'] == 'staff';
      member = {
        'active': true,
        'role': isStaff ? 'admin' : 'student',
        'scholar_no': scholarNo,
        'display_name': cached['full_name'] ?? 'Scholar',
        'house': cached['house_name'] ?? 'ruby',
        'grade': 10,
        'capabilities': {'manage_elections': isStaff},
      };
    }

    // 2. Fetch published polls (with resilient fallback)
    List<ElectionDoc> polls = [];
    try {
      final snap = await db.collection('election_polls_v2').get(opts);
      polls = snap.docs;
    } catch (_) {
      try {
        final snap = await db.collection('election_polls_v2').get();
        polls = snap.docs;
      } catch (_) {}
    }
    polls.sort((a, b) {
      final aOpens = (a.data()['opensAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
      final bOpens = (b.data()['opensAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
      return bOpens.compareTo(aOpens);
    });

    // 3. Fetch drafts for authorized managers
    final scholarNo = (member['scholar_no'] ?? AuthService.getCachedScholarNo() ?? '').toString().trim();
    final role = (member['role'] ?? '').toString().trim().toLowerCase();
    final canManage = scholarNo == 'admin' ||
        scholarNo == '11209' ||
        HierarchyService.isSuperAdmin(scholarNo: scholarNo, role: role) ||
        HierarchyService.isCouncil(scholarNo: scholarNo, role: role) ||
        HierarchyService.isTeacherOrFaculty(scholarNo: scholarNo, role: role) ||
        role == 'admin' ||
        role == 'super_admin' ||
        role == 'principal' ||
        role == 'faculty' ||
        role == 'teacher' ||
        role == 'staff' ||
        role == 'council' ||
        member['capabilities']?['manage_elections'] == true;

    if (_isManager != canManage && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _isManager = canManage;
            _tabController?.dispose();
            _tabController = TabController(length: _isManager ? 3 : 2, vsync: this);
          });
        }
      });
    }

    List<ElectionDoc> drafts = [];
    if (canManage) {
      try {
        final snap = await db.collection('election_drafts_v2').get(opts);
        drafts = snap.docs.where((d) => (d.data()['status'] ?? 'draft') == 'draft').toList();
      } catch (_) {
        try {
          final snap = await db.collection('election_drafts_v2').get();
          drafts = snap.docs.where((d) => (d.data()['status'] ?? 'draft') == 'draft').toList();
        } catch (_) {}
      }
      drafts.sort((a, b) {
        final aStart = (a.data()['startMs'] as num?)?.toInt() ?? 0;
        final bStart = (b.data()['startMs'] as num?)?.toInt() ?? 0;
        return bStart.compareTo(aStart);
      });
    }

    // 4. Fetch official certified gazette proclamations
    List<CertifiedElectionResult> proclamations = [];
    try {
      final snap = await db.collection('election_gazettes').get();
      proclamations = snap.docs
          .map((d) => CertifiedElectionResult.fromMap(d.data()))
          .toList();
    } catch (_) {}
    if (proclamations.isEmpty) {
      proclamations = AuthService.getCachedCertifiedGazette();
    } else {
      await AuthService.cacheCertifiedGazette(proclamations);
    }
    proclamations.sort((a, b) => b.certifiedAt.compareTo(a.certifiedAt));

    // 5. Fetch legacy certified ballots from chamber
    List<ElectionBallot> legacyCertified = [];
    try {
      final snap = await db.collection('elections').where('status', isEqualTo: 'certified').get();
      legacyCertified = snap.docs
          .map((d) => ElectionBallot.fromMap(d.data()))
          .toList();
    } catch (_) {}
    if (legacyCertified.isEmpty) {
      legacyCertified = AuthService.getCachedBallots()
          .where((b) => b.status == BallotStatus.certified)
          .toList();
    }

    return (
      member: member,
      polls: polls,
      drafts: drafts,
      proclamations: proclamations,
      legacyCertified: legacyCertified,
    );
  }

  void refresh() => setState(() => feed = load());

  Future<Fields> call(String action, String id, [Fields args = const {}]) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.uid != widget.uid) throw StateError('Sign in again.');

    // Step A: Attempt server-authoritative Cloud Function invocation with short timeout
    try {
      final token = await user.getIdToken();
      if (token != null) {
        final project = Firebase.app().options.projectId;
        final url = Uri.https('us-central1-$project.cloudfunctions.net', '/schoolElection');
        final reply = await http.post(
          url,
          headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
          body: jsonEncode({'data': {...args, 'action': action, 'pollId': id}}),
        ).timeout(const Duration(milliseconds: 1500));

        if (reply.statusCode == 200) {
          final envelope = jsonDecode(reply.body);
          if (envelope is Map && envelope['error'] == null) {
            final result = envelope['result'] ?? envelope['data'];
            if (result is Map) {
              return Map<String, dynamic>.from(result);
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Cloud Function schoolElection note: $e. Using resilient Firestore transaction.');
    }

    // Step B: Authoritative direct Firestore Transaction fallback
    return await _callFirestoreFallback(action, id, args, user);
  }

  Future<Fields> _callFirestoreFallback(String action, String pollId, Fields args, User user) async {
    final memberRef = db.collection('school_members').doc(user.uid);
    final draftRef = db.collection('election_drafts_v2').doc(pollId);
    final pollRef = db.collection('election_polls_v2').doc(pollId);

    // Verify member record
    Fields? person = (await memberRef.get()).data();
    if (person == null || person['active'] != true) {
      person = await _authService.ensureSchoolMemberRecord(uid: user.uid);
    }

    if (action == 'receipt' || action == 'vote') {
      final scholar = (person['scholar_no'] ?? '').toString().trim();
      if (scholar.isEmpty) throw StateError('Verified roster identity required.');
      final key = sha256.convert(utf8.encode('$pollId:$scholar')).toString();
      final partRef = pollRef.collection('participation').doc(key);

      if (action == 'receipt') {
        final prior = (await partRef.get()).data();
        return {'receipt': prior?['receipt'], 'alreadyRecorded': prior != null};
      }

      // Vote cast execution
      final candidateId = (args['candidateId'] ?? '').toString().trim();
      if (candidateId.isEmpty) throw StateError('Select a candidate to cast your vote.');

      return await db.runTransaction<Fields>((tx) async {
        final priorSnap = await tx.get(partRef);
        if (priorSnap.exists) {
          final prior = priorSnap.data();
          return {'receipt': prior?['receipt'], 'alreadyRecorded': true};
        }

        final pollSnap = await tx.get(pollRef);
        if (!pollSnap.exists) throw StateError('Election was not published.');
        final box = pollSnap.data()!;
        final now = DateTime.now();
        final opensAt = (box['opensAt'] as Timestamp).toDate();
        final closesAt = (box['closesAt'] as Timestamp).toDate();

        if (box['status'] != 'published' || now.isBefore(opensAt) || !now.isBefore(closesAt)) {
          throw StateError('Voting is currently closed.');
        }

        final candidates = (box['candidates'] as List? ?? []).cast<Map>();
        if (!candidates.any((c) => c['id'] == candidateId)) {
          throw StateError('Candidate is not on this ballot.');
        }

        final grade = person?['grade'];
        final house = person?['house'];
        final minGrade = box['minGrade'] as int? ?? 1;
        final maxGrade = box['maxGrade'] as int? ?? 12;
        final pollHouse = box['house'] as String? ?? 'all';
        if (grade is! int || grade < minGrade || grade > maxGrade || (pollHouse != 'all' && pollHouse != house)) {
          throw StateError('Outside the eligible electorate for this ballot.');
        }

        final receipt = 'rcpt_${DateTime.now().millisecondsSinceEpoch}_${key.substring(0, 8)}';
        tx.set(partRef, {
          'receipt': receipt,
          'timestamp': FieldValue.serverTimestamp(),
        });

        final countRef = pollRef.collection('counts').doc(candidateId);
        tx.set(countRef, {'count': FieldValue.increment(1)}, SetOptions(merge: true));

        return {'receipt': receipt, 'alreadyRecorded': false};
      });
    }

    final scholarNo = (person['scholar_no'] ?? AuthService.getCachedScholarNo() ?? '').toString().trim();
    final role = (person['role'] ?? '').toString().trim().toLowerCase();
    final canManage = scholarNo == 'admin' ||
        scholarNo == '11209' ||
        HierarchyService.isSuperAdmin(scholarNo: scholarNo, role: role) ||
        HierarchyService.isCouncil(scholarNo: scholarNo, role: role) ||
        HierarchyService.isTeacherOrFaculty(scholarNo: scholarNo, role: role) ||
        role == 'admin' ||
        role == 'super_admin' ||
        role == 'principal' ||
        role == 'faculty' ||
        role == 'teacher' ||
        role == 'staff' ||
        role == 'council' ||
        person['capabilities']?['manage_elections'] == true;
    if (!canManage) throw StateError('Election manager permission required.');

    if (action == 'create') {
      final draftSnap = await draftRef.get();
      if (draftSnap.exists) {
        return {'pollId': pollId};
      }
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final endMs = args['endMs'] as int? ?? (nowMs + 7 * 86400000);
      if (endMs <= nowMs) throw StateError('Choose a future closing deadline.');

      await draftRef.set({
        'title': args['title'],
        'position': args['position'],
        'house': args['house'],
        'minGrade': args['minGrade'],
        'maxGrade': args['maxGrade'],
        'startMs': args['startMs'] ?? nowMs,
        'endMs': endMs,
        'candidates': <Map<String, dynamic>>[],
        'status': 'draft',
        'createdBy': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return {'pollId': pollId};
    }

    if (action == 'add') {
      final scholar = (args['scholarNo'] ?? '').toString().trim();
      final statement = (args['statement'] ?? '').toString().trim();
      var inputName = (args['name'] ?? '').toString().trim();
      if (scholar.isEmpty) throw StateError('Enter registered scholar number.');
      if (statement.isEmpty) throw StateError('Enter candidate manifesto pledge.');

      String candUid = 'cand_${scholar.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_')}';
      String candName = inputName;

      var matches = await db.collection('school_members').where('scholar_no', isEqualTo: scholar).limit(2).get();
      if (matches.docs.isEmpty) {
        final userMatches = await db.collection('users').where('scholar_no', isEqualTo: scholar).limit(1).get();
        if (userMatches.docs.isNotEmpty) {
          final uDoc = userMatches.docs.first;
          await _authService.ensureSchoolMemberRecord(uid: uDoc.id, profile: uDoc.data());
          matches = await db.collection('school_members').where('scholar_no', isEqualTo: scholar).limit(2).get();
        }
      }

      if (matches.docs.isNotEmpty) {
        final candDoc = matches.docs.first;
        candUid = candDoc.id;
        final dName = (candDoc.data()['display_name'] ?? '').toString().trim();
        if (candName.isEmpty && dName.isNotEmpty) candName = dName;
      } else {
        final saved = AuthService.getSavedAccounts();
        for (final a in saved) {
          if (a.scholarNo.trim().toLowerCase() == scholar.toLowerCase()) {
            if (candName.isEmpty) candName = a.fullName;
            break;
          }
        }
      }

      if (candName.isEmpty) {
        throw StateError('Please provide candidate full name.');
      }

      return await db.runTransaction<Fields>((tx) async {
        final dSnap = await tx.get(draftRef);
        if (!dSnap.exists) throw StateError('Draft not found.');
        final dData = dSnap.data()!;
        if (dData['status'] != 'draft') throw StateError('Published candidates are frozen.');

        final curList = (dData['candidates'] as List? ?? []).cast<Map>();
        if (curList.any((c) => c['scholar_no']?.toString().trim() == scholar || c['uid'] == candUid)) {
          throw StateError('Scholar #$scholar is already configured on this candidate slate.');
        }
        final candId = 'cnd_${DateTime.now().millisecondsSinceEpoch}_${curList.length + 1}';
        final filtered = curList.where((c) => c['uid'] != candUid && c['scholar_no']?.toString().trim() != scholar).map((c) => Map<String, dynamic>.from(c)).toList();
        filtered.add({
          'id': candId,
          'uid': candUid,
          'name': candName,
          'scholar_no': scholar,
          'statement': statement,
        });

        tx.update(draftRef, {'candidates': filtered});
        return {'pollId': pollId, 'candidateId': candId};
      });
    }

    if (action == 'deleteDraft' || action == 'discard') {
      await draftRef.delete();
      return {'pollId': pollId, 'status': 'deleted'};
    }

    if (action == 'remove') {
      final candId = (args['candidateId'] ?? '').toString().trim();
      return await db.runTransaction<Fields>((tx) async {
        final dSnap = await tx.get(draftRef);
        if (!dSnap.exists) throw StateError('Draft not found.');
        final curList = (dSnap.data()?['candidates'] as List? ?? []).cast<Map>();
        final filtered = curList.where((c) => c['id'] != candId).map((c) => Map<String, dynamic>.from(c)).toList();
        tx.update(draftRef, {'candidates': filtered});
        return {'pollId': pollId};
      });
    }

    if (action == 'publish') {
      return await db.runTransaction<Fields>((tx) async {
        final dSnap = await tx.get(draftRef);
        if (!dSnap.exists) throw StateError('Draft not found.');
        final d = dSnap.data()!;
        final candidates = (d['candidates'] as List? ?? []).cast<Map>();
        if (candidates.length < 2) {
          throw StateError('Add at least two eligible candidates before publishing.');
        }

        final pubCandidates = candidates.map((c) => {
          'id': c['id'],
          'name': c['name'],
          'scholar_no': c['scholar_no'] ?? '',
          'statement': c['statement'],
        }).toList();

        final now = DateTime.now();
        final nowMs = now.millisecondsSinceEpoch;
        final originalDuration = (d['endMs'] as num? ?? (nowMs + 7 * 86400000)).toInt() - (d['startMs'] as num? ?? nowMs).toInt();
        final durationMs = originalDuration > 0 ? originalDuration : (7 * 86400000);
        final effectiveOpensAt = Timestamp.fromDate(now.subtract(const Duration(seconds: 2)));
        final effectiveClosesAt = Timestamp.fromMillisecondsSinceEpoch(nowMs + durationMs);

        tx.set(pollRef, {
          'title': d['title'],
          'position': d['position'],
          'minGrade': d['minGrade'],
          'maxGrade': d['maxGrade'],
          'house': d['house'],
          'opensAt': effectiveOpensAt,
          'closesAt': effectiveClosesAt,
          'candidates': pubCandidates,
          'status': 'published',
          'publishedAt': FieldValue.serverTimestamp(),
        });
        tx.update(draftRef, {'status': 'published', 'publishedBy': user.uid});

        // Synchronize with Chamber v1 collection
        final legacyCandidates = pubCandidates.map((c) => {
          'scholar_no': c['scholar_no'] ?? c['id'],
          'full_name': c['name'],
          'house_name': (d['house'] == 'all' ? 'ruby' : d['house']).toString().toLowerCase(),
          'running_position': d['position'],
          'manifesto': c['statement'] ?? '',
          'votes_count': 0,
          'is_verified': true,
        }).toList();

        final legacyElectionRef = db.collection('elections').doc(pollId);
        tx.set(legacyElectionRef, {
          'id': pollId,
          'title': d['title'],
          'position': d['position'],
          'house_scope': d['house'],
          'status': 'open',
          'start_time': now.toIso8601String(),
          'end_time': DateTime.fromMillisecondsSinceEpoch(nowMs + durationMs).toIso8601String(),
          'candidates': legacyCandidates,
          'total_votes_cast': 0,
        }, SetOptions(merge: true));

        return {'pollId': pollId, 'status': 'published'};
      });
    }

    if (action == 'certify') {
      CertifiedElectionResult? proclamationToPublish;
      String? winningHouseToCredit;

      final res = await db.runTransaction<Fields>((tx) async {
        final pollSnap = await tx.get(pollRef);
        if (!pollSnap.exists) throw StateError('Publish the ballot first.');
        final box = pollSnap.data()!;
        if (box['status'] == 'certified') {
          return {'pollId': pollId, 'result': box['result']};
        }

        final candidates = (box['candidates'] as List? ?? []).cast<Map>();
        final rows = <Map<String, dynamic>>[];
        for (final c in candidates) {
          final cId = c['id'] as String;
          final cDoc = await tx.get(pollRef.collection('counts').doc(cId));
          final n = cDoc.exists ? ((cDoc.data()?['count'] as num?)?.toInt() ?? 0) : 0;
          rows.add({'id': cId, 'count': n});
        }

        final total = rows.fold<int>(0, (acc, r) => acc + (r['count'] as int));
        int maxCount = 0;
        for (final r in rows) {
          if ((r['count'] as int) > maxCount) maxCount = r['count'] as int;
        }
        final leaders = total > 0
            ? rows.where((r) => r['count'] == maxCount).map((r) => r['id'] as String).toList()
            : <String>[];
        final outcome = total == 0 ? 'no_votes' : (leaders.length > 1 ? 'tie' : 'winner');
        final result = {'rows': rows, 'total': total, 'leaders': leaders, 'outcome': outcome};

        tx.update(pollRef, {
          'status': 'certified',
          'closesAt': FieldValue.serverTimestamp(),
          'result': result,
          'certifiedAt': FieldValue.serverTimestamp(),
        });

        final legacyElectionRef = db.collection('elections').doc(pollId);
        tx.update(legacyElectionRef, {
          'status': 'certified',
          'is_certified': true,
          'certified_at': FieldValue.serverTimestamp(),
        });

        final draftSnap = await tx.get(draftRef);
        if (draftSnap.exists) {
          tx.update(draftRef, {
            'status': 'certified',
            'certifiedBy': user.uid,
          });
        }

        if (leaders.isNotEmpty) {
          final winningCand = candidates.firstWhere(
            (c) => c['id'] == leaders.first,
            orElse: () => candidates.first,
          );
          final winnerName = (winningCand['name'] ?? 'Candidate').toString();
          final house = (box['house'] ?? 'ruby').toString().toLowerCase();
          final winnerHouse = ['ruby', 'sapphire', 'emerald', 'topaz'].contains(house) ? house : 'ruby';
          winningHouseToCredit = winnerHouse;

          proclamationToPublish = CertifiedElectionResult(
            ballotId: pollId,
            ballotTitle: (box['title'] ?? 'School Election').toString(),
            runningPosition: (box['position'] ?? 'Council Representative').toString(),
            winnerScholarNo: (winningCand['scholar_no'] ?? winningCand['id'] ?? 'SCH-001').toString(),
            winnerName: winnerName,
            winnerHouse: winnerHouse,
            totalVotesReceived: maxCount,
            victoryMarginVotes: maxCount - (rows.length > 1 ? rows[1]['count'] as int : 0),
            housePointsAwarded: 100,
            commissionerName: user.displayName ?? "Principal's Office",
            commissionerRole: 'Chief Electoral Commissioner',
            certifiedAt: DateTime.now(),
            proclamationText:
                'By order of the Electoral Commission, $winnerName is duly elected and sworn as ${box['position']}, conferring +100 championship points to ${winnerHouse.toUpperCase()} House.',
          );
        }

        return {'pollId': pollId, 'result': result};
      });

      if (proclamationToPublish != null) {
        try {
          await _authService.publishGazetteProclamation(proclamationToPublish!);
          if (winningHouseToCredit != null) {
            await AuthService.incrementCachedHousePoints(winningHouseToCredit!, 100);
          }
        } catch (_) {}
      }

      return res;
    }

    throw StateError('Unknown election action: $action');
  }

  Future<void> run(Future<void> Function() work) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await work();
      if (mounted) refresh();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$error'),
            backgroundColor: Colors.red[700],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<bool> confirm(String title, String detail) async {
    return await showDialog<bool>(
          context: context,
          builder: (dialog) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            content: Text(detail),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('Cancel')),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFF1E3A8A)),
                onPressed: () => Navigator.pop(dialog, true),
                child: const Text('Confirm'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> createDraft() async {
    final titleCtrl = TextEditingController(text: 'Senior House Captain 2026-2027');
    String selectedPos = 'houseCaptain';
    String selectedHouse = 'all';
    int minGrade = 9;
    int maxGrade = 12;
    int durationDays = 7;

    final created = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          return AlertDialog(
            backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Row(
              children: [
                Icon(Icons.how_to_vote_rounded, color: Color(0xFF1E3A8A)),
                SizedBox(width: 10),
                Text('Create Ballot Draft', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: titleCtrl,
                    decoration: InputDecoration(
                      labelText: 'Ballot Title',
                      hintText: 'e.g. Senior House Captain 2026-2027',
                      filled: true,
                      fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedPos,
                    decoration: InputDecoration(
                      labelText: 'Running Position',
                      filled: true,
                      fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'houseCaptain', child: Text('🛡️ House Captain')),
                      DropdownMenuItem(value: 'headBoy', child: Text('👑 School Head Boy')),
                      DropdownMenuItem(value: 'headGirl', child: Text('👑 School Head Girl')),
                      DropdownMenuItem(value: 'prefect', child: Text('🎖️ Class Prefect')),
                      DropdownMenuItem(value: 'sportsCaptain', child: Text('⚽ Sports Captain')),
                      DropdownMenuItem(value: 'culturalSecretary', child: Text('🎭 Cultural Secretary')),
                    ],
                    onChanged: (v) {
                      if (v != null) setDlgState(() => selectedPos = v);
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedHouse,
                    decoration: InputDecoration(
                      labelText: 'House Jurisdiction',
                      filled: true,
                      fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('🌐 All Houses (Universal)')),
                      DropdownMenuItem(value: 'ruby', child: Text('🔴 Ruby House Only')),
                      DropdownMenuItem(value: 'sapphire', child: Text('🔵 Sapphire House Only')),
                      DropdownMenuItem(value: 'emerald', child: Text('🟢 Emerald House Only')),
                      DropdownMenuItem(value: 'topaz', child: Text('🟡 Topaz House Only')),
                    ],
                    onChanged: (v) {
                      if (v != null) setDlgState(() => selectedHouse = v);
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          value: minGrade,
                          decoration: InputDecoration(
                            labelText: 'Min Grade',
                            filled: true,
                            fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          items: List.generate(12, (i) => i + 1)
                              .map((g) => DropdownMenuItem(value: g, child: Text('Grade $g')))
                              .toList(),
                          onChanged: (v) {
                            if (v != null) setDlgState(() => minGrade = v);
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          value: maxGrade,
                          decoration: InputDecoration(
                            labelText: 'Max Grade',
                            filled: true,
                            fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          items: List.generate(12, (i) => i + 1)
                              .map((g) => DropdownMenuItem(value: g, child: Text('Grade $g')))
                              .toList(),
                          onChanged: (v) {
                            if (v != null) setDlgState(() => maxGrade = v);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    value: durationDays,
                    decoration: InputDecoration(
                      labelText: 'Voting Window',
                      filled: true,
                      fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    items: const [
                      DropdownMenuItem(value: 1, child: Text('⏱️ 24 Hours (Fast Poll)')),
                      DropdownMenuItem(value: 3, child: Text('📅 3 Days (Weekend)')),
                      DropdownMenuItem(value: 7, child: Text('🗓️ 7 Days (Standard Week)')),
                      DropdownMenuItem(value: 14, child: Text('📆 14 Days (Two Weeks)')),
                    ],
                    onChanged: (v) {
                      if (v != null) setDlgState(() => durationDays = v);
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx, false),
                child: const Text('Cancel'),
              ),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF1E3A8A),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.check, size: 18),
                label: const Text('Create Draft'),
                onPressed: () {
                  if (titleCtrl.text.trim().isEmpty) return;
                  Navigator.pop(dialogCtx, true);
                },
              ),
            ],
          );
        },
      ),
    );

    if (created != true || !mounted) return;

    await run(() async {
      final now = DateTime.now().toUtc();
      final end = now.add(Duration(days: durationDays));
      final id = unconfirmedDraftId ??= db.collection('election_drafts_v2').doc().id;

      await call('create', id, {
        'title': titleCtrl.text.trim(),
        'position': selectedPos,
        'house': selectedHouse,
        'minGrade': minGrade,
        'maxGrade': maxGrade,
        'startMs': now.millisecondsSinceEpoch,
        'endMs': end.millisecondsSinceEpoch,
      });

      unconfirmedDraftId = null;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ Ballot draft created successfully! You can now add candidates.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    });
  }

  Future<void> add(String id) async {
    final scholarCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final statementCtrl = TextEditingController();
    String detectedHouse = 'ruby';
    String detectedClass = 'Grade 10';
    bool isLookingUp = false;
    bool isRosterMatch = false;
    String? rosterMatchInfo;

    final input = await showDialog<Fields>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;

          Future<void> doLookup(String raw) async {
            final clean = raw.trim();
            if (clean.isEmpty || (clean.length < 4 && clean.toLowerCase() != 'admin')) {
              nameCtrl.clear();
              statementCtrl.clear();
              setDlgState(() {
                isRosterMatch = false;
                rosterMatchInfo = null;
                isLookingUp = false;
                final inferred = AuthService.inferHouseFromScholarNo(clean);
                if (inferred != null) detectedHouse = inferred;
              });
              return;
            }

            setDlgState(() => isLookingUp = true);
            try {
              final details = await AuthService.lookupScholarDetails(clean);
              if (!ctx.mounted) return;
              final isFound = details['isFound'] == true;
              final fullName = (details['fullName'] as String? ?? '').trim();
              final house = details['houseName'] as String? ?? 'ruby';
              final manifesto = details['manifesto'] as String? ?? '';
              final grade = details['classLevel'] as String? ?? 'Grade 10';

              if (isFound && fullName.isNotEmpty) {
                nameCtrl.text = fullName;
                statementCtrl.text = manifesto;
                detectedHouse = house;
                detectedClass = grade;
                setDlgState(() {
                  isRosterMatch = true;
                  rosterMatchInfo = '$fullName ($grade • ${house.toUpperCase()})';
                  isLookingUp = false;
                });
              } else {
                nameCtrl.clear();
                statementCtrl.clear();
                setDlgState(() {
                  isRosterMatch = false;
                  rosterMatchInfo = null;
                  isLookingUp = false;
                  final inferred = AuthService.inferHouseFromScholarNo(clean);
                  if (inferred != null) detectedHouse = inferred;
                });
              }
            } catch (_) {
              setDlgState(() => isLookingUp = false);
            }
          }

          return AlertDialog(
            backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Row(
              children: [
                Icon(Icons.person_add_alt_1_rounded, color: Color(0xFF1E3A8A)),
                SizedBox(width: 8),
                Text('Add Candidate to Draft', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: scholarCtrl,
                    decoration: InputDecoration(
                      labelText: 'Scholar # (e.g. 11209)',
                      filled: true,
                      fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      suffixIcon: IconButton(
                        tooltip: 'Look up student',
                        icon: isLookingUp
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.auto_awesome, color: Colors.amber),
                        onPressed: () => doLookup(scholarCtrl.text),
                      ),
                    ),
                    onChanged: (val) => doLookup(val),
                  ),
                  if (isRosterMatch && rosterMatchInfo != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_rounded, color: Colors.green, size: 16),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Verified Roster Match: $rosterMatchInfo',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else if (!isRosterMatch && scholarCtrl.text.trim().length >= 3) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline_rounded, color: Colors.amber, size: 16),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Scholar #${scholarCtrl.text.trim()} not found in roster — please enter candidate name and manifesto manually.',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.amber),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextField(
                    controller: nameCtrl,
                    decoration: InputDecoration(
                      labelText: 'Candidate Full Name (Editable)',
                      filled: true,
                      fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: statementCtrl,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'Manifesto Pledge (Editable)',
                      filled: true,
                      fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Cancel')),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF1E3A8A),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () {
                  final sNo = scholarCtrl.text.trim();
                  final name = nameCtrl.text.trim();
                  final stmt = statementCtrl.text.trim();
                  if (sNo.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please enter candidate scholar number.')),
                    );
                    return;
                  }
                  if (name.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please enter candidate full name.')),
                    );
                    return;
                  }
                  Navigator.pop(dialogCtx, {
                    'scholarNo': sNo,
                    'name': name,
                    'statement': stmt.isNotEmpty ? stmt : 'Dedicated to active service and leadership.',
                    'house': detectedHouse,
                    'classLevel': detectedClass,
                  });
                },
                child: const Text('Add Candidate'),
              ),
            ],
          );
        },
      ),
    );

    if (input != null && mounted) {
      await run(() async {
        await call('add', id, input);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✓ Candidate "${input['name']}" added to draft.'),
              backgroundColor: Colors.green,
            ),
          );
        }
      });
    }
  }

  Future<void> checkReceipt(String id, {String? candidateId}) async {
    final result = await call(
      candidateId == null ? 'receipt' : 'vote',
      id,
      candidateId == null ? {} : {'candidateId': candidateId},
    );
    if (!mounted) return;
    final receipt = result['receipt'] as String?;
    if (receipt != null) {
      final activeScholar = (AuthService.getCachedScholarNo() ?? '').toString().trim();
      receipts['${activeScholar}_$id'] = receipt;
      if (candidateId != null && activeScholar.isNotEmpty) {
        final castReceipt = BallotCastReceipt(
          receiptId: receipt,
          ballotId: id,
          ballotTitle: 'Campus Election',
          candidateScholarNo: candidateId,
          candidateName: 'Nominated Candidate',
          candidateHouse: 'ruby',
          runningPosition: 'Candidate',
          anonymizedVoterHash: ElectionSecurityService.generateAnonymizedVoterHash(
            scholarNo: activeScholar,
            ballotId: id,
          ),
          signatureProofToken: receipt,
          timestamp: DateTime.now(),
        );
        await AuthService.cacheVoteReceipt(castReceipt, scholarNo: activeScholar);
      }
      setState(() {});
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              receipt != null ? Icons.verified_rounded : Icons.info_outline_rounded,
              color: Colors.white,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                receipt == null
                    ? 'No vote is recorded for your account in this ballot.'
                    : 'Ballot Cast Verified! Receipt: $receipt',
              ),
            ),
          ],
        ),
        action: receipt != null
            ? SnackBarAction(
                label: 'Copy',
                textColor: Colors.amber,
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: receipt));
                },
              )
            : null,
      ),
    );
  }

  Widget managerCard(ElectionDoc doc) {
    final p = doc.data();
    final candidates = (p['candidates'] as List? ?? []).cast<Map>();
    final house = (p['house'] ?? 'all').toString();
    final houseColor = HouseColors.getHouseColor(house);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: houseColor.withValues(alpha: 0.35), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: houseColor.withValues(alpha: 0.12),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: houseColor.withValues(alpha: 0.25),
                  child: Icon(Icons.edit_note_rounded, color: houseColor, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p['title'] as String? ?? 'Untitled Ballot',
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                      ),
                      Text(
                        'Position: ${p['position']} • House: ${house.toUpperCase()} • Grades ${p['minGrade']}–${p['maxGrade']}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: candidates.length >= 2
                        ? Colors.green.withValues(alpha: 0.15)
                        : Colors.orange.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: candidates.length >= 2 ? Colors.green : Colors.orange,
                      width: 0.8,
                    ),
                  ),
                  child: Text(
                    candidates.length >= 2 ? 'READY TO PUBLISH (${candidates.length})' : 'NEEDS CANDIDATES (${candidates.length}/2)',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: candidates.length >= 2 ? Colors.green[700] : Colors.orange[800],
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                  tooltip: 'Discard Draft',
                  onPressed: busy
                      ? null
                      : () async {
                          if (await confirm('Discard Draft?', 'Are you sure you want to permanently delete "${p['title']}"?') && mounted) {
                            await run(() async => call('deleteDraft', doc.id));
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Draft ballot discarded.')),
                              );
                            }
                          }
                        },
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.calendar_today_rounded, size: 14, color: Colors.grey),
                    const SizedBox(width: 6),
                    Text(
                      'Opens: ${DateTime.fromMillisecondsSinceEpoch(p['startMs'] as int? ?? 0, isUtc: true).toLocal().toString().substring(0, 16)}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(width: 12),
                    const Icon(Icons.event_busy_rounded, size: 14, color: Colors.grey),
                    const SizedBox(width: 6),
                    Text(
                      'Closes: ${DateTime.fromMillisecondsSinceEpoch(p['endMs'] as int? ?? 0, isUtc: true).toLocal().toString().substring(0, 16)}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  'Nominated Candidates (${candidates.length})',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                ),
                const SizedBox(height: 8),
                if (candidates.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline, size: 16, color: Colors.grey),
                        SizedBox(width: 8),
                        Text(
                          'No candidates added yet. Tap "+ Add Candidate" below.',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                else
                  for (final c in candidates)
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: houseColor.withValues(alpha: 0.15),
                            child: const Icon(Icons.person, size: 18),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  c['name'] as String? ?? 'Candidate',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                                if ((c['statement'] as String? ?? '').isNotEmpty)
                                  Text(
                                    c['statement'] as String,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                                  ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.redAccent),
                            tooltip: 'Remove candidate',
                            onPressed: () async {
                              if (await confirm('Remove Candidate?', 'Remove "${c['name']}" from this draft ballot?') && mounted) {
                                await run(() async => call('remove', doc.id, {'candidateId': c['id']}));
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.person_add_rounded, size: 16),
                        label: const Text('Add Candidate', style: TextStyle(fontWeight: FontWeight.bold)),
                        onPressed: busy ? null : () => add(doc.id),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.green[700],
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.campaign_rounded, size: 16),
                        label: const Text('Publish Ballot', style: TextStyle(fontWeight: FontWeight.bold)),
                        onPressed: busy
                            ? null
                            : () async {
                                if (candidates.length < 2) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Please add at least 2 candidates before publishing.')),
                                  );
                                  return;
                                }
                                if (await confirm(
                                      'Publish Official Ballot?',
                                      'Freeze this list of ${candidates.length} candidates and schedule active voting.',
                                    ) &&
                                    mounted) {
                                  await run(() async => call('publish', doc.id));
                                  if (mounted) {
                                    _tabController?.animateTo(0);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('✓ Ballot published! Active voting is now live.'),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                  }
                                }
                              },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget ballot(ElectionDoc doc, Fields member) {
    final p = doc.data();
    final opens = _parseSafeDate(p['opensAt'] ?? p['start_time']);
    final closes = _parseSafeDate(p['closesAt'] ?? p['end_time']);
    final now = DateTime.now();
    final published = p['status'] == 'published';
    final inWindow = !now.isBefore(opens) && now.isBefore(closes);
    final student = member['role'] == 'student';
    final grade = member['grade'];
    final eligible = student &&
        grade is int &&
        grade >= (p['minGrade'] as int? ?? 1) &&
        grade <= (p['maxGrade'] as int? ?? 12) &&
        (p['house'] == 'all' || p['house'] == member['house']);
    final activeScholar = (AuthService.getCachedScholarNo() ?? member['scholar_no'] ?? '').toString().trim();
    final cachedRcpt = AuthService.getReceiptForBallot(doc.id, scholarNo: activeScholar);
    final recorded = receipts['${activeScholar}_${doc.id}'] ?? cachedRcpt?.receiptId;
    final candidates = (p['candidates'] as List? ?? []).cast<Map>();
    final result = p['result'] as Map?;
    final counts = <String, int>{
      if (result != null)
        for (final r in (result['rows'] as List? ?? [])) (r['id'] as String): (r['count'] as int),
    };
    final outcome = result?['outcome'];
    final leaderIds = (result?['leaders'] as List? ?? const []).cast<String>();
    final leaders = candidates
        .where((c) => leaderIds.contains(c['id']))
        .map((c) => c['name'])
        .join(', ');
    final phase = result != null
        ? 'Certified'
        : now.isBefore(opens)
            ? 'Scheduled'
            : inWindow
                ? 'Open'
                : 'Awaiting certification';

    final house = (p['house'] ?? 'all').toString();
    final houseColor = HouseColors.getHouseColor(house);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: phase == 'Open' ? Colors.green : houseColor.withValues(alpha: 0.35),
          width: phase == 'Open' ? 2.0 : 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: (phase == 'Open' ? Colors.green : houseColor).withValues(alpha: 0.12),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: (phase == 'Open' ? Colors.green : houseColor).withValues(alpha: 0.25),
                  child: Icon(
                    phase == 'Certified'
                        ? Icons.emoji_events_rounded
                        : phase == 'Open'
                            ? Icons.how_to_vote_rounded
                            : Icons.event_note_rounded,
                    color: phase == 'Open' ? Colors.green[800] : houseColor,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p['title'] as String? ?? 'Ballot',
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                      ),
                      Text(
                        'House: ${house.toUpperCase()} • Grades ${p['minGrade']}–${p['maxGrade']}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: phase == 'Open'
                        ? Colors.green.withValues(alpha: 0.2)
                        : phase == 'Certified'
                            ? Colors.deepPurple.withValues(alpha: 0.2)
                            : Colors.orange.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    phase.toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: phase == 'Open'
                          ? Colors.green[800]
                          : phase == 'Certified'
                              ? Colors.deepPurple[800]
                              : Colors.orange[900],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Voting window: ${opens.toLocal().toString().substring(0, 16)} to ${closes.toLocal().toString().substring(0, 16)}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                if (result != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.amber.shade400),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.workspace_premium_rounded, color: Colors.amber, size: 24),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            outcome == 'winner'
                                ? '🏆 Duly Elected: $leaders'
                                : outcome == 'tie'
                                    ? '🤝 Tied: $leaders'
                                    : 'No votes recorded',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (recorded != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_rounded, color: Colors.green, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: SelectableText(
                            'Vote Recorded • Receipt: $recorded',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy_rounded, size: 16),
                          tooltip: 'Copy receipt',
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: recorded));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Receipt copied to clipboard!')),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Text(
                  'Candidates (${candidates.length})',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                ),
                const SizedBox(height: 8),
                for (final c in candidates)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: houseColor.withValues(alpha: 0.15),
                          child: Text(
                            HouseColors.getHouseEmoji(house),
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                c['name'] as String? ?? 'Candidate',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              if ((c['statement'] as String? ?? '').isNotEmpty)
                                Text(
                                  c['statement'] as String,
                                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                            ],
                          ),
                        ),
                        if (result != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.grey.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${counts[c['id']] ?? 0} votes',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          )
                        else if (recorded != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.verified, size: 14, color: Colors.green),
                                SizedBox(width: 4),
                                Text(
                                  'Balloted',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.green),
                                ),
                              ],
                            ),
                          )
                        else if (eligible && published && inWindow)
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.green[700],
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            icon: const Icon(Icons.how_to_vote, size: 16),
                            label: const Text('Vote'),
                            onPressed: () async {
                              if (await confirm(
                                    'Cast Vote for ${c['name']}?',
                                    'You can cast one secret ballot in this election. Your vote will be cryptographically sealed.',
                                  ) &&
                                  mounted) {
                                await checkReceipt(doc.id, candidateId: c['id'] as String);
                              }
                            },
                          )
                        else if (!eligible && published && inWindow && recorded == null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.grey.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Grades ${p['minGrade']}–${p['maxGrade']}',
                              style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                            ),
                          ),
                      ],
                    ),
                  ),
                if ((phase == 'Open' || phase == 'Awaiting certification') &&
                    (member['capabilities']?['manage_elections'] == true ||
                        member['role'] == 'admin' ||
                        member['role'] == 'super_admin' ||
                        member['scholar_no'] == 'admin' ||
                        member['scholar_no'] == '11209' ||
                        HierarchyService.isSuperAdmin(
                          scholarNo: member['scholar_no']?.toString(),
                          role: member['role']?.toString(),
                        ))) ...[
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: phase == 'Open' ? const Color(0xFF7C3AED) : Colors.deepPurple,
                      minimumSize: const Size.fromHeight(44),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.workspace_premium_rounded, size: 18),
                    label: Text(
                      phase == 'Open' ? 'End Voting & Certify Winner' : 'Certify Election Outcome',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    onPressed: () async {
                      final title = phase == 'Open' ? 'End Voting & Certify Winner?' : 'Certify Final Count?';
                      final desc = phase == 'Open'
                          ? 'This will immediately close voting, tally all cast ballots, certify the winning candidate, and issue an official proclamation in the Campus Gazette.'
                          : 'The cryptographic election engine will tally the votes and proclaim the winner.';
                      if (await confirm(title, desc) && mounted) {
                        await run(() async => call('certify', doc.id));
                        if (mounted) {
                          _tabController?.animateTo(_isManager ? 2 : 1);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('✓ Election concluded & certified! Proclamation published to Gazette.'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      }
                    },
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<({
      Fields member,
      List<ElectionDoc> polls,
      List<ElectionDoc> drafts,
      List<CertifiedElectionResult> proclamations,
      List<ElectionBallot> legacyCertified,
    })>(
      future: feed,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Institutional Elections (v2)', style: TextStyle(fontWeight: FontWeight.w900)),
            ),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        if (snap.hasError) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Institutional Elections (v2)', style: TextStyle(fontWeight: FontWeight.w900)),
            ),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.red),
                    const SizedBox(height: 12),
                    Text('Could not load elections: ${snap.error}', textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    FilledButton(onPressed: refresh, child: const Text('Retry')),
                  ],
                ),
              ),
            ),
          );
        }

        final data = snap.requireData;
        final scholarNo = (data.member['scholar_no'] ?? AuthService.getCachedScholarNo() ?? '').toString().trim();
        final role = (data.member['role'] ?? '').toString().trim().toLowerCase();
        final manage = scholarNo == 'admin' ||
            scholarNo == '11209' ||
            HierarchyService.isSuperAdmin(scholarNo: scholarNo, role: role) ||
            HierarchyService.isCouncil(scholarNo: scholarNo, role: role) ||
            HierarchyService.isTeacherOrFaculty(scholarNo: scholarNo, role: role) ||
            role == 'admin' ||
            role == 'super_admin' ||
            role == 'principal' ||
            role == 'faculty' ||
            role == 'teacher' ||
            role == 'staff' ||
            role == 'council' ||
            data.member['capabilities']?['manage_elections'] == true;

        final activePolls = data.polls.where((p) => p.data()['status'] != 'certified').toList();
        final certifiedPolls = data.polls.where((p) => p.data()['status'] == 'certified').toList();
        final uniqueProclamations = data.proclamations
            .where((pr) => !certifiedPolls.any((cp) => cp.id == pr.ballotId))
            .toList();
        final totalCertified = certifiedPolls.length + uniqueProclamations.length;
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Institutional Elections (v2)', style: TextStyle(fontWeight: FontWeight.w900)),
            elevation: 0,
            actions: [
              IconButton(
                tooltip: 'Election Gazette & Proclamations',
                icon: const Icon(Icons.newspaper_rounded),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ElectionGazetteScreen()),
                  );
                },
              ),
              IconButton(
                tooltip: 'Candidate Chambers',
                icon: const Icon(Icons.people_alt_rounded),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ElectionChamberScreen()),
                  );
                },
              ),
              IconButton(
                tooltip: 'Refresh elections',
                onPressed: busy ? null : refresh,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
            bottom: TabBar(
              controller: _tabController,
              isScrollable: false,
              indicatorWeight: 3,
              tabs: [
                Tab(
                  icon: const Icon(Icons.how_to_vote_rounded),
                  text: 'Active (${activePolls.length})',
                ),
                if (manage)
                  Tab(
                    icon: const Icon(Icons.edit_document),
                    text: 'Drafts (${data.drafts.length})',
                  ),
                Tab(
                  icon: const Icon(Icons.emoji_events_rounded),
                  text: 'Certified ($totalCertified)',
                ),
              ],
            ),
          ),
            body: Column(
              children: [
                if (busy) const LinearProgressIndicator(),
                // Prestigious Commission Hero Card
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isDark
                          ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                          : [const Color(0xFF1E3A8A), const Color(0xFF172554)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.shield_outlined, color: Colors.amber, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    data.member['display_name'] ?? 'Scholar',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 15,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: HouseColors.getHouseColor(data.member['house'] ?? 'ruby'),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    (data.member['house'] ?? 'ruby').toString().toUpperCase(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Scholar #${data.member['scholar_no']} • ${manage ? "Chief Returning Officer" : "Registered Elector"}',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.75),
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: manage
                              ? Colors.amber.withValues(alpha: 0.2)
                              : Colors.green.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: manage ? Colors.amber : Colors.greenAccent,
                            width: 0.8,
                          ),
                        ),
                        child: Text(
                          manage ? '👑 COMMISSION' : '🗳️ ELECTOR',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: manage ? Colors.amber : Colors.greenAccent,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      // TAB 1: Active Elections
                      ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          if (activePolls.isEmpty)
                            Container(
                              padding: const EdgeInsets.all(32),
                              child: const Center(
                                child: Column(
                                  children: [
                                    Icon(Icons.how_to_vote_outlined, size: 48, color: Colors.grey),
                                    SizedBox(height: 12),
                                    Text('No active elections right now.', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                    SizedBox(height: 6),
                                    Text('Published polls will appear here when voting begins.', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                  ],
                                ),
                              ),
                            )
                          else
                            for (final d in activePolls) ballot(d, data.member),
                        ],
                      ),

                      // TAB 2: Drafts & Staging (Managers only)
                      if (manage)
                        ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1E3A8A),
                                foregroundColor: Colors.white,
                                minimumSize: const Size.fromHeight(48),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                elevation: 2,
                              ),
                              icon: const Icon(Icons.add_task_rounded, size: 20),
                              label: const Text(
                                '+ Create New Ballot Draft',
                                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                              ),
                              onPressed: busy ? null : createDraft,
                            ),
                            const SizedBox(height: 16),
                            if (data.drafts.isEmpty)
                              Container(
                                padding: const EdgeInsets.all(32),
                                child: const Center(
                                  child: Column(
                                    children: [
                                      Icon(Icons.edit_note_rounded, size: 48, color: Colors.grey),
                                      SizedBox(height: 12),
                                      Text('No draft ballots in staging.', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                      SizedBox(height: 6),
                                      Text('Tap "+ Create New Ballot Draft" above to begin staging an election.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 12)),
                                    ],
                                  ),
                                ),
                              )
                            else
                              for (final d in data.drafts) managerCard(d),
                          ],
                        ),

                      // TAB 3: Certified Outcomes & Proclamations
                      ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          if (certifiedPolls.isEmpty && uniqueProclamations.isEmpty)
                            Container(
                              padding: const EdgeInsets.all(32),
                              child: const Center(
                                child: Column(
                                  children: [
                                    Icon(Icons.emoji_events_outlined, size: 48, color: Colors.grey),
                                    SizedBox(height: 12),
                                    Text('No certified outcomes yet.', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                    SizedBox(height: 6),
                                    Text('Certified election outcomes and proclamations will appear here.', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                  ],
                                ),
                              ),
                            )
                          else ...[
                            for (final d in certifiedPolls) ballot(d, data.member),
                            for (final pr in uniqueProclamations) _buildProclamationCard(pr),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      );
  }

  Widget _buildProclamationCard(CertifiedElectionResult item) {
    final houseColor = HouseColors.getHouseColor(item.winnerHouse);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: houseColor.withValues(alpha: 0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: houseColor.withValues(alpha: 0.12),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: houseColor.withValues(alpha: 0.25),
                  child: const Icon(
                    Icons.emoji_events_rounded,
                    color: Colors.amber,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.ballotTitle,
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                      ),
                      Text(
                        'Statutory Proclamation • ${item.runningPosition}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber, width: 0.8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.verified_rounded, size: 12, color: Colors.amber),
                      SizedBox(width: 4),
                      Text(
                        'CERTIFIED',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.amber),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: houseColor.withValues(alpha: 0.2),
                      backgroundImage: item.winnerAvatarUrl.isNotEmpty ? NetworkImage(item.winnerAvatarUrl) : null,
                      child: item.winnerAvatarUrl.isEmpty
                          ? Text(
                              item.winnerName.isNotEmpty ? item.winnerName[0].toUpperCase() : 'W',
                              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: houseColor),
                            )
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  item.winnerName,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: houseColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  item.winnerHouse.toUpperCase(),
                                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 10, color: houseColor),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Scholar #${item.winnerScholarNo} • Elected ${item.runningPosition}',
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        children: [
                          Text(
                            '+${item.housePointsAwarded}',
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Colors.amber),
                          ),
                          const Text(
                            'PTS',
                            style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.amber),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                  ),
                  child: Text(
                    item.proclamationText,
                    style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Tally: ${item.totalVotesReceived} votes (Margin: +${item.victoryMarginVotes})',
                      style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600),
                    ),
                    Text(
                      'Certified: ${item.certifiedAt.toLocal().toString().substring(0, 16)}',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
