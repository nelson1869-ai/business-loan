# User Flow Acceptance Criteria - Lending Nelson

This document details behavior-driven acceptance criteria (Given/When/Then format) for core application workflows.

---

## 🔐 1. User Login

### Scenario: Successful Authentication
* **Given** a user is on the login page
* **When** they input a valid username `officer1` and password `password123`
* **And** click the **Login** button
* **Then** the application should submit details to the server
* **And** retrieve the user access token and store it in Secure Storage
* **And** redirect the user to the active dashboard

---

## 🧑 2. Borrower Registration (Offline Mode)

### Scenario: Registration while Offline
* **Given** the device has no network connection
* **And** the Loan Officer is on the Borrower Registration screen
* **When** they enter valid borrower details (First Name: "John", Last Name: "Doe", Phone: "+254712345678")
* **And** click **Register**
* **Then** the app should save the borrower record to the local database with status `Pending`
* **And** add a synchronization task to the Offline Queue database
* **And** display a registration confirmation screen

---

## 📝 3. Submit Loan Application

### Scenario: Amount requested exceeds product limits
* **Given** the active loan product has a maximum limit of $1,000
* **And** the Loan Officer is creating a new application
* **When** they input an amount of $1,500
* **Then** the app should block submission
* **And** display a warning message: "Amount requested exceeds the maximum product limit of $1,000"

---

## 💵 4. Disbursement & Schedule Generation

### Scenario: Disbursing an Approved Loan
* **Given** the loan application is marked `Approved`
* **When** the Loan Officer logs a disbursement transaction
* **Then** the system should update the loan status to `Active`
* **And** generate the repayment schedule installments containing the correct principal and interest splits
* **And** block updates to the original loan contract parameters (e.g., amount, interest rate)

---

## 💳 5. Record Payments & Sync

### Scenario: Successful Repayment Capture
* **Given** a loan has an active balance of $500
* **When** the Cashier records a repayment payment of $100
* **Then** the system should generate a unique transaction UUID
* **And** reduce the outstanding loan balance to $400
* **And** create a shareable PDF receipt
* **And** queue the payment transaction to sync with the server

### Scenario: Synchronizing Offline Transactions on Network Recovery
* **Given** the app contains 2 pending payment records in the offline sync queue
* **When** network connectivity is restored
* **Then** the sync manager should sequentially dispatch the payments to the server
* **And** verify that each transaction uses its unique transaction UUID to prevent duplicate entries
* **And** remove the successfully processed items from the sync queue upon receiving a confirmation code from the server
