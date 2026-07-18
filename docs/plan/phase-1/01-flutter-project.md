# Lesson 1 - Flutter Project

## Objective

Create the starter Flutter application and understand its main files.

## Completed work

- [x] Created the Flutter project named `lending_nelson`.
- [x] Added the main application entry point at `lib/main.dart`.
- [x] Added package configuration in `pubspec.yaml`.
- [x] Generated locked dependencies in `pubspec.lock`.
- [x] Added analyzer rules in `analysis_options.yaml`.
- [x] Added the generated starter widget test in `test/widget_test.dart`.
- [x] Generated Flutter's standard platform folders.

## Important files

| File | Purpose |
| --- | --- |
| `lib/main.dart` | Starts the application and contains the starter UI |
| `pubspec.yaml` | Defines the app version, SDK, dependencies, and assets |
| `pubspec.lock` | Records the exact resolved dependency versions |
| `analysis_options.yaml` | Configures Dart analysis and lint rules |
| `test/widget_test.dart` | Contains the generated starter widget test |

## Verification commands

```powershell
flutter pub get
dart format lib test
flutter analyze
flutter test
```

## Student takeaway

Flutter application code belongs primarily in `lib/`. Dependencies and assets must be
declared in `pubspec.yaml`. Analysis and tests help detect problems before building.
