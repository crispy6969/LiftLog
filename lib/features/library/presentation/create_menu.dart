import 'package:liftlog/shared/material.dart';
import '../../exercises/data/tracker_repository.dart';
import '../../exercises/presentation/exercise_form.dart';
import '../../locations/presentation/location_form.dart';
import '../../split_days/presentation/split_form.dart';

Future<void> showCreateMenu(
  BuildContext context,
  TrackerRepository repository,
) async {
  final choice = await showModalBottomSheet<String>(
    context: context,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final item in [
            ('exercise', 'New exercise', Icons.fitness_center),
            ('split', 'New split day', Icons.category_outlined),
            ('location', 'New location', Icons.location_on_outlined),
          ])
            ListTile(
              leading: Icon(item.$3),
              title: Text(item.$2),
              onTap: () => Navigator.pop(context, item.$1),
            ),
        ],
      ),
    ),
  );
  if (!context.mounted) return;
  if (choice == 'exercise') {
    await exerciseForm(context, repository);
    return;
  }
  if (choice == 'split') {
    await splitForm(context, repository);
    return;
  }
  if (choice == 'location') {
    await locationForm(context, repository);
  }
}
