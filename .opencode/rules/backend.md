# Node.js Backend Rules

## Technical Stack
- **Runtime**: Node.js v22.22.0
- **Framework**: Express + TypeScript + SQLite (better-sqlite3)
- **Compile**: `cd server && npx tsc`
- **Start**: `PORT=5005 node dist/index.js`

## Database Rules
- Use `db.prepare().get/all/run()` — NOT `db.exec()` for queries
- PK column is `id` (INTEGER or TEXT UUID) — NOT `stock_id` or other names
- Check actual schema before writing queries: `node -e "const db=require('better-sqlite3')('path'); db.prepare('PRAGMA table_info(table)').all().forEach(c=>console.log(c.name,c.type,c.notnull))"`
- SQLite uses `"double quotes"` for identifiers, `'single quotes'` for string literals
- `status = "active"` is WRONG — must be `status = 'active'`

## API Design
- All routes need auth: extract token via `getCurrentUser(req)`
- Consistent response format: `{ success: true, data: {...} }` or `{ error: "message" }`
- Use `res.status(401).json({ error: '...' })` for auth failures
- Add try/catch around all DB operations
- Test endpoints with: `curl -s http://127.0.0.1:5005/api/xxx -H "Authorization: Bearer TOKEN"`

## Common Pitfalls
- Do NOT reference columns that don't exist (check schema first!)
- `ticker` vs `symbol` — always check column name in actual table
- `active` column may not exist — use `status` instead
- Server port: 5005 for travel-app, 6006 for stock-app
- Git: `git config user.email "jack@vultr.guest"`
