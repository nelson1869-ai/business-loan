# Lending Nelson

A modern Flutter business loan and lending application.

[![Flutter Analyze](https://img.shields.io/badge/flutter-analyze-blue.svg)](file:///d:/Development/lending_nelson/PROJECT_STATUS.md)
[![Flutter Test](https://img.shields.io/badge/flutter-test-green.svg)](file:///d:/Development/lending_nelson/PROJECT_STATUS.md)

## Project Overview

`lending-nelson` is a mobile application designed to manage lending operations, track borrower records, manage loan products, handle application workflows, structure repayments, collect payments, and sync records offline. 

- **Primary Target:** Android mobile devices.
- **Secondary Targets:** Web Admin Panel and Windows client (planned for future releases).

---

## Current Status

We are currently in **Phase 1: Documentation and Architecture Blueprint**. The initial repository setup, Android package ID customization (`com.nelson.lending`), Git integration, and foundational codebase have been verified.

For a detailed dashboard of current progress, check out [PROJECT_STATUS.md](file:///d:/Development/lending_nelson/PROJECT_STATUS.md).

---

## Tech Stack

* **Framework:** [Flutter Stable](https://flutter.dev/)
* **State Management & DI:** [Riverpod](https://riverpod.dev/) (Planned)
* **Navigation:** [GoRouter](https://pub.dev/packages/go_router) (Planned)
* **API Client:** [Dio](https://pub.dev/packages/dio) (Planned)
* **Local Database:** Secure Storage (for auth keys) and SQLite/Hive/Isar (for offline sync, TBC)

---

## Repository Structure

```
lending_nelson/
├── android/            # Android native project config
├── ios/                # iOS native project config
├── lib/                # Flutter source code (to be structured feature-first)
├── test/               # Unit, widget, and integration tests
├── docs/               # Project blueprints and documentation
│   ├── blueprint/      # Architecture, security, and data flow blueprints
│   ├── planning/       # Roadmap, Milestones, and TODOs
│   ├── development/    # Developer guides, structures, and standards
│   ├── product/        # PRD, user roles, business rules, flows
│   ├── api/            # Proposed API endpoints and error specifications
│   └── operations/     # Releases, deployments, and backup plans
└── README.md           # Project entry point
```

---

## Getting Started

### Prerequisites

Ensure you have the Flutter SDK installed and configured. Verify using:
```powershell
flutter doctor -v
```

### Installation

Clone the repository and install the dependencies:
```powershell
git clone https://github.com/nelson1869-ai/business-loan.git
cd lending_nelson
flutter pub get
```

### Run Commands

To run the application locally on an emulator or physical device:
```powershell
flutter devices
flutter run
```

### Quality & Testing Commands

Run static code analysis and tests before committing:
```powershell
flutter analyze
flutter test
```

---

## Documentation Index

### 🗺️ Planning & Progress
- [Roadmap](file:///d:/Development/lending_nelson/ROADMAP.md) (See also: [Phased Roadmap Detail](file:///d:/Development/lending_nelson/docs/planning/ROADMAP.md))
- [TODO List Dashboard](file:///d:/Development/lending_nelson/TODO.md) (See also: [Actionable TODO Checklist](file:///d:/Development/lending_nelson/docs/planning/TODO.md))
- [Project Status](file:///d:/Development/lending_nelson/PROJECT_STATUS.md)
- [Architecture Index](file:///d:/Development/lending_nelson/ARCHITECTURE.md)
- [Changelog](file:///d:/Development/lending_nelson/CHANGELOG.md)

### 📐 Blueprints & Design
- [Product Vision Blueprint](file:///d:/Development/lending_nelson/docs/blueprint/PRODUCT_BLUEPRINT.md)
- [System Architecture Specification](file:///d:/Development/lending_nelson/docs/blueprint/SYSTEM_ARCHITECTURE.md)
- [Domain Entity Models](file:///d:/Development/lending_nelson/docs/blueprint/DOMAIN_MODEL.md)
- [Data Flow Logic](file:///d:/Development/lending_nelson/docs/blueprint/DATA_FLOW.md)
- [Security Blueprint](file:///d:/Development/lending_nelson/docs/blueprint/SECURITY_BLUEPRINT.md)
- [Offline Synchronisation Plan](file:///d:/Development/lending_nelson/docs/blueprint/OFFLINE_SYNC_BLUEPRINT.md)
- [System Integrations](file:///d:/Development/lending_nelson/docs/blueprint/INTEGRATION_BLUEPRINT.md)

### 💻 Developer Guidelines
- [Development Guide](file:///d:/Development/lending_nelson/docs/development/DEVELOPMENT_GUIDE.md)
- [Project Directory Structure](file:///d:/Development/lending_nelson/docs/development/PROJECT_STRUCTURE.md)
- [Coding Standards & Conventions](file:///d:/Development/lending_nelson/docs/development/CODING_STANDARDS.md)
- [Git Workflow Policy](file:///d:/Development/lending_nelson/docs/development/GIT_WORKFLOW.md)
- [Testing Strategy](file:///d:/Development/lending_nelson/docs/development/TESTING_STRATEGY.md)
- [Environment Setup Guide](file:///d:/Development/lending_nelson/docs/development/ENVIRONMENT_SETUP.md)
- [Definition of Done](file:///d:/Development/lending_nelson/docs/development/DEFINITION_OF_DONE.md)

### 📦 Product Requirements & Rules
- [Product Requirements Document (PRD)](file:///d:/Development/lending_nelson/docs/product/PRODUCT_REQUIREMENTS.md)
- [User Roles & Permissions](file:///d:/Development/lending_nelson/docs/product/USER_ROLES.md)
- [Borrower User Journeys](file:///d:/Development/lending_nelson/docs/product/USER_FLOWS.md)
- [Lending Business Rules](file:///d:/Development/lending_nelson/docs/product/BUSINESS_RULES.md)
- [Workflows Acceptance Criteria](file:///d:/Development/lending_nelson/docs/product/ACCEPTANCE_CRITERIA.md)

### 🔌 API Specs
- [Backend API Plan](file:///d:/Development/lending_nelson/docs/api/API_PLAN.md)
- [API Endpoint Catalog](file:///d:/Development/lending_nelson/docs/api/ENDPOINT_CATALOG.md)
- [Error Handling Protocol](file:///d:/Development/lending_nelson/docs/api/ERROR_HANDLING.md)

### ⚙️ Operations
- [App Store Release Plan](file:///d:/Development/lending_nelson/docs/operations/RELEASE_PLAN.md)
- [Infrastructure Deployment Plan](file:///d:/Development/lending_nelson/docs/operations/DEPLOYMENT_PLAN.md)
- [Monitoring & Logging Setup](file:///d:/Development/lending_nelson/docs/operations/MONITORING_PLAN.md)
- [Backups & Disaster Recovery](file:///d:/Development/lending_nelson/docs/operations/BACKUP_RECOVERY.md)
- [Changelog Process](file:///d:/Development/lending_nelson/docs/operations/CHANGELOG_PROCESS.md)

---

## Visual Documentation

Refer to the visual system diagrams mapping different components and project states:

- **[Master Project Flow](file:///d:/Development/lending_nelson/docs/diagrams/PROJECT_MASTER_FLOW.md)** — Core project lifecycle stages.
- **[Timeline](file:///d:/Development/lending_nelson/docs/diagrams/PROJECT_TIMELINE.md)** — Phased roadmap timeline for Phases 0–20.
- **[System Architecture](file:///d:/Development/lending_nelson/docs/diagrams/SYSTEM_OVERVIEW.md)** — Architectural layers sequence.
- **[Navigation](file:///d:/Development/lending_nelson/docs/diagrams/NAVIGATION_FLOW.md)** — GoRouter visual navigation routes.
- **[Authentication](file:///d:/Development/lending_nelson/docs/diagrams/AUTH_FLOW.md)** — JWT login authentication sequence.
- **[Loan Workflow](file:///d:/Development/lending_nelson/docs/diagrams/LOAN_WORKFLOW.md)** — Borrower application state machine.
- **[Offline Sync](file:///d:/Development/lending_nelson/docs/diagrams/OFFLINE_SYNC.md)** — Local storage sync queues.
- **[Database Model](file:///d:/Development/lending_nelson/docs/diagrams/DATABASE_MODEL.md)** — Domain entity class diagram.
- **[API Architecture](file:///d:/Development/lending_nelson/docs/diagrams/API_ARCHITECTURE.md)** — Data sources and repositories transport map.
- **[Release Flow](file:///d:/Development/lending_nelson/docs/diagrams/RELEASE_FLOW.md)** — Continuous testing deployment pipelines.
- **[Phase Diagrams](file:///d:/Development/lending_nelson/docs/diagrams/INDEX.md#%EF%B8%8F-phased-implementation-map)** — Detailed checklist and diagrams for each phase (00 to 20).

---

## 🔒 Security Warnings & Policy

See [SECURITY.md](file:///d:/Development/lending_nelson/SECURITY.md) for vulnerability reporting and guidelines on preventing sensitive credentials from being committed to the public repository.

## 🤝 Contributing

Contributions must follow the workflow defined in [CONTRIBUTING.md](file:///d:/Development/lending_nelson/CONTRIBUTING.md).
