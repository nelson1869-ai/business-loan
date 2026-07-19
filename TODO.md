# Lending Nelson TODO

Only the current step is shown here. Complete and verify it before adding the
next step.

Long-term work remains in the [Product Roadmap](docs/roadmap/README.md).

## Step 8: Reverse payments safely

Goal: correct a mistaken payment without deleting financial history or silently
changing a previously issued balance.

1. [ ] Define reversal rules and add reversal request/response schemas.
2. [ ] Implement transactional backend reversal and balance reconstruction.
3. [ ] Add an idempotent authenticated payment-reversal API.
4. [ ] Add Flutter reversal reason, confirmation, and reversed-state UI.
5. [ ] Test reversal scenarios, update student docs, and commit Step 8.

Step 8 is complete only when an authorized officer can reverse a payment with a
reason, preserve both ledger entries, and reproduce the corrected loan balance.
