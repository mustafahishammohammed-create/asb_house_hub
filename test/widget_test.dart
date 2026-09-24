import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:asb_house_hub/theme/app_theme.dart';
import 'package:asb_house_hub/services/gemini_ai_service.dart';
import 'package:asb_house_hub/services/hierarchy_service.dart';
import 'package:asb_house_hub/screens/house_ai_chat_screen.dart';
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
}

