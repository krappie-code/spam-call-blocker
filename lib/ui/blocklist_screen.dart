import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/call_screening_service.dart';
import '../services/database_service.dart';
import '../models/block_list.dart';

class BlocklistScreen extends StatefulWidget {
  const BlocklistScreen({super.key});

  @override
  State<BlocklistScreen> createState() => _BlocklistScreenState();
}

class _BlocklistScreenState extends State<BlocklistScreen> {
  List<BlockListEntry> _blocklist = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadBlocklist();
  }

  Future<void> _loadBlocklist() async {
    final db = context.read<DatabaseService>();
    final list = await db.getBlockList();
    if (mounted) {
      setState(() {
        _blocklist = list;
        _loading = false;
      });
    }
  }

  Future<void> _addNumber() async {
    final phoneController = TextEditingController();
    final labelController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Block a Number'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: phoneController,
              decoration: const InputDecoration(
                labelText: 'Phone number',
                hintText: '+27821234567',
                prefixIcon: Icon(Icons.phone),
              ),
              keyboardType: TextInputType.phone,
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: labelController,
              decoration: const InputDecoration(
                labelText: 'Label (optional)',
                hintText: 'e.g. Telemarketer',
                prefixIcon: Icon(Icons.label_outline),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Block'),
          ),
        ],
      ),
    );

    if (result == true && phoneController.text.trim().isNotEmpty) {
      final screening = context.read<CallScreeningService>();
      await screening.blockNumber(
        phoneController.text.trim(),
        label: labelController.text.trim().isEmpty
            ? null
            : labelController.text.trim(),
      );
      await _loadBlocklist();
    }
  }

  Future<void> _removeNumber(BlockListEntry entry) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Unblock Number'),
        content: Text(
            'Remove ${entry.phoneNumber}${entry.label != null ? " (${entry.label})" : ""} from the blocklist?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Unblock'),
          ),
        ],
      ),
    );

    if (confirm == true && entry.id != null) {
      final screening = context.read<CallScreeningService>();
      await screening.unblockNumber(entry.id!);
      await _loadBlocklist();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Blocklist'),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addNumber,
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _blocklist.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.block, size: 64,
                            color: theme.colorScheme.onSurfaceVariant
                                .withAlpha(128)),
                        const SizedBox(height: 16),
                        Text('No blocked numbers',
                            style: theme.textTheme.titleMedium),
                        const SizedBox(height: 8),
                        Text(
                          'Numbers you block will be rejected instantly — '
                          'they won\'t even hear the hold message.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Tip: You can also block numbers from your call history.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadBlocklist,
                  child: ListView.builder(
                    itemCount: _blocklist.length,
                    itemBuilder: (context, index) {
                      final entry = _blocklist[index];
                      return ListTile(
                        leading: const CircleAvatar(
                          child: Icon(Icons.block),
                        ),
                        title: Text(entry.phoneNumber),
                        subtitle: Text(
                          entry.label ?? 'Blocked ${_formatDate(entry.createdAt)}',
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _removeNumber(entry),
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
