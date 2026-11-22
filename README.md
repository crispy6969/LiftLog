# Liftlog

A private, offline weightlifting tracker built with Flutter, Dart and SQLite.
Android is the initial development target; an iOS project is included for later
builds and device testing on macOS. No backend, real account, subscription or exercise
database is required. New installations start empty.

## What is included

- Create/rename exercises and split days; exercises can belong to multiple splits.
- Search exercises and combine search with a split or Unassigned filter.
- Log ordered sets in kilograms and fractional repetitions (up to one decimal).
- See each matching set from the latest saved performance beside the current input; new entries start with the same number of blank sets.
- Assign exercises to one gym or Any location; combine location, split and search filters.
- Track one body-weight measurement per day, with notes and a time-based graph.
- Use mock Log in/Sign up forms; all credentials, including blank fields, work.
- Compare against newest-first history and calendar-day intervals.
- Correct/delete entries and archive/restore exercises without losing history.
- Resume one automatically saved unfinished draft per exercise, including edits.
- Export readable JSON and restore a validated backup by replacing current data.
- System light/dark theme, numeric input, inline validation and empty states.

## Version 1.1 update

Bottom navigation has Workout, Weight, Manage and Profile. Manage contains exercises, locations and split days; Profile → Settings contains Backup & restore. Mock login is required after a cold start. It has no server check, stores no password, and all mock logins share this device’s local data. Logging out keeps that data.

The schema upgrades from v1 to v2 automatically, preserving history, notes, memberships and drafts. Existing exercises become Any location, and stored whole reps are converted to exact tenths (7 becomes 70 internally and still displays as 7). Backups exported by version 1 remain importable; new exports use format 2 and include locations and body weights. Export a backup before updating, then install the new APK with `adb install -r` using the same signing key.

## Run on Android

Use Flutter stable (developed with **Flutter 3.50.0 / Dart 3.14.0**), Android
Studio with its bundled JDK, Android SDK command-line tools and platform-tools.
The dependency lockfile is included. There is no need to install Dart or a
separate JDK when using the bundled tools.

In Android Studio's **SDK Manager**, install **Android SDK Platform 36** and
**Android SDK Platform 35** (one native dependency compiles against 35). Under
**SDK Tools**, enable **Show Package Details** and install **NDK (Side by side)
28.2.13676358**, the version selected by Flutter 3.50. Installing API 37 alone
does not supply the older platforms. These components are free.

If automatic NDK installation reports `Package ndk not found` and then reports
the version as another missing package, install the components directly using
the new Android CLI's slash-style package paths, from your normal terminal:

```powershell
& 'E:\coding_stuff\Android\Sdk\cmdline-tools\latest\bin\android.exe' `
  --sdk='E:\coding_stuff\Android\Sdk' sdk install `
  'ndk/28.2.13676358' 'platforms/android-36' 'platforms/android-35'
```

Alternatively use the Android Studio SDK Manager selections above. Keep the
project's `flutter.ndkVersion` setting; do not substitute a random NDK version.

On this machine Flutter is installed at `E:\coding_stuff\flutter`. Add its
`bin` directory to PATH through Windows environment settings, then open a new
terminal. For the current PowerShell session only:

```powershell
$env:Path = 'E:\coding_stuff\flutter\bin;' + $env:Path
```

From this repository:

```powershell
flutter doctor -v
flutter doctor --android-licenses
flutter precache --android
flutter pub get
flutter devices
flutter run -d <android-device-id>
```

Enable Developer options and USB debugging on your phone, connect a data-capable
USB cable, and accept the RSA authorization prompt. Alternatively start an
Android Studio emulator. Windows desktop/Visual Studio and Chrome warnings do
not prevent Android development. If the phone is missing, check:

```powershell
& 'E:\coding_stuff\Android\Sdk\platform-tools\adb.exe' devices -l
```

The device should say `device`, not `unauthorized` or `offline`. Some Windows
phones require their manufacturer's USB driver. If Flutter cannot find your
custom SDK/JDK locations, configure them explicitly:

```powershell
flutter config --android-sdk 'E:\coding_stuff\Android\Sdk'
flutter config --jdk-dir 'E:\coding_stuff\Android_Studio\jbr'
```

