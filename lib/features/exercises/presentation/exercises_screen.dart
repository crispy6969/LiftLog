import 'package:liftlog/shared/material.dart';
import '../../../core/formatting/values.dart';
import '../../../shared/widgets/messages.dart';
import '../../entries/presentation/exercise_screen.dart';
import '../../library/presentation/create_menu.dart';
import '../data/tracker_repository.dart';
import '../models/exercise.dart';
import 'exercise_form.dart';

class ExercisesScreen extends StatefulWidget {
  const ExercisesScreen({
    super.key,
    required this.repository,
    this.archived = false,
    this.manage = false,
  });
  final TrackerRepository repository;
  final bool archived;
  final bool manage;
  @override
  State<ExercisesScreen> createState() => _ExercisesScreenState();
}

class _ExercisesScreenState extends State<ExercisesScreen> {
  final search = TextEditingController();
  List<Exercise> exercises = [];
  List<SplitDay> splits = [];
  List<Location> locations = [];
  int? splitId;
  int? locationId;
  bool loading = true;
  Object? error;
  int request = 0;
  @override
  void initState() {
    super.initState();
    refresh();
  }

  Future<void> refresh() async {
    if (!mounted) return;
    final current = ++request;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final days = await widget.repository.splits();
      final places = await widget.repository.locations();
      if (!mounted || current != request) return;
      if (splitId != -1 && !days.any((s) => s.id == splitId)) splitId = null;
      if (!places.any((l) => l.id == locationId)) locationId = null;
      final rows = await widget.repository.exercises(
        search: search.text,
        splitId: splitId,
        locationId: locationId,
        archived: widget.archived,
      );
      if (!mounted || current != request) return;
      setState(() {
        splits = days;
        locations = places;
        exercises = rows;
        loading = false;
      });
    } catch (e) {
      if (mounted && current == request) {
        setState(() {
          error = e;
          loading = false;
        });
      }
    }
  }

  Future<void> create() async {
    await showCreateMenu(context, widget.repository);
    await refresh();
  }

  Future<void> manage(Exercise exercise, String action) async {
    try {
      if (action == 'edit') {
        await exerciseForm(context, widget.repository, exercise: exercise);
      } else if (action == 'restore') {
        await widget.repository.archive(exercise.id, false);
      } else if (action == 'archive') {
        await widget.repository.archive(exercise.id, true);
      } else {
        if (await widget.repository.hasHistory(exercise.id)) {
          throw StateError(
            'This exercise has history. Archive it to preserve your entries.',
          );
        }
        if (!mounted ||
            !await confirm(
              context,
              title: 'Delete exercise?',
              message: 'The exercise and its unfinished draft will be removed.',
            )) {
          return;
        }
        await widget.repository.deleteEmptyExercise(exercise.id);
      }
      await refresh();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        widget.archived
            ? 'Archived exercises'
            : widget.manage
            ? 'Exercises'
            : 'Workout',
      ),
      actions: [
        if (!widget.archived)
          PopupMenuButton<String>(
            onSelected: (_) async {
              await Navigator.push<void>(
                context,
                MaterialPageRoute(
                  builder: (_) => ExercisesScreen(
                    repository: widget.repository,
                    archived: true,
                    manage: true,
                  ),
                ),
              );
              await refresh();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'archive',
                child: Text('Archived exercises'),
              ),
            ],
          ),
      ],
    ),
    floatingActionButton: widget.archived
        ? null
        : FloatingActionButton.extended(
            onPressed: create,
            icon: const Icon(Icons.add),
            label: const Text('Create'),
          ),
    body: SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Column(
              children: [
                TextField(
                  controller: search,
                  decoration: InputDecoration(
                    labelText: 'Search exercises',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: search.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Clear search',
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              search.clear();
                              refresh();
                            },
                          ),
                  ),
                  onChanged: (_) => refresh(),
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        key: ValueKey('split-${splitId ?? 0}'),
                        initialValue: splitId ?? 0,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Split day',
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 14,
                          ),
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: 0,
                            child: Text(
                              'All splits',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const DropdownMenuItem(
                            value: -1,
                            child: Text(
                              'Unassigned',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          ...splits.map(
                            (s) => DropdownMenuItem(
                              value: s.id,
                              child: Text(
                                s.name,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                        onChanged: (id) {
                          splitId = id == 0 ? null : id;
                          refresh();
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        key: ValueKey('location-${locationId ?? 0}'),
                        initialValue: locationId ?? 0,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Location',
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 14,
                          ),
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: 0,
                            child: Text(
                              'Any location',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          ...locations.map(
                            (l) => DropdownMenuItem(
                              value: l.id,
                              child: Text(
                                l.name,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                        onChanged: (id) {
                          locationId = id == 0 ? null : id;
                          refresh();
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (loading) const LinearProgressIndicator(),
          Expanded(
            child: error != null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(friendlyError(error!)),
                        TextButton(
                          onPressed: refresh,
                          child: const Text('Try again'),
                        ),
                      ],
                    ),
                  )
                : exercises.isEmpty && !loading
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.fitness_center, size: 48),
                          const SizedBox(height: 16),
                          Text(
                            widget.archived
                                ? 'No archived exercises found.'
                                : search.text.isNotEmpty ||
                                      splitId != null ||
                                      locationId != null
                                ? 'No matching exercises.'
                                : 'Your progress starts here. Create your first exercise.',
                          ),
                          const SizedBox(height: 16),
                          if (search.text.isNotEmpty ||
                              splitId != null ||
                              locationId != null)
                            TextButton(
                              onPressed: () {
                                search.clear();
                                splitId = null;
                                locationId = null;
                                refresh();
                              },
                              child: const Text('Clear search and filters'),
                            )
                          else if (!widget.archived)
                            FilledButton(
                              onPressed: () async {
                                await exerciseForm(context, widget.repository);
                                await refresh();
                              },
                              child: const Text('Create your first exercise'),
                            ),
                        ],
                      ),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: refresh,
                    child: ListView.separated(
                      padding: const EdgeInsets.only(bottom: 100),
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: exercises.length,
                      separatorBuilder: (_, _) =>
                          const Divider(height: 1, indent: 16),
                      itemBuilder: (context, index) {
                        final exercise = exercises[index];
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 8,
                          ),
                          title: Text(exercise.name),
                          subtitle: Text(
                            '${exercise.locationName ?? 'Any location'} · ${exercise.lastAtMs == null ? 'No previous entries' : 'Last performed: ${daysAgo(DateTime.now(), recordedTime(exercise.lastAtMs!, exercise.lastOffset!))}'}',
                          ),
                          trailing: widget.manage
                              ? PopupMenuButton<String>(
                                  onSelected: (action) =>
                                      manage(exercise, action),
                                  itemBuilder: (_) => [
                                    const PopupMenuItem(
                                      value: 'edit',
                                      child: Text('Edit exercise'),
                                    ),
                                    if (exercise.archived)
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
                                )
                              : const Icon(Icons.chevron_right),
                          onTap: () async {
                            await Navigator.push<void>(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ExerciseScreen(
                                  repository: widget.repository,
                                  exercise: exercise,
                                ),
                              ),
                            );
                            await refresh();
                          },
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    ),
  );
  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }
}
