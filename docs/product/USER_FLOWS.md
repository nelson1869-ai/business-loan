# User Flows - Lending Nelson

This document details the step-by-step user journeys for core system operations.

---

## 🔐 1. Login Flow
1. User opens the application.
2. If the user does not have a saved token, they are prompted to input their Username and Password.
3. User clicks **Login**.
4. The application submits credentials to the server.
5. On validation success:
   - Server returns JWT tokens.
   - App stores tokens in [Secure Storage](file:///d:/Development/lending_nelson/docs/blueprint/SYSTEM_ARCHITECTURE.md).
   - App redirects the user to the dashboard.
6. On error, the app displays helpful validation messages (e.g., "Invalid username or password").

---

## 🧑 2. Register Borrower (Offline-Capable)
1. Loan Officer clicks **Add Borrower** from the dashboard.
2. Officer inputs Borrower PII: First Name, Last Name, National ID, Phone, Street Address.
3. Officer uploads files (Image/PDF) of borrower identification documents.
4. Officer reviews details and clicks **Submit**.
5. **App checks connectivity status:**
   - **If Online:** App uploads the details to the API (`POST /api/borrowers`) and updates local status to `Synced`.
   - **If Offline:** App writes the record to the local SQLite database with status `Pending` and inserts the sync task into the synchronization queue.
6. App displays confirmation screen: "Borrower Registered."

---

## 📝 3. Submit Loan Application
1. Loan Officer selects a borrower.
2. Officer clicks **Create Loan Application**.
3. Officer selects a pre-configured **Loan Product**.
4. App renders the loan limits, interest rates, and fee rules.
5. Officer inputs the loan Amount and Term.
6. App calculates and displays the estimated monthly installment payment.
7. Officer adds guarantor details and clicks **Submit**.
8. Application details are saved and uploaded to the server with status `Under Review`.

---

## ⚖️ 4. Review & Approval Flow
1. Branch Manager logs into the system.
2. Manager navigates to the **Applications Review** tab.
3. Manager selects a loan application status marked `Under Review`.
4. Manager reviews borrower profile, document attachments, and guarantor details.
5. Manager enters review comments.
6. Manager clicks **Approve** or **Reject**.
7. App submits status update to the server. On approval, the loan status transitions to `Approved`.

---

## 💵 5. Disbursement & Repayment Generation
1. Loan Officer selects an application marked `Approved`.
2. Officer logs disbursement details: Date, Amount Disbursed, Payment Method (Cash/Bank/Wallet), and Receipt ID.
3. Officer clicks **Disburse**.
4. The system:
   - Sets the Loan Status to `Active`.
   - Generates the official **Repayment Schedule** installment dates and breakdown.
   - Restricts updates to the loan contract terms.

---

## 💳 6. Payment Collection & Receipt Share
1. Cashier selects a borrower.
2. Cashier inputs payment Amount and selects the Payment Method.
3. Cashier clicks **Log Payment**.
4. System:
   - Generates a unique transaction UUID.
   - Inserts payment to the local database.
   - Adjusts the outstanding balance on the active loan schedule.
   - Dispatches a webhook to trigger an SMS payment notification.
5. App displays a "Payment Confirmed" layout with a receipt summary.
6. Cashier clicks **Share Receipt** to export a PDF receipt.

---

## 🛜 7. Work Offline & Sync Data
1. System detects network disconnection and prompts: "Running in Offline Mode."
2. Collector logs a repayment payment while offline.
3. App generates the transaction UUID, stores the payment details locally as `Pending`, and appends the action to the sync queue.
4. When connection is restored:
   - System displays: "Connection Restored. Syncing details..."
   - App dispatches queued items sequentially to the server (`POST /api/payments/sync`).
   - On success, the local status is updated to `Synced`.