The first build downloads Flutter engine files and Gradle/Android dependencies.
It needs ordinary internet access; subsequent workout logging needs none.
`android/gradle.properties` keeps `kotlin.incremental=false` to avoid the Kotlin
plugin compilation failure encountered on this Windows setup. This can make
subsequent native builds slower; it does not affect workout logging or storage.
The ignored `.tools` directory is a workspace-local tooling cache used by the
restricted development session, not an application dependency. Normal terminals
should use your installed Flutter SDK.

## Checks and tests

```powershell
flutter analyze
flutter test
flutter test integration_test/workout_test.dart -d <android-device-id>
```

Unit/repository/widget tests use an in-memory SQLite database through
`sqflite_common_ffi`. Its native library downloads automatically on the first
test run. Layout tests generate `build/screenshots/logging.png` and `history.png`.
The Android integration test uses its own database and leaves personal history
alone. Physical-device testing of keyboard behavior, sharing and the file picker
is still necessary before relying on the app for workouts.

For an offline Windows test run with an existing SQLite DLL, the optional helper
temporarily supplies its path to the native-assets hook and restores the manifest
afterward:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tool/test.ps1 `
  -Flutter 'E:\coding_stuff\flutter\bin\flutter.bat' `
  -SqliteLibrary 'C:\path\to\sqlite3.dll'
```

That override applies only to the test invocation. The mobile app uses `sqflite`,
not that desktop DLL. Normal online tests need no helper or extra SQLite install.

## Installable APK and signing

For a temporary test APK:

```powershell
flutter build apk --debug
```

The file is `build/app/outputs/flutter-apk/app-debug.apk`. Debug signing is for
development. Before long-term personal use, create and retain a private release
key. The helper refuses to overwrite an existing key/configuration:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tool/create_signing_key.ps1 `
  -Keytool 'E:\coding_stuff\Android_Studio\jbr\bin\keytool.exe'
flutter build apk --release
```

The release APK is `build/app/outputs/flutter-apk/app-release.apk`. Back up both
`.keys/liftlog-release.jks` and `android/key.properties` securely; both are ignored
by version control. The properties file contains the generated key password.
Release builds intentionally fail until signing is configured.

Keep the application ID (`dev.personal.liftlog`) and signing key unchanged for
updates, and increment `version` in `pubspec.yaml`. Switching from a debug-signed
installation to release signing usually requires uninstalling it: **export your
data first**, install the release, then restore. Do not uninstall to fix an update
error without first exporting the data.

## Using and protecting your data

Tap **Create** to add an exercise or split day. Tap an exercise to log sets and
browse its history. Enter **0 kg** for bodyweight alone; record assistance in an
exercise name or note. Notes are attached to the entire entry. Weight accepts
three decimal places using `.` or `,`; reps must be positive with at most one decimal (for example 7.5).

Use the exercise menu to change its name/memberships or archive it. Deleting a
split day keeps exercises and history. An exercise with entries cannot be
permanently deleted; archive it, or deliberately remove its entries first.
Only saved entries contribute to history and last-performed labels.

**Backup & restore** is under Profile → Settings. Export regularly and keep a copy off
the phone. App-private data survives normal restarts and upgrades, but uninstall,
clearing app data or losing the phone can destroy it. Platform automatic backup
is not a recovery guarantee. Exports are unencrypted and contain notes/drafts.
Restore validates the entire file and asks before replacing all current records;
it does not merge datasets. Canceling a share sheet does not create a backup.

## Structure and future iOS use

```text
lib/core/          SQLite setup/schema and value/date formatting
lib/features/      Exercises, split days, entries/controllers, backup
lib/shared/        Shared UI helpers and Material compatibility facade
test/              Database/repository, validation and widget tests
integration_test/  Native persistence/edit/restore journey
android/           Android application and release signing configuration
ios/               iOS scaffold; requires macOS/Xcode and device validation
tool/              Optional offline test and signing helpers
docs/              Architecture, schema relationships and migration guidance
```

See [architecture.md](docs/architecture.md) and the authoritative
[SQL schema](lib/core/database/schema.sql) for data contracts and migrations.

On a Mac, install Flutter and Xcode, run `flutter doctor`, resolve any requested
Apple tooling, run `flutter pub get`, then `flutter run -d <ios-device-id>`.
Configure an Apple development team in the Runner project for a real iPhone.
The scaffold targets iOS 15+. Test all plugins and phone layouts before claiming
iOS support; an Android build does not validate iOS. Personal Apple provisioning
has limitations and broader distribution can require paid membership.

PR tracking, timers, pounds, cloud synchronization, automatic backups and
grouped workout sessions are future features, not requirements of this version.
