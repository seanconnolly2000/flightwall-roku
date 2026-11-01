# Submitting FlightWall to the Roku Channel Store

Publishing is done in the Roku Developer Dashboard under the account that owns the channel, and
every public channel goes through Roku's certification review (typically one to three weeks).
The steps below prepare everything that can be prepared from this repository and then walk
through the dashboard.

## 1. Developer account

1. Sign in at <https://developer.roku.com/> with the Roku account the device is linked to and
   enroll in the (free) Roku Developer Program, accepting the agreement.
2. Keep the device in developer mode (it already is).

## 2. Signing key and signed package

A store package must be signed by a key generated on your Roku. Generate it once and keep the
password: every future update must be signed with the same key.

```bash
uv run flightwall genkey --host <roku-ip>
```

Save the printed **password** and **DevID** somewhere safe (a password manager), and put them in
the git-ignored `.env` as `ROKU_SIGNING_PASSWORD` and `ROKU_DEV_ID` so `sign` finds them. Then
build the screensaver package (Roku rejects screensavers that also have a `Main()` entry point),
install it, and sign it:

```bash
uv run flightwall deploy --screensaver-only
uv run flightwall sign --app-name FlightWall/1.0
uv run flightwall deploy                          # optional: put the interactive build back
```

`sign` saves `dist/flightwall-screensaver.pkg`. Bump `major_version` / `minor_version` /
`build_version` in `roku/manifest` for every submission.

> **Upload the `.pkg`, never the `.zip`.** The zips in `dist/` are for side-loading only. The
> Developer Dashboard rejects them with "The file you uploaded is incorrectly packaged". Only a
> `.pkg` produced by `flightwall sign` (that is, signed by the Roku with your genkey key) is
> accepted, for Beta channels and public channels alike.

## Beta channel (optional first step)

A Beta channel lets up to 20 people install the channel from a link without side-loading, with no
certification review. It expires after 120 days and cannot be renewed (create a new one). Use
**Manage My Channels > Add Channel > Beta** and upload a `.pkg`:

- `dist/flightwall.pkg`: the full interactive channel (map, settings screen, Play for the log).
  Sign it with the interactive build installed: `flightwall deploy` then
  `flightwall sign --out dist/flightwall.pkg`.
- `dist/flightwall-screensaver.pkg`: the screensaver-only build for the Screensavers menu.
  Sign it with that build installed: `flightwall deploy --screensaver-only` then `flightwall sign`.

## 3. Dashboard

In the Developer Dashboard choose **Manage My Channels > Add Channel > Developer SDK**, then:

1. **Properties**: name FlightWall; classification Screensaver; language English; countries United States.
2. **Channel Store Info**: paste the text from `store/LISTING.md`, upload the channel posters
   (`roku/images/icon_focus_*.png`), the screenshots in `store/screenshots/`, and the privacy
   policy URL. Content rating: all audiences.
3. **Monetization**: none.
4. **Package Upload**: upload `dist/flightwall-screensaver.pkg`, set the version (match the
   manifest) and minimum firmware (Roku OS 11 or later is a safe floor; the app uses
   StandardKeyboardDialog, which needs OS 10+).
5. **Static Analysis**: run it and fix anything it flags.
6. **Preview and Publish**: review, then **Submit for publishing**. Roku emails the result.

## 4. Things certification is likely to ask about

- **Screensaver rules**: no user input, no video or audio. FlightWall's screensaver build meets
  this; its settings live in the separate "Change screensaver settings" screen
  (`RunScreenSaverSettings`).
- **Third-party services**: Roku asks publishers to have the right to use the services an app
  depends on. The ADS-B feeds are community projects with dynamic limits and may ask a public app
  to self-host or throttle; OpenSky's data is free for non-commercial use only; the airline-logo
  CDN belongs to Kiwi.com and is not a documented public API. Consider contacting adsb.lol before
  a public release, and consider shipping the store build with logos off by default.
- **Privacy policy**: `store/PRIVACY.md` describes exactly what the app stores and sends; it
  must be reachable at a public URL, which the GitHub link provides once the repo is public.
- **Idle behavior**: screensavers run until a key press; the channel build is subject to Roku's
  two-hour idle exit like every other channel.

## 5. Updates

Bump the manifest version, rebuild, re-sign with the same key, upload the new package, and
submit. Certification is required again for each public update.
