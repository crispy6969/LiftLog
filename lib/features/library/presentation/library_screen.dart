import 'package:liftlog/shared/material.dart';
import '../../../shared/widgets/messages.dart';
import '../../exercises/data/tracker_repository.dart';
import '../../exercises/models/exercise.dart';
import '../../exercises/presentation/exercises_screen.dart';
import '../../locations/presentation/location_form.dart';
import '../../split_days/presentation/splits_screen.dart';
import 'create_menu.dart';

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key, required this.repository});
  final TrackerRepository repository;
  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 3,
    child: Column(
      children: [
        const SafeArea(
          bottom: false,
          child: TabBar(
            tabs: [
              Tab(text: 'Exercises'),
              Tab(text: 'Locations'),
              Tab(text: 'Split days'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            children: [
              ExercisesScreen(repository: repository, manage: true),
              _LocationsScreen(repository: repository),
              SplitsScreen(repository: repository),
            ],
          ),
        ),
      ],
    ),
  );
}

class _LocationsScreen extends StatefulWidget {
  const _LocationsScreen({required this.repository});
  final TrackerRepository repository;
  @override
  State<_LocationsScreen> createState() => _LocationsScreenState();
}

class _LocationsScreenState extends State<_LocationsScreen> {
  late Future<List<Location>> locations = widget.repository.locations();
  void refresh() {
    if (mounted) setState(() => locations = widget.repository.locations());
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Locations')),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: () async {
        await showCreateMenu(context, widget.repository);
        refresh();
      },
      icon: const Icon(Icons.add),
      label: const Text('Create'),
    ),
    body: FutureBuilder<List<Location>>(
      future: locations,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: TextButton(
              onPressed: refresh,
              child: const Text('Could not load locations. Retry'),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.data!.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Add your gyms here. Any location is available automatically.',
              ),
            ),
          );
        }
        return ListView(
          padding: const EdgeInsets.only(bottom: 96),
          children: [
            for (final location in snapshot.data!)
              ListTile(
                title: Text(location.name),
                subtitle: const Text('Tap to rename'),
                onTap: () async {
                  await locationForm(
                    context,
                    widget.repository,
                    location: location,
                  );
                  refresh();
                },
                trailing: IconButton(
                  tooltip: 'Delete location',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () async {
                    if (!await confirm(
                      context,
                      title: 'Delete ${location.name}?',
                      message:
                          'Only locations without assigned exercises can be deleted.',
                    )) {
                      return;
                    }
                    try {
                      await widget.repository.deleteLocation(location.id);
                      refresh();
                    } catch (e) {
                      if (context.mounted) showError(context, e);
                    }
                  },
                ),
              ),
          ],
        );
      },
    ),
  );
}
