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
## Step 11: Production Field & Risk Management Features

1. [x] **Real-time Offline Connectivity Status Banner**: Rendered top notification banner when offline (`⚡ Working Offline`) in `MainShell`.
2. [x] **Borrower Exposure Risk Guard**: Displayed borrower's total existing active loan balance risk card on `LoanCreateScreen`.
3. [x] **Overdue Arrears Breakdown Card**: Rendered exact overdue arrears collection banner on `LoanDetailScreen`.
