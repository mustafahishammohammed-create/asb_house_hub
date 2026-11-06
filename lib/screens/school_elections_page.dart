import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../services/auth_service.dart';
import '../models/election_gazette.dart';
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
        return _ElectionDesk(key: ValueKey(user.uid), uid: user.uid);
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

class _ElectionDeskState extends State<_ElectionDesk> {
  final db = FirebaseFirestore.instance;
  final _authService = AuthService();
  late Future<({Fields member, List<ElectionDoc> polls, List<ElectionDoc> drafts})> feed;
  bool busy = false;
  String? unconfirmedDraftId;
  final receipts = <String, String>{};

  @override
  void initState() {
    super.initState();
    feed = load();
  }

  Future<({Fields member, List<ElectionDoc> polls, List<ElectionDoc> drafts})> load() async {
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

    // 2. Fetch published polls
    List<ElectionDoc> polls = [];
    try {
      final snap = await db.collection('election_polls_v2').orderBy('opensAt', descending: true).get(opts);
      polls = snap.docs;
    } catch (_) {
      try {
        final snap = await db.collection('election_polls_v2').orderBy('opensAt', descending: true).get();
        polls = snap.docs;
      } catch (_) {}
    }

    // 3. Fetch drafts for authorized managers
    final canManage = member['capabilities']?['manage_elections'] == true ||
        member['role'] == 'admin' ||
        member['role'] == 'super_admin';
    List<ElectionDoc> drafts = [];
    if (canManage) {
      try {
        final snap = await db.collection('election_drafts_v2').orderBy('startMs', descending: true).get(opts);
        drafts = snap.docs;
      } catch (_) {
        try {
          final snap = await db.collection('election_drafts_v2').orderBy('startMs', descending: true).get();
          drafts = snap.docs;
        } catch (_) {}
      }
    }

    return (member: member, polls: polls, drafts: drafts);
  }

  void refresh() => setState(() => feed = load());

