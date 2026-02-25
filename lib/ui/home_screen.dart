import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/database_service.dart';
import '../services/call_screening_service.dart';
import '../models/call_log.dart';
import 'call_history_screen.dart';
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
  int _challengedCount = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
    // Listen for call events to auto-refresh stats
    final screening = context.read<CallScreeningService>();
    screening.onCallProcessed = (phoneNumber, result) {
      _loadStats();
    };
  }

  Future<void> _loadStats() async {
    final db = context.read<DatabaseService>();
    final logs = await db.getCallLogs(limit: 1000);
    int blocked = 0, allowed = 0, challenged = 0;
    for (final log in logs) {
      switch (log.result) {
        case CallResult.blocked:
          blocked++;
          break;
        case CallResult.allowed:
          allowed++;
          break;
        case CallResult.challengePassed:
        case CallResult.challengeFailed:
          challenged++;
          break;
      }
    }
    if (mounted) {
      setState(() {
        _blockedCount = blocked;
        _allowedCount = allowed;
        _challengedCount = challenged;
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
              onRefresh: _loadStats,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Icon(Icons.shield,
                              size: 64, color: theme.colorScheme.primary),
                          const SizedBox(height: 12),
                          Text('Protection Active',
                              style: theme.textTheme.headlineSmall),
                          const SizedBox(height: 4),
                          Text(
                            'Challenge-response screening enabled',
                            style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant),
                          ),
                        ],
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
                        label: 'Challenged',
                        count: _challengedCount,
                        icon: Icons.help_outline,
                        color: Colors.orange,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline,
                              color: theme.colorScheme.primary),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Calls from your contacts are automatically allowed. Unknown callers are challenged.',
                              style: theme.textTheme.bodyMedium,
                            ),
                          ),
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
