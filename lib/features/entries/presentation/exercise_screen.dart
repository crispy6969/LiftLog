import 'dart:async';

import 'package:liftlog/shared/material.dart';

import '../../../core/formatting/values.dart';
import '../../../shared/widgets/messages.dart';
import '../../exercises/data/tracker_repository.dart';
import '../../exercises/models/exercise.dart';
import '../../exercises/presentation/exercise_form.dart';
import '../models/entry.dart';
import 'entry_controller.dart';

class ExerciseScreen extends StatefulWidget {
  const ExerciseScreen({
    super.key,
    required this.repository,
    required this.exercise,
  });
  final TrackerRepository repository;
  final Exercise exercise;
  @override
  State<ExerciseScreen> createState() => _ExerciseScreenState();
}

class _ExerciseScreenState extends State<ExerciseScreen>
    with WidgetsBindingObserver {
  late final controller = EntryController(
    widget.repository,
    widget.exercise.id,
  );
  final _form = GlobalKey<FormState>();
  final _scroll = ScrollController();
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    controller.load();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) unawaited(controller.flush());
  }

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _date() async {
    final initial = controller.draft.localTime;
    final now = DateTime.now();
    final initialDay = DateTime(initial.year, initial.month, initial.day);
    final firstDay = initialDay.isBefore(DateTime(2000))
        ? initialDay
        : DateTime(2000);
    final date = await showDatePicker(
      context: context,
      initialDate: initialDay.isAfter(now) ? now : initialDay,
      firstDate: firstDay,
      lastDate: now,
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: initial.hour, minute: initial.minute),
    );
    if (time == null || !mounted) return;
    final selected = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    controller.draft.performedAtMs = selected.millisecondsSinceEpoch;
    controller.draft.offsetMinutes = selected.timeZoneOffset.inMinutes;
    controller.changed();
  }

  Future<void> _manage(String action) async {
    if (!await controller.flush() && mounted) {
      showError(context, controller.draftError!);
      return;
    }
    if (!mounted) return;
    if (action == 'edit') {
      if (await exerciseForm(
            context,
            widget.repository,
            exercise: widget.exercise,
          ) &&
          mounted) {
        Navigator.pop(context);
      }
      return;
    }
    if (action == 'restore') {
      await widget.repository.archive(widget.exercise.id, false);
    } else if (action == 'archive') {
      if (!await confirm(
        context,
        title: 'Archive exercise?',
        message:
            'History and drafts will be kept. Restore the exercise to log again.',
        action: 'Archive',
      )) {
        return;
      }
      await widget.repository.archive(widget.exercise.id, true);
    } else {
      if (await widget.repository.hasHistory(widget.exercise.id)) {
        if (mounted) {
          showError(
            context,
            StateError(
              'This exercise has history. Archive it to preserve your entries.',
            ),
          );
        }
        return;
      }
      if (!mounted ||
          !await confirm(
            context,
            title: 'Delete exercise?',
            message:
                'This exercise and any unfinished draft will be permanently removed.',
          )) {
        return;
      }
      await widget.repository.deleteEmptyExercise(widget.exercise.id);
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> _back() async {
    if (controller.busy) return;
    final saved = await controller.flush();
    if (!mounted) return;
    if (!saved &&
        !await confirm(
          context,
          title: 'Draft could not be saved',
          message:
              'Leaving may lose the latest changes. Stay here to retry, or leave anyway.',
          action: 'Leave anyway',
        )) {
      return;
    }
    if (!mounted) return;
    setState(() => _leaving = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.pop(context);
    });
  }

  Widget _editor() {
    final draft = controller.draft;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                draft.editingEntryId == null
                    ? 'Log performance'
                    : 'Edit saved entry',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: controller.busy ? null : _date,
                icon: const Icon(Icons.calendar_today_outlined),
                label: Text(dateLabel(draft.localTime)),
              ),
              const SizedBox(height: 4),
              const Text('Kilograms • 0 kg for bodyweight alone'),
              if (controller.comparison != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Comparing with ${dateLabel(controller.comparison!.localTime)}',
                  ),
                ),
              const SizedBox(height: 16),
              KeyedSubtree(
                key: ObjectKey(draft),
                child: Column(
                  children: [
                    ...draft.sets.asMap().entries.map((item) {
                      final input = item.value;
                      return Padding(
                        key: ObjectKey(input),
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 6,
                                children: [
                                  Text(
                                    'Set ${item.key + 1} · Previous:',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.labelLarge,
                                  ),
                                  if (controller.comparison != null &&
                                      item.key <
                                          controller.comparison!.sets.length)
                                    Text(
                                      '${kilograms(controller.comparison!.sets[item.key].grams)} kg × ${repetitions(controller.comparison!.sets[item.key].repsTenths)} reps',
                                    )
                                  else
                                    const Text('No matching set'),
                                  const Icon(Icons.arrow_forward, size: 16),
                                  const Text('Now'),
                                ],
                              ),
                            ),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(
                                    top: 18,
                                    right: 10,
                                  ),
                                  child: Text('${item.key + 1}'),
                                ),
                                Expanded(
                                  child: TextFormField(
                                    initialValue: input.weight,
                                    enabled: !controller.busy,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                    textInputAction: TextInputAction.next,
                                    decoration: const InputDecoration(
                                      labelText: 'Weight (kg)',
                                    ),
                                    autovalidateMode:
                                        AutovalidateMode.onUserInteraction,
                                    validator: (v) =>
                                        parseGrams(v ?? '') == null
                                        ? 'Use 0 or more kg'
                                        : null,
                                    onChanged: (v) {
                                      input.weight = v;
                                      controller.changed();
                                    },
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: TextFormField(
                                    initialValue: input.reps,
                                    enabled: !controller.busy,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                    textInputAction: TextInputAction.next,
                                    decoration: const InputDecoration(
                                      labelText: 'Repetitions',
                                    ),
                                    autovalidateMode:
                                        AutovalidateMode.onUserInteraction,
                                    validator: (v) => parseReps(v ?? '') == null
                                        ? 'Positive reps; max 1 decimal'
                                        : null,
                                    onChanged: (v) {
                                      input.reps = v;
                                      controller.changed();
                                    },
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Remove set ${item.key + 1}',
                                  onPressed: controller.busy
                                      ? null
                                      : () {
                                          draft.sets.removeAt(item.key);
                                          controller.changed();
                                        },
                                  icon: const Icon(Icons.remove_circle_outline),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }),
                    TextFormField(
                      initialValue: draft.note,
                      enabled: !controller.busy,
                      minLines: 2,
                      maxLines: 5,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Note (optional)',
                        hintText:
                            'Anything that helps explain this performance',
                      ),
                      onChanged: (value) {
                        draft.note = value;
                        controller.changed();
                      },
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: controller.busy
                    ? null
                    : () {
                        draft.sets.add(
                          SetInput(
                            weight: draft.sets.isEmpty
                                ? ''
                                : draft.sets.last.weight,
                          ),
                        );
                        controller.changed();
                      },
                icon: const Icon(Icons.add),
                label: const Text('Add set'),
              ),
              if (controller.hasDraft)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    controller.draftError != null
                        ? 'Draft could not be saved. Retry before leaving.'
                        : controller.persisting
                        ? 'Saving draft…'
                        : 'Draft saved on this device',
                    style: TextStyle(
                      color: controller.draftError == null
                          ? null
                          : Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              if (controller.draftError != null)
                TextButton(
                  onPressed: controller.changed,
                  child: const Text('Retry draft save'),
                ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: controller.busy
                        ? null
                        : () => _run(() async {
                            if (!_form.currentState!.validate()) return;
                            await controller.save();
                            if (mounted) {
                              FocusScope.of(context).unfocus();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Entry saved')),
                              );
                            }
                          }),
                    icon: const Icon(Icons.check),
                    label: Text(
                      controller.busy ? 'Please wait…' : 'Save entry',
                    ),
                  ),
                  if (controller.hasDraft)
                    TextButton(
                      onPressed: controller.busy
                          ? null
                          : () => _run(() async {
                              if (await confirm(
                                context,
                                title: 'Discard draft?',
                                message:
                                    'Unsaved changes will be removed. Existing history will be kept.',
                                action: 'Discard',
                              )) {
                                await controller.discard();
                              }
                            }),
                      child: const Text('Discard draft'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _historyCard(ExerciseEntry entry, ExerciseEntry? older) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  dateLabel(entry.localTime),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              if (!widget.exercise.archived)
                PopupMenuButton<String>(
                  enabled: !controller.busy,
                  onSelected: (action) => _run(() async {
                    if (action == 'edit') {
                      if (controller.hasDraft &&
                          !await confirm(
                            context,
                            title: 'Replace current draft?',
                            message:
                                'Discard the unfinished draft and edit this saved entry?',
                            action: 'Replace draft',
                          )) {
                        return;
                      }
                      await controller.edit(entry);
                      if (_scroll.hasClients) {
                        await _scroll.animateTo(
                          0,
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOut,
                        );
                      }
                    } else if (await confirm(
                      context,
                      title: 'Delete entry?',
                      message:
                          'All sets and the note in this entry will be permanently removed.',
                    )) {
                      await controller.delete(entry);
                    }
                  }),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('Edit entry')),
                    PopupMenuItem(value: 'delete', child: Text('Delete entry')),
                  ],
                ),
            ],
          ),
          if (older != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                '${calendarDays(entry.localTime, older.localTime).clamp(0, 999999)} calendar days since previous performance',
              ),
            ),
          ...entry.sets.asMap().entries.map(
            (s) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Text(
                'Set ${s.key + 1}    ${kilograms(s.value.grams)} kg × ${repetitions(s.value.repsTenths)} reps',
              ),
            ),
          ),
          if (entry.note != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(entry.note!),
            ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) => PopScope(
      canPop:
          _leaving ||
          (!controller.busy &&
              !controller.persisting &&
              controller.draftError == null),
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _back();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.exercise.name),
          actions: [
            PopupMenuButton<String>(
              enabled: !controller.busy && !controller.loading,
              onSelected: (action) => _run(() => _manage(action)),
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Text('Edit exercise'),
                ),
                if (widget.exercise.archived)
                  const PopupMenuItem(
                    value: 'restore',
                    child: Text('Restore exercise'),
                  )
                else
                  const PopupMenuItem(
                    value: 'archive',
                    child: Text('Archive exercise'),
                  ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Text('Delete empty exercise'),
                ),
              ],
            ),
          ],
        ),
        body: controller.loading
            ? const Center(child: CircularProgressIndicator())
            : controller.error != null
            ? Center(
                child: TextButton(
                  onPressed: controller.load,
                  child: const Text('Could not load exercise. Retry'),
                ),
              )
            : SafeArea(
                child: ListView(
                  controller: _scroll,
                  padding: const EdgeInsets.all(12),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(
                        controller.entries.isEmpty
                            ? 'No previous entries'
                            : 'Last performed: ${daysAgo(DateTime.now(), controller.entries.first.localTime)}',
                      ),
                    ),
                    if (widget.exercise.archived)
                      const Card(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Text(
                            'Archived • Restore this exercise to log or edit entries.',
                          ),
                        ),
                      )
                    else
                      _editor(),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        'Previous performances',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    if (controller.entries.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(12),
                        child: Text(
                          'Your saved performances will appear here.',
                        ),
                      ),
                    ...controller.entries.asMap().entries.map(
                      (item) => _historyCard(
                        item.value,
                        item.key + 1 < controller.entries.length
                            ? controller.entries[item.key + 1]
                            : controller.preceding,
                      ),
                    ),
                    if (controller.hasMore)
                      TextButton(
                        onPressed: controller.busy
                            ? null
                            : () => _run(controller.more),
                        child: const Text('Load older entries'),
                      ),
                  ],
                ),
              ),
      ),
    ),
  );
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    controller.dispose();
    _scroll.dispose();
    super.dispose();
  }
}
