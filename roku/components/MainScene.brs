' Orchestrates settings, ZIP lookup, polling, back-off and the panels.
' The same scene runs as the channel (interactive) and as the screensaver.

sub init()
    m.top.backgroundColor = "0x000000FF"
    m.map = m.top.findNode("map")
    m.panel = m.top.findNode("panel")
    m.diag = m.top.findNode("diag")
    m.settingsPanel = m.top.findNode("settingsPanel")
    m.pollTimer = m.top.findNode("pollTimer")
    m.clockTimer = m.top.findNode("clockTimer")
    m.weatherTimer = m.top.findNode("weatherTimer")
    m.weatherKey = ""

    m.screensaver = false
    m.started = false
    m.settings = Settings_Load()
    m.audit = Audit_Load()
    m.routes = {}
    m.owners = {}
    m.airlines = {}
    m.aircraft = []
    m.strikes = 0
    m.busy = false
    m.token = ""
    m.tokenExpiry = 0
    m.credits = -1
    m.pollCount = 0

    loadStaticData()

    m.flightTask = CreateObject("roSGNode", "FlightTask")
    m.flightTask.observeField("result", "onFlightResult")
    m.lookupTask = CreateObject("roSGNode", "LookupTask")
    m.lookupTask.observeField("result", "onLookupResult")
    m.weatherTask = CreateObject("roSGNode", "WeatherTask")
    m.weatherTask.observeField("result", "onWeatherResult")
    m.pollTimer.observeField("fire", "onPollTimer")
    m.clockTimer.observeField("fire", "onClockTimer")
    m.weatherTimer.observeField("fire", "onWeatherTimer")
    m.settingsPanel.observeField("result", "onSettingsResult")
    m.map.observeField("warning", "onMapWarning")

    startClock()
    m.top.setFocus(true)
end sub

' The clock shows minutes only, so wake up once per minute, aligned to the minute.
sub startClock()
    m.panel.clock = Format_Now(false)
    now = CreateObject("roDateTime")
    now.ToLocalTime()
    m.clockTimer.control = "stop"
    m.clockTimer.repeat = false
    m.clockTimer.duration = 61 - now.GetSeconds()
    m.clockTimer.control = "start"
end sub

sub onClockTimer()
    m.panel.clock = Format_Now(false)
    if not m.clockTimer.repeat then
        m.clockTimer.control = "stop"
        m.clockTimer.repeat = true
        m.clockTimer.duration = 60
        m.clockTimer.control = "start"
    end if
end sub

' Forecast: fetched once per location, refreshed hourly, retried after ten minutes on failure.
sub requestWeather()
    if not Settings_IsConfigured(m.settings) then return
    key = Util_Str(m.settings.lat) + "," + Util_Str(m.settings.lon)
    if key = m.weatherKey then return
    m.weatherKey = key
    fetchWeather()
end sub

sub fetchWeather()
    m.weatherTask.request = { lat: Util_ToFloat(m.settings.lat), lon: Util_ToFloat(m.settings.lon) }
    m.weatherTask.control = "RUN"
end sub

sub onWeatherTimer()
    fetchWeather()
end sub

sub onWeatherResult()
    result = m.weatherTask.result
    if not Util_IsAA(result) then return
    m.weatherTimer.control = "stop"
    if result.ok = true then
        m.panel.weather = { ok: true, days: result.days }
        logEvent("weather", "Open-Meteo " + result.days.Count().ToStr() + " days")
        m.weatherTimer.duration = 3600
    else
        m.panel.weather = { ok: false, days: [] }
        logEvent("weather-error", Util_Str(result.message))
        m.weatherTimer.duration = 600
    end if
    m.weatherTimer.control = "start"
end sub

