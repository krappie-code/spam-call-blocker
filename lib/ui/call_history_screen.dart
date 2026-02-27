import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/database_service.dart';
import '../services/call_screening_service.dart';
import '../models/call_log.dart';

class CallHistoryScreen extends StatefulWidget {
  const CallHistoryScreen({super.key});

  @override
  State<CallHistoryScreen> createState() => _CallHistoryScreenState();
}

class _CallHistoryScreenState extends State<CallHistoryScreen> {
  List<CallLogEntry> _logs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = context.read<DatabaseService>();
    final logs = await db.getCallLogs();
    if (mounted) setState(() { _logs = logs; _loading = false; });
  }

  Color _resultColor(CallResult r) {
    switch (r) {
      case CallResult.allowed:
        return Colors.green;
      case CallResult.blocked:
        return Colors.red;
      case CallResult.challengePassed: // screened & connected
        return Colors.orange;
      case CallResult.challengeFailed: // hung up during screening
        return Colors.red.shade300;
    }
  }

  IconData _resultIcon(CallResult r) {
    switch (r) {
      case CallResult.allowed:
        return Icons.check_circle;
      case CallResult.blocked:
        return Icons.block;
      case CallResult.challengePassed:
        return Icons.verified;
      case CallResult.challengeFailed:
        return Icons.cancel;
    }
  }

  Future<void> _markSpam(CallLogEntry entry) async {
    final db = context.read<DatabaseService>();
    await db.updateCallLogSpamStatus(entry.id!, true);
    final screening = context.read<CallScreeningService>();
    await screening.blockNumber(entry.phoneNumber, label: 'Marked as spam');
    await _load();
  }

  Future<void> _approve(CallLogEntry entry) async {
    final db = context.read<DatabaseService>();
    await db.updateCallLogSpamStatus(entry.id!, false);
    final screening = context.read<CallScreeningService>();
    await screening.whitelistNumber(entry.phoneNumber, label: 'Approved from history');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${entry.phoneNumber} will ring through next time')),
      );
    }
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Call History')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _logs.isEmpty
              ? const Center(child: Text('No call history yet.'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    itemCount: _logs.length,
                    itemBuilder: (ctx, i) {
                      final log = _logs[i];
                      final fmt = DateFormat('MMM d, HH:mm');
                      return ListTile(
                        leading: Icon(_resultIcon(log.result),
                            color: _resultColor(log.result)),
                        title: Text(log.phoneNumber),
                        subtitle: Text(
                            '${log.result.name} • ${fmt.format(log.timestamp)}'),
                        trailing: log.markedAsSpam == null
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.block,
                                        size: 20, color: Colors.red),
                                    tooltip: 'Block this number',
                                    onPressed: () => _markSpam(log),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.check_circle,
                                        size: 20, color: Colors.green),
                                    tooltip: 'Allow future calls',
                                    onPressed: () => _approve(log),
                                  ),
                                ],
                              )
                            : Icon(
                                log.markedAsSpam!
                                    ? Icons.report
                                    : Icons.verified_user,
                                color: log.markedAsSpam!
                                    ? Colors.red
                                    : Colors.green,
                              ),
                      );
                    },
                  ),
                ),
    );
  }
}
