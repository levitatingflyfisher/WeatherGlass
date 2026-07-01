# WeatherGlass — White Paper

*Weather without surveillance: keyless open data, coordinates blurred before they
leave, and a screen that shows you exactly what's sent.*

**Status:** conceptual overview. For the invariants see [VISION.md](../VISION.md); for
the mechanics, [architecture/OVERVIEW.md](architecture/OVERVIEW.md); for the privacy
rule stated rigorously, [reference/privacy-invariant.md](reference/privacy-invariant.md).
This document is honest about the line between what is built and what is aspirational —
see §6.

---

## Abstract

A weather app is the most innocent-looking tracker on a phone. To tell you if it will
rain, it needs to know where you are — and the mainstream way to deliver that is an
account, an API key that doubles as a per-install identifier, an analytics SDK, and
your precise coordinates sent to a server with every commercial reason to remember
them. The forecast is the feature; the location trail is the product. WeatherGlass
keeps the forecast and discards the trail, using three moves that a browser app can
actually make good on: **blur the coordinate before it leaves the device**, **use the
one genuinely open, keyless weather source**, and **show the user the exact request**
so the claim is checkable rather than promised.

## 1. The problem

You cannot make a direct internet request invisible. Whatever else is true, the server
you contact sees your IP. Faced with that, weather apps take one of two unsatisfying
paths:

- **Route everything through our servers.** Now there is a middleman that can log more
  than the weather provider ever could, tied to an account. "Privacy" becomes "trust
  us."
- **Send your exact location straight to a third party**, with a key that identifies
  the install. Convenient, and a durable location history for whoever holds the logs.

Both treat your location as theirs to collect. The interesting question is what a small,
honest app can control *given* that the IP leak is unavoidable.

## 2. The idea

**Reveal as little as possible around the leak you can't remove, and prove it.**

A browser app can't change its TLS fingerprint or its User-Agent. What it *can* control
is two things: **how precise a location it sends**, and **how often it asks**. So
WeatherGlass:

- **Rounds every coordinate to a coarse grid cell** before it is stored or sent — the
  user picks the coarseness (default ~1 km). Half a decimal place is the difference
  between "this house" and "this town." (§[invariant](reference/privacy-invariant.md))
- **Pins the request to a fixed, identifier-free shape** — no key, token, cache-buster,
  or custom header; only the rounded coordinates vary. This is enforced by a test that
  fails if any identifier ever creeps in.
- **Caches aggressively** (30-minute TTL) so it touches the network rarely — fewer
  requests to correlate.
- **Shows the exact URL** on a "What leaves your device" screen, with an honest note
  that the IP is still visible. Transparency instead of a trust-us promise.

The result is not anonymity — WeatherGlass is careful never to claim that — but a sharp
reduction in what any observer can learn, stated precisely enough to check.

## 3. Why local-first matters *here*

Local-first is not decoration for a weather app; it is the mechanism. Because there is
**no account and no backend of ours**, there is no server-side profile to build and no
second party to trust. Your saved places and forecast history live in an on-device
Drift/SQLite store — rounded on the way in, so even a device dump leaks only a coarse
cell. Offline works because the last forecast is cached. The privacy properties fall out
of the architecture rather than being bolted on as a policy someone must honor.

## 4. The one open source

WeatherGlass uses **Open-Meteo, and only Open-Meteo**. It is the single genuinely FLOSS
weather source (server AGPLv3, data CC BY 4.0), it needs **no API key**, it serves
**wildcard CORS** so a pure browser app can call it with no proxy, and it sets no
cookies. Its sibling geocoder is keyless too. The tempting alternatives — MET Norway,
the US NWS — mandate an identifying `User-Agent` that a browser cannot set, which would
force a proxy and reintroduce exactly the middleman the design rejects. Open-Meteo
already aggregates those national models, so coverage isn't lost.
([ADR-0002](adr/0002-open-meteo-only.md))

## 5. How it differs from the cloud incumbent

| | Typical weather app | WeatherGlass |
|---|---|---|
| Account | Required or nudged | None, ever |
| Location sent | Exact coordinates | Rounded to a user-chosen cell |
| Request identity | API key / install id | None — fixed, keyless, test-pinned |
| Backend | The vendor's servers | None; direct to the open provider |
| Trackers | Analytics + ads SDKs | None; fonts bundled, no runtime egress |
| The privacy claim | A policy document | A screen showing the real request + a test |

The difference is not a longer privacy policy. It is that there is *less to promise*,
because there is less being collected, and what remains is shown to you.

## 6. What is built, and what is not

A white paper that overclaims is marketing. Honestly, as of v0.1.0:

**Built, tested, load-bearing:** the privacy spine (rounding at the add boundary and the
send boundary; the fixed keyless request) enforced by passing tests; the Open-Meteo
client and JSON parse; WMO-code mapping; metric-then-convert units; the 30-minute cache
with self-healing eviction; the deterministic living-sky palette (unit- and
golden-tested); the "What leaves your device" screen; and a shipping PWA + sideload APK.
Roughly fifty tests; `flutter analyze` clean.

**Aspirational, or deliberately out of scope:** severe-weather **alerts**, **radar**,
and a home-screen **widget** are held out on purpose (§[limitations](limitations.md)) —
they need a second source or push. The **correlation limit** is real and unsolved:
rounding + caching shrink the constellation of saved places seen from one IP, they don't
erase it. There is **no sync** (and if it ever ships it must be encrypted-blob-through-a-
dumb-relay, never a BaaS). **iOS** is unbuilt; the artifacts are the PWA and the APK.

## 7. Why it's worth doing

Because the innocent-looking app is the one that gets a pass, and a weather app is the
softest possible on-ramp to a location history. Showing that you can deliver a genuinely
nice forecast — a living sky, hourly curves, a week ahead — with *no account, no key, no
backend, and a coarse location you can dial and verify* is a small proof that the
surveillance was never the necessary price of the feature. That is the whole argument.

---

## References

- **Open-Meteo** — open-source weather API (server AGPLv3, data CC BY 4.0),
  <https://open-meteo.com>. The single data source.
- **WMO weather interpretation codes** — the numeric condition codes the forecast uses.
- **Diátaxis** (Procida, D.) — the framework these [docs](README.md) follow.

*The code and comments referenced here were authored by an AI assistant and describe
what currently exists — take them with gratitude and a grain of salt, and verify before
relying.*
