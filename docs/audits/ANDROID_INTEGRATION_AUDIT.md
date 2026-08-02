# Android Integration Audit

## Scope

This audit records the Flutter architecture inspected before adding officer UI
access to backend capabilities introduced in migrations 021 through 031. The
borrower application's product scope was preserved.

## Officer application

The officer application uses feature-first folders, GoRouter, Riverpod, Dio,
secure token storage, encrypted SQLite, and a durable offline synchronization
queue. Existing screens cover authentication, dashboard, borrowers, borrower
registration and details, loans, schedules, payments, receipts, collection
tasks, notifications, documents, notes, guarantors, emergency contacts,
settings, conflict handling, reports, and the administrative assistant.

Existing repositories remain responsible for borrowers, loans, payments,
collection tasks, documents, notes, notifications, users, business settings,
and dashboard projections. The backend remains the authoritative source for
financial calculations. Existing offline mutations are ordered borrower,
loan, then payment and replayed using durable request identifiers.

The previously missing officer integrations were versioned policies,
maker-checker approvals, cash collection sessions, immutable accounting
journals, and the new reproducible operational reports. These integrations are
online-only and do not write to or extend the offline mutation queue.

## Borrower application

The borrower application contains invitation and registration, OTP
authentication, dashboard, loan list and detail, schedule, payment history,
digital receipts, profile, notification, device/session management, encrypted
account-keyed cache isolation, logout, and cached loading/empty/error/offline
states. No staff or operational-control feature was added.

## Navigation

Both applications use GoRouter. The officer application retains its existing
dashboard, borrower, and settings shell. A permission-aware Operations route
now links to policy, approval, collection-session, accounting, and operational
report pages. Existing routes were not renamed or removed.

## Permissions

The access token contains the backend-issued user ID and role. The officer UI
uses those claims only to hide unavailable navigation and actions. This is a
presentation hint, not an authorization decision: every request continues to
be authorized by the backend permission dependency. Maker-created approval
requests and policy drafts cannot be self-approved in the UI, and the backend
independently enforces that rule.

## Offline boundary

Existing borrower, loan, and payment offline workflows are unchanged. Policy
activation or retirement, approval decisions, collection reconciliation,
deposits, accounting access, and operational reporting require a reachable
backend and display an online-required notice. No sensitive transition is
queued for later replay.
