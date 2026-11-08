' One poll of the flight data provider plus a few small enrichment lookups
' (routes, registry owners, airline names). Runs on the Task thread; every network
' call lives here and nowhere else. HTTP connections are kept alive between polls.

sub init()
    m.top.functionName = "runTask"
    m.http = {}
    m.airlineTable = invalid
end sub

sub runTask()
    req = m.top.request
    timer = CreateObject("roTimespan")
    result = {
        ok: false
        kind: "network"
        status: 0
        message: ""
        aircraft: []
        routes: {}
        owners: {}
        airlines: {}
        credits: -1
        token: ""
        tokenExpiry: 0
        elapsedMs: 0
        provider: ""
    }
    if not Util_IsAA(req) then
        result.message = "no request"
        m.top.result = result
        return
    end if
    result.provider = Util_Str(req.provider)
    headers = { "User-Agent": "SkyTraffic-Roku/1.0", "Accept": "application/json" }

    token = Util_Str(req.token)
    tokenExpiry = Util_ToInt(req.tokenExpiry, 0)
    clientId = Util_Str(req.clientId)
    clientSecret = Util_Str(req.clientSecret)
    if result.provider = "opensky" and clientId <> "" and clientSecret <> "" then
        nowSeconds = Http_NowSeconds()
        if token = "" or nowSeconds >= tokenExpiry - 60 then
            tokenResult = Task_FetchOpenSkyToken(clientId, clientSecret)
            if tokenResult.ok then
                token = tokenResult.token
                tokenExpiry = nowSeconds + tokenResult.expiresIn
            else
                token = ""
                tokenExpiry = 0
                result.message = "OpenSky login failed (" + tokenResult.message + "); "
            end if
        end if
    else
        token = ""
        tokenExpiry = 0
    end if
    if token <> "" then headers["Authorization"] = "Bearer " + token
    result.token = token
    result.tokenExpiry = tokenExpiry

    response = Http_Request(m.http, "GET", Util_Str(req.url), headers, "", 15000)
    result.status = response.status
    classified = Flights_Classify(response.status)
    result.kind = classified.kind
    result.message = result.message + classified.message
    if response.status <= 0 and Util_Str(response.reason) <> "" then result.message = result.message + " " + response.reason

    if classified.kind = "ok" then
        result.ok = true
        result.aircraft = Flights_Parse(result.provider, response.body, Util_ToFloat(req.lat), Util_ToFloat(req.lon), Util_ToFloat(req.radius, 50))
        Task_ApplyAirlineTable(result.aircraft)
        result.credits = Http_HeaderInt(response.headers, "x-rate-limit-remaining")
        lookupHeaders = { "User-Agent": "SkyTraffic-Roku/1.0", "Accept": "application/json" }
        lookups = req.routeLookups
        if Util_IsArray(lookups) then
            for each callsign in lookups
                routeResponse = Http_Request(m.http, "GET", Routes_Url(callsign), lookupHeaders, "", 8000)
                if routeResponse.status = 200 then
                    result.routes[callsign] = Routes_Parse(routeResponse.body)
                else if routeResponse.status = 404 then
                    result.routes[callsign] = Routes_Empty()
                end if
            end for
        end if
        owners = req.ownerLookups
        if Util_IsArray(owners) then
            for each hex in owners
                ownerResponse = Http_Request(m.http, "GET", Operators_AircraftUrl(hex), lookupHeaders, "", 8000)
                if ownerResponse.status = 200 or ownerResponse.status = 404 then
                    result.owners[hex] = Operators_ParseAircraft(ownerResponse.body)
                end if
            end for
        end if
        airlines = req.airlineLookups
        if Util_IsArray(airlines) then
            for each prefix in airlines
                airlineResponse = Http_Request(m.http, "GET", Operators_AirlineUrl(prefix), lookupHeaders, "", 8000)
                if airlineResponse.status = 200 or airlineResponse.status = 404 then
                    result.airlines[prefix] = Operators_ParseAirline(airlineResponse.body)
                end if
            end for
        end if
    end if
    result.elapsedMs = timer.TotalMilliseconds()
    m.top.result = result
end sub

' Fills ac.airlineName from the bundled ICAO airline table (no network).
sub Task_ApplyAirlineTable(aircraft as Object)
    if m.airlineTable = invalid then m.airlineTable = ReadAsciiFile("pkg:/data/airlines.txt")
    for each ac in aircraft
        prefix = Operators_Prefix(ac.callsign)
        if prefix <> "" then ac.airlineName = Operators_TableLookup(m.airlineTable, prefix)
    end for
end sub

' OAuth2 client-credentials token for a free OpenSky account.
function Task_FetchOpenSkyToken(clientId as String, clientSecret as String) as Object
    body = "grant_type=client_credentials&client_id=" + Http_UrlEncode(clientId) + "&client_secret=" + Http_UrlEncode(clientSecret)
    headers = { "Content-Type": "application/x-www-form-urlencoded", "User-Agent": "SkyTraffic-Roku/1.0" }
    response = Http_Request(m.http, "POST", "https://auth.opensky-network.org/auth/realms/opensky-network/protocol/openid-connect/token", headers, body, 15000)
    if response.status <> 200 then return { ok: false, token: "", expiresIn: 0, message: "HTTP " + response.status.ToStr() }
    json = ParseJson(response.body)
    if not Util_IsAA(json) or not Util_IsString(json.access_token) then return { ok: false, token: "", expiresIn: 0, message: "no token in response" }
    return { ok: true, token: json.access_token, expiresIn: Util_ToInt(json.expires_in, 1800), message: "" }
end function
