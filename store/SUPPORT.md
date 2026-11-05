# FlightWall support

**Support email:** <mranonymous2000@yahoo.com>
**Bug reports and questions:** <https://github.com/seanconnolly2000/flightwall-roku/issues>

FlightWall shows the aircraft flying around your ZIP code on a minimal dark map, with routes,
airline logos and a five-day forecast. It runs as a Roku channel and as a Roku screensaver.

## What you need

- A Roku player or Roku TV on **Roku OS 15.1 or later** (Settings > System > About shows the
  version; Settings > System > System update installs the latest).
- An internet connection. FlightWall talks only to the free services listed in the
  [privacy policy](PRIVACY.md); no account or API key is needed.
- A **US ZIP code**. The map, airport and ZIP data cover the United States (Hawaii included).
- A remote with an `*` (Options) button for the settings screen. Remote keys cannot be injected
  over the network when the Roku's "Control by mobile apps" setting is in Limited mode.

## Installing

**From the Roku Channel Store** (once published): on the Roku, Home > Streaming Channels >
Search Channels, search for "FlightWall", choose Add Channel. Or add it from
<https://channelstore.roku.com/> in a browser while signed in to your Roku account; it installs
on your devices within a few minutes (Home > Settings > System > System update > Check now
forces it).

**From a beta link**: open the invitation link your tester received in a browser, sign in with
the Roku account linked to your device, and accept. Beta channels expire 120 days after they
are created.

**Side-loading the source** (developers): see the project README. In short, enable developer
mode on the Roku, then run `uv run flightwall deploy` from a checkout of the repository.

## First-time setup

1. Open FlightWall. The settings screen appears the first time.
2. Press **OK** on **ZIP code**, type your 5-digit ZIP on the on-screen keyboard, choose OK.
3. Press **OK** on **Radius** until it shows the distance you want (10 to 250 miles).
   25 to 50 miles suits most locations; use less near a busy hub.
4. Choose **Save and apply**. The map centres on your ZIP and the first aircraft appear within a
   few seconds.

Everything can be changed later: press `*` (Options) or **OK** on the main screen.

## Using it as the screensaver

1. Install the **FlightWall screensaver** from the Channel Store (it is listed under
   Screensavers), or, when side-loading, the screensaver build.
2. On the Roku go to **Settings > Theme > Screensavers** and select **FlightWall**.
3. Still under Screensavers, set **Wait time** to how long the Roku should idle before it starts.
4. Choose **Change screensaver settings** on the FlightWall entry to set the ZIP code, radius and
   other options. A screensaver installed from the Channel Store keeps its own settings, separate
   from the FlightWall app, so set the ZIP code in each one you install.

Any button press ends the screensaver, as with every Roku screensaver.

## Settings reference

| Setting | What it does | Default |
|---|---|---|
| ZIP code | Centre of the map and location for the forecast | none |
| Radius | How far out aircraft are shown, 10 to 250 miles (Up/Down on the main screen also changes it) | 50 miles |
| Data source | adsb.fi, adsb.lol or OpenSky Network for aircraft positions (adsb.fi also supplies owner and aircraft type) | adsb.fi |
| OpenSky client ID / secret | Optional free OpenSky account credentials for a higher daily limit (opensky-network.org > Account > API client) | not set |
| Poll every | Refresh interval, 10 to 60 seconds | 10 seconds |
| Route and airline lookups | Origin, destination, airline name and logo per flight | on |
| City labels | Major-city names on the map | on |
| Flight labels and airline logos | Callsign, route and logo next to each aircraft | on |
| Trails and origin lines | Breadcrumb trail and a faint line toward where a flight came from | on |
| Hide aircraft on the ground | Leaves out taxiing traffic that otherwise piles up on airports | on |
| Private aircraft owners | Whether a privately owned plane shows its registered owner's name or just "Private owner" (companies, agencies and airlines are always named) | Private owner |

**Main-screen keys:** `*` or OK opens settings, **Play** shows the activity log (every data
request and its result), **Up/Down** changes the radius, **Back** exits.

## Reading the screen

- **Plane colour**: amber below 10,000 ft, white up to 25,000 ft, blue above; grey on the ground.
- **Route line** (for example `SFO > LAX`) comes from a public flight-number database. When the
  listed leg does not match where the aircraft actually is or is heading, FlightWall hides it
  and shows "Route unknown" rather than a wrong route.
- **Faint line behind a plane** points back toward its origin airport (or back along its track
  when the route is unknown).
- The status line at the bottom shows the last update time, aircraft count and next poll.

## Troubleshooting

**No aircraft, or very few.** Increase the radius; check the status line for an HTTP error; try
another data source in settings. Private and general-aviation aircraft often show only a
registration (N-number) and no route.

**"Rate limited" banner or settings opening on the data source row.** The free feed has asked
this device to slow down. FlightWall backs off automatically. Switch to another free source, or
create a free OpenSky Network account, add its client ID and secret in settings, and choose
OpenSky as the source for a much higher daily allowance.

**Settings do not open when pressing `*`.** Make sure the FlightWall channel (not the
screensaver) is in the foreground; screensavers take no input. If a settings screen is already
open, Back closes it.

**The channel closes by itself after about two hours.** Roku OS exits any channel left without a
remote press for two hours. For an always-on display use FlightWall as the screensaver, which the
OS runs itself during idle time.

**Blank or blue screen on the TV or receiver.** This is the HDMI link, not the app. Power a
streaming stick from its wall adapter rather than a TV or receiver USB port, turn off Settings >
System > Power > Auto power savings, set Display type to a fixed resolution, and turn off
Auto-adjust display refresh rate.

**Everything disappears except the circle and an empty panel.** The Roku ran out of the texture
memory it shares with its home screen, so it stopped drawing updates. Press a button to leave the
screensaver and start it again; the activity log (Play, in the channel) will show "texture memory
low". Avoid running the FlightWall channel and the FlightWall screensaver at the same time, and
keep the radius at 50 miles or less on a streaming stick.

**Forecast missing.** The forecast loads a few seconds after the first aircraft and refreshes
hourly; if the weather service is unreachable it retries every ten minutes.

**Starting over.** Remove the channel and add it again; this clears all saved settings.

## Privacy and terms

FlightWall stores your settings only on the Roku and sends only your ZIP's approximate
coordinates to the data services. Details: [privacy policy](PRIVACY.md) and
[terms of service](TERMS.md).

## Contact

Email <mranonymous2000@yahoo.com> with the Roku model, Roku OS version, the ZIP code and radius
you use, and what the status line at the bottom of the screen says. If you can, press **Play**
and include the last few lines of the activity log.
