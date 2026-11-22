import 'package:liftlog/shared/material.dart';
import '../../../shared/widgets/messages.dart';
import '../../exercises/data/tracker_repository.dart';
import '../../exercises/models/exercise.dart';

Future<bool> locationForm(
  BuildContext context,
  TrackerRepository repository, {
  Location? location,
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (_) => _LocationForm(repository: repository, location: location),
    ) ??
    false;

class _LocationForm extends StatefulWidget {
  const _LocationForm({required this.repository, this.location});
  final TrackerRepository repository;
  final Location? location;
  @override
  State<_LocationForm> createState() => _LocationFormState();
}

class _LocationFormState extends State<_LocationForm> {
  late final name = TextEditingController(text: widget.location?.name);
  bool busy = false;
  String? error;
  Future<void> save() async {
    setState(() => busy = true);
    try {
      await widget.repository.saveLocation(name.text, id: widget.location?.id);
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
      title: Text(widget.location == null ? 'New location' : 'Rename location'),
      content: TextField(
        controller: name,
        autofocus: true,
        enabled: !busy,
        textCapitalization: TextCapitalization.words,
        decoration: InputDecoration(
          labelText: 'Location name',
          errorText: error,
        ),
        onSubmitted: (_) {
          if (!busy) save();
        },
      ),
      actions: [
        TextButton(
          onPressed: busy ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: busy ? null : save,
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
