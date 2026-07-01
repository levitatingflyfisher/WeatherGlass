# Documentation

Organized on the [Diátaxis](https://diataxis.fr/) model — four kinds of docs for
four different needs. Find what you need by *what you're trying to do*, not by
guessing a filename.

| I want to… | I need | Go to |
|---|---|---|
| **learn by doing** | a Tutorial | [Tutorials](#tutorials) |
| **accomplish a specific task** | a How-to guide | [How-to guides](#how-to-guides) |
| **look up exact details** | Reference | [Reference](#reference) |
| **understand why** | Explanation | [Explanation](#explanation) |

New here? Start with the [README quickstart](../README.md), then
[Explanation § concepts](concepts.md), then the [privacy model](privacy-model.md) —
the part of WeatherGlass most worth understanding.

---

## Tutorials
*Learning-oriented — take me by the hand through my first success.*

- The **[README quickstart](../README.md#build)** — install, generate code, run it in
  a browser, build the APK.

*Gap (contributions welcome):* a hand-held "add a place, then open the *What leaves
your device* screen and read the exact request" walkthrough. If you write one, put it
in `docs/tutorials/`.

## How-to guides
*Task-oriented — how do I accomplish X (assumes you know the basics)?*

- **[Build & run](how-to/build-and-run.md)** — from a fresh clone to a running app.
- **[Deploy the PWA and APK](how-to/deploy-pwa-and-apk.md)** — ship to GitHub Pages
  and a sideload release.
- **[Verify the privacy invariant](how-to/verify-the-privacy-invariant.md)** — prove
  to yourself that the request is fingerprint-free.
- **[Encrypted backup](how-to/encrypted-backup.md)** — set up, export, and restore
  a `.ohbk` file; the recovery-phrase honesty and the destructive-restore contract.

## Reference
*Information-oriented — tell me exactly, precisely, completely.*

- **[Privacy invariant](reference/privacy-invariant.md)** — the rounding rule and the
  fixed-request rule, stated rigorously, with the tests that enforce them. This is the
  closest thing WeatherGlass has to a formal spec.
- **[Data model](reference/data-model.md)** — the stored tables, the domain types,
  and the shape of an Open-Meteo response.
- **[Feature status](reference/feature-status.md)** — what's shipped, what's held out
  of scope, per version.

## Explanation
*Understanding-oriented — help me understand the ideas and the why.*

- **[Vision](../VISION.md)** — the one idea, the invariants, the honest scorecard.
- **[Architecture overview](architecture/OVERVIEW.md)** — the spine + a diagram.
- **[Architecture Decision Records](adr/)** — why each load-bearing choice was made.
- **[Concepts](concepts.md)** — the domain model: rounding & precision, WMO codes,
  the living sky, caching, units.
- **[Privacy model](privacy-model.md)** — the threat model and exactly what leaves the
  device (and what honestly can't be hidden).
- **[Limitations](limitations.md)** — read before adopting. What it does *not* do.

---

### The white paper

- **[White paper](whitepaper.md)** — *weather without surveillance*: the conceptual
  case for the design, why local-first matters *here*, and how it differs from the
  cloud incumbents. Honest about what's built vs. aspirational.

There is intentionally **no separate "yellow paper."** WeatherGlass has exactly one
formalizable core — the coordinate-rounding + fixed-request invariant — and it is
specified with full rigor in [reference/privacy-invariant.md](reference/privacy-invariant.md)
rather than padded into its own document.
