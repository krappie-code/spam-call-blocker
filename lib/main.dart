import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/database_service.dart';
import 'services/contacts_service.dart' as app_contacts;
import 'ui/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final db = DatabaseService();
  await db.init();

  runApp(
    MultiProvider(
      providers: [
        Provider<DatabaseService>.value(value: db),
        Provider<app_contacts.ContactsService>(
          create: (_) => app_contacts.ContactsService(db),
        ),
      ],
      child: const SpamCallBlockerApp(),
    ),
  );
}

class SpamCallBlockerApp extends StatelessWidget {
  const SpamCallBlockerApp({super.key});

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
      home: const HomeScreen(),
    );
  }
}
