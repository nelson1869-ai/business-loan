<div align="center">

# ================ LENDING NELSON ================

### Flutter Android Development Cheat Sheet

**Terminal:** PowerShell &nbsp;|&nbsp; **Branch:** `main` &nbsp;|&nbsp; **Target:** Android

</div>

---

## Quick start

Open PowerShell in the project directory:

```powershell
Set-Location D:\Development\lending_nelson
flutter pub get
flutter run
```

> **Project remote:** <https://github.com/nelson1869-ai/business-loan.git>

---

## Git setup

The repository is already initialized. These are the commands used:

```powershell
git init
git branch -M main
git remote add origin https://github.com/nelson1869-ai/business-loan.git
git remote -v
```

### First commit and push

```powershell
git status
git add .
git commit -m "Initial Flutter Android project"
git push -u origin main
```

> **Important:** If the GitHub repository already has commits, inspect them before
> the first push with `git fetch origin` and `git log --oneline --all --graph`.

---

## Daily Git workflow

| Task | PowerShell command |
| --- | --- |
| Check changes | `git status` |
| Review unstaged changes | `git diff` |
| Review staged changes | `git diff --staged` |
| Stage everything | `git add .` |
| Commit | `git commit -m "Describe the change"` |
| Get remote changes | `git pull --rebase origin main` |
| Push changes | `git push origin main` |
| Recent history | `git log --oneline --decorate -10` |

---

## Flutter development

### Setup and diagnostics

```powershell
flutter doctor -v        # Check Flutter, Dart, Android SDK, and Java
flutter pub get          # Install dependencies
flutter pub outdated     # Check for newer dependency versions
```

### Devices and emulators

```powershell
flutter devices
flutter emulators
flutter emulators --launch <emulator-id>
flutter run -d <device-id>
```

### Quality checks

```powershell
dart format lib test
flutter analyze
flutter test
```

### Run the app

```powershell
flutter run
```

While the app is running:

| Key | Action |
| --- | --- |
| `r` | Hot reload |
| `R` | Hot restart |
| `p` | Show performance overlay |
| `q` | Stop the app |

---

## Android builds

| Build | Command | Output |
| --- | --- | --- |
| Debug APK | `flutter build apk --debug` | `build\app\outputs\flutter-apk\` |
| Release APK | `flutter build apk --release` | `build\app\outputs\flutter-apk\` |
| Play Store bundle | `flutter build appbundle --release` | `build\app\outputs\bundle\release\` |

Reset generated build files when troubleshooting:

```powershell
flutter clean
flutter pub get
```

---

## Project reference

| Item | Current value or location |
| --- | --- |
| Flutter package | `lending_nelson` |
| Android application ID | `com.example.lending_nelson` |
| Java/Kotlin target | Java 17 |
| Main entry point | `lib\main.dart` |
| Dependencies and version | `pubspec.yaml` |
| Android build configuration | `android\app\build.gradle.kts` |
| VS Code settings | `.vscode\settings.json` |
| VS Code recommendations | `.vscode\extensions.json` |

> **Before publishing:** Replace the example Android application ID and configure
> a secure release signing key. Never commit signing passwords or private keys.

---

## Troubleshooting

```powershell
# Confirm the repository, branch, and remote.
git rev-parse --show-toplevel
git branch --show-current
git remote -v

# Inspect the Flutter environment.
flutter doctor -v

# Repair generated project state.
flutter clean
flutter pub get
flutter analyze
```

---

<div align="center">

**Lending Nelson - Build carefully, test often, commit clearly.**

</div>
