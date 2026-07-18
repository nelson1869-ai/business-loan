# Lending Business Rules - Lending Nelson

This document outlines the core business and financial rules governing lending operations. All specific amounts, rates, and day limits are draft values and must be verified by business owners before implementation.

---

## 🧑 1. Borrower Eligibility
- **Minimum Age:** Borrower must be >= 18 years old (Verified via DOB on National ID).
- **Onboarding Requirements:** Must submit at least one valid Government-issued ID and proof of income (TBC).
- **Active Loan Limit:** A borrower cannot have more than one active loan contract at any given time (TBC).

---

## 📈 2. Interest & Term Constraints
- **Lending Limits:** Borrowers are restricted by limits defined on the selected **Loan Product** (e.g., Min: $100, Max: $5,000 - TBC).
- **Interest Method:** Calculated using flat interest rate or declining balance calculations (Method choice TBC).
- **Payment Frequencies:** Installments are due monthly, weekly, or daily (Choice TBC).

---

## 💵 3. Repayment & Cash Allocation Rules

### Allocation Sequence
When a payment is received, funds must be allocated strictly in the following priority order:
1. **Unpaid Fees** (e.g., service fees, application fees)
2. **Late Penalties** (unpaid accumulated late charges)
3. **Interest Due** (accrued interest for the current installment)
4. **Principal Due** (principal balance for the current installment)

### Overpayments & Underpayments
- **Partial Payments:** If the amount received is less than the installment due, the system allocates funds following the priority order above, and the remaining amount remains outstanding.
- **Overpayments:** If the amount received exceeds the total balance due, excess funds are applied directly to reduce the outstanding loan principal, triggering a recalculation of subsequent interest due.

---

## 🚨 4. Delinquency & Late Penalties
- **Grace Period:** Borrowers have a grace period of 3 calendar days (TBC) after the due date to submit payments before late penalties are applied.
- **Penalty Calculation:** A late fee is applied starting on day 4 (TBC). It is calculated as:
  - Option A: A flat fee of $10 per installment (TBC).
  - Option B: A daily rate of 1% (TBC) of the overdue principal balance.
- **Overdue Flagging:** Active loans with any installment unpaid for > 3 calendar days (TBC) are flagged as `Overdue` in the system dashboard.

---

## 🔄 5. Status Transitions & Approvals
- **Unidirectional Approval:** A user cannot approve a loan application they submitted. Submissions by a Loan Officer must be reviewed and approved by a separate Branch Manager.
- **Disbursement Blocks:** Disbursement of funds is blocked if the loan application status is not `Approved`.
- **Payment Reversals:** Payment records cannot be deleted. If a cashier records an error, it must be corrected by creating a corresponding **Reversal Transaction** (with supervisor approval), leaving both logs intact for audit tracking.
