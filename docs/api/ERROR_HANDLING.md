# Error Handling Protocol - Lending Nelson

This protocol defines a standard JSON format for API error responses and maps how the Flutter client processes errors.

---

## 📋 Standard Error JSON Payload

All error responses from the API must conform to the following payload format:
```json
{
  "errorCode": "VALIDATION_FAILED",
  "message": "The request payload contains invalid fields.",
  "timestamp": "2026-07-18T14:13:00Z",
  "details": [
    {
      "field": "nationalId",
      "issue": "National ID must be exactly 9 digits."
    }
  ]
}
```

---

## 🏷️ Error Classifications & Status Codes

The application classifies errors into the following categories:

| Error Category | HTTP Code | Error Code | Client Behavior |
| --- | :---: | --- | --- |
| **Validation Error** | 422 | `VALIDATION_FAILED` | Highlight invalid text fields in UI. |
| **Authentication Error**| 401 | `UNAUTHORIZED` | Redirect user to the login screen. |
| **Authorization Error** | 403 | `FORBIDDEN` | Show "Access Denied" alert page. |
| **Record Not Found** | 404 | `NOT_FOUND` | Display generic 404 message. |
| **Conflict State** | 409 | `RESOURCE_CONFLICT` | Prompts sync resolution layout. |
| **Duplicate Transaction**| 409 | `DUPLICATE_TRANSACTION` | Show "Payment already processed" dialog. |
| **Rate Limit Exceeded** | 429 | `RATE_LIMIT_EXCEEDED` | Request developer wait before retrying. |
| **Internal Server Error**| 500 | `SERVER_ERROR` | Show "Server down, try again later" dialog. |

---

## 📲 Client-Side Exception Types

The Flutter client maps exceptions to the following classes:

- **`NetworkException`:** Triggered when the device has no internet access or a socket timeout occurs.
- **`ApiException`:** Triggered when the server returns a non-20x HTTP status code, parsing the error JSON payload.
- **`OfflineQueueException`:** Triggered when a transaction cannot be written to the local cache database.
- **`SyncConflictException`:** Triggered during synchronization when the server reports a newer database modification exists.
