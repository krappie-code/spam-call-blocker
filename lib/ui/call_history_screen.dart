import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/database_service.dart';
import '../models/call_log.dart';
import '../models/block_list.dart';

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
      case CallResult.challengePassed:
        return Colors.orange;
      case CallResult.challengeFailed:
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

  Future<void> _markSpam(CallLogEntry entry, bool isSpam) async {
    final db = context.read<DatabaseService>();
    await db.updateCallLogSpamStatus(entry.id!, isSpam);
    if (isSpam) {
      await db.addToBlockList(BlockListEntry(phoneNumber: entry.phoneNumber, label: 'Marked as spam'));
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
                                    icon: const Icon(Icons.thumb_down,
                                        size: 20),
                                    tooltip: 'Mark as spam',
                                    onPressed: () => _markSpam(log, true),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.thumb_up,
                                        size: 20),
                                    tooltip: 'Not spam',
                                    onPressed: () => _markSpam(log, false),
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
