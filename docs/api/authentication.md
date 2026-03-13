# Authentication

synthwaves.fm uses three authentication mechanisms depending on the API layer.

## API Keys & JWT (JWT API v1 + Import API)

The JWT API and Import API use Bearer token authentication. Tokens are obtained by exchanging an API key's credentials.

### 1. Create an API Key

Generate an API key from the web UI at `/api_keys`. You'll receive:

- **`client_id`** — Format: `bc_` followed by 32 hex characters (e.g., `bc_a1b2c3d4...`)
- **`secret_key`** — Shown once at creation. Store it securely.

### 2. Exchange for a JWT

```bash
curl -X POST https://your-server/api/v1/auth/token \
  -H "Content-Type: application/json" \
  -d '{"client_id": "bc_your_client_id", "secret_key": "your_secret_key"}'
```

**Response:**

```json
{
  "token": "eyJhbGciOiJIUzI1NiJ9...",
  "expires_in": 3600
}
```

The token is a HS256 JWT valid for 1 hour.

### 3. Use the Token

Include the token in the `Authorization` header for all JWT API and Import API requests:

```
Authorization: Bearer eyJhbGciOiJIUzI1NiJ9...
```

### Error Responses

| Status | Body | Cause |
|--------|------|-------|
| 401 | `{"error": "Invalid credentials"}` | Wrong `client_id` or `secret_key` |
| 401 | `{"error": "API key has expired"}` | Key has passed its expiration date |
| 401 | `{"error": "Unauthorized"}` | Missing or invalid JWT on a protected endpoint |

## Subsonic Authentication

The Subsonic API authenticates via query parameters on every request. The username is always the user's email address.

### Required Parameters

Every Subsonic request must include:

| Parameter | Description |
|-----------|-------------|
| `u` | Username (email address) |
| `v` | API version (e.g., `1.16.1`) |
| `c` | Client name (e.g., `myapp`) |
| `f` | Response format: `json` or `xml` (default: `xml`) |

Plus one of the two auth methods below.

### Method 1: MD5 Token (Recommended)

Generate a token from the user's Subsonic password and a random salt:

| Parameter | Description |
|-----------|-------------|
| `t` | MD5 hash of `password + salt` |
| `s` | Random salt string |

```
token = MD5(subsonicPassword + salt)
```

**Example:**

```
/rest/ping?u=user@example.com&t=abc123hash&s=randomsalt&v=1.16.1&c=myapp&f=json
```

### Method 2: Plaintext Password

| Parameter | Description |
|-----------|-------------|
| `p` | Subsonic password, optionally hex-encoded with `enc:` prefix |

**Plaintext:**

```
/rest/ping?u=user@example.com&p=mypassword&v=1.16.1&c=myapp&f=json
```

**Hex-encoded:**

```
/rest/ping?u=user@example.com&p=enc:6d7970617373776f7264&v=1.16.1&c=myapp&f=json
```

### Subsonic Password

The Subsonic password is a separate field (`subsonic_password`) on the User model, distinct from the web login password. It can be retrieved via the [native credentials endpoint](jwt-api.md#get-apiv1nativecredentials).

### Error Response

Authentication failures return error code `40`:

```json
{
  "subsonic-response": {
    "status": "failed",
    "version": "1.16.1",
    "type": "synthwaves.fm",
    "error": { "code": 40, "message": "Wrong username or password" }
  }
}
```

## Web Sessions

Web sessions use signed HTTP-only cookies and are intended for browser-based access only. They are not suitable for programmatic API use. Session records track `user_agent` and `ip_address`.
