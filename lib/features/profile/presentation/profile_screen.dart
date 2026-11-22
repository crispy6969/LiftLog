import 'package:liftlog/shared/material.dart';
import '../../backup/presentation/backup_screen.dart';
import '../../exercises/data/tracker_repository.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({
    super.key,
    required this.repository,
    required this.email,
    required this.onLogout,
  });
  final TrackerRepository repository;
  final String email;
  final VoidCallback onLogout;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Profile')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const CircleAvatar(
          radius: 36,
          child: Icon(Icons.person_outline, size: 40),
        ),
        const SizedBox(height: 16),
        Text(
          email.isEmpty ? 'Mock user' : email,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Text(
            'Mock session. Local data is shared across mock logins; passwords are not stored.',
            textAlign: TextAlign.center,
          ),
        ),
        ListTile(
          leading: const Icon(Icons.settings_outlined),
          title: const Text('Settings'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.push<void>(
            context,
            MaterialPageRoute(
              builder: (_) => _SettingsScreen(repository: repository),
            ),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.logout),
          title: const Text('Log out'),
          onTap: onLogout,
        ),
      ],
    ),
  );
}

class _SettingsScreen extends StatelessWidget {
  const _SettingsScreen({required this.repository});
  final TrackerRepository repository;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Settings')),
    body: ListView(
      children: [
        ListTile(
          leading: const Icon(Icons.backup_outlined),
          title: const Text('Backup & restore'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.push<void>(
            context,
            MaterialPageRoute(
              builder: (_) => BackupScreen(repository: repository),
            ),
          ),
        ),
      ],
    ),
  );
}
