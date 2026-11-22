import 'package:liftlog/shared/material.dart';

import '../../../shared/widgets/messages.dart';
import '../../exercises/data/tracker_repository.dart';
import '../../exercises/models/exercise.dart';

Future<bool> splitForm(
  BuildContext context,
  TrackerRepository repository, {
  SplitDay? split,
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (_) => _SplitForm(repository: repository, split: split),
    ) ??
    false;

class _SplitForm extends StatefulWidget {
  const _SplitForm({required this.repository, this.split});
  final TrackerRepository repository;
  final SplitDay? split;
  @override
  State<_SplitForm> createState() => _SplitFormState();
}

class _SplitFormState extends State<_SplitForm> {
  late final name = TextEditingController(text: widget.split?.name);
  String? error;
  bool busy = false;
  Future<void> _save() async {
    setState(() => busy = true);
    try {
      await widget.repository.saveSplit(name.text, id: widget.split?.id);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          busy = false;
          error = friendlyError(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: AlertDialog(
      title: Text(widget.split == null ? 'New split day' : 'Rename split day'),
      content: TextField(
        controller: name,
        autofocus: true,
        enabled: !busy,
        textCapitalization: TextCapitalization.words,
        decoration: InputDecoration(labelText: 'Split name', errorText: error),
        onSubmitted: (_) {
          if (!busy) _save();
        },
      ),
      actions: [
        TextButton(
          onPressed: busy ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: busy ? null : _save,
          child: Text(busy ? 'Saving…' : 'Save'),
        ),
      ],
    ),
  );
  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }
}
