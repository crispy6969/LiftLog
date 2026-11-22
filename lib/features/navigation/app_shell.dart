import 'package:liftlog/shared/material.dart';
import '../exercises/data/tracker_repository.dart';
import '../exercises/presentation/exercises_screen.dart';
import '../library/presentation/library_screen.dart';
import '../profile/presentation/profile_screen.dart';
import '../weight/presentation/weight_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.repository,
    required this.email,
    required this.onLogout,
  });
  final TrackerRepository repository;
  final String email;
  final VoidCallback onLogout;
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int selected = 0;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: switch (selected) {
      0 => ExercisesScreen(repository: widget.repository),
      1 => WeightScreen(repository: widget.repository),
      2 => LibraryScreen(repository: widget.repository),
      _ => ProfileScreen(
        repository: widget.repository,
        email: widget.email,
        onLogout: widget.onLogout,
      ),
    },
    bottomNavigationBar: NavigationBar(
      selectedIndex: selected,
      onDestinationSelected: (index) => setState(() => selected = index),
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.fitness_center),
          label: 'Workout',
        ),
        NavigationDestination(
          icon: Icon(Icons.monitor_weight_outlined),
          label: 'Weight',
        ),
        NavigationDestination(
          icon: Icon(Icons.library_books_outlined),
          label: 'Manage',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline),
          label: 'Profile',
        ),
      ],
    ),
  );
}
