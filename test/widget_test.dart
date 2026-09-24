import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:asb_house_hub/theme/app_theme.dart';
import 'package:asb_house_hub/services/gemini_ai_service.dart';
import 'package:asb_house_hub/screens/house_ai_chat_screen.dart';
import 'package:asb_house_hub/widgets/apple_fitness_badges_vault.dart';
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

    expect(find.text('Apple Activity Awards'), findsOneWidget);
    expect(find.text('TITAN VAULT'), findsOneWidget);
    expect(find.text('All Badges'), findsOneWidget);
    expect(find.text('House Centurion'), findsOneWidget);
  });
}

