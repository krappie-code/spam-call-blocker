import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/database_service.dart';
import 'services/contacts_service.dart' as app_contacts;
import 'services/challenge_service.dart';
import 'services/call_screening_service.dart';
import 'ui/home_screen.dart';
import 'ui/onboarding_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final db = DatabaseService();
  await db.init();

  final contacts = app_contacts.ContactsService(db);
  final challenge = ChallengeService();
  final screening = CallScreeningService(db, challenge, contacts);
  screening.init();

  final prefs = await SharedPreferences.getInstance();
  final onboardingComplete = prefs.getBool('onboarding_complete') ?? false;

  runApp(
    MultiProvider(
      providers: [
        Provider<DatabaseService>.value(value: db),
        Provider<app_contacts.ContactsService>.value(value: contacts),
        Provider<CallScreeningService>.value(value: screening),
      ],
      child: SpamCallBlockerApp(showOnboarding: !onboardingComplete),
    ),
  );
}

class SpamCallBlockerApp extends StatelessWidget {
  final bool showOnboarding;

  const SpamCallBlockerApp({super.key, required this.showOnboarding});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Spam Call Blocker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.deepPurple,
        useMaterial3: true,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.deepPurple,
        useMaterial3: true,
        brightness: Brightness.dark,
      ),
      themeMode: ThemeMode.system,
      home: showOnboarding ? const OnboardingScreen() : const HomeScreen(),
    );
  }
}
