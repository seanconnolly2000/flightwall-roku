' Flight data providers: request URLs, response normalisation and error classification.
'
' Normalised aircraft record:
'   hex, callsign, registration, typeCode, lat, lon, altFt, ground, speedKts,
'   track (degrees, -1 unknown), vrate (ft/min), squawk, category, distMi, bearing

function Flights_Blank() as Object
    return {
        hex: ""
        callsign: ""
        registration: ""
        typeCode: ""
        lat: 0.0
        lon: 0.0
        altFt: 0
        ground: false
        speedKts: 0
        track: -1.0
        vrate: 0
        squawk: ""
        category: ""
        distMi: 0.0
        bearing: 0.0
    }
end function

function Flights_MaxNm() as Float
    return 250.0
end function

function Flights_ProviderUrl(provider as String, lat as Float, lon as Float, radiusMiles as Float) as String
    if provider = "opensky" then
        bounds = Geo_BBox(lat, lon, radiusMiles)
        return "https://opensky-network.org/api/states/all?lamin=" + Util_FloatStr(bounds.lamin, 4) + "&lomin=" + Util_FloatStr(bounds.lomin, 4) + "&lamax=" + Util_FloatStr(bounds.lamax, 4) + "&lomax=" + Util_FloatStr(bounds.lomax, 4)
    end if
    nm = Geo_NmFromMiles(radiusMiles)
    if nm > Flights_MaxNm() then nm = Flights_MaxNm()
    if nm < 1 then nm = 1
    base = "https://api.adsb.lol/v2/lat/"
    if provider = "adsbfi" then base = "https://opendata.adsb.fi/api/v2/lat/"
    return base + Util_FloatStr(lat, 4) + "/lon/" + Util_FloatStr(lon, 4) + "/dist/" + Util_Round(nm).ToStr()
end function

' Parses a provider response body into a distance-sorted list of aircraft within the radius.
function Flights_Parse(provider as String, body as String, lat as Float, lon as Float, radiusMiles as Float) as Object
    result = []
    json = ParseJson(body)
    if not Util_IsAA(json) then return result
    rawList = invalid
    if provider = "opensky" then
        rawList = json.states
    else
        rawList = json.ac
        if rawList = invalid then rawList = json.aircraft
    end if
    if not Util_IsArray(rawList) then return result
    for each raw in rawList
        ac = invalid
        if provider = "opensky" then
            ac = Flights_FromOpenSky(raw)
        else
            ac = Flights_FromAdsb(raw)
        end if
        if ac <> invalid then
            ac.distMi = Geo_Haversine(lat, lon, ac.lat, ac.lon)
            if ac.distMi <= radiusMiles * 1.05 then
                ac.bearing = Geo_Bearing(lat, lon, ac.lat, ac.lon)
                result.Push(ac)
            end if
        end if
    end for
    result.SortBy("distMi")
    return result
end function

' adsb.lol / adsb.fi records (readsb JSON).
function Flights_FromAdsb(raw as Object) as Object
    if not Util_IsAA(raw) then return invalid
    if not Util_IsNumber(raw.lat) or not Util_IsNumber(raw.lon) then return invalid
    ac = Flights_Blank()
    ac.hex = LCase(Util_Str(raw.hex))
    ac.callsign = Routes_NormalizeCallsign(Util_Str(raw.flight))
    ac.registration = Util_Str(raw.r)
    ac.typeCode = Util_Str(raw.t)
    ac.lat = raw.lat
    ac.lon = raw.lon
    alt = raw.alt_baro
    if Util_IsString(alt) then
        ac.ground = true
        ac.altFt = 0
    else if Util_IsNumber(alt) then
        ac.altFt = Int(alt)
    else if Util_IsNumber(raw.alt_geom) then
        ac.altFt = Int(raw.alt_geom)
    end if
    ac.speedKts = Util_Round(Util_ToFloat(raw.gs, 0))
    if Util_IsNumber(raw.track) then
        ac.track = raw.track
    else if Util_IsNumber(raw.true_heading) then
        ac.track = raw.true_heading
    else if Util_IsNumber(raw.mag_heading) then
        ac.track = raw.mag_heading
    end if
    if Util_IsNumber(raw.baro_rate) then
        ac.vrate = Int(raw.baro_rate)
    else if Util_IsNumber(raw.geom_rate) then
        ac.vrate = Int(raw.geom_rate)
    end if
    ac.squawk = Util_Str(raw.squawk)
    ac.category = Util_Str(raw.category)
    return ac
