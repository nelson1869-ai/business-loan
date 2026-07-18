# Coding Standards & Conventions - Lending Nelson

These guidelines enforce code quality, security, and maintainability across the `lending-nelson` codebase.

---

## 🎨 Code Style & Naming

### 1. Formatting
- Use standard Dart formatting:
  ```powershell
  dart format lib test
  ```

### 2. File Naming
- Use `lower_case_with_underscores` for all files:
  - Good: `borrower_form_screen.dart`, `loan_repository.dart`
  - Bad: `borrowerFormScreen.dart`, `Loan_Repository.dart`

### 3. Class Naming
- Use `UpperCamelCase` for classes and mixins:
  - `class LoanCalculator`
- Use `lowerCamelCase` for variable names and constants.

---

## 📦 Riverpod State Conventions

- Always prefix providers with their scope.
- Use code generation (`@riverpod`) where possible to reduce boilerplate:
  ```dart
  @riverpod
  class ActiveLoansNotifier extends _$ActiveLoansNotifier {
    @override
    FutureOr<List<Loan>> build() => ref.read(loanRepositoryProvider).getLoans();
  }
  ```
- Widgets must not inherit or manage complex mutable state directly; delegate all mutations to a Riverpod notifier controller.

---

## 📐 Widget Guidelines

- **Size Limit:** No single Widget file should exceed 200 lines of code. If it grows larger, extract sub-layouts into private local widgets or separate shared widgets.
- **No Business Logic:** Widgets are strictly for presentation.
- **No Direct API/DB Calls:** UI widgets must never trigger raw HTTP requests or SQLite queries directly. They must call an Application Use Case or Notifier Provider instead.
- **No Business Calculations in UI:** Never compute interest rates, amortization, or penalties directly inside a `build` method. These computations belong in pure domain calculators.

---

## 🏛️ Domain & Data Layer Boundaries

- **Pure Domain Entities:** Domain classes must contain zero annotations or dependencies on JSON serialization packages (like `json_serializable`). Keep them as plain Dart objects.
- **Repositories Contract:** Data requests must go through a Repository interface defined in the Domain layer, with implementation code residing in the Data layer.
- **Null Safety:** Enable strict type safety checks in `analysis_options.yaml`. Never use the force-unwrap operator (`!`) without explicit null verification.

---

## 🔒 Security & Secrets

- **No Secrets in Git:** Hardcoding passwords, API tokens, keystore keys, or client credentials in source files is strictly prohibited.
- **Use Environment Variables:** Load external addresses and client keys using Dart defines (`String.fromEnvironment`).
- **Log Sanitation:** Do not print sensitive PII (Full Name, Phone, ID) or credentials (JWTs, session tokens) in application logs.
