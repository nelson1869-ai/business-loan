# n8n Integration for Lending Nelson (Windows Local Hosting)

This directory contains the documentation and pre-built workflow templates for connecting **Lending Nelson** with **n8n** on a local Windows PC.

---

## 🚀 Quick Setup Guide on Windows

### 1. Install & Start n8n

Open **PowerShell** (as Administrator):

```powershell
# Run n8n directly in PowerShell:
npx n8n
```

### 2. Access the n8n Dashboard

Open your web browser and navigate to:
👉 **`http://localhost:5678`**

Create your owner account on first login.

---

## ⚡ Connecting Lending Nelson to n8n

In `backend/.env`, set the following environment variables:

```env
N8N_WEBHOOK_URL=http://localhost:5678/webhook/lending-events
N8N_WEBHOOK_SECRET=your_secure_random_secret_key_123
```

---

## 📥 Importing Pre-Built Workflows

1. In n8n (`http://localhost:5678`), click **Workflows** -> **Import from File**.
2. Select any JSON workflow file inside `n8n/workflows/`.
3. Activate the workflow!

---

## 💳 Online Payment Webhooks (GCash / PayMongo / Xendit)

To receive webhooks from payment gateways on your local Windows PC:

1. Download **Cloudflare Tunnel** (`cloudflared`).
2. Run: `cloudflared tunnel --url http://localhost:5678`
3. Paste the generated `https://...trycloudflare.com` URL into PayMongo / Xendit / Stripe as your webhook endpoint.
