import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'theme/app_theme.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'l10n/app_localizations.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await AuthService.initPreferences();
    await AppThemeController.init();
  } catch (e) {
    debugPrint('Initialization preferences warning: $e');
  }

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // On Windows desktop, LevelDB disk locks cause fatal C++ assertions (FirestoreInternalError)
    // if previous instances were killed or restarted quickly.
    // We configure a high-performance in-memory cache bounded to 100 MB without disk locking.
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
      try {
        FirebaseFirestore.instance.settings = const Settings(
          persistenceEnabled: false,
          cacheSizeBytes: 100 * 1024 * 1024, // 100 MB bounded cache
        );
      } catch (e) {
        debugPrint('Firestore settings warning: $e');
      }
    }
  } catch (e) {
    debugPrint('Firebase initialization warning: $e');
  }

  runApp(const ASBHouseHubApp());
}

class ASBHouseHubApp extends StatelessWidget {
  const ASBHouseHubApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppThemeController.themeModeNotifier,
      builder: (context, currentMode, _) {
        return MaterialApp(
          title: 'ASB House Hub',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: currentMode,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const AuthGate(),
        );
      },
    );
  }
}

class AuthGate extends StatelessWidget {
  final Stream<User?>? authStateStream;
  const AuthGate({super.key, this.authStateStream});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: authStateStream ?? AuthService().authStateChanges,
      builder: (context, snapshot) {
        final hasCompletedOnboarding = AuthService.hasCompletedOnboarding();

        // 1. Loading / Waiting state guard
        if (snapshot.connectionState == ConnectionState.waiting) {
          final currentUser = AuthService().currentUser;
          final cachedProfile = AuthService.getCachedProfile();
          final cachedHouse = AuthService.getCachedHouse();
          if (currentUser == null && cachedProfile == null && cachedHouse == null) {
            return hasCompletedOnboarding ? const LoginScreen() : const OnboardingScreen();
          }
          if (currentUser != null) {
            return HomeScreen(key: ValueKey('home_${currentUser.uid}'));
          }

          // Render glowing mascot shield during disk cache / auth pre-hydration
          final house = cachedHouse ?? 'emerald';
          final houseColor = HouseColors.getHouseColor(house);
          final houseDark = HouseColors.getHouseDarkColor(house);
          final houseGlow = HouseColors.getHouseGlowColor(house);
          final houseEmoji = HouseColors.getHouseEmoji(house);

          return Scaffold(
            backgroundColor: Theme.of(context).colorScheme.surface,
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [houseColor, houseDark],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: houseGlow.withValues(alpha: 0.45),
                          blurRadius: 28,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        const Icon(
                          Icons.shield_rounded,
                          color: Colors.white,
                          size: 42,
                        ),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Text(
                            houseEmoji,
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Semantics(
                    container: true,
                    liveRegion: true,
                    label:
                        'Authenticating ASB House Hub session, please wait...',
                    child: SizedBox(
                      width: 140,
                      height: 4,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          backgroundColor: houseColor.withValues(alpha: 0.15),
                          valueColor:
                              AlwaysStoppedAnimation<Color>(houseGlow),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        // 2. Error state
        if (snapshot.hasError) {
          return hasCompletedOnboarding ? const LoginScreen() : const OnboardingScreen();
        }

        // 3. User is actively authenticated
        final user = snapshot.data;
        if (user != null) {
          return HomeScreen(key: ValueKey('home_${user.uid}'));
        }

        // 4. User is signed out (snapshot.data == null)
        if (!hasCompletedOnboarding) {
          return const OnboardingScreen();
        }
        return const LoginScreen();
      },
    );
  }
}


