# Lending Nelson TODO

Only the current step is shown here. Complete and verify it before adding the
next step.

Long-term work remains in the [Product Roadmap](docs/roadmap/README.md).

## Step 3: Build the tested loan-calculation foundation

Goal: turn the approved loan rules into exact backend calculations before loan
database tables or Flutter screens depend on them.

1. [x] Add backend test tooling and calculation test structure.
2. [x] Implement exact decimal interest and payment-allocation calculations.
3. [x] Implement regular installments with a final-payment adjustment.
4. [x] Add tests for partial, interest-only, early, and late payments.
5. [x] Run all backend and Flutter checks and document the verified results.

Required worked examples come from
[Loan and Payment Rules](docs/roadmap/LOAN_RULES.md), including:

- `1,000.00` at 10% monthly;
- `600.00` partial payment on `1,100.00` due;
- full payoff five days early or late; and
- ten twice-monthly installments with the final payment adjusted.

Step 3 is complete only when calculations use exact decimal arithmetic and all
documented examples pass automated tests. After that, replace this step with
Step 4.
