import 'package:liftlog/shared/material.dart';

import '../../../shared/widgets/messages.dart';
import '../data/tracker_repository.dart';
import '../models/exercise.dart';

Future<bool> exerciseForm(
  BuildContext context,
  TrackerRepository repository, {
  Exercise? exercise,
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (_) => _ExerciseForm(repository: repository, exercise: exercise),
    ) ??
    false;

class _ExerciseForm extends StatefulWidget {
  const _ExerciseForm({required this.repository, this.exercise});
  final TrackerRepository repository;
  final Exercise? exercise;
  @override
  State<_ExerciseForm> createState() => _ExerciseFormState();
}

class _ExerciseFormState extends State<_ExerciseForm> {
  late final TextEditingController name = TextEditingController(
    text: widget.exercise?.name,
  );
  List<SplitDay> splits = [];
  List<Location> locations = [];
  late int? locationId = widget.exercise?.locationId;
  Set<int> selected = {};
  bool loading = true;
  bool ready = false;
  bool busy = false;
  String? error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        loading = true;
        error = null;
      });
    }
    try {
      splits = await widget.repository.splits();
      locations = await widget.repository.locations();
      if (widget.exercise != null) {
        selected = await widget.repository.memberships(widget.exercise!.id);
      }
      ready = true;
    } catch (e) {
      error = friendlyError(e);
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> _save() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.repository.saveExercise(
        name.text,
        selected,
        id: widget.exercise?.id,
        locationId: locationId,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          error = friendlyError(e);
          busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: AlertDialog(
      title: Text(widget.exercise == null ? 'New exercise' : 'Edit exercise'),
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: name,
                autofocus: true,
                enabled: !busy,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Exercise name'),
                onSubmitted: (_) {
                  if (ready && !busy) _save();
                },
              ),
              const SizedBox(height: 20),
              if (ready) ...[
                DropdownButtonFormField<int>(
                  initialValue: locationId ?? 0,
                  decoration: const InputDecoration(labelText: 'Location'),
                  isExpanded: true,
                  items: [
                    const DropdownMenuItem(
                      value: 0,
                      child: Text('Any location'),
                    ),
                    ...locations.map(
                      (l) => DropdownMenuItem(
                        value: l.id,
                        child: Text(l.name, overflow: TextOverflow.ellipsis),
                      ),
                    ),
                  ],
                  onChanged: busy
                      ? null
                      : (id) =>
                            setState(() => locationId = id == 0 ? null : id),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'Any location exercises appear with every location filter. Choose a specific gym for equipment whose weights differ between locations.',
                  ),
                ),
              ],
              if (!loading && !ready)
                TextButton(
                  onPressed: _load,
                  child: const Text('Retry loading split days'),
                ),
              const Text('Split days (optional)'),
              if (loading)
                const LinearProgressIndicator()
              else if (splits.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text('No split days yet. You can add them later.'),
                )
              else
                ...splits.map(
                  (s) => CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(s.name),
                    value: selected.contains(s.id),
                    onChanged: busy
                        ? null
                        : (value) => setState(() {
                            value! ? selected.add(s.id) : selected.remove(s.id);
                          }),
                  ),
                ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: busy ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: busy || !ready ? null : _save,
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
