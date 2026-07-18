# Unresolved Project Questions - Lending Nelson

The following questions must be answered by business owners and technical leads prior to Phase 2 (Foundation) execution.

---

## 🏢 Business & Legal Operations
1. **Lending Jurisdiction:** Which country or state regulates this lending product? This dictates legal caps on interest rates and data compliance rules.
2. **Standard Currency:** What ISO currency code (e.g., USD, KES, NGN) is the system baseline?
3. **Branch Model:** Are branches independent entities (staff cannot see other branches' data) or is it a shared company portfolio?

---

## 💰 Loan Product & Financial Rules
4. **Interest Calculation Method:** Do we implement **Flat Interest** or **Declining Balance (Amortized)**?
5. **Repayment Frequencies:** Do we support Daily, Weekly, and Monthly schedules, or is it restricted to Monthly?
6. **Grace Periods:** How many days after the due date can a borrower pay before penalties are applied?
7. **Late Penalties:** Are penalties calculated as a flat fee per occurrence or as a daily percentage of the overdue installment balance?
8. **Reversal Rules:** What is the procedure for reversing an incorrectly logged payment?

---

## 🧑 Borrower Validation Checklist
9. **Required Documents:** What specific onboarding documents are mandatory (e.g., government ID, utility bill, payslip)?
10. **Guarantor Rules:** Is a guarantor mandatory for all loan products, or only for amounts above a specific threshold?
11. **Collateral Types:** Do we allow physical collateral recording, and if so, how is the valuation verified?

---

## 💻 Tech Stack & Infrastructure
12. **Backend Framework:** What is the selected backend API technology (e.g., Firebase, NestJS, Go, or FastAPI)?
13. **Database Provider:** Where will production data reside (e.g., Cloud SQL PostgreSQL, AlloyDB)?
14. **Identity Provider:** Is authentication handled natively via JWT tables or using an external OAuth provider (e.g., Keycloak, Auth0, Firebase Auth)?
15. **n8n Hosting Environment:** Where will n8n instances be deployed (Self-hosted Docker on GCP/AWS or n8n Cloud)?
16. **SMS Gateway API:** Which SMS provider is preferred for field alerts?
17. **Receipt Printing Format:** Do field officers require bluetooth thermal printing compatibility or is sharing a generated PDF via WhatsApp/Email sufficient?
