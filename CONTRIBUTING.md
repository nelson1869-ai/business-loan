# Contributing to Lending Nelson

Thank you for contributing to the `lending-nelson` business loan application! Please follow these guidelines to keep the codebase clean, stable, and secure.

## Local Setup

1. **Prerequisites:** Install Flutter (stable channel), Android SDK, and VS Code.
2. **Setup:**
   ```powershell
   git clone https://github.com/nelson1869-ai/business-loan.git
   cd lending_nelson
   flutter pub get
   ```
3. **Run local quality checks:**
   ```powershell
   dart format lib test
   flutter analyze
   flutter test
   ```

## Git Workflow

- **Branching:** Use short-lived feature branches branched from `main`. For example, `feat/borrower-registration`.
- **Pull Requests:** Submit all changes via PRs to `main`. Ensure all static analysis and tests pass.
- **Commit Messages:** Follow standard prefix conventions:
  - `feat:` for new features
  - `fix:` for bug fixes
  - `docs:` for documentation updates
  - `refactor:` for code refactoring
  - `test:` for writing tests
  - `chore:` for build/dependency updates

## Coding and Security Guidelines

- Run `flutter analyze` and `flutter test` before committing.
- Do not commit any API keys, client secrets, passwords, or keystore files to the repository. Use environment configuration or secure variables.
- Maintain test coverage for financial logic and state transformations.