sub loadStaticData()
    tilesIndex = ParseJson(ReadAsciiFile("pkg:/images/tiles/index.json"))
    if Util_IsAA(tilesIndex) then m.map.tiles = tilesIndex
    airportsJson = ParseJson(ReadAsciiFile("pkg:/data/airports.json"))
    if Util_IsAA(airportsJson) and Util_IsArray(airportsJson.airports) then m.map.airports = airportsJson.airports
    citiesJson = ParseJson(ReadAsciiFile("pkg:/data/cities.json"))
    if Util_IsAA(citiesJson) and Util_IsArray(citiesJson.cities) then m.map.cities = citiesJson.cities
end sub

sub onLaunch()
    params = m.top.launchParams
    if Util_IsAA(params) and params.screensaver = true then m.screensaver = true
    m.panel.screensaver = m.screensaver
    if m.started then return
    m.started = true
    mode = "channel"
    if m.screensaver then mode = "screensaver"
    logEvent("start", mode + " on " + deviceLabel())
    applyLaunchParams(params)
    start()
end sub

' ZIP and radius passed on the launch command line (ECP launch/dev?zip=...&radius=...).
sub applyLaunchParams(params as Object)
    if not Util_IsAA(params) then return
    zip = Util_Str(params.zip)
    radius = Util_Str(params.radius)
    changed = false
    if Settings_IsZipValid(zip) and zip <> Util_Str(m.settings.zip) then
        m.settings.zip = zip
        m.settings.lat = ""
        m.settings.lon = ""
        m.settings.place = ""
        changed = true
    end if
    if radius <> "" and Util_ToFloat(radius, 0) >= 5 and Util_ToFloat(radius, 0) <= 250 then
        m.settings.radius = Util_Round(Util_ToFloat(radius, 50)).ToStr()
        changed = true
    end if
    poll = Util_Str(params.poll)
    if poll <> "" and Util_ToInt(poll, 0) >= 5 and Util_ToInt(poll, 0) <= 600 then
        m.settings.pollSeconds = Util_ToInt(poll, 10).ToStr()
        changed = true
    end if
    source = LCase(Util_Str(params.provider))
    if source <> "" and Settings_IsProvider(source) and source <> Util_Str(m.settings.provider) then
        m.settings.provider = source
        m.token = ""
        m.tokenExpiry = 0
        changed = true
    end if
    if changed then
        Settings_Save(m.settings)
        logEvent("settings", "launch parameters: zip=" + Util_Str(m.settings.zip) + " radius=" + Util_Str(m.settings.radius) + " poll=" + Util_Str(m.settings.pollSeconds) + "s")
    end if
end sub

function deviceLabel() as String
    info = CreateObject("roDeviceInfo")
    return info.GetModelDisplayName() + " (" + info.GetModel() + ") OS " + info.GetOSVersion().major + "." + info.GetOSVersion().minor
end function

sub logEvent(event as String, detail as String)
    Audit_Append(m.audit, Audit_Now(event, detail))
    if m.diag.visible then m.diag.lines = m.audit
end sub

sub onMapWarning()
    text = m.map.warning
    if text = "" then return
    ? "[SkyTraffic] warning: " + text
    logEvent("warning", text)
    Audit_Save(m.audit)
end sub

' Memory snapshots from the main thread: log warnings always, routine readings only
' when usage moved by five points or more.
sub onMemoryStatus()
    status = m.top.memoryStatus
    if not Util_IsAA(status) then return
    percent = Util_ToInt(status.percent, -1)
    reason = Util_Str(status.reason)
    if m.lastMemoryPercent = invalid then m.lastMemoryPercent = -100
    routine = (reason = "periodic" or reason = "start")
    if routine and percent >= 0 and Abs(percent - m.lastMemoryPercent) < 5 then return
    m.lastMemoryPercent = percent
    detail = ""
    if percent >= 0 then detail = percent.ToStr() + "% of app memory limit"
    availableKb = Util_ToInt(status.availableKb, -1)
    if availableKb >= 0 then detail = detail + ", " + (availableKb \ 1024).ToStr() + " MB available"
    if detail = "" then detail = "memory monitor not supported on this device"
    if not routine then detail = reason + ": " + detail
    logEvent("memory", detail)
    if reason = "warning" or percent >= 85 then Audit_Save(m.audit)
