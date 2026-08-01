# n8n Operations & Troubleshooting Runbook

This runbook describes local setup, credentials configuration, workflow import/export, operational health monitoring, secret rotation, dead-letter recovery, and disaster procedures for the **Lending Nelson** n8n automation pipeline.

---

## 🚀 Local Setup Guide

### 1. Running n8n Locally on Windows PC

Using PowerShell:

```powershell
# Method A: Run via npx
npx n8n

# Method B: Run via Docker (if Docker Desktop installed)
docker run -d --name n8n -p 5678:5678 -v n8n_data:/home/node/.n8n docker.n8n.io/n8nio/n8n
```

Access the n8n dashboard at `http://localhost:5678`.

---

## 🔑 Environment Variables & Credentials

Configure `backend/.env`:

```env
N8N_ENABLED=true
N8N_WEBHOOK_URL=http://localhost:5678/webhook/lending-events
N8N_WEBHOOK_SECRET=your-32-character-random-hmac-secret-key
N8N_TIMEOUT_SECONDS=5
N8N_MAX_ATTEMPTS=8
N8N_RETRY_BASE_SECONDS=30
N8N_SIGNATURE_MAX_AGE_SECONDS=300
N8N_SERVICE_API_KEY=your-machine-service-api-key-here
```

---

## 📥 Workflow Import & Activation Procedure

1. In n8n (`http://localhost:5678`), navigate to **Workflows** -> **Import from File**.
2. Select files from `n8n/workflows/`:
   - `event_router.json` (Master Router)
   - `payment_receipt.json`
   - `telegram_manager_bot.json`
   - `sync_alert.json`
   - `workflow_error_handler.json`
3. Activate the imported workflows by toggling the **Active** switch in n8n.

---

## 🛠️ Operational Health & Dead-Letter Inspection

### Check Automation Outbox Health
```powershell
curl -H "X-Service-API-Key: your-machine-service-api-key-here" http://localhost:8000/api/v1/automation/health
```

Expected Response:
```json
{
  "n8n_enabled": true,
  "n8n_webhook_configured": true,
  "pending_count": 0,
  "processing_count": 0,
  "delivered_count": 142,
  "failed_count": 0,
  "dead_lettered_count": 0,
  "total_count": 142
}
```

### Inspect Failed or Dead-Lettered Events
```powershell
curl -H "X-Service-API-Key: your-machine-service-api-key-here" "http://localhost:8000/api/v1/automation/events?status=dead_lettered"
```

### Manually Replay a Failed Event
```powershell
curl -X POST -H "X-Service-API-Key: your-machine-service-api-key-here" "http://localhost:8000/api/v1/automation/events/{event_id}/retry"
```

---

## 🔄 Secret Rotation & Maintenance

1. Generate a new HMAC secret:
   ```powershell
   python -c "import secrets; print(secrets.token_urlsafe(32))"
   ```
2. Update `N8N_WEBHOOK_SECRET` in `backend/.env`.
3. Update the corresponding credential node or environment variable in n8n.
4. Restart FastAPI backend.

---

## 🚨 Offline & Failure Behavior
- **n8n Server Down:** FastAPI continues operating without disruption. Domain events remain safely queued in `automation_event_outbox`.
- **Automatic Recovery:** Once n8n comes back online, the outbox worker automatically resumes delivery on the next batch run.
