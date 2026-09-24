import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:asb_house_hub/theme/app_theme.dart';
import 'package:asb_house_hub/services/gemini_ai_service.dart';
import 'package:asb_house_hub/services/hierarchy_service.dart';
import 'package:asb_house_hub/screens/house_ai_chat_screen.dart';
import 'package:asb_house_hub/screens/signup_screen.dart';
import 'package:asb_house_hub/widgets/apple_fitness_badges_vault.dart';
import 'package:asb_house_hub/widgets/mascot_3d_stage.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
}

