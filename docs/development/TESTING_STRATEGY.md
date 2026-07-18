# Testing Strategy - Lending Nelson

This document outlines the testing framework and test suites required to maintain application quality.

---

## 🧪 Test Classification

```
                  ┌──────────────────────┐
                  │  Integration Tests   │ (E2E flows, sync, network restoration)
                  └──────────┬───────────┘
                             │
               ┌─────────────▼─────────────┐
               │       Widget Tests        │ (UI layouts, inputs validation, Goldens)
               └─────────────┬─────────────┘
                             │
               ┌─────────────▼─────────────┐
               │        Unit Tests         │ (Calculators, domain validation, models)
               └───────────────────────────┘
```

### 1. Unit Tests
* **Core Calculations:** Enforce 100% test coverage for interest calculations, late fee models, and installment schedules.
* **Domain Validations:** Verify field validation rules (e.g., minimum age constraints, national ID formatting, phone number parsing).
* **Data Deserialization:** Ensure JSON data parsing mapping from API DTOs into Domain Entities is accurate.

### 2. Widget & UI Tests
* **Form Inputs:** Verify that error labels are displayed correctly when invalid text is entered in forms.
* **State Updates:** Test UI changes in response to Riverpod notifier state transitions (e.g., changing loading spinner status during login).
* **Golden Tests:** (Where appropriate) Verify that custom widgets render consistently across different screen densities.

### 3. Integration Tests
* **Offline Operations:** Simulate a network dropout, verify that payments are queued locally, restore the network connection, and confirm that sync operations execute.
* **Authentication Flows:** Verify login, session expiry redirection, and token refresh interceptors.

---

## 🛠️ Testing Targets & Scenarios

### Repository Mocking
- Always use mock data sources (using packages like `mockito` or `mocktail`) rather than connecting to live servers during unit and widget tests:
  ```dart
  class MockLoanRepository extends Mock implements LoanRepository {}
  ```

### API Failure Conditions
- Ensure test cases handle common network failures:
  - HTTP `401 Unauthorized` ➔ Redirect to login.
  - HTTP `409 Conflict` (Idempotent warning) ➔ Handle gracefully on client.
  - HTTP `500 Server Error` ➔ Show user error alerts.
  - Socket exceptions (No network) ➔ Queue request locally.

### Release Smoke Tests
- Prior to Google Play deployment, the QA team must perform a manual smoke test covering:
  - Account login/logout.
  - Onboarding a new borrower.
  - Recording a payment.
  - Verifying data synchronization works from offline to online.
