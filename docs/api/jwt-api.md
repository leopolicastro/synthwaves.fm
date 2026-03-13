# JWT API v1

Two endpoints for token exchange and native app bootstrap.

## POST `/api/v1/auth/token`

Exchange API key credentials for a JWT.

**Auth:** None (this is the auth endpoint)

### Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `client_id` | string | Yes | API key client ID (format: `bc_` + 32 hex chars) |
| `secret_key` | string | Yes | API key secret |

### Request

```bash
curl -X POST https://your-server/api/v1/auth/token \
  -H "Content-Type: application/json" \
  -d '{"client_id": "bc_a1b2c3d4e5f6...", "secret_key": "sk_..."}'
```

### Response — 200 OK

```json
{
  "token": "eyJhbGciOiJIUzI1NiJ9...",
  "expires_in": 3600
}
```

| Field | Type | Description |
|-------|------|-------------|
| `token` | string | HS256 JWT, valid for 1 hour |
| `expires_in` | integer | Token lifetime in seconds |

### Errors

| Status | Body | Cause |
|--------|------|-------|
| 401 | `{"error": "Invalid credentials"}` | Wrong `client_id` or `secret_key` |
| 401 | `{"error": "API key has expired"}` | Key past expiration date |

---

## GET `/api/v1/native/credentials`

Returns the current user's credentials for configuring Subsonic clients. Intended for native app bootstrap flows.

**Auth:** Web session (cookie-based, not JWT)

### Request

```bash
curl https://your-server/api/v1/native/credentials \
  -b "session_cookie=..."
```

### Response — 200 OK

```json
{
  "email": "user@example.com",
  "subsonic_password": "abc123",
  "theme": "synthwave"
}
```

| Field | Type | Description |
|-------|------|-------------|
| `email` | string | User's email address (used as Subsonic username) |
| `subsonic_password` | string | Password for Subsonic API authentication |
| `theme` | string | User's selected theme (`synthwave`, `reggae`, `punk`, or `jazz`) |