  Future<Fields> call(String action, String id, [Fields args = const {}]) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.uid != widget.uid) throw StateError('Sign in again.');

    // Step A: Attempt server-authoritative Cloud Function invocation
    try {
      final token = await user.getIdToken();
      if (token != null) {
        final project = Firebase.app().options.projectId;
        final url = Uri.https('us-central1-$project.cloudfunctions.net', '/schoolElection');
        final reply = await http.post(
          url,
          headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
          body: jsonEncode({'data': {...args, 'action': action, 'pollId': id}}),
        ).timeout(const Duration(seconds: 8));

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

    final canManage = person['capabilities']?['manage_elections'] == true ||
        person['role'] == 'admin' ||
        person['role'] == 'super_admin';
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
      if (scholar.isEmpty) throw StateError('Enter registered scholar number.');
      if (statement.isEmpty) throw StateError('Enter approved candidate statement.');

      var matches = await db.collection('school_members').where('scholar_no', isEqualTo: scholar).limit(2).get();
      if (matches.docs.isEmpty) {
        final userMatches = await db.collection('users').where('scholar_no', isEqualTo: scholar).limit(1).get();
        if (userMatches.docs.isNotEmpty) {
          final uDoc = userMatches.docs.first;
          await _authService.ensureSchoolMemberRecord(uid: uDoc.id, profile: uDoc.data());
          matches = await db.collection('school_members').where('scholar_no', isEqualTo: scholar).limit(2).get();
        }
      }

      if (matches.docs.isEmpty) {
        throw StateError('Scholar #$scholar was not found on the roster.');
      }
      final candDoc = matches.docs.first;
      final candData = candDoc.data();
      final candName = (candData['display_name'] ?? 'Scholar $scholar').toString();

      return await db.runTransaction<Fields>((tx) async {
        final dSnap = await tx.get(draftRef);
        if (!dSnap.exists) throw StateError('Draft not found.');
        final dData = dSnap.data()!;
        if (dData['status'] != 'draft') throw StateError('Published candidates are frozen.');

        final curList = (dData['candidates'] as List? ?? []).cast<Map>();
        final existing = curList.firstWhere((c) => c['uid'] == candDoc.id, orElse: () => {});
        final candId = existing['id'] ?? 'cnd_${DateTime.now().millisecondsSinceEpoch}_${curList.length + 1}';
        final filtered = curList.where((c) => c['uid'] != candDoc.id).map((c) => Map<String, dynamic>.from(c)).toList();
        filtered.add({
          'id': candId,
          'uid': candDoc.id,
          'name': candName,
          'statement': statement,
        });

        tx.update(draftRef, {'candidates': filtered});
        return {'pollId': pollId, 'candidateId': candId};
      });
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
          'statement': c['statement'],
        }).toList();

        final startMs = d['startMs'] as int;
        final endMs = d['endMs'] as int;

        tx.set(pollRef, {
          'title': d['title'],
          'position': d['position'],
          'minGrade': d['minGrade'],
          'maxGrade': d['maxGrade'],
          'house': d['house'],
          'opensAt': Timestamp.fromMillisecondsSinceEpoch(startMs),
          'closesAt': Timestamp.fromMillisecondsSinceEpoch(endMs),
          'candidates': pubCandidates,
          'status': 'published',
          'publishedAt': FieldValue.serverTimestamp(),
        });
        tx.update(draftRef, {'status': 'published', 'publishedBy': user.uid});
        return {'pollId': pollId, 'status': 'published'};
      });
    }

    if (action == 'certify') {
      return await db.runTransaction<Fields>((tx) async {
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

        final total = rows.fold<int>(0, (sum, r) => sum + (r['count'] as int));
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
          'result': result,
          'certifiedAt': FieldValue.serverTimestamp(),
        });
        tx.update(draftRef, {
          'status': 'certified',
          'certifiedBy': user.uid,
        });

        // Publish statutory proclamation to Campus Election Gazette
        try {
          if (leaders.isNotEmpty) {
            final winningCand = candidates.firstWhere(
              (c) => c['id'] == leaders.first,
              orElse: () => candidates.first,
            );
            final winnerName = (winningCand['name'] ?? 'Candidate').toString();
            final house = (box['house'] ?? 'ruby').toString().toLowerCase();
            final winnerHouse = house == 'all' ? 'ruby' : house;

            final proclamation = CertifiedElectionResult(
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
            _authService.publishGazetteProclamation(proclamation);
          }
        } catch (_) {}

        return {'pollId': pollId, 'result': result};
      });
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

  Future<Fields?> form(String title, Map<String, String> labels) {
    final values = <String, dynamic>{};
    final key = GlobalKey<FormState>();
    return showDialog<Fields>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Form(
            key: key,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final field in labels.entries)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: TextFormField(
                      decoration: InputDecoration(
                        labelText: field.value,
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: (value) => values[field.key] = value.trim(),
                      validator: (value) => value == null || value.trim().isEmpty ? 'Required' : null,
                    ),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (key.currentState!.validate()) Navigator.pop(dialog, values);
            },
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  Future<bool> confirm(String title, String detail) async {
    return await showDialog<bool>(
          context: context,
          builder: (dialog) => AlertDialog(
            title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            content: Text(detail),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('Cancel')),
              FilledButton(onPressed: () => Navigator.pop(dialog, true), child: const Text('Confirm')),
            ],
          ),
        ) ??
        false;
  }

  Future<void> createDraft() async {
    final values = await form('Create an Institutional Ballot Draft', {
      'title': 'Election title (e.g. Senior House Captain 2026-2027)',
      'position': 'Position (houseCaptain, headBoy, headGirl, prefect, sportsCaptain)',
      'house': 'House (ruby, sapphire, emerald, topaz, or all)',
      'minGrade': 'Lowest eligible grade (1–12)',
      'maxGrade': 'Highest eligible grade (1–12)',
      'start': 'Opening time (UTC YYYY-MM-DDTHH:MMZ, or type "now")',
      'end': 'Closing time (UTC YYYY-MM-DDTHH:MMZ, or type "7d")',
    });
    if (values == null || !mounted) return;

    int parseInstant(String key, {bool isEnd = false}) {
      final raw = (values.remove(key) as String? ?? '').trim();
      DateTime dt;
      if (raw.isEmpty || raw.toLowerCase() == 'now') {
        dt = DateTime.now().toUtc();
        if (isEnd) dt = dt.add(const Duration(days: 7));
      } else if (raw.toLowerCase() == '7d') {
        dt = DateTime.now().toUtc().add(const Duration(days: 7));
      } else if (raw.toLowerCase() == '24h') {
        dt = DateTime.now().toUtc().add(const Duration(hours: 24));
      } else {
        try {
          dt = DateTime.parse(raw.endsWith('Z') ? raw : '${raw}Z').toUtc();
        } catch (_) {
          try {
            dt = DateTime.parse(raw).toUtc();
          } catch (_) {
            dt = DateTime.now().toUtc().add(isEnd ? const Duration(days: 7) : Duration.zero);
          }
        }
      }
      return dt.millisecondsSinceEpoch;
    }

    values['startMs'] = parseInstant('start');
    values['endMs'] = parseInstant('end', isEnd: true);
    values['minGrade'] = int.tryParse(values['minGrade'] as String? ?? '1') ?? 1;
    values['maxGrade'] = int.tryParse(values['maxGrade'] as String? ?? '12') ?? 12;
    values['house'] = (values['house'] as String? ?? 'all').toLowerCase();
    final id = unconfirmedDraftId ??= db.collection('election_drafts_v2').doc().id;
    await call('create', id, values);
    unconfirmedDraftId = null;
  }

  Future<void> add(String id) async {
    final scholarCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final statementCtrl = TextEditingController();
    String detectedHouse = 'ruby';
    String detectedClass = 'Grade 10';
    bool isLookingUp = false;

    final input = await showDialog<Fields>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          Future<void> doLookup(String raw) async {
            final clean = raw.trim();
            if (clean.length < 2) return;
            setDlgState(() => isLookingUp = true);
            try {
              final details = await AuthService.lookupScholarDetails(clean);
              nameCtrl.text = details['fullName'] as String? ?? '';
              statementCtrl.text = details['manifesto'] as String? ?? '';
              detectedHouse = details['houseName'] as String? ?? 'ruby';
              detectedClass = details['classLevel'] as String? ?? 'Grade 10';
            } catch (_) {} finally {
              setDlgState(() => isLookingUp = false);
            }
          }

          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.person_add_alt_1_rounded, color: Colors.blueAccent),
                SizedBox(width: 8),
                Text('Add Candidate (Auto-Filled)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
                      labelText: 'Scholar Number (e.g. SCH-042)',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        tooltip: 'Auto-fill from roster',
                        icon: isLookingUp
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.auto_awesome, color: Colors.amber),
                        onPressed: () => doLookup(scholarCtrl.text),
                      ),
                    ),
                    onChanged: (val) {
                      if (val.trim().length >= 3) {
                        doLookup(val);
                      }
                    },
                  ),
                  if (nameCtrl.text.isNotEmpty) ...[
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
                              'Roster Match: ${nameCtrl.text} (${detectedHouse.toUpperCase()} • $detectedClass)',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Candidate Full Name (Editable)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: statementCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Approved Candidate Statement / Pledge (Editable)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Cancel')),
              FilledButton(
                onPressed: () {
                  final sNo = scholarCtrl.text.trim();
                  final stmt = statementCtrl.text.trim();
                  if (sNo.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please enter candidate scholar number.')),
                    );
                    return;
                  }
                  Navigator.pop(dialogCtx, {
                    'scholarNo': sNo,
                    'statement': stmt.isNotEmpty ? stmt : 'Dedicated to active service and leadership.',
                    'name': nameCtrl.text.trim(),
                  });
                },
                child: const Text('Add Candidate'),
              ),
            ],
          );
        },
      ),
    );

    if (input != null && mounted) await call('add', id, input);
  }

  Future<void> checkReceipt(String id, {String? candidateId}) async {
    final result = await call(
      candidateId == null ? 'receipt' : 'vote',
      id,
      ifCandidate(candidateId),
    );
    if (!mounted) return;
    final receipt = result['receipt'] as String?;
    if (receipt != null) receipts[id] = receipt;
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

  Fields ifCandidate(String? id) => id == null ? {} : {'candidateId': id};

  Widget action(String label, Future<void> Function() work, {Color? color}) => TextButton(
        onPressed: busy ? null : () => run(work),
        style: color != null ? TextButton.styleFrom(foregroundColor: color) : null,
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
      );

  Widget managerCard(ElectionDoc doc) {
    final p = doc.data();
    final candidates = (p['candidates'] as List? ?? []).cast<Map>();
    final house = (p['house'] ?? 'all').toString();
    final houseColor = house == 'ruby'
        ? HouseColors.ruby
        : house == 'sapphire'
            ? const Color(0xFF2563EB)
            : house == 'emerald'
                ? const Color(0xFF059669)
                : house == 'topaz'
                    ? const Color(0xFFD97706)
                    : Colors.deepPurple;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: houseColor.withValues(alpha: 0.3)),
      ),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: houseColor.withValues(alpha: 0.15),
          child: Icon(Icons.edit_note_rounded, color: houseColor),
        ),
        title: Text(
          p['title'] as String? ?? 'Untitled Ballot',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${(p['status'] ?? 'draft').toString().toUpperCase()} · ${p['position']} · House: ${p['house']} · Grades ${p['minGrade']}–${p['maxGrade']}',
        ),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.schedule, size: 14, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      'Opens: ${DateTime.fromMillisecondsSinceEpoch(p['startMs'] as int? ?? 0, isUtc: true).toLocal()}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(Icons.event_busy, size: 14, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      'Closes: ${DateTime.fromMillisecondsSinceEpoch(p['endMs'] as int? ?? 0, isUtc: true).toLocal()}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
          for (final c in candidates)
            ListTile(
              dense: true,
              leading: const Icon(Icons.person_pin, size: 20),
              title: Text(c['name'] as String? ?? 'Candidate', style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(c['statement'] as String? ?? ''),
              trailing: p['status'] == 'draft'
                  ? action(
                      'Remove',
                      () async {
                        if (await confirm('Remove candidate?', c['name'] as String) && mounted) {
                          await call('remove', doc.id, {'candidateId': c['id']});
                        }
                      },
                      color: Colors.red[700],
                    )
                  : null,
            ),
          OverflowBar(
            alignment: MainAxisAlignment.end,
            children: [
              if (p['status'] == 'draft') ...[
                action('Add Candidate', () => add(doc.id)),
                action('Publish Ballot', () async {
                  if (await confirm(
                        'Publish Official Ballot?',
                        'Freeze this list of ${candidates.length} candidates and schedule active voting.',
                      ) &&
                      mounted) {
                    await call('publish', doc.id);
                  }
                }, color: Colors.green[700]),
              ],
              if (p['status'] == 'published')
                action('Certify Outcome', () async {
                  if (await confirm(
                        'Certify Final Count?',
                        'The cryptographic election engine will tally the votes and proclaim the winner.',
                      ) &&
                      mounted) {
                    await call('certify', doc.id);
                  }
                }, color: Colors.deepPurple),
            ],
          ),
        ],
      ),
    );
  }

  Widget ballot(ElectionDoc doc, Fields member) {
    final p = doc.data();
    final opens = (p['opensAt'] as Timestamp).toDate();
    final closes = (p['closesAt'] as Timestamp).toDate();
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
    final recorded = receipts[doc.id];
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
    final houseColor = house == 'ruby'
        ? HouseColors.ruby
        : house == 'sapphire'
            ? const Color(0xFF2563EB)
            : house == 'emerald'
                ? const Color(0xFF059669)
                : house == 'topaz'
                    ? const Color(0xFFD97706)
                    : Colors.deepPurple;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: phase == 'Open' ? Colors.green : houseColor.withValues(alpha: 0.3),
          width: phase == 'Open' ? 1.5 : 1.0,
        ),
      ),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: (phase == 'Open' ? Colors.green : houseColor).withValues(alpha: 0.15),
          child: Icon(
            phase == 'Certified'
                ? Icons.emoji_events_rounded
                : phase == 'Open'
                    ? Icons.how_to_vote_rounded
                    : Icons.event_note_rounded,
            color: phase == 'Open' ? Colors.green[700] : houseColor,
          ),
        ),
        title: Text(
          p['title'] as String? ?? 'Ballot',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: phase == 'Open'
                    ? Colors.green.withValues(alpha: 0.15)
                    : phase == 'Certified'
                        ? Colors.deepPurple.withValues(alpha: 0.15)
                        : Colors.orange.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                phase.toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: phase == 'Open'
                      ? Colors.green[800]
                      : phase == 'Certified'
                          ? Colors.deepPurple[800]
                          : Colors.orange[900],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${p['house']} · Grades ${p['minGrade']}–${p['maxGrade']}',
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Voting window (local time): ${opens.toLocal().toString().substring(0, 16)} to ${closes.toLocal().toString().substring(0, 16)}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 4),
                if (result != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    margin: const EdgeInsets.only(top: 4, bottom: 8),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber.shade400),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.workspace_premium_rounded, color: Colors.amber),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            outcome == 'winner'
                                ? 'Elected: $leaders'
                                : outcome == 'tie'
                                    ? 'Tied: $leaders'
                                    : 'No votes recorded',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (recorded != null)
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle, color: Colors.green, size: 16),
                        const SizedBox(width: 6),
                        Expanded(
                          child: SelectableText(
                            'Vote Recorded · Receipt: $recorded',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy, size: 14),
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
                if (published && inWindow && !eligible)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      'Ballot is open for eligible voting scholars in this grade and house.',
                      style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                    ),
                  ),
              ],
            ),
          ),
          for (final c in candidates)
            ListTile(
              leading: const Icon(Icons.account_circle, size: 28),
              title: Text(c['name'] as String? ?? 'Candidate', style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(c['statement'] as String? ?? ''),
              trailing: result != null
                  ? Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${counts[c['id']] ?? 0} votes',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    )
                  : eligible && published && inWindow && recorded == null
                      ? FilledButton.icon(
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
                      : null,
            ),
          Padding(
            padding: const EdgeInsets.only(right: 8, bottom: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (student)
                  action('Verify My Receipt', () => checkReceipt(doc.id)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Institutional Elections (v2)', style: TextStyle(fontWeight: FontWeight.w900)),
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
      ),
      body: FutureBuilder<({Fields member, List<ElectionDoc> polls, List<ElectionDoc> drafts})>(
        future: feed,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
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
            );
          }
          final data = snap.requireData;
          final manage = data.member['capabilities']?['manage_elections'] == true ||
              data.member['role'] == 'admin' ||
              data.member['role'] == 'super_admin';

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (busy) const LinearProgressIndicator(),
              if (manage) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Election Management', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                    FilledButton.icon(
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Create Draft'),
                      onPressed: busy ? null : createDraft,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (data.drafts.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('No draft ballots in preparation. Tap "Create Draft" to begin.'),
                  ),
                for (final d in data.drafts) managerCard(d),
                const SizedBox(height: 20),
              ],
              Text('Official Ballots & Proclamations', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              if (data.polls.isEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: Text('The school administration has not published any ballots yet.'),
                  ),
                ),
              for (final d in data.polls) ballot(d, data.member),
            ],
          );
        },
      ),
    );
  }
}
