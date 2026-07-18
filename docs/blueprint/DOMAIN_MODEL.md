# Domain Model - Lending Nelson

This blueprint details the primary domain entities, fields, relationships, and validations for the lending application. All entities are represented as pure Dart classes within the Domain layer.

---

## 👥 Core Identity Entities

### 1. User
* **Purpose:** Represents system staff members.
* **Suggested Fields:** `id` (UUID), `username` (String), `email` (String), `roleId` (UUID), `branchId` (UUID), `isActive` (bool).
* **Validation Rules:** Email must match standard regex; username cannot be empty.
* **Relationships:** Belongs to a **Branch**; has a **Role**.
* **Sensitive Data:** Username and email are PII; password hashes are handled backend-side only.

### 2. Role & Permission
* **Purpose:** Defines authorization boundaries for users.
* **Suggested Fields:** `id` (UUID), `name` (String - e.g., 'Loan Officer'), `permissions` (List<Permission>).
* **Validation Rules:** Name must be unique.
* **Relationships:** Many-to-Many mapping to Permissions.
* **Sensitive Data:** Access control configurations must be read-only in client space.

---

## 🧑 Borrower Entities

### 3. Borrower
* **Purpose:** Represents the person or business applying for a loan.
* **Suggested Fields:** `id` (UUID), `firstName` (String), `lastName` (String), `nationalId` (String), `dateOfBirth` (DateTime), `addresses` (List<Address>), `contacts` (List<Contact>), `createdAt` (DateTime).
* **Validation Rules:** National ID must match country format; age must be >= 18 years.
* **Relationships:** Has many **Loans** and **Documents**; belongs to a **Branch**.
* **Sensitive Data:** Full PII; national ID and name must be encrypted at rest in local storage.

### 4. Address & Contact
* **Purpose:** Contact points and physical residency of borrowers.
* **Suggested Fields:** `street` (String), `city` (String), `phone` (String), `email` (String), `isPrimary` (bool).
* **Validation Rules:** Phone must match regional pattern; street address cannot be blank.
* **Relationships:** Embedded or linked to Borrower.
* **Sensitive Data:** High PII exposure.

---

## 💰 Lending Entities

### 5. LoanProduct
* **Purpose:** Pre-configured loan templates defining constraints.
* **Suggested Fields:** `id` (UUID), `name` (String), `interestRate` (double), `minAmount` (double), `maxAmount` (double), `minTerms` (int), `maxTerms` (int), `interestMethod` (InterestMethodEnum).
* **Validation Rules:** Rates must be positive; min <= max.
* **Relationships:** Used by **LoanApplication**.
* **Sensitive Data:** Read-only for standard users.

### 6. LoanApplication
* **Purpose:** A request for a loan before approval.
* **Suggested Fields:** `id` (UUID), `borrowerId` (UUID), `productId` (UUID), `amountRequested` (double), `termRequested` (int), `status` (LoanStatus), `officerNotes` (String), `submittedAt` (DateTime).
* **Validation Rules:** Amount must fall within the selected Loan Product's min/max ranges.
* **Relationships:** Belongs to **Borrower** and **LoanProduct**.
* **Sensitive Data:** Financial details.

### 7. Loan & LoanStatus
* **Purpose:** An active financial contract resulting from an approved application.
* **Suggested Fields:** `id` (UUID), `applicationId` (UUID), `borrowerId` (UUID), `principal` (double), `interestRate` (double), `status` (LoanStatusEnum - e.g., Active, Overdue, Closed, Restructured), `disbursedAt` (DateTime).
* **Validation Rules:** Cannot disburse without approval signatures.
* **Relationships:** Has one **RepaymentSchedule** and many **Payments**.
* **Sensitive Data:** Financial ledger details.

### 8. RepaymentSchedule & Installment
* **Purpose:** Defines the structured schedule for repayments.
* **Suggested Fields:** `loanId` (UUID), `installments` (List<Installment>).
* **Installment Fields:** `sequenceNumber` (int), `dueDate` (DateTime), `principalDue` (double), `interestDue` (double), `feesDue` (double), `principalPaid` (double), `interestPaid` (double), `status` (InstallmentStatusEnum).
* **Validation Rules:** Total principal across installments must equal loan principal.
* **Relationships:** Part of **Loan**.

### 9. Payment
* **Purpose:** An allocation of funds received from a borrower.
* **Suggested Fields:** `id` (UUID), `loanId` (UUID), `transactionUuid` (String), `amount` (double), `paidAt` (DateTime), `receivedBy` (UUID), `paymentMethod` (String).
* **Validation Rules:** Amount must be > 0.
* **Relationships:** Belongs to **Loan**.
* **Sensitive Data:** Transaction identifiers must be unique and immutable.

### 10. Penalty
* **Purpose:** Charges applied for late payments.
* **Suggested Fields:** `id` (UUID), `loanId` (UUID), `installmentSequence` (int), `amount` (double), `appliedAt` (DateTime).
* **Relationships:** Linked to an overdue **Installment** on a **Loan**.

---

## 📎 Supporting Entities

### 11. Collateral & Guarantor
* **Purpose:** Securities backing the loan.
* **Suggested Fields:** `id` (UUID), `description` (String), `estimatedValue` (double), `guarantorName` (String), `guarantorPhone` (String).
* **Relationships:** Associated with **LoanApplication**.
* **Sensitive Data:** Guarantor PII.

### 12. Document
* **Purpose:** Signed contracts or identity proofs.
* **Suggested Fields:** `id` (UUID), `borrowerId` (UUID), `name` (String), `fileType` (String), `localPath` (String), `remoteUrl` (String), `hash` (String).
* **Relationships:** Belongs to **Borrower** or **LoanApplication**.
* **Sensitive Data:** Encrypted files.

### 13. AuditLog
* **Purpose:** Traceability of system mutations.
* **Suggested Fields:** `id` (UUID), `userId` (UUID), `action` (String), `entityName` (String), `entityId` (UUID), `timestamp` (DateTime), `oldStateJson` (String), `newStateJson` (String).
* **Relationships:** Reference to User.
* **Sensitive Data:** Log data must redact passwords and full national ID details.

### 14. Branch & CompanySettings
* **Purpose:** Organizational scope and rules config.
* **Suggested Fields:** `id` (UUID), `name` (String), `currency` (String), `interestCalculationMethod` (String).
* **Validation Rules:** Currency code must be standard ISO.
