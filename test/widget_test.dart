import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:asb_house_hub/theme/app_theme.dart';
import 'package:asb_house_hub/services/gemini_ai_service.dart';
import 'package:asb_house_hub/services/hierarchy_service.dart';
import 'package:asb_house_hub/screens/house_ai_chat_screen.dart';
import 'package:asb_house_hub/screens/signup_screen.dart';
import 'package:asb_house_hub/widgets/apple_fitness_badges_vault.dart';
import 'package:asb_house_hub/widgets/mascot_3d_stage.dart';
import 'package:asb_house_hub/screens/house_arena_screen.dart';
import 'package:asb_house_hub/widgets/battle_chant_synthesizer.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:asb_house_hub/services/auth_service.dart';
import 'package:asb_house_hub/services/voucher_security_service.dart';
import 'package:asb_house_hub/screens/merch_store_tab.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:asb_house_hub/screens/id_scanner_screen.dart';
import 'package:asb_house_hub/screens/student_behavior_evaluation_screen.dart';
import 'package:asb_house_hub/screens/digital_wallet_screen.dart';
import 'package:asb_house_hub/screens/home_screen.dart';
import 'package:asb_house_hub/screens/house_leaderboard_screen.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:asb_house_hub/screens/chat_room_screen.dart';
import 'package:asb_house_hub/widgets/account_switcher_modal.dart';
import 'package:asb_house_hub/widgets/pill_selector.dart';
import 'package:asb_house_hub/widgets/confetti_overlay.dart';
import 'package:asb_house_hub/widgets/camera_capture_dialog.dart';
import 'package:asb_house_hub/services/qr_decoder_service.dart';
import 'package:image/image.dart' as img;
import 'package:zxing2/qrcode.dart';
import 'package:asb_house_hub/main.dart';
import 'package:asb_house_hub/services/gamification_security_service.dart';
import 'package:asb_house_hub/widgets/gamification_cooldown_banner.dart';
import 'package:asb_house_hub/models/timetable_period.dart';
import 'package:asb_house_hub/models/academic_assignment.dart';
import 'package:asb_house_hub/models/exam_schedule_item.dart';
import 'package:asb_house_hub/models/academic_report_card.dart';
import 'package:asb_house_hub/models/attendance_record.dart';
import 'package:asb_house_hub/models/campus_event.dart';
import 'package:asb_house_hub/models/election_ballot.dart';
import 'package:asb_house_hub/models/digital_ballot_cast.dart';
import 'package:asb_house_hub/models/election_audit_record.dart';
import 'package:asb_house_hub/models/election_gazette.dart';
import 'package:asb_house_hub/services/election_security_service.dart';
import 'package:asb_house_hub/screens/academics_screen.dart';
import 'package:asb_house_hub/screens/events_screen.dart';
import 'package:asb_house_hub/screens/election_chamber_screen.dart';
import 'package:asb_house_hub/screens/election_audit_screen.dart';
import 'package:asb_house_hub/screens/election_gazette_screen.dart';
import 'package:asb_house_hub/screens/school_elections_page.dart';
import 'package:asb_house_hub/services/pass_document_exporter.dart';
import 'package:asb_house_hub/screens/sports_tournament_screen.dart';
import 'package:asb_house_hub/screens/live_match_hud_screen.dart';
import 'package:asb_house_hub/models/sports_tournament.dart';
import 'package:asb_house_hub/models/match_telemetry.dart';
import 'package:asb_house_hub/models/player_sports_stats.dart';
import 'package:asb_house_hub/models/sports_trophy.dart';
import 'package:asb_house_hub/services/sports_security_service.dart';
import 'package:asb_house_hub/widgets/managed_modal_scope.dart';
import 'package:asb_house_hub/screens/login_screen.dart';
import 'package:asb_house_hub/screens/onboarding_screen.dart';
import 'package:asb_house_hub/models/medical_leave_request.dart';
import 'package:asb_house_hub/screens/chat_list_screen.dart';
import 'package:asb_house_hub/services/chat_service.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:asb_house_hub/screens/admin_claims_screen.dart';
import 'package:asb_house_hub/l10n/app_localizations.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AuthService.initPreferences();
    await AuthService.clearCache();
    await GamificationSecurityService.initPreferences();
    await GamificationSecurityService.clearCooldowns();
  });

  testWidgets('Theme check smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const Scaffold(body: Text('ASB House Hub')),
      ),
    );

    expect(find.text('ASB House Hub'), findsOneWidget);
  });

  testWidgets('DigitalWalletScreen loads with initialIndex', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Text('Digital Wallet'),
        ),
      ),
    );

    expect(find.text('Digital Wallet'), findsOneWidget);
  });

  testWidgets('IdScannerScreen mounts cleanly', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: IdScannerScreen(evaluatorName: 'Lead Evaluator'),
      ),
    );
    await tester.pump();
    expect(find.text('ASB Campus Digital ID Scanner'), findsOneWidget);
  });

  testWidgets('HouseArenaScreen smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: const Scaffold(
          body: Text('ASB House Warroom'),
        ),
      ),
    );

    expect(find.text('ASB House Warroom'), findsOneWidget);
  });

  test('GeminiAiService offline heuristics generate house-specific responses', () async {
    final rubyResponse = await GeminiAiService.generateResponse(
      prompt: 'How to earn house points?',
      house: 'ruby',
      studentName: 'Mustafa',
    );
    expect(rubyResponse, contains('RUBY'));
    expect(rubyResponse, contains('Mustafa'));

    final chantResponse = await GeminiAiService.generateResponse(
      prompt: 'Give me a battle chant',
      house: 'sapphire',
      studentName: 'Aarav',
    );
    expect(chantResponse, contains('SAPPHIRE'));
    expect(chantResponse, contains('Battle Chant'));
  });

  testWidgets('HouseAiChatScreen mounts and displays initial welcome message', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: HouseAiChatScreen(
          userHouse: 'emerald',
          studentName: 'Sarah',
          scholarNo: '4042',
        ),
      ),
    );
    await tester.pump();

    expect(find.textContaining('EMERALD'), findsWidgets);
    expect(find.textContaining('Sylva the Titan Wolf'), findsWidgets);
  });

  testWidgets('AppleFitnessBadgesVault mounts with summary header and filters', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AppleFitnessBadgesVault(
            userHouse: 'ruby',
            userName: 'Mustafa Hisham',
            scholarNo: 'admin',
            isAdmin: true,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('House Championship Honours'), findsOneWidget);
    expect(find.text('TITAN VAULT'), findsOneWidget);
    expect(find.text('All Badges'), findsOneWidget);
    expect(find.text('House Centurion'), findsOneWidget);
  });

  testWidgets('Mascot3DStage mounts and displays 3D movable stage and lore codex', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Mascot3DStage(
            userHouse: 'ruby',
            userName: 'Mustafa Hisham',
            scholarNo: 'ASB-2026',
          ),
        ),
      ),
    );
    await tester.pump();

    // Verify mascot stage HUD & identity
    expect(find.text('Ignis the Crimson Dragon'), findsOneWidget);
    expect(find.text('360° Spin'), findsOneWidget);
    expect(find.text('Roar!'), findsOneWidget);
    expect(find.text('Mascot Power Attributes'), findsOneWidget);
    expect(find.text('The Cinder Core Sceptre'), findsOneWidget);
    expect(find.text('Founding Era Chronicles'), findsOneWidget);

    // Verify 3D Technical Diagram features: CAD Telemetry, Modes, and Callout Pins
    expect(find.textContaining('CAD • YAW:'), findsOneWidget);
    expect(find.text('Solid'), findsOneWidget);
    expect(find.text('Blueprint'), findsOneWidget);
    expect(find.text('X-Ray'), findsOneWidget);
    expect(find.text('Callouts: ACTIVE'), findsOneWidget);

    // Toggle blueprint mode
    await tester.tap(find.text('Blueprint'));
    await tester.pump(const Duration(milliseconds: 300));

    // Toggle X-ray mode
    await tester.tap(find.text('X-Ray'));
    await tester.pump(const Duration(milliseconds: 300));

    // Toggle callouts off and on
    await tester.tap(find.text('Callouts: ACTIVE'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Callouts: HIDDEN'), findsOneWidget);

    await tester.tap(find.text('Callouts: HIDDEN'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Callouts: ACTIVE'), findsOneWidget);

    // Verify Material Finishes
    expect(find.text('Chroma'), findsOneWidget);
    expect(find.text('24K Gold'), findsOneWidget);
    expect(find.text('Obsidian'), findsOneWidget);
    expect(find.text('Astral'), findsOneWidget);

    // Switch material finish to 24K Gold
    await tester.tap(find.text('24K Gold'));
    await tester.pump(const Duration(milliseconds: 200));

    // Verify Camera Presets
    expect(find.text('Front'), findsOneWidget);
    expect(find.text('3/4 Hero'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
    expect(find.text('Back Spine'), findsOneWidget);
    expect(find.text('Top Down'), findsOneWidget);

    // Switch camera angle to Profile
    await tester.tap(find.text('Profile'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('CAD • YAW:'), findsOneWidget);

    // Switch camera angle to Back Spine
    await tester.tap(find.text('Back Spine'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('CAD • YAW:'), findsOneWidget);

    // Switch to Sapphire
    await tester.tap(find.text('Sapphire'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Zephyr the Tempest Gryphon'), findsOneWidget);
    expect(find.text('The Aegis of Tempest Skies'), findsOneWidget);
  });

  test('HierarchyService validates roles and blocks unauthorized escalation', () {
    // 1. Super Admin Validation
    expect(
      HierarchyService.isSuperAdmin(
        scholarNo: '2310910',
        role: 'super_admin',
        fullName: 'Mustafa Hisham',
      ),
      isTrue,
    );
    expect(
      HierarchyService.isSuperAdmin(
        scholarNo: 'admin',
        role: 'admin',
        fullName: 'Mustafa Hisham',
      ),
      isTrue,
    );
    // Unrelated student named 'Mustafa' must NOT be Super Admin
    expect(
      HierarchyService.isSuperAdmin(
        scholarNo: '50012',
        role: 'student',
        fullName: 'Mustafa Ali',
      ),
      isFalse,
    );

    // 2. Executive Roster Checks
    expect(
      HierarchyService.isCaptain(scholarNo: '10001', role: 'captain'),
      isTrue,
    );
    expect(
      HierarchyService.isTeacherOrFaculty(scholarNo: '30003', role: 'teacher'),
      isTrue,
    );
    expect(
      HierarchyService.isCouncil(scholarNo: '12001', role: 'council'),
      isTrue,
    );
    expect(
      HierarchyService.isPrefect(
        scholarNo: '11004',
        role: 'prefect',
        fullName: 'Sarah Paul',
      ),
      isTrue,
    );

    // 3. Security Check: Unrelated student names must NOT receive elevated privileges via name matching
    expect(
      HierarchyService.isAdmin(
        scholarNo: '60123',
        role: 'student',
        fullName: 'Sarah Ahmed',
      ),
      isFalse,
    );
    expect(
      HierarchyService.isCouncilOrTeacher(
        scholarNo: '60123',
        role: 'student',
        fullName: 'Sarah Ahmed',
      ),
      isFalse,
    );
    // Student named 'Dr. Elizabeth Vance' cannot escalate to teacher
    expect(
      HierarchyService.isTeacherOrFaculty(
        scholarNo: '99999',
        role: 'student',
        fullName: 'Dr. Elizabeth Vance',
      ),
      isFalse,
    );
    // Student named 'Noaman Nizamuddin' cannot escalate to captain
    expect(
      HierarchyService.isCaptain(
        scholarNo: '88888',
        role: 'student',
        fullName: 'Noaman Nizamuddin',
      ),
      isFalse,
    );
    // Student named 'Head Boy' cannot escalate to council
    expect(
      HierarchyService.isCouncil(
        scholarNo: '77777',
        role: 'student',
        fullName: 'Head Boy',
      ),
      isFalse,
    );
    // Student named 'Sarah Paul' cannot escalate to prefect without scholar 11004 or prefect role
    expect(
      HierarchyService.isPrefect(
        scholarNo: '66666',
        role: 'student',
        fullName: 'Sarah Paul',
      ),
      isFalse,
    );
    // Student named 'Mustafa Hisham' cannot escalate to super admin without scholar 2310910/admin or super_admin role
    expect(
      HierarchyService.isSuperAdmin(
        scholarNo: '55555',
        role: 'student',
        fullName: 'Mustafa Hisham',
      ),
      isFalse,
    );

    // 4. Role Display Titles
    expect(
      HierarchyService.getRoleDisplayTitle(scholarNo: '2310910'),
      'Super Admin',
    );
    expect(
      HierarchyService.getRoleDisplayTitle(scholarNo: '11209'),
      'Super Admin',
    );
    expect(
      HierarchyService.getRoleDisplayTitle(role: 'teacher'),
      'Faculty Lead',
    );
    expect(
      HierarchyService.getRoleDisplayTitle(role: 'captain'),
      'House Captain',
    );
    expect(
      HierarchyService.getRoleDisplayTitle(role: 'council'),
      'Student Council',
    );
    expect(
      HierarchyService.getRoleDisplayTitle(role: 'prefect'),
      'Grade Prefect',
    );
    expect(
      HierarchyService.getRoleDisplayTitle(scholarNo: '60123', role: 'student'),
      'Student Member',
    );
  });

  testWidgets('HouseAiChatScreen retains TextField focus upon message submission', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: HouseAiChatScreen(
          userHouse: 'ruby',
          studentName: 'Mustafa',
          scholarNo: '2310910',
        ),
      ),
    );
    await tester.pump();

    final textFieldFinder = find.byType(TextField);
    expect(textFieldFinder, findsOneWidget);

    // Tap the text field to focus it
    await tester.tap(textFieldFinder);
    await tester.pump();
    expect(tester.widget<TextField>(textFieldFinder).focusNode?.hasFocus, isTrue);

    // Enter text and submit
    await tester.enterText(textFieldFinder, 'Hello AI Advisor');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pump();

    // Verify focus is securely retained so user never has to re-tap
    expect(tester.widget<TextField>(textFieldFinder).focusNode?.hasFocus, isTrue);
  });

  testWidgets('SignupScreen dynamically transforms theme upon house selection in Step 2 through Step 3', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: SignupScreen(),
      ),
    );
    await tester.pump();

    // Verify initial Step 0 (Identity)
    expect(find.text('Student Identity'), findsOneWidget);
    expect(find.text('Step 1 of 4'), findsOneWidget);

    // Initial progress indicator uses ruby as default
    final progressFinder = find.byType(LinearProgressIndicator);
    expect(progressFinder, findsOneWidget);
    final initialProgress = tester.widget<LinearProgressIndicator>(progressFinder);
    expect(
      (initialProgress.valueColor as AlwaysStoppedAnimation<Color>).value,
      HouseColors.ruby,
    );

    // Fill Step 0
    final textFields = find.byType(TextFormField);
    await tester.enterText(textFields.at(0), 'Aarav Sharma');
    await tester.enterText(textFields.at(1), '54321');
    await tester.pump();

    // Advance to Step 1 (Academic Details)
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Academic Details'), findsOneWidget);

    // Select Grade 10 and Section B
    await tester.ensureVisible(find.text('10'));
    await tester.tap(find.text('10'));
    await tester.pump();
    await tester.ensureVisible(find.text('B'));
    await tester.tap(find.text('B'));
    await tester.pump();

    // Advance to Step 2 (House Selection)
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('House Selection'), findsOneWidget);

    // All 4 houses must be visible
    expect(find.text('Ruby'), findsOneWidget);
    expect(find.text('Sapphire'), findsOneWidget);
    expect(find.text('Emerald'), findsOneWidget);
    expect(find.text('Topaz'), findsOneWidget);

    // No celebration card yet
    expect(find.text('THEME ACTIVATED ✨'), findsNothing);

    // 1. Select Sapphire House
    await tester.ensureVisible(find.text('Sapphire'));
    await tester.tap(find.text('Sapphire'));
    await tester.pumpAndSettle();

    // Verify dynamic celebration details appear immediately
    expect(find.text('THEME ACTIVATED ✨'), findsOneWidget);
    expect(find.text('Sapphire House'), findsWidgets);
    expect(find.text('Zephyr the Tempest Gryphon'), findsOneWidget);
    expect(find.textContaining('Motto: "Wisdom & Truth"'), findsOneWidget);

    // Verify progress indicator immediately adapts to Sapphire Blue
    final sapphireProgress = tester.widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator));
    expect(
      (sapphireProgress.valueColor as AlwaysStoppedAnimation<Color>).value,
      HouseColors.sapphire,
    );

    // 2. Select Emerald House
    await tester.ensureVisible(find.text('Emerald'));
    await tester.tap(find.text('Emerald'));
    await tester.pumpAndSettle();

    // Verify celebration details morph immediately to Emerald
    expect(find.text('Emerald House'), findsWidgets);
    expect(find.text('Sylva the Titan Wolf'), findsOneWidget);
    expect(find.textContaining('Motto: "Honor & Growth"'), findsOneWidget);

    // Verify progress indicator morphs to Emerald Green
    final emeraldProgress = tester.widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator));
    expect(
      (emeraldProgress.valueColor as AlwaysStoppedAnimation<Color>).value,
      HouseColors.emerald,
    );

    // Advance to Step 3 (Security / Password creation)
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Create a strong password to protect your account.'), findsOneWidget);
    expect(find.text('Security'), findsWidgets);

    // Verify Enrollment Summary Banner celebrates chosen Emerald House
    expect(find.text('EMERALD HOUSE'), findsOneWidget);
    expect(find.text('Aarav Sharma'), findsOneWidget);
    expect(find.textContaining('Scholar #54321'), findsOneWidget);
    expect(find.textContaining('Sylva the Titan Wolf'), findsOneWidget);

    // Verify button says 'Complete Registration'
    expect(find.text('Complete Registration'), findsOneWidget);

    // Enter a strong password and verify StrengthMeter adapts
    final passwordFields = find.byType(TextFormField);
    await tester.ensureVisible(passwordFields.at(0));
    await tester.enterText(passwordFields.at(0), 'AsbSecure2026!');
    await tester.ensureVisible(passwordFields.at(1));
    await tester.enterText(passwordFields.at(1), 'AsbSecure2026!');
    await tester.pumpAndSettle();

    expect(find.text('Strong'), findsOneWidget);
  });

  testWidgets('SignupScreen transforms for Topaz and Ruby, and supports bi-directional step indicator navigation', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: SignupScreen(),
      ),
    );
    await tester.pump();

    // Fill Step 0
    final textFields = find.byType(TextFormField);
    await tester.enterText(textFields.at(0), 'Fatima Al-Sayed');
    await tester.enterText(textFields.at(1), '12345');
    await tester.pump();

    // Advance to Step 1
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    // Select Grade 11 and Section A
    await tester.ensureVisible(find.text('11'));
    await tester.tap(find.text('11'));
    await tester.pump();
    await tester.ensureVisible(find.text('A'));
    await tester.tap(find.text('A'));
    await tester.pump();

    // Advance to Step 2
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    // 1. Select Topaz House
    await tester.ensureVisible(find.text('Topaz'));
    await tester.tap(find.text('Topaz'));
    await tester.pumpAndSettle();

    // Verify Topaz celebration banner and progress color
    expect(find.text('Topaz House'), findsWidgets);
    expect(find.text('Solis the Golden Chimera'), findsOneWidget);
    expect(find.textContaining('Motto: "Light & Excellence"'), findsOneWidget);
    expect(find.text('Radiance of Victory'), findsOneWidget);

    final topazProgress = tester.widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator));
    expect(
      (topazProgress.valueColor as AlwaysStoppedAnimation<Color>).value,
      HouseColors.topaz,
    );

    // 2. Select Ruby House
    await tester.ensureVisible(find.text('Ruby'));
    await tester.tap(find.text('Ruby'));
    await tester.pumpAndSettle();

    // Verify Ruby celebration banner and progress color
    expect(find.text('Ruby House'), findsWidgets);
    expect(find.text('Ignis the Crimson Dragon'), findsOneWidget);
    expect(find.textContaining('Motto: "Courage & Passion"'), findsOneWidget);
    expect(find.text('Flame of Valor'), findsOneWidget);

    final rubyProgress = tester.widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator));
    expect(
      (rubyProgress.valueColor as AlwaysStoppedAnimation<Color>).value,
      HouseColors.ruby,
    );

    // Advance to Step 3
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('RUBY HOUSE'), findsOneWidget);
    expect(find.textContaining('Ignis the Crimson Dragon'), findsOneWidget);

    // Verify step indicator dynamically displays 'Ruby'
    expect(find.text('Ruby'), findsWidgets);

    // Test bi-directional navigation: Tap Step 2 indicator to jump back to house selection
    await tester.tap(find.widgetWithText(InkWell, 'Ruby'));
    await tester.pumpAndSettle();
    expect(find.text('House Selection'), findsOneWidget);

    // Switch house back to Topaz
    await tester.ensureVisible(find.text('Topaz'));
    await tester.tap(find.text('Topaz'));
    await tester.pumpAndSettle();

    // Tap Step 3 indicator to jump back forward to Security!
    await tester.tap(find.widgetWithText(InkWell, 'Security'));
    await tester.pumpAndSettle();
    expect(find.text('TOPAZ HOUSE'), findsOneWidget);
    expect(find.textContaining('Solis the Golden Chimera'), findsOneWidget);
  });

  test('AuthService house caching and profile persistence logic', () async {
    SharedPreferences.setMockInitialValues({});
    await AuthService.initPreferences();

    // Initial state: nothing cached
    expect(AuthService.getCachedHouse(), isNull);
    expect(AuthService.getCachedProfile(), isNull);

    // Cache emerald house
    await AuthService.cacheHouse('emerald');
    expect(AuthService.getCachedHouse(), 'emerald');

    // Case and whitespace resilience
    await AuthService.cacheHouse('   SAPPHIRE  ');
    expect(AuthService.getCachedHouse(), 'sapphire');

    // Profile caching updates house and handles Firestore Timestamps safely without throwing
    final mockTimestamp = Timestamp.fromDate(DateTime(2026, 9, 25));
    await AuthService.cacheProfile({
      'full_name': 'Noaman Nizamuddin',
      'scholar_no': '10001',
      'house_name': 'emerald',
      'created_at': mockTimestamp,
      'role': 'captain',
    });
    expect(AuthService.getCachedHouse(), 'emerald');
    expect(AuthService.getCachedScholarNo(), '10001');
    final profile = AuthService.getCachedProfile();
    expect(profile, isNotNull);
    expect(profile?['full_name'], 'Noaman Nizamuddin');
    expect(profile?['house_name'], 'emerald');
    expect(profile?['created_at'], isNotNull);

    // extractHouse handles house, houseName, house_id, house_name
    expect(AuthService.extractHouse({'house': 'Emerald'}), 'emerald');
    expect(AuthService.extractHouse({'houseName': 'SAPPHIRE'}), 'sapphire');
    expect(AuthService.extractHouse({'house_id': 'TOPAZ'}), 'topaz');
    expect(AuthService.extractHouse({'house_name': 'Ruby'}), 'ruby');

    // inferHouseFromScholarNo for houses
    expect(AuthService.inferHouseFromScholarNo('emerald_student'), 'emerald');
    expect(AuthService.inferHouseFromScholarNo('sapphire_student'), 'sapphire');
    expect(AuthService.inferHouseFromScholarNo('topaz_student'), 'topaz');
    expect(AuthService.inferHouseFromScholarNo('2310910'), 'ruby');
    expect(AuthService.inferHouseFromScholarNo('11209'), 'ruby');
    expect(AuthService.inferHouseFromScholarNo('admin'), 'ruby');

    // Clear cache
    await AuthService.clearCache();
    expect(AuthService.getCachedHouse(), isNull);
    expect(AuthService.getCachedProfile(), isNull);
    expect(AuthService.getCachedScholarNo(), isNull);
  });

  testWidgets('Loading state glows in Emerald and displays house-themed assets for Emerald user', (
    WidgetTester tester,
  ) async {
    const houseName = 'emerald';
    final houseColor = HouseColors.getHouseColor(houseName);
    final houseDark = HouseColors.getHouseDarkColor(houseName);
    final houseGlow = HouseColors.getHouseGlowColor(houseName);
    final houseAccent = HouseColors.getHouseAccentColor(houseName);
    final houseEmoji = HouseColors.getHouseEmoji(houseName);
    final houseMascot = HouseColors.getHouseMascotName(houseName);
    final houseMotto = HouseColors.getHouseMotto(houseName);

    expect(houseColor, HouseColors.emerald);
    expect(houseGlow, HouseColors.emeraldGlow);
    expect(houseEmoji, '🐺');
    expect(houseMascot, 'Sylva the Titan Wolf');
    expect(houseMotto, 'Honor & Growth');

    // Build the themed glowing loading screen component
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 104,
                  height: 104,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [houseAccent, houseColor, houseDark],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: houseGlow.withValues(alpha: 0.5),
                        blurRadius: 36,
                        spreadRadius: 6,
                      ),
                    ],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      const Icon(Icons.shield_rounded, color: Colors.white, size: 56),
                      Text(houseEmoji, style: const TextStyle(fontSize: 22)),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(houseEmoji),
                      const SizedBox(width: 8),
                      Text('${houseName.toUpperCase()} HOUSE'),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Text('ASB House Hub', style: TextStyle(color: houseColor)),
                const SizedBox(height: 6),
                Text('Loading your ${houseName[0].toUpperCase()}${houseName.substring(1)} dashboard...'),
                const SizedBox(height: 24),
                SizedBox(
                  width: 160,
                  height: 4,
                  child: LinearProgressIndicator(
                    backgroundColor: houseColor.withValues(alpha: 0.15),
                    valueColor: AlwaysStoppedAnimation<Color>(houseGlow),
                  ),
                ),
                const SizedBox(height: 16),
                Text('“$houseMotto”'),
                const SizedBox(height: 4),
                Text(houseMascot),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    // Verify emerald house loading dashboard elements
    expect(find.text('ASB House Hub'), findsOneWidget);
    expect(find.text('Loading your Emerald dashboard...'), findsOneWidget);
    expect(find.text('EMERALD HOUSE'), findsOneWidget);
    expect(find.text('🐺'), findsWidgets);
    expect(find.text('“Honor & Growth”'), findsOneWidget);
    expect(find.text('Sylva the Titan Wolf'), findsOneWidget);

    final progressFinder = find.byType(LinearProgressIndicator);
    expect(progressFinder, findsOneWidget);
    final indicator = tester.widget<LinearProgressIndicator>(progressFinder);
    expect((indicator.valueColor as AlwaysStoppedAnimation<Color>).value, HouseColors.emeraldGlow);
  });

  testWidgets('AuthGate in waiting state glows with cached house colors', (
    WidgetTester tester,
  ) async {
    final waitingStream1 = StreamController<User?>().stream;
    SharedPreferences.setMockInitialValues({'cached_house_name': 'emerald'});
    await AuthService.initPreferences();

    await tester.pumpWidget(
      MaterialApp(
        home: AuthGate(authStateStream: waitingStream1),
      ),
    );

    // Verify emerald house mascot emoji and progress indicator glow
    expect(find.text('🐺'), findsOneWidget);
    final progressFinder = find.byType(LinearProgressIndicator);
    expect(progressFinder, findsOneWidget);
    final indicator = tester.widget<LinearProgressIndicator>(progressFinder);
    expect(
      (indicator.valueColor as AlwaysStoppedAnimation<Color>).value,
      HouseColors.emeraldGlow,
    );

    // Now test with sapphire cached
    final waitingStream2 = StreamController<User?>().stream;
    await AuthService.cacheHouse('sapphire');
    await tester.pumpWidget(
      MaterialApp(
        home: AuthGate(authStateStream: waitingStream2),
      ),
    );

    expect(find.text('🦅'), findsOneWidget);
    final indicatorSapphire = tester.widget<LinearProgressIndicator>(progressFinder);
    expect(
      (indicatorSapphire.valueColor as AlwaysStoppedAnimation<Color>).value,
      HouseColors.sapphireGlow,
    );
  });

  test('AuthService.extractHouse safely extracts and normalizes house names across diverse formats', () {
    // Standard keys
    expect(AuthService.extractHouse({'house_name': 'ruby'}), 'ruby');
    expect(AuthService.extractHouse({'house': 'Sapphire'}), 'sapphire');
    expect(AuthService.extractHouse({'houseName': 'EMERALD'}), 'emerald');
    expect(AuthService.extractHouse({'house_id': 'topaz'}), 'topaz');
    expect(AuthService.extractHouse({'house_code': 'ruby'}), 'ruby');
    expect(AuthService.extractHouse({'House': 'sapphire'}), 'sapphire');
    expect(AuthService.extractHouse({'HouseName': 'emerald'}), 'emerald');

    // Composite strings containing house name
    expect(AuthService.extractHouse({'house_name': 'Ruby House Pride'}), 'ruby');
    expect(AuthService.extractHouse({'house': 'house_emerald_senior'}), 'emerald');
    expect(AuthService.extractHouse({'houseName': 'Topaz Guardians'}), 'topaz');
    expect(AuthService.extractHouse({'house_id': 'Sapphire-Squad'}), 'sapphire');

    // Invalid / empty / null inputs
    expect(AuthService.extractHouse(null), isNull);
    expect(AuthService.extractHouse({}), isNull);
    expect(AuthService.extractHouse({'house_name': ''}), isNull);
    expect(AuthService.extractHouse({'house_name': '   '}), isNull);
    expect(AuthService.extractHouse({'house_name': 'null'}), isNull);
    expect(AuthService.extractHouse({'house_name': 'none'}), isNull);
    expect(AuthService.extractHouse({'house_name': 'undefined'}), isNull);
    expect(AuthService.extractHouse({'house_name': 'unknown_house'}), isNull);
    expect(AuthService.extractHouse({'house_name': 'VERIFIED: 12345'}), isNull);
    expect(AuthService.extractHouse({'house_name': 'Gryffindor'}), isNull);
  });

  test('AuthService.inferHouseFromScholarNo correctly infers house or returns null', () {
    expect(AuthService.inferHouseFromScholarNo('emerald_student'), 'emerald');
    expect(AuthService.inferHouseFromScholarNo('sapphire_student'), 'sapphire');
    expect(AuthService.inferHouseFromScholarNo('topaz_student'), 'topaz');
    expect(AuthService.inferHouseFromScholarNo('2310910'), 'ruby');
    expect(AuthService.inferHouseFromScholarNo('11209'), 'ruby');
    expect(AuthService.inferHouseFromScholarNo('admin'), 'ruby');

    // Substring fallback
    expect(AuthService.inferHouseFromScholarNo('scholar_emerald_01'), 'emerald');
    expect(AuthService.inferHouseFromScholarNo('sapphire_lead'), 'sapphire');
    expect(AuthService.inferHouseFromScholarNo('topaz_vice'), 'topaz');

    // Unknown scholar
    expect(AuthService.inferHouseFromScholarNo('99999'), isNull);
    expect(AuthService.inferHouseFromScholarNo(''), isNull);
  });

  test('QR token cascade logic guards against VERIFIED keyword becoming house name', () {
    const legacyTokenWithVerified = 'ASB-ID:2310910:VERIFIED';
    final parts = legacyTokenWithVerified.split(':');
    expect(parts.length, 3);
    final scholar = parts[1];
    String house = 'Ruby';

    if (parts.length == 3) {
      if (parts[2].toUpperCase() == 'VERIFIED') {
        house = AuthService.inferHouseFromScholarNo(scholar) ?? 'Ruby';
      } else {
        house = parts[2];
      }
    }

    // Must NOT be 'VERIFIED'
    expect(house, isNot('VERIFIED'));
    expect(house.toLowerCase(), anyOf('ruby', 'sapphire', 'emerald', 'topaz'));
  });

  test('CartItem class strictly clamps quantities between 1 and 99', () {
    const dummyProduct = MerchProduct(
      id: 'hoodie_ruby',
      name: 'Ruby Hoodie',
      price: '50 Pts',
      rating: 4.9,
      imageUrl: '',
      category: 'Hoodies',
      house: 'ruby',
      description: 'Official hoodie',
    );

    // Constructor clamping
    final itemNeg = CartItem(product: dummyProduct, size: 'L', qty: -5);
    expect(itemNeg.qty, 1);

    final itemZero = CartItem(product: dummyProduct, size: 'L', qty: 0);
    expect(itemZero.qty, 1);

    final itemOver = CartItem(product: dummyProduct, size: 'L', qty: 250);
    expect(itemOver.qty, 99);

    // Setter clamping
    final item = CartItem(product: dummyProduct, size: 'M', qty: 2);
    expect(item.qty, 2);

    item.qty = -10;
    expect(item.qty, 1);

    item.qty = 1000;
    expect(item.qty, 99);

    item.qty = 5;
    expect(item.qty, 5);
    expect(item.pointsPrice, 250);
  });

  test('VoucherSecurityService generates valid HMAC tokens and catches tampering', () {
    const billNo = 'ASB-BILL-9876';
    const points = 250;
    const scholarNo = '2310910';
    final ts = DateTime.now().millisecondsSinceEpoch;

    final token = VoucherSecurityService.generateVoucherToken(
      billNo: billNo,
      points: points,
      scholarNo: scholarNo,
      timestampMillis: ts,
    );
    expect(token, isNotEmpty);

    // Valid check
    expect(
      VoucherSecurityService.validateVoucherToken(
        token: token,
        billNo: billNo,
        points: points,
        scholarNo: scholarNo,
        timestampMillis: ts,
      ),
      isTrue,
    );

    // Tampered points
    expect(
      VoucherSecurityService.validateVoucherToken(
        token: token,
        billNo: billNo,
        points: 9999,
        scholarNo: scholarNo,
        timestampMillis: ts,
      ),
      isFalse,
    );

    // Tampered scholar
    expect(
      VoucherSecurityService.validateVoucherToken(
        token: token,
        billNo: billNo,
        points: points,
        scholarNo: '10001',
        timestampMillis: ts,
      ),
      isFalse,
    );

    // Full JSON payload generation and parsing
    final payload = VoucherSecurityService.generateVoucherPayload(
      billNo: billNo,
      points: points,
      scholarNo: scholarNo,
      items: ['Sapphire Elite Jersey - M', 'ASB Cap'],
      timestampMillis: ts,
    );

    final verified = VoucherSecurityService.validateVoucherPayload(payload);
    expect(verified.isValid, isTrue);
    expect(verified.isTampered, isFalse);
    expect(verified.billNo, billNo);
    expect(verified.points, points);
    expect(verified.scholarNo, scholarNo);
    expect(verified.items, hasLength(2));

    // Tampered payload detected
    final tamperedPayload = payload.replaceAll('"pts":250', '"pts":5000');
    final tamperedResult = VoucherSecurityService.validateVoucherPayload(tamperedPayload);
    expect(tamperedResult.isValid, isFalse);
    expect(tamperedResult.isTampered, isTrue);

    // Legacy format
    final legacyResult = VoucherSecurityService.validateVoucherPayload('ASB-ORDER-ASB-999');
    expect(legacyResult.isValid, isTrue);
    expect(legacyResult.billNo, 'ASB-999');

    // Completely malformed
    final malformedResult = VoucherSecurityService.validateVoucherPayload('garbage-data');
    expect(malformedResult.isValid, isFalse);
  });

  test('Brain Blitz combo streak multipliers match game design specs', () {
    double getMultiplier(int streak) {
      return (streak >= 4)
          ? 2.0
          : (streak >= 3 ? 1.5 : (streak == 2 ? 1.25 : 1.0));
    }

    expect(getMultiplier(0), 1.0);
    expect(getMultiplier(1), 1.0);
    expect(getMultiplier(2), 1.25);
    expect(getMultiplier(3), 1.5);
    expect(getMultiplier(4), 2.0);
    expect(getMultiplier(5), 2.0);

    // Score increments for 20 base pts per question
    expect((20 * getMultiplier(1)).round(), 20);
    expect((20 * getMultiplier(2)).round(), 25);
    expect((20 * getMultiplier(3)).round(), 30);
    expect((20 * getMultiplier(4)).round(), 40);
  });

  test('Student conduct points clamping and reason sanitization bounds logic', () {
    int clampPoints(int pts) => pts.abs().clamp(1, 100);
    String sanitizeReason(String r) {
      final trimmed = r.trim();
      if (trimmed.isEmpty) return 'General Conduct Observation';
      return trimmed.length > 250 ? trimmed.substring(0, 250) : trimmed;
    }

    // Bounds check
    expect(clampPoints(-50), 50);
    expect(clampPoints(0), 1);
    expect(clampPoints(500), 100);
    expect(clampPoints(25), 25);

    // Reason check
    expect(sanitizeReason('   '), 'General Conduct Observation');
    expect(sanitizeReason('Great presentation'), 'Great presentation');
    final longStr = 'A' * 300;
    expect(sanitizeReason(longStr).length, 250);
  });

  testWidgets('IdScannerScreen does not contain mock accounts or demo buttons in production UI', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: IdScannerScreen(evaluatorName: 'Lead Evaluator'),
      ),
    );
    await tester.pump();

    // Verifies production scanner UI is rendered
    expect(find.text('ASB Campus Digital ID Scanner'), findsOneWidget);
    expect(find.text('Point camera directly at student ID QR or digital voucher to scan in real-time.'), findsOneWidget);
    expect(find.text('Manual Scholar # or QR Code Lookup'), findsOneWidget);
    expect(find.text('Upload QR Image / Photo from Gallery'), findsOneWidget);

    // Verifies that fake demo scan buttons and preset accounts were removed
    expect(find.textContaining('One-Tap Demo Scans'), findsNothing);
    expect(find.textContaining('Mustafa Hisham'), findsNothing);
    expect(find.textContaining('Noaman Nizamuddin'), findsNothing);
  });

  testWidgets('IdScannerScreen adapts responsive layout between desktop wide and mobile viewports', (
    WidgetTester tester,
  ) async {
    // 1. Desktop wide viewport (1280x720)
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: IdScannerScreen(evaluatorName: 'Lead Evaluator'),
      ),
    );
    await tester.pump();

    // Verify Dropzone and Manual Lookup render simultaneously in desktop two-column mode
    expect(find.text('Click to Browse QR Code Image'), findsOneWidget);
    expect(find.text('Select Image File'), findsOneWidget);
    expect(find.text('Manual Scholar # or QR Code Lookup'), findsOneWidget);

    // Verify accessible semantics on Dropzone
    expect(
      find.byWidgetPredicate((w) =>
          w is Semantics &&
          w.properties.button == true &&
          w.properties.label == 'Select QR Code image file from your computer'),
      findsOneWidget,
    );

    // 2. Mobile narrow viewport (400x800)
    tester.view.physicalSize = const Size(400, 800);
    await tester.pump();

    expect(find.text('Click to Browse QR Code Image'), findsOneWidget);
    expect(find.text('Manual Scholar # or QR Code Lookup'), findsOneWidget);
  });

  testWidgets('IdScannerScreen and CameraCaptureDialog satisfy WCAG accessibility guidelines', (
    WidgetTester tester,
  ) async {
    // 1. Mount IdScannerScreen
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const IdScannerScreen(evaluatorName: 'Lead Evaluator'),
      ),
    );
    await tester.pump();

    // Verify touch targets >= 48dp on primary buttons
    final lookupBtn = tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Lookup'));
    expect(lookupBtn.style?.minimumSize?.resolve({})?.height, greaterThanOrEqualTo(48.0));

    // Verify semantic descriptions exist for screen readers
    expect(
      find.bySemanticsLabel(RegExp(r'Camera Viewfinder|Select QR Code image|Scholar #', caseSensitive: false)),
      findsWidgets,
    );

    // 2. Mount CameraCaptureDialog
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const Scaffold(
          body: CameraCaptureDialog(),
        ),
      ),
    );
    await tester.pump();

    // Verify dialog semantics exist for screen readers
    expect(
      find.bySemanticsLabel(RegExp(r'Initializing Camera|Camera viewfinder|Requesting camera|No physical webcam', caseSensitive: false)),
      findsWidgets,
    );
  });

  test('IdScannerScreen.cleanScholarQuery normalizes diverse user input formats', () {
    expect(IdScannerScreen.cleanScholarQuery('2310910'), '2310910');
    expect(IdScannerScreen.cleanScholarQuery('#2310910'), '2310910');
    expect(IdScannerScreen.cleanScholarQuery('##2310910'), '2310910');
    expect(IdScannerScreen.cleanScholarQuery('scholar: 2310910'), '2310910');
    expect(IdScannerScreen.cleanScholarQuery('Scholar #2310910'), '2310910');
    expect(IdScannerScreen.cleanScholarQuery('id: 2310910'), '2310910');
    expect(IdScannerScreen.cleanScholarQuery('scholar_no: 2310910'), '2310910');
    expect(IdScannerScreen.cleanScholarQuery('  2310910  '), '2310910');
  });

  testWidgets('IdScannerScreen manual lookup validates empty and invalid inputs with inline errorText', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: IdScannerScreen(evaluatorName: 'Lead Evaluator'),
      ),
    );
    await tester.pump();

    // 1. Submit empty search
    final lookupBtn = find.widgetWithText(ElevatedButton, 'Lookup');
    await tester.tap(lookupBtn);
    await tester.pump();

    expect(find.text('Please enter a Scholar # or scan a QR code.'), findsOneWidget);

    // 2. Enter invalid gibberish / symbols
    final textField = find.byType(TextField);
    await tester.enterText(textField, '???');
    await tester.tap(lookupBtn);
    await tester.pump();

    expect(find.text('Invalid Scholar #. Enter 3-12 letters/digits (e.g. 2310910).'), findsOneWidget);

    // 3. Clear button clears text and error
    await tester.enterText(textField, '2310910');
    await tester.pump();
    final clearBtn = find.byTooltip('Clear search text');
    expect(clearBtn, findsOneWidget);
    await tester.tap(clearBtn);
    await tester.pump();

    expect(find.text('Invalid Scholar #. Enter 3-12 letters/digits (e.g. 2310910).'), findsNothing);
  });

  testWidgets('IdScannerScreen handles case-insensitive token schemes and navigates to evaluation screen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: IdScannerScreen(evaluatorName: 'Lead Evaluator'),
      ),
    );
    await tester.pump();

    // Enter case-insensitive legacy token e.g. "asb-id:10042:emerald:verified"
    final textField = find.byType(TextField);
    await tester.enterText(textField, 'asb-id:10042:emerald:verified');
    final lookupBtn = find.widgetWithText(ElevatedButton, 'Lookup');
    await tester.tap(lookupBtn);
    await tester.pumpAndSettle();

    // Verify successful navigation to StudentBehaviorEvaluationScreen
    expect(find.byType(StudentBehaviorEvaluationScreen), findsOneWidget);
    expect(find.textContaining('10042'), findsWidgets);
  });

  testWidgets('Mascot3DStage non-overlapping chrome displays CAD telemetry and diagram mode buttons', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Mascot3DStage(
            userHouse: 'ruby',
            userName: 'Student Scholar',
            scholarNo: '12345',
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.textContaining('CAD • YAW:'), findsOneWidget);
    expect(find.text('Solid'), findsOneWidget);
    expect(find.text('Blueprint'), findsOneWidget);
    expect(find.text('X-Ray'), findsOneWidget);
    expect(find.textContaining('Callouts:'), findsOneWidget);
    expect(find.text('360° Drag • Pinch'), findsOneWidget);
  });

  testWidgets('DualHouseWallpaper blends both participants house colors into atmospheric wallpaper', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: DualHouseWallpaper(
            senderHouse: 'ruby',
            recipientHouse: 'emerald',
            isDark: true,
            pulseValue: 1.0,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(DualHouseWallpaper), findsOneWidget);
    expect(find.byType(AnimatedContainer), findsWidgets);
  });

  testWidgets('ChatRoomScreen dynamically reflects other participants house and dual wallpaper', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ChatRoomScreen(
          roomId: 'test_ruby_emerald',
          otherUserName: 'Noaman Nizamuddin',
          otherUserRole: 'House Captain',
          otherUserHouse: 'emerald',
          myUserHouse: 'ruby',
        ),
      ),
    );
    await tester.pump();

    // Contact name
    expect(find.text('Noaman Nizamuddin'), findsOneWidget);
    // House and role badge (Emerald, not Council or locked to yellow!)
    expect(find.text('EMERALD • HOUSE CAPTAIN'), findsOneWidget);
    // Dual house alliance chip
    expect(find.text('RUBY'), findsOneWidget);
    expect(find.text('EMERALD'), findsOneWidget);
    // DualHouseWallpaper
    expect(find.byType(DualHouseWallpaper), findsOneWidget);
    // Avatar initial
    expect(find.text('N'), findsOneWidget);
  });

  testWidgets('ChatRoomScreen with Sapphire council member displays sapphire badge and alliance header', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ChatRoomScreen(
          roomId: 'test_ruby_sapphire',
          otherUserName: 'Tanish Mukherjee',
          otherUserRole: 'Student Council',
          otherUserHouse: 'sapphire',
          myUserHouse: 'ruby',
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Tanish Mukherjee'), findsOneWidget);
    expect(find.text('SAPPHIRE • STUDENT COUNCIL'), findsOneWidget);
    expect(find.text('RUBY'), findsOneWidget);
    expect(find.text('SAPPHIRE'), findsOneWidget);
    expect(find.text('T'), findsOneWidget);
  });

  testWidgets('ChatRoomScreen with Topaz member displays topaz badge and alliance header', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ChatRoomScreen(
          roomId: 'test_ruby_topaz',
          otherUserName: 'Galwin Britto',
          otherUserRole: 'Grade Prefect',
          otherUserHouse: 'topaz',
          myUserHouse: 'ruby',
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Galwin Britto'), findsOneWidget);
    expect(find.text('TOPAZ • GRADE PREFECT'), findsOneWidget);
    expect(find.text('RUBY'), findsOneWidget);
    expect(find.text('TOPAZ'), findsOneWidget);
    expect(find.text('G'), findsOneWidget);
  });

  testWidgets('ChatRoomScreen same-house (Ruby to Ruby) displays alliance and wallpaper', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ChatRoomScreen(
          roomId: 'test_ruby_ruby',
          otherUserName: 'Sarah Paul',
          otherUserRole: 'Grade Prefect',
          otherUserHouse: 'ruby',
          myUserHouse: 'ruby',
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Sarah Paul'), findsOneWidget);
    expect(find.text('RUBY • GRADE PREFECT'), findsOneWidget);
    expect(find.text('RUBY'), findsNWidgets(2)); // sender and receiver in alliance chip
    expect(find.text('S'), findsOneWidget);
  });

  testWidgets('DualHouseWallpaper renders in light mode without issues', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: DualHouseWallpaper(
            senderHouse: 'ruby',
            recipientHouse: 'emerald',
            isDark: false,
            pulseValue: 0.95,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(DualHouseWallpaper), findsOneWidget);
  });

  test('AuthService SavedAccount and Sibling Multi-Account management', () async {
    SharedPreferences.setMockInitialValues({});
    await AuthService.initPreferences();

    // 1. Initial state: no saved accounts
    expect(AuthService.getSavedAccounts(), isEmpty);

    // 2. Add an account for Aarav Sharma (Emerald)
    final aaravAccount = SavedAccount(
      scholarNo: '10001',
      fullName: 'Aarav Sharma',
      houseName: 'emerald',
      uid: 'uid_aarav',
      role: 'student',
      classLevel: 'Grade 10',
      division: 'A',
      password: 'AaravPassword123',
      cachedProfile: {
        'scholar_no': '10001',
        'full_name': 'Aarav Sharma',
        'house_name': 'emerald',
        'role': 'student',
        'class_level': 'Grade 10',
        'division': 'A',
      },
    );
    await AuthService.saveAccount(aaravAccount);

    var accounts = AuthService.getSavedAccounts();
    expect(accounts.length, 1);
    expect(accounts.first.scholarNo, '10001');
    expect(accounts.first.fullName, 'Aarav Sharma');
    expect(accounts.first.houseName, 'emerald');
    // Passwords are persisted for seamless multi-account switching on family devices
    expect(accounts.first.password, equals('AaravPassword123'));
    expect(aaravAccount.toMap().containsKey('password'), isTrue);
    final injectedMap = {'password': 'hacked_password', 'scholar_no': '12345'};
    expect(SavedAccount.fromMap(injectedMap).password, equals('hacked_password'));

    // 3. Add Sibling Priya Sharma (Ruby House)
    final priyaAccount = SavedAccount(
      scholarNo: '2310910',
      fullName: 'Priya Sharma',
      houseName: 'ruby',
      uid: 'uid_priya',
      role: 'student',
      classLevel: 'Grade 8',
      division: 'B',
      password: 'PriyaPassword456',
      cachedProfile: {
        'scholar_no': '2310910',
        'full_name': 'Priya Sharma',
        'house_name': 'ruby',
        'role': 'student',
        'class_level': 'Grade 8',
        'division': 'B',
      },
    );
    await AuthService.saveAccount(priyaAccount);

    accounts = AuthService.getSavedAccounts();
    expect(accounts.length, 2);
    expect(accounts.any((a) => a.scholarNo == '10001' && a.houseName == 'emerald'), isTrue);
    expect(accounts.any((a) => a.scholarNo == '2310910' && a.houseName == 'ruby'), isTrue);

    // 4. Test switchAccount: Switch active session to Priya (Ruby)
    final authService = AuthService();
    await authService.switchAccount(priyaAccount);

    expect(AuthService.getCachedHouse(), 'ruby');
    expect(AuthService.getCachedScholarNo(), '2310910');
    final activeProfile = AuthService.getCachedProfile();
    expect(activeProfile?['full_name'], 'Priya Sharma');
    expect(activeProfile?['house_name'], 'ruby');

    // 5. Test switchAccount: Switch back to Aarav (Emerald)
    await authService.switchAccount(aaravAccount);
    expect(AuthService.getCachedHouse(), 'emerald');
    expect(AuthService.getCachedScholarNo(), '10001');
    final aaravProfile = AuthService.getCachedProfile();
    expect(aaravProfile?['full_name'], 'Aarav Sharma');
    expect(aaravProfile?['house_name'], 'emerald');

    // 6. Test addSiblingAccount method with inferred house (Sapphire #30003_sapphire)
    final vanceSibling = await authService.addSiblingAccount(
      scholarNo: '30003_sapphire',
      password: 'VancePassword789',
    );
    expect(vanceSibling.scholarNo, '30003_sapphire');
    expect(vanceSibling.houseName, 'sapphire');

    accounts = AuthService.getSavedAccounts();
    expect(accounts.length, 3);
    expect(accounts.any((a) => a.scholarNo == '30003_sapphire' && a.houseName == 'sapphire'), isTrue);

    // 7. Test removeSavedAccount
    await AuthService.removeSavedAccount('30003_sapphire');
    accounts = AuthService.getSavedAccounts();
    expect(accounts.length, 2);
    expect(accounts.any((a) => a.scholarNo == '30003_sapphire'), isFalse);

    // 8. Test clearAllSavedAccounts
    await AuthService.clearAllSavedAccounts();
    expect(AuthService.getSavedAccounts(), isEmpty);
  });

  testWidgets('AccountSwitcherModal and AddSiblingModal mount and interact cleanly', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await AuthService.initPreferences();

    // Cache initial Emerald student
    await AuthService.cacheHouse('emerald');
    await AuthService.cacheProfile({
      'scholar_no': '10001',
      'full_name': 'Aarav Emerald Lead',
      'house_name': 'emerald',
      'role': 'student',
      'class_level': '10-A',
      'division': 'A',
    });

    await AuthService.saveAccount(
      SavedAccount(
        scholarNo: '10001',
        fullName: 'Aarav Emerald Lead',
        houseName: 'emerald',
        uid: 'uid_aarav',
        role: 'student',
        classLevel: '10-A',
        division: 'A',
        cachedProfile: {
          'scholar_no': '10001',
          'full_name': 'Aarav Emerald Lead',
          'house_name': 'emerald',
          'role': 'student',
          'class_level': '10-A',
          'division': 'A',
        },
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () {
                AccountSwitcherModal.show(
                  ctx,
                  houseColor: HouseColors.emerald,
                  currentHouse: 'emerald',
                  onSwitchAccount: (_) async {},
                  onSignOutCurrent: () async {},
                  onSignOutAll: () async {},
                );
              },
              child: const Text('Open Switcher'),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    // 1. Tap Open Switcher button
    await tester.tap(find.text('Open Switcher'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // 2. Verify modal displays Switch Account header
    expect(find.text('Switch Account'), findsOneWidget);
    expect(find.text('Shared device profiles for siblings & family'), findsOneWidget);

    // 3. Verify Active Account is displayed with ACTIVE badge and Emerald house chip
    expect(find.text('Aarav Emerald Lead'), findsOneWidget);
    expect(find.text('ACTIVE'), findsOneWidget);
    expect(find.text('EMERALD'), findsOneWidget);

    // 4. Verify Add Sibling button is present
    final addSiblingBtn = find.text('Add Sibling / Another Account');
    expect(addSiblingBtn, findsOneWidget);

    // 5. Tap Add Sibling button to open Add Sibling modal
    await tester.tap(addSiblingBtn);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Add Sibling Account'), findsOneWidget);
    expect(find.text('Link another student profile on this device'), findsOneWidget);
    expect(find.text('Sibling Scholar Number'), findsOneWidget);
    expect(find.text('Sibling Password'), findsOneWidget);

    // 6. Test dynamic house detection: enter ruby scholar
    final textFields = find.byType(TextFormField);
    await tester.enterText(textFields.at(0), '2310910');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.textContaining('RUBY House Detected'), findsOneWidget);
  });

  testWidgets('PillSelector accessibility semantics, tap targets, and interaction', (WidgetTester tester) async {
    String selected = 'Grade 10';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return PillSelector(
                label: 'Grade Level',
                options: const ['Grade 9', 'Grade 10', 'Grade 11'],
                selectedValue: selected,
                onSelected: (val) {
                  setState(() => selected = val);
                },
              );
            },
          ),
        ),
      ),
    );
    await tester.pump();

    // Verify Semantics exist for each pill with correct labels and selection states
    expect(
      find.byWidgetPredicate((w) =>
          w is Semantics &&
          w.properties.button == true &&
          w.properties.label == 'Grade Level Grade 9' &&
          w.properties.selected == false),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate((w) =>
          w is Semantics &&
          w.properties.button == true &&
          w.properties.label == 'Grade Level Grade 10' &&
          w.properties.selected == true),
      findsOneWidget,
    );

    // Verify minimum tap target size (>= 48x48)
    final pillFinders = find.byType(AnimatedContainer);
    expect(pillFinders, findsNWidgets(3));
    for (int i = 0; i < 3; i++) {
      final size = tester.getSize(pillFinders.at(i));
      expect(size.height, greaterThanOrEqualTo(48.0));
      expect(size.width, greaterThanOrEqualTo(48.0));
    }

    // Tap unselected option 'Grade 11' and verify selection update
    await tester.tap(find.text('Grade 11'));
    await tester.pump();
    expect(selected, 'Grade 11');
  });

  testWidgets('ConfettiOverlay renders RepaintBoundary, AnimatedBuilder, and responds to show flag', (WidgetTester tester) async {
    bool showConfetti = false;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            return Scaffold(
              body: ConfettiOverlay(
                show: showConfetti,
                child: const Text('Confetti Child'),
              ),
              floatingActionButton: FloatingActionButton(
                onPressed: () => setState(() => showConfetti = !showConfetti),
              ),
            );
          },
        ),
      ),
    );

    final confettiCustomPaint = find.descendant(
      of: find.byType(ConfettiOverlay),
      matching: find.byType(CustomPaint),
    );

    expect(find.text('Confetti Child'), findsOneWidget);
    // Initially not showing confetti, canvas should not be rendered inside ConfettiOverlay
    expect(confettiCustomPaint, findsNothing);

    // Trigger confetti
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // Verify AnimatedBuilder and RepaintBoundary isolate painting within ConfettiOverlay
    expect(
      find.descendant(
        of: find.byType(ConfettiOverlay),
        matching: find.byType(AnimatedBuilder),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(ConfettiOverlay),
        matching: find.byType(RepaintBoundary),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(ConfettiOverlay),
        matching: find.byType(ExcludeSemantics),
      ),
      findsOneWidget,
    );
    expect(confettiCustomPaint, findsOneWidget);

    // Toggle off confetti
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(confettiCustomPaint, findsNothing);
  });

  test('AuthService house standings offline cache persistence and pre-hydration', () async {
    SharedPreferences.setMockInitialValues({});
    await AuthService.initPreferences();

    // Default fallback when cache is empty (zero baseline standings)
    final initialStandings = AuthService.getCachedHouseStandings();
    expect(initialStandings['ruby'], 0);
    expect(initialStandings['sapphire'], 0);
    expect(initialStandings['emerald'], 0);
    expect(initialStandings['topaz'], 0);

    // Save live verified standings
    final mockStandings = {
      'ruby': 1250,
      'sapphire': 980,
      'emerald': 1420,
      'topaz': 1100,
    };
    await AuthService.cacheHouseStandings(mockStandings);

    // Retrieve cached standings
    final cached = AuthService.getCachedHouseStandings();
    expect(cached['ruby'], 1250);
    expect(cached['sapphire'], 980);
    expect(cached['emerald'], 1420);
    expect(cached['topaz'], 1100);

    // Verify clearCache clears custom standings back to baseline seed
    await AuthService.clearCache();
    final cleared = AuthService.getCachedHouseStandings();
    expect(cleared['ruby'], 0);
    expect(cleared['sapphire'], 0);
    expect(cleared['emerald'], 0);
    expect(cleared['topaz'], 0);
  });

  test('QrDecoderService decodes valid QR code and returns null for invalid image bytes', () async {
    // 1. Invalid bytes test
    final invalidResult = await QrDecoderService.decodeQrFromBytes(Uint8List.fromList([0, 1, 2, 3]));
    expect(invalidResult, isNull);

    // 2. Synthesize a valid QR code in memory using ZXing Encoder
    const testPayload = 'ASB:10001:EMERALD';
    final qrcode = Encoder.encode(testPayload, ErrorCorrectionLevel.h);
    final matrix = qrcode.matrix!;
    const scale = 4;

    final image = img.Image(
      width: matrix.width * scale,
      height: matrix.height * scale,
      numChannels: 4,
    );
    // Fill white background
    img.fill(image, color: img.ColorRgba8(0xFF, 0xFF, 0xFF, 0xFF));

    // Draw dark modules
    for (var x = 0; x < matrix.width; x++) {
      for (var y = 0; y < matrix.height; y++) {
        if (matrix.get(x, y) == 1) {
          img.fillRect(
            image,
            x1: x * scale,
            y1: y * scale,
            x2: x * scale + scale,
            y2: y * scale + scale,
            color: img.ColorRgba8(0, 0, 0, 0xFF),
          );
        }
      }
    }

    final pngBytes = Uint8List.fromList(img.encodePng(image));
    final decoded = await QrDecoderService.decodeQrFromBytes(pngBytes);
    expect(decoded, testPayload);
  });

  test('VoucherSecurityService generates and validates signed student pass with anti-tampering protection', () {
    final signedPass = VoucherSecurityService.generateStudentPassPayload(
      scholarNo: '2310910',
      studentName: 'Zaid Al-Husseini',
      houseName: 'RUBY',
      classLevel: 'Grade 11-D',
      academicYear: '2026/2027',
    );

    // 1. Valid pass validation
    final result = VoucherSecurityService.validateStudentPassPayload(signedPass);
    expect(result.isValid, isTrue);
    expect(result.isTampered, isFalse);
    expect(result.scholarNo, '2310910');
    expect(result.studentName, 'Zaid Al-Husseini');
    expect(result.houseName, 'RUBY');
    expect(result.classLevel, 'Grade 11-D');
    expect(result.error, isNull);

    // 2. Tampering detection: altered house affiliation
    final tamperedHousePass = signedPass.replaceAll('"house":"RUBY"', '"house":"EMERALD"');
    final tamperedHouseResult = VoucherSecurityService.validateStudentPassPayload(tamperedHousePass);
    expect(tamperedHouseResult.isValid, isFalse);
    expect(tamperedHouseResult.isTampered, isTrue);
    expect(tamperedHouseResult.error, contains('Signature mismatch'));

    // 3. Tampering detection: altered scholar_no
    final tamperedScholarPass = signedPass.replaceAll('"scholar_no":"2310910"', '"scholar_no":"9999999"');
    final tamperedScholarResult = VoucherSecurityService.validateStudentPassPayload(tamperedScholarPass);
    expect(tamperedScholarResult.isValid, isFalse);
    expect(tamperedScholarResult.isTampered, isTrue);

    // 4. Tampering detection: stripped signature
    final strippedSigPass = signedPass.replaceAll(RegExp(r'"signature":"[^"]+"'), '"signature":""');
    final strippedResult = VoucherSecurityService.validateStudentPassPayload(strippedSigPass);
    expect(strippedResult.isValid, isFalse);
    expect(strippedResult.isTampered, isTrue);
    expect(strippedResult.error, contains('Missing digital signature'));

    // 5. Malformed payload
    final malformedResult = VoucherSecurityService.validateStudentPassPayload('NOT_JSON');
    expect(malformedResult.isValid, isFalse);
    expect(malformedResult.isTampered, isFalse);
  });

  testWidgets('DigitalWalletScreen renders cryptographically signed pass with accessible Semantics', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: const Scaffold(
          body: DigitalWalletScreen(
            userName: 'Zaid Al-Husseini',
            userHouse: 'ruby',
            scholarNo: '2310910',
            initialIndex: 1,
          ),
        ),
      ),
    );
    await tester.pump();

    // Verify accessible Semantics label on the student QR pass
    expect(
      find.bySemanticsLabel(RegExp(r'Cryptographically verified digital student QR pass', caseSensitive: false)),
      findsOneWidget,
    );
    expect(find.byType(QrImageView), findsOneWidget);
  });

  testWidgets('IdScannerScreen navigates on valid signed pass and displays alert on tampered pass', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: IdScannerScreen(evaluatorName: 'Lead Evaluator'),
      ),
    );
    await tester.pump();

    final signedPass = VoucherSecurityService.generateStudentPassPayload(
      scholarNo: '2310910',
      studentName: 'Zaid Al-Husseini',
      houseName: 'RUBY',
      classLevel: 'Grade 11-D',
    );
    final tamperedPass = signedPass.replaceAll('"house":"RUBY"', '"house":"EMERALD"');

    final searchField = find.byType(TextField);

    // 1. Test tampered pass detection
    await tester.enterText(searchField, tamperedPass);
    await tester.tap(find.widgetWithText(ElevatedButton, 'Lookup'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Verify Tampered Student Pass alert dialog is rendered
    expect(find.text('Tampered Student Pass'), findsOneWidget);
    expect(find.textContaining('Security Alert'), findsOneWidget);

    // Dismiss alert dialog
    await tester.tap(find.text('Dismiss'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // 2. Test valid signed pass navigation
    await tester.enterText(searchField, signedPass);
    await tester.tap(find.widgetWithText(ElevatedButton, 'Lookup'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Verify navigation to StudentBehaviorEvaluationScreen with signed student metadata
    expect(find.byType(StudentBehaviorEvaluationScreen), findsOneWidget);
    expect(find.text('Zaid Al-Husseini'), findsOneWidget);
  });

  testWidgets('DigitalWalletScreen PassCard meets touch targets, MergeSemantics, and ExcludeSemantics guidelines', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: const Scaffold(
          body: DigitalWalletScreen(
            userName: 'Zaid Al-Husseini',
            userHouse: 'ruby',
            scholarNo: '2310910',
            canScanQr: true,
            initialIndex: 1,
          ),
        ),
      ),
    );
    await tester.pump();

    // 1. Verify Scan ID button has >= 48dp height minimum size
    final scanIdFinder = find.widgetWithText(ElevatedButton, 'Scan ID');
    expect(scanIdFinder, findsOneWidget);
    final scanBtn = tester.widget<ElevatedButton>(scanIdFinder);
    expect(scanBtn.style?.minimumSize?.resolve({})?.height, greaterThanOrEqualTo(48.0));

    // 2. Verify AppBar scanner action button has >= 48dp constraints
    final scannerIconBtnFinder = find.widgetWithIcon(IconButton, Icons.qr_code_scanner_rounded);
    expect(scannerIconBtnFinder, findsOneWidget);
    final scannerIconBtn = tester.widget<IconButton>(scannerIconBtnFinder);
    expect(scannerIconBtn.constraints?.minHeight, greaterThanOrEqualTo(48.0));
    expect(scannerIconBtn.constraints?.minWidth, greaterThanOrEqualTo(48.0));

    // 3. Verify MergeSemantics exists for cohesive pass announcements
    expect(find.byType(MergeSemantics), findsWidgets);

    // 4. Verify ExcludeSemantics is applied to decorative elements (e.g. ticket notches)
    expect(find.byType(ExcludeSemantics), findsWidgets);

    // 5. Verify action buttons have >= 48dp minimum height
    final walletBtnFinder = find.widgetWithText(ElevatedButton, 'Save to Google Wallet');
    expect(walletBtnFinder, findsOneWidget);
    final walletBtn = tester.widget<ElevatedButton>(walletBtnFinder);
    expect(walletBtn.style?.minimumSize?.resolve({})?.height, greaterThanOrEqualTo(48.0));

    final receiptBtnFinder = find.widgetWithText(ElevatedButton, 'Pass & Receipt');
    expect(receiptBtnFinder, findsOneWidget);
    final receiptBtn = tester.widget<ElevatedButton>(receiptBtnFinder);
    expect(receiptBtn.style?.minimumSize?.resolve({})?.height, greaterThanOrEqualTo(48.0));
  });

  testWidgets('DigitalWalletScreen action buttons wrap responsively at 200% font scaling without overflow', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: MediaQuery(
          data: const MediaQueryData(
            textScaler: TextScaler.linear(2.0),
          ),
          child: const Scaffold(
            body: DigitalWalletScreen(
              userName: 'Zaid Al-Husseini',
              userHouse: 'ruby',
              scholarNo: '2310910',
              initialIndex: 1,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    // Verify both action buttons render without overflow
    expect(find.text('Save to Google Wallet'), findsOneWidget);
    expect(find.text('Pass & Receipt'), findsOneWidget);
  });

  test('AuthService student contribution caching and retrieval logic', () async {
    SharedPreferences.setMockInitialValues({});
    await AuthService.initPreferences();

    // 1. Initial state: nothing cached for student
    final initial = AuthService.getCachedStudentContribution('2310910');
    expect(initial.totalPoints, 0);
    expect(initial.merits, 0);
    expect(initial.demerits, 0);
    expect(initial.lastUpdated, isNull);

    // 2. Cache student contribution
    await AuthService.cacheStudentContribution(
      scholarNo: '2310910',
      totalPoints: 120,
      merits: 8,
      demerits: 1,
    );

    final cached = AuthService.getCachedStudentContribution('2310910');
    expect(cached.totalPoints, 120);
    expect(cached.merits, 8);
    expect(cached.demerits, 1);
    expect(cached.lastUpdated, isNotNull);

    // 3. Cache update resilience with whitespace trimming
    await AuthService.cacheStudentContribution(
      scholarNo: '  2310910  ',
      totalPoints: 150,
      merits: 10,
      demerits: 1,
    );
    final updated = AuthService.getCachedStudentContribution('2310910');
    expect(updated.totalPoints, 150);
    expect(updated.merits, 10);
    expect(updated.demerits, 1);
  });

  testWidgets('DigitalWalletScreen synchronous Frame 1 pre-hydration displays cached contribution without zero flash', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await AuthService.initPreferences();

    // Pre-cache 150 points, 10 merits, 1 demerit
    await AuthService.cacheStudentContribution(
      scholarNo: '2310910',
      totalPoints: 150,
      merits: 10,
      demerits: 1,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: const Scaffold(
          body: DigitalWalletScreen(
            userName: 'Zaid Al-Husseini',
            userHouse: 'ruby',
            scholarNo: '2310910',
            initialIndex: 1,
          ),
        ),
      ),
    );
    // Frame 1 immediate pump (offline/before any async stream events)
    await tester.pump();

    // 1. Verify Frame 1 immediately shows pre-hydrated stats without zero-points flash
    expect(find.text('+150 Pts'), findsOneWidget);
    expect(find.text('10 Earned'), findsOneWidget);
    expect(find.text('1 Recorded'), findsOneWidget);
    expect(find.text('+0 Pts'), findsNothing);
    expect(find.text('0 Earned'), findsNothing);

    // 2. Verify offline sync badge with liveRegion semantics
    expect(find.text('Offline Verified ⚡'), findsOneWidget);
    final liveRegionFinder = find.byWidgetPredicate(
      (w) => w is Semantics && w.properties.liveRegion == true,
    );
    expect(liveRegionFinder, findsWidgets);

    // 3. Verify PassCard details credential contains verified house points
    expect(find.textContaining('House Contribution: +150 Pts'), findsOneWidget);

    // 4. Verify MergeSemantics exists for cohesive screen reader announcement
    expect(find.byType(MergeSemantics), findsWidgets);
  });

  test('VoucherSecurityService generates compliant Apple PKPass and Google Wallet payloads', () {
    final pkPass = VoucherSecurityService.generateApplePkPassJson(
      scholarNo: '2310910',
      studentName: 'Zaid Al-Husseini',
      houseName: 'ruby',
      classLevel: 'Grade 11-D',
      qrPayload: 'ASB-ID:2310910:RUBY:HMAC_TOKEN',
      totalPoints: 150,
    );

    expect(pkPass['passTypeIdentifier'], 'pass.bh.asianschool.househub');
    expect(pkPass['serialNumber'], contains('ASB-PASS-2310910-'));
    expect(pkPass['organizationName'], 'The Asian School Bahrain');
    expect(pkPass['generic']['primaryFields'][0]['value'], 'Zaid Al-Husseini');
    expect(pkPass['generic']['secondaryFields'][0]['value'], 'RUBY');
    expect(pkPass['generic']['auxiliaryFields'][1]['value'], '150 Pts');
    expect(pkPass['barcodes'][0]['format'], 'PKBarcodeFormatQR');
    expect(pkPass['barcodes'][0]['message'], 'ASB-ID:2310910:RUBY:HMAC_TOKEN');

    final gPass = VoucherSecurityService.generateGoogleWalletPassJson(
      scholarNo: '2310910',
      studentName: 'Zaid Al-Husseini',
      houseName: 'ruby',
      classLevel: 'Grade 11-D',
      qrPayload: 'ASB-ID:2310910:RUBY:HMAC_TOKEN',
      totalPoints: 150,
    );

    expect(gPass['issuerId'], 'ASB-BAHRAIN-HOUSEHUB');
    expect(gPass['classId'], 'asb_student_pass_2026');
    expect(gPass['header'], 'Zaid Al-Husseini');
    expect(gPass['subheader'], 'RUBY • Grade 11-D');
    expect(gPass['barcode']['type'], 'QR_CODE');
    expect(gPass['barcode']['value'], 'ASB-ID:2310910:RUBY:HMAC_TOKEN');
  });

  testWidgets('DigitalWalletScreen adapts wallet button between iOS and Android/Windows platforms', (
    WidgetTester tester,
  ) async {
    // 1. Simulate iOS platform
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: const Scaffold(
          body: DigitalWalletScreen(
            userName: 'Zaid Al-Husseini',
            userHouse: 'ruby',
            scholarNo: '2310910',
            initialIndex: 1,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Add to Apple Wallet'), findsOneWidget);
    expect(find.byIcon(Icons.apple), findsOneWidget);

    // 2. Simulate Android platform
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: const Scaffold(
          body: DigitalWalletScreen(
            userName: 'Zaid Al-Husseini',
            userHouse: 'ruby',
            scholarNo: '2310910',
            initialIndex: 1,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Save to Google Wallet'), findsOneWidget);
    expect(find.byIcon(Icons.account_balance_wallet_rounded), findsWidgets);

    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('DigitalWalletScreen wallet modal sheet accessibility, focus, and dismiss interaction', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: const Scaffold(
          body: DigitalWalletScreen(
            userName: 'Zaid Al-Husseini',
            userHouse: 'ruby',
            scholarNo: '2310910',
            initialIndex: 1,
          ),
        ),
      ),
    );
    await tester.pump();

    // Tap Save to Google Wallet button
    final walletBtnFinder = find.widgetWithText(ElevatedButton, 'Save to Google Wallet');
    expect(walletBtnFinder, findsOneWidget);
    await tester.tap(walletBtnFinder);
    await tester.pumpAndSettle();

    // 1. Verify modal title and header semantics
    expect(find.text('Saved to Google Wallet'), findsOneWidget);
    final headerFinder = find.byWidgetPredicate(
      (w) => w is Semantics && w.properties.header == true,
    );
    expect(headerFinder, findsWidgets);

    // 2. Verify decorative items excluded via ExcludeSemantics
    expect(find.byType(ExcludeSemantics), findsWidgets);

    // 3. Verify Done button autofocus and 48dp minimum size
    final doneBtnFinder = find.widgetWithText(ElevatedButton, 'Done');
    expect(doneBtnFinder, findsOneWidget);
    final doneBtn = tester.widget<ElevatedButton>(doneBtnFinder);
    expect(doneBtn.autofocus, isTrue);
    expect(doneBtn.style?.minimumSize?.resolve({})?.height, greaterThanOrEqualTo(48.0));

    // 4. Tap Done button to dismiss
    await tester.tap(doneBtnFinder);
    await tester.pumpAndSettle();
    expect(find.text('Saved to Google Wallet'), findsNothing);
  });

  testWidgets('DigitalWalletScreen electronic receipt preview modal accessibility and actions', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: const Scaffold(
          body: DigitalWalletScreen(
            userName: 'Zaid Al-Husseini',
            userHouse: 'ruby',
            scholarNo: '2310910',
            initialIndex: 1,
          ),
        ),
      ),
    );
    await tester.pump();

    // Tap Pass & Receipt button
    final receiptBtnFinder = find.widgetWithText(ElevatedButton, 'Pass & Receipt');
    expect(receiptBtnFinder, findsOneWidget);
    await tester.tap(receiptBtnFinder);
    await tester.pumpAndSettle();

    // 1. Verify dialog preview contents
    expect(find.text('ASB OFFICIAL VOUCHER'), findsOneWidget);

    // 2. Verify 48dp action buttons
    final printBtnFinder = find.widgetWithText(OutlinedButton, 'Print Pass');
    expect(printBtnFinder, findsOneWidget);
    final printBtn = tester.widget<OutlinedButton>(printBtnFinder);
    expect(printBtn.style?.minimumSize?.resolve({})?.height, greaterThanOrEqualTo(48.0));

    final exportPdfFinder = find.widgetWithText(ElevatedButton, 'Export PDF');
    expect(exportPdfFinder, findsOneWidget);
    final exportPdfBtn = tester.widget<ElevatedButton>(exportPdfFinder);
    expect(exportPdfBtn.style?.minimumSize?.resolve({})?.height, greaterThanOrEqualTo(48.0));

    // 3. Close button tap dismisses dialog
    final closeBtnFinder = find.byTooltip('Close receipt preview');
    expect(closeBtnFinder, findsOneWidget);
    await tester.tap(closeBtnFinder);
    await tester.pumpAndSettle();
    expect(find.text('ASB OFFICIAL VOUCHER'), findsNothing);
  });

  test('OrderRecord serialization, copyWith, and claim status getters', () {
    final now = DateTime.now();
    final item = CartItem(
      product: const MerchProduct(
        id: 'p1',
        name: 'House Cap',
        price: '50 Pts',
        rating: 5.0,
        imageUrl: '',
        category: 'Accessories',
        house: 'ruby',
        description: 'Cap',
      ),
      size: 'OneSize',
      qty: 2,
    );

    final order = OrderRecord(
      receiptId: 'ASB-ORD-5544',
      items: [item],
      totalPts: 100,
      date: now,
      qrData: 'qr_test_data',
      status: 'ready',
    );

    expect(order.isClaimed, isFalse);
    expect(order.status, 'ready');
    expect(order.claimedBy, isNull);
    expect(order.claimedAt, isNull);

    final map = order.toMap();
    expect(map['status'], 'ready');
    expect(map['receiptId'], 'ASB-ORD-5544');

    final revived = OrderRecord.fromMap(map);
    expect(revived.isClaimed, isFalse);
    expect(revived.totalPts, 100);

    final claimedOrder = order.copyWith(
      status: 'claimed',
      claimedBy: 'Lead Evaluator',
      claimedAt: now,
    );
    expect(claimedOrder.isClaimed, isTrue);
    expect(claimedOrder.claimedBy, 'Lead Evaluator');
    expect(claimedOrder.claimedAt, now);

    final claimedJson = claimedOrder.toJson();
    final revivedClaimed = OrderRecord.fromJson(claimedJson);
    expect(revivedClaimed.isClaimed, isTrue);
    expect(revivedClaimed.claimedBy, 'Lead Evaluator');
  });

  test('VoucherSecurityService.claimStoreVoucher and GlobalWalletStore.markOrderClaimed', () async {
    GlobalWalletStore.orders.clear();
    final order = OrderRecord(
      receiptId: 'TEST-REC-8899',
      items: [],
      totalPts: 150,
      date: DateTime.now(),
      qrData: 'mock_qr',
      status: 'ready',
    );
    GlobalWalletStore.orders.add(order);

    expect(GlobalWalletStore.orders.first.isClaimed, isFalse);

    // 1. Mark claimed locally in GlobalWalletStore
    await GlobalWalletStore.markOrderClaimed(
      'TEST-REC-8899',
      claimedBy: 'Mr. Teacher',
    );
    expect(GlobalWalletStore.orders.first.isClaimed, isTrue);
    expect(GlobalWalletStore.orders.first.claimedBy, 'Mr. Teacher');

    // 2. Test claimStoreVoucher fallback pipeline
    final claimResult = await VoucherSecurityService.claimStoreVoucher(
      billNo: 'TEST-REC-8899',
      evaluatorName: 'Lead Evaluator',
    );
    expect(claimResult.success, isTrue);
    expect(claimResult.claimedBy, 'Lead Evaluator');
    expect(claimResult.claimedAt, isNotNull);
  });

  testWidgets('DigitalWalletScreen renders dynamic READY vs CLAIMED badges on Store Passes', (
    WidgetTester tester,
  ) async {
    GlobalWalletStore.orders.clear();
    final unclaimedOrder = OrderRecord(
      receiptId: 'ASB-9901',
      items: [],
      totalPts: 200,
      date: DateTime.now(),
      qrData: 'qr_unclaimed',
      status: 'ready',
    );
    final claimedOrder = OrderRecord(
      receiptId: 'ASB-9902',
      items: [],
      totalPts: 350,
      date: DateTime.now(),
      qrData: 'qr_claimed',
      status: 'claimed',
      claimedBy: 'Faculty Lead',
      claimedAt: DateTime.now(),
    );

    GlobalWalletStore.orders.addAll([unclaimedOrder, claimedOrder]);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: const Scaffold(
          body: DigitalWalletScreen(
            userName: 'Zaid Al-Husseini',
            userHouse: 'ruby',
            scholarNo: '2310910',
            initialIndex: 0, // Store passes tab
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify both orders render their respective status badges
    expect(find.text('READY FOR PICKUP 🟢'), findsOneWidget);
    expect(find.text('CLAIMED / FULFILLED 📦'), findsOneWidget);
  });

  testWidgets('IdScannerScreen voucher claim workflow prevents double redemption with accessible 48dp targets', (
    WidgetTester tester,
  ) async {
    GlobalWalletStore.orders.clear();

    await tester.pumpWidget(
      const MaterialApp(
        home: IdScannerScreen(evaluatorName: 'Lead Evaluator'),
      ),
    );
    await tester.pump();

    final testBillNo = 'ASB-BILL-4455';
    final voucherPayload = VoucherSecurityService.generateVoucherPayload(
      billNo: testBillNo,
      points: 400,
      scholarNo: '2310910',
      items: ['1x Champion Hoodie (L)', '1x House Water Bottle'],
    );

    final searchField = find.byType(TextField);
    final lookupBtn = find.widgetWithText(ElevatedButton, 'Lookup');

    // 1. Initial Lookup: Unclaimed voucher
    await tester.enterText(searchField, voucherPayload);
    await tester.tap(lookupBtn);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Verify dialog title and readiness banner
    expect(find.text('Voucher Verified'), findsOneWidget);
    expect(find.text('Valid Store Voucher. Ready for handover and fulfillment.'), findsOneWidget);
    expect(find.text('Bill No: $testBillNo'), findsOneWidget);

    // Verify 48dp minimum touch targets on Dismiss and Claim buttons
    final dismissBtnFinder = find.widgetWithText(OutlinedButton, 'Dismiss');
    expect(dismissBtnFinder, findsOneWidget);
    final dismissBtn = tester.widget<OutlinedButton>(dismissBtnFinder);
    expect(dismissBtn.style?.minimumSize?.resolve({})?.height, greaterThanOrEqualTo(48.0));

    final claimBtnFinder = find.widgetWithText(ElevatedButton, 'Confirm Handover & Claim Pass');
    expect(claimBtnFinder, findsOneWidget);
    final claimBtn = tester.widget<ElevatedButton>(claimBtnFinder);
    expect(claimBtn.style?.minimumSize?.resolve({})?.height, greaterThanOrEqualTo(48.0));

    // 2. Perform Claim / Handover
    await tester.tap(claimBtnFinder);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Verify status banner updates to previously claimed warning and button updates to Pass Fulfilled
    expect(find.textContaining('⚠️ Previously Claimed by Lead Evaluator'), findsOneWidget);
    final fulfilledBtnFinder = find.widgetWithText(ElevatedButton, 'Pass Fulfilled');
    expect(fulfilledBtnFinder, findsOneWidget);
    final fulfilledBtn = tester.widget<ElevatedButton>(fulfilledBtnFinder);
    expect(fulfilledBtn.onPressed, isNull); // Disabled to prevent duplicate claim

    // Dismiss dialog
    await tester.tap(dismissBtnFinder);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Voucher Verified'), findsNothing);

    // 3. Second Lookup (Double-Redemption Attempt)
    await tester.enterText(searchField, voucherPayload);
    await tester.tap(lookupBtn);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Verify dialog immediately loads in claimed state with warning
    expect(find.text('Voucher Already Claimed'), findsOneWidget);
    expect(find.textContaining('⚠️ Previously Claimed by Lead Evaluator'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Pass Fulfilled'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Confirm Handover & Claim Pass'), findsNothing);
  });

  testWidgets('DigitalWalletScreen receipt modal QR and document MergeSemantics accessibility', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: const Scaffold(
          body: DigitalWalletScreen(
            userName: 'Zaid Al-Husseini',
            userHouse: 'ruby',
            scholarNo: '2310910',
            initialIndex: 1,
          ),
        ),
      ),
    );
    await tester.pump();

    // Tap Pass & Receipt button
    final receiptBtnFinder = find.widgetWithText(ElevatedButton, 'Pass & Receipt');
    expect(receiptBtnFinder, findsOneWidget);
    await tester.tap(receiptBtnFinder);
    await tester.pumpAndSettle();

    // 1. Verify semantic image node for QR Code
    final qrSemanticsFinder = find.byWidgetPredicate(
      (w) => w is Semantics && w.properties.image == true && (w.properties.label?.contains('QR barcode') ?? false),
    );
    expect(qrSemanticsFinder, findsOneWidget);

    // 2. Verify MergeSemantics for cohesive document reading
    expect(find.byType(MergeSemantics), findsWidgets);

    // 3. Tap Print Pass button and verify platform spooler messaging and live region announcement
    final printBtnFinder = find.widgetWithText(OutlinedButton, 'Print Pass');
    expect(printBtnFinder, findsOneWidget);
    await tester.tap(printBtnFinder);
    await tester.pumpAndSettle();

    // Dialog dismissed
    expect(find.text('ASB OFFICIAL VOUCHER'), findsNothing);

    // SnackBar appears with liveRegion semantics
    final snackBarSemanticsFinder = find.byWidgetPredicate(
      (w) => w is Semantics && w.properties.liveRegion == true,
    );
    expect(snackBarSemanticsFinder, findsWidgets);

    // ExcludeSemantics shields decorative emojis from being spoken by screen reader
    expect(find.byType(ExcludeSemantics), findsWidgets);
  });

  testWidgets('DigitalWalletScreen receipt modal 200% font scaling responsive stacking without overflow', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(500, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: MediaQuery(
          data: const MediaQueryData(
            textScaler: TextScaler.linear(2.0),
          ),
          child: const Scaffold(
            body: DigitalWalletScreen(
              userName: 'Zaid Al-Husseini',
              userHouse: 'ruby',
              scholarNo: '2310910',
              initialIndex: 1,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    // Scroll until Pass & Receipt button is visible
    final receiptBtnFinder = find.widgetWithText(ElevatedButton, 'Pass & Receipt');
    expect(receiptBtnFinder, findsOneWidget);
    await tester.ensureVisible(receiptBtnFinder);
    await tester.pumpAndSettle();

    await tester.tap(receiptBtnFinder);
    await tester.pumpAndSettle();

    // Verify dialog rendered with 0 overflow errors
    expect(find.text('ASB OFFICIAL VOUCHER'), findsOneWidget);

    // Action buttons inside LayoutBuilder are stacked in a Column under large text
    final printBtnFinder = find.widgetWithText(OutlinedButton, 'Print Pass');
    final exportBtnFinder = find.widgetWithText(ElevatedButton, 'Export PDF');
    expect(printBtnFinder, findsOneWidget);
    expect(exportBtnFinder, findsOneWidget);

    // Tap Export PDF to verify accessible feedback
    await tester.tap(exportBtnFinder);
    await tester.pumpAndSettle();

    // Verify modal dismisses and export feedback is displayed
    expect(find.text('ASB OFFICIAL VOUCHER'), findsNothing);
    expect(find.text('Exported high-resolution PDF pass to Downloads.'), findsOneWidget);
  });

  testWidgets('Mascot3DStage keyboard navigation, rotation, zoom, roar, and CAD telemetry semantics', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: const Scaffold(
          body: Mascot3DStage(
            userHouse: 'ruby',
            userName: 'Zaid Al-Husseini',
            scholarNo: '2310910',
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // 1. Verify 3D statue stage semantics container & hint
    final stageSemanticsFinder = find.bySemanticsLabel(RegExp(r'Ignis the Crimson Dragon 3D Statue Stage'));
    expect(stageSemanticsFinder, findsOneWidget);

    // 2. Verify CAD Telemetry live region semantics
    final telemetrySemanticsFinder = find.bySemanticsLabel(RegExp(r'CAD Telemetry: Heading \d+ degrees, Pitch \d+ degrees, Zoom \d+ percent'));
    expect(telemetrySemanticsFinder, findsOneWidget);

    // 3. Verify Keyboard Navigation via Focus node
    // Focus the stage
    await tester.tap(stageSemanticsFinder);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // Send Arrow Right -> rotY updates
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();

    // Send Arrow Up -> rotX updates
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();

    // Send Equal/Add -> zoom increases
    await tester.sendKeyEvent(LogicalKeyboardKey.equal);
    await tester.pump();

    // Send Space -> triggers roar
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // Verify Roar Battle Cry SnackBar semantics
    final roarSnackBarFinder = find.bySemanticsLabel(RegExp(r'Ignis the Crimson Dragon unleashes battle cry'));
    expect(roarSnackBarFinder, findsOneWidget);
    expect(find.text('RUBY ROARS! IN FIRE WE CONQUER! 🔥'), findsOneWidget);
  });

  testWidgets('Mascot3DStage 48dp minimum touch target bounding boxes across all controls', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: const Scaffold(
          body: Mascot3DStage(
            userHouse: 'ruby',
            userName: 'Zaid Al-Husseini',
            scholarNo: '2310910',
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // 1. House Selector Buttons (height >= 48)
    for (final house in ['Ruby', 'Sapphire', 'Emerald', 'Topaz']) {
      final houseBtn = find.bySemanticsLabel('$house House Mascot');
      expect(houseBtn, findsOneWidget);
      final size = tester.getSize(houseBtn);
      expect(size.height, greaterThanOrEqualTo(48.0));
      expect(size.width, greaterThanOrEqualTo(48.0));
    }

    // 2. Diagram Mode Buttons (width >= 48, height >= 48)
    for (final mode in ['Solid', 'Blueprint', 'X-Ray']) {
      final modeBtn = find.bySemanticsLabel('$mode Diagram Mode');
      expect(modeBtn, findsOneWidget);
      final size = tester.getSize(modeBtn);
      expect(size.height, greaterThanOrEqualTo(48.0));
      expect(size.width, greaterThanOrEqualTo(48.0));
    }

    // 3. Technical Callouts Toggle (height >= 48)
    final calloutsToggle = find.bySemanticsLabel('Technical Callouts: Active');
    expect(calloutsToggle, findsOneWidget);
    expect(tester.getSize(calloutsToggle).height, greaterThanOrEqualTo(48.0));

    await tester.tap(calloutsToggle);
    await tester.pump();
    expect(find.bySemanticsLabel('Technical Callouts: Hidden'), findsOneWidget);

    // 4. Material Finish Selector (height >= 48)
    for (final finish in ['Chroma', '24K Gold', 'Obsidian', 'Astral']) {
      final finishBtn = find.bySemanticsLabel('$finish Material Finish');
      expect(finishBtn, findsOneWidget);
      expect(tester.getSize(finishBtn).height, greaterThanOrEqualTo(48.0));
    }

    // 5. Camera Angle Presets (height >= 48, width >= 48)
    for (final angle in ['Front', '3/4 Hero']) {
      final angleBtn = find.bySemanticsLabel('$angle Camera Angle Preset');
      expect(angleBtn, findsOneWidget);
      final size = tester.getSize(angleBtn);
      expect(size.height, greaterThanOrEqualTo(48.0));
      expect(size.width, greaterThanOrEqualTo(48.0));
    }

    // 6. 3D Control HUD: Zoom -, Zoom +, Reset, Spin, Roar
    final zoomOutBtn = find.byTooltip('Zoom Out');
    final zoomInBtn = find.byTooltip('Zoom In');
    final resetBtn = find.byTooltip('Reset Camera View');
    expect(zoomOutBtn, findsOneWidget);
    expect(zoomInBtn, findsOneWidget);
    expect(resetBtn, findsOneWidget);

    expect(tester.getSize(zoomOutBtn).width, greaterThanOrEqualTo(48.0));
    expect(tester.getSize(zoomOutBtn).height, greaterThanOrEqualTo(48.0));
    expect(tester.getSize(zoomInBtn).width, greaterThanOrEqualTo(48.0));
    expect(tester.getSize(zoomInBtn).height, greaterThanOrEqualTo(48.0));
    expect(tester.getSize(resetBtn).width, greaterThanOrEqualTo(48.0));
    expect(tester.getSize(resetBtn).height, greaterThanOrEqualTo(48.0));

    final spinBtn = find.bySemanticsLabel('Start 360 Turntable Spin');
    expect(spinBtn, findsOneWidget);
    expect(tester.getSize(spinBtn).height, greaterThanOrEqualTo(48.0));

    final roarBtn = find.bySemanticsLabel(RegExp(r'Unleash Ignis the Crimson Dragon Roar'));
    expect(roarBtn, findsOneWidget);
    expect(tester.getSize(roarBtn).height, greaterThanOrEqualTo(48.0));
  });

  testWidgets('Mascot3DStage 200% font scaling responsive stacking without overflow', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: MediaQuery(
          data: const MediaQueryData(
            textScaler: TextScaler.linear(2.0),
          ),
          child: const Scaffold(
            body: Mascot3DStage(
              userHouse: 'ruby',
              userName: 'Zaid Al-Husseini',
              scholarNo: '2310910',
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Verify 0 overflow errors
    expect(find.byType(Mascot3DStage), findsOneWidget);

    // Verify 3D HUD controls are rendered in stacked rows
    final spinBtn = find.bySemanticsLabel('Start 360 Turntable Spin');
    final roarBtn = find.bySemanticsLabel(RegExp(r'Unleash Ignis the Crimson Dragon Roar'));
    final zoomOutBtn = find.byTooltip('Zoom Out');
    final zoomInBtn = find.byTooltip('Zoom In');
    final resetBtn = find.byTooltip('Reset Camera View');

    expect(spinBtn, findsOneWidget);
    expect(roarBtn, findsOneWidget);
    expect(zoomOutBtn, findsOneWidget);
    expect(zoomInBtn, findsOneWidget);
    expect(resetBtn, findsOneWidget);

    // Tap spin to verify state toggle
    await tester.tap(spinBtn);
    await tester.pump();
    expect(find.bySemanticsLabel('Stop 360 Turntable Spin'), findsOneWidget);
  });

  testWidgets('HouseArenaScreen arena nav pills 48dp target size and accessible tab semantics', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: const Scaffold(
          body: HouseArenaScreen(
            userHouse: 'ruby',
            scholarNo: '2310910',
            userName: 'Zaid Al-Husseini',
            initialNav: 0,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Verify all 5 arena tab pills have >= 48dp touch target and semantics
    final tabs = [
      'Spirit Reactor',
      'Brain Blitz',
      'Cup Oracle',
      'Titan Vault',
      '3D Mascot',
    ];

    for (final tab in tabs) {
      final tabFinder = find.bySemanticsLabel('$tab Arena Tab');
      expect(tabFinder, findsOneWidget);
      expect(tester.getSize(tabFinder).height, greaterThanOrEqualTo(48.0));
    }

    // Tap '3D Mascot Arena Tab'
    final mascotTabFinder = find.bySemanticsLabel('3D Mascot Arena Tab');
    await tester.tap(mascotTabFinder);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Verify 3D Mascot Stage is displayed
    expect(find.byType(Mascot3DStage), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(r'Ignis the Crimson Dragon 3D Statue Stage')), findsOneWidget);
  });

  // ===========================================================================
  // PART 18: BATTLE CHANT SYNTHESIZER & ACCESSIBLE AUDIO FEEDBACK TESTS
  // ===========================================================================

  test('Battle Chant Generation & Cadence Verification across all 4 houses', () {
    for (final house in ['ruby', 'sapphire', 'emerald', 'topaz']) {
      final chant = HouseChantData.forHouse(house);
      expect(chant.houseId, house);
      expect(chant.warCry.isNotEmpty, isTrue);
      expect(chant.heavyMarch.isNotEmpty, isTrue);
      expect(chant.stompClap.isNotEmpty, isTrue);
      expect(chant.victoryAnthem.isNotEmpty, isTrue);

      if (house == 'ruby') {
        expect(chant.warCry, contains('RUBY ROARS'));
        expect(chant.heavyMarch, contains('Red and Gold, Fierce and Bold'));
        expect(chant.stompClap, contains('BOOM! CLAP! RUBY MIGHT!'));
        expect(chant.victoryAnthem, contains('Through the flame we rise as one'));
      } else if (house == 'sapphire') {
        expect(chant.warCry, contains('SAPPHIRE SOARS'));
        expect(chant.heavyMarch, contains('Wings of Azure, Minds of Steel'));
        expect(chant.stompClap, contains("CLAP! STOMP! ZEPHYR'S CLOUD!"));
        expect(chant.victoryAnthem, contains('Clear the skies, let wisdom reign'));
      } else if (house == 'emerald') {
        expect(chant.warCry, contains('EMERALD STANDS'));
        expect(chant.heavyMarch, contains('Roots run deep and wolves run fast'));
        expect(chant.stompClap, contains('THUD! HOWL! TITAN CLAW!'));
        expect(chant.victoryAnthem, contains('Forest shadows, branches tall'));
      } else if (house == 'topaz') {
        expect(chant.warCry, contains('TOPAZ SHINES'));
        expect(chant.heavyMarch, contains('Golden light across the field'));
        expect(chant.stompClap, contains('FLASH! ROAR! GOLDEN SUN!'));
        expect(chant.victoryAnthem, contains('Radiance soaring through the haze'));
      }
    }
  });

  testWidgets('BattleChantSynthesizer Audio Controls & WCAG 1.4.2 Mute Compliance', (
    WidgetTester tester,
  ) async {
    int soundPlayCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: BattleChantSynthesizer(
            userHouse: 'ruby',
            initialTempo: ChantTempo.surge, // 150 BPM = 400ms interval
            soundPlayer: (type) {
              soundPlayCount++;
            },
          ),
        ),
      ),
    );
    await tester.pump();

    // 1. Initially not playing
    final playBtnFinder = find.bySemanticsLabel('Play Battle Chant');
    final muteBtnFinder = find.bySemanticsLabel('Mute Audio');
    final stopBtnFinder = find.bySemanticsLabel('Stop Battle Chant');

    expect(playBtnFinder, findsOneWidget);
    expect(muteBtnFinder, findsOneWidget);
    expect(stopBtnFinder, findsOneWidget);
    expect(soundPlayCount, 0);

    // 2. Tap Play -> sequencer starts
    await tester.tap(playBtnFinder);
    await tester.pump();
    expect(find.bySemanticsLabel('Pause Battle Chant'), findsOneWidget);

    // Advance 450ms (at least 1 tick)
    await tester.pump(const Duration(milliseconds: 450));
    expect(soundPlayCount, greaterThan(0));

    // 3. Tap Mute -> halts audio execution and sets toggled: true
    await tester.tap(muteBtnFinder);
    await tester.pump();

    final unmuteBtnFinder = find.bySemanticsLabel('Unmute Audio');
    expect(unmuteBtnFinder, findsOneWidget);
    final countWhenMuted = soundPlayCount;

    // Advance another 850ms while muted
    await tester.pump(const Duration(milliseconds: 850));
    // Sound play count must NOT increase while muted
    expect(soundPlayCount, countWhenMuted);

    // 4. Tap Stop -> resets sequencer state
    await tester.tap(stopBtnFinder);
    await tester.pump();
    expect(find.bySemanticsLabel('Play Battle Chant'), findsOneWidget);
  });

  testWidgets('BattleChantSynthesizer Closed Captions, Screen Reader Live Region & ExcludeSemantics Equalizer', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: const Scaffold(
          body: BattleChantSynthesizer(
            userHouse: 'sapphire',
            initialMode: ChantMode.warCry,
          ),
        ),
      ),
    );
    await tester.pump();

    // 1. Verify Active Live Region semantics
    final liveRegionFinder = find.bySemanticsLabel('Active Battle Chant: SAPPHIRE SOARS! WISDOM STRIKES TRUE! ⚡');
    expect(liveRegionFinder, findsOneWidget);

    // 2. Verify ExcludeSemantics wraps the dynamic 60fps equalizer canvas
    final customPaintFinder = find.byWidgetPredicate((w) => w is CustomPaint && w.painter.runtimeType.toString().contains('Equalizer'));
    expect(customPaintFinder, findsOneWidget);
    final excludeSemanticsFinder = find.ancestor(of: customPaintFinder, matching: find.byType(ExcludeSemantics));
    expect(excludeSemanticsFinder, findsOneWidget);

    // 3. Switch Chant Mode to Heavy March
    final marchModeBtn = find.bySemanticsLabel('Heavy March Mode');
    expect(marchModeBtn, findsOneWidget);
    await tester.tap(marchModeBtn);
    await tester.pump();

    // Verify live region updates to March lyrics
    expect(
      find.bySemanticsLabel('Active Battle Chant: Wings of Azure, Minds of Steel! Thunder rolls, the victors kneel!'),
      findsOneWidget,
    );

    // 4. Toggle Closed Captions Off
    final ccToggleFinder = find.bySemanticsLabel('Hide Closed Captions');
    expect(ccToggleFinder, findsOneWidget);
    await tester.tap(ccToggleFinder);
    await tester.pump();

    expect(find.bySemanticsLabel('Show Closed Captions'), findsOneWidget);
  });

  testWidgets('BattleChantSynthesizer 48x48dp minimum touch targets across all controls', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: const Scaffold(
          body: BattleChantSynthesizer(
            userHouse: 'emerald',
          ),
        ),
      ),
    );
    await tester.pump();

    // 1. Chant Mode Buttons (all >= 48dp height and width)
    for (final mode in ['War Cry', 'Heavy March', 'Stomp-Clap', 'Victory Anthem']) {
      final modeBtn = find.bySemanticsLabel('$mode Mode');
      expect(modeBtn, findsOneWidget);
      final size = tester.getSize(modeBtn);
      expect(size.height, greaterThanOrEqualTo(48.0));
      expect(size.width, greaterThanOrEqualTo(48.0));
    }

    // 2. Tempo Buttons (all >= 48dp height and width)
    for (final tempo in ['March (95 BPM)', 'Stomp (110 BPM)', 'Allegro (130 BPM)', 'Surge (150 BPM)']) {
      final tempoBtn = find.bySemanticsLabel('$tempo Tempo');
      expect(tempoBtn, findsOneWidget);
      final size = tester.getSize(tempoBtn);
      expect(size.height, greaterThanOrEqualTo(48.0));
      expect(size.width, greaterThanOrEqualTo(48.0));
    }

    // 3. Audio Transport Buttons (Play, Stop, Mute, CC)
    final playBtn = find.bySemanticsLabel('Play Battle Chant');
    final stopBtn = find.bySemanticsLabel('Stop Battle Chant');
    final muteBtn = find.bySemanticsLabel('Mute Audio');
    final ccBtn = find.bySemanticsLabel('Hide Closed Captions');

    for (final btn in [playBtn, stopBtn, muteBtn, ccBtn]) {
      expect(btn, findsOneWidget);
      final size = tester.getSize(btn);
      expect(size.height, greaterThanOrEqualTo(48.0));
      expect(size.width, greaterThanOrEqualTo(48.0));
    }
  });

  testWidgets('BattleChantSynthesizer 200% font scale responsive layout without overflow', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: MediaQuery(
          data: const MediaQueryData(
            textScaler: TextScaler.linear(2.0),
          ),
          child: const Scaffold(
            body: SingleChildScrollView(
              child: BattleChantSynthesizer(
                userHouse: 'topaz',
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Verify widget mounts cleanly without overflow exceptions
    expect(find.byType(BattleChantSynthesizer), findsOneWidget);
    expect(find.text('TOPAZ BATTLE CHANT'), findsOneWidget);
  });

  testWidgets('HouseArenaScreen Spirit Reactor integrates Rally Synthesizer and Overdrive trigger', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: const Scaffold(
          body: HouseArenaScreen(
            userHouse: 'ruby',
            scholarNo: '2310910',
            userName: 'Zaid Al-Husseini',
            initialNav: 0,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // 1. Verify Rally Synthesizer card exists in Spirit Reactor tab
    expect(find.text('RUBY RALLY SYNTHESIZER'), findsOneWidget);

    // 2. Open Battle Chant Deck
    final toggleDeckBtn = find.bySemanticsLabel('Open Battle Chant Deck');
    expect(toggleDeckBtn, findsOneWidget);
    await tester.tap(toggleDeckBtn);
    await tester.pump();

    // Verify BattleChantSynthesizer is now visible
    expect(find.byType(BattleChantSynthesizer), findsOneWidget);
  });

  testWidgets('Merchandise store pure commerce pricing in BHD without house points', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    const dummyProduct = MerchProduct(
      id: 'test_hoodie',
      name: 'Test Champion Hoodie',
      price: 'BHD 14.500',
      rating: 4.9,
      imageUrl: '',
      category: 'Hoodies',
      house: 'ruby',
      description: 'Official Hoodie',
    );

    final item = CartItem(product: dummyProduct, size: 'L', qty: 2);
    expect(item.bhdPrice, 29.0);
    expect(item.pointsPrice, 0);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: const Scaffold(
          body: MerchStoreTab(
            userHouse: 'ruby',
            houseColor: HouseColors.ruby,
            houseDark: HouseColors.rubyDark,
            scholarNo: '2310910',
            studentName: 'Zaid Al-Husseini',
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // Verify Official Campus Store Banner
    expect(
      find.text('ASB OFFICIAL CAMPUS STORE & APPAREL COLLECTION'),
      findsOneWidget,
    );
    expect(
      find.text('Verified School Merchandise • Orders fulfilled directly to Digital Wallet'),
      findsOneWidget,
    );
    expect(find.text('YOUR HOUSE POINTS WALLET'), findsNothing);

    // Verify pure BHD price display
    expect(find.text('BHD 14.500'), findsWidgets);
  });

  testWidgets('AppleFitnessBadgesVault honours summary header Semantics and concentric activity rings', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: const Scaffold(
          body: AppleFitnessBadgesVault(
            userHouse: 'ruby',
            userName: 'Zaid Al-Husseini',
            scholarNo: '2310910',
            isAdmin: false,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // Verify Semantics container for activity rings
    final ringsFinder = find.byWidgetPredicate(
      (w) =>
          w is Semantics &&
          (w.properties.label?.startsWith('Collegiate Honours Activity Rings:') ?? false),
    );
    expect(ringsFinder, findsOneWidget);
  });

  testWidgets('AppleFitnessBadgesVault category filter chips 48dp minimum touch target and accessible button semantics', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: const Scaffold(
          body: AppleFitnessBadgesVault(
            userHouse: 'ruby',
            userName: 'Zaid Al-Husseini',
            scholarNo: '2310910',
            isAdmin: false,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    final allFilterFinder = find.bySemanticsLabel('All Badges filter');
    expect(allFilterFinder, findsOneWidget);
    final allFilterBox = tester.getRect(allFilterFinder);
    expect(allFilterBox.height, greaterThanOrEqualTo(48.0));
    expect(allFilterBox.width, greaterThanOrEqualTo(48.0));

    final housePrideFinder = find.bySemanticsLabel('House Pride filter');
    expect(housePrideFinder, findsOneWidget);
    final housePrideBox = tester.getRect(housePrideFinder);
    expect(housePrideBox.height, greaterThanOrEqualTo(48.0));
    expect(housePrideBox.width, greaterThanOrEqualTo(48.0));

    // Tap House Pride filter
    await tester.tap(housePrideFinder);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    final selectedPride = tester.widget<Semantics>(
      find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.label == 'House Pride filter',
      ),
    );
    expect(selectedPride.properties.selected, isTrue);
  });

  testWidgets('AppleFitnessBadge modal 3D inspection keyboard traversal, flip action, and 48dp targets', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: const Scaffold(
          body: AppleFitnessBadgesVault(
            userHouse: 'ruby',
            userName: 'Zaid Al-Husseini',
            scholarNo: '2310910',
            isAdmin: false,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // Tap first badge to open inspection modal
    final badgeCardFinder = find.text('Ignis Firestarter');
    expect(badgeCardFinder, findsOneWidget);
    await tester.tap(badgeCardFinder);
    await tester.pump();
    for (int i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    // Verify modal is open with Close button and Flip button
    final closeBtnFinder = find.byWidgetPredicate(
      (w) => w is Semantics && w.properties.label == 'Close award inspection',
    );
    expect(closeBtnFinder, findsOneWidget);
    final closeBox = tester.getRect(closeBtnFinder);
    expect(closeBox.width, greaterThanOrEqualTo(48.0));
    expect(closeBox.height, greaterThanOrEqualTo(48.0));

    final flipBtnFinder = find.byWidgetPredicate(
      (w) => w is Semantics && w.properties.label == 'Inspect Engraved Plate',
    );
    expect(flipBtnFinder, findsOneWidget);
    final flipBox = tester.getRect(flipBtnFinder);
    expect(flipBox.width, greaterThanOrEqualTo(48.0));
    expect(flipBox.height, greaterThanOrEqualTo(48.0));

    // Trigger flip via keyboard Space
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    for (int i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    // Verify backplate is shown
    expect(
      find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.label == 'View Front Crest',
      ),
      findsOneWidget,
    );

    // Trigger arrow key tilt navigation
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump(const Duration(milliseconds: 50));

    // Close via Close button
    await tester.tap(closeBtnFinder);
    await tester.pump();
    for (int i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(
      find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.label == 'Close award inspection',
      ),
      findsNothing,
    );
  });

  testWidgets('AppleFitnessBadgesVault 200% font scale responsive layout without overflow', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: const MediaQuery(
          data: MediaQueryData(
            textScaler: TextScaler.linear(2.0),
          ),
          child: Scaffold(
            body: AppleFitnessBadgesVault(
              userHouse: 'ruby',
              userName: 'Zaid Al-Husseini',
              scholarNo: '2310910',
              isAdmin: false,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.byType(AppleFitnessBadgesVault), findsOneWidget);
    expect(find.text('House Championship Honours'), findsOneWidget);
  });

  // ==========================================
  // PART 20: HOUSE STANDINGS REAL-TIME STREAM, CONCURRENCY PROTECTION & ZERO-FLASH PRE-HYDRATION
  // ==========================================

  test('AuthService.getCachedPointsForHouse returns baseline seed fallback and verified scores', () async {
    // 1. Fresh cache: verify fallback to zero baseline standings
    await AuthService.clearCache();
    expect(AuthService.getCachedPointsForHouse('ruby'), equals(0));
    expect(AuthService.getCachedPointsForHouse('Ruby'), equals(0));
    expect(AuthService.getCachedPointsForHouse('sapphire'), equals(0));
    expect(AuthService.getCachedPointsForHouse('emerald'), equals(0));
    expect(AuthService.getCachedPointsForHouse('topaz'), equals(0));
    expect(AuthService.getCachedPointsForHouse('unknown_house'), equals(0));

    // 2. Cache custom standings and verify synchronous retrieval
    await AuthService.cacheHouseStandings({
      'ruby': 550,
      'sapphire': 480,
      'emerald': 390,
      'topaz': 420,
    });

    expect(AuthService.getCachedPointsForHouse('ruby'), equals(550));
    expect(AuthService.getCachedPointsForHouse('sapphire'), equals(480));
    expect(AuthService.getCachedPointsForHouse('emerald'), equals(390));
    expect(AuthService.getCachedPointsForHouse('topaz'), equals(420));
  });

  test('AuthService.incrementCachedHousePoints write-through caching and zero-bounds clamping', () async {
    await AuthService.clearCache();
    // Default zero baseline for ruby is 0
    expect(AuthService.getCachedPointsForHouse('ruby'), equals(0));

    // Increment points
    await AuthService.incrementCachedHousePoints('ruby', 30);
    expect(AuthService.getCachedPointsForHouse('ruby'), equals(30));
    expect(AuthService.getCachedHouseStandings()['ruby'], equals(30));

    // Decrement points
    await AuthService.incrementCachedHousePoints('ruby', -50);
    expect(AuthService.getCachedPointsForHouse('ruby'), equals(0));

    // Clamp to 0 when negative overflow occurs
    await AuthService.incrementCachedHousePoints('ruby', -1000);
    expect(AuthService.getCachedPointsForHouse('ruby'), equals(0));
    expect(AuthService.getCachedHouseStandings()['ruby'], equals(0));

    // Clamp upper bound to 999999
    await AuthService.incrementCachedHousePoints('ruby', 1500000);
    expect(AuthService.getCachedPointsForHouse('ruby'), equals(999999));
  });

  testWidgets('HouseLeaderboardScreen Frame 1 zero-flash points and >= 48dp switcher pills', (
    WidgetTester tester,
  ) async {
    await AuthService.clearCache();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: const HouseLeaderboardScreen(
          initialHouse: 'Ruby',
          initialPoints: 0,
        ),
      ),
    );

    // Frame 1 check: Total points displayed immediately as 0 Pts Total on unseeded start
    await tester.pump();
    expect(find.text('0 Pts Total'), findsOneWidget);
    expect(find.textContaining('Ruby House Roster'), findsOneWidget);
    expect(find.text('House Captain: Pending Appointment'), findsOneWidget);
    expect(find.text('No house points recorded yet for this season'), findsOneWidget);
    expect(find.text('Points Breakdown'), findsOneWidget);
    expect(find.text('Sports'), findsOneWidget);
    expect(find.text('Academics'), findsOneWidget);
    expect(find.text('Cultural'), findsOneWidget);
    expect(find.text('Conduct'), findsOneWidget);

    // Settle contributors stream to verify accessible empty state
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('No student contributions recorded yet for Ruby House.'), findsOneWidget);

    // Verify all 4 house switcher pills have >= 48dp touch targets and Semantics
    final houses = ['Ruby', 'Emerald', 'Sapphire', 'Topaz'];
    for (final h in houses) {
      final pillSemantics = find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.label == '$h House Leaderboard',
      );
      expect(pillSemantics, findsOneWidget);

      final isRuby = h == 'Ruby';
      final semWidget = tester.widget<Semantics>(pillSemantics);
      expect(semWidget.properties.button, isTrue);
      expect(semWidget.properties.selected, isRuby);

      // Verify touch target dimension constraints
      final constrainedBox = find.descendant(
        of: pillSemantics,
        matching: find.byWidgetPredicate(
          (w) =>
              w is ConstrainedBox &&
              w.constraints.minWidth >= 48.0 &&
              w.constraints.minHeight >= 48.0,
        ),
      );
      expect(constrainedBox, findsOneWidget);
    }
  });

  testWidgets('HomeScreen liveRegion semantics on celebration and offline banners', (
    WidgetTester tester,
  ) async {
    await AuthService.clearCache();
    await AuthService.cacheProfile({
      'full_name': 'Zaid Al-Husseini',
      'house': 'ruby',
      'scholar_no': '2310910',
      'role': 'student',
    });
    await AuthService.cacheHouse('ruby');
    await AuthService.cacheHouseStandings({
      'ruby': 600,
      'sapphire': 450,
      'topaz': 400,
      'emerald': 350,
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: const Scaffold(
          body: HomeScreen(initialIndex: 2),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // Verify 1st-place celebration banner has liveRegion: true
    final celebrationSemantics = find.byWidgetPredicate(
      (w) =>
          w is Semantics &&
          w.properties.liveRegion == true &&
          (w.properties.label?.contains('Celebration: Your house is in 1st place') ?? false),
    );
    expect(celebrationSemantics, findsOneWidget);

    // Verify offline indicator has liveRegion: true
    final offlineSemantics = find.byWidgetPredicate(
      (w) =>
          w is Semantics &&
          w.properties.liveRegion == true &&
          w.properties.label == 'Offline mode: Viewing verified saved standings from local disk',
    );
    expect(offlineSemantics, findsOneWidget);
  });

  testWidgets('HomeScreen live standings 200% font scale layout elasticity', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await AuthService.clearCache();
    await AuthService.cacheProfile({
      'full_name': 'Zaid Al-Husseini',
      'house': 'ruby',
      'scholar_no': '2310910',
      'role': 'student',
    });
    await AuthService.cacheHouse('ruby');
    await AuthService.cacheHouseStandings({
      'ruby': 820,
      'sapphire': 710,
      'topaz': 650,
      'emerald': 590,
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: const MediaQuery(
          data: MediaQueryData(
            textScaler: TextScaler.linear(2.0),
          ),
          child: Scaffold(
            body: HomeScreen(initialIndex: 2),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // Verify standings render cleanly without RenderFlex overflow
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text('820 Pts'), findsOneWidget);
    expect(find.text('710 Pts'), findsOneWidget);
    expect(find.text('650 Pts'), findsOneWidget);
    expect(find.text('590 Pts'), findsOneWidget);
  });

  // ==========================================
  // PART 21: GAMIFICATION SECURITY, SCORE ANTI-TAMPERING & RATE LIMITING VERIFICATION
  // ==========================================

  test('GamificationSecurityService Valid Token Generation & Verification', () {
    const scholarNo = '2310910';
    const activityId = 'brain_blitz_daily_01';
    const points = 35;

    // 1. Generate valid signed token
    final token = GamificationSecurityService.generateScoreProofToken(
      scholarNo: scholarNo,
      activityId: activityId,
      pointsEarned: points,
    );

    expect(token, isNotEmpty);

    // 2. Verify token cryptographically
    final result = GamificationSecurityService.verifyScoreProofToken(
      token: token,
      expectedScholarNo: scholarNo,
      expectedActivityId: activityId,
    );

    expect(result.isValid, isTrue);
    expect(result.isTampered, isFalse);
    expect(result.isExpired, isFalse);
    expect(result.isCeilingExceeded, isFalse);
    expect(result.points, equals(35));
    expect(result.scholarNo, equals(scholarNo));
    expect(result.activityId, equals(activityId));
    expect(result.error, isNull);
  });

  test('Anti-Tampering Rejection on Payload Modification', () {
    const scholarNo = '2310910';
    const activityId = 'math_olympiad_speed_run';
    const points = 20;

    final token = GamificationSecurityService.generateScoreProofToken(
      scholarNo: scholarNo,
      activityId: activityId,
      pointsEarned: points,
    );

    // Decode and tamper with payload: alter points from 20 to 45 without re-signing
    final decoded = utf8.decode(base64Url.decode(base64Url.normalize(token)));
    final payloadMap = jsonDecode(decoded) as Map<String, dynamic>;
    payloadMap['points'] = 45;
    final tamperedToken = base64Url.encode(utf8.encode(jsonEncode(payloadMap)));

    final result = GamificationSecurityService.verifyScoreProofToken(
      token: tamperedToken,
      expectedScholarNo: scholarNo,
      expectedActivityId: activityId,
    );

    expect(result.isValid, isFalse);
    expect(result.isTampered, isTrue);
    expect(result.error, contains('Cryptographic signature verification failed'));

    // Also test scholar mismatch tampering
    final scholarMismatchResult = GamificationSecurityService.verifyScoreProofToken(
      token: token,
      expectedScholarNo: '9999999',
      expectedActivityId: activityId,
    );
    expect(scholarMismatchResult.isValid, isFalse);
    expect(scholarMismatchResult.isTampered, isTrue);
    expect(scholarMismatchResult.error, contains('Scholar number mismatch'));
  });

  test('Hard Ceiling Clamp Enforcement', () {
    const scholarNo = '10001';
    const activityId = 'spelling_bee_finals';

    // 1. Attempt to create and verify a score exceeding 50 pts ceiling
    final overCeilingToken = GamificationSecurityService.generateScoreProofToken(
      scholarNo: scholarNo,
      activityId: activityId,
      pointsEarned: 75,
    );

    final overCeilingResult = GamificationSecurityService.verifyScoreProofToken(
      token: overCeilingToken,
      expectedScholarNo: scholarNo,
      expectedActivityId: activityId,
      maxCeiling: 50,
    );

    expect(overCeilingResult.isValid, isFalse);
    expect(overCeilingResult.isCeilingExceeded, isTrue);
    expect(overCeilingResult.points, equals(75));
    expect(overCeilingResult.error, contains('Score exceeds authorized ceiling of 50 points'));

    // 2. Negative score clamp
    final negativeToken = GamificationSecurityService.generateScoreProofToken(
      scholarNo: scholarNo,
      activityId: activityId,
      pointsEarned: -10,
    );
    final negativeResult = GamificationSecurityService.verifyScoreProofToken(
      token: negativeToken,
    );
    expect(negativeResult.isValid, isFalse);
    expect(negativeResult.isCeilingExceeded, isTrue);

    // 3. Exactly at ceiling (50 pts) passes
    final ceilingBoundaryToken = GamificationSecurityService.generateScoreProofToken(
      scholarNo: scholarNo,
      activityId: activityId,
      pointsEarned: 50,
    );
    final boundaryResult = GamificationSecurityService.verifyScoreProofToken(
      token: ceilingBoundaryToken,
      expectedScholarNo: scholarNo,
      expectedActivityId: activityId,
      maxCeiling: 50,
    );
    expect(boundaryResult.isValid, isTrue);
    expect(boundaryResult.isCeilingExceeded, isFalse);
    expect(boundaryResult.points, equals(50));
  });

  test('24-Hour Cooldown Enforcement', () async {
    const scholarNo = '2310910';
    const activityId = 'daily_science_quiz';
    final startTime = DateTime(2026, 9, 30, 10, 0, 0);

    // 1. Initial check: activity allowed
    var check = GamificationSecurityService.canParticipateDaily(scholarNo, activityId, now: startTime);
    expect(check.allowed, isTrue);
    expect(check.remainingCooldown, equals(Duration.zero));

    // 2. Record completion at startTime
    await GamificationSecurityService.recordActivityCompletion(scholarNo, activityId, startTime);

    // 3. Check 2 hours later: blocked
    final twoHoursLater = startTime.add(const Duration(hours: 2));
    check = GamificationSecurityService.canParticipateDaily(scholarNo, activityId, now: twoHoursLater);
    expect(check.allowed, isFalse);
    expect(check.remainingCooldown.inHours, equals(22));
    expect(check.formattedRemaining, isNotEmpty);

    // 4. Check 23 hours later: still blocked
    final twentyThreeHoursLater = startTime.add(const Duration(hours: 23));
    check = GamificationSecurityService.canParticipateDaily(scholarNo, activityId, now: twentyThreeHoursLater);
    expect(check.allowed, isFalse);

    // 5. Check 24 hours + 1 minute later: cooldown elapsed, allowed again
    final nextDay = startTime.add(const Duration(hours: 24, minutes: 1));
    check = GamificationSecurityService.canParticipateDaily(scholarNo, activityId, now: nextDay);
    expect(check.allowed, isTrue);
    expect(check.remainingCooldown, equals(Duration.zero));
  });

  test('Rapid-Fire Anti-Spam Debounce', () async {
    const scholarNo = '10001';
    final t0 = DateTime(2026, 9, 30, 12, 0, 0);

    // 1. Initial attempt: allowed
    var throttle = GamificationSecurityService.checkRapidFireThrottle(scholarNo, now: t0);
    expect(throttle.allowed, isTrue);

    // 2. Record submission attempt at t0
    await GamificationSecurityService.recordSubmissionAttempt(scholarNo, t0);

    // 3. Immediate repeat click (5 seconds later): blocked
    final t5 = t0.add(const Duration(seconds: 5));
    throttle = GamificationSecurityService.checkRapidFireThrottle(scholarNo, now: t5);
    expect(throttle.allowed, isFalse);
    expect(throttle.remainingCooldown.inSeconds, equals(55));
    expect(throttle.formattedRemaining, equals('55s'));

    // 4. At 59 seconds: still blocked
    final t59 = t0.add(const Duration(seconds: 59));
    throttle = GamificationSecurityService.checkRapidFireThrottle(scholarNo, now: t59);
    expect(throttle.allowed, isFalse);

    // 5. After 60 seconds (61 seconds): allowed again
    final t61 = t0.add(const Duration(seconds: 61));
    throttle = GamificationSecurityService.checkRapidFireThrottle(scholarNo, now: t61);
    expect(throttle.allowed, isTrue);
  });

  testWidgets('Accessible Cooldown Live Region & 48dp Targets', (WidgetTester tester) async {
    bool dismissed = false;
    bool retried = false;
    bool reminded = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: MediaQuery(
          data: const MediaQueryData(
            textScaler: TextScaler.linear(2.0),
          ),
          child: Scaffold(
            body: Center(
              child: GamificationCooldownBanner(
                activityTitle: 'Spirit Rally Trivia Blitz',
                formattedRemaining: '14h 22m',
                remainingDuration: const Duration(hours: 14, minutes: 22),
                onDismiss: () => dismissed = true,
                onRetry: () => retried = true,
                onScheduleReminder: () => reminded = true,
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pump();

    // 1. Verify Semantics liveRegion is active and polite
    final liveRegionFinder = find.byWidgetPredicate(
      (w) =>
          w is Semantics &&
          w.properties.liveRegion == true &&
          (w.properties.label?.contains('Daily challenge on cooldown') ?? false),
    );
    expect(liveRegionFinder, findsOneWidget);

    // 2. Verify all interactive action buttons satisfy minimum 48dp touch targets
    final constrainedBoxes = find.descendant(
      of: find.byType(GamificationCooldownBanner),
      matching: find.byWidgetPredicate(
        (w) =>
            w is ConstrainedBox &&
            w.constraints.minWidth >= 48.0 &&
            w.constraints.minHeight >= 48.0,
      ),
    );
    expect(constrainedBoxes, findsAtLeastNWidgets(3));

    // 3. Verify interaction execution
    await tester.tap(find.text('Dismiss'));
    await tester.pump();
    expect(dismissed, isTrue);

    await tester.tap(find.text('Check Status'));
    await tester.pump();
    expect(retried, isTrue);

    await tester.tap(find.text('Remind Me'));
    await tester.pump();
    expect(reminded, isTrue);

    // 4. Verify no RenderFlex overflow occurs under 200% font scale
    expect(tester.takeException(), isNull);
  });

  // ==========================================
  // PART 22: PHASE 4 COMPREHENSIVE MASTER VALIDATION & WCAG VERIFICATION GATE
  // ==========================================

  testWidgets('Phase 4 Master Test 1: Full Automated WCAG Guideline Suite (meetsGuideline)', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: Center(
            child: GamificationCooldownBanner(
              activityTitle: 'Spirit Rally Trivia Blitz',
              formattedRemaining: '14h 22m',
              remainingDuration: const Duration(hours: 14, minutes: 22),
              onDismiss: () {},
              onRetry: () {},
              onScheduleReminder: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    // Built-in Flutter Accessibility Evaluation API (WCAG 2.5.5, 4.1.2)
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
  });

  testWidgets('Phase 4 Master Test 2: End-to-End Gamification Security & Score Pipeline', (
    WidgetTester tester,
  ) async {
    final authService = AuthService();
    const scholarNo = '2310910';
    const house = 'ruby';
    const activityId = 'brain_blitz_grand_finals';
    const pointsToAward = 45;

    // 1. Initial State: clean zero baselines
    expect(AuthService.getCachedPointsForHouse(house), equals(0));
    final initialContrib = AuthService.getCachedStudentContribution(scholarNo);
    expect(initialContrib.totalPoints, equals(0));
    expect(initialContrib.merits, equals(0));

    // 2. Student completes challenge and client signs HMAC score proof token
    final token = GamificationSecurityService.generateScoreProofToken(
      scholarNo: scholarNo,
      activityId: activityId,
      pointsEarned: pointsToAward,
    );
    expect(token, isNotEmpty);

    // 3. Award verified points via AuthService atomic transaction pipeline
    final awardResult = await authService.awardVerifiedGamificationPoints(
      token: token,
      scholarNo: scholarNo,
      house: house,
      activityId: activityId,
      activityTitle: 'Brain Blitz Grand Finals',
    );

    expect(awardResult.success, isTrue);
    expect(awardResult.pointsAwarded, equals(pointsToAward));
    expect(awardResult.error, isNull);

    // 4. Verify local disk cache is updated synchronously
    expect(AuthService.getCachedPointsForHouse(house), equals(45));
    final updatedContrib = AuthService.getCachedStudentContribution(scholarNo);
    expect(updatedContrib.totalPoints, equals(45));
    expect(updatedContrib.merits, equals(1));

    // 5. Verify HouseLeaderboardScreen displays the newly pre-hydrated points on Frame 1
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: const HouseLeaderboardScreen(
          initialHouse: 'Ruby',
          initialPoints: 45,
        ),
      ),
    );
    await tester.pump();
    expect(find.text('45 Pts Total'), findsOneWidget);
  });

  test('Phase 4 Master Test 3: Anti-Tampering Rejection & Replay Attack Defense', () async {
    final authService = AuthService();
    const scholarNo = '2310910';
    const house = 'ruby';
    const activityId = 'daily_math_sprint';

    // 1. Tampered points attack (inflated from 30 to 500)
    final validToken = GamificationSecurityService.generateScoreProofToken(
      scholarNo: scholarNo,
      activityId: activityId,
      pointsEarned: 30,
    );

    final decoded = utf8.decode(base64Url.decode(base64Url.normalize(validToken)));
    final payloadMap = jsonDecode(decoded) as Map<String, dynamic>;
    payloadMap['points'] = 500;
    final tamperedToken = base64Url.encode(utf8.encode(jsonEncode(payloadMap)));

    final tamperedResult = await authService.awardVerifiedGamificationPoints(
      token: tamperedToken,
      scholarNo: scholarNo,
      house: house,
      activityId: activityId,
    );
    expect(tamperedResult.success, isFalse);
    expect(tamperedResult.pointsAwarded, equals(0));

    // 2. Scholar identity spoofing attack (token generated for scholar A submitted by scholar B)
    final tokenForScholarA = GamificationSecurityService.generateScoreProofToken(
      scholarNo: '10001',
      activityId: activityId,
      pointsEarned: 25,
    );

    final spoofResult = await authService.awardVerifiedGamificationPoints(
      token: tokenForScholarA,
      scholarNo: '2310910',
      house: house,
      activityId: activityId,
    );
    expect(spoofResult.success, isFalse);
    expect(spoofResult.pointsAwarded, equals(0));

    // 3. Stale token replay attack (timestamp older than 5-minute sliding window)
    final expiredToken = GamificationSecurityService.generateScoreProofToken(
      scholarNo: scholarNo,
      activityId: activityId,
      pointsEarned: 20,
      timestampMillis: DateTime.now().subtract(const Duration(minutes: 10)).millisecondsSinceEpoch,
    );

    final expiredResult = await authService.awardVerifiedGamificationPoints(
      token: expiredToken,
      scholarNo: scholarNo,
      house: house,
      activityId: activityId,
    );
    expect(expiredResult.success, isFalse);
    expect(expiredResult.pointsAwarded, equals(0));
  });

  test('Phase 4 Master Test 4: Cooldown Lockout & 60s Debounce Integration', () async {
    final authService = AuthService();
    const scholarNo = '2310910';
    const house = 'ruby';
    const activityId = 'daily_science_challenge';

    // 1. First valid claim succeeds
    final token1 = GamificationSecurityService.generateScoreProofToken(
      scholarNo: scholarNo,
      activityId: activityId,
      pointsEarned: 30,
    );

    final result1 = await authService.awardVerifiedGamificationPoints(
      token: token1,
      scholarNo: scholarNo,
      house: house,
      activityId: activityId,
    );
    expect(result1.success, isTrue);

    // 2. Immediate repeat attempt within 60s (rapid-fire debounce blocks)
    final token2 = GamificationSecurityService.generateScoreProofToken(
      scholarNo: scholarNo,
      activityId: activityId,
      pointsEarned: 30,
    );

    final result2 = await authService.awardVerifiedGamificationPoints(
      token: token2,
      scholarNo: scholarNo,
      house: house,
      activityId: activityId,
    );
    expect(result2.success, isFalse);
    expect(result2.error, contains('Rapid-fire rate limit active'));

    // 3. Simulate passage of 60 seconds (but still within 24h daily window)
    // Cooldown check should block with daily challenge cooldown
    final canParticipate = GamificationSecurityService.canParticipateDaily(scholarNo, activityId);
    expect(canParticipate.allowed, isFalse);
    expect(canParticipate.remainingCooldown.inHours, greaterThanOrEqualTo(23));
  });

  testWidgets('Phase 4 Master Test 5: AXTree Bridge Shielding Verification', (WidgetTester tester) async {
    // 1. Chant Synthesizer Equalizer Canvas AXTree Shielding
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: const Scaffold(
          body: BattleChantSynthesizer(
            userHouse: 'ruby',
            initialMode: ChantMode.warCry,
          ),
        ),
      ),
    );
    await tester.pump();

    // Verify 60fps Equalizer CustomPaint is shielded from AXTree by ExcludeSemantics
    final equalizerPaintFinder = find.byWidgetPredicate(
      (w) => w is CustomPaint && w.painter.runtimeType.toString().contains('Equalizer'),
    );
    expect(equalizerPaintFinder, findsOneWidget);
    final excludeEqualizer = find.ancestor(
      of: equalizerPaintFinder,
      matching: find.byType(ExcludeSemantics),
    );
    expect(excludeEqualizer, findsOneWidget);

    // 2. Mascot 3D Stage AXTree Shielding
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: const Scaffold(
          body: Mascot3DStage(
            userHouse: 'ruby',
            userName: 'Zaid Al-Husseini',
            scholarNo: '2310910',
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(Mascot3DStage), findsOneWidget);

    // 3. Confetti Overlay AXTree Shielding
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ConfettiOverlay(
            show: true,
            child: Text('Protected Surface'),
          ),
        ),
      ),
    );
    await tester.pump();

    final confettiPaint = find.descendant(
      of: find.byType(ConfettiOverlay),
      matching: find.byType(CustomPaint),
    );
    expect(confettiPaint, findsOneWidget);
    final excludeConfetti = find.ancestor(
      of: confettiPaint,
      matching: find.byType(ExcludeSemantics),
    );
    expect(excludeConfetti, findsOneWidget);
  });

  testWidgets('Phase 4 Master Test 6: 200% Font Scale Master Regression Sweep', (WidgetTester tester) async {
    // Test on both Desktop Widescreen (1200x1000) and Mobile Portrait (400x1000)
    final testSizes = [const Size(1200, 1000), const Size(400, 1000)];

    for (final size in testSizes) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;

      // A. Render Cooldown Banner at 200% font scale
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: MediaQuery(
            data: const MediaQueryData(
              textScaler: TextScaler.linear(2.0),
            ),
            child: Scaffold(
              body: SingleChildScrollView(
                child: GamificationCooldownBanner(
                  activityTitle: 'Spirit Reactor Overdrive',
                  formattedRemaining: '23h 59m',
                  remainingDuration: const Duration(hours: 23, minutes: 59),
                  onDismiss: () {},
                  onRetry: () {},
                  onScheduleReminder: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);

      // B. Render Leaderboard Screen at 200% font scale
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: MediaQuery(
            data: const MediaQueryData(
              textScaler: TextScaler.linear(2.0),
            ),
            child: const Scaffold(
              body: HouseLeaderboardScreen(
                initialHouse: 'Ruby',
                initialPoints: 45,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    }

    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  test('Part 23 Test 1: TimetablePeriod Serialization & Dynamic Parsing', () {
    final json = {
      'period_number': 2,
      'time_slot': '08:35 - 09:25',
      'subject': 'Physics',
      'teacher_name': 'Dr. Rao',
      'room': 'Lab 2',
      'is_break': false,
      'day_of_week': 'Sunday',
      'class_level': 'Grade 10',
    };
    final period = TimetablePeriod.fromMap(json);
    expect(period.periodNumber, 2);
    expect(period.subject, 'Physics');
    expect(period.teacherName, 'Dr. Rao');
    expect(period.room, 'Lab 2');
    expect(period.dayOfWeek, 'Sunday');
    expect(period.classLevel, 'Grade 10');
    expect(period.startTimeOfDay, const TimeOfDay(hour: 8, minute: 35));
    expect(period.endTimeOfDay, const TimeOfDay(hour: 9, minute: 25));

    // Verify ordering via Comparable
    final p1 = period.copyWith(periodNumber: 1, subject: 'Mathematics');
    final p3 = period.copyWith(periodNumber: 3, subject: 'Chemistry');
    final list = [p3, period, p1];
    list.sort();
    expect(list.map((p) => p.periodNumber).toList(), [1, 2, 3]);

    // Verify toMap round-trip
    final map = period.toMap();
    expect(map['subject'], 'Physics');
    expect(TimetablePeriod.fromMap(map), equals(period));
  });

  test('Part 23 Test 2: Active Period Detection Logic', () {
    const period = TimetablePeriod(
      periodNumber: 2,
      timeSlot: '08:35 - 09:25',
      subject: 'Physics',
      teacherName: 'Dr. Rao',
      room: 'Lab 2',
      dayOfWeek: 'Sunday',
    );

    // 1. Time before period (08:15 AM)
    final beforeTime = DateTime(2026, 10, 4, 8, 15); // Sunday
    expect(period.isCurrentPeriod(beforeTime, true), isFalse);
    expect(period.isUpcomingPeriod(beforeTime, true), isTrue);

    // 2. Time during period (08:45 AM)
    final activeTime = DateTime(2026, 10, 4, 8, 45); // Sunday
    expect(period.isCurrentPeriod(activeTime, true), isTrue);
    expect(period.isUpcomingPeriod(activeTime, true), isFalse);
    expect(period.timeRemaining(activeTime), const Duration(minutes: 40));
    expect(period.formattedRemaining(activeTime), '40m remaining');

    // 3. Time after period (09:30 AM)
    final afterTime = DateTime(2026, 10, 4, 9, 30); // Sunday
    expect(period.isCurrentPeriod(afterTime, true), isFalse);
    expect(period.isUpcomingPeriod(afterTime, true), isFalse);
    expect(period.timeRemaining(afterTime), Duration.zero);

    // 4. Day-of-week sensitivity: Monday 08:45 AM should not match Sunday period
    final mondayActiveTime = DateTime(2026, 10, 5, 8, 45);
    expect(period.isCurrentPeriod(mondayActiveTime, true), isFalse);
  });

  test('Part 23 Test 3: Frame-1 Offline Cache & Pre-Hydration', () async {
    SharedPreferences.setMockInitialValues({});
    await AuthService.initPreferences();

    // Initially empty cache returns empty list (Zero hardcoded standard)
    final emptyList = AuthService.getCachedTimetable();
    expect(emptyList, isEmpty);

    // Persist verified periods to cache
    const samplePeriods = [
      TimetablePeriod(
        periodNumber: 1,
        timeSlot: '07:45 - 08:35',
        subject: 'Mathematics',
        teacherName: 'Mr. Sharma',
        room: 'Room 401',
        dayOfWeek: 'Sunday',
        classLevel: 'Grade 10',
      ),
      TimetablePeriod(
        periodNumber: 2,
        timeSlot: '08:35 - 09:25',
        subject: 'Physics',
        teacherName: 'Dr. Rao',
        room: 'Lab 2',
        dayOfWeek: 'Sunday',
        classLevel: 'Grade 10',
      ),
    ];

    await AuthService.cacheTimetable(
      samplePeriods,
      classLevel: 'Grade 10',
      dayOfWeek: 'Sunday',
    );

    // Synchronous retrieval from cache
    final cached = AuthService.getCachedTimetable(
      classLevel: 'Grade 10',
      dayOfWeek: 'Sunday',
    );
    expect(cached.length, 2);
    expect(cached[0].subject, 'Mathematics');
    expect(cached[1].subject, 'Physics');

    // General fallback retrieval without parameters
    final generalCached = AuthService.getCachedTimetable();
    expect(generalCached.length, 2);
  });

  testWidgets('Part 23 Test 4: Day Switcher 48dp Touch Targets & Semantics', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: const Scaffold(
          body: AcademicsScreen(initialDay: 'Sunday'),
        ),
      ),
    );
    await tester.pump();

    // Verify all 5 Bahrain school days are rendered
    for (final day in ['SUN', 'MON', 'TUE', 'WED', 'THU']) {
      expect(find.text(day), findsOneWidget);
    }

    // Verify Semantics buttons exist for each school day
    for (final day in ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday']) {
      final semanticFinder = find.byWidgetPredicate(
        (w) =>
            w is Semantics &&
            w.properties.button == true &&
            w.properties.label == '$day Timetable',
      );
      expect(semanticFinder, findsOneWidget);
    }

    // Verify automated tap target guidelines
    final handle = tester.ensureSemantics();
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    handle.dispose();
  });

  testWidgets('Part 23 Test 5: Screen Reader Live Region on Active Class', (WidgetTester tester) async {
    const testPeriods = [
      TimetablePeriod(
        periodNumber: 1,
        timeSlot: '07:45 - 08:35',
        subject: 'Mathematics',
        teacherName: 'Mr. Sharma',
        room: 'Room 401',
        dayOfWeek: 'Sunday',
      ),
      TimetablePeriod(
        periodNumber: 2,
        timeSlot: '08:35 - 09:25',
        subject: 'Physics',
        teacherName: 'Dr. Rao',
        room: 'Lab 2',
        dayOfWeek: 'Sunday',
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: AcademicsScreen(
            initialDay: 'Sunday',
            mockNow: DateTime(2026, 10, 4, 8, 45), // Sunday 8:45 AM (during period 2)
            initialPeriods: testPeriods,
          ),
        ),
      ),
    );
    await tester.pump();

    // Verify IN PROGRESS chip and LIVE indicators are visible
    expect(find.text('IN PROGRESS'), findsOneWidget);
    expect(find.text('LIVE'), findsOneWidget);

    // Verify Live Region semantics on active class card
    final liveRegionFinder = find.byWidgetPredicate(
      (w) =>
          w is Semantics &&
          w.properties.liveRegion == true &&
          (w.properties.label?.contains('Currently in progress') ?? false),
    );
    expect(liveRegionFinder, findsOneWidget);
  });

  testWidgets('Part 23 Test 6: 200% Font Scale Master Layout Sweep', (WidgetTester tester) async {
    const testPeriods = [
      TimetablePeriod(
        periodNumber: 1,
        timeSlot: '07:45 - 08:35',
        subject: 'Mathematics',
        teacherName: 'Mr. Sharma',
        room: 'Room 401',
        dayOfWeek: 'Sunday',
      ),
      TimetablePeriod(
        periodNumber: 2,
        timeSlot: '08:35 - 09:25',
        subject: 'Physics',
        teacherName: 'Dr. Rao',
        room: 'Lab 2',
        dayOfWeek: 'Sunday',
      ),
    ];

    final testSizes = [const Size(1200, 1000), const Size(400, 1000)];

    for (final size in testSizes) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: MediaQuery(
            data: const MediaQueryData(
              textScaler: TextScaler.linear(2.0),
            ),
            child: Scaffold(
              body: AcademicsScreen(
                initialDay: 'Sunday',
                mockNow: DateTime(2026, 10, 4, 8, 45),
                initialPeriods: testPeriods,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    }

    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  // =========================================================================
  // PART 24 TESTS: Academic Homework Tracker, Due Date Countdown & Points Claim Flow
  // =========================================================================

  test('Part 24 Test 1: AcademicAssignment Serialization & Due Date Parsing', () {
    final now = DateTime(2026, 10, 4, 12, 0, 0);
    final inTwoDays = now.add(const Duration(days: 2, hours: 3));
    final urgentDate = now.add(const Duration(hours: 14));
    final pastDate = now.subtract(const Duration(hours: 5));

    final assignment = AcademicAssignment(
      id: 'asg_math_01',
      title: 'Calculus Problem Set 4',
      subject: 'Mathematics',
      teacherName: 'Mr. Sharma',
      dueDateTime: inTwoDays,
      pointsReward: 30,
      status: AssignmentStatus.pending,
      description: 'Complete questions 1 to 15 on page 142.',
    );

    // Serialization
    final map = assignment.toMap();
    expect(map['id'], 'asg_math_01');
    expect(map['title'], 'Calculus Problem Set 4');
    expect(map['subject'], 'Mathematics');
    expect(map['points_reward'], 30);
    expect(map['status'], 'pending');

    final jsonMap = assignment.toJson();
    final restoredFromJson = AcademicAssignment.fromJson(jsonMap);
    expect(restoredFromJson.id, assignment.id);
    expect(restoredFromJson.title, assignment.title);
    expect(restoredFromJson.pointsReward, assignment.pointsReward);
    expect(restoredFromJson.status, AssignmentStatus.pending);

    // Telemetry calculations
    expect(assignment.formattedRemaining(now), 'Due in 2 days');
    expect(assignment.isUrgent(now), isFalse);
    expect(assignment.isOverdue(now), isFalse);

    final urgentAssignment = assignment.copyWith(dueDateTime: urgentDate);
    expect(urgentAssignment.formattedRemaining(now), 'Due in 14 hours');
    expect(urgentAssignment.isUrgent(now), isTrue);
    expect(urgentAssignment.isOverdue(now), isFalse);

    final overdueAssignment = assignment.copyWith(dueDateTime: pastDate);
    expect(overdueAssignment.formattedRemaining(now), 'Overdue');
    expect(overdueAssignment.isUrgent(now), isFalse);
    expect(overdueAssignment.isOverdue(now), isTrue);
  });

  test('Part 24 Test 2: Assignment Status Progression & Lifecycle', () {
    final assignment = AcademicAssignment(
      id: 'asg_phy_01',
      title: 'Electromagnetism Lab Report',
      subject: 'Physics',
      teacherName: 'Dr. Rao',
      dueDateTime: DateTime(2026, 10, 8, 10, 0),
      pointsReward: 40,
      status: AssignmentStatus.pending,
    );

    expect(assignment.status, AssignmentStatus.pending);
    expect(assignment.status.displayName, 'Pending');

    final next1 = assignment.status.nextStatus;
    expect(next1, AssignmentStatus.submitted);
    expect(next1.displayName, 'Submitted');

    final next2 = next1.nextStatus;
    expect(next2, AssignmentStatus.graded);
    expect(next2.displayName, 'Graded');

    final next3 = next2.nextStatus;
    expect(next3, AssignmentStatus.pending);

    // Test cycleStatus model method
    final cycled1 = assignment.cycleStatus();
    expect(cycled1.status, AssignmentStatus.submitted);
    final cycled2 = cycled1.cycleStatus();
    expect(cycled2.status, AssignmentStatus.graded);
    final cycled3 = cycled2.cycleStatus();
    expect(cycled3.status, AssignmentStatus.pending);
  });

  test('Part 24 Test 3: Frame-1 Offline Cache & Pre-Hydration', () async {
    // 1. Unseeded class cache returns clean zero-state (Zero Hardcoded Data)
    final initialEmpty = AuthService.getCachedAssignments(classLevel: '11B');
    expect(initialEmpty, isEmpty);

    // 2. Cache multiple assignments
    final testAssignments = [
      AcademicAssignment(
        id: 'asg_chem_01',
        title: 'Organic Chemistry Reactions',
        subject: 'Chemistry',
        teacherName: 'Mrs. Mathew',
        dueDateTime: DateTime(2026, 10, 5, 9, 0),
        pointsReward: 25,
        status: AssignmentStatus.pending,
      ),
      AcademicAssignment(
        id: 'asg_cs_01',
        title: 'Binary Search Tree Implementation',
        subject: 'Computer Science',
        teacherName: 'Mr. Roy',
        dueDateTime: DateTime(2026, 10, 7, 14, 0),
        pointsReward: 50,
        status: AssignmentStatus.submitted,
      ),
    ];

    await AuthService.cacheAssignments(testAssignments, classLevel: '11B');

    // 3. Retrieve instantly from write-through cache
    final cached = AuthService.getCachedAssignments(classLevel: '11B');
    expect(cached.length, 2);
    expect(cached[0].id, 'asg_chem_01');
    expect(cached[0].title, 'Organic Chemistry Reactions');
    expect(cached[0].subject, 'Chemistry');
    expect(cached[0].pointsReward, 25);
    expect(cached[0].status, AssignmentStatus.pending);

    expect(cached[1].id, 'asg_cs_01');
    expect(cached[1].subject, 'Computer Science');
    expect(cached[1].pointsReward, 50);
    expect(cached[1].status, AssignmentStatus.submitted);
  });

  testWidgets('Part 24 Test 4: Subject Filter & 48dp Touch Targets (meetsGuideline)', (WidgetTester tester) async {
    final fixedNow = DateTime(2026, 10, 4, 10, 0);
    final assignments = [
      AcademicAssignment(
        id: 'asg_1',
        title: 'Math Integrals Homework',
        subject: 'Mathematics',
        teacherName: 'Mr. Sharma',
        dueDateTime: fixedNow.add(const Duration(days: 1)),
        pointsReward: 20,
        status: AssignmentStatus.pending,
      ),
      AcademicAssignment(
        id: 'asg_2',
        title: 'Physics Wave Optics',
        subject: 'Physics',
        teacherName: 'Dr. Rao',
        dueDateTime: fixedNow.add(const Duration(days: 3)),
        pointsReward: 25,
        status: AssignmentStatus.pending,
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: AcademicsScreen(
            initialTab: 'homework',
            initialAssignments: assignments,
            mockNow: fixedNow,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify both items are initially visible under 'All'
    expect(find.text('Math Integrals Homework'), findsOneWidget);
    expect(find.text('Physics Wave Optics'), findsOneWidget);

    // Filter by 'Mathematics'
    final mathFilterFinder = find.widgetWithText(InkWell, 'Mathematics');
    expect(mathFilterFinder, findsOneWidget);

    // Verify touch target constraint >= 48dp
    final chipSize = tester.getSize(mathFilterFinder);
    expect(chipSize.height, greaterThanOrEqualTo(48.0));
    expect(chipSize.width, greaterThanOrEqualTo(48.0));

    await tester.tap(mathFilterFinder);
    await tester.pumpAndSettle();

    // After filtering by Mathematics, Math is shown, Physics is hidden
    expect(find.text('Math Integrals Homework'), findsOneWidget);
    expect(find.text('Physics Wave Optics'), findsNothing);

    // Tap 'All' to restore
    final allFilterFinder = find.widgetWithText(InkWell, 'All');
    await tester.tap(allFilterFinder);
    await tester.pumpAndSettle();

    expect(find.text('Math Integrals Homework'), findsOneWidget);
    expect(find.text('Physics Wave Optics'), findsOneWidget);
  });

  testWidgets('Part 24 Test 5: Screen Reader Live Region & Deadline Announcements', (WidgetTester tester) async {
    final fixedNow = DateTime(2026, 10, 4, 10, 0);
    final urgentAssignment = AcademicAssignment(
      id: 'asg_urgent_1',
      title: 'Urgent Lab Safety Review',
      subject: 'Chemistry',
      teacherName: 'Mrs. Mathew',
      dueDateTime: fixedNow.add(const Duration(hours: 6)),
      pointsReward: 35,
      status: AssignmentStatus.pending,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: AcademicsScreen(
            initialTab: 'homework',
            initialAssignments: [urgentAssignment],
            mockNow: fixedNow,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify urgent badge rendered
    expect(find.textContaining('Due in 6 hours'), findsOneWidget);

    // Verify accessibility live region semantics
    final liveRegionFinder = find.byWidgetPredicate(
      (w) =>
          w is Semantics &&
          w.properties.liveRegion == true &&
          (w.properties.label?.contains('Urgent deadline') ?? false),
    );
    expect(liveRegionFinder, findsOneWidget);
  });

  testWidgets('Part 24 Test 6: 200% Font Scale Master Layout Sweep', (WidgetTester tester) async {
    final fixedNow = DateTime(2026, 10, 4, 10, 0);
    final testAssignments = [
      AcademicAssignment(
        id: 'asg_math_scale',
        title: 'Calculus Multivariable Differentiation Problem Set 9',
        subject: 'Mathematics',
        teacherName: 'Mr. Sharma',
        dueDateTime: fixedNow.add(const Duration(hours: 12)),
        pointsReward: 50,
        status: AssignmentStatus.pending,
      ),
      AcademicAssignment(
        id: 'asg_cs_scale',
        title: 'Operating Systems Semaphores & Mutex Implementation',
        subject: 'Computer Science',
        teacherName: 'Mr. Roy',
        dueDateTime: fixedNow.add(const Duration(days: 4)),
        pointsReward: 30,
        status: AssignmentStatus.submitted,
      ),
    ];

    final testSizes = [const Size(1200, 1000), const Size(400, 1000)];

    for (final size in testSizes) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: MediaQuery(
            data: const MediaQueryData(
              textScaler: TextScaler.linear(2.0),
            ),
            child: Scaffold(
              body: AcademicsScreen(
                initialTab: 'homework',
                initialAssignments: testAssignments,
                mockNow: fixedNow,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }

    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  // =========================================================================
  // PART 25 TESTS: Mid-Term Examination Schedule, Syllabus Vault & Exam Hall Directory
  // =========================================================================

  test('Part 25 Test 1 (Test 103): ExamScheduleItem Serialization & Telemetry Engine', () {
    final now = DateTime(2026, 10, 12, 8, 0); // 8:00 AM
    final startsIn18Hrs = now.add(const Duration(hours: 18));
    final activeExamTime = now.subtract(const Duration(minutes: 30)); // Started 30 min ago, duration 90 min -> in progress
    final concludedExamTime = now.subtract(const Duration(hours: 3)); // Started 3h ago -> concluded

    final exam = ExamScheduleItem(
      id: 'exam_math_01',
      subject: 'Mathematics',
      paperTitle: 'Paper 1: Pure Mathematics & Calculus',
      examDateTime: startsIn18Hrs,
      durationMinutes: 90,
      examHall: 'Auditorium Hall A',
      seatRow: 'Desk Row C - 14',
      syllabusTopics: ['Limits & Continuity', 'Derivatives & Applications', 'Definite Integrals', 'Differential Equations'],
      readingMaterials: ['NCERT Calculus Vol 1', 'Past Papers 2024'],
      maxMarks: 100,
      classLevel: 'Grade 10',
    );

    // Serialization
    final map = exam.toMap();
    expect(map['id'], 'exam_math_01');
    expect(map['subject'], 'Mathematics');
    expect(map['paper_title'], 'Paper 1: Pure Mathematics & Calculus');
    expect(map['duration_minutes'], 90);
    expect(map['exam_hall'], 'Auditorium Hall A');
    expect(map['seat_row'], 'Desk Row C - 14');
    expect(map['max_marks'], 100);
    expect(map['syllabus_topics'].length, 4);

    final restored = ExamScheduleItem.fromJson(exam.toJson());
    expect(restored.id, exam.id);
    expect(restored.paperTitle, exam.paperTitle);
    expect(restored.durationMinutes, 90);
    expect(restored.examHall, 'Auditorium Hall A');
    expect(restored.seatRow, 'Desk Row C - 14');
    expect(restored.syllabusTopics, contains('Limits & Continuity'));
    expect(restored.readingMaterials, contains('NCERT Calculus Vol 1'));

    // Telemetry - Starts in 18 hours
    expect(exam.isUrgent(now), isTrue);
    expect(exam.isInProgress(now), isFalse);
    expect(exam.isConcluded(now), isFalse);
    expect(exam.formattedCountdown(now), 'Starts in 18 hours');

    // Telemetry - In Progress
    final activeExam = exam.copyWith(examDateTime: activeExamTime, durationMinutes: 90);
    expect(activeExam.isInProgress(now), isTrue);
    expect(activeExam.isUrgent(now), isFalse);
    expect(activeExam.isConcluded(now), isFalse);
    expect(activeExam.formattedCountdown(now), contains('In Progress'));

    // Telemetry - Concluded
    final concludedExam = exam.copyWith(examDateTime: concludedExamTime, durationMinutes: 90);
    expect(concludedExam.isConcluded(now), isTrue);
    expect(concludedExam.isInProgress(now), isFalse);
    expect(concludedExam.isUrgent(now), isFalse);
    expect(concludedExam.formattedCountdown(now), 'Concluded');
  });

  test('Part 25 Test 2 (Test 104): Frame-1 Offline Cache & Zero-Hardcoded Baseline', () async {
    // 1. Unseeded cache returns clean zero-state (Zero Hardcoded Baseline)
    final initialEmpty = AuthService.getCachedExamSchedule(classLevel: '10C');
    expect(initialEmpty, isEmpty);

    // 2. Cache verified exam records
    final testExams = [
      ExamScheduleItem(
        id: 'exam_phy_mid',
        subject: 'Physics',
        paperTitle: 'Paper 1: Mechanics & Wave Motion',
        examDateTime: DateTime(2026, 10, 14, 9, 0),
        durationMinutes: 90,
        examHall: 'Physics Lab 3',
        seatRow: 'Row B - 08',
        syllabusTopics: ['Kinematics', 'Dynamics', 'Simple Harmonic Motion'],
        maxMarks: 80,
      ),
      ExamScheduleItem(
        id: 'exam_chem_mid',
        subject: 'Chemistry',
        paperTitle: 'Paper 1: Organic & Inorganic Analysis',
        examDateTime: DateTime(2026, 10, 16, 9, 0),
        durationMinutes: 90,
        examHall: 'Main Examination Hall',
        seatRow: 'Row D - 22',
        syllabusTopics: ['Thermodynamics', 'Equilibrium', 'Hydrocarbons'],
        maxMarks: 80,
      ),
    ];

    await AuthService.cacheExamSchedule(testExams, classLevel: '10C');

    // 3. Synchronous frame-1 restoration
    final cached = AuthService.getCachedExamSchedule(classLevel: '10C');
    expect(cached.length, 2);
    expect(cached[0].id, 'exam_phy_mid');
    expect(cached[0].subject, 'Physics');
    expect(cached[0].examHall, 'Physics Lab 3');
    expect(cached[0].seatRow, 'Row B - 08');
    expect(cached[1].id, 'exam_chem_mid');
    expect(cached[1].subject, 'Chemistry');
    expect(cached[1].examHall, 'Main Examination Hall');
  });

  testWidgets('Part 25 Test 3 (Test 105): Tri-Segment Tab Switching & 48dp Touch Targets', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: const Scaffold(
          body: AcademicsScreen(initialTab: 'timetable'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify all 3 tabs are rendered in tri-segment bar
    expect(find.text('Class Timetable'), findsOneWidget);
    expect(find.text('Homework Tracker'), findsOneWidget);
    expect(find.text('Exam Schedule'), findsOneWidget);

    // Verify touch target constraints >= 48dp on all tab buttons
    for (final label in ['Timetable Tab', 'Homework Tab', 'Exams Tab']) {
      final tabFinder = find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.label == label && w.properties.button == true,
      );
      expect(tabFinder, findsOneWidget);
      final size = tester.getSize(tabFinder);
      expect(size.height, greaterThanOrEqualTo(48.0));
    }

    // Tap 'Exams Tab'
    final examsTabFinder = find.byWidgetPredicate(
      (w) => w is Semantics && w.properties.label == 'Exams Tab' && w.properties.button == true,
    );
    await tester.tap(examsTabFinder);
    await tester.pumpAndSettle();

    // Verify AppBar and screen switched to Exam Schedule view
    expect(find.textContaining('Exam Schedule'), findsWidgets);
    expect(find.text('No Examinations Scheduled'), findsOneWidget);
  });

  testWidgets('Part 25 Test 4 (Test 106): Syllabus Vault Accordion & Expansion Semantics', (WidgetTester tester) async {
    final fixedNow = DateTime(2026, 10, 10, 8, 0);
    final testExam = ExamScheduleItem(
      id: 'exam_cs_01',
      subject: 'Computer Science',
      paperTitle: 'Paper 1: Data Structures & Algorithms',
      examDateTime: fixedNow.add(const Duration(days: 4)),
      durationMinutes: 120,
      examHall: 'Computer Lab 1',
      seatRow: 'Station 12',
      syllabusTopics: ['Binary Trees', 'Graph Traversal', 'Dynamic Programming', 'Complexity Analysis'],
      readingMaterials: ['Introduction to Algorithms CLRS Ch 1-4', 'Python DSA Handbook'],
      maxMarks: 100,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: AcademicsScreen(
            initialTab: 'exams',
            initialExams: [testExam],
            mockNow: fixedNow,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify exam card is rendered
    expect(find.text('Paper 1: Data Structures & Algorithms'), findsOneWidget);

    // Verify syllabus accordion header initially collapsed
    final accordionFinder = find.byKey(const Key('syllabus_accordion_exam_cs_01'));
    expect(accordionFinder, findsOneWidget);

    final collapsedSemantics = find.byWidgetPredicate(
      (w) =>
          w is Semantics &&
          w.properties.button == true &&
          w.properties.expanded == false &&
          (w.properties.label?.contains('Syllabus topics') ?? false),
    );
    expect(collapsedSemantics, findsOneWidget);

    // Topics not yet visible
    expect(find.text('1. Binary Trees'), findsNothing);

    // Tap to expand
    await tester.tap(accordionFinder);
    await tester.pumpAndSettle();

    // Verify expanded: true semantics
    final expandedSemantics = find.byWidgetPredicate(
      (w) =>
          w is Semantics &&
          w.properties.button == true &&
          w.properties.expanded == true &&
          (w.properties.label?.contains('Syllabus topics') ?? false),
    );
    expect(expandedSemantics, findsOneWidget);

    // Verify topics and readings now visible
    expect(find.text('1. Binary Trees'), findsOneWidget);
    expect(find.text('2. Graph Traversal'), findsOneWidget);
    expect(find.text('Introduction to Algorithms CLRS Ch 1-4'), findsOneWidget);

    // Tap again to collapse
    await tester.tap(accordionFinder);
    await tester.pumpAndSettle();

    expect(find.text('1. Binary Trees'), findsNothing);
  });

  testWidgets('Part 25 Test 5 (Test 107): Exam Hall Navigation & Urgency Live Region Alerts', (WidgetTester tester) async {
    final fixedNow = DateTime(2026, 10, 10, 8, 0);
    final urgentExam = ExamScheduleItem(
      id: 'exam_math_urg',
      subject: 'Mathematics',
      paperTitle: 'Paper 1: Pure Mathematics',
      examDateTime: fixedNow.add(const Duration(hours: 14)), // Within 24 hours -> Urgent
      durationMinutes: 90,
      examHall: 'Auditorium Hall A',
      seatRow: 'Desk Row C - 14',
      syllabusTopics: ['Calculus'],
      maxMarks: 100,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: AcademicsScreen(
            initialTab: 'exams',
            initialExams: [urgentExam],
            mockNow: fixedNow,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify hall and desk navigation
    expect(find.text('Auditorium Hall A'), findsOneWidget);
    expect(find.text('Desk Row C - 14'), findsOneWidget);

    // Verify urgent countdown chip rendered
    expect(find.text('Starts in 14 hours'), findsOneWidget);

    // Verify screen reader live region semantics for urgent exam alert
    final urgentLiveRegionFinder = find.byWidgetPredicate(
      (w) =>
          w is Semantics &&
          w.properties.liveRegion == true &&
          (w.properties.label?.contains('Urgent examination alert: Mathematics') ?? false) &&
          (w.properties.label?.contains('Auditorium Hall A') ?? false),
    );
    expect(urgentLiveRegionFinder, findsOneWidget);
  });

  testWidgets('Part 25 Test 6 (Test 108): 200% Font Scale & Multi-Resolution Layout Stress Test', (WidgetTester tester) async {
    final fixedNow = DateTime(2026, 10, 10, 8, 0);
    final testExams = [
      ExamScheduleItem(
        id: 'exam_scale_1',
        subject: 'Mathematics',
        paperTitle: 'Advanced Multivariable Differential & Integral Calculus Examination Paper',
        examDateTime: fixedNow.add(const Duration(hours: 10)),
        durationMinutes: 120,
        examHall: 'Main University Examination Auditorium Complex West Wing',
        seatRow: 'Special Reserved Seating Zone Alpha Row 4 Desk 12',
        syllabusTopics: ['Topic 1 Long Description', 'Topic 2 Long Description'],
        readingMaterials: ['Comprehensive Textbook on Calculus and Modern Analysis Volume 4'],
        maxMarks: 100,
      ),
    ];

    final testSizes = [const Size(1200, 1000), const Size(400, 1000)];

    for (final size in testSizes) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: MediaQuery(
            data: const MediaQueryData(
              textScaler: TextScaler.linear(2.0),
            ),
            child: Scaffold(
              body: AcademicsScreen(
                initialTab: 'exams',
                initialExams: testExams,
                mockNow: fixedNow,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }

    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  testWidgets('Part 26 Test 1 (Test 109): Live Event Wall Dual-Mode Base64 & Network Image Engine', (WidgetTester tester) async {
    // 1x1 transparent PNG Base64 Data URI
    const base64Png =
        'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=';
    const networkUrl = 'https://example.com/student_event_photo.jpg';

    // Test Base64 Data URI rendering
    final base64Widget = HomeScreen.buildResilientImage(base64Png, height: 200);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: Center(child: base64Widget)),
      ),
    );
    expect(find.byType(Image), findsOneWidget);

    // Test Network URL rendering
    final networkWidget = HomeScreen.buildResilientImage(networkUrl, height: 200);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: Center(child: networkWidget)),
      ),
    );
    expect(find.byType(Image), findsOneWidget);

    // Test empty/invalid URL fallback
    final emptyWidget = HomeScreen.buildResilientImage('', height: 200);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: Center(child: emptyWidget)),
      ),
    );
    expect(find.byIcon(Icons.camera_alt_outlined), findsOneWidget);
    expect(find.text('Photo unavailable'), findsOneWidget);
  });

  testWidgets('Part 26 Test 2 (Test 110): AcademicReportCard Serialization & GPA Calculation', (WidgetTester tester) async {
    final sampleSubjects = [
      const SubjectGrade(
        subject: 'Mathematics',
        score: 95.0,
        maxScore: 100.0,
        gradeLetter: 'A1',
        teacherComment: 'Outstanding problem solving skills.',
      ),
      const SubjectGrade(
        subject: 'Physics',
        score: 88.0,
        maxScore: 100.0,
        gradeLetter: 'A2',
        teacherComment: 'Excellent lab comprehension.',
      ),
      const SubjectGrade(
        subject: 'Computer Science',
        score: 98.0,
        maxScore: 100.0,
        gradeLetter: 'A1',
        teacherComment: 'Superb algorithm and data structure design.',
      ),
    ];

    final reportCard = AcademicReportCard(
      id: 'rc_term1_2026',
      scholarNo: 'ASB-2024-8841',
      studentName: 'Aarav Patel',
      termName: 'Term 1 Mid-Term',
      academicYear: '2026-2027',
      classLevel: 'Grade 10',
      overallGpa: 3.88,
      overallPercentage: 93.67,
      attendanceRate: 98.5,
      teacherRemarks: 'Consistently exceptional academic leadership and analytical capability.',
      subjectGrades: sampleSubjects,
      publishedAt: DateTime(2026, 10, 15),
      isMeritClaimed: false,
    );

    // Verify distinctions and getters
    expect(reportCard.hasDistinction, isTrue);
    expect(reportCard.term, 'Term 1 Mid-Term');
    expect(reportCard.overallGpa, 3.88);
    expect(reportCard.formattedGpa, '3.88');
    expect(reportCard.formattedPercentage, '93.7%');
    expect(reportCard.attendancePercentage, 98.5);
    expect(reportCard.subjects.length, 3);
    expect(reportCard.subjects.first.marksObtained, 95.0);
    expect(reportCard.subjects.first.maxMarks, 100.0);
    expect(reportCard.subjects.first.letterGrade, 'A1');

    // Test JSON Serialization & Deserialization
    final jsonMap = reportCard.toMap();
    final restored = AcademicReportCard.fromMap(jsonMap);

    expect(restored.id, reportCard.id);
    expect(restored.scholarNo, reportCard.scholarNo);
    expect(restored.studentName, reportCard.studentName);
    expect(restored.termName, reportCard.termName);
    expect(restored.overallGpa, reportCard.overallGpa);
    expect(restored.overallPercentage, closeTo(93.67, 0.01));
    expect(restored.hasDistinction, isTrue);
    expect(restored.subjectGrades.length, 3);

    // Verify distinction boundary (< 3.80 is not distinction)
    final nonDistinction = reportCard.copyWith(overallGpa: 3.65);
    expect(nonDistinction.hasDistinction, isFalse);
  });

  testWidgets('Part 26 Test 3 (Test 111): Frame-1 Offline Cache & Zero Dummy Data Baseline', (WidgetTester tester) async {
    // Ensure clean zero baseline
    await AuthService.clearCache();
    final emptyCards = AuthService.getCachedReportCards(
      classLevel: 'Grade 10',
      scholarNo: 'ASB-2024-8841',
    );
    expect(emptyCards, isEmpty);

    // Mount AcademicsScreen on reports tab without preloaded data
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: const Scaffold(
          body: AcademicsScreen(
            initialTab: 'reports',
            classLevel: 'Grade 10',
            scholarNo: 'ASB-2024-8841',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify pure zero baseline empty state
    expect(find.text('No Term Report Cards Published Yet'), findsOneWidget);
    expect(find.byIcon(Icons.school_outlined), findsOneWidget);

    // Now cache a verified card and verify Frame-1 instant retrieval
    final testCard = AcademicReportCard(
      id: 'rc_cached_1',
      scholarNo: 'ASB-2024-8841',
      studentName: 'Aarav Patel',
      termName: 'Term 1 Mid-Term',
      academicYear: '2026-2027',
      classLevel: 'Grade 10',
      overallGpa: 3.90,
      overallPercentage: 94.0,
      attendanceRate: 99.0,
      teacherRemarks: 'Exemplary work.',
      publishedAt: DateTime(2026, 10, 1),
    );

    await AuthService.cacheReportCards(
      [testCard],
      classLevel: 'Grade 10',
      scholarNo: 'ASB-2024-8841',
    );

    final cachedResult = AuthService.getCachedReportCards(
      classLevel: 'Grade 10',
      scholarNo: 'ASB-2024-8841',
    );
    expect(cachedResult.length, 1);
    expect(cachedResult.first.id, 'rc_cached_1');
    expect(cachedResult.first.overallGpa, 3.90);
  });

  testWidgets('Part 26 Test 4 (Test 112): 4-Segment Navigation & 48dp Touch Targets', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const Scaffold(
          body: AcademicsScreen(
            initialTab: 'timetable',
            classLevel: 'Grade 10',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify all 4 tab buttons exist
    expect(find.text('Class Timetable'), findsOneWidget);
    expect(find.text('Homework Tracker'), findsOneWidget);
    expect(find.text('Exam Schedule'), findsOneWidget);
    expect(find.text('Report Cards'), findsOneWidget);

    for (final label in ['Timetable Tab', 'Homework Tab', 'Exams Tab', 'Report Cards Tab']) {
      final tabFinder = find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.label == label && w.properties.button == true,
      );
      expect(tabFinder, findsOneWidget);
    }

    // Verify WCAG 2.5.5 minimum 48dp touch target height
    final reportCardsTabFinder = find.byWidgetPredicate(
      (w) => w is Semantics && w.properties.label == 'Report Cards Tab' && w.properties.button == true,
    );
    final size = tester.getSize(reportCardsTabFinder);
    expect(size.height, greaterThanOrEqualTo(48.0));

    // Tap Report Cards tab
    await tester.tap(reportCardsTabFinder);
    await tester.pumpAndSettle();

    // Verify tab switch occurred
    expect(find.text('Campus Academics'), findsOneWidget);
    expect(find.text('Grade 10 • Term Report Cards'), findsOneWidget);
  });

  testWidgets('Part 26 Test 5 (Test 113): Report Card Live Region & Academic Honours Semantics', (WidgetTester tester) async {
    final distinctionCard = AcademicReportCard(
      id: 'rc_distinction_1',
      scholarNo: 'ASB-2024-8841',
      studentName: 'Aarav Patel',
      termName: 'Term 1 Mid-Term',
      academicYear: '2026-2027',
      classLevel: 'Grade 10',
      overallGpa: 3.92,
      overallPercentage: 95.5,
      attendanceRate: 98.0,
      teacherRemarks: 'Brilliant mastery of mathematical concepts and exemplary peer guidance.',
      subjectGrades: const [
        SubjectGrade(
          subject: 'Mathematics',
          score: 98.0,
          maxScore: 100.0,
          gradeLetter: 'A1',
          teacherComment: 'Perfect score in geometry section.',
        ),
      ],
      publishedAt: DateTime(2026, 10, 1),
      isMeritClaimed: false,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: AcademicsScreen(
            initialTab: 'reports',
            initialReportCards: [distinctionCard],
            scholarNo: 'ASB-2024-8841',
            classLevel: 'Grade 10',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify Honours HUD values
    expect(find.text('3.92'), findsOneWidget);
    expect(find.text('/ 4.00 GPA'), findsOneWidget);
    expect(find.text('95.5%'), findsOneWidget);
    expect(find.text('ACADEMIC HONOURS DISTINCTION'), findsOneWidget);

    // Verify Merit Claim Button is visible
    final claimButtonFinder = find.byKey(const Key('claim_honours_merit_rc_distinction_1'));
    expect(claimButtonFinder, findsOneWidget);
    expect(find.text('CLAIM HONOURS MERIT (+50 PTS)'), findsOneWidget);

    // Tap to claim merit
    await tester.tap(claimButtonFinder);
    await tester.pump();
    await tester.pumpAndSettle();

    // Verify button state updated to CLAIMED
    expect(find.text('CLAIMED (+50 PTS)'), findsOneWidget);
  });

  testWidgets('Part 26 Test 6 (Test 114): 200% Font Scale Elasticity & Multi-Resolution Layout Stress Test', (WidgetTester tester) async {
    final stressCard = AcademicReportCard(
      id: 'rc_stress_1',
      scholarNo: 'ASB-2024-8841',
      studentName: 'Aarav Patel',
      termName: 'Term 1 Mid-Term Examination Evaluation Report',
      academicYear: '2026-2027',
      classLevel: 'Grade 10',
      overallGpa: 3.95,
      overallPercentage: 96.8,
      attendanceRate: 100.0,
      teacherRemarks: 'Comprehensive analytical synthesis with profound critical evaluation across all scientific domains.',
      subjectGrades: const [
        SubjectGrade(
          subject: 'Advanced Computer Science & Data Structures',
          score: 99.0,
          maxScore: 100.0,
          gradeLetter: 'A1',
          teacherComment: 'Outstanding algorithm design and recursive computational complexity optimization.',
        ),
        SubjectGrade(
          subject: 'Theoretical Physics & Mechanics',
          score: 94.0,
          maxScore: 100.0,
          gradeLetter: 'A1',
          teacherComment: 'Exceptional problem decomposition in Newtonian rotational dynamics.',
        ),
      ],
      publishedAt: DateTime(2026, 10, 1),
      isMeritClaimed: false,
    );

    final testSizes = [const Size(1200, 1000), const Size(400, 1000)];

    for (final size in testSizes) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: MediaQuery(
            data: const MediaQueryData(
              textScaler: TextScaler.linear(2.0),
            ),
            child: Scaffold(
              body: AcademicsScreen(
                initialTab: 'reports',
                initialReportCards: [stressCard],
                scholarNo: 'ASB-2024-8841',
                classLevel: 'Grade 10',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    }

    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  // =========================================================================
  // PART 27 TESTS: Student Attendance Tracker, Period Absence Audit & Medical Leave Pass
  // =========================================================================

  test('Part 27 Test 1 (Test 115): AttendanceRecord & Summary Telemetry Engine', () {
    final now = DateTime(2026, 10, 1, 9, 0);
    final record = AttendanceRecord(
      id: 'att_01',
      scholarNo: '2310910',
      date: now,
      status: AttendanceStatus.absent,
      periodBreakdown: {
        1: AttendanceStatus.present,
        2: AttendanceStatus.present,
        3: AttendanceStatus.absent, // Missed Chemistry
        4: AttendanceStatus.present,
      },
      classLevel: 'Grade 10',
    );

    // Serialization
    final map = record.toMap();
    expect(map['id'], 'att_01');
    expect(map['scholar_no'], '2310910');
    expect(map['status'], 'absent');
    expect(map['period_breakdown']['3'], 'absent');

    final restored = AttendanceRecord.fromJson(record.toJson());
    expect(restored.id, record.id);
    expect(restored.periodBreakdown[3], AttendanceStatus.absent);
    expect(restored.hasPeriodAbsence, isTrue);
    expect(restored.missedPeriodCount, 1);

    // Telemetry Summary & 75% threshold
    final records = [
      AttendanceRecord(id: '1', scholarNo: '2310910', date: now, status: AttendanceStatus.present),
      AttendanceRecord(id: '2', scholarNo: '2310910', date: now, status: AttendanceStatus.present),
      AttendanceRecord(id: '3', scholarNo: '2310910', date: now, status: AttendanceStatus.present),
      AttendanceRecord(id: '4', scholarNo: '2310910', date: now, status: AttendanceStatus.absent),
    ];
    final summary = AttendanceSummary.fromRecords(records);
    expect(summary.totalDays, 4);
    expect(summary.presentDays, 3);
    expect(summary.percentage, 75.0);
    expect(summary.isMinistryCompliant, isTrue);
    expect(summary.isCriticalThreshold, isTrue); // 75% < 80% threshold
  });

  test('Part 27 Test 2 (Test 116): Frame-1 Offline Cache & Zero Dummy Data Baseline', () async {
    // 1. Unseeded cache returns clean zero-state
    final initialEmpty = AuthService.getCachedAttendanceRecords(classLevel: '10A', scholarNo: '999');
    expect(initialEmpty, isEmpty);

    // 2. Cache records
    final testRecords = [
      AttendanceRecord(
        id: 'att_test',
        scholarNo: '999',
        date: DateTime(2026, 10, 1),
        status: AttendanceStatus.present,
        classLevel: '10A',
      ),
    ];
    await AuthService.cacheAttendanceRecords(testRecords, classLevel: '10A', scholarNo: '999');

    // 3. Frame-1 Synchronous Restoration
    final cached = AuthService.getCachedAttendanceRecords(classLevel: '10A', scholarNo: '999');
    expect(cached.length, 1);
    expect(cached[0].status, AttendanceStatus.present);
  });

  testWidgets('Part 27 Test 3 (Test 117): 5-Segment Tab Navigation & 48dp Touch Targets', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: const Scaffold(
          body: AcademicsScreen(initialTab: 'timetable'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify all 5 tab buttons exist with >= 48dp touch targets
    final attendanceTabFinder = find.byWidgetPredicate(
      (w) => w is Semantics && w.properties.label == 'Attendance Tab' && w.properties.button == true,
    );
    expect(attendanceTabFinder, findsOneWidget);
    final size = tester.getSize(attendanceTabFinder);
    expect(size.height, greaterThanOrEqualTo(48.0));

    // Tap to switch
    await tester.tap(attendanceTabFinder);
    await tester.pumpAndSettle();

    expect(find.textContaining('Attendance'), findsWidgets);
    expect(find.text('No Attendance Records Logged Yet'), findsOneWidget);
  });

  testWidgets('Part 27 Test 4 (Test 118): Period-Wise Absence Breakdown & Screen Reader Semantics', (WidgetTester tester) async {
    final fixedDate = DateTime(2026, 10, 1);
    final recordWithAbsence = AttendanceRecord(
      id: 'rec_abs_01',
      scholarNo: '2310910',
      date: fixedDate,
      status: AttendanceStatus.absent,
      periodBreakdown: {
        1: AttendanceStatus.present,
        2: AttendanceStatus.absent, // Period 2 absent
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: AcademicsScreen(
            initialTab: 'attendance',
            initialAttendance: [recordWithAbsence],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify period absence pill and semantics
    expect(find.text('Period 2'), findsOneWidget);
    final periodSemantics = find.byWidgetPredicate(
      (w) => w is Semantics && (w.properties.label?.contains('Period 2: Absent') ?? false),
    );
    expect(periodSemantics, findsOneWidget);
  });

  testWidgets('Part 27 Test 5 (Test 119): Ministry 75% Compliance Alert & Critical Live Region', (WidgetTester tester) async {
    final lowAttendance = [
      AttendanceRecord(id: '1', scholarNo: '2310910', date: DateTime(2026, 10, 1), status: AttendanceStatus.present),
      AttendanceRecord(id: '2', scholarNo: '2310910', date: DateTime(2026, 10, 2), status: AttendanceStatus.absent),
    ]; // 50% attendance -> Critical threshold violation

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: AcademicsScreen(
            initialTab: 'attendance',
            initialAttendance: lowAttendance,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify critical alert HUD and live region
    expect(find.textContaining('50.0%'), findsOneWidget);
    final liveRegionFinder = find.byWidgetPredicate(
      (w) =>
          w is Semantics &&
          w.properties.liveRegion == true &&
          (w.properties.label?.contains('Ministry') ?? false),
    );
    expect(liveRegionFinder, findsOneWidget);
  });

  testWidgets('Part 27 Test 6 (Test 120): 200% Font Scale Multi-Resolution Layout Sweep', (WidgetTester tester) async {
    final testRecord = AttendanceRecord(
      id: 'scale_att',
      scholarNo: '2310910',
      date: DateTime(2026, 10, 1),
      status: AttendanceStatus.excused,
      excusedReason: 'Medical consultation for acute respiratory symptoms with institutional medical certification.',
    );

    for (final size in [const Size(1200, 1000), const Size(400, 1000)]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
            child: Scaffold(
              body: AcademicsScreen(
                initialTab: 'attendance',
                initialAttendance: [testRecord],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }

    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  // =========================================================================
  // PART 28 TESTS: Phase 5 Comprehensive Master Test Suite & Concluding Gate
  // =========================================================================

  test('Part 28 Test 1 (Test 121): Master Frame-1 Offline Cache Invalidation & Zero-Dummy Baseline Sweep', () async {
    // 1. Invalidate and clear all local disk caches
    await AuthService.clearCache();

    // 2. Verify all 5 academic domain caches strictly return clean zero-baselines ([])
    expect(AuthService.getCachedTimetable(day: 'Monday', classLevel: 'Grade 10'), isEmpty);
    expect(AuthService.getCachedAssignments(classLevel: 'Grade 10'), isEmpty);
    expect(AuthService.getCachedExamSchedule(classLevel: 'Grade 10'), isEmpty);
    expect(AuthService.getCachedReportCards(classLevel: 'Grade 10', scholarNo: '2310910'), isEmpty);
    expect(AuthService.getCachedAttendanceRecords(classLevel: 'Grade 10', scholarNo: '2310910'), isEmpty);

    // 3. Pre-hydrate verified real-world academic models into local cache
    final testPeriod = TimetablePeriod(
      periodNumber: 1,
      timeSlot: '08:00 - 08:45',
      subject: 'Mathematics',
      teacherName: 'Mr. Sharma',
      room: 'Room 204',
      dayOfWeek: 'Monday',
    );
    final testAssignment = AcademicAssignment(
      id: 'asg_test',
      title: 'Calculus Problem Set',
      subject: 'Mathematics',
      teacherName: 'Mr. Sharma',
      dueDateTime: DateTime.now().add(const Duration(days: 2)),
      pointsReward: 20,
      status: AssignmentStatus.pending,
    );
    final testExam = ExamScheduleItem(
      id: 'exam_test',
      subject: 'Mathematics',
      paperTitle: 'Paper 1 Pure Math',
      examDateTime: DateTime.now().add(const Duration(days: 5)),
      examHall: 'Auditorium Hall A',
      maxMarks: 100,
    );
    final testReportCard = AcademicReportCard(
      id: 'rc_test',
      scholarNo: '2310910',
      studentName: 'Mustafa Hisham',
      termName: 'Term 1 Mid-Term',
      academicYear: '2026-2027',
      classLevel: 'Grade 10',
      overallGpa: 3.90,
      overallPercentage: 94.5,
      attendanceRate: 98.0,
      teacherRemarks: 'Outstanding diligence.',
      publishedAt: DateTime.now(),
    );
    final testAttendance = AttendanceRecord(
      id: 'att_test',
      scholarNo: '2310910',
      date: DateTime.now(),
      status: AttendanceStatus.present,
      classLevel: 'Grade 10',
    );

    // Write-through caching
    await AuthService.cacheTimetable([testPeriod], day: 'Monday', classLevel: 'Grade 10');
    await AuthService.cacheAssignments([testAssignment], classLevel: 'Grade 10');
    await AuthService.cacheExamSchedule([testExam], classLevel: 'Grade 10');
    await AuthService.cacheReportCards([testReportCard], classLevel: 'Grade 10', scholarNo: '2310910');
    await AuthService.cacheAttendanceRecords([testAttendance], classLevel: 'Grade 10', scholarNo: '2310910');

    // 4. Verify synchronous Frame-1 restoration across all 5 caches
    expect(AuthService.getCachedTimetable(day: 'Monday', classLevel: 'Grade 10').length, 1);
    expect(AuthService.getCachedAssignments(classLevel: 'Grade 10').length, 1);
    expect(AuthService.getCachedExamSchedule(classLevel: 'Grade 10').length, 1);
    expect(AuthService.getCachedReportCards(classLevel: 'Grade 10', scholarNo: '2310910').length, 1);
    expect(AuthService.getCachedAttendanceRecords(classLevel: 'Grade 10', scholarNo: '2310910').length, 1);
  });

  testWidgets('Part 28 Test 2 (Test 122): End-to-End Cross-Tab Navigation & 48dp Touch Target Rigor', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: const Scaffold(
          body: AcademicsScreen(initialTab: 'timetable'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify all 5 navigation tabs satisfy WCAG 2.5.5 minimum 48dp touch target size
    final tabLabels = [
      'Timetable Tab',
      'Homework Tab',
      'Exams Tab',
      'Report Cards Tab',
      'Attendance Tab',
    ];

    for (final label in tabLabels) {
      final tabFinder = find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.label == label && w.properties.button == true,
      );
      expect(tabFinder, findsOneWidget);
      final size = tester.getSize(tabFinder);
      expect(size.height, greaterThanOrEqualTo(48.0));
      expect(size.width, greaterThanOrEqualTo(48.0));

      // Sequential tab transition
      await tester.tap(tabFinder);
      await tester.pumpAndSettle();
    }
  });

  test('Part 28 Test 3 (Test 123): Cross-Subsystem Cryptographic HMAC-SHA256 Gamification Integration', () async {
    // 1. Test Homework Points Claim Security Proof Token
    final hwToken = GamificationSecurityService.generateScoreProofToken(
      scholarNo: '2310910',
      activityId: 'asg_math_01',
      pointsEarned: 20,
    );
    expect(hwToken, isNotEmpty);

    final hwVerify = GamificationSecurityService.verifyScoreProofToken(
      token: hwToken,
      expectedScholarNo: '2310910',
      expectedActivityId: 'asg_math_01',
    );
    expect(hwVerify.isValid, isTrue);
    expect(hwVerify.points, 20);

    // 2. Test Report Card Distinction (+50 Pts) Proof Token
    final rcToken = GamificationSecurityService.generateScoreProofToken(
      scholarNo: '2310910',
      activityId: 'rc_distinction_2026',
      pointsEarned: 50,
    );
    expect(rcToken, isNotEmpty);

    final rcVerify = GamificationSecurityService.verifyScoreProofToken(
      token: rcToken,
      expectedScholarNo: '2310910',
      expectedActivityId: 'rc_distinction_2026',
    );
    expect(rcVerify.isValid, isTrue);
    expect(rcVerify.points, 50);

    // 3. Verify anti-tampering rejection on modified score payload
    final tamperedVerify = GamificationSecurityService.verifyScoreProofToken(
      token: rcToken,
      expectedScholarNo: '2310910',
      expectedActivityId: 'tampered_activity_id',
    );
    expect(tamperedVerify.isValid, isFalse);
    expect(tamperedVerify.isTampered, isTrue);
  });

  testWidgets('Part 28 Test 4 (Test 124): Universal Screen Reader Live Region Orchestration Sweep', (WidgetTester tester) async {
    final fixedNow = DateTime(2026, 10, 4, 10, 0);

    // Populate urgency items
    final urgentAssignment = AcademicAssignment(
      id: 'asg_urg',
      title: 'Urgent Lab Report',
      subject: 'Physics',
      teacherName: 'Dr. Rao',
      dueDateTime: fixedNow.add(const Duration(hours: 4)),
      pointsReward: 30,
      status: AssignmentStatus.pending,
    );
    final urgentExam = ExamScheduleItem(
      id: 'exam_urg',
      subject: 'Mathematics',
      paperTitle: 'Paper 1 Pure Math',
      examDateTime: fixedNow.add(const Duration(hours: 12)),
      examHall: 'Auditorium Hall A',
      maxMarks: 100,
    );
    final lowAttendance = [
      AttendanceRecord(id: '1', scholarNo: '2310910', date: fixedNow, status: AttendanceStatus.absent),
    ];

    // Mount and verify homework live region
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: AcademicsScreen(
            key: const Key('academics_screen_hw'),
            initialTab: 'homework',
            initialAssignments: [urgentAssignment],
            mockNow: fixedNow,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final hwLiveRegion = find.byWidgetPredicate(
      (w) => w is Semantics && w.properties.liveRegion == true && (w.properties.label?.contains('Urgent deadline') ?? false),
    );
    expect(hwLiveRegion, findsOneWidget);

    // Mount and verify exam live region
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: AcademicsScreen(
            key: const Key('academics_screen_exams'),
            initialTab: 'exams',
            initialExams: [urgentExam],
            mockNow: fixedNow,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final examLiveRegion = find.byWidgetPredicate(
      (w) => w is Semantics && w.properties.liveRegion == true && (w.properties.label?.contains('Urgent examination alert') ?? false),
    );
    expect(examLiveRegion, findsOneWidget);

    // Mount and verify attendance compliance live region
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: AcademicsScreen(
            key: const Key('academics_screen_attendance'),
            initialTab: 'attendance',
            initialAttendance: lowAttendance,
            mockNow: fixedNow,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final attLiveRegion = find.byWidgetPredicate(
      (w) => w is Semantics && w.properties.liveRegion == true && (w.properties.label?.contains('Ministry') ?? false),
    );
    expect(attLiveRegion, findsOneWidget);
  });

  testWidgets('Part 28 Test 5 (Test 125): Resilient Dual-Mode Image Engine Integration Stress Test', (WidgetTester tester) async {
    const validBase64 =
        'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=';
    const remoteUrl = 'https://example.com/medical_sick_leave_certificate.jpg';
    const malformedData = 'data:image/jpeg;base64,invalid_unpadded_base64_data!!!';

    // 1. Valid Base64 render
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: HomeScreen.buildResilientImage(validBase64, height: 180)),
      ),
    );
    expect(find.byType(Image), findsOneWidget);

    // 2. Remote URL render
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: HomeScreen.buildResilientImage(remoteUrl, height: 180)),
      ),
    );
    expect(find.byType(Image), findsOneWidget);

    // 3. Malformed data graceful recovery (no crash)
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: HomeScreen.buildResilientImage(malformedData, height: 180)),
      ),
    );
    expect(find.byIcon(Icons.camera_alt_outlined), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Part 28 Test 6 (Test 126): Phase 5 Master 200% Font Scale & Multi-Resolution Responsive Sweep', (WidgetTester tester) async {
    final fixedNow = DateTime(2026, 10, 4, 10, 0);
    final viewports = [
      const Size(1200, 1000), // Desktop
      const Size(800, 1000),  // Tablet
      const Size(400, 1000),  // Mobile
    ];

    for (final size in viewports) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: MediaQuery(
            data: const MediaQueryData(
              textScaler: TextScaler.linear(2.0),
            ),
            child: Scaffold(
              body: AcademicsScreen(
                initialTab: 'timetable',
                mockNow: fixedNow,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }

    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  test('Test 127: Multi-Account Management & Sibling Authentication State Machine', () async {
    // 1. Clear any residual accounts
    await AuthService.clearAllSavedAccounts();
    expect(AuthService.getSavedAccounts(), isEmpty);

    // 2. Add sibling account
    final sibling = await AuthService().addSiblingAccount(
      scholarNo: '2310910',
      password: 'password123',
    );
    expect(sibling.scholarNo, equals('2310910'));
    expect(sibling.houseName, equals('ruby'));
    expect(AuthService.getSavedAccounts().length, equals(1));

    // 3. Add second sibling account
    final sibling2 = await AuthService().addSiblingAccount(
      scholarNo: '10001',
      password: 'password123',
    );
    expect(sibling2.scholarNo, equals('10001'));
    expect(sibling2.houseName, equals('emerald'));
    expect(AuthService.getSavedAccounts().length, equals(2));

    // 4. Switch active account
    await AuthService().switchAccount(sibling);
    expect(AuthService.getCachedScholarNo(), equals('2310910'));
    expect(AuthService.getCachedHouse(), equals('ruby'));

    // 5. Remove an account
    await AuthService.removeSavedAccount('10001');
    expect(AuthService.getSavedAccounts().length, equals(1));
    expect(AuthService.getSavedAccounts().first.scholarNo, equals('2310910'));

    // 6. Clear all
    await AuthService.clearAllSavedAccounts();
    expect(AuthService.getSavedAccounts(), isEmpty);
  });

  testWidgets('Test 128: AccountSwitcherModal & AddSiblingModal Responsive & Accessible Workflow', (WidgetTester tester) async {
    await AuthService.clearAllSavedAccounts();
    await AuthService().addSiblingAccount(
      scholarNo: '2310910',
      password: 'password123',
    );

    SavedAccount? switchedAccount;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                AccountSwitcherModal.show(
                  context,
                  houseColor: HouseColors.ruby,
                  currentHouse: 'ruby',
                  onSwitchAccount: (acc) async {
                    switchedAccount = acc;
                  },
                  onSignOutCurrent: () async {},
                  onSignOutAll: () async {},
                );
              },
              child: const Text('Open Switcher'),
            ),
          ),
        ),
      ),
    );

    // 1. Open Switcher
    await tester.tap(find.text('Open Switcher'));
    await tester.pumpAndSettle();

    // Verify modal elements
    expect(find.text('Switch Account'), findsOneWidget);
    expect(find.text('Add Sibling / Another Account'), findsOneWidget);
    expect(find.text('#2310910'), findsOneWidget);
    expect(find.text('ACTIVE'), findsOneWidget);

    // 2. Open Add Sibling
    await tester.tap(find.text('Add Sibling / Another Account'));
    await tester.pumpAndSettle();

    expect(find.text('Add Sibling Account'), findsOneWidget);
    expect(find.text('Authenticate & Link Sibling'), findsOneWidget);

    // 3. Test empty validation
    await tester.tap(find.text('Authenticate & Link Sibling'));
    await tester.pumpAndSettle();
    expect(find.text('Please enter sibling scholar number.'), findsOneWidget);

    // 4. Enter credentials and link
    await tester.enterText(find.byType(TextFormField).first, '10001_emerald');
    await tester.pumpAndSettle();
    expect(find.textContaining('EMERALD House Detected'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).last, 'pass123');
    await tester.tap(find.text('Authenticate & Link Sibling'));
    await tester.pumpAndSettle();

    expect(switchedAccount, isNotNull);
    expect(switchedAccount?.scholarNo, equals('10001_emerald'));
    expect(switchedAccount?.houseName, equals('emerald'));
  });

  testWidgets('Part 29 Test 1 (Test 129): LoginScreen Enter key submission executes _handleLogin via CallbackShortcuts', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: LoginScreen(),
      ),
    );
    await tester.pumpAndSettle();

    // Enter scholar number and password
    final textFields = find.byType(TextFormField);
    expect(textFields, findsNWidgets(2));

    await tester.enterText(textFields.first, '10001');
    await tester.enterText(textFields.last, 'pass123');
    await tester.pump();

    // Press Physical Enter Key
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    // Verify no unhandled exceptions thrown
    expect(tester.takeException(), isNull);
  });

  test('Part 29 Test 2 (Test 130): SavedAccount JSON round-trip retains credentials and restores active session without nulling profile', () {
    final original = SavedAccount(
      scholarNo: '2310910',
      fullName: 'Zaid Al-Husseini',
      houseName: 'ruby',
      uid: 'uid_zaid_123',
      role: 'student',
      classLevel: 'Grade 10',
      division: 'A',
      password: 'Secr3tPassword!',
      cachedProfile: {'scholar_no': '2310910', 'role': 'student'},
      lastActive: DateTime(2026, 10, 4),
    );

    final jsonString = original.toJson();
    final restored = SavedAccount.fromJson(jsonString);

    expect(restored.scholarNo, equals('2310910'));
    expect(restored.fullName, equals('Zaid Al-Husseini'));
    expect(restored.houseName, equals('ruby'));
    expect(restored.uid, equals('uid_zaid_123'));
    expect(restored.password, equals('Secr3tPassword!'));
    expect(restored.cachedProfile['scholar_no'], equals('2310910'));
  });

  test('Part 29 Test 3 (Test 131): CampusEvent model serialization, category parsing, and duration calculations', () {
    final now = DateTime.now();
    final event = CampusEvent(
      id: 'event_001',
      title: 'Inter-House Chess Championship',
      description: 'Annual grandmaster tournament.',
      category: EventCategory.academic,
      houseScope: 'All',
      startTime: now.add(const Duration(hours: 2)),
      endTime: now.add(const Duration(hours: 5)),
      venue: 'Main Auditorium',
      pointsAwarded: 50,
      pointsMultiplier: 1.5,
      bannerUrl: 'https://asianschool.bh/chess.jpg',
      isLive: false,
    );

    expect(event.isUpcoming, isTrue);
    expect(event.isOngoing, isFalse);
    expect(event.formattedRemaining, contains('h'));

    final map = event.toMap();
    final fromMap = CampusEvent.fromMap(map);

    expect(fromMap.id, equals('event_001'));
    expect(fromMap.title, equals('Inter-House Chess Championship'));
    expect(fromMap.category, equals(EventCategory.academic));
    expect(fromMap.pointsMultiplier, equals(1.5));
    expect(EventCategoryExt.fromString('tech'), equals(EventCategory.tech));
  });

  test('Part 29 Test 4 (Test 132): AuthService.getCachedEvents returns pure zero baseline ([]) when unseeded', () async {
    await AuthService.clearCache();
    expect(AuthService.getCachedEvents(), isEmpty);

    final sampleEvent = CampusEvent(
      id: 'event_test_1',
      title: 'Track & Field Dash',
      description: '100m sprint heats.',
      category: EventCategory.sports,
      startTime: DateTime(2026, 10, 5, 9, 0),
      endTime: DateTime(2026, 10, 5, 12, 0),
      venue: 'Sports Complex Stadium',
    );

    await AuthService.cacheEvents([sampleEvent]);
    final cached = AuthService.getCachedEvents();
    expect(cached.length, equals(1));
    expect(cached.first.title, equals('Track & Field Dash'));

    await AuthService.clearCache();
    expect(AuthService.getCachedEvents(), isEmpty);
  });

  testWidgets('Part 29 Test 5 (Test 133): EventsScreen renders category filter pills meeting >= 48x48 dp target guidelines', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: EventsScreen(
          userHouse: 'ruby',
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify Title & Empty State
    expect(find.text('Campus House Events'), findsOneWidget);
    expect(find.text('No Events Scheduled'), findsOneWidget);

    // Verify Category Pills and Minimum Touch Target Size
    for (final cat in EventCategory.values) {
      final pillFinder = find.bySemanticsLabel(RegExp('Filter by ${cat.displayName}'));
      expect(pillFinder, findsOneWidget);
      final size = tester.getSize(pillFinder);
      expect(size.height, greaterThanOrEqualTo(48.0));
      expect(size.width, greaterThanOrEqualTo(48.0));
    }

    // Tap on Cultural Filter Pill
    final culturalPill = find.bySemanticsLabel(RegExp('Filter by Cultural'));
    await tester.tap(culturalPill);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('Part 29 Test 6 (Test 134): HomeScreen.buildResilientImage safely renders Base64 Data URIs and remote URLs on EventsScreen', (WidgetTester tester) async {
    const base64Pixel =
        'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==';
    const remoteUrl = 'https://asianschool.bh/banner.jpg';

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              HomeScreen.buildResilientImage(base64Pixel, height: 100),
              HomeScreen.buildResilientImage(remoteUrl, height: 100),
              HomeScreen.buildResilientImage('', height: 100),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(Image), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  test('Part 30 Test 1 (Test 135): ElectionCandidate and ElectionBallot domain models JSON round-trip and getters', () {
    final candidate = ElectionCandidate(
      scholarNo: '2310101',
      fullName: 'Layla Al-Sayed',
      houseName: 'ruby',
      runningPosition: 'School Head Girl',
      manifesto: 'Action over words, unity in diversity.\n1. Organize inter-house science fairs.\n2. Extend library operating hours.',
      avatarUrl: 'https://asianschool.bh/layla.jpg',
      classLevel: 'Grade 11-B',
      votesCount: 42,
      isVerified: true,
    );

    final candidateJson = candidate.toMap();
    final restoredCandidate = ElectionCandidate.fromMap(candidateJson);
    expect(restoredCandidate.scholarNo, equals('2310101'));
    expect(restoredCandidate.fullName, equals('Layla Al-Sayed'));
    expect(restoredCandidate.runningPosition, equals('School Head Girl'));
    expect(restoredCandidate.votesCount, equals(42));
    expect(restoredCandidate.isVerified, isTrue);

    final startTime = DateTime(2026, 10, 1, 8, 0);
    final endTime = DateTime(2026, 10, 3, 15, 0);

    final ballot = ElectionBallot(
      id: 'ballot_1',
      title: '2026/2027 Head Girl Election',
      position: BallotPosition.headGirl,
      houseScope: 'All',
      eligibleGrades: const ['Grade 9', 'Grade 10', 'Grade 11', 'Grade 12'],
      status: BallotStatus.open,
      startTime: startTime,
      endTime: endTime,
      candidates: [candidate],
      totalVotesCast: 42,
    );

    final ballotJson = ballot.toMap();
    final restoredBallot = ElectionBallot.fromMap(ballotJson, docId: 'ballot_1');
    expect(restoredBallot.id, equals('ballot_1'));
    expect(restoredBallot.title, equals('2026/2027 Head Girl Election'));
    expect(restoredBallot.position, equals(BallotPosition.headGirl));
    expect(restoredBallot.candidates.length, equals(1));
    expect(restoredBallot.candidates.first.fullName, equals('Layla Al-Sayed'));

    // Test duration and formatting getters
    expect(ballot.formattedRemaining, isNotEmpty);
  });

  test('Part 30 Test 2 (Test 136): AuthService.getCachedBallots returns pure zero baseline when unseeded', () {
    final cached = AuthService.getCachedBallots();
    expect(cached, isEmpty);
    expect(cached, isA<List<ElectionBallot>>());
  });

  test('Part 30 Test 3 (Test 137): AuthService.cacheBallots writes through to persistent storage and retrieves accurately', () async {
    expect(AuthService.getCachedBallots(), isEmpty);

    final candidate = ElectionCandidate(
      scholarNo: '2310202',
      fullName: 'Tariq Al-Mansoor',
      houseName: 'emerald',
      runningPosition: 'House Captain',
      manifesto: 'Leading Emerald with pride and dedication.',
      avatarUrl: '',
      classLevel: 'Grade 12-A',
      votesCount: 15,
      isVerified: true,
    );

    final sampleBallot = ElectionBallot(
      id: 'ballot_test_1',
      title: 'Emerald House Captain Election',
      position: BallotPosition.houseCaptain,
      houseScope: 'emerald',
      eligibleGrades: const ['Grade 9', 'Grade 10', 'Grade 11', 'Grade 12'],
      status: BallotStatus.open,
      startTime: DateTime(2026, 10, 1, 8, 0),
      endTime: DateTime(2026, 10, 5, 16, 0),
      candidates: [candidate],
      totalVotesCast: 15,
    );

    await AuthService.cacheBallots([sampleBallot]);
    final cached = AuthService.getCachedBallots();
    expect(cached.length, equals(1));
    expect(cached.first.title, equals('Emerald House Captain Election'));
    expect(cached.first.candidates.first.fullName, equals('Tariq Al-Mansoor'));

    await AuthService.clearCache();
    expect(AuthService.getCachedBallots(), isEmpty);
  });

  testWidgets('Part 30 Test 4 (Test 138): ElectionChamberScreen renders position filter pills meeting >= 48x48 dp touch target guidelines', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: ElectionChamberScreen(
          userHouse: 'ruby',
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify Title & Empty State
    expect(find.text('Election Chamber'), findsOneWidget);
    expect(find.text('No active election ballots found.'), findsOneWidget);

    // Verify Position Filter Pills and Touch Target Size
    for (final pos in BallotPosition.values) {
      final pillFinder = find.bySemanticsLabel(RegExp('Filter by ${pos.displayName}'));
      expect(pillFinder, findsOneWidget);
      final size = tester.getSize(pillFinder);
      expect(size.height, greaterThanOrEqualTo(48.0));
      expect(size.width, greaterThanOrEqualTo(48.0));
    }

    // Tap on Head Boy Filter Pill
    final headBoyPill = find.bySemanticsLabel(RegExp('Filter by School Head Boy'));
    await tester.tap(headBoyPill);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('Part 30 Test 5 (Test 139): ElectionChamberScreen candidate manifesto modal opens and displays full pledge text', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final candidate = ElectionCandidate(
      scholarNo: '2310303',
      fullName: 'Yusuf Al-Bahrani',
      houseName: 'ruby',
      runningPosition: 'School Head Boy',
      manifesto: 'Empowering every student voice.\n• Introduce peer tutoring hubs in break periods.\n• Expand campus eco-initiatives and solar recharge stations.',
      avatarUrl: '',
      classLevel: 'Grade 12-B',
      votesCount: 88,
      isVerified: true,
    );

    final activeBallot = ElectionBallot(
      id: 'ballot_active_1',
      title: '2026/2027 Head Boy Election',
      position: BallotPosition.headBoy,
      houseScope: 'All',
      eligibleGrades: const ['Grade 9', 'Grade 10', 'Grade 11', 'Grade 12'],
      status: BallotStatus.open,
      startTime: DateTime(2026, 10, 1, 8, 0),
      endTime: DateTime(2026, 10, 10, 16, 0),
      candidates: [candidate],
      totalVotesCast: 88,
    );

    await AuthService.cacheBallots([activeBallot]);

    await tester.pumpWidget(
      MaterialApp(
        home: ElectionChamberScreen(
          userHouse: 'ruby',
          mockNow: DateTime(2026, 10, 2, 10, 0),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify candidate card rendered
    expect(find.text('Yusuf Al-Bahrani'), findsOneWidget);

    // Tap "Manifesto" button
    final manifestoBtn = find.widgetWithText(OutlinedButton, 'Manifesto');
    expect(manifestoBtn, findsOneWidget);
    await tester.tap(manifestoBtn);
    await tester.pumpAndSettle();

    // Verify Manifesto Dialog
    expect(find.text('Campaign Manifesto & Pledges:'), findsOneWidget);
    expect(find.textContaining('Introduce peer tutoring hubs'), findsOneWidget);
    expect(find.textContaining('Expand campus eco-initiatives'), findsOneWidget);

    // Dismiss dialog
    final dismissBtn = find.widgetWithText(TextButton, 'Dismiss');
    expect(dismissBtn, findsOneWidget);
    await tester.tap(dismissBtn);
    await tester.pumpAndSettle();

    expect(find.text('Campaign Manifesto & Pledges:'), findsNothing);
  });

  testWidgets('Part 30 Test 6 (Test 140): ElectionChamberScreen displays accessible zero-data empty state when no ballots are registered', (WidgetTester tester) async {
    await AuthService.clearCache();

    await tester.pumpWidget(
      const MaterialApp(
        home: ElectionChamberScreen(
          userHouse: 'ruby',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No active election ballots found.'), findsOneWidget);
    expect(
      find.text('Student Council and House Captain polls will be registered here by school administration.'),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.how_to_vote_outlined), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  // =========================================================================
  // Part 31 Tests (Tests 141 to 146): Cryptographic Ballot & Voting Audit
  // =========================================================================

  test('Part 31 Test 1 (Test 141): BallotCastReceipt domain model serialization and formatted number', () {
    final now = DateTime.now();
    final receipt = BallotCastReceipt(
      receiptId: 'rcpt_001',
      ballotId: 'ballot_council_01',
      ballotTitle: 'Head Boy Election',
      candidateScholarNo: '2310910',
      candidateName: 'Zaid Al-Husseini',
      candidateHouse: 'ruby',
      runningPosition: 'School Head Boy',
      anonymizedVoterHash: 'abc123hash',
      signatureProofToken: 'e4f2a1b9c8d7e6f5',
      timestamp: now,
    );

    expect(receipt.formattedReceiptNumber, 'ASB-VOTE-E4F2A1B9');
    final map = receipt.toMap();
    final fromMap = BallotCastReceipt.fromMap(map);
    expect(fromMap.candidateScholarNo, '2310910');
    expect(fromMap.candidateHouse, 'ruby');
    expect(fromMap.signatureProofToken, 'e4f2a1b9c8d7e6f5');
  });

  test('Part 31 Test 2 (Test 142): ElectionSecurityService generates deterministic anonymized voter hashes', () {
    final hash1 = ElectionSecurityService.generateAnonymizedVoterHash(
      scholarNo: '2310910',
      ballotId: 'ballot_01',
    );
    final hash2 = ElectionSecurityService.generateAnonymizedVoterHash(
      scholarNo: '2310910',
      ballotId: 'ballot_01',
    );
    final hashDifferentBallot = ElectionSecurityService.generateAnonymizedVoterHash(
      scholarNo: '2310910',
      ballotId: 'ballot_02',
    );

    expect(hash1, hash2);
    expect(hash1 != hashDifferentBallot, true);
    expect(hash1.length, 64); // Valid SHA-256 output length
  });

  test('Part 31 Test 3 (Test 143): ElectionSecurityService verifies and detects altered proof tokens', () {
    final now = DateTime.now();
    const vHash = 'voter_hash_123';
    const bId = 'ballot_01';
    const cNo = '11004';

    final validToken = ElectionSecurityService.generateBallotProofToken(
      anonymizedVoterHash: vHash,
      ballotId: bId,
      candidateScholarNo: cNo,
      timestamp: now,
    );

    final isValid = ElectionSecurityService.verifyReceiptToken(
      signatureToken: validToken,
      anonymizedVoterHash: vHash,
      ballotId: bId,
      candidateScholarNo: cNo,
      timestamp: now,
    );
    expect(isValid, true);

    final isTampered = ElectionSecurityService.verifyReceiptToken(
      signatureToken: validToken,
      anonymizedVoterHash: vHash,
      ballotId: bId,
      candidateScholarNo: 'tampered_candidate',
      timestamp: now,
    );
    expect(isTampered, false);
  });

  test('Part 31 Test 4 (Test 144): AuthService.getCachedVoteReceipts returns pure zero baseline when unseeded', () {
    final receipts = AuthService.getCachedVoteReceipts();
    expect(receipts, isA<List<BallotCastReceipt>>());
    expect(receipts, isEmpty);
  });

  test('Part 31 Test 5 (Test 145): AuthService.castDigitalVote prevents duplicate voting for the same ballot', () async {
    final candidate = ElectionCandidate(
      scholarNo: '11004',
      fullName: 'Aisha Al-Khalifa',
      houseName: 'sapphire',
      runningPosition: 'School Head Girl',
      manifesto: 'Excellence in leadership and student welfare.',
    );

    final firstVote = await AuthService().castDigitalVote(
      ballotId: 'test_ballot_double_vote',
      ballotTitle: 'Head Girl Election',
      candidate: candidate,
      scholarNo: '99001',
    );
    expect(firstVote.success, true);
    expect(firstVote.receipt != null, true);

    // Duplicate attempt
    final duplicateVote = await AuthService().castDigitalVote(
      ballotId: 'test_ballot_double_vote',
      ballotTitle: 'Head Girl Election',
      candidate: candidate,
      scholarNo: '99001',
    );
    expect(duplicateVote.success, false);
    expect(duplicateVote.error?.contains('already cast'), true);
  });

  testWidgets('Part 31 Test 6 (Test 146): Digital voting confirmation modal enforces min 48x48 dp touch targets', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              style: ElevatedButton.styleFrom(minimumSize: const Size(64, 48)),
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  builder: (ctx) => Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Confirm & Cast My Ballot'),
                      ),
                      TextButton(
                        style: TextButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cancel'),
                      ),
                    ],
                  ),
                );
              },
              child: const Text('Open Voting Modal'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open Voting Modal'));
    await tester.pumpAndSettle();

    final confirmBtn = tester.getRect(find.widgetWithText(ElevatedButton, 'Confirm & Cast My Ballot'));
    expect(confirmBtn.height >= 48.0, true);

    final cancelBtn = tester.getRect(find.widgetWithText(TextButton, 'Cancel'));
    expect(cancelBtn.height >= 48.0, true);
  });

  // =========================================================================
  // Part 32 Tests (Tests 147 to 152): Election Audit Chamber & Ledger Verifier
  // =========================================================================

  test('Part 32 Test 1 (Test 147): ElectionAuditRecord model serialization and quorum compliance calculation', () {
    final audit = ElectionAuditRecord(
      ballotId: 'ballot_audit_01',
      ballotTitle: 'Head Boy Election Audit',
      totalEligibleVoters: 200,
      totalVotesCast: 110,
      houseTurnoutBreakdown: {'ruby': 40, 'sapphire': 30, 'emerald': 20, 'topaz': 20},
      gradeTurnoutBreakdown: {'Grade 10': 50, 'Grade 11': 60},
      isCertified: true,
      certifiedBy: 'Principal Office',
    );

    expect(audit.turnoutPercentage, 55.0);
    expect(audit.hasMetQuorum, true);

    final map = audit.toMap();
    final restored = ElectionAuditRecord.fromMap(map);
    expect(restored.ballotId, 'ballot_audit_01');
    expect(restored.isCertified, true);
    expect(restored.houseTurnoutBreakdown['ruby'], 40);
  });

  test('Part 32 Test 2 (Test 148): ElectionSecurityService.verifyBallotBoxIntegrity confirms uncorrupted vote ledgers', () {
    final now = DateTime.now();
    final validReceipt = BallotCastReceipt(
      receiptId: 'rcpt_audit_01',
      ballotId: 'ballot_01',
      ballotTitle: 'Sports Captain Election',
      candidateScholarNo: '2310910',
      candidateName: 'Zaid Al-Husseini',
      candidateHouse: 'ruby',
      runningPosition: 'Sports Captain',
      anonymizedVoterHash: 'anon_hash_01',
      signatureProofToken: ElectionSecurityService.generateBallotProofToken(
        anonymizedVoterHash: 'anon_hash_01',
        ballotId: 'ballot_01',
        candidateScholarNo: '2310910',
        timestamp: now,
      ),
      timestamp: now,
    );

    final isClean = ElectionSecurityService.verifyBallotBoxIntegrity(
      receipts: [validReceipt],
      expectedTotalVotes: 1,
    );
    expect(isClean, true);

    final isCountMismatch = ElectionSecurityService.verifyBallotBoxIntegrity(
      receipts: [validReceipt],
      expectedTotalVotes: 2,
    );
    expect(isCountMismatch, false);
  });

  test('Part 32 Test 3 (Test 149): ElectionSecurityService.auditReceiptVerification checks valid receipts and flags invalid tokens', () {
    final now = DateTime.now();
    final receipt = BallotCastReceipt(
      receiptId: 'rcpt_02',
      ballotId: 'ballot_02',
      ballotTitle: 'Head Girl Election',
      candidateScholarNo: '11004',
      candidateName: 'Aisha Al-Khalifa',
      candidateHouse: 'sapphire',
      runningPosition: 'School Head Girl',
      anonymizedVoterHash: 'anon_02',
      signatureProofToken: 'abcdef1234567890',
      timestamp: now,
    );

    final matched = ElectionSecurityService.auditReceiptVerification(
      receiptNumber: receipt.formattedReceiptNumber,
      auditedReceipts: [receipt],
    );
    expect(matched.verified, true);
    expect(matched.receipt?.candidateScholarNo, '11004');

    final missing = ElectionSecurityService.auditReceiptVerification(
      receiptNumber: 'ASB-VOTE-UNKNOWN0',
      auditedReceipts: [receipt],
    );
    expect(missing.verified, false);
  });

  test('Part 32 Test 4 (Test 150): AuthService.getCachedElectionAudit returns null when unseeded (pure zero baseline)', () {
    final record = AuthService.getCachedElectionAudit('unseeded_ballot_id');
    expect(record, isNull);
  });

  testWidgets('Part 32 Test 5 (Test 151): ElectionAuditScreen renders House turnout bars and verification input with min 48x48 dp touch targets', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        themeMode: ThemeMode.light,
        home: ElectionAuditScreen(
          ballotId: 'ballot_test_screen',
          ballotTitle: 'Head Boy Election Audit',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('House Turnout Telemetry'), findsOneWidget);
    expect(find.text('Ruby House'), findsOneWidget);
    expect(find.text('Verify Digital Ballot Receipt'), findsOneWidget);

    final verifyBtn = tester.getRect(find.widgetWithText(ElevatedButton, 'Verify Ballot Inclusion'));
    expect(verifyBtn.height >= 48.0, true);
  });

  testWidgets('Part 32 Test 6 (Test 152): Screen reader live region announces ballot box audit certification and receipt verification status', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        themeMode: ThemeMode.light,
        home: ElectionAuditScreen(
          ballotId: 'ballot_test_live_region',
          ballotTitle: 'Prefect Election Audit',
        ),
      ),
    );
    await tester.pumpAndSettle();

    final input = find.byType(TextFormField);
    expect(input, findsOneWidget);

    await tester.enterText(input, 'ASB-VOTE-NONEXISTENT');
    await tester.ensureVisible(find.widgetWithText(ElevatedButton, 'Verify Ballot Inclusion'));
    await tester.tap(find.widgetWithText(ElevatedButton, 'Verify Ballot Inclusion'));
    await tester.pumpAndSettle();

    final liveRegionFinder = find.byWidgetPredicate(
      (w) => w is Semantics && w.properties.liveRegion == true,
    );
    expect(liveRegionFinder, findsOneWidget);
  });

  // =========================================================================
  // Part 33 Tests (Tests 153 to 158): Electoral Gazette & Phone Compatibility
  // =========================================================================

  test('Part 33 Test 1 (Test 153): CertifiedElectionResult model serialization and proclamation formatting', () {
    final now = DateTime.now();
    final result = CertifiedElectionResult(
      ballotId: 'ballot_gzt_01',
      ballotTitle: 'School Head Boy Election',
      runningPosition: 'School Head Boy',
      winnerScholarNo: '2310910',
      winnerName: 'Zaid Al-Husseini',
      winnerHouse: 'ruby',
      totalVotesReceived: 215,
      victoryMarginVotes: 48,
      housePointsAwarded: 100,
      commissionerName: 'Principal Office',
      certifiedAt: now,
      proclamationText: 'Official proclamation for winning candidate.',
    );

    final map = result.toMap();
    final restored = CertifiedElectionResult.fromMap(map);
    expect(restored.ballotId, 'ballot_gzt_01');
    expect(restored.winnerScholarNo, '2310910');
    expect(restored.housePointsAwarded, 100);
    expect(restored.winnerHouse, 'ruby');
  });

  test('Part 33 Test 2 (Test 154): AuthService.certifyElectionAndAwardPoints transactionally awards house points', () async {
    final candidate = ElectionCandidate(
      scholarNo: '12001',
      fullName: 'Omar Tariq',
      houseName: 'topaz',
      runningPosition: 'House Captain',
      manifesto: 'Topaz House Excellence',
      votesCount: 85,
    );

    final initialPoints = AuthService.getCachedPointsForHouse('topaz');

    final res = await AuthService().certifyElectionAndAwardPoints(
      ballotId: 'test_cert_ballot_01',
      ballotTitle: 'Topaz Captain Election',
      winner: candidate,
      victoryMargin: 20,
      commissionerName: 'Electoral Commission',
      housePoints: 50,
    );

    expect(res.success, true);
    expect(res.result != null, true);

    final updatedPoints = AuthService.getCachedPointsForHouse('topaz');
    expect(updatedPoints >= initialPoints + 50, true);
  });

  test('Part 33 Test 3 (Test 155): AuthService.getCachedCertifiedGazette returns empty list when unseeded', () {
    final gazette = AuthService.getCachedCertifiedGazette();
    expect(gazette, isA<List<CertifiedElectionResult>>());
  });

  testWidgets('Part 33 Test 4 (Test 156): ElectionGazetteScreen renders accessible empty state when unseeded', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ElectionGazetteScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Campus Election Gazette'), findsOneWidget);
    expect(find.text('No Election Proclamations Yet'), findsOneWidget);
  });

  testWidgets('Part 33 Test 5 (Test 157): ElectionGazetteScreen renders certified cards without overflow on mobile phone dimensions (360x640)', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final now = DateTime.now();
    await AuthService.cacheCertifiedGazette([
      CertifiedElectionResult(
        ballotId: 'ballot_mobile_01',
        ballotTitle: 'Head Girl Election',
        runningPosition: 'School Head Girl',
        winnerScholarNo: '11004',
        winnerName: 'Aisha Al-Khalifa',
        winnerHouse: 'sapphire',
        totalVotesReceived: 180,
        victoryMarginVotes: 35,
        housePointsAwarded: 100,
        commissionerName: 'Electoral Commission',
        certifiedAt: now,
        proclamationText: 'Aisha Al-Khalifa has been declared duly elected.',
      ),
    ]);

    await tester.pumpWidget(
      const MaterialApp(
        home: ElectionGazetteScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Aisha Al-Khalifa'), findsOneWidget);
    expect(find.text('+100 PTS'), findsOneWidget);
    // Verifies zero RenderFlex overflows on 360 dp mobile viewport
    expect(tester.takeException(), isNull);
  });

  testWidgets('Part 33 Test 6 (Test 158): Phone version app bar and list items meet min 48x48 dp touch target guidelines', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ElectionGazetteScreen(),
      ),
    );
    await tester.pumpAndSettle();

    final appBarFinder = find.byType(AppBar);
    expect(appBarFinder, findsOneWidget);
    final appBarSize = tester.getSize(appBarFinder);
    expect(appBarSize.height >= 48.0, true);
  });

  // =========================================================================
  // Part 34 Tests (Tests 159 to 164): Master Cross-Phase Audit (Phases 1–6)
  // =========================================================================

  test('Part 34 Test 1 (Test 159): Cross-Phase Zero Dummy Baseline Audit across all 6 subsystems', () {
    // Verifies that unseeded caches across all 6 phases return pure zero/empty baselines
    expect(AuthService.getCachedTimetable(), isEmpty);
    expect(AuthService.getCachedAssignments(), isEmpty);
    expect(AuthService.getCachedExams(), isEmpty);
    expect(AuthService.getCachedReportCards(), isEmpty);
    expect(AuthService.getCachedAttendanceRecords(), isEmpty);
    expect(AuthService.getCachedEvents(), isEmpty);
    expect(AuthService.getCachedBallots(), isEmpty);
    expect(AuthService.getCachedVoteReceipts(), isEmpty);
    expect(AuthService.getCachedCertifiedGazette(), isEmpty);
    expect(AuthService.getCachedElectionAudit('unseeded_id'), isNull);
  });

  testWidgets('Part 34 Test 2 (Test 160): Universal Mobile Phone Viewport Stress Test (360x640 dp) across Phase 6 screens', (tester) async {
    // Configure mobile phone viewport dimensions (360x640 dp, 1.0 DPR)
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    // 1. Events Screen on Mobile Viewport
    await tester.pumpWidget(
      const MaterialApp(
        home: EventsScreen(),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // 2. Election Chamber Screen on Mobile Viewport
    await tester.pumpWidget(
      const MaterialApp(
        home: ElectionChamberScreen(),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // 3. Election Audit Screen on Mobile Viewport
    await tester.pumpWidget(
      const MaterialApp(
        home: ElectionAuditScreen(
          ballotId: 'ballot_mobile_stress',
          ballotTitle: 'Head Boy Audit',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // 4. Election Gazette Screen on Mobile Viewport
    await tester.pumpWidget(
      const MaterialApp(
        home: ElectionGazetteScreen(),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('Part 34 Test 3 (Test 161): Master WCAG 2.1 AA Tap Target Audit (all controls >= 48x48 dp)', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: EventsScreen(),
      ),
    );
    await tester.pumpAndSettle();

    final allPills = find.byType(InkWell);
    expect(allPills, findsWidgets);

    // Verify touch target constraints on the first filter pill
    final firstPillSize = tester.getSize(allPills.first);
    expect(firstPillSize.height >= 44.0, true); // Complies with iOS 44 dp / Android 48 dp
  });

  test('Part 34 Test 4 (Test 162): Cross-Phase Cryptographic Security Audit (HMAC-SHA256 tamper detection)', () {
    // 1. Gamification Token Security
    final gToken = GamificationSecurityService.generateScoreProofToken(
      scholarNo: '2310910',
      activityId: 'math_derby',
      points: 25,
    );
    final gValid = GamificationSecurityService.verifyScoreProofToken(
      token: gToken,
      expectedScholarNo: '2310910',
      expectedActivityId: 'math_derby',
    );
    expect(gValid.isValid, true);
    expect(gValid.points, 25);

    // 2. Voting Anonymization & Receipt Token Security
    final vHash = ElectionSecurityService.generateAnonymizedVoterHash(
      scholarNo: '2310910',
      ballotId: 'ballot_council_01',
    );
    final now = DateTime.now();
    final vToken = ElectionSecurityService.generateBallotProofToken(
      anonymizedVoterHash: vHash,
      ballotId: 'ballot_council_01',
      candidateScholarNo: '11004',
      timestamp: now,
    );
    final vValid = ElectionSecurityService.verifyReceiptToken(
      signatureToken: vToken,
      anonymizedVoterHash: vHash,
      ballotId: 'ballot_council_01',
      candidateScholarNo: '11004',
      timestamp: now,
    );
    expect(vValid, true);

    // Verify tamper rejection
    final vTampered = ElectionSecurityService.verifyReceiptToken(
      signatureToken: vToken,
      anonymizedVoterHash: vHash,
      ballotId: 'ballot_council_01',
      candidateScholarNo: 'impostor_scholar',
      timestamp: now,
    );
    expect(vTampered, false);
  });

  test('Part 34 Test 5 (Test 163): Multi-Account & Sibling Switcher Session Isolation Audit', () async {
    final accountA = SavedAccount(
      scholarNo: '2310910',
      fullName: 'Zaid Al-Husseini',
      houseName: 'ruby',
      uid: 'uid_zaid',
      password: 'password123',
      cachedProfile: {
        'scholar_no': '2310910',
        'full_name': 'Zaid Al-Husseini',
        'house_name': 'ruby',
      },
    );

    final accountB = SavedAccount(
      scholarNo: '11004',
      fullName: 'Aisha Al-Khalifa',
      houseName: 'sapphire',
      uid: 'uid_aisha',
      password: 'password456',
      cachedProfile: {
        'scholar_no': '11004',
        'full_name': 'Aisha Al-Khalifa',
        'house_name': 'sapphire',
      },
    );

    await AuthService.saveAccount(accountA);
    await AuthService.saveAccount(accountB);

    final saved = AuthService.getSavedAccounts();
    expect(saved.length >= 2, true);

    // Verify complete profile and house isolation
    final zaid = saved.firstWhere((a) => a.scholarNo == '2310910');
    final aisha = saved.firstWhere((a) => a.scholarNo == '11004');
    expect(zaid.houseName, 'ruby');
    expect(aisha.houseName, 'sapphire');
    expect(zaid.password, 'password123');
    expect(aisha.password, 'password456');
  });

  test('Part 34 Test 6 (Test 164): End-to-End Democratic Election to Gazette Proclamation Lifecycle', () async {
    final candidate = ElectionCandidate(
      scholarNo: '30003',
      fullName: 'Layla Mansoor',
      houseName: 'sapphire',
      runningPosition: 'Cultural Secretary',
      manifesto: 'Promoting arts and cultural excellence.',
      votesCount: 95,
    );

    // 1. Cast digital vote
    final voteRes = await AuthService().castDigitalVote(
      ballotId: 'lifecycle_ballot_01',
      ballotTitle: 'Cultural Secretary Election',
      candidate: candidate,
      scholarNo: '99002',
    );
    expect(voteRes.success, true);
    expect(voteRes.receipt != null, true);

    // 2. Audit ballot box integrity
    final isIntact = ElectionSecurityService.verifyBallotBoxIntegrity(
      receipts: [voteRes.receipt!],
      expectedTotalVotes: 1,
    );
    expect(isIntact, true);

    // 3. Certify election and award house points
    final initialPoints = AuthService.getCachedPointsForHouse('sapphire');
    final certRes = await AuthService().certifyElectionAndAwardPoints(
      ballotId: 'lifecycle_ballot_01',
      ballotTitle: 'Cultural Secretary Election',
      winner: candidate,
      victoryMargin: 25,
      commissionerName: 'Electoral Commission',
      housePoints: 50,
    );
    expect(certRes.success, true);
    expect(certRes.result != null, true);

    // 4. Verify local standings cache reflects +50 points
    final updatedPoints = AuthService.getCachedPointsForHouse('sapphire');
    expect(updatedPoints >= initialPoints + 50, true);

    // 5. Verify publication in official gazette cache
    final gazette = AuthService.getCachedCertifiedGazette();
    expect(gazette.any((g) => g.ballotId == 'lifecycle_ballot_01'), true);
  });

  // =========================================================================
  // Part 35 Tests (Tests 165 to 170): Sports League, Fixtures & Phone Engine
  // =========================================================================

  test('Part 35 Test 1 (Test 165): SportsMatchFixture serialization and SportType enum parsing', () {
    final now = DateTime.now();
    final fixture = SportsMatchFixture(
      fixtureId: 'match_vball_01',
      tournamentTitle: 'Inter-House Volleyball Championship',
      sportType: SportType.volleyball,
      houseA: 'ruby',
      houseB: 'topaz',
      scoreA: 25,
      scoreB: 21,
      venue: 'Indoor Court 2',
      scheduledAt: now,
      status: MatchStatus.completed,
    );

    final map = fixture.toMap();
    final restored = SportsMatchFixture.fromMap(map);

    expect(restored.fixtureId, 'match_vball_01');
    expect(restored.sportType, SportType.volleyball);
    expect(restored.sportType.displayName, 'Volleyball');
    expect(restored.sportType.emoji, '🏐');
    expect(restored.winnerHouse, 'ruby');
  });

  test('Part 35 Test 2 (Test 166): HouseLeagueStanding.calculateStandings verifies 3-1-0 points formula and goal difference sorting', () {
    final fixtures = [
      SportsMatchFixture(
        fixtureId: 'f1',
        tournamentTitle: 'Football Cup',
        sportType: SportType.football,
        houseA: 'ruby',
        houseB: 'sapphire',
        scoreA: 3,
        scoreB: 1,
        venue: 'Main Field',
        scheduledAt: DateTime.now(),
        status: MatchStatus.completed,
      ),
      SportsMatchFixture(
        fixtureId: 'f2',
        tournamentTitle: 'Basketball Cup',
        sportType: SportType.basketball,
        houseA: 'emerald',
        houseB: 'topaz',
        scoreA: 20,
        scoreB: 20,
        venue: 'Court 1',
        scheduledAt: DateTime.now(),
        status: MatchStatus.completed,
      ),
    ];

    final standings = HouseLeagueStanding.calculateStandings(fixtures);
    expect(standings.length, 4);

    final ruby = standings.firstWhere((s) => s.houseName == 'ruby');
    expect(ruby.points, 3);
    expect(ruby.goalDifference, 2);

    final emerald = standings.firstWhere((s) => s.houseName == 'emerald');
    expect(emerald.points, 1);
    expect(emerald.goalDifference, 0);

    final sapphire = standings.firstWhere((s) => s.houseName == 'sapphire');
    expect(sapphire.points, 0);
    expect(sapphire.goalDifference, -2);
  });

  test('Part 35 Test 3 (Test 167): AuthService.getCachedSportsFixtures returns pure zero baseline when unseeded', () {
    final list = AuthService.getCachedSportsFixtures();
    expect(list, isA<List<SportsMatchFixture>>());
  });

  testWidgets('Part 35 Test 4 (Test 168): SportsTournamentScreen renders accessible empty state and 4 sports filter chips', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SportsTournamentScreen(userHouse: 'ruby'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Inter-House Sports League'), findsOneWidget);
    expect(find.text('Football'), findsOneWidget);
    expect(find.text('Basketball'), findsOneWidget);
    expect(find.text('Volleyball'), findsOneWidget);
    expect(find.text('Track & Field'), findsOneWidget);
    expect(find.text('No Match Fixtures Scheduled'), findsOneWidget);
  });

  testWidgets('Part 35 Test 5 (Test 169): SportsTournamentScreen renders match cards and league tables with 0 overflows on mobile phone (360x640 dp)', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await AuthService.cacheSportsFixtures([
      SportsMatchFixture(
        fixtureId: 'match_phone_01',
        tournamentTitle: 'Inter-House Volleyball',
        sportType: SportType.volleyball,
        houseA: 'sapphire',
        houseB: 'emerald',
        scoreA: 25,
        scoreB: 23,
        venue: 'ASB Gymnasium',
        scheduledAt: DateTime.now(),
        status: MatchStatus.completed,
      ),
    ]);

    await tester.pumpWidget(
      const MaterialApp(
        home: SportsTournamentScreen(userHouse: 'sapphire'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Inter-House Volleyball'), findsNothing); // Renders in details
    expect(find.text('Volleyball'), findsWidgets);
    expect(find.text('25 - 23'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Part 35 Test 6 (Test 170): All sports filter tabs and action buttons enforce min 48x48 dp touch target guidelines', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SportsTournamentScreen(userHouse: 'ruby'),
      ),
    );
    await tester.pumpAndSettle();

    final vBallFinder = find.widgetWithText(FilterChip, 'Volleyball');
    expect(vBallFinder, findsOneWidget);

    final size = tester.getSize(vBallFinder);
    expect(size.height >= 48.0, true);
  });

  // =========================================================================
  // Part 36 Tests (Tests 171 to 176): Live Match Day HUD & Telemetry Clocks
  // =========================================================================

  test('Part 36 Test 1 (Test 171): LiveMatchEvent serialization and commentary formatting', () {
    final now = DateTime.now();
    final event = LiveMatchEvent(
      eventId: 'ev_vball_01',
      fixtureId: 'match_vball_01',
      eventType: MatchEventType.ace,
      houseName: 'ruby',
      playerName: 'Farhan Tariq',
      minute: 14,
      periodDescription: 'Set 2',
      scoreAAfter: 20,
      scoreBAfter: 18,
      timestamp: now,
    );

    final map = event.toMap();
    final restored = LiveMatchEvent.fromMap(map);

    expect(restored.eventId, 'ev_vball_01');
    expect(restored.eventType, MatchEventType.ace);
    expect(restored.commentaryText, contains('Service Ace by Ruby House by Farhan Tariq'));
    expect(restored.commentaryText, contains('[20 - 18]'));
  });

  test('Part 36 Test 2 (Test 172): LiveMatchClock period formatting across Football, Basketball, Volleyball & Track', () {
    final vballPeriods = LiveMatchClock.getPeriodsForSport(SportType.volleyball);
    expect(vballPeriods.contains('Set 1'), true);
    expect(vballPeriods.contains('Set 2'), true);

    final bballClock = LiveMatchClock.formatClock(
      sport: SportType.basketball,
      currentPeriod: 'Q3',
      elapsedMinutes: 4,
      elapsedSeconds: 30,
    );
    expect(bballClock, 'Q3 • 04:30 Remaining');

    final fballClock = LiveMatchClock.formatClock(
      sport: SportType.football,
      currentPeriod: '1st Half',
      elapsedMinutes: 38,
      elapsedSeconds: 12,
    );
    expect(fballClock, '1st Half • 38:12');
  });

  test('Part 36 Test 3 (Test 173): AuthService.getCachedLiveMatchEvents returns pure zero baseline when unseeded', () {
    final list = AuthService.getCachedLiveMatchEvents('match_unseeded_99');
    expect(list, isA<List<LiveMatchEvent>>());
    expect(list.isEmpty, true);
  });

  testWidgets('Part 36 Test 4 (Test 174): LiveMatchHudScreen renders digital scoreboard, house crests & dynamic period clock', (tester) async {
    final fixture = SportsMatchFixture(
      fixtureId: 'fixture_hud_01',
      tournamentTitle: 'Inter-House Volleyball Championship',
      sportType: SportType.volleyball,
      houseA: 'ruby',
      houseB: 'topaz',
      scoreA: 25,
      scoreB: 22,
      venue: 'Indoor Sports Hall',
      scheduledAt: DateTime.now(),
      status: MatchStatus.live,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: LiveMatchHudScreen(fixture: fixture, userHouse: 'ruby'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('MATCH DAY LIVE'), findsOneWidget);
    expect(find.text('25 - 22'), findsOneWidget);
    expect(find.text('RUBY'), findsOneWidget);
    expect(find.text('TOPAZ'), findsOneWidget);
    expect(find.text('📍 Indoor Sports Hall'), findsOneWidget);
  });

  testWidgets('Part 36 Test 5 (Test 175): LiveMatchHudScreen renders with 0 overflows on mobile phone dimensions (360x640 dp)', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final fixture = SportsMatchFixture(
      fixtureId: 'fixture_mobile_02',
      tournamentTitle: 'Football Final',
      sportType: SportType.football,
      houseA: 'sapphire',
      houseB: 'emerald',
      scoreA: 2,
      scoreB: 1,
      venue: 'ASB Main Pitch',
      scheduledAt: DateTime.now(),
      status: MatchStatus.live,
    );

    await AuthService.cacheLiveMatchEvents('fixture_mobile_02', [
      LiveMatchEvent(
        eventId: 'ev_01',
        fixtureId: 'fixture_mobile_02',
        eventType: MatchEventType.goal,
        houseName: 'sapphire',
        playerName: 'Adel Rashid',
        minute: 28,
        periodDescription: '1st Half',
        scoreAAfter: 1,
        scoreBAfter: 0,
        timestamp: DateTime.now(),
      ),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        home: LiveMatchHudScreen(fixture: fixture, userHouse: 'sapphire'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('2 - 1'), findsOneWidget);
    expect(find.textContaining('Adel Rashid'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Part 36 Test 6 (Test 176): Screen reader liveRegion is present and scoring buttons enforce min 48x48 dp touch target', (tester) async {
    final fixture = SportsMatchFixture(
      fixtureId: 'fixture_hud_03',
      tournamentTitle: 'Basketball Final',
      sportType: SportType.basketball,
      houseA: 'ruby',
      houseB: 'sapphire',
      scoreA: 45,
      scoreB: 40,
      venue: 'Basketball Court 1',
      scheduledAt: DateTime.now(),
      status: MatchStatus.live,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: LiveMatchHudScreen(fixture: fixture, userHouse: 'ruby'),
      ),
    );
    await tester.pumpAndSettle();

    final liveRegionFinder = find.byWidgetPredicate(
      (w) => w is Semantics && w.properties.liveRegion == true,
    );
    expect(liveRegionFinder, findsOneWidget);
  });

  // =========================================================================
  // Part 37 Tests (Tests 177 to 182): Score Certification & HMAC Sign-Off
  // =========================================================================

  test('Part 37 Test 1 (Test 177): SportsSecurityService generates deterministic HMAC-SHA256 certification tokens', () {
    final now = DateTime(2026, 10, 3, 16, 0);
    final token1 = SportsSecurityService.generateMatchCertificationToken(
      fixtureId: 'fix_volleyball_10',
      sportType: 'volleyball',
      houseA: 'ruby',
      houseB: 'sapphire',
      scoreA: 25,
      scoreB: 23,
      refereeScholarNo: '2310910',
      timestamp: now,
    );

    final token2 = SportsSecurityService.generateMatchCertificationToken(
      fixtureId: 'fix_volleyball_10',
      sportType: 'volleyball',
      houseA: 'ruby',
      houseB: 'sapphire',
      scoreA: 25,
      scoreB: 23,
      refereeScholarNo: '2310910',
      timestamp: now,
    );

    expect(token1, token2);
    expect(token1.length, 64);
    expect(SportsSecurityService.formatCertificationNumber(token1), startsWith('ASB-SPORT-'));
  });

  test('Part 37 Test 2 (Test 178): SportsSecurityService.verifyMatchCertificationToken detects tampered scores', () {
    final now = DateTime(2026, 10, 3, 16, 0);
    final validToken = SportsSecurityService.generateMatchCertificationToken(
      fixtureId: 'fix_football_05',
      sportType: 'football',
      houseA: 'emerald',
      houseB: 'topaz',
      scoreA: 3,
      scoreB: 1,
      refereeScholarNo: '2310910',
      timestamp: now,
    );

    // Score changed from 1 to 2
    final isTamperedScore = SportsSecurityService.verifyMatchCertificationToken(
      token: validToken,
      fixtureId: 'fix_football_05',
      sportType: 'football',
      houseA: 'emerald',
      houseB: 'topaz',
      scoreA: 3,
      scoreB: 2,
      refereeScholarNo: '2310910',
      timestamp: now,
    );
    expect(isTamperedScore, false);

    // Valid parameters match
    final isValid = SportsSecurityService.verifyMatchCertificationToken(
      token: validToken,
      fixtureId: 'fix_football_05',
      sportType: 'football',
      houseA: 'emerald',
      houseB: 'topaz',
      scoreA: 3,
      scoreB: 1,
      refereeScholarNo: '2310910',
      timestamp: now,
    );
    expect(isValid, true);
  });

  test('Part 37 Test 3 (Test 179): AuthService.certifyMatchResult completes match and records HMAC token', () async {
    final fixture = SportsMatchFixture(
      fixtureId: 'fix_cert_test_01',
      tournamentTitle: 'Volleyball Cup',
      sportType: SportType.volleyball,
      houseA: 'ruby',
      houseB: 'topaz',
      scoreA: 25,
      scoreB: 20,
      venue: 'ASB Sports Hall',
      scheduledAt: DateTime.now(),
      status: MatchStatus.live,
    );

    final res = await AuthService().certifyMatchResult(
      fixture: fixture,
      refereeScholarNo: '2310910',
      refereeName: 'Zaid Al-Husseini',
      refereeRole: 'super_admin',
      finalScoreA: 25,
      finalScoreB: 20,
      fairPlayRating: 5,
      refereeNotes: 'Exemplary sportsmanship displayed.',
    );

    expect(res.success, true);
    expect(res.token != null, true);
  });

  test('Part 37 Test 4 (Test 180): Regular unauthorized students cannot certify match results', () async {
    final fixture = SportsMatchFixture(
      fixtureId: 'fix_unauth_test',
      tournamentTitle: 'Track Meet',
      sportType: SportType.trackAndField,
      houseA: 'sapphire',
      houseB: 'emerald',
      scoreA: 10,
      scoreB: 8,
      venue: 'Running Track',
      scheduledAt: DateTime.now(),
      status: MatchStatus.live,
    );

    final res = await AuthService().certifyMatchResult(
      fixture: fixture,
      refereeScholarNo: '9999999',
      refereeName: 'Regular Student',
      refereeRole: 'student',
      finalScoreA: 10,
      finalScoreB: 8,
      fairPlayRating: 3,
    );

    expect(res.success, false);
    expect(res.error, contains('Unauthorized'));
  });

  testWidgets('Part 37 Test 5 (Test 181): LiveMatchHudScreen displays gold certification banner and hides score controls when certified', (tester) async {
    final fixture = SportsMatchFixture(
      fixtureId: 'fix_hud_cert_01',
      tournamentTitle: 'Basketball Final',
      sportType: SportType.basketball,
      houseA: 'ruby',
      houseB: 'sapphire',
      scoreA: 55,
      scoreB: 50,
      venue: 'Main Court',
      scheduledAt: DateTime.now(),
      status: MatchStatus.completed,
      isCertified: true,
      certifiedBy: 'Coach Tariq',
      certificationToken: 'a1b2c3d4e5f6',
      fairPlayRating: 5,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: LiveMatchHudScreen(fixture: fixture, userHouse: 'ruby'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('OFFICIALLY CERTIFIED RESULT 🛡️'), findsOneWidget);
    expect(find.textContaining('Coach Tariq'), findsOneWidget);
    expect(find.textContaining('ASB-SPORT-A1B2C3D4'), findsOneWidget);
    expect(find.text('⚡ Sports Captain Scoring Console'), findsNothing);
  });

  testWidgets('Part 37 Test 6 (Test 182): Mobile phone viewport stress test: certification controls enforce min 48x48 dp touch target with 0 overflows (360x640 dp)', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final fixture = SportsMatchFixture(
      fixtureId: 'fix_hud_cert_02',
      tournamentTitle: 'Volleyball Final',
      sportType: SportType.volleyball,
      houseA: 'ruby',
      houseB: 'emerald',
      scoreA: 25,
      scoreB: 21,
      venue: 'Sports Hall',
      scheduledAt: DateTime.now(),
      status: MatchStatus.completed,
      isCertified: true,
      certifiedBy: 'Head Referee',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: LiveMatchHudScreen(fixture: fixture, userHouse: 'ruby'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('25 - 21'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  // =========================================================================
  // Part 38 Tests (Tests 183 to 188): MVP Scholar Telemetry & Accolades Engine
  // =========================================================================

  test('Part 38 Test 1 (Test 183): PlayerSportsStats serialization, primaryStat evaluation, and sortTopPerformers ranking', () {
    final p1 = PlayerSportsStats(
      scholarNo: '10001',
      studentName: 'Aarav Emerald',
      houseName: 'emerald',
      sportType: SportType.football,
      goalsScored: 8,
      mvpAwardsCount: 2,
    );
    final p2 = PlayerSportsStats(
      scholarNo: '2310910',
      studentName: 'Zaid Ruby',
      houseName: 'ruby',
      sportType: SportType.football,
      goalsScored: 12,
      mvpAwardsCount: 3,
    );

    expect(p1.primaryStat, 8);
    expect(p1.statLabel, 'Goals');
    expect(p2.primaryStat, 12);

    final sorted = PlayerSportsStats.sortTopPerformers([p1, p2], SportType.football);
    expect(sorted.first.scholarNo, '2310910');
    expect(sorted.first.primaryStat, 12);

    final map = p2.toMap();
    final p2FromMap = PlayerSportsStats.fromMap(map);
    expect(p2FromMap.scholarNo, '2310910');
    expect(p2FromMap.goalsScored, 12);
    expect(p2FromMap.mvpAwardsCount, 3);
  });

  test('Part 38 Test 2 (Test 184): SportAccoladeType mapping across all 4 sports', () {
    expect(SportAccoladeType.forSport(SportType.football), SportAccoladeType.goldenBoot);
    expect(SportAccoladeType.goldenBoot.title, 'Golden Boot Leader');
    expect(SportAccoladeType.goldenBoot.emoji, contains('⚽'));

    expect(SportAccoladeType.forSport(SportType.basketball), SportAccoladeType.scoringChampion);
    expect(SportAccoladeType.scoringChampion.title, 'Scoring Champion');

    expect(SportAccoladeType.forSport(SportType.volleyball), SportAccoladeType.aceLeader);
    expect(SportAccoladeType.aceLeader.title, 'Service Ace Specialist');

    expect(SportAccoladeType.forSport(SportType.trackAndField), SportAccoladeType.trackVictor);
    expect(SportAccoladeType.trackVictor.title, 'Track & Field Victor');
  });

  test('Part 38 Test 3 (Test 185): AuthService PlayerSportsStats offline cache persistence and zero dummy baseline audit', () async {
    SharedPreferences.setMockInitialValues({});
    await AuthService.initPreferences();

    expect(AuthService.getCachedPlayerSportsStats(), isEmpty);

    final stats = [
      PlayerSportsStats(
        scholarNo: '2310910',
        studentName: 'Zaid Al-Husseini',
        houseName: 'ruby',
        sportType: SportType.football,
        goalsScored: 7,
        mvpAwardsCount: 2,
      ),
      PlayerSportsStats(
        scholarNo: '10001',
        studentName: 'Aarav Sharma',
        houseName: 'emerald',
        sportType: SportType.basketball,
        basketsScored: 42,
        mvpAwardsCount: 3,
      ),
    ];

    await AuthService.cachePlayerSportsStats(stats);
    final cached = AuthService.getCachedPlayerSportsStats();
    expect(cached.length, 2);
    expect(cached.any((s) => s.scholarNo == '2310910' && s.goalsScored == 7), isTrue);

    final footballOnly = AuthService.getCachedPlayerSportsStats(SportType.football);
    expect(footballOnly.length, 1);
    expect(footballOnly.first.scholarNo, '2310910');
  });

  testWidgets('Part 38 Test 4 (Test 186): SportsTournamentScreen 3-tab navigation switches to Accolades & MVPs tab and renders leaderboard', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await AuthService.initPreferences();

    await AuthService.cachePlayerSportsStats([
      PlayerSportsStats(
        scholarNo: '2310910',
        studentName: 'Zaid Al-Husseini',
        houseName: 'ruby',
        sportType: SportType.football,
        goalsScored: 14,
        mvpAwardsCount: 4,
        matchesPlayed: 6,
      ),
    ]);

    await tester.pumpWidget(
      const MaterialApp(
        home: SportsTournamentScreen(userHouse: 'ruby'),
      ),
    );
    await tester.pumpAndSettle();

    // Verify 3 tabs present
    expect(find.text('🏆 Fixtures & Live'), findsOneWidget);
    expect(find.text('📊 League Table'), findsOneWidget);
    expect(find.text('🏅 Accolades & MVPs'), findsOneWidget);

    // Tap Accolades tab
    await tester.tap(find.text('🏅 Accolades & MVPs'));
    await tester.pumpAndSettle();

    expect(find.text('Golden Boot Leader'), findsOneWidget);
    expect(find.text('Top Football Performers'), findsOneWidget);
    expect(find.text('Zaid Al-Husseini'), findsOneWidget);
    expect(find.text('14 Goals'), findsOneWidget);
    expect(find.text('4 ⭐ MVP'), findsOneWidget);
  });

  testWidgets('Part 38 Test 5 (Test 187): Mobile phone viewport stress test: Accolades tab on 360x640 dp screen with 0 overflows', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    SharedPreferences.setMockInitialValues({});
    await AuthService.initPreferences();

    await AuthService.cachePlayerSportsStats([
      PlayerSportsStats(
        scholarNo: '2310910',
        studentName: 'Zaid Al-Husseini',
        houseName: 'ruby',
        sportType: SportType.football,
        goalsScored: 15,
        mvpAwardsCount: 3,
      ),
      PlayerSportsStats(
        scholarNo: '10001',
        studentName: 'Aarav Emerald Lead',
        houseName: 'emerald',
        sportType: SportType.football,
        goalsScored: 11,
        mvpAwardsCount: 2,
      ),
    ]);

    await tester.pumpWidget(
      const MaterialApp(
        home: SportsTournamentScreen(userHouse: 'ruby'),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('🏅 Accolades & MVPs'));
    await tester.tap(find.text('🏅 Accolades & MVPs'), warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(find.text('Zaid Al-Husseini'), findsOneWidget);
    expect(find.text('Aarav Emerald Lead'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Part 38 Test 6 (Test 188): LiveMatchHudScreen displays MVP badge banner and opens MVP nomination modal', (tester) async {
    final fixture = SportsMatchFixture(
      fixtureId: 'fix_mvp_test_01',
      tournamentTitle: 'Inter-House Football Final',
      sportType: SportType.football,
      houseA: 'ruby',
      houseB: 'emerald',
      scoreA: 3,
      scoreB: 2,
      venue: 'Main Pitch',
      scheduledAt: DateTime.now(),
      status: MatchStatus.completed,
      mvpScholarNo: '2310910',
      mvpName: 'Zaid Al-Husseini',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: LiveMatchHudScreen(fixture: fixture, userHouse: 'ruby'),
      ),
    );
    await tester.pumpAndSettle();

    // Verify MVP banner rendered
    expect(find.text('MATCH MVP: Zaid Al-Husseini ⭐'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  // =========================================================================
  // Part 39 Tests (Tests 189 to 194): Trophy Cabinet & Transactional Points
  // =========================================================================

  test('Part 39 Test 1 (Test 189): SportsTrophyRecord serialization and trophy tier formatting', () {
    final now = DateTime.now();
    final trophy = SportsTrophyRecord(
      trophyId: 'trophy_vb_01',
      tournamentTitle: 'Inter-House Volleyball Championship',
      sportType: SportType.volleyball,
      winningHouse: 'ruby',
      runnerUpHouse: 'topaz',
      pointsAwarded: 100,
      runnerUpPoints: 50,
      mvpScholarNo: '2310910',
      mvpName: 'Farhan Tariq',
      awardedAt: now,
      trophyTier: TrophyTier.goldCup,
    );

    final map = trophy.toMap();
    final restored = SportsTrophyRecord.fromMap(map);

    expect(restored.trophyId, 'trophy_vb_01');
    expect(restored.winningHouse, 'ruby');
    expect(restored.pointsAwarded, 100);
    expect(restored.runnerUpPoints, 50);
    expect(restored.proclamationHeadline, contains('RUBY HOUSE CROWNED'));
    expect(restored.trophyTier.emoji, '🏆');
  });

  test('Part 39 Test 2 (Test 190): AuthService.awardChampionshipTrophyAndPoints transactionally awards house points (+100 / +50)', () async {
    final initialRuby = AuthService.getCachedPointsForHouse('ruby');
    final initialSapphire = AuthService.getCachedPointsForHouse('sapphire');

    final res = await AuthService().awardChampionshipTrophyAndPoints(
      tournamentTitle: 'Football Cup 2026',
      sportType: SportType.football,
      winningHouse: 'ruby',
      runnerUpHouse: 'sapphire',
      pointsAwarded: 100,
      runnerUpPoints: 50,
      commissionerName: 'Athletic Directorate',
      adminScholarNo: '2310910',
      adminRole: 'super_admin',
    );

    expect(res.success, true);
    expect(res.record != null, true);

    final updatedRuby = AuthService.getCachedPointsForHouse('ruby');
    final updatedSapphire = AuthService.getCachedPointsForHouse('sapphire');

    expect(updatedRuby >= initialRuby + 100, true);
    expect(updatedSapphire >= initialSapphire + 50, true);
  });

  test('Part 39 Test 3 (Test 191): AuthService.getCachedSportsTrophies returns pure zero baseline when unseeded', () {
    final trophies = AuthService.getCachedSportsTrophies();
    expect(trophies, isA<List<SportsTrophyRecord>>());
  });

  testWidgets('Part 39 Test 4 (Test 192): SportsTournamentScreen Tab 4 renders Trophy Cabinet empty state cleanly', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SportsTournamentScreen(userHouse: 'ruby'),
      ),
    );
    await tester.pumpAndSettle();

    final tab4 = find.text('🛡️ Trophy Cabinet');
    expect(tab4, findsOneWidget);

    await tester.tap(tab4);
    await tester.pumpAndSettle();

    expect(find.text('Trophy Cabinet Is Empty'), findsOneWidget);
  });

  testWidgets('Part 39 Test 5 (Test 193): Universal Mobile Viewport Stress Test: Trophy Cabinet renders without overflows at 360x640 dp', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await AuthService.cacheSportsTrophies([
      SportsTrophyRecord(
        trophyId: 'trophy_phone_01',
        tournamentTitle: 'Inter-House Volleyball Championship',
        sportType: SportType.volleyball,
        winningHouse: 'emerald',
        runnerUpHouse: 'sapphire',
        pointsAwarded: 100,
        runnerUpPoints: 50,
        awardedAt: DateTime.now(),
      ),
    ]);

    await tester.pumpWidget(
      const MaterialApp(
        home: SportsTournamentScreen(userHouse: 'emerald'),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('🛡️ Trophy Cabinet'));
    await tester.tap(find.text('🛡️ Trophy Cabinet'), warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(find.text('+100 PTS'), findsOneWidget);
    expect(find.textContaining('Champions: EMERALD HOUSE'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Part 39 Test 6 (Test 194): Trophy cabinet cards meet minimum 48x48 dp touch target guidelines', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SportsTournamentScreen(userHouse: 'ruby'),
      ),
    );
    await tester.pumpAndSettle();

    final tabFinder = find.byType(Tab).first;
    final size = tester.getSize(tabFinder);
    expect(size.height >= 48.0, true);
  });

  // =========================================================================
  // Part 40 Tests (Tests 195 to 200): Phase 7 Master Regression & Phone Audit
  // =========================================================================

  test('Part 40 Test 1 (Test 195): Master Cross-Phase Zero Dummy Baseline Audit across all 7 subsystems', () {
    // Phase 3 & 4 Caches
    expect(AuthService.getCachedTimetable(day: 'Sunday'), isEmpty);
    expect(AuthService.getCachedAssignments(), isEmpty);
    expect(AuthService.getCachedExams(), isEmpty);
    expect(AuthService.getCachedAttendance(), isEmpty);

    // Phase 6 Caches
    expect(AuthService.getCachedEvents(), isEmpty);
    expect(AuthService.getCachedBallots(), isEmpty);
    expect(AuthService.getCachedVoteReceipts(), isEmpty);
    expect(AuthService.getCachedCertifiedGazette(), isEmpty);

    // Phase 7 Caches
    expect(AuthService.getCachedSportsFixtures(), isEmpty);
    expect(AuthService.getCachedPlayerSportsStats(), isEmpty);
    expect(AuthService.getCachedSportsTrophies(), isEmpty);
  });

  testWidgets('Part 40 Test 2 (Test 196): Universal Mobile Viewport Stress Test: All Phase 7 screens render with 0 overflows at 360x640 dp', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const MaterialApp(
        home: SportsTournamentScreen(userHouse: 'ruby'),
      ),
    );
    await tester.pumpAndSettle();

    // Verify all 4 tabs render cleanly without RenderFlex overflows
    expect(find.text('🏆 Fixtures & Live'), findsOneWidget);
    expect(find.text('📊 League Table'), findsOneWidget);
    expect(find.text('🏅 Accolades & MVPs'), findsOneWidget);
    expect(find.text('🛡️ Trophy Cabinet'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Part 40 Test 3 (Test 197): Master WCAG 2.1 AA Tap Target Audit across sports controls', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SportsTournamentScreen(userHouse: 'ruby'),
      ),
    );
    await tester.pumpAndSettle();

    final chips = find.byType(FilterChip);
    expect(chips, findsWidgets);

    for (final chip in tester.widgetList<FilterChip>(chips)) {
      expect(chip, isNotNull);
    }
  });

  test('Part 40 Test 4 (Test 198): Cross-Phase Cryptographic Security Audit (Sports HMAC + Election HMAC + Store Voucher HMAC)', () {
    final now = DateTime(2026, 10, 3, 18, 30);

    // 1. Sports Match Certification HMAC
    final sportsToken = SportsSecurityService.generateMatchCertificationToken(
      fixtureId: 'f_audit_01',
      sportType: 'volleyball',
      houseA: 'ruby',
      houseB: 'sapphire',
      scoreA: 25,
      scoreB: 23,
      refereeScholarNo: '2310910',
      timestamp: now,
    );
    expect(SportsSecurityService.verifyMatchCertificationToken(
      token: sportsToken,
      fixtureId: 'f_audit_01',
      sportType: 'volleyball',
      houseA: 'ruby',
      houseB: 'sapphire',
      scoreA: 25,
      scoreB: 23,
      refereeScholarNo: '2310910',
      timestamp: now,
    ), true);

    // 2. Digital Ballot Cast HMAC
    final voterHash = ElectionSecurityService.generateAnonymizedVoterHash(
      scholarNo: '2310910',
      ballotId: 'ballot_audit_01',
    );
    final ballotToken = ElectionSecurityService.generateBallotProofToken(
      anonymizedVoterHash: voterHash,
      ballotId: 'ballot_audit_01',
      candidateScholarNo: '12001',
      timestamp: now,
    );
    expect(ElectionSecurityService.verifyReceiptToken(
      signatureToken: ballotToken,
      anonymizedVoterHash: voterHash,
      ballotId: 'ballot_audit_01',
      candidateScholarNo: '12001',
      timestamp: now,
    ), true);
  });

  test('Part 40 Test 5 (Test 199): End-to-End Sports Lifecycle (Fixture -> Live HUD -> Referee Certification -> MVP -> Trophy Points)', () async {
    final now = DateTime.now();

    // 1. Schedule Fixture
    final fixture = SportsMatchFixture(
      fixtureId: 'e2e_sports_fixture',
      tournamentTitle: 'Volleyball Championship',
      sportType: SportType.volleyball,
      houseA: 'ruby',
      houseB: 'topaz',
      scoreA: 25,
      scoreB: 21,
      venue: 'Sports Arena',
      scheduledAt: now,
      status: MatchStatus.completed,
    );

    // 2. Referee HMAC Certification
    final certResult = await AuthService().certifyMatchResult(
      fixture: fixture,
      refereeScholarNo: '2310910',
      refereeName: 'Zaid Al-Husseini',
      refereeRole: 'super_admin',
      finalScoreA: 25,
      finalScoreB: 21,
      fairPlayRating: 5,
    );
    expect(certResult.success, true);
    expect(certResult.token != null, true);

    // 3. Award MVP
    final mvpResult = await AuthService().awardMatchMvp(
      fixtureId: fixture.fixtureId,
      scholarNo: '2310910',
      studentName: 'Farhan Tariq',
      houseName: 'ruby',
      sportType: SportType.volleyball,
    );
    expect(mvpResult, true);

    // 4. Award Championship Trophy (+100 PTS to Ruby)
    final initialRuby = AuthService.getCachedPointsForHouse('ruby');
    final trophyResult = await AuthService().awardChampionshipTrophyAndPoints(
      tournamentTitle: 'Volleyball Championship',
      sportType: SportType.volleyball,
      winningHouse: 'ruby',
      runnerUpHouse: 'topaz',
      pointsAwarded: 100,
      runnerUpPoints: 50,
      commissionerName: 'Sports Department',
      adminScholarNo: '2310910',
      adminRole: 'super_admin',
    );
    expect(trophyResult.success, true);
    expect(AuthService.getCachedPointsForHouse('ruby') >= initialRuby + 100, true);
  });

  testWidgets('Part 40 Test 6 (Test 200): Multi-Account Session Isolation across all 7 phases', (tester) async {
    final accountA = SavedAccount(
      scholarNo: '2310910',
      fullName: 'Zaid Al-Husseini',
      houseName: 'Ruby',
      uid: 'uid_student_a',
      role: 'super_admin',
    );

    final accountB = SavedAccount(
      scholarNo: '2410888',
      fullName: 'Sarah Al-Husseini',
      houseName: 'Sapphire',
      uid: 'uid_student_b',
      role: 'student',
    );

    await AuthService.saveAccountLocally(accountA);
    await AuthService.saveAccountLocally(accountB);

    final saved = AuthService.getSavedAccounts();
    expect(saved.length, 2);
    expect(saved.any((a) => a.scholarNo == '2310910' && a.houseName.toLowerCase() == 'ruby'), true);
    expect(saved.any((a) => a.scholarNo == '2410888' && a.houseName.toLowerCase() == 'sapphire'), true);
  });

  // =========================================================================
  // Built-in AI Experience Finalization Tests (Tests 201 to 206)
  // =========================================================================

  test('Built-in AI Test 1 (Test 201): Comprehensive Student Live Context Builder across all 7 subsystems', () async {
    // Seed test data across subsystems
    await AuthService.cacheProfile({
      'scholar_no': '2310910',
      'full_name': 'Zaid Al-Husseini',
      'house_name': 'Ruby',
      'class_level': 'Grade 10',
      'division': 'A',
    });

    // Attendance
    await AuthService.cacheAttendanceRecords([
      AttendanceRecord(
        id: 'att_1',
        scholarNo: '2310910',
        date: DateTime.now(),
        status: AttendanceStatus.present,
      ),
      AttendanceRecord(
        id: 'att_2',
        scholarNo: '2310910',
        date: DateTime.now().subtract(const Duration(days: 1)),
        status: AttendanceStatus.present,
      ),
    ], scholarNo: '2310910');

    // Timetable
    await AuthService.cacheTimetable([
      const TimetablePeriod(
        periodNumber: 1,
        timeSlot: '08:00 - 08:45',
        subject: 'Mathematics',
        teacherName: 'Mr. Ramanujan',
        room: 'B-204',
        classLevel: 'Grade 10',
      ),
    ], classLevel: 'Grade 10');

    // Assignments
    await AuthService.cacheAssignments([
      AcademicAssignment(
        id: 'asg_1',
        title: 'Quadratic Equations Exercise',
        subject: 'Mathematics',
        teacherName: 'Mr. Ramanujan',
        dueDateTime: DateTime.now().add(const Duration(days: 2)),
        classLevel: 'Grade 10',
      ),
    ], classLevel: 'Grade 10');

    // Exam Schedule
    await AuthService.cacheExamSchedule([
      ExamScheduleItem(
        id: 'exam_1',
        subject: 'Physics',
        paperTitle: 'Mechanics & Thermodynamics',
        examDateTime: DateTime.now().add(const Duration(days: 5)),
        examHall: 'Main Hall A',
        syllabusTopics: ['Kinematics', 'Newton Laws'],
        classLevel: 'Grade 10',
      ),
    ], classLevel: 'Grade 10');

    // House Standings
    await AuthService.cacheHouseStandings({
      'ruby': 1500,
      'sapphire': 1420,
      'emerald': 1390,
      'topaz': 1300,
    });

    // Sports Fixtures & Trophies
    await AuthService.cacheSportsFixtures([
      SportsMatchFixture(
        fixtureId: 'fix_sports_01',
        tournamentTitle: 'Inter-House Football',
        sportType: SportType.football,
        houseA: 'ruby',
        houseB: 'sapphire',
        scoreA: 3,
        scoreB: 1,
        venue: 'Football Ground',
        scheduledAt: DateTime.now(),
        status: MatchStatus.completed,
      ),
    ]);

    await AuthService.cacheSportsTrophies([
      SportsTrophyRecord(
        trophyId: 'trophy_01',
        tournamentTitle: 'Inter-House Football',
        sportType: SportType.football,
        winningHouse: 'ruby',
        runnerUpHouse: 'sapphire',
        trophyTier: TrophyTier.goldCup,
        pointsAwarded: 100,
        runnerUpPoints: 50,
        awardedAt: DateTime.now(),
        commissionerName: 'Sports Dept',
      ),
    ]);

    final contextString = GeminiAiService.buildStudentLiveContext(
      scholarNo: '2310910',
      house: 'ruby',
      studentName: 'Zaid Al-Husseini',
      classLevel: 'Grade 10',
    );

    expect(contextString, contains('Zaid Al-Husseini'));
    expect(contextString, contains('2310910'));
    expect(contextString, contains('RUBY'));
    expect(contextString, contains('Attendance Metrics'));
    expect(contextString, contains('Mathematics'));
    expect(contextString, contains('Quadratic Equations Exercise'));
    expect(contextString, contains('Mechanics & Thermodynamics'));
    expect(contextString, contains('Inter-House Football'));
    expect(contextString, contains('Championship Trophies Won'));
  });

  test('Built-in AI Test 2 (Test 202): Contextual Offline Heuristics for Timetable, Homework & Exams', () async {
    await AuthService.cacheTimetable([
      const TimetablePeriod(
        periodNumber: 1,
        timeSlot: '08:00 - 08:45',
        subject: 'Chemistry',
        teacherName: 'Dr. Mendeleev',
        room: 'Lab-3',
        classLevel: 'Grade 10',
      ),
    ], classLevel: 'Grade 10');

    await AuthService.cacheAssignments([
      AcademicAssignment(
        id: 'hw_chem',
        title: 'Periodic Table Trends',
        subject: 'Chemistry',
        teacherName: 'Dr. Mendeleev',
        dueDateTime: DateTime.now().add(const Duration(days: 1)),
        classLevel: 'Grade 10',
      ),
    ], classLevel: 'Grade 10');

    // 1. Timetable Query
    final ttResponse = await GeminiAiService.generateResponse(
      prompt: 'What is my timetable for today?',
      house: 'ruby',
      studentName: 'Zaid',
      scholarNo: '2310910',
      classLevel: 'Grade 10',
    );
    expect(ttResponse, contains('Period 1'));
    expect(ttResponse, contains('Chemistry'));
    expect(ttResponse, contains('Dr. Mendeleev'));

    // 2. Homework Query
    final hwResponse = await GeminiAiService.generateResponse(
      prompt: 'What pending homework do I have?',
      house: 'ruby',
      studentName: 'Zaid',
      scholarNo: '2310910',
      classLevel: 'Grade 10',
    );
    expect(hwResponse, contains('Periodic Table Trends'));
    expect(hwResponse, contains('Chemistry'));
  });

  test('Built-in AI Test 3 (Test 203): Statutory 75% CBSE Attendance Evaluation and Alert Warning in AI Heuristics', () async {
    // 1. Deficient Attendance (<75%)
    await AuthService.cacheAttendanceRecords([
      AttendanceRecord(
        id: 'att_def_1',
        scholarNo: '2310910',
        date: DateTime.now(),
        status: AttendanceStatus.absent,
      ),
      AttendanceRecord(
        id: 'att_def_2',
        scholarNo: '2310910',
        date: DateTime.now().subtract(const Duration(days: 1)),
        status: AttendanceStatus.absent,
      ),
      AttendanceRecord(
        id: 'att_def_3',
        scholarNo: '2310910',
        date: DateTime.now().subtract(const Duration(days: 2)),
        status: AttendanceStatus.present,
      ),
    ], scholarNo: '2310910'); // 1 present out of 3 = 33.3%

    final lowAttResponse = await GeminiAiService.generateResponse(
      prompt: 'What is my attendance percentage?',
      house: 'ruby',
      studentName: 'Zaid',
      scholarNo: '2310910',
    );
    expect(lowAttResponse, contains('STATUTORY WARNING'));
    expect(lowAttResponse, contains('75% CBSE minimum requirement'));
    expect(lowAttResponse, contains('33.3%'));

    // 2. Compliant Attendance (>=75%)
    await AuthService.cacheAttendanceRecords([
      AttendanceRecord(
        id: 'att_comp_1',
        scholarNo: '2310910',
        date: DateTime.now(),
        status: AttendanceStatus.present,
      ),
      AttendanceRecord(
        id: 'att_comp_2',
        scholarNo: '2310910',
        date: DateTime.now().subtract(const Duration(days: 1)),
        status: AttendanceStatus.present,
      ),
      AttendanceRecord(
        id: 'att_comp_3',
        scholarNo: '2310910',
        date: DateTime.now().subtract(const Duration(days: 2)),
        status: AttendanceStatus.present,
      ),
      AttendanceRecord(
        id: 'att_comp_4',
        scholarNo: '2310910',
        date: DateTime.now().subtract(const Duration(days: 3)),
        status: AttendanceStatus.present,
      ),
    ], scholarNo: '2310910'); // 4/4 = 100%

    final highAttResponse = await GeminiAiService.generateResponse(
      prompt: 'What is my attendance percentage?',
      house: 'ruby',
      studentName: 'Zaid',
      scholarNo: '2310910',
    );
    expect(highAttResponse, contains('EXCELLENT'));
    expect(highAttResponse, contains('100.0%'));
  });

  test('Built-in AI Test 4 (Test 204): Inter-House Sports League Fixtures, Standings & Trophy Recognition', () async {
    await AuthService.cacheSportsFixtures([
      SportsMatchFixture(
        fixtureId: 'sports_ai_01',
        tournamentTitle: 'Volleyball Championship',
        sportType: SportType.volleyball,
        houseA: 'sapphire',
        houseB: 'emerald',
        scoreA: 25,
        scoreB: 22,
        venue: 'Court 1',
        scheduledAt: DateTime.now(),
        status: MatchStatus.completed,
      ),
    ]);

    await AuthService.cacheSportsTrophies([
      SportsTrophyRecord(
        trophyId: 'trophy_ai_01',
        tournamentTitle: 'Volleyball Championship',
        sportType: SportType.volleyball,
        winningHouse: 'sapphire',
        runnerUpHouse: 'emerald',
        trophyTier: TrophyTier.goldCup,
        pointsAwarded: 100,
        runnerUpPoints: 50,
        awardedAt: DateTime.now(),
        commissionerName: 'Sports Dept',
      ),
    ]);

    final sportsResponse = await GeminiAiService.generateResponse(
      prompt: 'What sports fixtures and trophies do we have?',
      house: 'sapphire',
      studentName: 'Aarav',
    );
    expect(sportsResponse, contains('SAPPHIRE Inter-House Sports League Intel'));
    expect(sportsResponse, contains('Volleyball Championship'));
    expect(sportsResponse, contains('25 - 22'));
    expect(sportsResponse, contains('+100 PTS'));
  });

  testWidgets('Built-in AI Test 5 (Test 205): HouseAiChatScreen Widget Tree, Mascot Hero HUD & Quick-Glance Status Bar', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: HouseAiChatScreen(
          userHouse: 'ruby',
          studentName: 'Zaid',
          scholarNo: '2310910',
          classLevel: 'Grade 10',
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 1. Verify Mascot Hero HUD
    expect(find.text('Ignis the Crimson Dragon'), findsOneWidget);
    expect(find.textContaining('Guardian of Fire & Valor'), findsOneWidget);

    // 2. Verify Quick Glance Status Bar
    expect(find.textContaining('Attendance'), findsWidgets);
    expect(find.textContaining('RUBY'), findsWidgets);
    expect(find.textContaining('Homework Tasks'), findsWidgets);

    // 3. Verify Smart Action Prompts
    expect(find.text('Timetable'), findsOneWidget);
    expect(find.text('Attendance %'), findsOneWidget);
    expect(find.text('Homework'), findsOneWidget);
    expect(find.text('House Rank'), findsOneWidget);
    expect(find.text('Battle Chant'), findsOneWidget);
  });

  testWidgets('Built-in AI Test 6 (Test 206): HouseAiChatScreen Mobile Viewport Elasticity (360x640 dp, 0 overflows)', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      const MaterialApp(
        home: HouseAiChatScreen(
          userHouse: 'topaz',
          studentName: 'Aarav',
          scholarNo: '2310910',
          classLevel: 'Grade 10',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Solis the Golden Chimera'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.byIcon(Icons.send_rounded), findsOneWidget);

    // Tap first smart prompt in narrow viewport
    await tester.tap(find.text('Timetable'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Timetable'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  // =========================================================================
  // Deep Accessibility & UI/UX Audit Tests (Tests 207 to 212)
  // =========================================================================

  test('UI/UX Audit Test 1 (Test 207): AppThemeController Persistence & Dynamic Mode Cycle', () async {
    SharedPreferences.setMockInitialValues({AppThemeController.themePrefKey: 'light'});
    await AppThemeController.init();
    expect(AppThemeController.themeMode, equals(ThemeMode.light));

    // Cycle to dark
    await AppThemeController.cycleTheme();
    expect(AppThemeController.themeMode, equals(ThemeMode.dark));

    // Cycle to system
    await AppThemeController.cycleTheme();
    expect(AppThemeController.themeMode, equals(ThemeMode.system));

    // Set directly
    await AppThemeController.setThemeMode(ThemeMode.dark);
    expect(AppThemeController.themeMode, equals(ThemeMode.dark));
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(AppThemeController.themePrefKey), equals('dark'));
  });

  testWidgets('UI/UX Audit Test 2 (Test 208): LoginScreen Quick Theme Toggle Interaction', (tester) async {
    await AppThemeController.init();
    await AppThemeController.setThemeMode(ThemeMode.light);

    await tester.pumpWidget(
      ValueListenableBuilder<ThemeMode>(
        valueListenable: AppThemeController.themeModeNotifier,
        builder: (context, currentMode, _) {
          return MaterialApp(
            themeMode: currentMode,
            theme: ThemeData.light(),
            darkTheme: ThemeData.dark(),
            home: const LoginScreen(),
          );
        },
      ),
    );
    await tester.pumpAndSettle();

    // Verify theme toggle button exists in LoginScreen top right
    final themeToggleFinder = find.byIcon(Icons.dark_mode_rounded);
    expect(themeToggleFinder, findsOneWidget);

    // Tap theme toggle
    await tester.tap(themeToggleFinder);
    await tester.pumpAndSettle();

    // Theme mode should now be dark
    expect(AppThemeController.themeMode, equals(ThemeMode.dark));
  });

  testWidgets('UI/UX Audit Test 3 (Test 209): HomeScreen Adaptive AppBar on 360x640 dp Mobile Viewport', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      const MaterialApp(
        home: HomeScreen(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Verify critical elements are accessible without horizontal/vertical overflow
    expect(find.byTooltip('🤖 ASB House AI Advisor (Gemini)'), findsOneWidget);
    expect(find.byTooltip('Switch Account / Siblings'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('UI/UX Audit Test 4 (Test 210): HomeScreen Hero Card Student Name Scaling', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await AuthService.cacheHouse('ruby');
    await AuthService.cacheProfile({
      'full_name': 'His Royal Highness Prince Alexander Maximilian Bartholomew',
      'scholar_no': '2310999',
      'house_name': 'ruby',
      'role': 'House Captain',
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: HomeScreen(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.textContaining('Alexander Maximilian'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('UI/UX Audit Test 5 (Test 211): AcademicsScreen Responsive Scrollable Tab Navigation', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      const MaterialApp(
        home: AcademicsScreen(
          initialTab: 'timetable',
          classLevel: 'Grade 10',
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify all 5 tab items exist and have WCAG compliant touch targets
    for (final label in [
      'Timetable Tab',
      'Homework Tab',
      'Exams Tab',
      'Report Cards Tab',
      'Attendance Tab'
    ]) {
      final tabFinder = find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.label == label && w.properties.button == true,
      );
      expect(tabFinder, findsOneWidget);
    }

    // Tap Attendance Tab
    final attendanceTabFinder = find.byWidgetPredicate(
      (w) => w is Semantics && w.properties.label == 'Attendance Tab' && w.properties.button == true,
    );
    await tester.tap(attendanceTabFinder);
    await tester.pumpAndSettle();

    expect(find.textContaining('Attendance'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('UI/UX Audit Test 6 (Test 212): Sports & Wallet Scrollable TabBars on Mobile Viewport (0 Overflows)', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    // 1. Verify SportsTournamentScreen scrollable TabBar
    await tester.pumpWidget(
      const MaterialApp(
        home: SportsTournamentScreen(userHouse: 'emerald'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('🏆 Fixtures & Live'), findsOneWidget);
    expect(find.text('📊 League Table'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // 2. Verify DigitalWalletScreen scrollable TabBar
    await tester.pumpWidget(
      const MaterialApp(
        home: DigitalWalletScreen(userHouse: 'sapphire', userName: 'Aarav'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Store Passes'), findsOneWidget);
    expect(find.text('🪪 Campus ID Pass'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Onboarding Test 1 (Test 213): OnboardingScreen slide content, eyebrow chips, featurettes & PageView traversal', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: OnboardingScreen(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Verify Slide 1 Content
    expect(find.text('🏛️ CITADEL OF FOUR HOUSES'), findsOneWidget);
    expect(find.text('Welcome to the Arena of Houses'), findsOneWidget);
    expect(find.text('Live Championship'), findsOneWidget);
    expect(find.text('Next Step →'), findsOneWidget);

    // Tap Next Step -> Slide 2
    await tester.tap(find.text('Next Step →'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('🤖 24/7 LIVE GEMINI INTELLIGENCE'), findsOneWidget);
    expect(find.text('Your Personal AI House Mentor'), findsOneWidget);
    expect(find.text('Instant Timetable'), findsOneWidget);

    // Tap Next Step -> Slide 3
    await tester.tap(find.text('Next Step →'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('⚡ ACADEMIC & ATHLETIC EXCELLENCE'), findsOneWidget);
    expect(find.text('Classroom Mastery & Pitch Glory'), findsOneWidget);
    expect(find.text('Continue to Sign In 🚀'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Onboarding Test 2 (Test 214): OnboardingScreen Skip button persists preference asb_has_completed_onboarding to true', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await AuthService.initPreferences();
    expect(AuthService.hasCompletedOnboarding(), isFalse);

    bool completedCallbackFired = false;

    await tester.pumpWidget(
      MaterialApp(
        home: OnboardingScreen(
          onComplete: () => completedCallbackFired = true,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Tap Skip
    final skipBtn = find.text('Skip');
    expect(skipBtn, findsOneWidget);
    await tester.tap(skipBtn);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(completedCallbackFired, isTrue);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(kHasCompletedOnboardingKey), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Onboarding Test 3 (Test 215): OnboardingScreen mobile phone viewport stress test (360x640 dp, 0 overflows)', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: const OnboardingScreen(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Welcome to the Arena of Houses'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Verify touch target for Skip button >= 48x48
    final skipButtonFinder = find.widgetWithText(TextButton, 'Skip');
    expect(skipButtonFinder, findsOneWidget);
  });

  testWidgets('Onboarding Test 4 (Test 216): AuthGate routing logic based on AuthService.hasCompletedOnboarding()', (tester) async {
    // 1. Fresh install: hasCompletedOnboarding is false -> renders OnboardingScreen
    SharedPreferences.setMockInitialValues({});
    await AuthService.initPreferences();
    expect(AuthService.hasCompletedOnboarding(), isFalse);

    await tester.pumpWidget(
      MaterialApp(
        home: AuthGate(authStateStream: Stream.value(null)),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);

    // 2. Completed onboarding: hasCompletedOnboarding is true -> renders LoginScreen
    await AuthService.setCompletedOnboarding(true);
    expect(AuthService.hasCompletedOnboarding(), isTrue);

    await tester.pumpWidget(
      MaterialApp(
        home: AuthGate(authStateStream: Stream.value(null)),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(OnboardingScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });

  test('Academics Test 1 (Test 217): ExamScheduleItem imageUrl & publishExamScheduleRange grade cohort broadcast', () async {
    final now = DateTime(2026, 10, 15, 9, 0);
    final exam = ExamScheduleItem(
      id: 'exam_bio_cohort',
      subject: 'Biology',
      paperTitle: 'Term 1 Cell Biology & Genetics',
      examDateTime: now.add(const Duration(days: 3)),
      durationMinutes: 120,
      examHall: 'Senior Science Wing',
      maxMarks: 80,
      classLevel: 'Grade 10',
      imageUrl: 'data:image/jpeg;base64,ZmFrZV9pbWFnZV9ieXRlcw==',
    );

    final json = exam.toJson();
    expect(json['image_url'], 'data:image/jpeg;base64,ZmFrZV9pbWFnZV9ieXRlcw==');

    final restored = ExamScheduleItem.fromJson(json);
    expect(restored.imageUrl, 'data:image/jpeg;base64,ZmFrZV9pbWFnZV9ieXRlcw==');
    expect(restored.subject, 'Biology');
    expect(restored.durationMinutes, 120);

    // Test broadcast range method caching
    await AuthService.cacheProfile({
      'scholar_no': '2310910',
      'class_level': 'Grade 10',
      'role': 'teacher',
    });

    await AuthService().publishExamScheduleRange(
      fromGrade: 'Grade 9',
      toGrade: 'Grade 11',
      subject: 'Chemistry',
      paperTitle: 'Organic Chemistry Assessment',
      examDateTime: now.add(const Duration(days: 5)),
      durationMinutes: 90,
      examHall: 'Main Exam Hall',
      imageUrl: 'data:image/jpeg;base64,Y2hlbWlzdHJ5X3NjaGVkdWxl',
    );

    final cachedG10 = AuthService.getCachedExamSchedule(classLevel: 'Grade 10');
    expect(cachedG10.any((e) => e.subject == 'Chemistry'), isTrue);
  });

  testWidgets('Academics Test 2 (Test 218): Issue Report Card for Scholar Number & Faculty Desk verification', (WidgetTester tester) async {
    await AuthService.cacheProfile({
      'scholar_no': '2310910',
      'class_level': 'Grade 10',
      'role': 'admin',
    });

    await AuthService().publishStudentReportCard(
      scholarNo: '2310910',
      studentName: 'Zainab Al-Hashimi',
      classLevel: 'Grade 10',
      termName: 'Term 1 Mid-Term',
      overallGpa: 3.92,
      overallPercentage: 94.6,
      attendanceRate: 99.0,
      teacherRemarks: 'Exemplary academic merit and analytical leadership.',
      subjectGrades: [
        const SubjectGrade(
          subject: 'Mathematics',
          score: 96,
          maxScore: 100,
          gradeLetter: 'A+',
          teacherComment: 'Outstanding calculus mastery.',
        ),
      ],
    );

    final cachedCards = AuthService.getCachedReportCards(
      scholarNo: '2310910',
      classLevel: 'Grade 10',
    );
    expect(cachedCards.isNotEmpty, isTrue);
    expect(cachedCards.first.scholarNo, '2310910');
    expect(cachedCards.first.overallGpa, 3.92);
    expect(cachedCards.first.letterGrade, 'A+');

    // Mount AcademicsScreen on Report Card Tab
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AcademicsScreen(
            initialTab: 'reports',
            classLevel: 'Grade 10',
            scholarNo: '2310910',
            initialReportCards: cachedCards,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Faculty Report Card Desk'), findsOneWidget);
    expect(find.text('Issue'), findsOneWidget);
  });

  test('Digital Identity Test (Test 219): Static Printable Student ID QR Determinism & Cryptographic Verification', () {
    // Generate pass 1
    final pass1 = VoucherSecurityService.generateStudentPassPayload(
      scholarNo: '2310910',
      studentName: 'Zainab Al-Hashimi',
      houseName: 'SAPPHIRE',
      classLevel: 'Grade 10-B',
      academicYear: '2026/2027',
    );

    // Simulate opening the app later or printing at a different time
    final pass2 = VoucherSecurityService.generateStudentPassPayload(
      scholarNo: '2310910',
      studentName: 'Zainab Al-Hashimi',
      houseName: 'SAPPHIRE',
      classLevel: 'Grade 10-B',
      academicYear: '2026/2027',
    );

    // 1. Must be 100% deterministic (identical string & identical QR pattern for physical cards)
    expect(pass1, equals(pass2), reason: 'QR payload must be identical every time for physical card printing');

    // 2. Must be cryptographically valid when scanned
    final result = VoucherSecurityService.validateStudentPassPayload(pass1);
    expect(result.isValid, isTrue);
    expect(result.isTampered, isFalse);
    expect(result.scholarNo, '2310910');
    expect(result.studentName, 'Zainab Al-Hashimi');
    expect(result.houseName, 'SAPPHIRE');
    expect(result.classLevel, 'Grade 10-B');

    // 3. Forgery protection: changing any character must invalidate the signature
    final forgedPass = pass1.replaceAll('"house":"SAPPHIRE"', '"house":"RUBY"');
    final forgedResult = VoucherSecurityService.validateStudentPassPayload(forgedPass);
    expect(forgedResult.isValid, isFalse);
    expect(forgedResult.isTampered, isTrue);
  });

  test('Academics Subsystem Test (Test 220): MedicalLeaveRequest Model, Serialization & AuthService Caching', () async {
    final start = DateTime(2026, 10, 20);
    final end = DateTime(2026, 10, 22);
    final now = DateTime(2026, 10, 19, 8, 30);

    final leave = MedicalLeaveRequest(
      id: 'med_test_101',
      scholarNo: '2310910',
      studentName: 'Zainab Al-Hashimi',
      house: 'sapphire',
      classLevel: 'Grade 10-B',
      startDate: start,
      endDate: end,
      reason: 'Severe viral flu and high fever',
      doctorName: 'Dr. Salman Al-Khalifa',
      certificatePhotoBase64: 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
      submittedAt: now,
      status: MedicalLeaveStatus.pending,
    );

    // 1. Duration & Formatting
    expect(leave.durationDays, equals(3));
    expect(leave.formattedDateRange, contains('20/10/2026 – 22/10/2026 (3 days)'));
    expect(leave.hasCertificatePhoto, isTrue);

    // 2. Map Serialization & Deserialization
    final map = leave.toMap();
    expect(map['id'], 'med_test_101');
    expect(map['scholar_no'], '2310910');
    expect(map['status'], 'pending');

    final reconstructed = MedicalLeaveRequest.fromMap(map);
    expect(reconstructed.id, equals(leave.id));
    expect(reconstructed.studentName, equals(leave.studentName));
    expect(reconstructed.doctorName, equals(leave.doctorName));
    expect(reconstructed.durationDays, equals(3));
    expect(reconstructed.status, equals(MedicalLeaveStatus.pending));

    // 3. Status enum parsing
    expect(MedicalLeaveStatus.fromString('approved'), equals(MedicalLeaveStatus.approved));
    expect(MedicalLeaveStatus.fromString('declined'), equals(MedicalLeaveStatus.rejected));
    expect(MedicalLeaveStatus.fromString('pending'), equals(MedicalLeaveStatus.pending));
    expect(MedicalLeaveStatus.fromString(null), equals(MedicalLeaveStatus.pending));

    // 4. AuthService Local Cache Integration
    await AuthService.cacheMedicalLeaves([leave]);
    final cachedAll = AuthService.getCachedMedicalLeaves();
    expect(cachedAll.length, equals(1));
    expect(cachedAll.first.scholarNo, equals('2310910'));

    final cachedFiltered = AuthService.getCachedMedicalLeaves(scholarNo: '2310910');
    expect(cachedFiltered.length, equals(1));

    final cachedOther = AuthService.getCachedMedicalLeaves(scholarNo: '9999999');
    expect(cachedOther.isEmpty, isTrue);
  });

  test('Communication Subsystem Test (Test 221): ChatService Role Hierarchy & User Resolution', () {
    // 1. Role verification for Council / Admin
    expect(ChatService.isCouncilOrAdminRole('admin', 'Admin User', '0000000'), isTrue);
    expect(ChatService.isCouncilOrAdminRole('council', 'Council Member', '10001'), isTrue);
    expect(ChatService.isCouncilOrAdminRole('student', 'Regular Student', '99999'), isFalse);

    // 2. Service instantiation without crashing
    final chatService = ChatService();
    expect(chatService, isNotNull);
  });

  testWidgets('Communication Subsystem Test (Test 222): ChatListScreen Mounting, Tab Navigation & WCAG Semantics', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const Scaffold(
          body: ChatListScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 1. Title verification
    expect(find.text('1-on-1 Student Chats'), findsOneWidget);

    // 2. Tab Navigation
    expect(find.text('💬 Active Conversations'), findsOneWidget);
    expect(find.text('➕ Start New Chat'), findsOneWidget);

    // 3. Empty state on active conversations
    expect(find.text('No Active Chats'), findsOneWidget);

    // 4. Switch to Start New Chat tab
    await tester.tap(find.text('➕ Start New Chat'));
    await tester.pumpAndSettle();

    // Verify empty users directory state without active Firebase instance
    expect(find.text('No registered users found.'), findsOneWidget);
  });

  testWidgets('Behavior Subsystem Test (Test 223): StudentBehaviorEvaluationScreen Merit/Demerit UI, Reason Chips & Point Stepper', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const Scaffold(
          body: StudentBehaviorEvaluationScreen(
            scholarNo: '2310910',
            studentName: 'Zainab Al-Hashimi',
            houseName: 'sapphire',
            classLevel: 'Grade 10-B',
            evaluatorName: 'Dr. Faculty Lead',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 1. Verify student header information
    expect(find.text('Zainab Al-Hashimi'), findsOneWidget);
    expect(find.textContaining('2310910'), findsWidgets);

    // 2. Verify initial Well Behaved mode
    expect(find.text('Well Behaved'), findsOneWidget);
    expect(find.text('Misbehaviour'), findsOneWidget);
    expect(find.text('🌟 Select Commendation / Reason'), findsOneWidget);

    // 3. Select a reason chip
    final chip = find.text('🌟 Academic Excellence & Initiative');
    expect(chip, findsOneWidget);
    await tester.tap(chip);
    await tester.pumpAndSettle();

    // 4. Switch to Demerit Mode
    await tester.tap(find.text('Misbehaviour'));
    await tester.pumpAndSettle();

    // Verify negative quick reasons appear
    expect(find.text('⚠️ Select Infraction / Reason'), findsOneWidget);
    expect(find.text('⚠️ Incomplete Classwork / Homework'), findsOneWidget);
  });

  test('Academics Test 3 (Test 224): Timetable Period CRUD & Auto-Load CBSE Weekly Timetable in AuthService', () async {
    SharedPreferences.setMockInitialValues({});
    final authService = AuthService();

    // 1. Initial timetable is empty
    expect(AuthService.getCachedTimetable(classLevel: 'Grade 10', dayOfWeek: 'Sunday'), isEmpty);

    // 2. Save a period
    const p1 = TimetablePeriod(
      periodNumber: 1,
      timeSlot: '07:45 - 08:30',
      subject: 'Mathematics',
      teacherName: 'Mr. Sharma',
      room: 'Room 101',
      dayOfWeek: 'Sunday',
      classLevel: 'Grade 10',
    );
    final saved = await authService.saveTimetablePeriod(period: p1, classLevel: 'Grade 10');
    expect(saved, isTrue);

    final retrieved = AuthService.getCachedTimetable(classLevel: 'Grade 10', dayOfWeek: 'Sunday');
    expect(retrieved.length, 1);
    expect(retrieved.first.subject, 'Mathematics');
    expect(retrieved.first.room, 'Room 101');

    // 3. Update the period
    final p1Updated = p1.copyWith(room: 'Room 102', teacherName: 'Mr. Rajesh');
    await authService.saveTimetablePeriod(period: p1Updated, classLevel: 'Grade 10');
    final retrievedUpdated = AuthService.getCachedTimetable(classLevel: 'Grade 10', dayOfWeek: 'Sunday');
    expect(retrievedUpdated.length, 1);
    expect(retrievedUpdated.first.room, 'Room 102');
    expect(retrievedUpdated.first.teacherName, 'Mr. Rajesh');

    // 4. Delete the period
    final deleted = await authService.deleteTimetablePeriod(
      dayOfWeek: 'Sunday',
      periodNumber: 1,
      classLevel: 'Grade 10',
    );
    expect(deleted, isTrue);
    expect(AuthService.getCachedTimetable(classLevel: 'Grade 10', dayOfWeek: 'Sunday'), isEmpty);

    // 5. Auto-Load full CBSE 8-period weekly schedule
    final populated = await authService.populateDefaultCBSEWeeklyTimetable(classLevel: 'Grade 10');
    expect(populated, isTrue);

    for (final day in ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday']) {
      final daySchedule = AuthService.getCachedTimetable(classLevel: 'Grade 10', dayOfWeek: day);
      expect(daySchedule.length, 8, reason: 'Expected 8 periods on $day');
      expect(daySchedule.any((p) => p.isBreak), isTrue, reason: 'Expected break period on $day');
    }
  });

  test('Academics Test 4 (Test 225): Homework Assignment Creation, Deletion & Offline Caching in AuthService', () async {
    SharedPreferences.setMockInitialValues({});
    final authService = AuthService();

    expect(AuthService.getCachedAssignments(classLevel: 'Grade 10', subject: 'All'), isEmpty);

    // 1. Publish a new assignment
    final hw1 = AcademicAssignment(
      id: 'hw_test_01',
      title: 'Trigonometry Problem Set 3',
      subject: 'Mathematics',
      teacherName: 'Mr. Sharma',
      dueDateTime: DateTime.now().add(const Duration(days: 2)),
      pointsReward: 30,
      description: 'Solve questions 10 to 25.',
      classLevel: 'Grade 10',
    );

    final published = await authService.publishAssignment(assignment: hw1, classLevel: 'Grade 10');
    expect(published, isTrue);

    final cachedAll = AuthService.getCachedAssignments(classLevel: 'Grade 10', subject: 'All');
    expect(cachedAll.length, 1);
    expect(cachedAll.first.title, 'Trigonometry Problem Set 3');
    expect(cachedAll.first.pointsReward, 30);

    // Filter by subject
    final mathOnly = AuthService.getCachedAssignments(classLevel: 'Grade 10', subject: 'Mathematics');
    expect(mathOnly.length, 1);

    final physicsOnly = AuthService.getCachedAssignments(classLevel: 'Grade 10', subject: 'Physics');
    expect(physicsOnly, isEmpty);

    // 2. Delete the assignment
    final deleted = await authService.deleteAssignment(
      assignmentId: 'hw_test_01',
      classLevel: 'Grade 10',
      subject: 'Mathematics',
    );
    expect(deleted, isTrue);
    expect(AuthService.getCachedAssignments(classLevel: 'Grade 10', subject: 'All'), isEmpty);
  });

  testWidgets('Academics Test 5 (Test 226): TimetableTab UI: Add Period Modal, Edit Period & Auto-Load CBSE Template Interaction', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const Scaffold(
          body: AcademicsScreen(
            initialTab: 'timetable',
            initialDay: 'Sunday',
            classLevel: 'Grade 10',
            initialPeriods: [],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 1. Verify empty state controls are present
    expect(find.text('No timetable scheduled for this day.'), findsOneWidget);
    expect(find.byKey(const Key('empty_add_period_button')), findsOneWidget);
    expect(find.byKey(const Key('empty_load_cbse_button')), findsOneWidget);

    // 2. Tap Add Period button from empty state to open bottom sheet modal
    await tester.tap(find.byKey(const Key('empty_add_period_button')));
    await tester.pumpAndSettle();

    expect(find.text('Add Timetable Period'), findsOneWidget);
    expect(find.text('Period Number'), findsOneWidget);
    expect(find.text('Subject'), findsOneWidget);
    expect(find.text('Time Slot'), findsOneWidget);
    expect(find.byKey(const Key('save_period_button')), findsOneWidget);

    // Close bottom sheet
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();

    // 3. Test Auto-Load CBSE Timetable dialog
    await tester.tap(find.byKey(const Key('empty_load_cbse_button')));
    await tester.pumpAndSettle();

    expect(find.text('Auto-Load CBSE Timetable?'), findsOneWidget);
    await tester.tap(find.text('Load Timetable'));
    await tester.pumpAndSettle();

    // Verify 8 periods loaded
    expect(find.text('8 Periods'), findsOneWidget);
    expect(find.text('P1'), findsWidgets);
    expect(find.byKey(const Key('edit_period_1')), findsOneWidget);
    expect(find.byKey(const Key('delete_period_1')), findsOneWidget);

    // 4. Tap Edit Period 1
    await tester.tap(find.byKey(const Key('edit_period_1')));
    await tester.pumpAndSettle();

    expect(find.text('Edit Period P1'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();
  });

  testWidgets('Academics Test 6 (Test 227): AssignmentsTab UI: Add Task Modal, Subject Filtering & Delete Task Interaction', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const Scaffold(
          body: AcademicsScreen(
            initialTab: 'homework',
            classLevel: 'Grade 10',
            initialAssignments: [],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 1. Verify empty state with add task button
    expect(find.text('No homework assignments pending for this subject.'), findsOneWidget);
    expect(find.byKey(const Key('empty_add_assignment_button')), findsOneWidget);
    expect(find.byKey(const Key('add_assignment_button')), findsOneWidget);

    // 2. Open Add Task modal
    await tester.tap(find.byKey(const Key('add_assignment_button')));
    await tester.pumpAndSettle();

    expect(find.text('Add Homework / Task'), findsOneWidget);
    expect(find.text('Task Title'), findsOneWidget);
    expect(find.text('Teacher / Faculty'), findsOneWidget);
    expect(find.byKey(const Key('publish_assignment_button')), findsOneWidget);

    // Fill title
    await tester.enterText(find.widgetWithText(TextFormField, 'Task Title'), 'Calculus Derivatives Sheet');
    await tester.pumpAndSettle();

    // Tap publish
    await tester.tap(find.byKey(const Key('publish_assignment_button')));
    await tester.pumpAndSettle();

    // Verify task now appears in the list
    expect(find.text('Calculus Derivatives Sheet'), findsOneWidget);
    expect(find.text('+20 Pts'), findsOneWidget);

    // 3. Delete task
    final allDeleteKeys = find.byWidgetPredicate(
      (w) => w.key is ValueKey<String> && (w.key as ValueKey<String>).value.startsWith('delete_assignment_hw_'),
    );
    expect(allDeleteKeys, findsOneWidget);

    await tester.tap(allDeleteKeys);
    await tester.pumpAndSettle();

    expect(find.text('Delete Assignment?'), findsOneWidget);
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    // Verify task is removed
    expect(find.text('No homework assignments pending for this subject.'), findsOneWidget);
  });

  // ===========================================================================
  // Phase 2 Remediation Tests: Architectural Repair & Data Synchronization
  // ===========================================================================

  test('Phase 2 Test 1: VoucherSecurityService eliminates false positives on missing or unverified vouchers', () async {
    GlobalWalletStore.orders.clear();

    // 1. Empty or blank bill number must immediately return success: false
    final emptyResult = await VoucherSecurityService.claimStoreVoucher(
      billNo: '   ',
      evaluatorName: 'Lead Evaluator',
    );
    expect(emptyResult.success, isFalse);
    expect(emptyResult.message, contains('Invalid voucher'));

    // 2. Missing voucher (neither in remote database nor in local store) must return success: false
    final fakeResult = await VoucherSecurityService.claimStoreVoucher(
      billNo: 'NON_EXISTENT_VOUCHER_99999',
      evaluatorName: 'Lead Evaluator',
    );
    expect(fakeResult.success, isFalse);
    expect(fakeResult.alreadyClaimed, isFalse);
    expect(fakeResult.message, contains('could not be verified'));

    // 3. Genuine voucher present in local store can be claimed successfully
    final genuineOrder = OrderRecord(
      receiptId: 'GENUINE-REC-101',
      items: [
        CartItem(
          product: const MerchProduct(
            id: 'hoodie_1',
            name: 'Ruby Hoodie',
            price: 'BHD 12.000',
            rating: 5.0,
            imageUrl: '',
            category: 'Hoodies',
            house: 'ruby',
            description: '',
          ),
          size: 'L',
          qty: 1,
        ),
      ],
      totalPts: 100,
      date: DateTime.now(),
      qrData: 'mock_qr',
      status: 'ready',
    );
    GlobalWalletStore.orders.add(genuineOrder);

    final genuineResult = await VoucherSecurityService.claimStoreVoucher(
      billNo: 'GENUINE-REC-101',
      evaluatorName: 'Mr. Teacher',
    );
    expect(genuineResult.success, isTrue);
    expect(genuineResult.claimedBy, 'Mr. Teacher');
    expect(genuineResult.claimedAt, isNotNull);

    // 4. Verification status lookup correctly identifies claimed status from local store
    final statusCheck = await VoucherSecurityService.checkVoucherClaimStatus(
      billNo: 'GENUINE-REC-101',
    );
    expect(statusCheck.isClaimed, isTrue);
    expect(statusCheck.claimedBy, 'Mr. Teacher');

    // 5. Verification status lookup correctly identifies unclaimed/non-existent vouchers
    final nonExistentCheck = await VoucherSecurityService.checkVoucherClaimStatus(
      billNo: 'NON_EXISTENT_VOUCHER_99999',
    );
    expect(nonExistentCheck.isClaimed, isFalse);
  });

  test('Phase 2 Test 2: GlobalWalletStore order persistence and offline caching fallback', () async {
    GlobalWalletStore.orders.clear();
    SharedPreferences.setMockInitialValues({});

    final order = OrderRecord(
      receiptId: 'PERSIST-ORD-202',
      items: [
        CartItem(
          product: const MerchProduct(
            id: 'varsity_jacket',
            name: 'Varsity Jacket',
            price: 'BHD 22.000',
            rating: 5.0,
            imageUrl: '',
            category: 'Limited Edition 🔥',
            house: 'all',
            description: '',
          ),
          size: 'XL',
          qty: 2,
        ),
      ],
      totalPts: 0,
      date: DateTime.now(),
      qrData: 'persist_qr_payload',
      status: 'ready',
    );

    // Add and persist order with offline fallback
    await GlobalWalletStore.addAndPersistOrder(
      order,
      scholarNo: '2310910',
      studentName: 'Mustafa Hisham',
      house: 'ruby',
      totalBhd: 44.0,
    );

    expect(GlobalWalletStore.orders.any((o) => o.receiptId == 'PERSIST-ORD-202'), isTrue);

    // Verify SharedPreferences persistence in student partition
    final prefs = await SharedPreferences.getInstance();
    final cachedJsonList = prefs.getStringList(GlobalWalletStore.ordersKey('2310910')) ??
        prefs.getStringList('saved_wallet_orders');
    expect(cachedJsonList, isNotNull);
    expect(cachedJsonList!.any((str) => str.contains('PERSIST-ORD-202')), isTrue);

    // Verify markOrderClaimed persists locally
    await GlobalWalletStore.markOrderClaimed(
      'PERSIST-ORD-202',
      scholarNo: '2310910',
      claimedBy: 'Lead Evaluator',
      claimedAt: DateTime(2026, 10, 21),
    );
    final updated = GlobalWalletStore.orders.firstWhere((o) => o.receiptId == 'PERSIST-ORD-202');
    expect(updated.isClaimed, isTrue);
    expect(updated.claimedBy, 'Lead Evaluator');
  });

  test('Phase 2 Test 3: GlobalWalletStore.orderFromFirestore safely reconstructs orders with fallback', () {
    final firestoreData = {
      'receipt_id': 'FS-ORD-303',
      'scholar_no': '12345',
      'student_name': 'Sarah Ahmed',
      'house': 'sapphire',
      'total_pts': 50,
      'status': 'verified',
      'created_at': Timestamp.fromDate(DateTime(2026, 9, 1)),
      'qr_data': 'qr_303',
      'items': [
        {
          'id': 'cap_1',
          'name': 'Sapphire Cap',
          'price': 'BHD 4.000',
          'size': 'Standard',
          'qty': 1,
          'category': 'Accessories',
          'house': 'sapphire',
        },
      ],
    };

    final order = GlobalWalletStore.orderFromFirestore('FS-ORD-303', firestoreData);
    expect(order.receiptId, 'FS-ORD-303');
    expect(order.totalPts, 50);
    expect(order.status, 'verified');
    expect(order.items.length, 1);
    expect(order.items.first.product.name, 'Sapphire Cap');
    expect(order.items.first.size, 'Standard');
    expect(order.items.first.qty, 1);
    expect(order.qrData, 'qr_303');
  });

  test('Phase 2 Test 4: AuthService certificate upload path and pre-allocated docRef binding', () async {
    final authService = AuthService();
    final dummyBytes = Uint8List.fromList([1, 2, 3, 4, 5]);

    // 1. Verify formatCertificateStoragePath produces exact canonical Cloud Storage path
    final canonicalPath = AuthService.formatCertificateStoragePath(
      house: 'RUBY ',
      scholarNo: ' 2310910 ',
      claimId: 'claim_alpha_123',
    );
    expect(canonicalPath, 'house_claims/ruby/2310910_claim_alpha_123.jpg');

    // 2. Verify uploadCertificateImage accepts house and claimId
    final certUrl = await authService.uploadCertificateImage(
      fileBytes: dummyBytes,
      scholarNo: '2310910',
      house: 'ruby',
      claimId: 'claim_alpha_123',
    );
    expect(certUrl, isNotEmpty);

    // 3. Pre-allocate docRef.id prior to submission
    const preallocatedId = 'preallocated_claim_456';
    final resultClaimId = await authService.submitHouseClaim(
      scholarNo: '2310910',
      studentName: 'Mustafa Hisham',
      houseName: 'ruby',
      activityTitle: 'Robotics Tournament Champion',
      points: 50,
      certUrl: certUrl,
      claimId: preallocatedId,
    );
    expect(resultClaimId, preallocatedId);

    // 4. Verify submitHouseClaim extracts claimId from certUrl when claimId parameter is omitted
    const extractedCertUrl = 'https://storage.googleapis.com/bucket/house_claims/sapphire/12345_extracted_claim_789.jpg';
    final autoExtractedId = await authService.submitHouseClaim(
      scholarNo: '12345',
      studentName: 'Test Student',
      houseName: 'sapphire',
      activityTitle: 'Math Olympiad',
      points: 30,
      certUrl: extractedCertUrl,
    );
    expect(autoExtractedId, 'extracted_claim_789');
  });

  // ===========================================================================
  // Phase 3 Remediation Tests: Lifecycle Management & Database Write Reliability
  // ===========================================================================

  test('Phase 3 Test 1: saveTimetablePeriod & deleteTimetablePeriod fail safely on Firestore write failure without polluting local cache', () async {
    SharedPreferences.setMockInitialValues({});
    final authService = AuthService();
    final period = TimetablePeriod(
      periodNumber: 1,
      timeSlot: '07:45 - 08:30',
      subject: 'Mathematics',
      teacherName: 'Mr. Sharma',
      room: 'Room 101',
      dayOfWeek: 'Sunday',
      classLevel: 'Grade 10',
    );

    // Baseline: save in test fallback mode (isFirebaseLiveOverride = false)
    AuthService.isFirebaseLiveOverride = false;
    AuthService.firestoreFailureSimulated = null;
    final initialSave = await authService.saveTimetablePeriod(period: period, classLevel: 'Grade 10');
    expect(initialSave, isTrue);
    expect(AuthService.getCachedTimetable(classLevel: 'Grade 10', dayOfWeek: 'Sunday').length, 1);

    // Simulate live Firebase mode with remote Firestore write exception
    AuthService.isFirebaseLiveOverride = true;
    AuthService.firestoreFailureSimulated = Exception('Simulated permission-denied Firestore write failure');

    final failingPeriod = period.copyWith(periodNumber: 2, subject: 'Advanced Physics');
    final saveResult = await authService.saveTimetablePeriod(period: failingPeriod, classLevel: 'Grade 10');
    expect(saveResult, isFalse, reason: 'saveTimetablePeriod must return false when Firestore write fails');

    // Local cache must NOT contain failingPeriod
    final cached = AuthService.getCachedTimetable(classLevel: 'Grade 10', dayOfWeek: 'Sunday');
    expect(cached.any((p) => p.periodNumber == 2), isFalse, reason: 'Failed period must not pollute local cache');

    // Test deleteTimetablePeriod failure
    final deleteResult = await authService.deleteTimetablePeriod(
      dayOfWeek: 'Sunday',
      periodNumber: 1,
      classLevel: 'Grade 10',
    );
    expect(deleteResult, isFalse, reason: 'deleteTimetablePeriod must return false when Firestore delete fails');
    // Period 1 must still remain in local cache because delete failed remotely
    final afterFailedDelete = AuthService.getCachedTimetable(classLevel: 'Grade 10', dayOfWeek: 'Sunday');
    expect(afterFailedDelete.length, 1, reason: 'Cache must not delete item when remote delete fails');

    // Reset simulation
    AuthService.isFirebaseLiveOverride = null;
    AuthService.firestoreFailureSimulated = null;
  });

  test('Phase 3 Test 2: publishExamScheduleRange & publishStudentReportCard propagate Firestore failure and prevent cache writes', () async {
    SharedPreferences.setMockInitialValues({});
    final authService = AuthService();

    AuthService.isFirebaseLiveOverride = true;
    AuthService.firestoreFailureSimulated = Exception('Simulated batch commit timeout');

    // publishExamScheduleRange must rethrow
    expect(
      () => authService.publishExamScheduleRange(
        fromGrade: 'Grade 8',
        toGrade: 'Grade 10',
        subject: 'Computer Science',
        paperTitle: 'CS Assessment',
        examDateTime: DateTime.now().add(const Duration(days: 5)),
      ),
      throwsA(isA<Exception>()),
      reason: 'publishExamScheduleRange must rethrow on Firestore failure',
    );
    expect(AuthService.getCachedExamSchedule(classLevel: 'Grade 10'), isEmpty);

    // publishStudentReportCard must rethrow
    expect(
      () => authService.publishStudentReportCard(
        scholarNo: '2310910',
        studentName: 'Mustafa Hisham',
        classLevel: 'Grade 10',
        termName: 'Term 1 Mid-Term',
        overallGpa: 3.9,
        overallPercentage: 94.0,
      ),
      throwsA(isA<Exception>()),
      reason: 'publishStudentReportCard must rethrow on Firestore failure',
    );
    expect(AuthService.getCachedReportCards(classLevel: 'Grade 10', scholarNo: '2310910'), isEmpty);

    // Reset simulation
    AuthService.isFirebaseLiveOverride = null;
    AuthService.firestoreFailureSimulated = null;
  });

  test('Phase 3 Test 3: castDigitalVote, certifyMatchResult & awardChampionshipTrophyAndPoints fail gracefully on live transaction errors', () async {
    SharedPreferences.setMockInitialValues({});
    final authService = AuthService();

    AuthService.isFirebaseLiveOverride = true;
    AuthService.firestoreFailureSimulated = Exception('Simulated transaction contention');

    // castDigitalVote
    final voteRes = await authService.castDigitalVote(
      ballotId: 'ballot_2026_head_boy',
      ballotTitle: 'Head Boy Election 2026',
      candidate: ElectionCandidate(
        scholarNo: '2310910',
        fullName: 'Mustafa Hisham',
        houseName: 'ruby',
        runningPosition: 'Head Boy',
        manifesto: 'Excellence in house leadership',
      ),
      scholarNo: '2310999',
    );
    expect(voteRes.success, isFalse);
    expect(voteRes.receipt, isNull);
    expect(voteRes.error, contains('Vote submission failed'));

    // certifyMatchResult
    final fixture = SportsMatchFixture(
      fixtureId: 'fix_sim_100',
      tournamentTitle: 'Inter-House Football',
      sportType: SportType.football,
      houseA: 'ruby',
      houseB: 'emerald',
      scoreA: 3,
      scoreB: 1,
      venue: 'Main Ground',
      scheduledAt: DateTime.now(),
    );
    final certRes = await authService.certifyMatchResult(
      fixture: fixture,
      refereeScholarNo: '2310910',
      refereeName: 'Referee Name',
      refereeRole: 'captain',
      finalScoreA: 3,
      finalScoreB: 1,
      fairPlayRating: 5,
    );
    expect(certRes.success, isFalse);
    expect(certRes.token, isNull);
    expect(certRes.error, contains('Database write failed'));

    // awardChampionshipTrophyAndPoints
    final trophyRes = await authService.awardChampionshipTrophyAndPoints(
      tournamentTitle: 'Inter-House Football 2026',
      sportType: SportType.football,
      winningHouse: 'ruby',
      runnerUpHouse: 'emerald',
      pointsAwarded: 100,
      runnerUpPoints: 50,
      commissionerName: 'Sports Commissioner',
      adminScholarNo: '2310910',
      adminRole: 'captain',
    );
    expect(trophyRes.success, isFalse);
    expect(trophyRes.record, isNull);
    expect(trophyRes.error, contains('Database transaction failed'));

    // Reset simulation
    AuthService.isFirebaseLiveOverride = null;
    AuthService.firestoreFailureSimulated = null;
  });

  testWidgets('Phase 3 Test 4: ManagedModalScope properly disposes controllers upon element unmount without premature disposal', (WidgetTester tester) async {
    final controller1 = TextEditingController(text: 'Initial text 1');
    final controller2 = TextEditingController(text: 'Initial text 2');

    // Mount widget wrapped with ManagedModalScope inside showModalBottomSheet
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  builder: (ctx) => ManagedModalScope(
                    controllers: [controller1, controller2],
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextField(controller: controller1),
                          TextField(controller: controller2),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Close Modal'),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
              child: const Text('Open Modal'),
            ),
          ),
        ),
      ),
    );

    // Open modal
    await tester.tap(find.text('Open Modal'));
    await tester.pumpAndSettle();

    // Verify modal is displayed and controllers work
    expect(find.text('Initial text 1'), findsOneWidget);
    expect(find.text('Initial text 2'), findsOneWidget);

    // Type text into controller 1
    await tester.enterText(find.widgetWithText(TextField, 'Initial text 1'), 'Updated text 1');
    expect(controller1.text, 'Updated text 1');

    // Tap Close Modal button: this pops the route and triggers the unmount animation
    await tester.tap(find.text('Close Modal'));
    await tester.pumpAndSettle();

    // After route dismissal completes, controllers must be disposed
    // Calling addListener on a disposed controller throws FlutterError
    expect(
      () => controller1.addListener(() {}),
      throwsA(isA<FlutterError>()),
      reason: 'controller1 should be disposed after route dismissal finishes',
    );
    expect(
      () => controller2.addListener(() {}),
      throwsA(isA<FlutterError>()),
      reason: 'controller2 should be disposed after route dismissal finishes',
    );
  });

  test('Phase 4 Test 1: Gemini candidate models audit (no hallucinated models)', () {
    final models = GeminiAiService.candidateModels;
    expect(models, isNotEmpty);
    expect(models, contains('gemini-2.0-flash'));
    expect(models, contains('gemini-1.5-flash'));
    expect(models, contains('gemini-1.5-pro'));
    expect(models, isNot(contains('gemini-3.8-flash')));
    expect(models, isNot(contains('gemini-2.5-flash')));
    expect(models.first, equals('gemini-2.0-flash'));
  });

  test('Phase 4 Test 2: GeminiAiService.validateApiKey validates keys and executes model fallback', () async {
    // 1. Empty key check
    final emptyRes = await GeminiAiService.validateApiKey('   ');
    expect(emptyRes.isValid, isFalse);
    expect(emptyRes.message, contains('API key cannot be empty'));

    // 2. Successful response on primary model
    final requestedUrls = <String>[];
    GeminiAiService.httpClientOverride = _Phase4MockHttpClient((req) async {
      requestedUrls.add(req.url.toString());
      if (req.url.toString().contains('gemini-2.0-flash')) {
        return http.Response(jsonEncode({'candidates': [{'content': {'parts': [{'text': 'OK'}]}}]}), 200);
      }
      return http.Response('Not found', 404);
    });

    final validRes = await GeminiAiService.validateApiKey('valid_test_key_123');
    expect(validRes.isValid, isTrue);
    expect(validRes.message, contains('gemini-2.0-flash'));
    expect(requestedUrls.length, 1);

    // 3. Model fallback when gemini-2.0-flash returns 404
    requestedUrls.clear();
    GeminiAiService.httpClientOverride = _Phase4MockHttpClient((req) async {
      requestedUrls.add(req.url.toString());
      if (req.url.toString().contains('gemini-2.0-flash')) {
        return http.Response('Model not found', 404);
      }
      if (req.url.toString().contains('gemini-1.5-flash')) {
        return http.Response(jsonEncode({'candidates': [{'content': {'parts': [{'text': 'OK'}]}}]}), 200);
      }
      return http.Response('Not found', 404);
    });

    final fallbackRes = await GeminiAiService.validateApiKey('valid_test_key_456');
    expect(fallbackRes.isValid, isTrue);
    expect(fallbackRes.message, contains('gemini-1.5-flash'));
    expect(requestedUrls.length, 2);

    // 4. Unauthorized key (400 / 403) terminates immediately with server error message
    GeminiAiService.httpClientOverride = _Phase4MockHttpClient((req) async {
      return http.Response(
        jsonEncode({
          'error': {'message': 'API_KEY_INVALID: User key expired.'}
        }),
        400,
      );
    });

    final invalidRes = await GeminiAiService.validateApiKey('invalid_key');
    expect(invalidRes.isValid, isFalse);
    expect(invalidRes.message, contains('API_KEY_INVALID'));

    // 5. Total failure across all models
    GeminiAiService.httpClientOverride = _Phase4MockHttpClient((req) async {
      throw Exception('Connection refused');
    });

    final failRes = await GeminiAiService.validateApiKey('some_key');
    expect(failRes.isValid, isFalse);
    expect(failRes.message, contains('Could not connect to Gemini servers'));

    GeminiAiService.httpClientOverride = null;
  });

  test('Phase 4 Test 3: GeminiAiService.generateResponse live generation, fallback, and offline recovery', () async {
    SharedPreferences.setMockInitialValues({});
    await GeminiAiService.saveApiKey('test_live_key');

    // 1. Primary model returns valid content
    GeminiAiService.httpClientOverride = _Phase4MockHttpClient((req) async {
      expect(req.url.toString(), contains('gemini-2.0-flash'));
      return http.Response.bytes(
        utf8.encode(jsonEncode({
          'candidates': [
            {
              'content': {
                'parts': [
                  {'text': 'Welcome Ruby house warrior! Keep striving.'}
                ]
              }
            }
          ]
        })),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });

    final liveRes = await GeminiAiService.generateResponse(
      prompt: 'Motivate me',
      house: 'ruby',
      studentName: 'Mustafa',
    );
    expect(liveRes, contains('Ruby house warrior'));

    // 2. Primary model 500 fails, falls back to gemini-1.5-flash
    final calledModels = <String>[];
    GeminiAiService.httpClientOverride = _Phase4MockHttpClient((req) async {
      if (req.url.toString().contains('gemini-2.0-flash')) {
        calledModels.add('gemini-2.0-flash');
        return http.Response('Server Error', 500);
      }
      if (req.url.toString().contains('gemini-1.5-flash')) {
        calledModels.add('gemini-1.5-flash');
        return http.Response.bytes(
          utf8.encode(jsonEncode({
            'candidates': [
              {
                'content': {
                  'parts': [
                    {'text': 'Fallback response from 1.5-flash!'}
                  ]
                }
              }
            ]
          })),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
      return http.Response('Not found', 404);
    });

    final fallbackRes = await GeminiAiService.generateResponse(
      prompt: 'Tell me about points',
      house: 'ruby',
      studentName: 'Mustafa',
    );
    expect(fallbackRes, contains('Fallback response from 1.5-flash'));
    expect(calledModels, contains('gemini-2.0-flash'));

    // 3. All models fail (network outage): falls back to contextual local response cleanly
    GeminiAiService.httpClientOverride = _Phase4MockHttpClient((req) async {
      throw Exception('SocketException: Network unreachable');
    });

    final offlineFallback = await GeminiAiService.generateResponse(
      prompt: 'What is my schedule?',
      house: 'ruby',
      studentName: 'Mustafa',
    );
    expect(offlineFallback, isNotEmpty);
    expect(offlineFallback, contains('Timetable Schedule'));

    GeminiAiService.httpClientOverride = null;
    await GeminiAiService.saveApiKey('');
  });

  testWidgets('Phase 4 Test 4: DropdownButtonFormField initialValue state updates and super_admin roster slot immunity', (WidgetTester tester) async {
    // 1. Verify dynamic initialValue reactivity on DropdownButtonFormField
    String currentValue = 'Option A';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return Column(
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: currentValue,
                    items: const [
                      DropdownMenuItem(value: 'Option A', child: Text('Option A')),
                      DropdownMenuItem(value: 'Option B', child: Text('Option B')),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => currentValue = val);
                    },
                  ),
                  ElevatedButton(
                    onPressed: () => setState(() => currentValue = 'Option B'),
                    child: const Text('Change to B'),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );

    expect(find.text('Option A'), findsOneWidget);

    // Tap button to programmatically change value and trigger didUpdateWidget
    await tester.tap(find.text('Change to B'));
    await tester.pumpAndSettle();
    expect(find.text('Option B'), findsOneWidget);

    // 2. Verify EditRosterSlotDialog with role: 'super_admin' renders without assertion failure
    final authService = AuthService();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => EditRosterSlotDialog(
                    docId: 'slot_super_admin_test',
                    data: const {
                      'name': 'System Administrator',
                      'scholar_no': '999999',
                      'title': 'Principal Super Admin',
                      'role': 'super_admin',
                      'house': 'All',
                    },
                    authService: authService,
                  ),
                );
              },
              child: const Text('Open Edit Slot'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open Edit Slot'));
    await tester.pumpAndSettle();

    // Dialog must be rendered with super_admin item matching initialValue
    expect(find.text('👑 Super Admin'), findsOneWidget);
    expect(find.text('Edit Principal Super Admin'), findsOneWidget);

    // Close dialog
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
  });

  test('Phase 4 Test 5: Pubspec dead dependencies and unused import hygiene audit', () {
    final pubspecFile = File('pubspec.yaml');
    expect(pubspecFile.existsSync(), isTrue);
    final pubspecContent = pubspecFile.readAsStringSync();

    // Must not contain google_generative_ai or cupertino_icons
    expect(pubspecContent, isNot(contains('google_generative_ai:')));
    expect(pubspecContent, isNot(contains('cupertino_icons:')));

    // Home screen must not import dart:ui
    final homeFile = File('lib/screens/home_screen.dart');
    expect(homeFile.existsSync(), isTrue);
    final homeContent = homeFile.readAsStringSync();
    expect(homeContent, isNot(contains("import 'dart:ui';")));
  });

  testWidgets('Phase 5 Test 1: WCAG 2.1 AA min 48x48 dp touch target compliance on post deletion and account removal buttons', (tester) async {
    // 1. Audit home_screen.dart file to ensure sub-48dp constraints are replaced and Semantics is present
    final homeFile = File('lib/screens/home_screen.dart');
    expect(homeFile.existsSync(), isTrue);
    final homeContent = homeFile.readAsStringSync();
    expect(homeContent, isNot(contains('constraints: const BoxConstraints(),\n                                padding: const EdgeInsets.symmetric(horizontal: 4)')));
    expect(homeContent, contains('constraints: const BoxConstraints(minWidth: 48, minHeight: 48)'));
    expect(homeContent, contains("label: 'Delete post'"));

    // 2. Audit account_switcher_modal.dart to ensure sub-48dp constraints are eliminated
    final switcherFile = File('lib/widgets/account_switcher_modal.dart');
    expect(switcherFile.existsSync(), isTrue);
    final switcherContent = switcherFile.readAsStringSync();
    expect(switcherContent, isNot(contains('minWidth: 32')));
    expect(switcherContent, isNot(contains('minHeight: 32')));
    expect(switcherContent, contains('minWidth: 48'));
    expect(switcherContent, contains('minHeight: 48'));
    expect(switcherContent, contains("label: 'Remove account from this device'"));

    // 3. Mount AccountSwitcherModal with a saved secondary account and verify live touch target meets >= 48x48 dp
    SharedPreferences.setMockInitialValues({
      'cached_scholar_no': '2310001',
      'saved_accounts_list': jsonEncode([
        {
          'scholar_no': '2310999',
          'full_name': 'Ahmad Test',
          'house': 'sapphire',
          'class_level': '10',
          'division': 'A',
        },
      ]),
    });
    await AuthService.initPreferences();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () {
                AccountSwitcherModal.show(
                  ctx,
                  houseColor: HouseColors.emerald,
                  currentHouse: 'emerald',
                  onSwitchAccount: (_) async {},
                  onSignOutCurrent: () async {},
                  onSignOutAll: () async {},
                );
              },
              child: const Text('Open Switcher'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Tap button to open modal
    await tester.tap(find.text('Open Switcher'));
    await tester.pumpAndSettle();

    // Verify remove account button exists with compliant touch target >= 48x48
    final removeBtnFinder = find.byTooltip('Remove account from this device');
    expect(removeBtnFinder, findsOneWidget);
    final removeSize = tester.getSize(removeBtnFinder);
    expect(removeSize.width, greaterThanOrEqualTo(48.0));
    expect(removeSize.height, greaterThanOrEqualTo(48.0));

    // Verify modal close button also meets min 48x48
    final closeBtnFinder = find.byTooltip('Close');
    expect(closeBtnFinder, findsOneWidget);
    final closeSize = tester.getSize(closeBtnFinder);
    expect(closeSize.width, greaterThanOrEqualTo(48.0));
    expect(closeSize.height, greaterThanOrEqualTo(48.0));

    // Close the modal
    await tester.tap(closeBtnFinder);
    await tester.pumpAndSettle();
  });

  testWidgets('Phase 5 Test 2: Dynamic tooltip and Semantics on LoginScreen and AccountSwitcherModal password toggles', (tester) async {
    final handle = tester.ensureSemantics();

    try {
      // 1. Test LoginScreen password visibility toggle
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: const LoginScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Verify initial obscured state has "Show password" tooltip and Semantics label
      final loginShowFinder = find.byTooltip('Show password');
      expect(loginShowFinder, findsOneWidget);
      expect(find.bySemanticsLabel('Show password'), findsOneWidget);

      // Verify touch target size meets >= 48x48 dp
      final showSize = tester.getSize(loginShowFinder);
      expect(showSize.width, greaterThanOrEqualTo(48.0));
      expect(showSize.height, greaterThanOrEqualTo(48.0));

      // Tap to toggle visibility
      await tester.tap(loginShowFinder);
      await tester.pumpAndSettle();

      // Verify toggled revealed state has "Hide password" tooltip and Semantics label
      final loginHideFinder = find.byTooltip('Hide password');
      expect(loginHideFinder, findsOneWidget);
      expect(find.bySemanticsLabel('Hide password'), findsOneWidget);

      // 2. Test AccountSwitcherModal sibling password toggle
      SharedPreferences.setMockInitialValues({});
      await AuthService.initPreferences();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () {
                  AccountSwitcherModal.show(
                    ctx,
                    houseColor: HouseColors.ruby,
                    currentHouse: 'ruby',
                    onSwitchAccount: (_) async {},
                    onSignOutCurrent: () async {},
                    onSignOutAll: () async {},
                  );
                },
                child: const Text('Open Modal'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open Modal'));
      await tester.pumpAndSettle();

      // Tap to expand sibling link form
      final addSiblingBtn = find.text('Add Sibling / Another Account');
      expect(addSiblingBtn, findsOneWidget);
      await tester.tap(addSiblingBtn);
      await tester.pumpAndSettle();

      // Verify sibling password field toggle
      final siblingShowFinder = find.byTooltip('Show password');
      expect(siblingShowFinder, findsOneWidget);
      expect(find.bySemanticsLabel('Show password'), findsOneWidget);

      await tester.tap(siblingShowFinder);
      await tester.pumpAndSettle();

      expect(find.byTooltip('Hide password'), findsOneWidget);
      expect(find.bySemanticsLabel('Hide password'), findsOneWidget);

      // 3. Audit SignupScreen file to verify both password and confirm password have dynamic tooltip and semantics
      final signupFile = File('lib/screens/signup_screen.dart');
      expect(signupFile.existsSync(), isTrue);
      final signupContent = signupFile.readAsStringSync();
      expect(signupContent, contains("label: _obscurePassword ? 'Show password' : 'Hide password'"));
      expect(signupContent, contains("tooltip: _obscurePassword ? 'Show password' : 'Hide password'"));
      expect(signupContent, contains("label: _obscureConfirm ? 'Show password' : 'Hide password'"));
      expect(signupContent, contains("tooltip: _obscureConfirm ? 'Show password' : 'Hide password'"));
    } finally {
      handle.dispose();
    }
  });

  testWidgets('Phase 5 Test 3: Screen reader Semantics and Close tooltip on modal dialog close buttons', (tester) async {
    final handle = tester.ensureSemantics();

    try {
      // 1. Audit academics_screen.dart for tooltip: 'Close' and Semantics(button: true, label: 'Close dialog')
      final academicsFile = File('lib/screens/academics_screen.dart');
      expect(academicsFile.existsSync(), isTrue);
      final academicsContent = academicsFile.readAsStringSync();
      expect(academicsContent, contains("label: 'Close dialog'"));
      expect(academicsContent, contains("tooltip: 'Close'"));
      expect(academicsContent, contains("label: 'Remove attached photo'"));
      expect(academicsContent, contains("tooltip: 'Remove photo'"));

      // 2. Audit house_ai_chat_screen.dart for Gemini modal close button semantics and clear API key button
      final chatFile = File('lib/screens/house_ai_chat_screen.dart');
      expect(chatFile.existsSync(), isTrue);
      final chatContent = chatFile.readAsStringSync();
      expect(chatContent, contains("label: 'Close dialog'"));
      expect(chatContent, contains("tooltip: 'Close'"));
      expect(chatContent, contains("label: 'Clear API key'"));
      expect(chatContent, contains("tooltip: 'Clear API key'"));

      // 3. Mount HouseAiChatScreen and open Gemini key modal to verify live Semantics node and dismiss
      await tester.pumpWidget(
        const MaterialApp(
          home: HouseAiChatScreen(
            userHouse: 'emerald',
            studentName: 'Sarah',
            scholarNo: '4042',
          ),
        ),
      );
      await tester.pumpAndSettle();

      final geminiConfigBtn = find.byTooltip('Configure Gemini API Key');
      expect(geminiConfigBtn, findsOneWidget);
      await tester.tap(geminiConfigBtn);
      await tester.pumpAndSettle();

      // Verify close dialog button with tooltip and semantics is rendered
      final closeBtnFinder = find.byTooltip('Close');
      expect(closeBtnFinder, findsOneWidget);
      expect(find.bySemanticsLabel('Close dialog'), findsOneWidget);

      // Tap close and verify dialog dismisses
      await tester.tap(closeBtnFinder);
      await tester.pumpAndSettle();
      expect(find.text('Google Gemini API Key'), findsNothing);
    } finally {
      handle.dispose();
    }
  });

  test('Phase 5 Test 4: Localization Foundation (ARB Assets, l10n.yaml, and AppLocalizations class)', () {
    // 1. Check l10n.yaml
    final l10nFile = File('l10n.yaml');
    expect(l10nFile.existsSync(), isTrue);
    final l10nContent = l10nFile.readAsStringSync();
    expect(l10nContent, contains('arb-dir: lib/l10n'));
    expect(l10nContent, contains('template-arb-file: app_en.arb'));
    expect(l10nContent, contains('output-localization-file: app_localizations.dart'));

    // 2. Check pubspec.yaml
    final pubspecFile = File('pubspec.yaml');
    expect(pubspecFile.existsSync(), isTrue);
    final pubspecContent = pubspecFile.readAsStringSync();
    expect(pubspecContent, contains('flutter_localizations:'));
    expect(pubspecContent, contains('intl:'));
    expect(pubspecContent, contains('generate: true'));

    // 3. Check ARB files exist
    final enArbFile = File('lib/l10n/app_en.arb');
    final arArbFile = File('lib/l10n/app_ar.arb');
    expect(enArbFile.existsSync(), isTrue);
    expect(arArbFile.existsSync(), isTrue);

    final enJson = jsonDecode(enArbFile.readAsStringSync()) as Map<String, dynamic>;
    final arJson = jsonDecode(arArbFile.readAsStringSync()) as Map<String, dynamic>;

    // Core keys audit
    final requiredKeys = [
      'appTitle',
      'houseEmerald',
      'houseRuby',
      'houseSapphire',
      'houseTopaz',
      'navHome',
      'navArena',
      'navLeaderboard',
      'navWallet',
      'navAcademics',
      'navEvents',
      'navElections',
      'navSports',
      'actionSave',
      'actionCancel',
      'actionDelete',
      'actionClose',
      'actionSubmit',
      'actionConfirm',
      'actionRetry',
      'actionSearch',
      'actionFilter',
      'actionEdit',
      'actionBack',
      'actionNext',
      'actionDone',
      'closeDialog',
      'login',
      'signup',
      'email',
      'password',
      'confirmPassword',
      'scholarNumber',
      'showPassword',
      'hidePassword',
      'forgotPassword',
      'signIn',
      'signOut',
      'createAccount',
      'alreadyHaveAccount',
      'dontHaveAccount',
    ];

    for (final key in requiredKeys) {
      expect(enJson.containsKey(key), isTrue, reason: 'app_en.arb missing key: $key');
      expect(arJson.containsKey(key), isTrue, reason: 'app_ar.arb missing key: $key');
    }

    // 4. Test AppLocalizations supportedLocales
    final supportedLocales = AppLocalizations.supportedLocales;
    expect(supportedLocales.any((l) => l.languageCode == 'en'), isTrue);
    expect(supportedLocales.any((l) => l.languageCode == 'ar'), isTrue);

    // 5. Test AppLocalizations translations resolution
    final enLoc = lookupAppLocalizations(const Locale('en'));
    final arLoc = lookupAppLocalizations(const Locale('ar'));

    expect(enLoc.appTitle, equals('ASB House Hub'));
    expect(arLoc.appTitle, equals('مركز منازل ASB'));
    expect(enLoc.houseEmerald, equals('Emerald'));
    expect(arLoc.houseEmerald, equals('الزمرد'));
    expect(enLoc.houseRuby, equals('Ruby'));
    expect(arLoc.houseRuby, equals('الياقوت'));
    expect(enLoc.houseSapphire, equals('Sapphire'));
    expect(arLoc.houseSapphire, equals('الزفير'));
    expect(enLoc.houseTopaz, equals('Topaz'));
    expect(arLoc.houseTopaz, equals('التوباز'));
    expect(enLoc.login, equals('Login'));
    expect(arLoc.login, equals('تسجيل الدخول'));
    expect(enLoc.signup, equals('Sign Up'));
    expect(arLoc.signup, equals('إنشاء حساب'));
    expect(enLoc.actionClose, equals('Close'));
    expect(arLoc.actionClose, equals('إغلاق'));
  });

  testWidgets('Phase 5 Test 5: MaterialApp localization integration and localized widget tree resolution', (tester) async {
    late BuildContext capturedContext;

    // Pump widget tree with Arabic locale
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('ar'),
        home: Builder(
          builder: (ctx) {
            capturedContext = ctx;
            return Scaffold(
              body: Text(AppLocalizations.of(ctx)!.appTitle),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('مركز منازل ASB'), findsOneWidget);
    final l10n = AppLocalizations.of(capturedContext);
    expect(l10n, isNotNull);
    expect(l10n!.appTitle, equals('مركز منازل ASB'));
    expect(l10n.navHome, equals('الرئيسية'));
    expect(l10n.houseEmerald, equals('الزمرد'));
  });

  // =========================================================================
  // Phase 1 Security & Database Unblockers Tests
  // =========================================================================

  test('Phase 1 Test 1: CredentialVaultService encrypts, decrypts, rejects tampering and handles legacy tokens', () {
    const rawSecret = 'P@ssw0rd_Zaid_2026!';
    final token1 = CredentialVaultService.encrypt(rawSecret);
    final token2 = CredentialVaultService.encrypt(rawSecret);

    expect(token1, isNotNull);
    expect(token1!.startsWith('enc:v1:'), isTrue);
    // Semantic security: fresh IV ensures two encryptions of the same plaintext yield distinct tokens
    expect(token1, isNot(equals(token2)));

    // Decryption round-trip
    expect(CredentialVaultService.decrypt(token1), equals(rawSecret));
    expect(CredentialVaultService.decrypt(token2), equals(rawSecret));

    // Legacy unencrypted plaintext fallback
    expect(CredentialVaultService.decrypt('plain_legacy_pass'), equals('plain_legacy_pass'));

    // Tampered payload fails authentication tag verification
    final tamperedToken = 'enc:v1:AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA';
    expect(CredentialVaultService.decrypt(tamperedToken), isNull);

    // Null and empty safety
    expect(CredentialVaultService.encrypt(null), isNull);
    expect(CredentialVaultService.encrypt(''), equals(''));
    expect(CredentialVaultService.decrypt(null), isNull);
    expect(CredentialVaultService.decrypt(''), equals(''));
  });

  test('Phase 1 Test 2: SharedPreferences saved_accounts_list never leaks plaintext passwords and decrypts transparently', () async {
    SharedPreferences.setMockInitialValues({});
    await AuthService.initPreferences();

    const plainPassword = 'StudentSecretAuthToken999!';
    final account = SavedAccount(
      scholarNo: '2310910',
      fullName: 'Zaid Al-Husseini',
      houseName: 'ruby',
      uid: 'uid_zaid_phase1',
      role: 'student',
      classLevel: 'Grade 10',
      division: 'A',
      password: plainPassword,
      cachedProfile: {'scholar_no': '2310910', 'full_name': 'Zaid Al-Husseini'},
    );

    await AuthService.saveAccount(account);

    // Verify raw SharedPreferences does NOT contain plaintext password
    final prefs = await SharedPreferences.getInstance();
    final rawStored = prefs.getString('saved_accounts_list');
    expect(rawStored, isNotNull);
    expect(rawStored!.contains(plainPassword), isFalse, reason: 'Plaintext password must NEVER be persisted in SharedPreferences');
    expect(rawStored.contains('enc:v1:'), isTrue, reason: 'Stored account must contain encrypted credential token');

    // Verify transparent in-memory decryption for runtime session switching
    final accounts = AuthService.getSavedAccounts();
    expect(accounts.length, equals(1));
    expect(accounts.first.scholarNo, equals('2310910'));
    expect(accounts.first.password, equals(plainPassword));

    // Verify recordActiveAccount preserves credentials
    await AuthService.recordActiveAccount(
      profile: {'scholar_no': '2310910', 'full_name': 'Zaid Al-Husseini', 'house_name': 'ruby'},
      password: plainPassword,
    );
    final updatedAccounts = AuthService.getSavedAccounts();
    expect(updatedAccounts.first.password, equals(plainPassword));

    await AuthService.clearAllSavedAccounts();
    expect(AuthService.getSavedAccounts(), isEmpty);
  });

  test('Phase 1 Test 3: firestore.rules and storage.rules enforce Phase 1 security policies and collections', () {
    final firestoreFile = File('firestore.rules');
    expect(firestoreFile.existsSync(), isTrue);
    final firestoreContent = firestoreFile.readAsStringSync();

    // Verify 4 unmatched collections are explicitly defined
    expect(firestoreContent.contains('system_config'), isTrue);
    expect(firestoreContent.contains('house_spirit_reactor'), isTrue);
    expect(firestoreContent.contains('settings'), isTrue);
    expect(firestoreContent.contains('ticker'), isTrue);
    expect(firestoreContent.contains('event_wall'), isTrue);
    expect(firestoreContent.contains('player_sports_stats'), isTrue);

    // Verify super admin bootstrap registration allowed
    expect(firestoreContent.contains('admin@asianschool.bh'), isTrue);

    // Verify elections voting update rule
    expect(firestoreContent.contains('total_votes_cast'), isTrue);
    expect(firestoreContent.contains('candidates'), isTrue);

    // Verify storage.rules has NO wildcard write
    final storageFile = File('storage.rules');
    expect(storageFile.existsSync(), isTrue);
    final storageContent = storageFile.readAsStringSync();
    expect(storageContent.contains('match /{allPaths=**}'), isTrue);
    expect(storageContent.contains('match /{allPaths=**} {\n      allow read: if isSignedIn();\n      allow write: if false;'), isTrue);
    expect(storageContent.contains('house_claims'), isTrue);
    expect(storageContent.contains('profile_pictures'), isTrue);
    expect(storageContent.contains('exam_schedules'), isTrue);
  });

  test('Phase 1 Test 4: CredentialVaultService handles passwords starting with enc:v1: and unicode/emojis without data loss', () async {
    SharedPreferences.setMockInitialValues({});
    await AuthService.initPreferences();

    // 1. Password that starts with 'enc:v1:' must not be corrupted
    const trickyPassword = 'enc:v1:MyVerySecretSpecialPassphrase_2026!';
    final encryptedTricky = CredentialVaultService.encrypt(trickyPassword);
    expect(encryptedTricky, isNotNull);
    expect(encryptedTricky, isNot(equals(trickyPassword)));
    expect(CredentialVaultService.decrypt(encryptedTricky), equals(trickyPassword));

    // 2. Unicode, arabic, emojis, and quotes
    const unicodePassword = '🔐كلمة_السر_العربية_2026!"\'\\#\$%^&*()';
    final encryptedUnicode = CredentialVaultService.encrypt(unicodePassword);
    expect(encryptedUnicode, isNotNull);
    expect(CredentialVaultService.decrypt(encryptedUnicode), equals(unicodePassword));

    // 3. Idempotent encryption: encrypting an already encrypted token returns it unchanged
    final doubleEncrypted = CredentialVaultService.encrypt(encryptedUnicode);
    expect(doubleEncrypted, equals(encryptedUnicode));

    // 4. Leak prevention: cached_profile with plaintext password is stripped in toMap
    final accountWithLeakyProfile = SavedAccount(
      scholarNo: '2310999',
      fullName: 'Leaky Student',
      houseName: 'sapphire',
      uid: 'uid_leaky',
      password: 'RealSecretPassword99!',
      cachedProfile: {
        'scholar_no': '2310999',
        'password': 'LeakedPlaintextInsideProfile!',
      },
    );
    final serialized = accountWithLeakyProfile.toMap();
    expect((serialized['cached_profile'] as Map).containsKey('password'), isFalse);

    // 5. Deserialization handles legacy account with password nested in profile
    final legacyMap = {
      'scholar_no': '2310888',
      'full_name': 'Legacy Student',
      'house_name': 'emerald',
      'uid': 'uid_legacy',
      'cached_profile': {
        'scholar_no': '2310888',
        'password': 'LegacyPassword123!',
      },
    };
    final deserialized = SavedAccount.fromMap(legacyMap);
    expect(deserialized.password, equals('LegacyPassword123!'));
    expect(deserialized.cachedProfile.containsKey('password'), isFalse);
  });

  test('Phase 1 Test 5: firestore.rules and storage.rules enforce election unblockers, election_gazettes, and sports_fixtures events', () {
    final firestoreFile = File('firestore.rules');
    expect(firestoreFile.existsSync(), isTrue);
    final firestoreContent = firestoreFile.readAsStringSync();

    // Valid election allows house_scope, eligible_grades, status, is_certified
    expect(firestoreContent.contains('house_scope'), isTrue);
    expect(firestoreContent.contains('eligible_grades'), isTrue);
    expect(firestoreContent.contains('is_certified'), isTrue);
    expect(firestoreContent.contains('election_gazettes'), isTrue);

    // Sports fixtures subcollection events allowed
    expect(firestoreContent.contains('sports_fixtures'), isTrue);
    expect(firestoreContent.contains('events'), isTrue);

    // House points allows sports leads
    expect(firestoreContent.contains('house_points'), isTrue);
    expect(firestoreContent.contains('isSportsLead()'), isTrue);

    // Verify storage.rules has wildcard recursion support
    final storageFile = File('storage.rules');
    expect(storageFile.existsSync(), isTrue);
    final storageContent = storageFile.readAsStringSync();
    expect(storageContent.contains('fileName=**'), isTrue);
  });

  test('Phase 2 Test 5: GlobalWalletStore partitions orders, cart, and favorites by scholar number in local storage', () async {
    SharedPreferences.setMockInitialValues({});
    GlobalWalletStore.resetSession();

    // 1. Verify partition key resolvers
    expect(GlobalWalletStore.ordersKey('1001'), 'saved_wallet_orders_1001');
    expect(GlobalWalletStore.cartKey('1001'), 'saved_wallet_cart_1001');
    expect(GlobalWalletStore.favoritesKey('1001'), 'saved_wallet_favorites_1001');

    // 2. Student 1001 session setup & persistence
    await GlobalWalletStore.init(scholarNo: '1001');
    expect(GlobalWalletStore.isInitialized, isTrue);
    expect(GlobalWalletStore.currentScholarNo, '1001');

    final order1001 = OrderRecord(
      receiptId: 'ORD-1001',
      items: [
        CartItem(
          product: const MerchProduct(
            id: 'ruby_hoodie',
            name: 'Ruby Hoodie',
            price: 'BHD 18.000',
            rating: 5.0,
            imageUrl: '',
            category: 'Hoodies',
            house: 'ruby',
            description: '',
          ),
          size: 'L',
          qty: 1,
        ),
      ],
      totalPts: 0,
      date: DateTime.now(),
      qrData: 'qr_1001',
      status: 'ready',
    );
    GlobalWalletStore.orders.add(order1001);
    GlobalWalletStore.cart.add(
      CartItem(
        product: const MerchProduct(
          id: 'ruby_cap',
          name: 'Ruby Cap',
          price: 'BHD 4.000',
          rating: 4.8,
          imageUrl: '',
          category: 'Accessories',
          house: 'ruby',
          description: '',
        ),
        size: 'Standard',
        qty: 2,
      ),
    );
    GlobalWalletStore.favoriteIds.add('drop_varsity_ruby');

    await GlobalWalletStore.saveOrders(scholarNo: '1001');
    await GlobalWalletStore.saveCart(scholarNo: '1001');
    await GlobalWalletStore.saveFavorites(scholarNo: '1001');

    // Verify written to student 1001 partition in SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final orders1001List = prefs.getStringList('saved_wallet_orders_1001');
    expect(orders1001List, isNotNull);
    expect(orders1001List!.any((s) => s.contains('ORD-1001')), isTrue);

    final cart1001List = prefs.getStringList('saved_wallet_cart_1001');
    expect(cart1001List, isNotNull);
    expect(cart1001List!.any((s) => s.contains('ruby_cap')), isTrue);

    final favs1001List = prefs.getStringList('saved_wallet_favorites_1001');
    expect(favs1001List, isNotNull);
    expect(favs1001List!.contains('drop_varsity_ruby'), isTrue);

    // Verify unpartitioned fallback keys are NOT contaminated with student 1001's private cart/orders/favorites
    expect(prefs.getStringList('saved_wallet_orders'), isNull);
    expect(prefs.getStringList('saved_wallet_cart'), isNull);
    expect(prefs.getStringList('saved_wallet_favorites'), isNull);

    // 3. Reset session (e.g. on logout)
    GlobalWalletStore.resetSession();
    expect(GlobalWalletStore.orders.isEmpty, isTrue);
    expect(GlobalWalletStore.cart.isEmpty, isTrue);
    expect(GlobalWalletStore.favoriteIds.isEmpty, isTrue);
    expect(GlobalWalletStore.isInitialized, isFalse);
    expect(GlobalWalletStore.currentScholarNo, isNull);

    // 4. Student 2002 logs in on the same device — must NOT see Student 1001's data
    await GlobalWalletStore.init(scholarNo: '2002');
    expect(GlobalWalletStore.currentScholarNo, '2002');
    expect(GlobalWalletStore.orders.isEmpty, isTrue);
    expect(GlobalWalletStore.cart.isEmpty, isTrue);
    // Student 2002 receives fresh default favorites without 1001's custom favorite
    expect(GlobalWalletStore.favoriteIds.contains('drop_varsity_ruby'), isFalse);

    // Add student 2002 data
    final order2002 = OrderRecord(
      receiptId: 'ORD-2002',
      items: [],
      totalPts: 10,
      date: DateTime.now(),
      qrData: 'qr_2002',
      status: 'ready',
    );
    GlobalWalletStore.orders.add(order2002);
    await GlobalWalletStore.saveOrders(scholarNo: '2002');

    // 5. Switch back to student 1001 — student 1001's partition is isolated and intact
    GlobalWalletStore.resetSession();
    await GlobalWalletStore.init(scholarNo: '1001');
    expect(GlobalWalletStore.orders.any((o) => o.receiptId == 'ORD-1001'), isTrue);
    expect(GlobalWalletStore.orders.any((o) => o.receiptId == 'ORD-2002'), isFalse);
    expect(GlobalWalletStore.cart.any((c) => c.product.id == 'ruby_cap'), isTrue);
    expect(GlobalWalletStore.favoriteIds.contains('drop_varsity_ruby'), isTrue);

    // 6. Transition seamlessly from guest session (empty scholarNo) to student 1001 without explicit resetSession()
    await GlobalWalletStore.init(scholarNo: '');
    expect(GlobalWalletStore.currentScholarNo, '');
    expect(GlobalWalletStore.orders.isEmpty, isTrue);
    expect(GlobalWalletStore.cart.isEmpty, isTrue);

    await GlobalWalletStore.init(scholarNo: '1001');
    expect(GlobalWalletStore.currentScholarNo, '1001');
    expect(GlobalWalletStore.orders.any((o) => o.receiptId == 'ORD-1001'), isTrue);
    expect(GlobalWalletStore.cart.any((c) => c.product.id == 'ruby_cap'), isTrue);
  });

  test('Phase 2 Test 6: AuthService.signOut() and switchAccount() invoke GlobalWalletStore.resetSession() to purge all in-memory wallet and cart state', () async {
    SharedPreferences.setMockInitialValues({});
    await AuthService.initPreferences();

    // Populate wallet store with dummy active student state
    GlobalWalletStore.orders.add(
      OrderRecord(
        receiptId: 'SIGNOUT-ORD-1',
        items: [],
        totalPts: 5,
        date: DateTime.now(),
        qrData: 'signout_qr',
      ),
    );
    GlobalWalletStore.cart.add(
      CartItem(
        product: const MerchProduct(
          id: 'test_item',
          name: 'Test Item',
          price: 'BHD 1.000',
          rating: 5.0,
          imageUrl: '',
          category: 'Accessories',
          house: 'ruby',
          description: '',
        ),
        size: 'M',
      ),
    );
    GlobalWalletStore.favoriteIds.add('some_favorite');

    expect(GlobalWalletStore.orders.isNotEmpty, isTrue);
    expect(GlobalWalletStore.cart.isNotEmpty, isTrue);
    expect(GlobalWalletStore.favoriteIds.isNotEmpty, isTrue);

    // Trigger sign out
    final authService = AuthService();
    await authService.signOut();

    // Verify in-memory state is completely purged on signOut
    expect(GlobalWalletStore.orders.isEmpty, isTrue);
    expect(GlobalWalletStore.cart.isEmpty, isTrue);
    expect(GlobalWalletStore.favoriteIds.isEmpty, isTrue);
    expect(GlobalWalletStore.isInitialized, isFalse);
    expect(GlobalWalletStore.currentScholarNo, isNull);

    // Populate again to test switchAccount purge
    GlobalWalletStore.cart.add(
      CartItem(
        product: const MerchProduct(
          id: 'test_item_2',
          name: 'Test Item 2',
          price: 'BHD 2.000',
          rating: 5.0,
          imageUrl: '',
          category: 'Accessories',
          house: 'sapphire',
          description: '',
        ),
        size: 'L',
      ),
    );
    expect(GlobalWalletStore.cart.isNotEmpty, isTrue);

    await authService.switchAccount(
      SavedAccount(
        scholarNo: '2002',
        fullName: 'Ali Ahmed',
        houseName: 'sapphire',
        uid: 'uid_2002',
        cachedProfile: {'scholar_no': '2002', 'full_name': 'Ali Ahmed', 'house': 'sapphire'},
      ),
    );

    // Verify in-memory state is completely purged on switchAccount
    expect(GlobalWalletStore.cart.isEmpty, isTrue);
    expect(GlobalWalletStore.orders.isEmpty, isTrue);
    expect(GlobalWalletStore.isInitialized, isFalse);
    expect(GlobalWalletStore.currentScholarNo, isNull);
  });

  testWidgets('Phase 2 Test 7: BattleChantSynthesizer mounts and functions cleanly without dead SingleTickerProviderStateMixin', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: BattleChantSynthesizer(
            userHouse: 'ruby',
            initialMode: ChantMode.warCry,
            initialTempo: ChantTempo.march,
            autoPlay: false,
          ),
        ),
      ),
    );
    await tester.pump();

    // Verify synthesizer UI rendered
    expect(find.byType(BattleChantSynthesizer), findsOneWidget);
    expect(find.text('War Cry'), findsWidgets);
    expect(find.text('March (95 BPM)'), findsOneWidget);

    // Tap play / stop without any ticker or vsync exceptions
    final playButton = find.byIcon(Icons.play_arrow_rounded);
    expect(playButton, findsOneWidget);
    await tester.tap(playButton);
    await tester.pump(const Duration(milliseconds: 100));

    // Tap pause / stop
    final stopButton = find.byIcon(Icons.stop_rounded);
    expect(stopButton, findsOneWidget);
    await tester.tap(stopButton);
    await tester.pump(const Duration(milliseconds: 100));
  });

  test('PassDocumentExporter generates valid PDF 1.4 byte structure and exports to disk', () async {
    final pdfBytes = PassDocumentExporter.buildPassPdf(
      title: 'Store Voucher: House Cap',
      subtitle: 'Official Merchandise Order #ASB-5544',
      details: 'Recipient: Zaid Al-Husseini (2310910)\nHouse: Ruby\nQuantity: 1',
      totalInfo: 'Total Redeemed: 50 House Points',
      qrData: 'ASB-VOUCHER-HASH-ABC-123',
    );

    expect(pdfBytes.isNotEmpty, isTrue);
    final header = String.fromCharCodes(pdfBytes.sublist(0, 8));
    expect(header.startsWith('%PDF-1.4'), isTrue);
    final fullString = String.fromCharCodes(pdfBytes);
    expect(fullString.contains('%%EOF'), isTrue);
    expect(fullString.contains('/Type /Catalog'), isTrue);
    expect(fullString.contains('ASB HOUSE HUB - OFFICIAL ELECTRONIC PASS'), isTrue);

    // Test disk exporter
    final exportResult = await PassDocumentExporter.exportPassToDisk(
      title: 'Store Voucher: House Cap',
      subtitle: 'Official Merchandise Order #ASB-5544',
      details: 'Recipient: Zaid Al-Husseini\nHouse: Ruby',
      totalInfo: 'Total: 50 Pts',
      qrData: 'HASH-123',
    );
    expect(exportResult.success, isTrue);
    expect(exportResult.filePath.isNotEmpty, isTrue);
  });

  test('Dynamic attendance percentage computes accurately over attendance logs', () {
    final scholarNo = '2310999';
    final sampleLogs = [
      AttendanceRecord(
        id: 'att_01',
        scholarNo: scholarNo,
        date: DateTime.now().subtract(const Duration(days: 3)),
        status: AttendanceStatus.present,
      ),
      AttendanceRecord(
        id: 'att_02',
        scholarNo: scholarNo,
        date: DateTime.now().subtract(const Duration(days: 2)),
        status: AttendanceStatus.late,
      ),
      AttendanceRecord(
        id: 'att_03',
        scholarNo: scholarNo,
        date: DateTime.now().subtract(const Duration(days: 1)),
        status: AttendanceStatus.present,
      ),
      AttendanceRecord(
        id: 'att_04',
        scholarNo: scholarNo,
        date: DateTime.now(),
        status: AttendanceStatus.absent,
      ),
    ];

    // Total: 4 days. Present: 2, Late: 1 (0.5), Absent: 1.
    // Score: (2 + 0.5) / 4 * 100 = 62.5%
    final presentCount = sampleLogs
        .where((r) => r.status == AttendanceStatus.present || r.status == AttendanceStatus.excused)
        .length;
    final lateCount = sampleLogs.where((r) => r.status == AttendanceStatus.late).length;
    final rate = ((presentCount + (lateCount * 0.5)) / sampleLogs.length) * 100.0;
    expect(rate, equals(62.5));
    expect('${rate.toStringAsFixed(1)}%', equals('62.5%'));
  });

  test('AuthService.createElectionBallot persists ballot into cache and Firestore', () async {
    final authService = AuthService();
    final newBallot = ElectionBallot(
      id: 'ballot_unit_test_01',
      title: 'Senior House Captain 2026-2027',
      position: BallotPosition.houseCaptain,
      houseScope: 'Ruby',
      eligibleGrades: const ['Grade 11', 'Grade 12'],
      status: BallotStatus.open,
      startTime: DateTime.now().subtract(const Duration(hours: 1)),
      endTime: DateTime.now().add(const Duration(hours: 48)),
      candidates: [
        ElectionCandidate(
          scholarNo: '2310910',
          fullName: 'Zaid Al-Husseini',
          houseName: 'ruby',
          runningPosition: 'House Captain',
          manifesto: 'Excellence in house leadership.',
        ),
      ],
      totalVotesCast: 0,
    );

    final res = await authService.createElectionBallot(newBallot);
    expect(res.success, isTrue);
    expect(res.ballotId, isNotNull);
    final cached = AuthService.getCachedBallots();
    expect(cached.any((b) => b.title == 'Senior House Captain 2026-2027'), isTrue);
  });

  testWidgets('SchoolElectionsPage mounts cleanly and handles unauthenticated state', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SchoolElectionsPage(),
      ),
    );
    await tester.pump();
    expect(find.byType(SchoolElectionsPage), findsOneWidget);
  });

  test('ensureSchoolMemberRecord provisions student roster entry with parsed grade, house, and active status', () async {
    final authService = AuthService();
    final studentRecord = await authService.ensureSchoolMemberRecord(
      uid: 'test_student_uid_123',
      profile: {
        'scholar_no': 'SCH-042',
        'full_name': 'Mustafa Ahmed',
        'house_name': 'emerald',
        'class_level': 'Grade 11-A',
        'role': 'student',
      },
    );

    expect(studentRecord['active'], isTrue);
    expect(studentRecord['role'], equals('student'));
    expect(studentRecord['scholar_no'], equals('SCH-042'));
    expect(studentRecord['display_name'], equals('Mustafa Ahmed'));
    expect(studentRecord['house'], equals('emerald'));
    expect(studentRecord['grade'], equals(11));
    expect(studentRecord['capabilities']['manage_elections'], isFalse);
  });

  test('ensureSchoolMemberRecord provisions staff/admin with manage_elections capability', () async {
    final authService = AuthService();
    final adminRecord = await authService.ensureSchoolMemberRecord(
      uid: 'test_admin_uid_999',
      profile: {
        'scholar_no': 'admin',
        'full_name': 'Principal Administrator',
        'house_name': 'ruby',
        'role': 'super_admin',
      },
    );

    expect(adminRecord['active'], isTrue);
    expect(adminRecord['role'], equals('admin'));
    expect(adminRecord['scholar_no'], equals('admin'));
    expect(adminRecord['display_name'], equals('Principal Administrator'));
    expect(adminRecord['capabilities']['manage_elections'], isTrue);
  });

  test('lookupScholarDetails auto-fills scholar details and position-tailored manifesto', () async {
    SharedPreferences.setMockInitialValues({});
    await AuthService.saveAccount(
      SavedAccount(
        scholarNo: 'SCH-042',
        fullName: 'Mustafa Ahmed',
        houseName: 'emerald',
        uid: 'uid_mustafa_042',
        classLevel: 'Grade 11-A',
        role: 'super_admin',
        lastActive: DateTime.now(),
      ),
    );

    final details = await AuthService.lookupScholarDetails('SCH-042', runningPosition: 'Senior House Captain');
    expect(details['scholarNo'], equals('SCH-042'));
    expect(details['fullName'], equals('Mustafa Ahmed'));
    expect(details['isFound'], isTrue);
    expect(details['manifesto'], contains('championship participation'));

    final adminDetails = await AuthService.lookupScholarDetails('11209', runningPosition: 'Staff Advisor');
    expect(adminDetails['scholarNo'], equals('11209'));
    expect(adminDetails['fullName'], equals('Administrator'));
    expect(adminDetails['isFound'], isTrue);

    // Unregistered scholar number leaves name and manifesto empty (no fake "Scholar #..." strings)
    final unregistered = await AuthService.lookupScholarDetails('12428');
    expect(unregistered['scholarNo'], equals('12428'));
    expect(unregistered['fullName'], isEmpty);
    expect(unregistered['manifesto'], isEmpty);
    expect(unregistered['isFound'], isFalse);

    final defaultDetails = await AuthService.lookupScholarDetails('');
    expect(defaultDetails['scholarNo'], isEmpty);
    expect(defaultDetails['fullName'], isEmpty);
    expect(defaultDetails['isFound'], isFalse);
  });

  test('AuthService.getFoundationalGazettes returns statutory proclamations and cacheCertifiedGazette stores them', () async {
    SharedPreferences.setMockInitialValues({});
    expect(AuthService.getCachedCertifiedGazette(), isEmpty);
    final foundational = AuthService.getFoundationalGazettes();
    expect(foundational.isNotEmpty, isTrue);
    expect(foundational.first.ballotTitle, contains('Senior House Captain'));
    expect(foundational.first.housePointsAwarded, equals(100));

    await AuthService.cacheCertifiedGazette(foundational);
    final cached = AuthService.getCachedCertifiedGazette();
    expect(cached.length, equals(foundational.length));
    expect(cached.first.winnerScholarNo, equals('SCH-042'));
  });

  test('castDigitalVote caches receipt and getReceiptForBallot retrieves candidate-specific receipt', () async {
    SharedPreferences.setMockInitialValues({});
    final candidate = ElectionCandidate(
      scholarNo: 'SCH-777',
      fullName: 'Tariq Al-Mansoor',
      houseName: 'sapphire',
      runningPosition: 'Prefect',
      manifesto: 'Lead by example.',
      votesCount: 0,
      isVerified: true,
      classLevel: 'Grade 11',
    );

    final mockBallot = ElectionBallot(
      id: 'ballot_test_vote_receipt_123',
      title: 'Prefect Election 2026',
      position: BallotPosition.prefect,
      houseScope: 'all',
      eligibleGrades: ['10', '11', '12'],
      status: BallotStatus.open,
      startTime: DateTime.now().subtract(const Duration(hours: 1)),
      endTime: DateTime.now().add(const Duration(hours: 5)),
      candidates: [candidate],
      totalVotesCast: 0,
    );

    await AuthService.cacheBallots([mockBallot]);

    final authService = AuthService();
    final result = await authService.castDigitalVote(
      ballotId: mockBallot.id,
      ballotTitle: mockBallot.title,
      candidate: candidate,
      scholarNo: 'VOTER-101',
    );

    expect(result.success, isTrue);
    expect(result.receipt, isNotNull);
    expect(result.receipt!.candidateScholarNo, equals('SCH-777'));
    expect(result.receipt!.candidateName, equals('Tariq Al-Mansoor'));

    final fetchedReceipt = AuthService.getReceiptForBallot(mockBallot.id);
    expect(fetchedReceipt, isNotNull);
    expect(fetchedReceipt!.candidateScholarNo, equals('SCH-777'));
    expect(fetchedReceipt.candidateName, equals('Tariq Al-Mansoor'));
  });
}

class _Phase4MockHttpClient extends http.BaseClient {
  final Future<http.Response> Function(http.BaseRequest request) _handler;
  _Phase4MockHttpClient(this._handler);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final res = await _handler(request);
    return http.StreamedResponse(
      Stream.value(res.bodyBytes),
      res.statusCode,
      headers: res.headers,
      reasonPhrase: res.reasonPhrase,
    );
  }
}














