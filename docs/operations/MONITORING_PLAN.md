# Monitoring & Observability Plan - Lending Nelson

This plan outlines the monitoring systems and metrics required to track application health and security in production.

---

## 📲 Client-Side Crash Reporting

- **Firebase Crashlytics Integration:**
  - Automatically captures uncaught Dart exceptions and native crash logs.
  - Prioritizes fixes based on crash frequency and impact (e.g., blocking launch).
- **Network Latency Logging:**
  - Reports slow API requests (> 2000ms) to Firebase Performance Monitoring to identify weak connectivity zones in the field.

---

## 🖥️ Server-Side System Observability

The backend API must record and trigger alerts for the following metrics:

### 1. Availability & Performance
- **API Health Check:** Standard ping endpoint (`/health`) polled every 60 seconds to track uptime.
- **Slow Query Log:** Alerts developers for database queries taking > 500ms to resolve.

### 2. Operational & Transaction Failures
- **Failed Payments:** Monitor and alert if payment capture endpoints return 5xx server errors.
- **Duplicate Transactions:** Log when the backend receives an idempotency key that already exists in the transaction cache.
- **Sync Failures:** Track the ratio of sync errors (e.g., schema mismatches) reported during offline uploads.

### 3. Authentication & Security
- **Failed Logins:** Trigger alerts if a single user account experiences > 5 failed login attempts in 10 minutes (potential brute force).
- **Security Alerts:** Log attempts to access resources without proper role permissions.

---

## 🚨 Alerts & Operations Metrics Dashboard

- **Alert Integration:** Connect critical alerts (e.g., API down, high database CPU usage) directly to communication channels (e.g., Slack, Discord, or SMS alerts).
- **Daily Operations Dashboard:** Create a read-only monitoring console for branch managers tracking payment sync success rates.
