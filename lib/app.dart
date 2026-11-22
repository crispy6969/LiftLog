import 'package:liftlog/shared/material.dart';
import 'features/exercises/data/tracker_repository.dart';
import 'features/auth/presentation/auth_screen.dart';
import 'features/navigation/app_shell.dart';

class LiftlogApp extends StatelessWidget {
  const LiftlogApp({super.key, required this.repository});
  final TrackerRepository repository;
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Liftlog',
    debugShowCheckedModeBanner: false,
    theme: _theme(Brightness.light),
    darkTheme: _theme(Brightness.dark),
    home: _AuthGate(repository: repository),
  );
  ThemeData _theme(Brightness brightness) => ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF216D60),
      brightness: brightness,
    ),
    useMaterial3: true,
    inputDecorationTheme: const InputDecorationTheme(
      border: OutlineInputBorder(),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
    ),
  );
}

class _AuthGate extends StatefulWidget {
  const _AuthGate({required this.repository});
  final TrackerRepository repository;
  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  String? email;
  @override
  Widget build(BuildContext context) => email == null
      ? AuthScreen(onAuthenticated: (value) => setState(() => email = value))
      : AppShell(
          repository: widget.repository,
          email: email!,
          onLogout: () => setState(() => email = null),
        );
}
