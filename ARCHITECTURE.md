# Architecture Summary

This project implements a **Clean Architecture** combined with a **Feature-First** structure.

## Architectural Layers

```
                       ┌────────────────────────┐
                       │   Presentation Layer   │ (Widgets, Controllers/Notifiers)
                       └───────────┬────────────┘
                                   │
                       ┌───────────▼────────────┐
                       │    Application Layer   │ (Use Cases / Service Layer)
                       └───────────┬────────────┘
                                   │
                       ┌───────────▼────────────┐
                       │      Domain Layer      │ (Entities, Value Objects, Repository Interfaces)
                       └───────────▲────────────┘
                                   │
                       ┌───────────┴────────────┐
                       │       Data Layer       │ (Models, Repositories Impl, Data Sources)
                       └────────────────────────┘
```

- **Domain Layer:** The core business rules and entities. It is completely independent of frameworks, databases, or UI.
- **Data Layer:** Handles data retrieval and serialization. Implements repository interfaces defined in the Domain layer.
- **Application Layer:** Orchestrates business flow using Use Cases.
- **Presentation Layer:** Widgets, UI state, and user interactions.

## State Management and Navigation

- **State Management:** [Riverpod](https://pub.dev/packages/flutter_riverpod) is recommended for state management and dependency injection.
- **Navigation:** [GoRouter](https://pub.dev/packages/go_router) manages app routing and deep linking.

## Reference Documentation

For detailed blueprints, see:
- [System Architecture (docs/blueprint/SYSTEM_ARCHITECTURE.md)](file:///d:/Development/lending_nelson/docs/blueprint/SYSTEM_ARCHITECTURE.md)
- [Domain Model (docs/blueprint/DOMAIN_MODEL.md)](file:///d:/Development/lending_nelson/docs/blueprint/DOMAIN_MODEL.md)
- [Data Flow (docs/blueprint/DATA_FLOW.md)](file:///d:/Development/lending_nelson/docs/blueprint/DATA_FLOW.md)
