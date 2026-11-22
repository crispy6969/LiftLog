import 'package:intl/intl.dart';
import 'package:liftlog/shared/material.dart';
import '../../../core/formatting/values.dart';
import '../../../shared/widgets/messages.dart';
import '../../exercises/data/tracker_repository.dart';
import '../data/weight_repository.dart';
import 'weight_chart.dart';

class WeightScreen extends StatefulWidget {
  const WeightScreen({super.key, required this.repository});
  final TrackerRepository repository;
  @override
  State<WeightScreen> createState() => _WeightScreenState();
}

class _WeightScreenState extends State<WeightScreen> {
  late final repository = WeightRepository(widget.repository.db);
  late Future<List<BodyWeight>> data = repository.entries();
  BodyWeight? selected;
  void refresh() {
    if (mounted) {
      setState(() {
        selected = null;
        data = repository.entries();
      });
    }
  }

  Future<void> edit({BodyWeight? entry}) async {
    await showDialog<bool>(
      context: context,
      builder: (_) => _WeightForm(repository: repository, entry: entry),
    );
    refresh();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Weight tracker')),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: edit,
      icon: const Icon(Icons.add),
      label: const Text('Add weight'),
    ),
    body: SafeArea(
      child: FutureBuilder<List<BodyWeight>>(
        future: data,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: TextButton(
                onPressed: refresh,
                child: const Text('Could not load measurements. Retry'),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final entries = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            children: [
              if (entries.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Column(
                    children: [
                      Icon(Icons.monitor_weight_outlined, size: 48),
                      SizedBox(height: 16),
                      Text(
                        'Add your first weight measurement to start your graph.',
                      ),
                    ],
                  ),
                )
              else ...[
                Text(
                  '${kilograms(entries.first.grams)} kg',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                Text(
                  'Latest · ${DateFormat.yMMMd().format(entries.first.date)}',
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: WeightChart(
                      entries: entries,
                      onSelected: (entry) => setState(() => selected = entry),
                    ),
                  ),
                ),
                if (selected != null)
                  Card(
                    child: ListTile(
                      title: Text(
                        '${DateFormat.yMMMd().format(selected!.date)} · ${kilograms(selected!.grams)} kg',
                      ),
                      subtitle: selected!.note == null
                          ? null
                          : Text(selected!.note!),
                    ),
                  ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'Tap a graph point or a measurement to see its note. One measurement per date.',
                  ),
                ),
                for (final entry in entries)
                  Card(
                    child: ListTile(
                      title: Text(
                        '${kilograms(entry.grams)} kg · ${DateFormat.yMMMd().format(entry.date)}',
                      ),
                      subtitle: entry.note == null ? null : Text(entry.note!),
                      onTap: () => edit(entry: entry),
                      trailing: PopupMenuButton<String>(
                        onSelected: (action) async {
                          if (action == 'edit') {
                            await edit(entry: entry);
                            return;
                          }
                          if (!await confirm(
                            context,
                            title: 'Delete measurement?',
                            message:
                                'The weight and note for this date will be permanently removed.',
                          )) {
                            return;
                          }
                          try {
                            await repository.delete(entry.id);
                            refresh();
                          } catch (e) {
                            if (context.mounted) showError(context, e);
                          }
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(
                            value: 'edit',
                            child: Text('Edit measurement'),
                          ),
                          PopupMenuItem(
                            value: 'delete',
                            child: Text('Delete measurement'),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ],
          );
        },
      ),
    ),
  );
}

class _WeightForm extends StatefulWidget {
  const _WeightForm({required this.repository, this.entry});
  final WeightRepository repository;
  final BodyWeight? entry;
  @override
  State<_WeightForm> createState() => _WeightFormState();
}

class _WeightFormState extends State<_WeightForm> {
  late final weight = TextEditingController(
    text: widget.entry == null ? '' : kilograms(widget.entry!.grams),
  );
  late final note = TextEditingController(text: widget.entry?.note);
  late DateTime date = widget.entry?.date ?? DateTime.now();
  bool busy = false;
  String? error;
  Future<void> save() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.repository.save(
        id: widget.entry?.id,
        day: dayKey(date),
        weight: weight.text,
        note: note.text,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          busy = false;
          error = e.toString().contains('UNIQUE')
              ? 'There is already a measurement for this date. Edit it from the list.'
              : friendlyError(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: AlertDialog(
      title: Text(widget.entry == null ? 'Add weight' : 'Edit measurement'),
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextButton.icon(
                onPressed: busy
                    ? null
                    : () async {
                        final chosen = await showDatePicker(
                          context: context,
                          initialDate: date,
                          firstDate: DateTime(2000),
                          lastDate: DateTime.now(),
                        );
                        if (chosen != null && mounted) {
                          setState(() => date = chosen);
                        }
                      },
                icon: const Icon(Icons.calendar_today_outlined),
                label: Text(DateFormat.yMMMd().format(date)),
              ),
              TextField(
                controller: weight,
                enabled: !busy,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Body weight (kg)',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: note,
                enabled: !busy,
                minLines: 2,
                maxLines: 5,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Note (optional)',
                  hintText: 'For example: Started bulking',
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
          onPressed: busy ? null : save,
          child: Text(busy ? 'Saving…' : 'Save'),
        ),
      ],
    ),
  );
  @override
  void dispose() {
    weight.dispose();
    note.dispose();
    super.dispose();
  }
}
