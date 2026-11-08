' Fetches the five-day forecast for the viewer's coordinates (Task thread).

sub init()
    m.top.functionName = "runTask"
    m.http = {}
end sub

sub runTask()
    req = m.top.request
    result = { ok: false, days: [], message: "", status: 0 }
    if not Util_IsAA(req) then
        result.message = "no request"
        m.top.result = result
        return
    end if
    url = Weather_Url(Util_ToFloat(req.lat), Util_ToFloat(req.lon))
    headers = { "User-Agent": "SkyTraffic-Roku/1.0", "Accept": "application/json" }
    response = Http_Request(m.http, "GET", url, headers, "", 15000)
    result.status = response.status
    if response.status <> 200 then
        result.message = "HTTP " + response.status.ToStr()
        if response.status <= 0 then result.message = result.message + " " + Util_Str(response.reason)
        m.top.result = result
        return
    end if
    parsed = Weather_Parse(response.body, Weather_TodayIso())
    result.ok = parsed.ok
    result.days = parsed.days
    result.message = parsed.message
    m.top.result = result
end sub