end function

' OpenSky state vectors: positional arrays.
function Flights_FromOpenSky(state as Object) as Object
    if not Util_IsArray(state) then return invalid
    if state.Count() < 11 then return invalid
    if not Util_IsNumber(state[6]) or not Util_IsNumber(state[5]) then return invalid
    ac = Flights_Blank()
    ac.hex = LCase(Util_Str(state[0]))
    ac.callsign = Routes_NormalizeCallsign(Util_Str(state[1]))
    ac.lat = state[6]
    ac.lon = state[5]
    ac.ground = (state[8] = true)
    if Util_IsNumber(state[7]) then ac.altFt = Int(state[7] * 3.28084)
    if Util_IsNumber(state[9]) then ac.speedKts = Util_Round(state[9] * 1.94384)
    if Util_IsNumber(state[10]) then ac.track = state[10]
    if Util_IsNumber(state[11]) then ac.vrate = Int(state[11] * 196.85)
    if state.Count() > 14 then ac.squawk = Util_Str(state[14])
    return ac
end function

' Maps an HTTP status to what the UI should do about it.
function Flights_Classify(status as Integer) as Object
    if status = 200 then return { kind: "ok", message: "" }
    if status = 429 then return { kind: "ratelimited", message: "HTTP 429: too many requests" }
    if status = 401 or status = 403 then return { kind: "auth", message: "HTTP " + status.ToStr() + ": not authorized" }
    if status <= 0 then return { kind: "network", message: "network error (" + status.ToStr() + ")" }
    if status >= 500 then return { kind: "server", message: "HTTP " + status.ToStr() + ": server error" }
    return { kind: "http", message: "HTTP " + status.ToStr() }
end function

' Exponential back-off capped at five minutes.
function Flights_Backoff(baseSeconds as Integer, strikes as Integer) as Integer
    seconds = baseSeconds
    for i = 1 to strikes
        seconds = seconds * 2
        if seconds >= 300 then return 300
    end for
    return seconds
end function

' Whether the UI should surface the data-source / API-key screen.
function Flights_NeedsKeyPrompt(kind as String, strikes as Integer, provider as String, hasCredentials as Boolean) as Boolean
    if kind = "auth" then return true
    if kind <> "ratelimited" then return false
    if provider = "opensky" and hasCredentials then return false
    return strikes >= 2
end function

function Flights_AltitudeColor(altFt as Integer, ground as Boolean) as String
    if ground then return "0x8B949EFF"
    if altFt < 10000 then return "0xFFC857FF"
    if altFt < 25000 then return "0xFFFFFFFF"
    return "0x7CC4FFFF"
end function

' Sprite base name for a track, e.g. 94 degrees -> "plane_090".
function Flights_SpriteName(track as Float) as String
    if track < 0 then track = 0
    heading = Int((track / 10.0) + 0.5) * 10
    heading = heading MOD 360
    return "plane_" + Util_PadLeft(heading.ToStr(), 3, "0")
end function

function Flights_DisplayName(ac as Object) as String
    if ac.callsign <> "" then return ac.callsign
    if ac.registration <> "" then return ac.registration
    return UCase(ac.hex)
end function

function Flights_IsOverhead(ac as Object) as Boolean
    return (not ac.ground) and ac.distMi <= 2.0
end function

' Drops aircraft that are on the ground (taxiing traffic clutters airports).
function Flights_Airborne(aircraft as Object) as Object
    kept = []
    for each ac in aircraft
        if ac.ground <> true then kept.Push(ac)
    end for
    return kept
end function
