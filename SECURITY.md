# Security Policy

## Supported Versions

Only the latest release is actively supported for security updates.

| Version | Supported |
| ------- | --------- |
| 1.0.x   | Yes       |
| < 1.0.0 | No        |

## Reporting a Vulnerability

If you discover a security vulnerability in this project, please do not open a public issue. Instead, report it privately to the maintainers (e.g., via email at security@nelson.com).

We will investigate your report and provide a fix within a reasonable timeframe.

## Secret Handling

- **No Secrets in Git:** Never commit private API keys, keystores, environment passwords, or client secrets.
- **Local Settings:** Use separate local properties or environment variables (`.env`) which are gitignored.
- **Production Secrets:** Store production secrets in a secure secret manager (like GCP Secret Manager) and inject them during the CI/CD build process.
