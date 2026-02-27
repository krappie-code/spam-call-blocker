import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'home_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _step = 0; // 0 = welcome, 1 = permissions, 2 = screening role
  bool _permissionsGranted = false;
  // ignore: unused_field
  bool _roleGranted = false;
  String _permissionStatus = '';

  static const _screeningChannel =
      MethodChannel('com.spamcallblocker.app/screening');

  final _requiredPermissions = [
    Permission.phone,
    Permission.contacts,
  ];

  Future<void> _requestPermissions() async {
    setState(() => _permissionStatus = 'Requesting permissions...');

    final statuses = await _requiredPermissions.request();

    final allGranted = statuses.values.every((s) => s.isGranted);

    if (allGranted) {
      setState(() {
        _permissionsGranted = true;
        _permissionStatus = 'All permissions granted!';
        _step = 2;
      });
    } else {
      final denied = <String>[];
      statuses.forEach((perm, status) {
        if (!status.isGranted) {
          if (perm == Permission.phone) denied.add('Phone');
          if (perm == Permission.contacts) denied.add('Contacts');
        }
      });
      setState(() {
        _permissionStatus =
            'Missing: ${denied.join(", ")}. Tap to retry or open settings.';
      });
    }
  }

  Future<void> _requestScreeningRole() async {
    try {
      final result =
          await _screeningChannel.invokeMethod<bool>('requestScreeningRole');
      if (result == true) {
        setState(() => _roleGranted = true);
        await _finishOnboarding();
      } else {
        // On Android < 10, role isn't available - just proceed
        await _finishOnboarding();
      }
    } on PlatformException {
      // Screening role not available, proceed anyway
      await _finishOnboarding();
    }
  }

  Future<void> _finishOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_complete', true);
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
              if (_step == 0) ...[
                Icon(Icons.shield, size: 96, color: theme.colorScheme.primary),
                const SizedBox(height: 24),
                Text('Spam Call Blocker',
                    style: theme.textTheme.headlineMedium),
                const SizedBox(height: 12),
                Text(
                  'Protect yourself from spam calls with challenge-response screening. '
                  'Unknown callers must press a digit to reach you.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 32),
                FilledButton.icon(
                  onPressed: () => setState(() => _step = 1),
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text('Get Started'),
                ),
              ] else if (_step == 1) ...[
                Icon(Icons.security, size: 96, color: theme.colorScheme.primary),
                const SizedBox(height: 24),
                Text('Permissions Required',
                    style: theme.textTheme.headlineMedium),
                const SizedBox(height: 12),
                Text(
                  'We need the following permissions to screen calls and check your contacts:',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 24),
                _PermissionTile(
                  icon: Icons.phone,
                  title: 'Phone',
                  subtitle: 'Read phone state, manage calls',
                ),
                _PermissionTile(
                  icon: Icons.contacts,
                  title: 'Contacts',
                  subtitle: 'Check if callers are in your contacts',
                ),
                if (_permissionStatus.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(_permissionStatus,
                      style: theme.textTheme.bodyMedium?.copyWith(
                          color: _permissionsGranted
                              ? Colors.green
                              : Colors.orange)),
                ],
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _requestPermissions,
                  icon: const Icon(Icons.check),
                  label: const Text('Grant Permissions'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => openAppSettings(),
                  child: const Text('Open App Settings'),
                ),
              ] else if (_step == 2) ...[
                Icon(Icons.phone_callback,
                    size: 96, color: theme.colorScheme.primary),
                const SizedBox(height: 24),
                Text('Call Screening',
                    style: theme.textTheme.headlineMedium),
                const SizedBox(height: 12),
                Text(
                  'Set this app as your default call screening service to automatically '
                  'screen unknown callers.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 32),
                FilledButton.icon(
                  onPressed: _requestScreeningRole,
                  icon: const Icon(Icons.verified_user),
                  label: const Text('Enable Call Screening'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _finishOnboarding,
                  child: const Text('Skip for Now'),
                ),
              ],
              const Spacer(),
              // Step indicator
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(3, (i) {
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: _step == i ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _step == i
                          ? theme.colorScheme.primary
                          : theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _PermissionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _PermissionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(title),
      subtitle: Text(subtitle),
      dense: true,
    );
  }
}
