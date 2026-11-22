import 'package:liftlog/shared/material.dart';
import 'app.dart';
import 'core/database/app_database.dart';
import 'features/exercises/data/tracker_repository.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _Bootstrap());
}

class _Bootstrap extends StatefulWidget {
  const _Bootstrap();
  @override
  State<_Bootstrap> createState() => _BootstrapState();
}

class _BootstrapState extends State<_Bootstrap> {
  late Future<TrackerRepository> repository;
  @override
  void initState() {
    super.initState();
    repository = _open();
  }

  Future<TrackerRepository> _open() async =>
      TrackerRepository(await AppDatabase.open());
  @override
  Widget build(BuildContext context) => FutureBuilder<TrackerRepository>(
    future: repository,
    builder: (context, snapshot) {
      if (snapshot.hasData) return LiftlogApp(repository: snapshot.data!);
      return MaterialApp(
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: snapshot.hasError
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Could not open your data. Nothing has been deleted. Try again, or check that your phone has free storage.',
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: () => setState(() => repository = _open()),
                          child: const Text('Retry'),
                        ),
                      ],
                    )
                  : const CircularProgressIndicator(),
            ),
          ),
        ),
      );
    },
  );
}
