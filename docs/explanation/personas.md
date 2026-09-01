# Personas

Agents drive the real WeatherGlass build as these people, per the fleet
testing rule. Each scenario gives a start state, plain steps, what success
looks like, and what to check. "Standard checks" means: text scale 1.3 at
360 dp width, dark mode, and every error in plain words with a way forward.
For this app "offline" means the forecast request fails: airplane mode, or
block `api.open-meteo.com`. Scenarios aim at the weak spots found by the
September 2026 lens audit.

## Primary: Farah, a parent checking the school-run weather

Farah is 39, walks two kids to school, and checks the sky once each morning
at the door, coat half on, phone in one hand. They picked WeatherGlass
because a previous app sold location data.

- **Goal:** see today and the next few hours for home and the kids' school,
  fast, even on a flaky connection.
- **Context:** one-handed, in a hurry, patchy mobile data in the hallway,
  text scale 1.3.
- **Would quit if:** they get a wall of code instead of a forecast.

**F1. Stale forecast on a dead connection.** Start: two places saved; a
forecast fetched over an hour ago. Steps: go offline; open the app. Success:
the last forecast shows with a plain note of how old it is; no
`ClientException` or query string anywhere. Check: the same on the Places
screen; dark mode.

**F2. Read the week at large text.** Start: one place, online. Steps: set
text scale 1.3; read the 7-day rows and the next-hours graph. Success: "Today"
and "98%" are whole, not split over two lines; the hourly numbers grow with
text size. Check: standard checks; the range bar has no fake minimum length.

**F3. Find Settings on first run.** Start: fresh install, no places. Steps:
before adding any place, look for Settings and the "What leaves your device"
screen. Success: both are reachable with words on the controls, before any
coordinate is sent. Check: labels readable without a hover tooltip.

**F4. Add the school's town, then remove it.** Start: Places open. Steps: open
Add a place; type a misspelled town; submit; then add "Porto"; then remove it
from Places. Success: an empty search says "No places found"; there is a
visible Search control; removal can be undone. Check: undo after delete; the
trash icon is not right against the drag handle.

## Secondary: Tomasz, the privacy-minded grandparent

Tomasz is 67, a retired engineer who lives with their daughter's family and
reads every privacy claim twice. They have low vision and use a desktop PWA
at 150 percent zoom as well as a phone.

- **Goal:** confirm exactly what the app sends, including when searching.
- **Context:** large text, reads slowly, checks claims against behaviour.
- **Would quit if:** the privacy screen says something untrue.

**T1. The whole story.** Start: one place saved. Steps: open "What leaves your
device"; read it fully. Success: it mentions the town-name search request as
well as the forecast request; the "Never sent" list is reachable at 1.3.
Check: prose lines are not over-long on a wide window.

**T2. Precision both ways.** Start: two places saved at Precise. Steps: switch
to Coarse; then back to Precise; read the caption and each place. Success:
before the tap, the screen warns that coarsening saved places cannot be
reversed; the caption matches what happened. Check: plain words.

**T3. Backup section.** Start: Settings. Steps: scroll to Backup & Restore.
Success: the heading has content under it, or a plain sentence saying why
not. Check: dark mode; 150 percent zoom on the desktop PWA.
