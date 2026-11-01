# FlightWall privacy policy

_Last updated: November 1, 2026_

FlightWall is a Roku channel and screensaver that shows aircraft flying near a location you
choose. It is free, has no accounts, and collects no personal information.

## What the app stores

The settings you enter with the remote are stored only in the Roku's local registry for this
channel: a ZIP code, the coordinates and place name derived from it, a radius, a polling
interval, display preferences and, if you choose to enter them, OpenSky Network API client
credentials. An activity log of the app's own network requests (time, data source, HTTP status,
aircraft count) and settings changes is kept in a separate registry section on the device. Nothing
is stored anywhere else. Removing the channel removes this data.

## What leaves the device

To show flights and weather the app sends requests to the services below. Each request carries
the approximate coordinates of the ZIP code you entered (the ZIP's centroid, to three or four
decimal places) and the radius, plus a generic user-agent string. No account identifiers, device
identifiers, names or email addresses are sent. The services see the IP address of your internet
connection, as with any web request.

- adsb.lol, adsb.fi or OpenSky Network (your choice): aircraft positions around your coordinates.
  If you enter OpenSky credentials, they are sent only to OpenSky's login server to obtain a token.
- adsbdb.com: route and airline details for a flight's callsign.
- images.kiwi.com: airline logo images by airline code.
- api.open-meteo.com: a five-day forecast for your coordinates.

## What the app does not do

No analytics, advertising, tracking, telemetry or crash reporting. No data is sold or shared with
anyone other than the services listed above, and only to fulfil the request you see on screen.

## Open source

The complete source code is available at
<https://github.com/seanconnolly2000/flightwall-roku>, so anything stated here can be verified.

## Contact

Open an issue at <https://github.com/seanconnolly2000/flightwall-roku/issues>.
