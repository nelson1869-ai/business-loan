# Loan and Payment Rules

These are recommended default rules for the first implementation. Store the
chosen rule on each loan so later configuration changes do not rewrite history.

## Version-one policy summary

The examples in this roadmap use one consistent policy:

| Rule | Version-one behavior |
| --- | --- |
| Rate | Chosen by the lender per loan; examples use 10% per month |
| Interest basis | Current outstanding principal |
| Date calculation | Fixed periods for schedules; daily proration for off-schedule payoff |
| Payment order | Accrued interest first, then principal |
| Unpaid interest | Tracked separately; never automatically compounded |
| Early payment | Future unaccrued interest is not charged after full payoff |
| Late payment | Ordinary interest continues through the payment date |
| Multiple loans | Allowed as separate loan accounts with a warning |
| Due-date change | Only through an explicit audited reschedule |

Every transaction must preserve this balance identity:

```text
Loan amount currently owed = outstanding principal
                           + accrued unpaid interest
                           + agreed posted fees
                           - unapplied borrower credit
```

Do not include future unaccrued interest in the current payoff amount.

## Contents

1. [Lender-selected interest rate](#1-lender-selected-interest-rate)
2. [Borrower-requested term and frequency](#2-borrower-requested-term-and-payment-frequency)
3. [Multiple active loans](#3-multiple-active-loans)
4. [Interest calculation](#4-interest-calculation)
5. [Payment allocation](#5-payment-allocation)
6. [Interest-only payments](#6-interest-only-payment)
7. [Partial payments](#7-partial-payments)
8. [Early and advance payments](#8-early-or-advance-payment)
9. [Underpayments and missed payments](#9-underpayment-and-missed-payment)
10. [New loans while another is unpaid](#10-new-loan-while-another-is-unpaid)
11. [Corrections and reversals](#11-corrections-and-reversals)
12. [Payments after the due date](#12-payment-after-the-due-date)
13. [Rounding and timestamps](#13-rounding-and-timestamps)

## 1. Lender-selected interest rate

The lender chooses the interest rate separately for every new loan. The app
must not assume that all loans use 10%.

Examples:

```text
Loan A: 1,000.00 at 10% per month
Loan B:   500.00 at  5% per month
Loan C: 2,000.00 at  8% per month
```

The loan form should allow the lender to enter the rate and show a calculation
preview before confirming:

```text
Principal:             1,000.00
Selected monthly rate:      10%
Estimated full-cycle interest: 100.00
Estimated full-cycle total:  1,100.00
```

Requirements for a lender-selected rate:

- store the rate on the individual loan, not only in global settings;
- display whether the rate is monthly, annual, or another supported period;
- show the borrower the selected rate and calculation method before release;
- require explicit lender confirmation before disbursement;
- preserve the confirmed rate in the loan history;
- validate configured minimum and maximum values; and
- require the selected rate and terms to comply with applicable law.

After a loan is active, do not silently edit its rate. A rate change requires a
formal amendment with an effective date, reason, old rate, new rate, actor, and
agreement record. Accrued interest before that effective date must not be
recalculated using the new rate.

## 2. Borrower-requested term and payment frequency

The borrower may request a repayment term and frequency, and the lender may
approve or adjust them before disbursement.

Example:

```text
Requested term:       5 months
Payments each month:  2
Scheduled payments:  10
```

```text
Number of installments = term in months * payments per month
                       = 5 * 2
                       = 10
```

The agreement must record:

- term length;
- payment frequency;
- exact due dates, such as the 5th and 20th of each month;
- number of scheduled installments;
- selected interest rate and rate period;
- expected installment amount;
- first and final due dates; and
- rules for early, partial, and missed installments.

The first due date must be selected explicitly. If the period between
disbursement and the first due date is shorter or longer than a normal scheduled
period, treat it as an irregular first period and show its prorated interest in
the preview. Do not silently pretend it is a full half-month period.

### Equal installment amount

When the lender and borrower choose equal installments, calculate one scheduled
amount that covers the interest accrued for each period and reduces principal
to zero by the final installment.

```text
Equal payment = principal * periodic rate
              / (1 - (1 + periodic rate) ^ -number of payments)
```

For two payments per month, a 10% monthly rate has a planned half-month rate of
5% before exact date proration:

```text
Periodic rate = monthly rate / payments per month
              = 10% / 2
              = 5% per scheduled period
```

For a `1,000.00` principal, 5-month term, 10% monthly rate, and 10 equal
scheduled payments, the estimated installment is approximately `129.50`:

```text
Principal:                 1,000.00
Term:                       5 months
Frequency:             twice monthly
Number of payments:               10
Estimated payment:             129.50
Estimated scheduled total:   1,295.05
```

The exact unrounded payment is about `129.5046`. The formula therefore estimates
a `1,295.05` total. Actual currency entries must be rounded to cents. Using
`129.50` for payments 1-9, rounding each period's interest, and adjusting the
last payment produces this ledger:

| Payment | Amount | Interest | Principal | Balance |
| ---: | ---: | ---: | ---: | ---: |
| 1 | 129.50 | 50.00 | 79.50 | 920.50 |
| 2 | 129.50 | 46.03 | 83.47 | 837.03 |
| 3 | 129.50 | 41.85 | 87.65 | 749.38 |
| 4 | 129.50 | 37.47 | 92.03 | 657.35 |
| 5 | 129.50 | 32.87 | 96.63 | 560.72 |
| 6 | 129.50 | 28.04 | 101.46 | 459.26 |
| 7 | 129.50 | 22.96 | 106.54 | 352.72 |
| 8 | 129.50 | 17.64 | 111.86 | 240.86 |
| 9 | 129.50 | 12.04 | 117.46 | 123.40 |
| 10 | 129.57 | 6.17 | 123.40 | 0.00 |

```text
Total principal: 1,000.00
Total interest:    295.07
Total paid:      1,295.07
```

The `0.02` difference from the unrounded formula estimate is caused by rounding
interest and balances to cents at each installment. The app must store one
documented rounding policy and apply it consistently.

### Final-payment adjustment

Use the same rounded amount for every regular installment and adjust only the
last payment to settle the exact remaining principal and interest.

```text
Payments 1-9: 129.50 each
Payment 10:   129.57
Final balance:  0.00
```

This is the version-one rule. It avoids waiving a remaining balance, creating a
borrower credit, or adding a separate rounding transaction. The schedule and
agreement should clearly label the last payment as an estimate that may differ
by a few cents because of currency rounding.

The payment stays approximately equal, but its allocation changes:

```text
Earlier installment: more interest, less principal
Later installment:   less interest, more principal
```

Each period's interest is calculated only on outstanding principal. This does
not add paid interest to principal. If an installment is missed, unpaid interest
remains separate and follows the underpayment rules.

Use exact decimal calculations internally. Round regular installments to the
currency's smallest unit and calculate the final installment from the exact
remaining balance so the ending principal is zero.

### Exact dates versus estimated equal amount

Two payments per month do not always create equal numbers of days. For example,
the 5th-to-20th period and 20th-to-next-5th period can have different lengths.
The app should support one of these disclosed choices:

1. fixed periodic rate, which keeps scheduled installments equal; or
2. actual-day proration, which can slightly change installment amounts.

Version one should use fixed equal scheduled installments for clarity, while
calculating an exact payoff quote for early or late payments using effective
dates. The agreement and preview must clearly state this method.

### Schedule changes

Version one uses one predictable default when a payment is above the expected
installment: keep the regular installment amount, apply the excess to principal
immediately, and shorten the remaining term or reduce the final payment. Show
that effect in the payment preview before confirmation.

Preserve the original agreed schedule as history. Display a separate current
projection using the actual outstanding principal. When early principal
reduction pays the loan off before the original final date, mark later
installments satisfied or cancelled with an audit event rather than deleting
or silently rewriting them.

A missed or partial payment should first be recorded as arrears, not
automatically spread across later installments. Holding extra money as advance
credit or recalculating every future installment can be added later as an
explicit lender-selected, audited option.

## 3. Multiple active loans

A borrower may receive another loan while an earlier loan remains unpaid.
Each loan keeps its own:

- original and outstanding principal;
- interest rate and calculation method;
- start date and payment cycle;
- accrued and unpaid interest;
- payments, allocations, and status; and
- audit history.

Before issuing another loan, show total borrower exposure:

```text
Total exposure = outstanding principal across all active loans
               + unpaid accrued interest
               + posted agreed fees
               - unapplied borrower credit
```

The first version should warn and require confirmation when active loans exist.
A later version may enforce a configurable exposure or active-loan limit.

Every payment must identify the loan it pays. Do not automatically spread one
payment across several active loans. If the lender intentionally splits one
receipt, record a separate amount and allocation for each selected loan, and
show the split before confirmation.

## 4. Interest calculation

Use non-compounding interest on outstanding principal. Version one uses two
related calculations for different situations.

For an on-time scheduled installment, use the fixed periodic rate:

```text
Scheduled interest = outstanding principal * periodic rate
Periodic rate = monthly rate / payments per month
```

For an early, late, or irregular-period payoff, prorate the applicable periodic
rate by elapsed days:

```text
Off-schedule interest = outstanding principal
                      * periodic rate
                      * elapsed days / scheduled-period days
```

For a 10% monthly rate, store the rate as `0.10`, not as `10`. Use the actual
calendar dates for off-schedule calculations so short months, leap years, and
31-day months are handled consistently. Do not charge both a full fixed-period
amount and daily interest for the same days.

Unpaid interest remains in an `interest_due` balance. Do not automatically add
it to principal because that would create interest on interest.

## 5. Payment allocation

Recommended default order:

1. accrued interest due;
2. outstanding principal; and
3. remaining amount as borrower credit or a refund requiring confirmation.

Show the allocation preview before saving:

```text
Payment received:       250.00
Applied to interest:     50.00
Applied to principal:   200.00
Unallocated credit:       0.00
```

Allow an authorized lender to choose `interest only`, `principal only`, or a
custom split, but require a reason and audit entry when overriding the default.
The preview must show how an override changes interest due, principal, and the
remaining schedule.

### Payment above the scheduled installment

An amount above the scheduled installment is not automatically advance credit.
After accrued interest is cleared, every remaining peso reduces principal.

Example for a `1,000.00` loan at 10% monthly, paid twice monthly, with a regular
installment of `129.50`:

```text
Payment received:                 200.00
Accrued half-month interest:       50.00
Applied to principal:             150.00
Remaining principal:              850.00

Normal scheduled principal:        79.50
Additional principal reduction:    70.50
```

For the next planned half-month period:

```text
Interest on 850.00 at 5%:          42.50
Regular payment remains:          129.50
Applied to principal:              87.00
Projected remaining principal:    763.00
```

Continue requesting the regular installment until the payoff amount is smaller,
then make the last payment only the exact principal and accrued interest still
owed. Create unapplied borrower credit only if money remains after all accrued
interest and outstanding principal have been cleared.

## 6. Interest-only payment

If the borrower pays exactly the accrued interest:

- interest due becomes zero;
- principal stays unchanged;
- the loan remains active; and
- interest continues accruing on the same principal.

Example for a 30-day cycle:

```text
Principal:          1,000.00
Monthly rate:             10%
Full-cycle interest:  100.00
Payment:              100.00
Principal afterward: 1,000.00
Interest due:             0.00
```

## 7. Partial payments

### Partial mid-cycle payment

Accrue interest up to the exact payment date, allocate the payment, then accrue
future interest using the new outstanding principal.

Example using a simplified 30-day cycle:

```text
Starting principal: 1,000.00
Monthly rate:             10%
Payment on day 15:     250.00

Interest for days 1-15:  50.00
Applied to interest:      50.00
Applied to principal:    200.00
New principal:           800.00
Interest for days 16-30:  40.00
```

The total interest for that cycle becomes `90.00`, because the second half of
the cycle accrues against the reduced principal.

### Partial payment at the monthly due date

Use the reducing-balance method: settle the completed month's interest first,
apply the rest to principal, and calculate the next month's interest using only
the principal that remains.

Example with a payment of `600.00` at the end of the first month:

```text
Original principal:             1,000.00
First-month interest at 10%:      100.00
Total due before payment:        1,100.00
Payment received:                  600.00

Applied to first-month interest:   100.00
Applied to principal:              500.00
Remaining principal:               500.00

Second-month interest at 10%:       50.00
Total due after second month:       550.00
```

Do not charge the next month's 10% against the original `1,000.00`, because
`500.00` of principal was already repaid. Also do not calculate 10% against the
old `1,100.00` total; completed interest is settled before principal reduction.

The transaction should preserve separate values:

```text
Payment allocation
  Interest: 100.00
  Principal: 500.00

Loan balance after payment
  Principal: 500.00
  Interest due: 0.00
```

If the payment is less than `100.00`, it does not reduce principal under the
default interest-first allocation rule. Any unpaid interest remains separate,
and the next month's ordinary interest still uses the `1,000.00` principal.

## 8. Early or advance payment

Recommended default behavior:

- first settle interest accrued through the payment date;
- apply the remainder immediately to principal; and
- calculate later interest using the reduced principal.

Do not pre-charge future interest. If the lender wants to hold excess money for
a future due date, record it as a separate credit balance and show it clearly.

### Full payoff five days early

If a 30-day cycle is paid in full on day 25, charge only the interest accrued
for 25 days. The remaining 5 days are unaccrued interest, so they are not
charged or later refunded.

```text
Outstanding principal:    1,000.00
Monthly rate:                  10%
Cycle length:               30 days
Full payoff date:            Day 25

Interest for 25 days:          83.33
Principal payoff:           1,000.00
Total payoff:               1,083.33
Unaccrued 5-day interest:      16.67
```

The app may show `16.67 interest avoided by early payoff`, but should not call
it a payment discount because that interest was never earned or accrued.

### Interest-only or partial payment on day 25

The 5 remaining days are not automatically removed when principal remains:

- an interest-only payment settles interest accrued through day 25, while the
  unchanged principal continues accruing interest for days 26-30;
- a partial payment settles accrued interest first, reduces principal with the
  remainder, and days 26-30 accrue against the reduced principal; and
- a full payoff stops future accrual because principal becomes zero.

Example of interest-only payment:

```text
Interest paid on day 25:       83.33
Principal afterward:        1,000.00
Interest for days 26-30:       16.67
```

Therefore, `5 days of interest not charged` applies only when the loan is fully
settled on day 25. Otherwise, calculate those days using the principal that
remains after the payment.

## 9. Underpayment and missed payment

If a payment is less than accrued interest:

- apply it to interest due;
- keep the remaining interest as unpaid;
- leave principal unchanged; and
- mark the schedule item `partially paid`.

If no payment is made, mark the schedule item overdue after the configured due
date. Do not invent a late fee or capitalize interest unless the signed loan
terms and applicable law explicitly allow it.

## 10. New loan while another is unpaid

Create a new loan record rather than increasing the old loan principal. This
keeps rates, dates, payments, and agreements understandable.

The confirmation screen should show:

- number of active loans;
- total outstanding principal;
- total interest due;
- overdue amount;
- proposed new principal; and
- total exposure after disbursement.

## 11. Corrections and reversals

Never edit or delete a completed payment silently. Create a reversal linked to
the original payment, restore its allocations, and then record the corrected
payment. Preserve both entries in the audit history.

## 12. Payment after the due date

Count overdue calendar days from the due date up to, but not including, the
effective payment date:

```text
Overdue days = payment date - due date
```

Example:

```text
Due date:       5 August
Payment date:  10 August
Overdue days:           5
```

The app should display `5 days overdue` and accrue ordinary simple interest
through the payment date. Do not automatically add a penalty or late fee unless
it was agreed in the loan terms and is permitted by applicable law.

For the version-one off-schedule calculation, additional interest after the due
date is:

```text
Additional interest = outstanding principal
                    * periodic rate
                    * overdue days / scheduled-period days
```

Simplified monthly-payment example using a configured 30-day cycle, where the
periodic rate is the 10% monthly rate:

```text
Outstanding principal: 1,000.00
Monthly rate:                10%
Overdue days:                  5
Additional interest:       16.67
```

Complete payoff example after five overdue days:

```text
Principal at first due date:       1,000.00
First-cycle interest due:            100.00
Additional five-day interest:         16.67
Full payoff on the 10th:           1,116.67
```

Partial-payment example using the same `600.00` payment:

```text
Payment received:                    600.00
Applied to total interest:           116.67
Applied to principal:                483.33
Remaining principal:                 516.67
Remaining interest due:                0.00
```

The next cycle accrues against `516.67`, not against `1,000.00` or `1,116.67`.
This example assumes no earlier unpaid interest, fees, credits, or payments.

When payment arrives on the 10th, calculate interest through the 10th and then
apply the payment using the normal allocation order. If the payment covers only
interest, principal remains unchanged. If it is less than interest due, the
remaining interest stays overdue.

Recommended schedule behavior:

- keep the regular due day on the 5th for the next cycle;
- do not silently move future due dates to the 10th;
- use a formal reschedule action if both parties agree to change due dates; and
- record the old schedule, new schedule, reason, and actor in the audit history.

A configurable grace period may suppress an overdue label or late fee, but it
should not silently change interest accrual. Show both `days after due date` and
the grace-period status so the calculation remains understandable.

## 13. Rounding and timestamps

- Use exact decimal arithmetic, never binary floating-point for money.
- Round currency only at documented allocation or statement boundaries.
- Save timestamps in UTC and display them in the user's local timezone.
- Save the effective payment date separately from the record-created time.
