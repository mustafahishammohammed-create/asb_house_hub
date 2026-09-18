import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:typed_data';
import 'dart:convert';

/// Domain appended to scholar numbers to create Firebase-compatible emails.
/// e.g., scholar_no "123456" becomes "123456@asianschool.bh"
const String kSchoolDomain = 'asianschool.bh';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Current authenticated user (nullable).
  User? get currentUser => _auth.currentUser;

  /// Stream of auth state changes.
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Convert a scholar number to a Firebase-compatible email.
  String _scholarToEmail(String scholarNo) {
    return '${scholarNo.trim()}@$kSchoolDomain';
  }

  /// Sign in with scholar number and password.
  /// Throws [FirebaseAuthException] on failure.
  Future<UserCredential> signIn({
    required String scholarNo,
    required String password,
  }) async {
    final email = _scholarToEmail(scholarNo);
    return await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  /// Admin profile data for the super admin account.
  static const _adminProfile = {
    'full_name': 'Mustafa Hisham',
    'scholar_no': 'admin',
    'role': 'super_admin',
    'house_name': 'ruby',
    'class_level': '11-D',
    'division': 'D',
  };

  /// Sign in as Administrator (admin@asianschool.bh).
  /// Auto-creates the admin account if it does not exist yet.
  Future<UserCredential> signInAdmin({required String password}) async {
    if (password != '2310910') {
      throw Exception('Incorrect Admin Master Password.');
    }
    const adminEmail = 'admin@asianschool.bh';
    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: adminEmail,
        password: password,
      );
      await _firestore
          .collection('users')
          .doc(cred.user!.uid)
          .set(_adminProfile, SetOptions(merge: true));
      return cred;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found' ||
          e.code == 'invalid-credential' ||
          e.code == 'invalid-login-credentials') {
        try {
          final cred = await _auth.createUserWithEmailAndPassword(
            email: adminEmail,
            password: password,
          );
          await _firestore
              .collection('users')
              .doc(cred.user!.uid)
              .set(_adminProfile, SetOptions(merge: true));
          return cred;
        } catch (_) {
          rethrow;
        }
      }
      rethrow;
    }
  }

  /// Register a new user and save their profile to Firestore.
  ///
  /// 1. Creates a Firebase Auth account using the scholar-email.
  /// 2. Saves profile metadata to the `users` collection keyed by UID.
  Future<UserCredential> signUp({
    required String scholarNo,
    required String password,
    required String fullName,
    required int age,
    required String classLevel,
    required String division,
    required String houseName,
  }) async {
    final email = _scholarToEmail(scholarNo);

    // Step 1 — Create auth user
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    // Step 2 — Save profile to Firestore `users` collection
    final uid = credential.user!.uid;
    await _firestore.collection('users').doc(uid).set({
      'full_name': fullName,
      'scholar_no': scholarNo,
      'age': age,
      'class_level': classLevel,
      'division': division,
      'house_name': houseName,
      'created_at': FieldValue.serverTimestamp(),
    });

    // Update display name
    await credential.user!.updateDisplayName(fullName);

    return credential;
  }

  /// Fetch user profile from Firestore by UID.
  Future<Map<String, dynamic>?> getUserProfile(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    return doc.data();
  }

  /// Send password reset email.
  Future<void> resetPassword(String scholarNo) async {
    final email = _scholarToEmail(scholarNo);
    await _auth.sendPasswordResetEmail(email: email);
  }

  /// Sign out.
  Future<void> signOut() async {
    await _auth.signOut();
  }

  /// Stream house standings.
  Stream<QuerySnapshot> getHouseStandingsStream() {
    return _firestore.collection('house_points').snapshots();
  }

  /// Stream recent school notices.
  Stream<QuerySnapshot> getNoticesStream() {
    return _firestore
        .collection('notices')
        .orderBy('created_at', descending: true)
        .limit(5)
        .snapshots();
  }

  /// Upload image file to Firebase Storage or convert to Data URL fallback.
  Future<String> uploadCertificateImage(
    Uint8List fileBytes,
    String scholarNo,
  ) async {
    try {
      final fileName =
          '${scholarNo}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = FirebaseStorage.instance.ref().child('claims/$fileName');
      await ref
          .putData(fileBytes, SettableMetadata(contentType: 'image/jpeg'))
          .timeout(const Duration(seconds: 3));
      return await ref.getDownloadURL().timeout(const Duration(seconds: 2));
    } catch (e) {
      // Fallback to fast Base64 Data URL if Firebase Storage bucket CORS or rules time out on Web
      final base64Str = base64Encode(fileBytes);
      return 'data:image/jpeg;base64,$base64Str';
    }
  }

  /// Submit a new house claim (Status: pending).
  Future<void> submitHouseClaim({
    required String scholarNo,
    required String studentName,
    required String houseName,
    required String activityTitle,
    required int points,
    required String certUrl,
  }) async {
    await _firestore.collection('house_claims').add({
      'scholar_no': scholarNo,
      'student_name': studentName,
      'house_name': houseName.toLowerCase(),
      'activity_title': activityTitle,
      'points': points,
      'cert_url': certUrl,
      'status': 'pending',
      'created_at': FieldValue.serverTimestamp(),
    });
  }

  /// Stream pending claims for Admin review.
  Stream<QuerySnapshot> getPendingClaimsStream() {
    return _firestore
        .collection('house_claims')
        .where('status', isEqualTo: 'pending')
        .snapshots();
  }

  /// Stream approved claims for Admin and Council gallery view.
  Stream<QuerySnapshot> getApprovedClaimsStream() {
    return _firestore
        .collection('house_claims')
        .where('status', isEqualTo: 'approved')
        .snapshots();
  }

  /// Approve claim and add points to house standings.
  Future<void> approveClaim({
    required String claimId,
    required String houseName,
    required int points,
  }) async {
    // 1. Mark claim as approved
    await _firestore.collection('house_claims').doc(claimId).update({
      'status': 'approved',
      'verified_at': FieldValue.serverTimestamp(),
    });

    // 2. Increment house points
    final houseRef = _firestore
        .collection('house_points')
        .doc(houseName.toLowerCase());
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(houseRef);
      if (!snapshot.exists) {
        transaction.set(houseRef, {
          'house_name': houseName.toLowerCase(),
          'total_points': points,
        });
      } else {
        final currentPoints =
            (snapshot.data()?['total_points'] as num?)?.toInt() ?? 0;
        transaction.update(houseRef, {'total_points': currentPoints + points});
      }
    });
  }

  /// Reject claim.
  Future<void> rejectClaim(String claimId) async {
    await _firestore.collection('house_claims').doc(claimId).update({
      'status': 'rejected',
      'verified_at': FieldValue.serverTimestamp(),
    });
  }

  /// Record a student conduct action (Merit or Demerit).
  /// Dynamically updates:
  /// 1. Overall house points (+pts for well-behaved, -pts for misbehaviour)
  /// 2. Student conduct audit log
  /// 3. Student's personal contribution total
  /// 4. Push notification alert to student's notification queue
  Future<void> recordStudentConduct({
    required String scholarNo,
    required String studentName,
    required String houseName,
    required String type, // 'merit' or 'demerit'
    required int points, // positive number of points
    required String reason,
    required String teacherName,
    String? classLevel,
  }) async {
    final hName = houseName.toLowerCase().trim();
    final delta = type == 'merit' ? points : -points;

    // 1. Atomically adjust house points
    final houseRef = _firestore.collection('house_points').doc(hName);
    await _firestore.runTransaction((tx) async {
      final snap = await tx.get(houseRef);
      if (!snap.exists) {
        tx.set(houseRef, {
          'house_name': hName,
          'total_points': delta > 0 ? delta : 0,
        });
      } else {
        final currentPts = (snap.data()?['total_points'] as num?)?.toInt() ?? 0;
        final newPts = (currentPts + delta) < 0 ? 0 : (currentPts + delta);
        tx.update(houseRef, {'total_points': newPts});
      }
    });

    // 2. Add to student_conduct log
    await _firestore.collection('student_conduct').add({
      'scholar_no': scholarNo,
      'student_name': studentName,
      'house_name': hName,
      'type': type,
      'points': delta,
      'reason': reason,
      'teacher_name': teacherName,
      'timestamp': FieldValue.serverTimestamp(),
    });

    // 3. Atomically update student contributor record
    final contributorRef = _firestore.collection('house_contributors').doc(scholarNo);
    await _firestore.runTransaction((tx) async {
      final snap = await tx.get(contributorRef);
      if (!snap.exists) {
        tx.set(contributorRef, {
          'scholar_no': scholarNo,
          'student_name': studentName,
          'house_name': hName,
          'class_level': classLevel ?? 'Senior',
          'total_contributed': delta,
          'merits_count': type == 'merit' ? 1 : 0,
          'demerits_count': type == 'demerit' ? 1 : 0,
          'last_updated': FieldValue.serverTimestamp(),
        });
      } else {
        final currentContributed =
            (snap.data()?['total_contributed'] as num?)?.toInt() ?? 0;
        final merits = (snap.data()?['merits_count'] as num?)?.toInt() ?? 0;
        final demerits = (snap.data()?['demerits_count'] as num?)?.toInt() ?? 0;
        tx.update(contributorRef, {
          'student_name': studentName,
          'house_name': hName,
          'total_contributed': currentContributed + delta,
          'merits_count': merits + (type == 'merit' ? 1 : 0),
          'demerits_count': demerits + (type == 'demerit' ? 1 : 0),
          'last_updated': FieldValue.serverTimestamp(),
        });
      }
    });

    // 4. Update user document and trigger push notification queue
    try {
      final userQuery = await _firestore
          .collection('users')
          .where('scholar_no', isEqualTo: scholarNo)
          .limit(1)
          .get();
      if (userQuery.docs.isNotEmpty) {
        final userDoc = userQuery.docs.first;
        await userDoc.reference.update({
          'points_contributed': FieldValue.increment(delta),
        });
        await userDoc.reference.collection('notifications').add({
          'title': type == 'merit'
              ? '🌟 +$points House Points Awarded!'
              : '⚠️ -$points House Points Deducted',
          'body': type == 'merit'
              ? 'Awarded to ${hName.toUpperCase()} House by $teacherName for: $reason'
              : 'Deducted from ${hName.toUpperCase()} House by $teacherName for: $reason',
          'timestamp': FieldValue.serverTimestamp(),
          'is_read': false,
          'type': 'conduct_record',
        });
      }
    } catch (_) {}
  }

  /// Stream conduct history for a specific student without requiring composite indexes.
  Stream<List<QueryDocumentSnapshot>> getStudentConductStream(String scholarNo) {
    if (scholarNo.trim().isEmpty || scholarNo == '---') {
      return Stream.value(<QueryDocumentSnapshot>[]);
    }
    return _firestore
        .collection('student_conduct')
        .where('scholar_no', isEqualTo: scholarNo)
        .snapshots()
        .map((snapshot) {
          final docs = snapshot.docs.toList();
          docs.sort((a, b) {
            final dataA = a.data() as Map<String, dynamic>?;
            final dataB = b.data() as Map<String, dynamic>?;
            final tA = dataA?['timestamp'] as Timestamp?;
            final tB = dataB?['timestamp'] as Timestamp?;
            if (tA == null && tB == null) return 0;
            if (tA == null) return 1;
            if (tB == null) return -1;
            return tB.compareTo(tA);
          });
          return docs;
        });
  }

  /// Stream contributors for a house leaderboard.
  Stream<QuerySnapshot> getHouseContributorsStream(String houseName) {
    return _firestore
        .collection('house_contributors')
        .where('house_name', isEqualTo: houseName.toLowerCase())
        .snapshots();
  }

  /// Seed initial sample contributors for all houses if empty.
  Future<void> seedSampleContributors() async {
    try {
      final snap = await _firestore.collection('house_contributors').limit(3).get();
      if (snap.docs.isNotEmpty) return;

      final samples = [
        // Ruby House
        {
          'scholar_no': '2310910',
          'student_name': 'Mustafa Hisham',
          'house_name': 'ruby',
          'class_level': '11-D',
          'total_contributed': 120,
          'merits_count': 4,
          'demerits_count': 0,
        },
        {
          'scholar_no': '11004',
          'student_name': 'Sarah Paul',
          'house_name': 'ruby',
          'class_level': '11-D',
          'total_contributed': 85,
          'merits_count': 3,
          'demerits_count': 0,
        },
        {
          'scholar_no': '10105',
          'student_name': 'Aryan Sharma',
          'house_name': 'ruby',
          'class_level': '10-A',
          'total_contributed': 65,
          'merits_count': 2,
          'demerits_count': 0,
        },
        {
          'scholar_no': '90123',
          'student_name': 'Riya Patel',
          'house_name': 'ruby',
          'class_level': '9-B',
          'total_contributed': 40,
          'merits_count': 2,
          'demerits_count': 0,
        },
        // Emerald House
        {
          'scholar_no': '10001',
          'student_name': 'Noaman Nizamuddin',
          'house_name': 'emerald',
          'class_level': '11-E',
          'total_contributed': 110,
          'merits_count': 4,
          'demerits_count': 0,
        },
        {
          'scholar_no': '20002',
          'student_name': 'Sarah Student Rep',
          'house_name': 'emerald',
          'class_level': '11-E',
          'total_contributed': 95,
          'merits_count': 3,
          'demerits_count': 0,
        },
        {
          'scholar_no': '11089',
          'student_name': 'Liam Chen',
          'house_name': 'emerald',
          'class_level': '11-E',
          'total_contributed': 70,
          'merits_count': 2,
          'demerits_count': 0,
        },
        // Sapphire House
        {
          'scholar_no': '30003',
          'student_name': 'Dr. Elizabeth Vance',
          'house_name': 'sapphire',
          'class_level': 'Teacher Lead',
          'total_contributed': 105,
          'merits_count': 3,
          'demerits_count': 0,
        },
        {
          'scholar_no': '12045',
          'student_name': 'Kevin George',
          'house_name': 'sapphire',
          'class_level': '12-B',
          'total_contributed': 90,
          'merits_count': 3,
          'demerits_count': 0,
        },
        {
          'scholar_no': '10432',
          'student_name': 'Meera Nair',
          'house_name': 'sapphire',
          'class_level': '10-C',
          'total_contributed': 60,
          'merits_count': 2,
          'demerits_count': 0,
        },
        // Topaz House
        {
          'scholar_no': '12001',
          'student_name': 'Tanish Mukherjee',
          'house_name': 'topaz',
          'class_level': '12-E',
          'total_contributed': 115,
          'merits_count': 4,
          'demerits_count': 0,
        },
        {
          'scholar_no': '11012',
          'student_name': 'Nayla Muhammad',
          'house_name': 'topaz',
          'class_level': '11-A',
          'total_contributed': 95,
          'merits_count': 3,
          'demerits_count': 0,
        },
        {
          'scholar_no': '10567',
          'student_name': 'Rohan Jacob',
          'house_name': 'topaz',
          'class_level': '10-B',
          'total_contributed': 50,
          'merits_count': 2,
          'demerits_count': 0,
        },
      ];

      final batch = _firestore.batch();
      for (final s in samples) {
        final ref = _firestore.collection('house_contributors').doc(s['scholar_no'] as String);
        batch.set(ref, {
          ...s,
          'last_updated': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
      await batch.commit();
    } catch (_) {}
  }

  /// Seed the complete admin and council roster into Firestore database.
  Future<void> seedAdminRoster() async {
    // Always ensure Mustafa Hisham is updated to 11-D and super_admin
    await _firestore.collection('admin_roster').doc('ruby_captain').set({
      'slot_id': 'ruby_captain',
      'title': 'Ruby House Captain',
      'name': 'Mustafa Hisham',
      'class': '11-D',
      'role': 'super_admin',
      'house': 'Ruby',
    }, SetOptions(merge: true));

    final snapshot = await _firestore.collection('admin_roster').limit(2).get();
    if (snapshot.docs.length > 1) return; // Already seeded other slots!

    final roster = [
      {
        'slot_id': 'ruby_captain',
        'title': 'Ruby House Captain',
        'name': 'Mustafa Hisham',
        'class': '11-D',
        'role': 'super_admin',
        'house': 'Ruby',
        'scholar_no': '',
      },
      {
        'slot_id': 'emerald_captain',
        'title': 'Emerald House Captain',
        'name': 'Noaman Nizamuddin',
        'class': '11-E',
        'role': 'captain',
        'house': 'Emerald',
        'scholar_no': '',
      },
      {
        'slot_id': 'head_boy',
        'title': 'School Head Boy',
        'name': 'Tanish Mukherjee',
        'class': '12-E',
        'role': 'council',
        'house': 'All',
        'scholar_no': '',
      },
      {
        'slot_id': 'head_girl',
        'title': 'School Head Girl',
        'name': 'Ann Binu',
        'class': '12',
        'role': 'council',
        'house': 'All',
        'scholar_no': '',
      },
      {
        'slot_id': 'deputy_head_boy',
        'title': 'Deputy Head Boy',
        'name': 'Saakshat Guhan',
        'class': '11-E',
        'role': 'council',
        'house': 'All',
        'scholar_no': '',
      },
      {
        'slot_id': 'deputy_head_girl',
        'title': 'Deputy Head Girl',
        'name': 'Nayla Muhammad',
        'class': '11-A',
        'role': 'council',
        'house': 'All',
        'scholar_no': '',
      },
      {
        'slot_id': 'g11_prefect_boy',
        'title': 'Grade 11 Prefect Boy',
        'name': 'Galwin Britto',
        'class': '11-E',
        'role': 'prefect',
        'house': 'All',
        'scholar_no': '',
      },
      {
        'slot_id': 'g11_prefect_girl',
        'title': 'Grade 11 Prefect Girl',
        'name': 'Sarah Paul',
        'class': '11-D',
        'role': 'prefect',
        'house': 'All',
        'scholar_no': '',
      },
      {
        'slot_id': 'cultural_sec_1',
        'title': 'Cultural Secretary Slot 1',
        'name': 'Vacant Slot',
        'class': '',
        'role': 'council',
        'house': 'All',
        'scholar_no': '',
      },
      {
        'slot_id': 'cultural_sec_2',
        'title': 'Cultural Secretary Slot 2',
        'name': 'Vacant Slot',
        'class': '',
        'role': 'council',
        'house': 'All',
        'scholar_no': '',
      },
      {
        'slot_id': 'cultural_sec_3',
        'title': 'Cultural Secretary Slot 3',
        'name': 'Vacant Slot',
        'class': '',
        'role': 'council',
        'house': 'All',
        'scholar_no': '',
      },
      {
        'slot_id': 'sports_captain',
        'title': 'Sports Captain',
        'name': 'Vacant Slot',
        'class': '',
        'role': 'captain',
        'house': 'All',
        'scholar_no': '',
      },
      {
        'slot_id': 'sports_vice_captain',
        'title': 'Sports Vice Captain',
        'name': 'Vacant Slot',
        'class': '',
        'role': 'captain',
        'house': 'All',
        'scholar_no': '',
      },
    ];

    for (int grade = 6; grade <= 12; grade++) {
      roster.add({
        'slot_id': 'g${grade}_prefect_1',
        'title': 'Grade $grade Prefect Slot 1',
        'name': 'Vacant Slot',
        'class': 'Grade $grade',
        'role': 'prefect',
        'house': 'All',
        'scholar_no': '',
      });
      roster.add({
        'slot_id': 'g${grade}_prefect_2',
        'title': 'Grade $grade Prefect Slot 2',
        'name': 'Vacant Slot',
        'class': 'Grade $grade',
        'role': 'prefect',
        'house': 'All',
        'scholar_no': '',
      });
    }

    final batch = _firestore.batch();
    for (final item in roster) {
      final docRef = _firestore
          .collection('admin_roster')
          .doc(item['slot_id']!);
      batch.set(docRef, item, SetOptions(merge: true));
    }
    await batch.commit();
  }
}
