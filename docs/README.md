# Lending Nelson Documentation

This directory contains project architecture, learning guides, financial rules, the remaining roadmap, and historical development notes.

Operational setup belongs in the component README files:

- [Backend setup and API operations](../backend/README.md)
- [Postman regression collection](../postman/README.md)
- [Project overview](../README.md)

## Documentation map

| Area | Document | Purpose |
| --- | --- | --- |
| Quick start | [QUICK_START.md](QUICK_START.md) | Essential local commands and URLs |
| Architecture | [System overview](architecture/SYSTEM_OVERVIEW.md) | Components, ownership, and sources of truth |
| Architecture | [Data flows](architecture/DATA_FLOWS.md) | Login, loan, payment, projection, and sync flows |
| Learning | [Student guide](guides/STUDENT_GUIDE.md) | Recommended end-to-end study path |
| Learning | [Backend study guide](guides/BACKEND_STUDY_GUIDE.md) | FastAPI, services, ledger, and projections |
| Learning | [Flutter study guide](guides/FLUTTER_STUDY_GUIDE.md) | UI, Riverpod, repositories, and offline behavior |
| Domain | [Loan and payment rules](domain/LOAN_AND_PAYMENT_RULES.md) | Financial policy and calculation examples |
| Roadmap | [Roadmap overview](roadmap/README.md) | Remaining product work |
| Roadmap | [Milestones](roadmap/MILESTONES.md) | Implemented and outstanding capabilities |
| History | [Development log](history/DEVELOPMENT_LOG.md) | Dated engineering record; not current setup guidance |

## Documentation rules

- FastAPI code and `/openapi.json` are authoritative for API contracts.
- Backend services and persisted ledger data are authoritative for financial results.
- `backend/README.md` and `postman/README.md` are authoritative for setup and test commands.
- Roadmap documents must distinguish implemented behavior from proposed work.
- Historical test counts belong only in the dated development log.
- Never place real passwords, tokens, `.env` values, or private keys in documentation.
