import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/database_service.dart';
import '../services/call_screening_service.dart';
import '../models/call_log.dart';
import 'call_history_screen.dart';
import 'blocklist_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      const _DashboardPage(),
      const CallHistoryScreen(),
      const BlocklistScreen(),
      const SettingsScreen(),
    ];

    return Scaffold(
      body: pages[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (i) => setState(() => _selectedIndex = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.shield_outlined),
            selectedIcon: Icon(Icons.shield),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: 'History',
          ),
          NavigationDestination(
            icon: Icon(Icons.block_outlined),
            selectedIcon: Icon(Icons.block),
            label: 'Blocklist',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

class _DashboardPage extends StatefulWidget {
  const _DashboardPage();

  @override
  State<_DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<_DashboardPage> {
  int _blockedCount = 0;
  int _allowedCount = 0;
  int _screenedCount = 0;
  bool _loading = true;
  bool _protectionEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadAll();
    final screening = context.read<CallScreeningService>();
    screening.onCallProcessed = (phoneNumber, result) {
      _loadStats();
    };
  }

  Future<void> _loadAll() async {
    await _loadProtectionState();
    await _loadStats();
  }

  Future<void> _loadProtectionState() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _protectionEnabled = prefs.getBool('protection_enabled') ?? true;
      });
    }
  }

  Future<void> _toggleProtection() async {
    final newState = !_protectionEnabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('protection_enabled', newState);

    // Also sync to native SharedPreferences via method channel
    final screening = context.read<CallScreeningService>();
    await screening.setProtectionEnabled(newState);

    if (mounted) {
      setState(() {
        _protectionEnabled = newState;
      });
    }
  }

  Future<void> _loadStats() async {
    final db = context.read<DatabaseService>();
    final logs = await db.getCallLogs(limit: 1000);
    int blocked = 0, allowed = 0, screened = 0;
    for (final log in logs) {
      switch (log.result) {
        case CallResult.blocked:
          blocked++;
          break;
        case CallResult.allowed:
          allowed++;
          break;
        case CallResult.challengePassed:
          screened++;
          break;
        case CallResult.challengeFailed:
          blocked++;
          break;
      }
    }
    if (mounted) {
      setState(() {
        _blockedCount = blocked;
        _allowedCount = allowed;
        _screenedCount = screened;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Spam Call Blocker'),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadAll,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Protection toggle card
                  Card(
                    color: _protectionEnabled
                        ? theme.colorScheme.primaryContainer
                        : theme.colorScheme.errorContainer,
                    child: InkWell(
                      onTap: _toggleProtection,
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            Icon(
                              _protectionEnabled
                                  ? Icons.shield
                                  : Icons.shield_outlined,
                              size: 64,
                              color: _protectionEnabled
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.error,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _protectionEnabled
                                  ? 'Protection Active'
                                  : 'Protection Disabled',
                              style: theme.textTheme.headlineSmall?.copyWith(
                                color: _protectionEnabled
                                    ? theme.colorScheme.onPrimaryContainer
                                    : theme.colorScheme.onErrorContainer,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Switch(
                              value: _protectionEnabled,
                              onChanged: (_) => _toggleProtection(),
                              activeColor: theme.colorScheme.primary,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _protectionEnabled
                                  ? 'Tap to disable call screening'
                                  : 'Tap to enable call screening',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: _protectionEnabled
                                    ? theme.colorScheme.onPrimaryContainer
                                        .withAlpha(180)
                                    : theme.colorScheme.onErrorContainer
                                        .withAlpha(180),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _StatCard(
                        label: 'Blocked',
                        count: _blockedCount,
                        icon: Icons.block,
                        color: Colors.red,
                      ),
                      const SizedBox(width: 8),
                      _StatCard(
                        label: 'Allowed',
                        count: _allowedCount,
                        icon: Icons.check_circle,
                        color: Colors.green,
                      ),
                      const SizedBox(width: 8),
                      _StatCard(
                        label: 'Screened',
                        count: _screenedCount,
                        icon: Icons.verified_user,
                        color: Colors.orange,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.info_outline,
                                  color: theme.colorScheme.primary),
                              const SizedBox(width: 12),
                              Text('How it works',
                                  style: theme.textTheme.titleSmall),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Text(
                              '• Contacts ring through normally\n'
                              '• Blocklisted numbers are rejected instantly\n'
                              '• Unknown callers are silenced (no ring)\n'
                              '• Review missed calls in History → approve or block'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final int count;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.count,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          child: Column(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 8),
              Text('$count',
                  style: Theme.of(context).textTheme.headlineMedium),
              Text(label, style: Theme.of(context).textTheme.labelSmall),
            ],
          ),
        ),
      ),
    );
  }
}
