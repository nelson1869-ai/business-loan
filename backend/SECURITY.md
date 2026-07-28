# Backend security notes

Environment credentials belong only in the local, untracked `backend/.env`
file. The tracked `backend/.env.example` contains placeholders and must never
contain working credentials.

If a credential has ever appeared in a tracked file, removing it from the
current revision is not sufficient. Repository owners must revoke and replace
the credential, update only their local `.env`, review GitHub secret-scanning
alerts, and consider purging the credential from Git history.

Never include credentials, authorization headers, user questions, borrower
PII, or external AI payloads in logs, audit metadata, tests, or documentation.
