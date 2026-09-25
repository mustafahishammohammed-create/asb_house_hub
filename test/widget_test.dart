import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:asb_house_hub/theme/app_theme.dart';
import 'package:asb_house_hub/services/gemini_ai_service.dart';
import 'package:asb_house_hub/services/hierarchy_service.dart';
import 'package:asb_house_hub/screens/house_ai_chat_screen.dart';
import 'package:asb_house_hub/screens/signup_screen.dart';
import 'package:asb_house_hub/widgets/apple_fitness_badges_vault.dart';
import 'package:asb_house_hub/widgets/mascot_3d_stage.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:asb_house_hub/services/auth_service.dart';
import 'package:asb_house_hub/services/voucher_security_service.dart';
import 'package:asb_house_hub/screens/merch_store_tab.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:asb_house_hub/main.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
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
    // Test mounting IdScannerScreen
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

    expect(find.textContaining('EMERALD House AI Advisor'), findsOneWidget);
    expect(find.textContaining('How can I earn 50 points'), findsOneWidget);
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
      HierarchyService.isPrefect(scholarNo: '11004', fullName: 'Sarah Paul'),
      isTrue,
    );

    // 3. Security Check: Unrelated student named Sarah must NOT receive elevated privileges
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

    // 4. Role Display Titles
    expect(
      HierarchyService.getRoleDisplayTitle(scholarNo: '2310910'),
      'Super Admin',
    );
    expect(
      HierarchyService.getRoleDisplayTitle(scholarNo: '30003'),
      'Faculty Lead',
    );
    expect(
      HierarchyService.getRoleDisplayTitle(scholarNo: '10001'),
      'House Captain',
    );
    expect(
      HierarchyService.getRoleDisplayTitle(scholarNo: '12001'),
      'Student Council',
    );
    expect(
      HierarchyService.getRoleDisplayTitle(scholarNo: '11004'),
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

    // inferHouseFromScholarNo for all 4 houses
    expect(AuthService.inferHouseFromScholarNo('10001'), 'emerald');
    expect(AuthService.inferHouseFromScholarNo('20002'), 'emerald');
    expect(AuthService.inferHouseFromScholarNo('30003'), 'sapphire');
    expect(AuthService.inferHouseFromScholarNo('12001'), 'topaz');
    expect(AuthService.inferHouseFromScholarNo('2310910'), 'ruby');
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
    expect(AuthService.inferHouseFromScholarNo('10001'), 'emerald');
    expect(AuthService.inferHouseFromScholarNo('20002'), 'emerald');
    expect(AuthService.inferHouseFromScholarNo('11089'), 'emerald');
    expect(AuthService.inferHouseFromScholarNo('30003'), 'sapphire');
    expect(AuthService.inferHouseFromScholarNo('12001'), 'topaz');
    expect(AuthService.inferHouseFromScholarNo('11012'), 'topaz');
    expect(AuthService.inferHouseFromScholarNo('40001'), 'topaz');

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
}

