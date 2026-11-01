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
the git-ignored `.env` as `ROKU_SIGNING_PASSWORD` and `ROKU_DEV_ID` so `sign` finds them.
Expect one side effect: Roku keys a side-loaded app's saved settings by developer ID, so the
next launch after `genkey` starts with an empty registry (ZIP, radius and preferences must be
re-entered, or passed as launch parameters). Then
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

## Which package for which submission

**One listing holds one package.** The dashboard has no screensaver type to pick; it works out
the type from the package itself. A package whose manifest has `screensaver_title` **and no
`title`** is detected as a screensaver ("package detected as Screensaver" in static analysis);
anything with `title` is a channel. A channel may not contain screensaver entry points or
`screensaver_*` attributes, and a screensaver may not contain `Main()`. The tooling builds a
clean package for each, so to publish both you create **two listings**:

| Listing | Build | Produce the `.pkg` |
|---|---|---|
| FlightWall (channel) | `--channel-only`: no screensaver code or manifest lines | `flightwall deploy --channel-only` then `flightwall sign --out dist/flightwall-channel.pkg` |
| FlightWall screensaver | `--screensaver-only`: no `Main()`, no `title` | `flightwall deploy --screensaver-only` then `flightwall sign` |

The default combined build (both `title` and `screensaver_title`) is only for local
side-loading. Uploading the screensaver package while its manifest still had `title` is what
produced "Channel type is channel but Main() ... is missing" plus three "in-channel screensaver"
errors.

Screensavers may not handle remote keys at all: static analysis reports "Your screensaver is
using a prohibited OnKeyEvent() method" for any `onKeyEvent` function in the package. The key
handlers therefore live in `components/*Keys.brs` files, which the screensaver build leaves out
(and whose `<script>` references it removes from the component XML).

The dashboard's App type menu has no "Screensaver" entry, so static analysis on a screensaver
package shows the warning "Channel type mismatch: Channel Store reports App, package detected as
Screensaver". It is a warning, not an error; the package type is what Roku uses.

Other static-analysis requirements already met by the current manifest and code: `rsg_version=1.3`
with minimum Roku OS 15.1, no `subtitle` attribute, no `InitClientCertificates()`, and the
roAppMemoryMonitor / low-memory event integration (mandatory for certification since
October 2026). Name the channel plainly "FlightWall": names containing "Roku" are flagged.

## Beta channel (optional first step)

A Beta channel lets up to 20 people install the channel from a link without side-loading, with no
certification review. It expires after 120 days and cannot be renewed (create a new one). Use
**Manage My Channels > Add Channel > Beta** and upload a `.pkg`:

- `dist/flightwall-channel.pkg`: the interactive channel (map, settings screen, Play for the log),
  for a Beta channel of type "channel".
- `dist/flightwall-screensaver.pkg`: the screensaver-only build, for a Beta channel of type
  "screensaver".

## From beta to public

A beta app cannot be promoted or converted; Roku's guide says to "create a public app using your
tested package file" once testing is done. The beta keeps running separately until it expires
(120 days). So:

1. **Manage My Channels > Add Channel > Developer SDK > Public.** Name it FlightWall (no "Roku"
   in the name), distribution United States, language English.
2. Re-enter the listing: copy the text from `store/LISTING.md`, upload the posters from
   `store/artwork/` and the screenshots from `store/screenshots/`, set the privacy, terms and
   support URLs and the support email. Classification: Screensavers (for the screensaver package)
   or an appropriate channel category (for the channel package). Content rating: all audiences.
3. **App Profile**: app type, contact information, and a vanity access code if you want one
   (lets people add the channel from `my.roku.com/add/<code>` immediately after publication).
4. **Monetization**: none (free, no ads).
5. **App Package**: upload the **same signed `.pkg`** that passed in the beta, minimum firmware
   Roku OS 15.1 or later.
6. **Deep linking**: a screensaver has no content to deep-link; for the channel listing, state
   that the app has no deep-linkable content (it shows live data only).
7. **Static Analysis**: run it; every error must be cleared (warnings are allowed).
8. **App Behavior Analysis** (Roku's automated runtime test) runs after upload; fix anything it
   reports.
9. **Preview and Publish > Submit for publishing** and pick a publish date. Roku's reviewers
   then certify the app, typically within one to two weeks, and email the outcome. Once published,
   the app appears in its Streaming Store category within minutes and in search within a day.

The beta listing can be deleted once the public app is live, or left to expire.

## 3. Dashboard

In the Developer Dashboard choose **Manage My Channels > Add Channel > Developer SDK**, then:

1. **Properties**: name FlightWall; classification Screensaver; language English; countries United States.
2. **Channel Store Info**: paste the text from `store/LISTING.md`, upload the channel posters
   (`roku/images/icon_focus_*.png`), the 16:9 screenshots from `store/screenshots/` (all exactly
   1920 x 1080; the dashboard rejects any other size, and files in `dist/` are not screenshots),
   and the privacy policy and terms of service URLs (`store/PRIVACY.md`, `store/TERMS.md` on
   GitHub), the support URL (`store/SUPPORT.md`) and support email. Content rating: all audiences.
3. **Monetization**: none.
4. **Package Upload**: upload `dist/flightwall-screensaver.pkg` (or `flightwall-channel.pkg`
   for a channel-type listing), set the version to match the manifest, and set the minimum
   firmware to Roku OS 15.1, which `rsg_version=1.3` requires.
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
