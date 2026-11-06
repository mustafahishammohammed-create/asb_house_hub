import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

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
    final member = (await db.collection('school_members').doc(widget.uid).get(opts)).data();
    if (member == null || member['active'] != true) {
      throw StateError('Ask the school to link your account to its roster.');
    }
    final polls = await db.collection('election_polls_v2').orderBy('opensAt', descending: true).get(opts);
    final canManage = member['capabilities']?['manage_elections'] == true;
    final drafts = canManage
        ? (await db.collection('election_drafts_v2').orderBy('startMs', descending: true).get(opts)).docs
        : <ElectionDoc>[];
    return (member: member, polls: polls.docs, drafts: drafts);
  }

  void refresh() => setState(() => feed = load());

  Future<Fields> call(String action, String id, [Fields args = const {}]) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.uid != widget.uid) throw StateError('Sign in again.');
    final token = await user.getIdToken();
    if (token == null) throw StateError('Sign in again.');
    final project = Firebase.app().options.projectId;
    final url = Uri.https('us-central1-$project.cloudfunctions.net', '/schoolElection');
    final reply = await http.post(
      url,
      headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
      body: jsonEncode({'data': {...args, 'action': action, 'pollId': id}}),
    ).timeout(const Duration(seconds: 25));
    if (!mounted || FirebaseAuth.instance.currentUser?.uid != user.uid) {
      throw StateError('Account changed. Reopen elections.');
    }
    final envelope = jsonDecode(reply.body);
    if (envelope is! Map) throw const FormatException('Unrecognized server response.');
    if (reply.statusCode != 200 || envelope['error'] != null) {
      throw StateError(envelope['error']?['message']?.toString() ?? 'Request failed.');
    }
    final result = envelope['result'] ?? envelope['data'];
    if (result is! Map) throw const FormatException('Missing election confirmation.');
    return Map<String, dynamic>.from(result);
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
          SnackBar(content: Text('$error  Refresh to check the server before retrying.')),
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
        title: Text(title),
        content: SingleChildScrollView(
          child: Form(
            key: key,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final field in labels.entries)
                  TextFormField(
                    decoration: InputDecoration(labelText: field.value),
                    onChanged: (value) => values[field.key] = value.trim(),
                    validator: (value) => value == null || value.trim().isEmpty ? 'Required' : null,
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
        title: Text(title),
        content: Text(detail),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialog, true), child: const Text('Confirm')),
        ],
      ),
    ) ?? false;
  }

  Future<void> createDraft() async {
    final values = await form('Create a private draft', {
      'title': 'Election title',
      'position': 'Position code, e.g. houseCaptain',
      'house': 'House, or all',
      'minGrade': 'Lowest eligible grade (1–12)',
      'maxGrade': 'Highest eligible grade (1–12)',
      'start': 'Opening time in UTC, YYYY-MM-DDTHH:MMZ',
      'end': 'Closing time in UTC, YYYY-MM-DDTHH:MMZ',
    });
    if (values == null || !mounted) return;
    int instant(String key) {
      final text = values.remove(key) as String;
      if (!text.endsWith('Z')) throw const FormatException('Include the UTC suffix Z.');
      final date = DateTime.parse(text);
      final canonical = '${date.toUtc().toIso8601String().substring(0, 16)}Z';
      if (canonical != text) throw const FormatException('Use YYYY-MM-DDTHH:MMZ.');
      return date.millisecondsSinceEpoch;
    }
    values['startMs'] = instant('start');
    values['endMs'] = instant('end');
    values['minGrade'] = int.parse(values['minGrade'] as String);
    values['maxGrade'] = int.parse(values['maxGrade'] as String);
    values['house'] = (values['house'] as String).toLowerCase();
    final id = unconfirmedDraftId ??= db.collection('election_drafts_v2').doc().id;
    await call('create', id, values);
    unconfirmedDraftId = null;
  }

  Future<void> add(String id) async {
    final input = await form('Add or update a candidate', {
      'scholarNo': 'Registered scholar number',
      'statement': 'Approved candidate statement',
    });
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
        content: Text(
          receipt == null
              ? 'No vote is recorded for your account in this election.'
              : 'Your vote is recorded. Receipt: $receipt',
        ),
      ),
    );
  }

  Fields ifCandidate(String? id) => id == null ? {} : {'candidateId': id};

  Widget action(String label, Future<void> Function() work) => TextButton(
        onPressed: busy ? null : () => run(work),
        child: Text(label),
      );

  Widget managerCard(ElectionDoc doc) {
    final p = doc.data();
    final candidates = (p['candidates'] as List).cast<Map>();
    return Card(
      child: ExpansionTile(
        title: Text(p['title'] as String),
        subtitle: Text(
          '${p['status']} · ${p['position']} · ${p['house']} · Grades ${p['minGrade']}–${p['maxGrade']}',
        ),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Opens ${DateTime.fromMillisecondsSinceEpoch(p['startMs'] as int, isUtc: true)}'),
                Text('Closes ${DateTime.fromMillisecondsSinceEpoch(p['endMs'] as int, isUtc: true)}'),
              ],
            ),
          ),
          for (final c in candidates)
            ListTile(
              title: Text(c['name'] as String),
              subtitle: Text(c['statement'] as String),
              trailing: p['status'] == 'draft'
                  ? action('Remove', () async {
                      if (await confirm('Remove candidate?', c['name'] as String) && mounted) {
                        await call('remove', doc.id, {'candidateId': c['id']});
                      }
                    })
                  : null,
            ),
          if (p['status'] == 'draft') ...[
            action('Add candidate', () => add(doc.id)),
            action('Publish ballot', () async {
              if (await confirm(
                    'Publish ballot?',
                    'Freeze this list of ${candidates.length} candidates and schedule voting.',
                  ) &&
                  mounted) {
                await call('publish', doc.id);
              }
            }),
          ],
          if (p['status'] == 'published')
            action('Certify after deadline', () async {
              if (await confirm(
                    'Publish the final count?',
                    'The server will count the votes and declare the outcome.',
                  ) &&
                  mounted) {
                await call('certify', doc.id);
              }
            }),
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
        grade >= p['minGrade'] &&
        grade <= p['maxGrade'] &&
        (p['house'] == 'all' || p['house'] == member['house']);
    final recorded = receipts[doc.id];
    final candidates = (p['candidates'] as List).cast<Map>();
    final result = p['result'] as Map?;
    final counts = <String, int>{
      if (result != null)
        for (final r in result['rows'] as List) r['id'] as String: r['count'] as int,
    };
    final outcome = result?['outcome'];
    final leaderIds = result?['leaders'] as List? ?? const [];
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
    return Card(
      child: ExpansionTile(
        title: Text(p['title'] as String),
        subtitle: Text('$phase · ${p['house']} · Grades ${p['minGrade']}–${p['maxGrade']}'),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Voting window (your local time): ${opens.toLocal()} to ${closes.toLocal()}'),
                if (result != null)
                  Text(
                    outcome == 'winner'
                        ? 'Elected: $leaders'
                        : outcome == 'tie'
                            ? 'Tied: $leaders'
                            : 'No votes cast',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                if (recorded != null) SelectableText('Recorded · Receipt $recorded'),
                if (published && inWindow && !eligible)
                  const Text('You can view this ballot. Voting is limited to eligible students.'),
              ],
            ),
          ),
          for (final c in candidates)
            ListTile(
              title: Text(c['name'] as String),
              subtitle: Text(c['statement'] as String),
              trailing: result != null
                  ? Text('${counts[c['id']]} votes')
                  : eligible && published && inWindow && recorded == null
                      ? action('Vote', () async {
                          if (await confirm(
                                'Vote for ${c['name']}?',
                                'You can cast one vote in this election.',
                              ) &&
                              mounted) {
                            await checkReceipt(doc.id, candidateId: c['id'] as String);
                          }
                        })
                      : null,
            ),
          if (student) action('Check my receipt', () => checkReceipt(doc.id)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('School Elections'),
        actions: [
          IconButton(
            tooltip: 'Refresh elections',
            onPressed: busy ? null : refresh,
            icon: const Icon(Icons.refresh),
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
            return Center(child: Text('Could not load elections. ${snap.error}'));
          }
          final data = snap.requireData;
          final manage = data.member['capabilities']?['manage_elections'] == true;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (busy) const LinearProgressIndicator(),
              if (manage) ...[
                Text('Election management', style: Theme.of(context).textTheme.titleLarge),
                action('Create draft', createDraft),
                for (final d in data.drafts) managerCard(d),
                const SizedBox(height: 16),
              ],
              Text('Published ballots and results', style: Theme.of(context).textTheme.titleLarge),
              if (data.polls.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.0),
                  child: Text('The school has not published any ballots yet.'),
                ),
              for (final d in data.polls) ballot(d, data.member),
            ],
          );
        },
      ),
    );
  }
}
