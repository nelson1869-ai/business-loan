# Lending Nelson API — Postman Collection

This folder contains the **Lending Nelson API** Postman collection in Postman's
file-based YAML format. Every request, test script, and variable is version-controlled here.

---

## 📋 Prerequisites

| Requirement | Details |
|---|---|
| **Backend running** | Run `.\start.ps1` from the project root |
| **Postman app** | [Download Postman](https://www.postman.com/downloads/) |
| **Postman CLI** (optional) | See install steps below |

---

## 🖥️ Option 1 — Run from the Postman App (Recommended)

Best for interactive testing and debugging individual requests.

### Step 1: Open the collection in Postman
1. Open the **Postman** desktop app.
2. Go to **File → Open** (or press `Ctrl + O`).
3. Select the folder: `D:\Development\lending_nelson\postman\collections\Lending Nelson API`
4. The **Lending Nelson API** collection will appear in the left sidebar.

### Step 2: Run individual requests
1. Expand a folder (e.g., **Authentication**).
2. Click a request (e.g., **Login**).
3. Click the blue **Send** button.
4. Collection variables (`accessToken`, `loanId`, etc.) are set automatically by test scripts.

### Step 3: Run the full collection (Collection Runner)
1. Right-click **`Lending Nelson API`** in the sidebar.
2. Click **`Run collection`**.
3. Click the blue **`Run Lending Nelson API`** button.
4. All 19 requests run in order. Results show pass/fail per test.

> ✅ **Correct run order:** Authentication → Admin (Seed) → Borrowers → Loans → Payments

---

## ⌨️ Option 2 — Run from Terminal (Postman CLI)

Best for CI/CD pipelines and automated regression testing.

### Install Postman CLI (Windows — one time only)

```powershell
powershell.exe -NoProfile -InputFormat None -ExecutionPolicy AllSigned -Command "[System.Net.ServicePointManager]::SecurityProtocol = 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://dl-cli.pstmn.io/install/win64.ps1'))"
```

### Export then run (required for CLI)

The CLI requires a JSON-exported collection file. Export it from the Postman app first:

1. Right-click **`Lending Nelson API`** → **Export**.
2. Choose **Collection v2.1** → Save as `postman/lending-nelson-api.json`.
3. Run:

```powershell
postman collection run "D:/Development/lending_nelson/postman/lending-nelson-api.json"
```

---

## 🔑 Collection Variables

These are set automatically by test scripts — you do **not** need to set them manually.

| Variable | Set By | Used By |
|---|---|---|
| `baseUrl` | Pre-defined (`http://localhost:8000`) | All requests |
| `accessToken` | Login → afterResponse | All protected endpoints |
| `refreshToken` | Login → afterResponse | Refresh Token |
| `borrowerId` | Create Borrower → afterResponse | Get/Update/Delete Borrower |
| `loanId` | List Loans → afterResponse | Get Loan, Payments |
| `paymentId` | Confirm Payment / List Payments | Reverse Payment |
| `paymentDate` | Preview/Confirm Payment → prerequest | Preview/Confirm Payment body |

---

## 📁 Folder Structure & Request Order

```
Lending Nelson API/
├── Authentication/
│   ├── Login              ← Captures accessToken & refreshToken
│   └── Refresh Token
├── Admin/
│   ├── Seed Database      ← Seeds borrowers + loans (runs after Login)
│   └── Reset All Data
├── Borrowers/
│   ├── List Borrowers
│   ├── Create Borrower    ← Captures borrowerId
│   ├── Get Borrower
│   ├── Update Borrower
│   └── Delete Borrower
├── Health/
│   └── Health Check
├── Loans/
│   ├── Create Loan
│   ├── List Loans         ← Captures loanId (picks first Active loan)
│   └── Get Loan
├── Offline Sync/
│   └── Drain Sync Queue
└── Payments/
    ├── Preview Payment    ← Uses today's date dynamically
    ├── Confirm Payment    ← Captures paymentId
    ├── List Payments      ← Fallback: captures latest paymentId
    └── Reverse Payment
```

---

## ✅ Expected Test Results (All Passing)

| Request | Expected Status | Tests |
|---|---|---|
| Login | `200 OK` | Token captured ✅ |
| Seed Database | `200 OK` | `status == "ok"` ✅ |
| List Borrowers | `200 OK` | — |
| Create Borrower | `201 Created` | borrowerId captured ✅ |
| Health Check | `200 OK` | — |
| List Loans | `200 OK` | loanId captured ✅ |
| Get Loan | `200 OK` | — |
| Preview Payment | `200 OK` | Interest + Principal fields present ✅ |
| Confirm Payment | `201 Created` | paymentId captured ✅ |
| Reverse Payment | `200 OK` | `status == "Reversed"` ✅ |