end sub

' Entry point after launch and after every settings change.
sub start()
    m.top.setFocus(true)
    applySettingsToViews()
    if not Settings_IsZipValid(Util_Str(m.settings.zip)) then
        if m.screensaver then
            m.panel.banner = "Set your ZIP code first. On the Roku go to Settings > Theme > Screensavers, select SkyTraffic, then choose Change screensaver settings."
        else
            openSettings("Welcome to SkyTraffic. Enter your ZIP code and pick a radius to begin.", "zip")
        end if
        return
    end if
    if not Settings_IsConfigured(m.settings) then
        lookupZip(Util_Str(m.settings.zip))
        return
    end if
    startPolling()
end sub

sub applySettingsToViews()
    m.map.options = {
        cityLabels: Settings_Flag(m.settings, "cityLabels")
        planeLabels: Settings_Flag(m.settings, "planeLabels")
        trails: Settings_Flag(m.settings, "trails")
    }
    if Settings_IsConfigured(m.settings) then
        m.map.center = {
            lat: Util_ToFloat(m.settings.lat)
            lon: Util_ToFloat(m.settings.lon)
            radiusMiles: Settings_Radius(m.settings)
        }
    end if
    m.panel.location = {
        zip: Util_Str(m.settings.zip)
        place: Util_Str(m.settings.place)
        radius: Settings_Radius(m.settings)
        provider: Settings_ProviderName(Util_Str(m.settings.provider))
    }
end sub

sub lookupZip(zip as String)
    m.panel.banner = "Looking up ZIP " + zip + "..."
    m.lookupTask.zip = zip
    m.lookupTask.control = "RUN"
end sub

sub onLookupResult()
    result = m.lookupTask.result
    if not Util_IsAA(result) then return
    if result.ok then
        m.settings.lat = Util_FloatStr(result.lat, 5)
        m.settings.lon = Util_FloatStr(result.lon, 5)
        m.settings.place = Util_Str(result.place)
        Settings_Save(m.settings)
        logEvent("zip", Util_Str(result.zip) + " -> " + m.settings.lat + "," + m.settings.lon + " " + m.settings.place)
        Audit_Save(m.audit)
        m.panel.banner = ""
        applySettingsToViews()
        startPolling()
    else
        logEvent("zip-error", Util_Str(result.message))
        if m.screensaver then
            m.panel.banner = Util_Str(result.message)
        else
            openSettings(Util_Str(result.message) + ". Please check the ZIP code.", "zip")
        end if
    end if
end sub

sub startPolling()
    m.strikes = 0
    m.pollTimer.control = "stop"
    m.pollTimer.duration = Settings_PollSeconds(m.settings)
    m.pollTimer.control = "start"
    requestWeather()
    poll()
end sub

sub onPollTimer()
    poll()
end sub

sub poll()
    if m.busy then return
    if m.settingsPanel.visible then return
    if not Settings_IsConfigured(m.settings) then return
    lat = Util_ToFloat(m.settings.lat)
    lon = Util_ToFloat(m.settings.lon)
    radius = Settings_Radius(m.settings)
    provider = Util_Str(m.settings.provider)
    lookups = []
    ownerLookups = []
    airlineLookups = []
    if Settings_Flag(m.settings, "routes") then
        lookups = Routes_Pick(m.aircraft, m.routes, 1)
        ownerLookups = Operators_PickOwnerLookups(m.aircraft, m.routes, m.airlines, m.owners, 1)
        airlineLookups = Operators_PickAirlineLookups(m.aircraft, m.routes, m.airlines, 1)
    end if
    m.flightTask.request = {
        provider: provider
        url: Flights_ProviderUrl(provider, lat, lon, radius)
        lat: lat
        lon: lon
        radius: radius
        clientId: Util_Str(m.settings.openskyClientId)
        clientSecret: Util_Str(m.settings.openskyClientSecret)
        token: m.token
        tokenExpiry: m.tokenExpiry
        routeLookups: lookups
        ownerLookups: ownerLookups
        airlineLookups: airlineLookups
    }
    m.busy = true
    m.flightTask.control = "RUN"
