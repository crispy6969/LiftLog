import 'dart:convert';
import 'package:file_selector/file_selector.dart';
import 'package:liftlog/shared/material.dart';
import 'package:share_plus/share_plus.dart';
import '../../../shared/widgets/messages.dart';
import '../../exercises/data/tracker_repository.dart';
import '../data/backup_service.dart';

class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key, required this.repository});
  final TrackerRepository repository;
  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  late final service = BackupService(widget.repository.db);
  bool busy = false;
  String? status;
  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      busy = true;
      status = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _export() async {
    final data = await service.export();
    if (!mounted) return;
    final box = context.findRenderObject() as RenderBox?;
    final filename =
        'liftlog-${DateTime.now().toUtc().toIso8601String().replaceAll(':', '-')}.json';
    final result = await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile.fromData(
            utf8.encode(data),
            mimeType: 'application/json',
            name: filename,
          ),
        ],
        fileNameOverrides: [filename],
        subject: 'Liftlog backup',
        sharePositionOrigin: box == null
            ? null
            : box.localToGlobal(Offset.zero) & box.size,
      ),
    );
    if (mounted) {
      setState(
        () => status = result.status == ShareResultStatus.dismissed
            ? 'Export cancelled. No backup was confirmed.'
            : 'Backup prepared. Make sure the file was saved somewhere safe, preferably off this phone.',
      );
    }
  }

  Future<void> _restore() async {
    final file = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(
          label: 'Liftlog JSON backup',
          extensions: ['json'],
          mimeTypes: ['application/json'],
          uniformTypeIdentifiers: ['public.json'],
        ),
      ],
    );
    if (file == null) return;
    final source = await file.readAsString();
    final preview = BackupDocument.parse(source);
    if (!mounted) return;
    final backupFirst = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Back up current data first?'),
        content: const Text(
          'Restore replaces all current exercises, entries and drafts. You can export them before continuing.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Continue'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Export first'),
          ),
        ],
      ),
    );
    if (backupFirst == null) return;
    if (backupFirst) await _export();
    if (!mounted ||
        !await confirm(
          context,
          title: 'Replace all current data?',
          message:
              'The selected backup contains ${preview.count('exercises')} exercises, ${preview.count('locations')} locations, ${preview.count('split_days')} split days, ${preview.count('exercise_entries')} entries, ${preview.count('entry_drafts')} drafts and ${preview.count('body_weights')} body-weight measurements.\n\nCurrent data will be replaced. This cannot be undone without another backup.',
          action: 'Replace data',
        )) {
      return;
    }
    await service.restore(source);
    if (mounted) {
      setState(() => status = 'Restore complete. Your backup data is ready.');
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: Scaffold(
      appBar: AppBar(title: const Text('Backup & restore')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Icon(Icons.backup_outlined, size: 56),
            const SizedBox(height: 24),
            Text(
              'Keep your progress safe',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            const Text(
              'Everything is stored on this phone. Uninstalling the app removes its local data. A lost phone cannot be recovered without a backup stored elsewhere.',
            ),
            const SizedBox(height: 12),
            const Text(
              'Export regularly to your computer, another device, or a storage provider you already use. A file kept only on this phone will not protect against losing the phone.',
            ),
            const SizedBox(height: 12),
            const Text(
              'Backup files include notes and unfinished drafts. They are readable JSON, without encryption. Share them only with destinations you trust.',
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: busy ? null : () => _run(_export),
              icon: const Icon(Icons.ios_share),
              label: const Text('Export backup'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: busy ? null : () => _run(_restore),
              icon: const Icon(Icons.restore),
              label: const Text('Restore from backup'),
            ),
            if (busy)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),
            if (status != null)
              Padding(
                padding: const EdgeInsets.only(top: 24),
                child: Text(status!),
              ),
          ],
        ),
      ),
    ),
  );
}
