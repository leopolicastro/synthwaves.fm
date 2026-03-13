# System

## `ping`

Test connectivity and authentication.

**Path:** `/rest/ping`

**Parameters:** [Common params](README.md#required-common-parameters) only.

### Response

```json
{
  "subsonic-response": {
    "status": "ok",
    "version": "1.16.1",
    "type": "synthwaves.fm",
    "serverVersion": "0.1.0",
    "openSubsonic": true
  }
}
```

---

## `getLicense`

Get the server license status. Always returns a valid license.

**Path:** `/rest/getLicense`

**Parameters:** [Common params](README.md#required-common-parameters) only.

### Response

```json
{
  "subsonic-response": {
    "status": "ok",
    "version": "1.16.1",
    "type": "synthwaves.fm",
    "serverVersion": "0.1.0",
    "openSubsonic": true,
    "license": {
      "valid": true,
      "email": "user@example.com"
    }
  }
}
```

| Field | Type | Description |
|-------|------|-------------|
| `license.valid` | boolean | Always `true` |
| `license.email` | string | Authenticated user's email address |
