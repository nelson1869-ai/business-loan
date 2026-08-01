# Borrower Mobile Application Architecture

## System Overview
The Borrower Mobile Application (`apps/borrower_mobile`) is an online-first, security-hardened Flutter client designed for borrowers to manage loans, view balances, request OTP verification, and receive account updates.

```
apps/borrower_mobile/
├── android/                   # Native Android Platform (com.nelson.lending.borrower)
├── lib/
│   ├── app/                   # App entrypoint, GoRouter configuration, design theme
│   │   ├── router.dart
│   │   ├── theme/
│   ├── core/                  # Shared utilities, HTTP client, storage, auth notifier
│   │   ├── api/               # Dio ApiClient & AuthInterceptor
│   │   ├── auth/              # AuthNotifier, AuthState state management
│   │   ├── storage/           # Flutter Secure Storage for JWT access/refresh tokens
│   │   └── widgets/           # AppButton, AppTextField UI components
│   └── features/
│       ├── authentication/    # LoginScreen, OtpScreen
│       └── home/              # HomeScreen
└── test/                      # Unit & Widget Tests
```

## Architectural Principles
1. **Feature-First Clean Architecture**: Presentation, core state, and data access layers are strictly isolated. Business logic resides in `AuthNotifier` and `ApiClient`, never in Widgets.
2. **GoRouter Declarative Navigation**: App state is driven by Riverpod (`authNotifierProvider`), enabling GoRouter to perform declarative auth redirects (`/` -> `/login` when unauthenticated, `/login` -> `/home` when authenticated).
3. **Secure Token Storage**: Access and refresh tokens are stored exclusively using `FlutterSecureStorage` (`EncryptedSharedPreferences` on Android).
4. **Resilient Interceptor-Driven Refresh**: Automatic token refresh is managed by `AuthInterceptor` using a dedicated, un-intercepted `Dio` instance (`_refreshDio`) with a `Completer` concurrency lock.
