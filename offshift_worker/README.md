# Offshift Worker demo API

A standalone Cloudflare Worker demo for safe, bounded focus-break flows. It has no runtime dependencies, no outbound `fetch` calls, and no webhook integration.

## Endpoints

| Method | Endpoint | Purpose |
| --- | --- | --- |
| `GET` | `/health` | Service health response. |
| `GET` | `/v1/focus/snapshot?userId=ada` | Deterministic demo focus snapshot. `userId` is optional. |
| `POST` | `/v1/breaks/preview` | Preview one allowlisted break action. |
| `POST` | `/v1/breaks/schedule` | Create a scheduled break. |
| `POST` | `/v1/breaks/:id/snooze` | Delay a scheduled break. |

The only supported actions are `stretch`, `walk`, `breathe`, and `hydrate`. Clients cannot submit arbitrary instructions, custom plan steps, URLs, or webhook targets.

```sh
curl -X POST http://localhost:8787/v1/breaks/preview \
  -H 'content-type: application/json' \
  -d '{"action":"stretch"}'

curl -X POST http://localhost:8787/v1/breaks/schedule \
  -H 'content-type: application/json' \
  -d '{"action":"walk","userId":"ada","startInMinutes":15}'
```

`startInMinutes` is limited to 0–480. Snoozes are limited to 5–60 minutes, with at most three snoozes for each plan.

## Development

```sh
npm install
npm run dev
npm run typecheck
npm test
```

Deploy with `npm run deploy` after authenticating Wrangler.

## Demo-store persistence limitation

`InMemoryDemoStore` deliberately stores schedules only in the Worker isolate's memory. State may disappear when a Worker restarts, scales, or receives a request in another isolate; it is not suitable for production scheduling. It exists to make the demo predictable and testable without bindings or external services. Use a durable Cloudflare binding (for example, Durable Objects or D1) before relying on scheduled breaks in production.
