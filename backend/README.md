# Axum App (minimal scaffold)

This is a minimal Axum scaffold created for you.

Run locally:

```bash
cd backend/axum-app
cargo run
```

The server listens on `127.0.0.1:3000` and exposes:
- `GET /` -> plain text
- `GET /health` -> JSON { "status": "ok" }

Dependencies: `axum`, `tokio`, `tracing`, `tower-http`.
