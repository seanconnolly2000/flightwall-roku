' Route and airline enrichment via adsbdb.com (free, keyless) plus airline logos.

function Routes_NormalizeCallsign(raw as String) as String
    return UCase(raw.Trim())
end function

' Only airline-style callsigns (3 letters + flight number) are worth a route lookup.
function Routes_IsLookupWorthy(callsign as String) as Boolean
    length = Len(callsign)
    if length < 4 or length > 8 then return false
    for i = 1 to 3
        ch = Mid(callsign, i, 1)
        if ch < "A" or ch > "Z" then return false
    end for
    hasDigit = false
    for i = 4 to length
        ch = Mid(callsign, i, 1)
        if ch >= "0" and ch <= "9" then hasDigit = true
    end for
    return hasDigit
end function

function Routes_Url(callsign as String) as String
    return "https://api.adsbdb.com/v0/callsign/" + callsign
end function

function Routes_Empty() as Object
    return {
        found: false
        airlineName: ""
        airlineIata: ""
        airlineIcao: ""
        originIata: ""
        originCity: ""
        originLat: 0.0
        originLon: 0.0
        destIata: ""
        destCity: ""
        destLat: 0.0
        destLon: 0.0
    }
end function

function Routes_Parse(body as String) as Object
    route = Routes_Empty()
    json = ParseJson(body)
    if not Util_IsAA(json) then return route
    if not Util_IsAA(json.response) then return route
    flightroute = json.response.flightroute
    if not Util_IsAA(flightroute) then return route
    airline = flightroute.airline
    if Util_IsAA(airline) then
        route.airlineName = Util_Str(airline.name)
        route.airlineIata = UCase(Util_Str(airline.iata))
        route.airlineIcao = UCase(Util_Str(airline.icao))
    end if
    origin = flightroute.origin
    if Util_IsAA(origin) then
        route.originIata = UCase(Util_Str(origin.iata_code))
        route.originCity = Util_Str(origin.municipality)
        route.originLat = Util_ToFloat(origin.latitude, 0)
        route.originLon = Util_ToFloat(origin.longitude, 0)
    end if
    destination = flightroute.destination
    if Util_IsAA(destination) then
        route.destIata = UCase(Util_Str(destination.iata_code))
        route.destCity = Util_Str(destination.municipality)
        route.destLat = Util_ToFloat(destination.latitude, 0)
        route.destLon = Util_ToFloat(destination.longitude, 0)
    end if
    route.found = (route.originIata <> "" or route.destIata <> "")
    return route
end function

function Routes_HasOrigin(route as Object) as Boolean
    if route = invalid then return false
    if not route.found then return false
    return route.originLat <> 0 or route.originLon <> 0
end function

' Airline logo by two-letter IATA code (same public CDN OpenFlightWall uses).
function Routes_LogoUrl(airlineIata as String) as String
    if Len(airlineIata) <> 2 then return ""
    return "https://images.kiwi.com/airlines/64/" + airlineIata + ".png"
end function

' "SFO > SIN"; unknown ends become "?".
function Routes_Label(route as Object) as String
    if route = invalid or not route.found then return ""
    origin = route.originIata
    if origin = "" then origin = "?"
    dest = route.destIata
    if dest = "" then dest = "?"
    return origin + " > " + dest
end function

' "San Francisco to Singapore"
function Routes_CityLabel(route as Object) as String
    if route = invalid or not route.found then return ""
    origin = route.originCity
    if origin = "" then origin = route.originIata
    dest = route.destCity
    if dest = "" then dest = route.destIata
    if origin = "" and dest = "" then return ""
    if origin = "" then origin = "unknown"
    if dest = "" then dest = "unknown"
    return origin + " to " + dest
end function

function Routes_HasBothEnds(route as Object) as Boolean
    if route = invalid or not route.found then return false
    if route.originLat = 0 and route.originLon = 0 then return false
    return not (route.destLat = 0 and route.destLon = 0)
end function

' Returns a copy of the route with origin and destination exchanged.
function Routes_Swap(route as Object) as Object
    out = Util_CopyAA(route)
    out.originIata = route.destIata
    out.originCity = route.destCity
    out.originLat = route.destLat
    out.originLon = route.destLon
    out.destIata = route.originIata
    out.destCity = route.originCity
    out.destLat = route.originLat
    out.destLon = route.originLon
    return out
end function

' Checks a looked-up route against where the aircraft actually is and where it is
' going. Flight numbers are reused across legs and days, so the database answer
' can be stale (a BOS-JFK leg for a plane over California) or reversed (KOA-OAK
' for a plane climbing out of Oakland toward Hawaii). Returns a copy that is
' corrected, or marked not found (airline details are kept) when it cannot fit.
function Routes_Reconcile(route as Object, ac as Object) as Object
    if not Routes_HasBothEnds(route) then return route
    out = Util_CopyAA(route)
    lat = Util_ToFloat(ac.lat)
    lon = Util_ToFloat(ac.lon)
    toOrigin = Geo_Haversine(lat, lon, route.originLat, route.originLon)
    toDest = Geo_Haversine(lat, lon, route.destLat, route.destLon)
    total = Geo_Haversine(route.originLat, route.originLon, route.destLat, route.destLon)
    if toOrigin + toDest > total * 1.25 + 100 then
        out.found = false
        out.rejected = true
        return out
    end if
    vrate = Util_ToInt(ac.vrate)
    track = Util_ToFloat(ac.track, -1)
    swap = false
    if vrate > 500 and toDest < 40 and toOrigin > 150 then
        swap = true
    else if vrate < -500 and toOrigin < 40 and toDest > 150 then
        swap = true
    else if track >= 0 and toOrigin > 40 and toDest > 40 then
        awayFromDest = Geo_AngleDiff(track, Geo_Bearing(lat, lon, route.destLat, route.destLon)) > 110
        towardOrigin = Geo_AngleDiff(track, Geo_Bearing(lat, lon, route.originLat, route.originLon)) < 70
        if awayFromDest and towardOrigin then
            swap = true
        else if awayFromDest then
            out.found = false
            out.rejected = true
            return out
        end if
    end if
    if swap then return Routes_Swap(out)
    return out
end function

' Picks up to maxCount callsigns (nearest first) that still need a route lookup.
function Routes_Pick(aircraft as Object, cache as Object, maxCount as Integer) as Object
    picks = []
    chosen = {}
    for each ac in aircraft
        if picks.Count() < maxCount then
            callsign = ac.callsign
            if Routes_IsLookupWorthy(callsign) and not cache.DoesExist(callsign) and not chosen.DoesExist(callsign) then
                picks.Push(callsign)
                chosen[callsign] = true
            end if
        end if
    end for
    return picks
end function
