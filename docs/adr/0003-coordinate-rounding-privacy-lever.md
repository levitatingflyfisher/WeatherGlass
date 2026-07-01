# ADR-0003 — Coordinate rounding at the boundary is the privacy lever

**Status:** Accepted. This is the app's defining decision.

## Context

The goal is that an individual user is **not trackable by a unique request
fingerprint**. A browser app cannot control the things people usually think of as
fingerprints — TLS/JA3-JA4 and forbidden request headers are out of JavaScript's hands,
and the User-Agent is set by the browser. What a browser app *can* control is **how
precise a location it sends** and **how often it asks**. Precision is the lever with the
most leverage: the difference between two decimal places and four is the difference
between "this neighbourhood" and "this house."

## Decision

Round every coordinate to a user-chosen grid **at the boundary**, and never let a finer
value be stored or sent.

- Precision is a setting with three levels: `coarse` (1 dp, ~11 km), `balanced` (2 dp,
  ~1 km, **default**), `precise` (3 dp, ~110 m). (`domain/geo.dart`)
- Round at the **add boundary** — the moment a place is added or the device is located —
  so the database only ever holds a rounded coordinate.
- Round **again at the send boundary** — every outbound request re-rounds to the
  *current* precision. This makes the setting authoritative even for places saved
  earlier at a finer precision. (`data/weather_repository.dart`)
- Request the device fix at `LocationAccuracy.low`, then round it further.

The rule is specified precisely in
[reference/privacy-invariant.md](../reference/privacy-invariant.md) and enforced by
`geo_test.dart`.

## Consequences

- Even a full device dump leaks only a coarse cell, never an exact home.
- The send-boundary re-round is subtle but load-bearing: without it, lowering precision
  later would keep leaking the finer grid saved earlier. The `forecast` provider watches
  the precision setting so a change actually recomputes and refetches.
- There is an accuracy/privacy trade the user controls; `balanced` (~1 km) is a
  deliberate default sweet spot — a forecast is still good at town-to-neighbourhood
  scale.
- Rounding bounds precision **per request**; it does not defeat correlation of the *set*
  of places over time (see ADR-0004 and [privacy-model](../privacy-model.md)). We are
  precise that it does the former, not the latter.
- Pairs with the fixed keyless request shape (see
  [privacy-invariant § I2](../reference/privacy-invariant.md#4-the-fixed-request-invariant-i2)):
  rounding coarsens *what* is sent, the fixed shape ensures nothing *else* is.
