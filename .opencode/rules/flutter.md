# Flutter Web Development Rules

## Technical Stack
- **Flutter SDK**: `/home/jack/flutter/bin/flutter` (add to PATH first)
- **Build**: `export PATH="/home/jack/flutter/bin:$PATH" && flutter build web --release`
- **HTTP Client**: Always use `BrowserClient` with `withCredentials = true` for web
- **API URLs**: Always use relative paths like `/api/xxx` (NOT hardcoded IPs or localhost)
- **Same-origin deploy**: Express serves Flutter static + API on same port

## Coding Standards
- Do NOT use `const` on widgets with non-const parameters
- JSON parsing must use explicit type casts: `(json['key'] as num).toDouble()`
- `withAlpha`/`withValues`/`withOpacity` all valid in Flutter 3.41.5
- `fl_chart` is in pubspec.yaml — do NOT remove it
- Use `import 'package:http/browser_client.dart'` for web HTTP requests
- All API calls must include Authorization header with real JWT token
- Store token after login in ApiService static field, access via `ApiService.token`

## Build Verification
After code changes, ALWAYS verify:
1. `flutter analyze` — must show 0 errors (warnings OK)
2. `flutter build web --release` — must succeed
3. Server restart: `fuser -k PORT/tcp; sleep 1; PORT=PORT nohup node dist/index.js > /tmp/server.log 2>&1 &`

## Common Pitfalls
- Flutter web build takes 120-180 seconds — set timeout >= 200s
- Do NOT hardcode trip IDs — always use real IDs from API responses
- Do NOT use mock/demo data — fetch from real API
- Empty states: show "No data yet" when API returns empty
