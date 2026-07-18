# Integration Blueprint - Lending Nelson

This blueprint documents external integrations, defining which components are verified, proposed, or undecided.

---

## 🔌 API & Workflow Integrations

### 1. Primary Backend REST API
* **Status:** **Proposed / Undecided Framework**
* **Role:** Serves as the primary source of truth. Handles business calculations, user permissions, database storage, and serves JSON endpoints to the Flutter client.

### 2. n8n Automation Engine
* **Status:** **Proposed**
* **Role:** n8n will orchestrate complex workflow logic behind the scenes, triggered by backend webhooks:
  - *Trigger:* Borrower Registered ➔ *Action:* Trigger background identity verification search.
  - *Trigger:* Loan Application Approved ➔ *Action:* Assemble PDF contract, save in Cloud Storage, and send a notification.
  - *Trigger:* Daily Chronometer ➔ *Action:* Check for active loans overdue by >3 days, queue late fee notifications.

---

## 💬 Notification Channels

### 3. SMS Gateway (Twilio / Africa's Talking / TBC)
* **Status:** **Proposed**
* **Role:** Sends text messages for receipt transactions, late warnings, and PIN verification.

### 4. Email Services (SendGrid / Mailgun / TBC)
* **Status:** **Proposed**
* **Role:** Delivers monthly statements, loan schedules, and staff audit reports.

### 5. Mobile Push Notifications (Firebase Cloud Messaging - FCM)
* **Status:** **Proposed**
* **Role:** Alerts loan officers on application status changes (e.g., "Application Approved by Manager").

---

## 💳 Financial & Accounting Systems

### 6. Mobile Money / Payment Gateways (M-Pesa / Stripe / Paystack / TBC)
* **Status:** **Undecided**
* **Role:** Future integration to automate loan disbursement and direct payment collections. First release will rely on manual tracking of cash/transfers.

### 7. Accounting Platforms (QuickBooks / Xero / TBC)
* **Status:** **Undecided**
* **Role:** Syncing of daily lending transactions to double-entry accounting ledgers.

---

## 📁 Support & Infrastructure

### 8. Cloud Storage (Google Cloud Storage / AWS S3 / TBC)
* **Status:** **Proposed**
* **Role:** Secure storage for borrower identity files, contract PDFs, and system backups.

### 9. Document Generation Service
* **Status:** **Proposed (via n8n or server-side library)**
* **Role:** Creates signed PDF loan contracts using standard HTML-to-PDF templates.

### 10. Product Analytics (Firebase Analytics / TBC)
* **Status:** **Proposed**
* **Role:** Tracking app crashes, load times, and feature usage patterns.
