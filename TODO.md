# Lending Nelson TODO

Only the current step is shown here. Complete and verify it before adding the
next step.

Long-term work remains in the [Product Roadmap](docs/roadmap/README.md).

## Step 9: Generate receipts and loan statements

Goal: give the lender and borrower an understandable record derived from the
immutable loan, payment, allocation, and reversal ledger.

1. [ ] Define receipt and statement contents with response schemas.
2. [ ] Implement backend receipt and statement projection services.
3. [ ] Add authenticated receipt and loan-statement APIs.
4. [ ] Add Flutter receipt detail and loan-statement screens.
5. [ ] Test financial totals, update student docs, and commit Step 9.

Step 9 is complete only when every payment or reversal has a reproducible
receipt and the complete loan statement reconciles to the current balance.
