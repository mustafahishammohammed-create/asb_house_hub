import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:asb_house_hub/main.dart';
import 'package:asb_house_hub/screens/login_screen.dart';
import 'package:asb_house_hub/screens/signup_screen.dart';
import 'package:asb_house_hub/services/auth_service.dart';
import 'package:asb_house_hub/theme/app_theme.dart';

void main() {
  setUpAll(() {
    CredentialVaultService.setTestSecret('TEST_VAULT_SECRET_2026');
  });

  setUp(() async {
    AuthService.authTransitionInProgress.value = false;
    SharedPreferences.setMockInitialValues({});
    await AuthService.initPreferences();
    await AuthService.clearCache();
  });

  tearDown(() {
    AuthService.authTransitionInProgress.value = false;
  });

  group('LoginScreen & Sign-In Fixes', () {
    testWidgets(
      'Theme toggle never overlaps portal tabs on compact 360x640 screen',
      (tester) async {
        tester.view.physicalSize = const Size(360, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: const LoginScreen(),
          ),
        );
        await tester.pumpAndSettle();

        final themeBtnRect = tester.getRect(
          find.byTooltip('Switch to Dark Theme'),
        );
        final studentTabRect = tester.getRect(find.text('Student Login'));
        final adminTabRect = tester.getRect(find.text('Admin Login'));

        expect(themeBtnRect.overlaps(studentTabRect), isFalse);
        expect(themeBtnRect.overlaps(adminTabRect), isFalse);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Switching tabs clears stale validation errors and toggles signup link',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: const LoginScreen(),
          ),
        );
        await tester.pumpAndSettle();

        // Trigger student form validation error
        await tester.ensureVisible(find.text('Sign In'));
        await tester.tap(find.text('Sign In'));
        await tester.pump();
        expect(find.text('Enter your scholar number'), findsOneWidget);
        expect(find.text('Create an account'), findsOneWidget);

        // Switch to Admin Login: stale error cleared, ID prefilled to admin,
        // and self-signup link hidden.
        await tester.ensureVisible(find.text('Admin Login'));
        await tester.tap(find.text('Admin Login'));
        await tester.pumpAndSettle();
        expect(find.text('Enter your scholar number'), findsNothing);
        expect(find.text('Admin Portal.'), findsOneWidget);
        expect(find.text('Create an account'), findsNothing);
        expect(find.text('admin'), findsOneWidget);

        // Trigger password validation error on Admin Login with 11209 ID
        await tester.enterText(find.byType(TextFormField).first, '11209');
        await tester.ensureVisible(find.text('Sign In to Admin Portal'));
        await tester.tap(find.text('Sign In to Admin Portal'));
        await tester.pump();
        expect(find.text('Enter your password'), findsOneWidget);

        // Switch back to Student Login: stale error cleared, admin ID cleared
        await tester.ensureVisible(find.text('Student Login'));
        await tester.tap(find.text('Student Login'));
        await tester.pumpAndSettle();
        expect(find.text('Enter your password'), findsNothing);
        expect(find.text('Welcome back.'), findsOneWidget);
        expect(find.text('Create an account'), findsOneWidget);
        expect(find.text('11209'), findsNothing);
      },
    );

    testWidgets(
      'Forgot password dialog validates empty submission cleanly',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: const LoginScreen(),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Forgot Password?'));
        await tester.pumpAndSettle();
        expect(find.text('Reset Password'), findsOneWidget);

        await tester.tap(find.text('Send Reset Link'));
        await tester.pump();
        expect(
          find.text('Enter your scholar number or email'),
          findsOneWidget,
        );
      },
    );
  });

  group('SignupScreen & Protected Identity Guards', () {
    testWidgets(
      'Blocks self-registration of reserved 11209 scholar number',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: const SignupScreen(),
          ),
        );
        await tester.pumpAndSettle();

        final fields = find.byType(TextFormField);
        await tester.enterText(fields.at(0), 'Test User');
        await tester.enterText(fields.at(1), '11209');
        await tester.tap(find.text('Continue'));
        await tester.pump();

        expect(
          find.text('This scholar number is reserved. Please sign in instead.'),
          findsOneWidget,
        );
        expect(find.text('Student Identity'), findsOneWidget);
      },
    );

    testWidgets(
      'Supports LKG student signup flow through Step 3 summary',
      (tester) async {
        tester.view.physicalSize = const Size(420, 840);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: const SignupScreen(),
          ),
        );
        await tester.pumpAndSettle();

        // Step 0
        final fields = find.byType(TextFormField);
        await tester.enterText(fields.at(0), 'Zoya Khan');
        await tester.enterText(fields.at(1), '25104');
        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();

        // Step 1: LKG + A
        await tester.ensureVisible(find.text('LKG'));
        await tester.tap(find.text('LKG'));
        await tester.pump();
        await tester.ensureVisible(find.text('A'));
        await tester.tap(find.text('A'));
        await tester.pump();
        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();

        // Step 2: Ruby
        await tester.ensureVisible(find.text('Ruby'));
        await tester.tap(find.text('Ruby'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();

        // Step 3 summary shows LKG-A and validates password mismatch
        expect(find.textContaining('Class LKG-A'), findsOneWidget);
        final pwFields = find.byType(TextFormField);
        await tester.enterText(pwFields.at(0), 'StrongPass1!');
        await tester.enterText(pwFields.at(1), 'Mismatch1!');
        await tester.tap(find.text('Complete Registration'));
        await tester.pump();
        expect(find.text('Passwords do not match'), findsOneWidget);
      },
    );

    test('AuthService.signUp rejects all variants of 11209 and admin', () async {
      final auth = AuthService();
      for (final reserved in [
        '11209',
        ' 11209 ',
        '11209@asianschool.bh',
        'admin',
        'ADMIN',
        'admin@asianschool.bh',
      ]) {
        await expectLater(
          auth.signUp(
            scholarNo: reserved,
            password: 'Password123!',
            fullName: 'Test Account',
            age: 14,
            classLevel: 'Grade 10',
            division: 'A',
            houseName: 'ruby',
          ),
          throwsA(
            isA<FirebaseAuthException>().having(
              (e) => e.code,
              'code',
              'operation-not-allowed',
            ),
          ),
        );
      }
    });

    test('ensureSchoolMemberRecord preserves grade 0 for LKG/UKG', () async {
      final auth = AuthService();
      final lkgRecord = await auth.ensureSchoolMemberRecord(
        uid: 'uid_lkg_student',
        profile: {
          'scholar_no': '25104',
          'full_name': 'Zoya Khan',
          'house_name': 'ruby',
          'class_level': 'LKG',
          'grade': 0,
          'role': 'student',
        },
      );
      expect(lkgRecord['grade'], equals(0));

      final ukgRecord = await auth.ensureSchoolMemberRecord(
        uid: 'uid_ukg_student',
        profile: {
          'scholar_no': '25105',
          'full_name': 'Ayan Ali',
          'house_name': 'sapphire',
          'class_level': 'UKG',
          'role': 'student',
        },
      );
      expect(ukgRecord['grade'], equals(0));
    });
  });

  group('AuthGate transition guard', () {
    testWidgets(
      'AuthGate stays on LoginScreen while authTransitionInProgress is true',
      (tester) async {
        await AuthService.setCompletedOnboarding(true);
        AuthService.authTransitionInProgress.value = true;

        await tester.pumpWidget(
          MaterialApp(
            home: AuthGate(authStateStream: Stream.value(null)),
          ),
        );
        await tester.pump();
        expect(find.byType(LoginScreen), findsOneWidget);

        AuthService.authTransitionInProgress.value = false;
        await tester.pump();
        expect(find.byType(LoginScreen), findsOneWidget);
      },
    );
  });
}
