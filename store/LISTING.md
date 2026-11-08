# Channel Store listing text

Copy these into the Roku Developer Dashboard (Channel Store Info).

**Channel name:** SkyTraffic

**Channel type:** Screensaver (the submitted package is the screensaver-only build)

**Category:** Screensavers

**Short description (one line):**
Live map of the aircraft flying around your ZIP code, with routes, airline logos and a 5-day forecast.

**App description, SkyTraffic App listing (on-device and online fields, 298 characters):**
Who is flying over your house right now? SkyTraffic App plots every aircraft within 10 to 250 miles of your ZIP: callsign, airline logo, route, altitude, aircraft type and owner, helicopters in orange, trails, a 5-day forecast. Free data, no sign-up. Want it while idle? Get SkyTraffic Screensaver.

**App description, SkyTraffic screensaver listing (on-device and online fields, 297 characters):**
Your TV rests, the sky does not. SkyTraffic Screensaver starts when your Roku idles and plots every aircraft within 10 to 250 miles of your ZIP: callsign, airline logo, route, altitude and type, helicopters in orange, a 5-day forecast. Free data, no sign-up. Want it on demand? Get SkyTraffic App.

**Long description (optional, for the 1,500-character online field):**
SkyTraffic turns your TV into a live flight board. Enter a ZIP code and a radius and it shows every
aircraft nearby on a minimal dark map: black land, deep-blue water, airports and city labels for
orientation. Each flight carries its callsign, altitude-tinted icon, airline logo, origin and
destination, a breadcrumb trail and a faint line pointing back toward where it came from. The
panel spotlights the nearest flight with its airline, aircraft type and route, lists what else
is overhead, and shows a five-day forecast for the same location. Positions refresh every ten
seconds from free, community-run ADS-B feeds; no account or API key is required. If a free feed
rate-limits you, the settings screen offers alternative feeds and optional free OpenSky
credentials. Settings are entered once with the remote and kept on the device.

**Keywords:** flights, aircraft, ADS-B, flight tracker, plane spotting, radar, weather, screensaver, map

**Privacy policy URL:** https://github.com/seanconnolly2000/skytraffic-roku/blob/main/store/PRIVACY.md

**Terms of service URL:** https://github.com/seanconnolly2000/skytraffic-roku/blob/main/store/TERMS.md

**Support URL:** https://github.com/seanconnolly2000/skytraffic-roku/blob/main/store/SUPPORT.md

**Support email:** mranonymous2000@yahoo.com

**Content rating:** All audiences

**Languages:** English

**Countries:** United States (ZIP-code lookup and airport/map data cover the US; Hawaii included, Alaska optional)

**Artwork:**

The dashboard asks for two different kinds of image. Match the size it names in the error to the
file below.

| Dashboard slot | File | Size |
|---|---|---|
| Channel poster, FHD (the store tile), SkyTraffic App listing | `store/artwork/poster-540x405-app.png` | 540 x 405 |
| Channel poster, FHD (the store tile), SkyTraffic screensaver listing | `store/artwork/poster-540x405-screensaver.png` | 540 x 405 |
| Channel poster, FHD, generic (either listing) | `store/artwork/poster-540x405.png` | 540 x 405 |
| Channel poster, HD | `store/artwork/poster-290x218.png` | 290 x 218 |
| Channel poster, SD | `store/artwork/poster-246x140.png` | 246 x 140 |
| Screenshots (16:9) | `store/screenshots/skytraffic-1.jpg`, `skytraffic-2.jpg`, `skytraffic-settings.jpg` | 1920 x 1080 |

The posters are the same artwork the channel ships as its home-screen icons
(`roku/images/icon_focus_*.png`), flattened to opaque PNG. The per-listing 540x405 posters name
the app and the screensaver so shoppers can tell them apart; `uv run skytraffic images`
regenerates them.

Use the files in `store/screenshots/` only. Anything in `dist/` is a build artifact; `skytraffic
screenshot` now always writes 1920 x 1080, so new captures can go straight into `store/screenshots/`.