end sub

sub onFlightResult()
    m.busy = false
    result = m.flightTask.result
    if not Util_IsAA(result) then return
    m.pollCount = m.pollCount + 1
    m.token = Util_Str(result.token)
    m.tokenExpiry = Util_ToInt(result.tokenExpiry, 0)
    providerName = Settings_ProviderName(Util_Str(m.settings.provider))
    if result.ok then
        m.strikes = 0
        m.aircraft = result.aircraft
        if Settings_Flag(m.settings, "hideGround") then m.aircraft = Flights_Airborne(m.aircraft)
        m.aircraft = Flights_Nearest(m.aircraft, 20)
        if Util_IsAA(result.routes) then
            for each callsign in result.routes
                m.routes[callsign] = result.routes[callsign]
            end for
        end if
        if Util_IsAA(result.owners) then
            for each hex in result.owners
                m.owners[hex] = result.owners[hex]
            end for
        end if
        if Util_IsAA(result.airlines) then
            for each prefix in result.airlines
                m.airlines[prefix] = result.airlines[prefix]
            end for
        end if
        Operators_TrimCache(m.routes, 500)
        Operators_TrimCache(m.owners, 300)
        Operators_TrimCache(m.airlines, 300)
        m.credits = Util_ToInt(result.credits, -1)
        displayRoutes = reconcileRoutes(m.aircraft)
        decorateAircraft(m.aircraft, displayRoutes)
        m.map.routes = displayRoutes
        m.map.aircraft = m.aircraft
        m.panel.routes = displayRoutes
        m.panel.aircraft = m.aircraft
        m.panel.banner = ""
        normal = Settings_PollSeconds(m.settings)
        if m.pollTimer.duration <> normal then
            m.pollTimer.control = "stop"
            m.pollTimer.duration = normal
            m.pollTimer.control = "start"
        end if
        logEvent("poll", providerName + " HTTP 200 " + m.aircraft.Count().ToStr() + " aircraft " + Util_ToInt(result.elapsedMs).ToStr() + " ms")
    else
        m.strikes = m.strikes + 1
        backoff = Flights_Backoff(Settings_PollSeconds(m.settings), m.strikes)
        m.pollTimer.control = "stop"
        m.pollTimer.duration = backoff
        m.pollTimer.control = "start"
        logEvent("poll-error", providerName + " " + Util_Str(result.kind) + " " + Util_Str(result.message) + " (retry in " + backoff.ToStr() + "s)")
        m.panel.banner = describeError(result, providerName, backoff)
        if not m.screensaver and not m.settingsPanel.visible then
            if Flights_NeedsKeyPrompt(Util_Str(result.kind), m.strikes, Util_Str(m.settings.provider), Settings_HasCredentials(m.settings)) then
                openSettings(keyPrompt(result, providerName), "provider")
            end if
        end if
    end if
    m.panel.status = {
        updated: Format_Now(true)
        count: m.aircraft.Count()
        credits: m.credits
        kind: Util_Str(result.kind)
        message: Util_Str(result.message)
        nextSeconds: m.pollTimer.duration
    }
    ' Persist the log rarely: registry writes hit flash. Errors and every ten minutes.
    if (m.pollCount MOD 60 = 0) or not result.ok then Audit_Save(m.audit)
end sub

' Fills operatorName/operatorKind/modelName on each aircraft from the route, the bundled
' and looked-up airline names, the registry owner, and the viewer's owner-name setting.
' The registry type and model also settle whether an aircraft is a helicopter when the
' feed itself did not say.
sub decorateAircraft(aircraft as Object, displayRoutes as Object)
    showNames = Settings_Flag(m.settings, "ownerNames")
    for each ac in aircraft
        route = displayRoutes[Util_Str(ac.callsign)]
        airline = ""
        prefix = Operators_Prefix(Util_Str(ac.callsign))
        if prefix <> "" then airline = Util_Str(m.airlines[prefix])
        owner = m.owners[Util_Str(ac.hex)]
        resolved = Operators_Resolve(ac, route, airline, owner, showNames)
        ac.operatorName = resolved.name
        ac.operatorKind = resolved.kind
        if Util_Str(ac.typeCode) = "" and owner <> invalid then ac.typeCode = Util_Str(owner.typeCode)
        ac.modelName = Operators_Model(ac, owner)
        if ac.helicopter <> true then ac.helicopter = Flights_IsHelicopter(ac)
    end for
