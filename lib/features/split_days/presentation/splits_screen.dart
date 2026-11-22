import 'package:liftlog/shared/material.dart';
import '../../../shared/widgets/messages.dart';
import '../../exercises/data/tracker_repository.dart';
import '../../exercises/models/exercise.dart';
import '../../library/presentation/create_menu.dart';
import 'split_form.dart';

class SplitsScreen extends StatefulWidget {
  const SplitsScreen({super.key, required this.repository});
  final TrackerRepository repository;
  @override
  State<SplitsScreen> createState() => _SplitsScreenState();
}

class _SplitsScreenState extends State<SplitsScreen> {
  late Future<List<SplitDay>> data;
  @override
  void initState() {
    super.initState();
    data = widget.repository.splits();
  }

  void _refresh() {
    if (mounted) setState(() => data = widget.repository.splits());
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Split days')),
    floatingActionButton: FloatingActionButton(
      onPressed: () async {
        await showCreateMenu(context, widget.repository);
        _refresh();
      },
      child: const Icon(Icons.add),
    ),
    body: FutureBuilder<List<SplitDay>>(
      future: data,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: TextButton(
              onPressed: _refresh,
              child: const Text('Could not load split days. Retry'),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final splits = snapshot.data!;
        if (splits.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text('Create a split day to organize your exercises.'),
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 100),
          itemCount: splits.length,
          itemBuilder: (context, i) => ListTile(
            title: Text(splits[i].name),
            subtitle: const Text('Tap to rename'),
            onTap: () async {
              await splitForm(context, widget.repository, split: splits[i]);
              _refresh();
            },
            trailing: IconButton(
              tooltip: 'Delete split day',
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                if (!await confirm(
                  context,
                  title: 'Delete ${splits[i].name}?',
                  message: 'Exercises and workout history will be kept.',
                )) {
                  return;
                }
                try {
                  await widget.repository.deleteSplit(splits[i].id);
                  _refresh();
                } catch (e) {
                  if (context.mounted) showError(context, e);
                }
              },
            ),
          ),
        );
      },
    ),
  );
}
