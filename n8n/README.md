# n8n Integration for Lending Nelson

This directory contains version-controlled workflow exports, sample event fixtures, and quick-start instructions for connecting **Lending Nelson** with an **n8n** automation server.

---

## 🚀 Quick Start Guide

### 1. Start n8n Local Server

```powershell
# Run n8n in PowerShell:
npx n8n
```

Open browser at `http://localhost:5678`.

### 2. Import Workflows

Import the JSON files from `n8n/workflows/`:
1. `event_router.json` (Master Inbound Router)
2. `payment_receipt.json` (Payment SMS Dispatcher)
3. `telegram_manager_bot.json` (Manager Notification Bot)
4. `sync_alert.json` (Operational Offline Sync Failure Alert)
5. `workflow_error_handler.json` (Global Error Handler)

### 3. Validate Workflows

Run the workflow JSON quality & security validator before committing changes:

```powershell
.\backend\.venv\Scripts\python.exe scripts\validate_n8n_workflows.py
```

---

## 📚 Documentation Links
- **Architecture & Event Outbox:** [docs/architecture/N8N_AUTOMATION.md](file:///D:/Development/lending_nelson/docs/architecture/N8N_AUTOMATION.md)
- **Operations & Troubleshooting:** [docs/runbooks/N8N_OPERATIONS.md](file:///D:/Development/lending_nelson/docs/runbooks/N8N_OPERATIONS.md)
