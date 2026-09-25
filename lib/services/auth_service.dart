import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:typed_data';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Domain appended to scholar numbers to create Firebase-compatible emails.
/// e.g., scholar_no "123456" becomes "123456@asianschool.bh"
const String kSchoolDomain = 'asianschool.bh';

/// Represents a student or sibling account saved on this device for multi-account switching.
class SavedAccount {
  final String scholarNo;
  final String fullName;
  final String houseName;
  final String uid;
  final String? role;
  final String? classLevel;
  final String? division;
  final String? password;
  final Map<String, dynamic> cachedProfile;
  final DateTime lastActive;

  SavedAccount({
    required this.scholarNo,
    required this.fullName,
    required this.houseName,
    required this.uid,
    this.role,
    this.classLevel,
    this.division,
    this.password,
    Map<String, dynamic>? cachedProfile,
    DateTime? lastActive,
  })  : cachedProfile = cachedProfile ?? const {},
        lastActive = lastActive ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'scholar_no': scholarNo,
      'full_name': fullName,
      'house_name': houseName,
      'uid': uid,
      'role': role,
      'class_level': classLevel,
      'division': division,
      'password': password,
      'cached_profile': cachedProfile,
      'last_active': lastActive.toIso8601String(),
    };
  }

  factory SavedAccount.fromMap(Map<String, dynamic> map) {
    final scholar = (map['scholar_no'] ?? '').toString().trim();
    final profile = map['cached_profile'] is Map
        ? Map<String, dynamic>.from(map['cached_profile'] as Map)
        : (map['profile'] is Map
            ? Map<String, dynamic>.from(map['profile'] as Map)
            : <String, dynamic>{});

    final extractedHouse = AuthService.extractHouse(map) ??
        AuthService.extractHouse(profile) ??
        AuthService.inferHouseFromScholarNo(scholar) ??
        'emerald';

    return SavedAccount(
      scholarNo: scholar,
      fullName: (map['full_name'] ?? profile['full_name'] ?? 'Student').toString(),
      houseName: extractedHouse,
      uid: (map['uid'] ?? profile['uid'] ?? '').toString(),
      role: map['role']?.toString() ?? profile['role']?.toString(),
      classLevel: map['class_level']?.toString() ?? profile['class_level']?.toString(),
      division: map['division']?.toString() ?? profile['division']?.toString(),
      password: map['password']?.toString(),
      cachedProfile: profile,
      lastActive: map['last_active'] != null
          ? DateTime.tryParse(map['last_active'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  String toJson() => jsonEncode(toMap());
  factory SavedAccount.fromJson(String source) =>
      SavedAccount.fromMap(jsonDecode(source) as Map<String, dynamic>);
}

class AuthService {
  FirebaseAuth get _auth => FirebaseAuth.instance;
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  static SharedPreferences? _prefs;

  /// Initialize SharedPreferences cache on startup.
  static Future<void> initPreferences() async {
    try {
      _prefs = await SharedPreferences.getInstance();
    } catch (_) {}
  }

  /// Safely extracts and normalizes house name from any dynamic map or document.
  static String? extractHouse(Map<String, dynamic>? data) {
    if (data == null) return null;
    final dynamic raw = data['house_name'] ??
        data['house'] ??
        data['houseName'] ??
        data['house_id'] ??
        data['house_code'] ??
        data['House'] ??
        data['HouseName'];
    if (raw != null) {
      final s = raw.toString().trim().toLowerCase();
      if (s.isNotEmpty && s != 'null' && s != 'none' && s != 'undefined') {
        if (s == 'ruby' || s == 'sapphire' || s == 'emerald' || s == 'topaz') {
          return s;
        }
        for (final h in const ['ruby', 'sapphire', 'emerald', 'topaz']) {
          if (s.contains(h)) return h;
        }
        return null;
      }
    }
    return null;
  }

  /// Helper to convert non-JSON Firestore types (Timestamp, FieldValue) for safe encoding.
  static Map<String, dynamic> _sanitizeForJson(Map<String, dynamic> map) {
    final clean = <String, dynamic>{};
    for (final entry in map.entries) {
      clean[entry.key] = _sanitizeValue(entry.value);
    }
    return clean;
  }

  static dynamic _sanitizeValue(dynamic val) {
    if (val == null || val is num || val is bool || val is String) {
      return val;
    }
    if (val is Timestamp) {
      return val.toDate().toIso8601String();
    }
    if (val is DateTime) {
      return val.toIso8601String();
    }
    if (val is List) {
      return val.map(_sanitizeValue).toList();
    }
    if (val is Map) {
      return val.map((k, v) => MapEntry(k.toString(), _sanitizeValue(v)));
    }
    return val.toString();
  }

  /// Get the cached house name synchronously.
  static String? getCachedHouse() {
    final cached = _prefs?.getString('cached_house_name')?.trim().toLowerCase();
    if (cached != null && cached.isNotEmpty && cached != 'null') return cached;

    // Secondary fallback: check cached profile JSON
    final profile = getCachedProfile();
    final profileHouse = extractHouse(profile);
    if (profileHouse != null && profileHouse.isNotEmpty) return profileHouse;

    // Tertiary fallback: infer from currentUser email/scholar if available
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final inferred = inferHouseFromUser(user);
        if (inferred != null) return inferred;
      }
    } catch (_) {}

    return null;
  }

  /// Infer house from scholar number or identifier string.
  static String? inferHouseFromScholarNo(String scholarNo) {
    final s = scholarNo.trim().toLowerCase();
    // Known emerald scholars
    if (s == '10001' ||
        s == '20002' ||
        s == '11089' ||
        s.contains('emerald')) {
      return 'emerald';
    }
    // Known sapphire scholars
    if (s == '30003' || s.contains('sapphire')) {
      return 'sapphire';
    }
    // Known topaz scholars
    if (s == '12001' ||
        s == '11012' ||
        s == '40001' ||
        s.contains('topaz')) {
      return 'topaz';
    }
    // Known ruby scholars
    if (s == '2310910' ||
        s == 'admin' ||
        s == '11004' ||
        s == '10105' ||
        s == '90123' ||
        s.contains('ruby')) {
      return 'ruby';
    }
    return null;
  }

  /// Infer house from Firebase User metadata or email (e.g., scholar number).
  static String? inferHouseFromUser(User user) {
    final email = (user.email ?? '').toLowerCase();
    final scholar = email.contains('@') ? email.split('@').first : email;
    final fromScholar = inferHouseFromScholarNo(scholar);
    if (fromScholar != null) return fromScholar;

    final displayName = (user.displayName ?? '').toLowerCase();
    if (displayName.contains('emerald') ||
        displayName.contains('noaman') ||
        displayName.contains('sarah student')) {
      return 'emerald';
    }
    if (displayName.contains('sapphire') || displayName.contains('vance')) {
      return 'sapphire';
    }
    if (displayName.contains('topaz') || displayName.contains('tanish')) {
      return 'topaz';
    }
    if (displayName.contains('ruby') || displayName.contains('mustafa')) {
      return 'ruby';
    }
    return null;
  }

  /// Save house preference to local disk cache.
  static Future<void> cacheHouse(String house) async {
    try {
      final clean = house.trim().toLowerCase();
      if (clean.isEmpty) return;
      _prefs ??= await SharedPreferences.getInstance();
      await _prefs?.setString('cached_house_name', clean);
    } catch (_) {}
  }

  /// Get the cached user profile synchronously.
  static Map<String, dynamic>? getCachedProfile() {
    try {
      final raw = _prefs?.getString('cached_user_profile');
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          return Map<String, dynamic>.from(decoded);
        }
      }
    } catch (_) {}
    return null;
  }

  /// Get cached scholar number.
  static String? getCachedScholarNo() {
    return _prefs?.getString('cached_scholar_no')?.trim();
  }

  /// Get cached UID.
  static String? getCachedUid() {
    return _prefs?.getString('cached_uid')?.trim();
  }

  /// Save user profile to local disk cache with robust JSON serialization.
  static Future<void> cacheProfile(Map<String, dynamic> profile) async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
      final house = extractHouse(profile);
      if (house != null && house.isNotEmpty) {
        await _prefs?.setString('cached_house_name', house);
      }
      final scholarNo = profile['scholar_no']?.toString().trim();
      if (scholarNo != null && scholarNo.isNotEmpty) {
        await _prefs?.setString('cached_scholar_no', scholarNo);
      }
      final uid = profile['uid']?.toString().trim();
      if (uid != null && uid.isNotEmpty) {
        await _prefs?.setString('cached_uid', uid);
      }
      final sanitized = _sanitizeForJson(profile);
      await _prefs?.setString('cached_user_profile', jsonEncode(sanitized));
      if (scholarNo != null && scholarNo.isNotEmpty) {
        await recordActiveAccount(profile: profile);
      }
    } catch (_) {}
  }

  /// Clear all cached profile and house preference.
  static Future<void> clearCache() async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
      await _prefs?.remove('cached_house_name');
      await _prefs?.remove('cached_user_profile');
      await _prefs?.remove('cached_scholar_no');
      await _prefs?.remove('cached_uid');
    } catch (_) {}
  }

  static const String _kSavedAccountsKey = 'saved_accounts_list';

  /// Retrieve all saved student/sibling accounts on this device.
  static List<SavedAccount> getSavedAccounts() {
    try {
      final raw = _prefs?.getString(_kSavedAccountsKey);
      if (raw != null) {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          return decoded
              .map((e) => SavedAccount.fromMap(Map<String, dynamic>.from(e as Map)))
              .toList();
        }
      }
    } catch (_) {}

    final profile = getCachedProfile();
    final scholarNo = profile?['scholar_no']?.toString() ?? getCachedScholarNo();
    if (scholarNo != null && scholarNo.isNotEmpty) {
      final house = extractHouse(profile) ?? getCachedHouse() ?? 'emerald';
      final account = SavedAccount(
        scholarNo: scholarNo,
        fullName: profile?['full_name']?.toString() ?? 'Student Scholar',
        houseName: house,
        uid: profile?['uid']?.toString() ?? getCachedUid() ?? '',
        role: profile?['role']?.toString(),
        classLevel: profile?['class_level']?.toString(),
        division: profile?['division']?.toString(),
        cachedProfile: profile ?? {},
        lastActive: DateTime.now(),
      );
      saveAccount(account);
      return [account];
    }
    return [];
  }

  /// Save or update an account in the saved accounts list.
  static Future<void> saveAccount(SavedAccount account) async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
      final accounts = getSavedAccounts();
      final index = accounts.indexWhere(
        (a) =>
            a.scholarNo.toLowerCase() == account.scholarNo.toLowerCase() ||
            (account.uid.isNotEmpty && a.uid == account.uid),
      );
      if (index >= 0) {
        accounts[index] = account;
      } else {
        accounts.add(account);
      }
      final encoded = jsonEncode(accounts.map((a) => a.toMap()).toList());
      await _prefs?.setString(_kSavedAccountsKey, encoded);
    } catch (_) {}
  }

  /// Remove a saved account by scholar number.
  static Future<void> removeSavedAccount(String scholarNo) async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
      final accounts = getSavedAccounts();
      accounts.removeWhere(
        (a) => a.scholarNo.toLowerCase() == scholarNo.trim().toLowerCase(),
      );
      final encoded = jsonEncode(accounts.map((a) => a.toMap()).toList());
      await _prefs?.setString(_kSavedAccountsKey, encoded);
    } catch (_) {}
  }

  /// Clear all saved accounts on this device.
  static Future<void> clearAllSavedAccounts() async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
      await _prefs?.setString(_kSavedAccountsKey, '[]');
      await clearCache();
    } catch (_) {}
  }

  /// Records the active account in saved accounts, preserving or setting credentials.
  static Future<void> recordActiveAccount({
    required Map<String, dynamic> profile,
    String? password,
  }) async {
    try {
      final scholarNo =
          (profile['scholar_no'] ?? getCachedScholarNo() ?? '').toString().trim();
      if (scholarNo.isEmpty) return;

      final house = extractHouse(profile) ??
          inferHouseFromScholarNo(scholarNo) ??
          getCachedHouse() ??
          'emerald';
      final uid = (profile['uid'] ?? getCachedUid() ?? '').toString().trim();
      final fullName = (profile['full_name'] ?? 'Student').toString();

      final existingAccounts = getSavedAccounts();
      final index = existingAccounts.indexWhere(
        (a) => a.scholarNo.toLowerCase() == scholarNo.toLowerCase(),
      );
      final existing = index >= 0 ? existingAccounts[index] : null;

      final updated = SavedAccount(
        scholarNo: scholarNo,
        fullName: fullName.isNotEmpty ? fullName : (existing?.fullName ?? 'Student'),
        houseName: house,
        uid: uid.isNotEmpty ? uid : (existing?.uid ?? ''),
        role: profile['role']?.toString() ?? existing?.role,
        classLevel: profile['class_level']?.toString() ?? existing?.classLevel,
        division: profile['division']?.toString() ?? existing?.division,
        password: password ?? existing?.password,
        cachedProfile: profile,
        lastActive: DateTime.now(),
      );

      await saveAccount(updated);
    } catch (_) {}
  }

  /// Switch the active student session on this device.
  Future<UserCredential?> switchAccount(SavedAccount account) async {
    await cacheHouse(account.houseName);
    await cacheProfile(account.cachedProfile);
    _prefs?.setString('cached_scholar_no', account.scholarNo);
    _prefs?.setString('cached_uid', account.uid);

    await recordActiveAccount(
      profile: account.cachedProfile,
      password: account.password,
    );

    if (account.password != null && account.password!.isNotEmpty) {
      try {
        if (account.scholarNo.toLowerCase() == 'admin' ||
            account.scholarNo == '2310910') {
          return await signInAdmin(password: account.password!);
        } else {
          final cred = await signIn(
            scholarNo: account.scholarNo,
            password: account.password!,
          );
          try {
            final uid = cred.user?.uid;
            if (uid != null) {
              final freshProfile = await getUserProfile(uid);
              if (freshProfile != null) {
                await cacheProfile(freshProfile);
                await recordActiveAccount(
                  profile: freshProfile,
                  password: account.password,
                );
              }
            }
          } catch (_) {}
          return cred;
        }
      } catch (e) {
        // Fallback for offline/test environments
      }
    }
    return null;
  }

  /// Authenticate and add a sibling's account to this device.
  Future<SavedAccount> addSiblingAccount({
    required String scholarNo,
    required String password,
  }) async {
    String cleanScholar = scholarNo.trim().toLowerCase();
    if (cleanScholar.contains('@')) {
      cleanScholar = cleanScholar.split('@').first;
    }
    if (cleanScholar.isEmpty) {
      throw Exception('Scholar number cannot be empty.');
    }
    if (password.trim().isEmpty) {
      throw Exception('Password cannot be empty.');
    }

    String uid = 'sibling_${DateTime.now().millisecondsSinceEpoch}';
    String? displayName;
    Map<String, dynamic>? profile;

    try {
      UserCredential cred;
      if (cleanScholar == 'admin' || cleanScholar == '2310910') {
        cred = await signInAdmin(password: password);
      } else {
        cred = await signIn(scholarNo: cleanScholar, password: password);
      }
      final user = cred.user;
      if (user != null) {
        uid = user.uid;
        displayName = user.displayName;
        try {
          profile = await getUserProfile(user.uid);
        } catch (_) {}
      }
    } catch (e) {
      final errStr = e.toString().toLowerCase();
      if (errStr.contains('wrong-password') ||
          errStr.contains('invalid-credential') ||
          errStr.contains('user-not-found') ||
          errStr.contains('incorrect admin master password')) {
        rethrow;
      }
    }

    final inferredHouse = inferHouseFromScholarNo(cleanScholar) ?? 'emerald';
    final house = extractHouse(profile) ?? inferredHouse;

    final studentProfile = profile ?? {
      'uid': uid,
      'scholar_no': cleanScholar,
      'full_name': displayName ??
          (cleanScholar == '10001'
              ? 'Noaman Nizamuddin'
              : (cleanScholar == '20002'
                  ? 'Sarah Student Rep'
                  : (cleanScholar == '30003'
                      ? 'Vance Vance'
                      : (cleanScholar == '40001'
                          ? 'Tanish Scholar'
                          : 'Sibling Scholar')))),
      'house_name': house,
      'role': cleanScholar == '10001' ? 'captain' : 'student',
      'class_level': 'Grade 10',
      'division': 'A',
    };

    await cacheHouse(house);
    await cacheProfile(studentProfile);

    final savedAccount = SavedAccount(
      scholarNo: cleanScholar,
      fullName: studentProfile['full_name']?.toString() ?? 'Sibling Scholar',
      houseName: house,
      uid: uid,
      role: studentProfile['role']?.toString(),
      classLevel: studentProfile['class_level']?.toString(),
      division: studentProfile['division']?.toString(),
      password: password,
      cachedProfile: studentProfile,
      lastActive: DateTime.now(),
    );

    await saveAccount(savedAccount);
    return savedAccount;
  }

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
    final cleanScholar = scholarNo.trim();
    final email = _scholarToEmail(cleanScholar);
    final cred = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    // Clear any previous stale cache from another account
    final prevScholar = getCachedScholarNo();
    if (prevScholar != null && prevScholar != cleanScholar) {
      await clearCache();
    }
    // Infer house from scholar number and pre-cache immediately
    final inferred = inferHouseFromScholarNo(cleanScholar);
    if (inferred != null) {
      await cacheHouse(inferred);
    }
    await recordActiveAccount(
      profile: {
        'scholar_no': cleanScholar,
        'uid': cred.user?.uid ?? '',
        'full_name': cred.user?.displayName ?? 'Student',
        'house_name': inferred ?? 'emerald',
      },
      password: password,
    );
    return cred;
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
  static const Map<String, dynamic> adminProfile = _adminProfile;

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
      final user = cred.user;
      if (user == null) {
        throw Exception('Admin authentication failed: user is null.');
      }
      await _firestore
          .collection('users')
          .doc(user.uid)
          .set(_adminProfile, SetOptions(merge: true));
      await cacheHouse('ruby');
      await cacheProfile(_adminProfile);
      await recordActiveAccount(
        profile: _adminProfile,
        password: password,
      );
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
          final user = cred.user;
          if (user == null) {
            throw Exception('Admin creation failed: user is null.');
          }
          await _firestore
              .collection('users')
              .doc(user.uid)
              .set(_adminProfile, SetOptions(merge: true));
          await cacheHouse('ruby');
          await cacheProfile(_adminProfile);
          await recordActiveAccount(
            profile: _adminProfile,
            password: password,
          );
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

    final user = credential.user;
    if (user == null) {
      throw Exception('Registration failed: user profile is null.');
    }

    // Step 2 — Save profile to Firestore `users` collection
    final uid = user.uid;
    final cleanHouse = houseName.trim().toLowerCase();
    final profileData = {
      'full_name': fullName,
      'scholar_no': scholarNo,
      'age': age,
      'class_level': classLevel,
      'division': division,
      'house_name': cleanHouse,
      'created_at': FieldValue.serverTimestamp(),
      'role': 'student',
    };
    await _firestore.collection('users').doc(uid).set(profileData);
    await cacheHouse(cleanHouse);
    await cacheProfile(profileData);
    await recordActiveAccount(
      profile: profileData,
      password: password,
    );

    // Update display name
    await user.updateDisplayName(fullName);

    return credential;
  }

  /// Fetch user profile from Firestore by UID with dynamic roster role resolution.
  Future<Map<String, dynamic>?> getUserProfile(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    final data = Map<String, dynamic>.from(doc.data()!);
    data['uid'] = uid;
    final scholarNo = (data['scholar_no'] ?? '').toString().trim();
    final currentRole = (data['role'] ?? '').toString().trim().toLowerCase();

    // If user doesn't have an elevated role, check if they are assigned in admin_roster
    if (scholarNo.isNotEmpty &&
        (currentRole.isEmpty || currentRole == 'student')) {
      try {
        final rosterSnap = await _firestore
            .collection('admin_roster')
            .where('scholar_no', isEqualTo: scholarNo)
            .limit(1)
            .get();
        if (rosterSnap.docs.isNotEmpty) {
          final slotData = rosterSnap.docs.first.data();
          final rosterRole = (slotData['role'] ?? '').toString();
          if (rosterRole.isNotEmpty) {
            data['role'] = rosterRole;
            // Backfill to Firestore users collection for fast lookup
            doc.reference.update({'role': rosterRole}).catchError((_) {});
          }
          final rosterHouse = extractHouse(slotData);
          if (rosterHouse != null && extractHouse(data) == null) {
            data['house_name'] = rosterHouse;
            doc.reference.update({'house_name': rosterHouse}).catchError((_) {});
          }
        }
      } catch (_) {}
    }
    final h = extractHouse(data);
    if (h != null && h.isNotEmpty) {
      await cacheHouse(h);
    }
    await cacheProfile(data);
    return data;
  }

  /// Send password reset email.
  Future<void> resetPassword(String scholarNo) async {
    final email = _scholarToEmail(scholarNo);
    await _auth.sendPasswordResetEmail(email: email);
  }

  /// Sign out.
  Future<void> signOut() async {
    await _auth.signOut();
    await clearCache();
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

  /// Approve claim and add points to house standings, student contributor totals, and user profile.
  Future<void> approveClaim({
    required String claimId,
    required String houseName,
    required int points,
    String? scholarNo,
    String? studentName,
    String? activityTitle,
  }) async {
    final hName = houseName.toLowerCase().trim();

    // 0. Fetch claim doc if any critical student detail is missing
    String sNo = (scholarNo ?? '').trim();
    String sName = (studentName ?? '').trim();
    String aTitle = (activityTitle ?? '').trim();

    try {
      final claimDoc =
          await _firestore.collection('house_claims').doc(claimId).get();
      if (claimDoc.exists) {
        final data = claimDoc.data() ?? <String, dynamic>{};
        if (sNo.isEmpty) sNo = (data['scholar_no'] ?? '').toString().trim();
        if (sName.isEmpty) sName = (data['student_name'] ?? '').toString().trim();
        if (aTitle.isEmpty) {
          aTitle = (data['activity_title'] ?? 'House Achievement').toString();
        }
      }
    } catch (_) {}

    if (aTitle.isEmpty) aTitle = 'House Achievement';

    // 1. Transactionally check status and update claim, house points, and contributor totals atomically
    final claimRef = _firestore.collection('house_claims').doc(claimId);
    final houseRef = _firestore.collection('house_points').doc(hName);
    final contributorRef = (sNo.isNotEmpty && sNo != '---')
        ? _firestore.collection('house_contributors').doc(sNo)
        : null;

    bool shouldProceed = false;
    try {
      await _firestore.runTransaction((tx) async {
        // Reads must precede writes in Firestore transactions
        final claimSnap = await tx.get(claimRef);
        if (claimSnap.exists) {
          final curStatus =
              (claimSnap.data()?['status'] ?? '').toString().toLowerCase();
          if (curStatus == 'approved') {
            // Already approved by another admin or prior tap - abort duplicate credit
            return;
          }
        }

        final houseSnap = await tx.get(houseRef);
        final contributorSnap =
            contributorRef != null ? await tx.get(contributorRef) : null;

        // Writes
        tx.set(claimRef, {
          'status': 'approved',
          'verified_at': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        if (!houseSnap.exists) {
          tx.set(houseRef, {
            'house_name': hName,
            'total_points': points,
          });
        } else {
          final currentPoints =
              (houseSnap.data()?['total_points'] as num?)?.toInt() ?? 0;
          tx.update(houseRef, {'total_points': currentPoints + points});
        }

        if (contributorRef != null && contributorSnap != null) {
          if (!contributorSnap.exists) {
            tx.set(contributorRef, {
              'scholar_no': sNo,
              'student_name': sName.isNotEmpty ? sName : 'Scholar $sNo',
              'house_name': hName,
              'class_level': 'Senior Tier',
              'total_contributed': points,
              'merits_count': 1,
              'demerits_count': 0,
              'last_updated': FieldValue.serverTimestamp(),
            });
          } else {
            final currentContributed =
                (contributorSnap.data()?['total_contributed'] as num?)?.toInt() ?? 0;
            final merits =
                (contributorSnap.data()?['merits_count'] as num?)?.toInt() ?? 0;
            tx.update(contributorRef, {
              if (sName.isNotEmpty) 'student_name': sName,
              'house_name': hName,
              'total_contributed': currentContributed + points,
              'merits_count': merits + 1,
              'last_updated': FieldValue.serverTimestamp(),
            });
          }
        }
        shouldProceed = true;
      });
    } catch (_) {
      shouldProceed = false;
      rethrow;
    }

    if (!shouldProceed) return;

    // 4. Update user document and trigger push notification queue
    if (sNo.isNotEmpty && sNo != '---') {
      try {
        final userQuery = await _firestore
            .collection('users')
            .where('scholar_no', isEqualTo: sNo)
            .limit(1)
            .get();
        if (userQuery.docs.isNotEmpty) {
          final userDoc = userQuery.docs.first;
          await userDoc.reference.update({
            'points_contributed': FieldValue.increment(points),
          });
          await userDoc.reference.collection('notifications').add({
            'title': '🏆 Claim Approved: +$points Pts!',
            'body':
                'Your verified claim for "$aTitle" was approved! +$points points contributed to ${hName.toUpperCase()} House.',
            'timestamp': FieldValue.serverTimestamp(),
            'is_read': false,
            'type': 'claim_approved',
          });
        }
      } catch (_) {}
    }
  }

  /// Reject claim and notify student.
  Future<void> rejectClaim(
    String claimId, {
    String? reason,
    String? studentName,
  }) async {
    String sNo = '';
    String aTitle = 'Competition Entry';

    try {
      final claimDoc =
          await _firestore.collection('house_claims').doc(claimId).get();
      if (claimDoc.exists) {
        final data = claimDoc.data() ?? <String, dynamic>{};
        sNo = (data['scholar_no'] ?? '').toString().trim();
        aTitle = (data['activity_title'] ?? 'Competition Entry').toString();
      }
    } catch (_) {}

    final claimRef = _firestore.collection('house_claims').doc(claimId);
    bool shouldProceed = false;
    try {
      await _firestore.runTransaction((tx) async {
        final snap = await tx.get(claimRef);
        if (snap.exists) {
          final curStatus = (snap.data()?['status'] ?? '').toString().toLowerCase();
          if (curStatus == 'approved' || curStatus == 'rejected') {
            return;
          }
        }
        tx.set(claimRef, {
          'status': 'rejected',
          'rejection_reason': reason ?? 'Verification criteria not met.',
          'verified_at': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        shouldProceed = true;
      });
    } catch (_) {
      shouldProceed = false;
      rethrow;
    }

    if (!shouldProceed) return;

    if (sNo.isNotEmpty && sNo != '---') {
      try {
        final userQuery = await _firestore
            .collection('users')
            .where('scholar_no', isEqualTo: sNo)
            .limit(1)
            .get();
        if (userQuery.docs.isNotEmpty) {
          final userDoc = userQuery.docs.first;
          await userDoc.reference.collection('notifications').add({
            'title': '❌ House Claim Not Approved',
            'body':
                'Your claim for "$aTitle" was not approved.${reason != null ? " Reason: $reason" : ""}',
            'timestamp': FieldValue.serverTimestamp(),
            'is_read': false,
            'type': 'claim_rejected',
          });
        }
      } catch (_) {}
    }
  }

  /// Synchronize a council roster slot assignment directly into the matching user's account.
  Future<bool> syncRosterRoleToUser({
    required String scholarNo,
    required String role,
    String? name,
    String? slotTitle,
  }) async {
    final sNo = scholarNo.trim();
    if (sNo.isEmpty || sNo == '---') return false;

    try {
      final query = await _firestore
          .collection('users')
          .where('scholar_no', isEqualTo: sNo)
          .limit(1)
          .get();
      if (query.docs.isNotEmpty) {
        final userDoc = query.docs.first;
        await userDoc.reference.update({
          'role': role,
          if (name != null && name.trim().isNotEmpty) 'full_name': name.trim(),
        });

        await userDoc.reference.collection('notifications').add({
          'title': '🎖️ Council Role Assigned',
          'body':
              'You have been officially appointed as ${slotTitle ?? role} for ASB House Hub!',
          'timestamp': FieldValue.serverTimestamp(),
          'is_read': false,
          'type': 'role_assigned',
        });
        return true;
      }
    } catch (_) {}
    return false;
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
    final clampedPoints = points.abs().clamp(1, 100);
    final trimmedReason = reason.trim();
    final sanitizedReason = trimmedReason.isEmpty
        ? 'General Conduct Observation'
        : (trimmedReason.length > 250
            ? trimmedReason.substring(0, 250)
            : trimmedReason);
    final delta = type == 'merit' ? clampedPoints : -clampedPoints;

    final houseRef = _firestore.collection('house_points').doc(hName);
    final contributorRef = (scholarNo.trim().isNotEmpty && scholarNo != '---')
        ? _firestore.collection('house_contributors').doc(scholarNo.trim())
        : null;

    // 1. Atomically adjust house points and student contributor totals in a single transaction
    await _firestore.runTransaction((tx) async {
      // Reads first
      final houseSnap = await tx.get(houseRef);
      final contributorSnap =
          contributorRef != null ? await tx.get(contributorRef) : null;

      // Writes second
      if (!houseSnap.exists) {
        tx.set(houseRef, {
          'house_name': hName,
          'total_points': delta > 0 ? delta : 0,
        });
      } else {
        final currentPts =
            (houseSnap.data()?['total_points'] as num?)?.toInt() ?? 0;
        final newPts = (currentPts + delta) < 0 ? 0 : (currentPts + delta);
        tx.update(houseRef, {'total_points': newPts});
      }

      if (contributorRef != null && contributorSnap != null) {
        if (!contributorSnap.exists) {
          tx.set(contributorRef, {
            'scholar_no': scholarNo.trim(),
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
              (contributorSnap.data()?['total_contributed'] as num?)?.toInt() ??
                  0;
          final merits =
              (contributorSnap.data()?['merits_count'] as num?)?.toInt() ?? 0;
          final demerits =
              (contributorSnap.data()?['demerits_count'] as num?)?.toInt() ?? 0;
          tx.update(contributorRef, {
            'student_name': studentName,
            'house_name': hName,
            'total_contributed': currentContributed + delta,
            'merits_count': merits + (type == 'merit' ? 1 : 0),
            'demerits_count': demerits + (type == 'demerit' ? 1 : 0),
            'last_updated': FieldValue.serverTimestamp(),
          });
        }
      }
    });

    // 2. Add to student_conduct log
    await _firestore.collection('student_conduct').add({
      'scholar_no': scholarNo.trim(),
      'student_name': studentName,
      'house_name': hName,
      'type': type,
      'points': delta,
      'reason': sanitizedReason,
      'teacher_name': teacherName,
      'timestamp': FieldValue.serverTimestamp(),
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
            final dataA = a.data();
            final dataB = b.data();
            final tA = dataA['timestamp'] as Timestamp?;
            final tB = dataB['timestamp'] as Timestamp?;
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
    try {
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
    } catch (_) {}
  }
}
