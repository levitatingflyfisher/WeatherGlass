# ADR-0004 — No backend; call the provider directly, and be honest about the IP

**Status:** Accepted.

## Context

Any direct internet request reveals the device's IP to the server. A common "privacy"
response is to route requests through the app's own proxy so the provider sees the
proxy's IP instead of the user's. But a proxy is a **middleman that can log more than
the provider ever could**, tied to whatever identity the app assigns — it converts a
provider-trust problem into a trust-us problem, and it requires running and securing
servers. Open-Meteo's wildcard CORS and keyless access (ADR-0002) make a proxy
unnecessary.

## Decision

Run **no backend**. The app calls Open-Meteo directly from the device. Accept that the
IP is visible, and **state it plainly** rather than pretend otherwise: the "What leaves
your device" screen shows the exact request and an honest note that the IP is inherent
to a direct request and is not masked.

## Consequences

- No servers to run, secure, or trust; nothing between the user and the open provider.
- The IP leak is **not** hidden — this is disclosed, not obscured. The design instead
  minimises everything else: a coarse location (ADR-0003), a fixed keyless request, and
  aggressive caching so requests are rare.
- The **constellation** limit remains: the set of coarse cells seen from one IP over
  time is loosely correlatable. Rounding and caching shrink it; they don't erase it, and
  the docs say so ([privacy-model](../privacy-model.md)).
- Rules out any provider that needs an identifying User-Agent (reinforcing ADR-0002) and
  any future sync that would introduce a server — a sync feature, if ever built, must be
  encrypted-blob-through-a-dumb-relay, never a BaaS.
- Honesty is the product: the transparency screen only works because there is nothing
  hidden behind a server to contradict it.