end sub

' Routes are cached per callsign; check each one against the aircraft that carries it.
function reconcileRoutes(aircraft as Object) as Object
    display = {}
    for each ac in aircraft
        callsign = Util_Str(ac.callsign)
        if callsign <> "" and m.routes.DoesExist(callsign) then
            display[callsign] = Routes_Reconcile(m.routes[callsign], ac)
        end if
    end for
    return display
end function

function describeError(result as Object, providerName as String, backoff as Integer) as String
    kind = Util_Str(result.kind)
    retry = " Retrying in " + backoff.ToStr() + " seconds."
    if kind = "ratelimited" then return providerName + " is rate limiting this device (HTTP 429)." + retry + " Press * to switch data source or add OpenSky credentials."
    if kind = "auth" then return providerName + " rejected the request (" + Util_Str(result.message) + "). Press * to check the credentials."
    if kind = "network" then return "Network problem reaching " + providerName + ": " + Util_Str(result.message) + "." + retry
    return providerName + " error: " + Util_Str(result.message) + "." + retry
end function

function keyPrompt(result as Object, providerName as String) as String
    if Util_Str(result.kind) = "auth" then
        return providerName + " rejected the credentials. Check the OpenSky client ID and secret, or switch data source."
    end if
    return providerName + " has rate limited this device (HTTP 429). Switch to another free data source, or add free OpenSky account credentials for a higher daily limit."
end function

sub openSettings(message as String, focusRow as String)
    m.pollTimer.control = "stop"
    m.settingsPanel.message = message
    m.settingsPanel.focusRow = focusRow
    m.settingsPanel.settings = m.settings
    m.settingsPanel.visible = true
    m.settingsPanel.setFocus(true)
end sub

sub onSettingsResult()
    result = m.settingsPanel.result
    if not Util_IsAA(result) then return
    m.settingsPanel.visible = false
    m.top.setFocus(true)
    if result.saved = true then
        previous = m.settings
        m.settings = Settings_Defaults()
        m.settings.Append(result.settings)
        if Util_Str(previous.zip) <> Util_Str(m.settings.zip) then
            m.settings.lat = ""
            m.settings.lon = ""
            m.settings.place = ""
        end if
        providerChanged = Util_Str(previous.provider) <> Util_Str(m.settings.provider)
        credentialsChanged = Util_Str(previous.openskyClientId) <> Util_Str(m.settings.openskyClientId) or Util_Str(previous.openskyClientSecret) <> Util_Str(m.settings.openskyClientSecret)
        if providerChanged or credentialsChanged then
            m.token = ""
            m.tokenExpiry = 0
            m.strikes = 0
        end if
        Settings_Save(m.settings)
        logEvent("settings", "saved from remote: zip=" + Util_Str(m.settings.zip) + " radius=" + Util_Str(m.settings.radius) + " source=" + Util_Str(m.settings.provider) + " poll=" + Util_Str(m.settings.pollSeconds) + "s credentials=" + Util_Str(Settings_HasCredentials(m.settings)))
        Audit_Save(m.audit)
        start()
    else if Settings_IsConfigured(m.settings) then
        startPolling()
    else
        m.panel.banner = "Press * to enter your ZIP code."
    end if
end sub

sub toggleDiagnostics()
    m.diag.visible = not m.diag.visible
    if m.diag.visible then m.diag.lines = m.audit
end sub

' Remote-key handling is in MainSceneKeys.brs (channel build only).
