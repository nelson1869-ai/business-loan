# Environment Setup Guide - Lending Nelson

This guide details the local setup requirements and development workflows for the `lending-nelson` project.

---

## 💻 Verified Development Environment

* **Operating System:** Windows 11
* **Project Path:** `D:\Development\lending_nelson`
* **Editor:** Antigravity (integrated workspace)
* **Terminal:** PowerShell Core
* **Flutter Version:** Stable Channel
* **Target Platform:** Android SDK (API Level 34 compatible)
* **Git Repository:** <https://github.com/nelson1869-ai/business-loan>

---

## 🛠️ Installation & Setup Steps

### 1. Flutter & Android SDK
1. Download and extract the Flutter SDK from the official website.
2. Add the `flutter/bin` directory to your user account's PATH environment variables.
3. Install Android Studio, download the Android SDK platform tools, and accept the licenses:
   ```powershell
   flutter doctor --android-licenses
   ```
4. Verify the setup by running:
   ```powershell
   flutter doctor -v
   ```

### 2. Open Project in Antigravity
Open PowerShell and navigate to the project directory:
```powershell
Set-Location D:\Development\lending_nelson
flutter pub get
```

---

## 📱 Device & Emulator Workflow

### Using the Android Emulator
1. List available virtual devices:
   ```powershell
   flutter emulators
   ```
2. Launch a virtual device:
   ```powershell
   flutter emulators --launch <emulator_id>
   ```
3. Run the application:
   ```powershell
   flutter run
   ```

### Using a Physical Android Device
1. Enable **Developer Options** and **USB Debugging** on the target device.
2. Connect the device via USB or Wi-Fi.
3. Verify the connection:
   ```powershell
   flutter devices
   ```
4. Run the application on the target device:
   ```powershell
   flutter run -d <device_id>
   ```

---

## 🔄 Hot Reload & Hot Restart Workflow

While the app is running in debug mode (`flutter run`):
- **Hot Reload (`r`):** Compiles and injects updated source code changes into the running Dart VM, preserving state. Use this to tweak UI layouts, change colors, or adjust text formatting.
- **Hot Restart (`R`):** Recompiles the source code and restarts the application state from scratch. Use this when modifying state providers, database configurations, routing setup, or initialization routines.
- **Quit (`q`):** Terminates the active running session.
