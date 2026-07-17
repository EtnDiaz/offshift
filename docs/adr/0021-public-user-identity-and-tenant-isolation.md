# ADR 0021: Separate the anonymous demo from an authenticated multi-user service

**Status:** Accepted

**Date:** 2026-07-17

**Supersedes:** the production-readiness implication of ADR 0013's demo
dashboard capability

## Context

The deployed Worker has a deliberately anonymous demo contract. It accepts a
caller-supplied `userId`, keeps dashboard and plan state in Worker-isolate
memory, and uses a short-lived widget capability only to prove that a
currently rendered widget initiated a bounded demo mutation. Neither the
parameter nor the capability identifies a human, an account, or a macOS
installation. Isolate memory is also not durable or globally consistent.

That is acceptable for a fixture-only connector, but unsafe for a product that
shows a person's status or stores a break plan. In particular, a public user
must never be able to choose another account identifier, and a shared relay
secret must never decide which person's Codex event is being updated.

An Apps SDK application is backed by an MCP server; it is not an alternative
to one. A private tunnel can expose a development or on-premises MCP server to
ChatGPT without making that server Internet-public, but it supplies neither
end-user identity nor tenant isolation for a public service.

## Decision

Keep the current endpoint explicitly labelled and operated as an anonymous,
fixture-only demo. It must not accept real local activity, device state,
smart-home credentials, or personal schedules, and it must not be described
as a public multi-user beta.

Before a public or user-specific Apps SDK release, Offshift will add a
standards-compliant OAuth 2.1 authorization server from an established identity
provider rather than implement passwords or OAuth itself. The MCP resource
server will:

- publish protected-resource metadata and return an OAuth challenge for every
  account-specific tool;
- use authorization-code + PKCE, and validate token signature, issuer,
  audience/resource, expiry, and required scopes on every request;
- derive the account subject exclusively from the validated token. Public tool
  schemas must not contain `userId`, `accountId`, or an installation id that
  selects another person's state;
- keep only account-scoped cloud data that a user explicitly chooses to sync:
  coarse plan/override state, consent version, and a pseudonymous device
  record. The default source of timing and every intervention decision remains
  local to the macOS companion;
- enforce ownership in every storage query and transaction. Durable plan and
  idempotency data will have an immutable account subject and compound indexes;
  a per-account serialized state boundary may be implemented with a Durable
  Object where concurrent mutation needs it;
- issue a device-specific, revocable pairing credential after a user confirms
  a one-time pairing code locally. The companion stores it in Keychain. Codex
  events use this registered device credential and resolve the account on the
  server; they cannot submit a caller-selected installation or rely on one
  shared global relay secret;
- keep ChatGPT, the Worker, and Codex unable to invoke the local care surface,
  Lock Screen rule, Home Assistant scene, or settings. Pairing authorizes only
  the narrow, consented data flow, not remote device control.

ChatGPT is authenticated as the MCP client separately from the end user where
appropriate (for example, mTLS); client authentication does not replace OAuth
user authentication.

## Consequences

- The smallest safe next release is a **single-user, local-first pilot**. Its
  public Worker stays fixture/read-only unless and until OAuth and storage
  isolation are implemented and tested.
- A Secure MCP Tunnel is useful for developer testing of a local/private MCP
  server. It is not a production authentication mechanism and cannot make the
  existing anonymous Worker multi-tenant.
- The public multi-user milestone now has explicit work: identity-provider
  selection, OAuth metadata and tests, token middleware, a tenant-scoped data
  store, companion pairing/revocation, per-user relay credentials, abuse/rate
  limits, and a privacy/retention review.
- Screen Time / Family Controls, camera analysis, and reading Codex work data
  remain outside this decision and outside the MVP.
