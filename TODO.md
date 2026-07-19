# Lending Nelson TODO

Only the current step is shown here. Complete and verify it before adding the
next step.

Long-term work remains in the [Product Roadmap](docs/roadmap/README.md).

## Step 4: Persist loan accounts and installment schedules

Goal: store lender-approved loans and their generated installment schedules in
PostgreSQL using exact decimal columns and auditable records.

1. [x] Add SQLAlchemy loan and installment models with relationships.
2. [x] Add and apply the PostgreSQL Alembic migration.
3. [x] Add Pydantic loan request and response schemas.
4. [x] Add loan creation, listing, and detail services and API routes.
5. [x] Add backend tests, run all checks, document results, and commit Step 4.

Version-one persistence rules:

- every loan belongs to one borrower;
- one borrower may have multiple active loans;
- rates and money use exact decimal database types;
- the lender-selected rate is stored on each loan;
- approved terms and payment frequency cannot change silently;
- installments preserve expected interest, principal, amount, and balance;
- the final installment clears the remaining balance; and
- financial records use audit events instead of destructive history changes.

Step 4 is complete only when a tested API can create a loan, generate and store
its schedule, list borrower loans, and return one loan with its installments.
After that, replace this step with Step 5.
