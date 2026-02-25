import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../services/database_service.dart';
import '../models/settings.dart';
import '../models/block_list.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  AppSettings? _settings;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = context.read<DatabaseService>();
    final s = await db.getSettings();
    if (mounted) setState(() => _settings = s);
  }

  Future<void> _toggle(String key, bool value) async {
    final db = context.read<DatabaseService>();
    await db.updateSetting(key, value ? 1 : 0);
    await _load();
  }

  Future<void> _exportBlockList() async {
    final db = context.read<DatabaseService>();
    final list = await db.getBlockList();
    final json = jsonEncode(list.map((e) => e.toJson()).toList());
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/block_list.json');
    await file.writeAsString(json);
    await Share.shareXFiles([XFile(file.path)],
        text: 'Spam Call Blocker - Block List');
  }

  Future<void> _importBlockList() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (result == null || result.files.single.path == null) return;

    final file = File(result.files.single.path!);
    final content = await file.readAsString();
    final List<dynamic> data = jsonDecode(content);
    final db = context.read<DatabaseService>();

    int count = 0;
    for (final item in data) {
      await db.addToBlockList(
          BlockListEntry.fromJson(item as Map<String, dynamic>));
      count++;
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Imported $count entries.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_settings == null) {
      return const Scaffold(
          body: Center(child: CircularProgressIndicator()));
    }
    final s = _settings!;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const _SectionHeader('Call Screening'),
          SwitchListTile(
            title: const Text('Enable Call Screening'),
            subtitle:
                const Text('Screen unknown callers automatically'),
            value: s.callScreeningEnabled,
            onChanged: (v) => _toggle('call_screening_enabled', v),
          ),
          SwitchListTile(
            title: const Text('Challenge-Response'),
            subtitle: const Text(
                'Require callers to press a digit to connect'),
            value: s.challengeEnabled,
            onChanged: (v) => _toggle('challenge_enabled', v),
          ),
          const _SectionHeader('Contacts'),
          SwitchListTile(
            title: const Text('Auto-Whitelist Contacts'),
            subtitle: const Text(
                'Automatically allow calls from your contacts'),
            value: s.autoWhitelistContacts,
            onChanged: (v) => _toggle('auto_whitelist_contacts', v),
          ),
          const _SectionHeader('Feedback'),
          SwitchListTile(
            title: const Text('Post-Call Feedback'),
            subtitle: const Text(
                'Ask "Was this spam?" after calls from unknown numbers'),
            value: s.postCallFeedback,
            onChanged: (v) => _toggle('post_call_feedback', v),
          ),
          const _SectionHeader('Data'),
          ListTile(
            leading: const Icon(Icons.upload_file),
            title: const Text('Export Block List'),
            subtitle: const Text('Share as JSON file'),
            onTap: _exportBlockList,
          ),
          ListTile(
            leading: const Icon(Icons.download),
            title: const Text('Import Block List'),
            subtitle: const Text('Load from JSON file'),
            onTap: _importBlockList,
          ),
          const _SectionHeader('Privacy'),
          const ListTile(
            leading: Icon(Icons.lock),
            title: Text('POPIA Compliant'),
            subtitle: Text(
                'All data is stored locally on your device. Nothing is sent to external servers.'),
          ),
          const SizedBox(height: 32),
          Center(
            child: Text(
              'Spam Call Blocker v1.0.0',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(title,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.primary)),
    );
  }
}
