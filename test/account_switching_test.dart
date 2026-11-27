import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:asb_house_hub/services/auth_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AuthService.clearCache();
  });

  group('Account Switching Security & Behavior', () {
    test('SavedAccount zero-disk persistence: toMap sets password to null', () {
      final original = SavedAccount(
        scholarNo: '12428',
        fullName: 'Jane Doe',
        houseName: 'sapphire',
        uid: 'uid_jane_12428',
        role: 'student',
        password: 'TemporaryMemoryPassword123!',
        cachedProfile: {
          'scholar_no': '12428',
          'full_name': 'Jane Doe',
          'house_name': 'sapphire',
          'role': 'student',
        },
      );

      final map = original.toMap();
      expect(map['password'], isNull, reason: 'Zero password persistence on disk');

      final restored = SavedAccount.fromMap(map);
      expect(restored.scholarNo, equals('12428'));
      expect(restored.password, isNull);
    });

    test('switchAccount succeeds without password and updates active session seamlessly', () async {
      final accountA = SavedAccount(
        scholarNo: '11209',
        fullName: 'Mustafa Hisham',
        houseName: 'ruby',
        uid: 'uid_mustafa_11209',
        role: 'student',
        password: null, // Zero persistence - password is null on disk load
        cachedProfile: {
          'scholar_no': '11209',
          'full_name': 'Mustafa Hisham',
          'house_name': 'ruby',
          'role': 'student',
        },
      );

      final accountB = SavedAccount(
        scholarNo: '13500',
        fullName: 'Sibling Scholar',
        houseName: 'emerald',
        uid: 'uid_sibling_13500',
        role: 'student',
        password: null, // Password omitted on switch
        cachedProfile: {
          'scholar_no': '13500',
          'full_name': 'Sibling Scholar',
          'house_name': 'emerald',
          'role': 'student',
        },
      );

      await AuthService().switchAccount(accountA);
      expect(AuthService.getCachedScholarNo(), equals('11209'));
      expect(AuthService.getCachedHouse(), equals('ruby'));
      expect(AuthService.getCachedUid(), equals('uid_mustafa_11209'));

      // Switch to accountB without password must succeed immediately without throwing
      await AuthService().switchAccount(accountB);
      expect(AuthService.getCachedScholarNo(), equals('13500'));
      expect(AuthService.getCachedHouse(), equals('emerald'));
      expect(AuthService.getCachedUid(), equals('uid_sibling_13500'));
      expect(AuthService.getCachedProfile()?['full_name'], equals('Sibling Scholar'));
    });

    test('switchAccount preserves administrator roles and ruby house for admin', () async {
      final adminAccount = SavedAccount(
        scholarNo: 'admin',
        fullName: 'School Admin',
        houseName: 'ruby',
        uid: 'admin_uid_root',
        role: 'super_admin',
        cachedProfile: {
          'scholar_no': 'admin',
          'role': 'super_admin',
        },
      );

      await AuthService().switchAccount(adminAccount);
      expect(AuthService.getCachedScholarNo(), equals('admin'));
      expect(AuthService.getCachedHouse(), equals('ruby'));
      expect(AuthService.getCachedProfile()?['role'], equals('super_admin'));
    });
  });
}
