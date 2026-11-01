' One poll of the flight data provider plus a handful of route lookups.
' Runs on the Task thread; every network call lives here and nowhere else.

sub init()
    m.top.functionName = "runTask"
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
    headers = { "User-Agent": "FlightWall-Roku/1.0", "Accept": "application/json" }

    token = Util_Str(req.token)
    tokenExpiry = Util_ToInt(req.tokenExpiry, 0)
    clientId = Util_Str(req.clientId)
    clientSecret = Util_Str(req.clientSecret)
    if result.provider = "opensky" and clientId <> "" and clientSecret <> "" then
        nowSeconds = Task_NowSeconds()
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

    response = Task_Http("GET", Util_Str(req.url), headers, "", 15000)
    result.status = response.status
    classified = Flights_Classify(response.status)
    result.kind = classified.kind
    result.message = result.message + classified.message
    if response.status <= 0 and response.reason <> "" then result.message = result.message + " " + response.reason

    if classified.kind = "ok" then
        result.ok = true
        result.aircraft = Flights_Parse(result.provider, response.body, Util_ToFloat(req.lat), Util_ToFloat(req.lon), Util_ToFloat(req.radius, 50))
        result.credits = Task_HeaderInt(response.headers, "x-rate-limit-remaining")
        lookups = req.routeLookups
        if Util_IsArray(lookups) then
            for each callsign in lookups
                routeResponse = Task_Http("GET", Routes_Url(callsign), { "User-Agent": "FlightWall-Roku/1.0" }, "", 8000)
                if routeResponse.status = 200 then
                    result.routes[callsign] = Routes_Parse(routeResponse.body)
                else if routeResponse.status = 404 then
                    result.routes[callsign] = Routes_Empty()
                end if
            end for
        end if
    end if
    result.elapsedMs = timer.TotalMilliseconds()
    m.top.result = result
end sub

function Task_NowSeconds() as Integer
    dateTime = CreateObject("roDateTime")
    return dateTime.AsSeconds()
end function

function Task_HeaderInt(headers as Object, name as String) as Integer
    if not Util_IsAA(headers) then return -1
    for each key in headers
        if LCase(key) = name then return Util_ToInt(headers[key], -1)
    end for
    return -1
end function

' Synchronous HTTP with a timeout. Returns {status, body, headers, reason}.
function Task_Http(method as String, url as String, headers as Object, body as String, timeoutMs as Integer) as Object
    transfer = CreateObject("roUrlTransfer")
    port = CreateObject("roMessagePort")
    transfer.SetMessagePort(port)
    transfer.SetUrl(url)
    if Left(url, 8) = "https://" then
        transfer.SetCertificatesFile("common:/certs/ca-bundle.crt")
        transfer.InitClientCertificates()
    end if
    transfer.EnableEncodings(true)
    transfer.RetainBodyOnError(true)
    transfer.SetRequest(method)
    for each key in headers
        transfer.AddHeader(key, headers[key])
    end for
    started = false
    if method = "POST" then
        started = transfer.AsyncPostFromString(body)
    else
        started = transfer.AsyncGetToString()
    end if
    if not started then return { status: 0, body: "", headers: invalid, reason: "could not start request" }
    msg = wait(timeoutMs, port)
    if Type(msg) = "roUrlEvent" then
        return {
            status: msg.GetResponseCode()
            body: msg.GetString()
            headers: msg.GetResponseHeaders()
            reason: msg.GetFailureReason()
        }
    end if
    transfer.AsyncCancel()
    return { status: -28, body: "", headers: invalid, reason: "timed out after " + timeoutMs.ToStr() + " ms" }
end function

' OAuth2 client-credentials token for a free OpenSky account.
function Task_FetchOpenSkyToken(clientId as String, clientSecret as String) as Object
    encoder = CreateObject("roUrlTransfer")
    body = "grant_type=client_credentials&client_id=" + encoder.Escape(clientId) + "&client_secret=" + encoder.Escape(clientSecret)
    response = Task_Http("POST", "https://auth.opensky-network.org/auth/realms/opensky-network/protocol/openid-connect/token", { "Content-Type": "application/x-www-form-urlencoded", "User-Agent": "FlightWall-Roku/1.0" }, body, 15000)
    if response.status <> 200 then return { ok: false, token: "", expiresIn: 0, message: "HTTP " + response.status.ToStr() }
    json = ParseJson(response.body)
    if not Util_IsAA(json) or not Util_IsString(json.access_token) then return { ok: false, token: "", expiresIn: 0, message: "no token in response" }
    return { ok: true, token: json.access_token, expiresIn: Util_ToInt(json.expires_in, 1800), message: "" }
end function
