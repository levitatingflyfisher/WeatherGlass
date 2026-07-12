# How to back up and restore WeatherGlass

WeatherGlass keeps your saved places and settings on-device only — there is no
account and no server of ours to lose them to. Encrypted backup exists so that
"on-device only" doesn't mean "gone if you lose the device."

## What's in a backup

A `.ohbk` file contains, encrypted:

- **Saved places** — every city you've added, at the rounded precision you
  chose.
- **Settings** — units, location precision, and theme.

**The forecast cache is deliberately excluded.** It's disposable derived
data — raw Open-Meteo JSON, re-fetched automatically the next time you open a
saved place (see [`WeatherRepository`](../../lib/features/weather/data/weather_repository.dart)).
Backing it up would bloat every file with public weather data you never
chose, and a restored cache could already be stale the moment it lands.

## Setting up

1. Open **Settings → Backup & Restore → Set up encrypted backup**.
2. Write down the 12 recovery words on paper. **They are the only way to
   recover your data on a new device — WeatherGlass holds no copy, and there
   is no "forgot my words" recovery.**
3. Re-enter the 12 words to confirm you copied them correctly. This turns "I
   clicked OK" into a cryptographic proof the paper copy is right.

## Exporting

**Settings → Backup & Restore → Export backup** encrypts everything above
into a `.ohbk` file and hands it to your device's share sheet — save it to a
file, email it to yourself, put it on a USB stick, whatever you trust. Nothing
is uploaded anywhere by WeatherGlass itself.

## Restoring

**Settings → Backup & Restore → Restore from backup**, then pick a `.ohbk`
file. Restoring is **destructive**: it replaces every saved place and every
setting on this device with what's in the file. You'll see a confirmation
dialog stating that plainly before anything happens — there is no partial or
silent restore.

If this device's key doesn't unlock the file (e.g. a fresh install, or a
backup made under different recovery words), you'll be asked to type the 12
words the backup was made with.

## The honest limits

- **Wrong words, no data.** There is no password reset. If the 12 words are
  lost, an existing `.ohbk` file cannot be decrypted by anyone, including us —
  that's the point of local-only key material, but it means the backup is
  only as safe as the paper it's written on.
- **A rejected restore never touches your data.** A backup from a different
  app, a newer schema than this version of WeatherGlass understands, or a
  corrupt file all fail before any write — you keep what you had.
- **Nothing new leaves the device.** Export writes bytes to the OS share
  sheet you choose; WeatherGlass runs no relay or server of its own. See
  [privacy-model.md](../privacy-model.md#what-stays-on-the-device) for the
  full accounting of what does and doesn't leave.
