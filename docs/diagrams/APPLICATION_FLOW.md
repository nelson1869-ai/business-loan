# Application User Flow

This diagram illustrates the navigation pathways for field staff interacting with the mobile client.

```mermaid
flowchart TD
    classDef screen fill:#FFF3E0,stroke:#FFE0B2,color:#E65100;
    classDef action fill:#E0F7FA,stroke:#B2EBF2,color:#006064;

    SPLASH["Splash Screen\n(lib/features/splash/presentation/splash_screen.dart)"]:::screen
    LOGIN["Login Screen\n(lib/features/auth/presentation/login_screen.dart)"]:::screen
    DASH["Main Dashboard\n(lib/features/dashboard/presentation/dashboard_screen.dart)"]:::screen
    BORR["Borrowers List\n(lib/features/dashboard/presentation/borrower_list_screen.dart)"]:::screen
    B_DETAIL["Borrower Detail Profile\n(Planned details screen)"]:::screen
    B_ADD["Add Borrower Form\n(lib/features/dashboard/presentation/borrower_registration_screen.dart)"]:::screen
    L_APP["New Loan Application Form\n(Planned)"]:::screen
    LOANS["Loans Overview\n(Planned)"]:::screen
    L_DETAIL["Active Loan Details\n(Planned)"]:::screen
    PAY["Log Payment Form\n(Planned)"]:::screen
    REP["Reports Panel\n(Planned)"]:::screen
    SET["Settings / Sync Panel\n(lib/features/dashboard/presentation/settings_screen.dart)"]:::screen

    SPLASH -->|Auth Check Failed| LOGIN
    SPLASH -->|Auth Check Passed| DASH
    LOGIN -->|Authenticate| DASH
    
    DASH --> BORR
    DASH --> LOANS
    DASH --> REP
    DASH --> SET
    
    BORR --> B_DETAIL
    BORR --> B_ADD
    B_ADD -->|Save| B_DETAIL
    
    B_DETAIL --> L_APP
    L_APP -->|Submit| LOANS
    
    LOANS --> L_DETAIL
    L_DETAIL --> PAY
    PAY -->|Confirm Transaction| L_DETAIL
```

---

### File References

* **Splash Screen:** [splash_screen.dart](file:///d:/Development/lending_nelson/lib/features/splash/presentation/splash_screen.dart)
* **Login Screen:** [login_screen.dart](file:///d:/Development/lending_nelson/lib/features/auth/presentation/login_screen.dart)
* **Dashboard Screen:** [dashboard_screen.dart](file:///d:/Development/lending_nelson/lib/features/dashboard/presentation/dashboard_screen.dart)
* **Borrower List Screen:** [borrower_list_screen.dart](file:///d:/Development/lending_nelson/lib/features/dashboard/presentation/borrower_list_screen.dart)
* **Borrower Registration Screen:** [borrower_registration_screen.dart](file:///d:/Development/lending_nelson/lib/features/dashboard/presentation/borrower_registration_screen.dart)
* **Settings Screen:** [settings_screen.dart](file:///d:/Development/lending_nelson/lib/features/dashboard/presentation/settings_screen.dart)
* **Router Config:** [app_router.dart](file:///d:/Development/lending_nelson/lib/app/app_router.dart)
* **Theme Config:** [app_theme.dart](file:///d:/Development/lending_nelson/lib/app/app_theme.dart)
* **Database Cache:** [database_service.dart](file:///d:/Development/lending_nelson/lib/core/database/database_service.dart)

