# Lending Nelson Documentation

This directory contains production architecture, financial rules, and operational setup documentation.

Operational references:

- [Backend setup and API operations](../backend/README.md)
- [Project overview](../README.md)

## Documentation map

| Area | Document | Purpose |
| --- | --- | --- |
| Quick start | [QUICK_START.md](QUICK_START.md) | Production configuration and release commands |
| Local testing | [Local Wi-Fi Android testing](local_wifi_testing/README.md) | Run the Android debug client against a backend PC on the same trusted Wi-Fi |
| Architecture | [System overview](architecture/SYSTEM_OVERVIEW.md) | Components, ownership, and sources of truth |
| Architecture | [Data flows](architecture/DATA_FLOWS.md) | Login, loan, payment, projection, and sync flows |
| Domain | [Loan and payment rules](domain/LOAN_AND_PAYMENT_RULES.md) | Financial policy and calculation examples |

## Documentation rules

- FastAPI code and `/openapi.json` are authoritative for API contracts.
- Backend services and persisted ledger data are authoritative for financial results.
- Never place real passwords, tokens, `.env` values, private keys, or signing credentials in documentation.
- Local HTTP instructions are development-only; production Android builds require HTTPS.
