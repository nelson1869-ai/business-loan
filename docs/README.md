# Lending Nelson Documentation

This directory contains production architecture, financial rules, and operational setup documentation.

## Send to Borrower

The Android application prepares payment reminders, loan summaries, schedule
summaries, payment receipts, payment-schedule PDFs, and loan-statement PDFs from
records already stored in encrypted local SQLite.

The officer reviews and may edit every text message before continuing. SMS
opens an installed SMS application with a draft; the application never sends
directly and requests no SMS permission. **More Sharing Options** uses the
Android share sheet. Generated PDFs can be previewed or shared and are written
only to the application's temporary directory.

The feature works with Wi-Fi, mobile data, and FastAPI turned off. Sharing does
not enqueue a mutation, change sync status, or modify financial data.
Borrower-facing output excludes government IDs, addresses, contacts, guarantor
details, photos, authentication data, officer notes, and internal database IDs.
The phone number is masked in the interface and its validated full value is
used only to open an SMS draft.

The phone also schedules privacy-safe reminders for the lending officer at
9:00 AM three days before a locally stored installment is due, on its due date,
and one day after it becomes overdue. Notification text contains no borrower
name, phone number, or financial amount. Tapping a reminder opens the
corresponding local loan and the Send to Borrower review sheet; it never sends a
borrower message. Completing or reversing a payment refreshes scheduled
reminders. The officer may dismiss the Android notification or snooze the
follow-up for one day from the sheet.

### Manual test

1. Cache or create a borrower, active loan, schedule, and payment on the phone.
2. Stop FastAPI and disable Wi-Fi and mobile data.
3. Open the borrower or loan and select **Send to Borrower**.
4. Prepare and edit a reminder, then continue to SMS. Return without sending
   and verify that loan and synchronization state are unchanged.
5. Use **More Sharing Options** and verify the Android share sheet opens.
6. Generate and preview the payment schedule and loan statement PDFs.
7. From Payment History, expand an effective payment, select **Send Receipt to
   Borrower**, and generate its receipt PDF.
8. Compare all values with local records and confirm no sensitive information
   appears.

Operational references:

- [Backend setup and API operations](../backend/README.md)
- [Project overview](../README.md)

## Documentation map

| Area | Document | Purpose |
| --- | --- | --- |
| Quick start | [QUICK_START.md](QUICK_START.md) | Production configuration and release commands |
| Operations | [Admin credentials](admin_credentials/README.md) | Safe reference for the admin username and password storage |
| Local testing | [Local Wi-Fi Android testing](local_wifi_testing/README.md) | Run the Android debug client against a backend PC on the same trusted Wi-Fi |
| Architecture | [System overview](architecture/SYSTEM_OVERVIEW.md) | Components, ownership, and sources of truth |
| Architecture | [Data flows](architecture/DATA_FLOWS.md) | Login, loan, payment, projection, and sync flows |
| Domain | [Loan and payment rules](domain/LOAN_AND_PAYMENT_RULES.md) | Financial policy and calculation examples |

## Documentation rules

- FastAPI code and `/openapi.json` are authoritative for API contracts.
- Backend services and persisted ledger data are authoritative for financial results.
- Never place real passwords, tokens, `.env` values, private keys, or signing credentials in documentation.
- Local HTTP instructions are development-only; production Android builds require HTTPS.
