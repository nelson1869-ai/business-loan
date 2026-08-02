# Loan Policy Versioning

## Purpose

Loan policy versions preserve the rules approved for a loan without recalculating history when future products change. Policy records are administrative configuration, not legal advice; final rates, fees, grace periods, settlement rules, restructuring rules, and write-off authority require documented business ownership and appropriate legal review.

## Lifecycle

```text
draft -> active -> retired
```

- Creation always produces a draft.
- Drafts cannot govern a loan where an active policy is required.
- Activation requires an administrator other than the policy creator.
- Activation records the checker, timestamp, reason, and audit event.
- Active and retired versions are not edited. A change requires a new version number.
- Retirement prevents new use but never changes existing loans.

## Loan binding

Loans may reference an approved `loan_policy_versions` row. At creation, the backend copies the complete financial policy into `loans.policy_snapshot`. Calculations continue to use the explicit persisted loan terms and snapshot, not mutable global settings.

Loans created before policy versioning, and compatibility flows that do not yet select a version, receive a `legacy-explicit-terms` snapshot containing their calculation method, exact rate, rounding mode, and allocation order. This preserves the existing API while making historical provenance explicit. A later product-selection UI should require an active version for newly originated production loans after business rollout approval.

## Safety rules

- Rates are exact decimals and must fall within the selected policy's approved range.
- Calculation method must match the selected policy.
- Policy foreign keys use `ON DELETE RESTRICT`.
- Policy snapshots are database-required and must not be mutated after loan creation.
- Fees, penalties, compounding, restructuring, and write-off remain disabled unless the selected approved policy explicitly enables them and an implementing service exists.
