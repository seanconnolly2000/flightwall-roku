' HTTP helpers for Task threads. Never call these from the render thread.
'
' Http_Request keeps one roUrlTransfer per host in the cache you pass in, so the
' TLS connection is reused between polls instead of being renegotiated every time.

function Http_Host(url as String) as String
    rest = url
    marker = Instr(1, rest, "://")
    if marker > 0 then rest = Mid(rest, marker + 3)
    slash = Instr(1, rest, "/")
    if slash > 0 then rest = Left(rest, slash - 1)
    return LCase(rest)
end function

function Http_Transfer(cache as Object, url as String) as Object
    host = Http_Host(url)
    if Util_IsAA(cache) and cache.DoesExist(host) then return cache[host]
    transfer = CreateObject("roUrlTransfer")
    transfer.SetMessagePort(CreateObject("roMessagePort"))
    if Left(url, 8) = "https://" then
        transfer.SetCertificatesFile("common:/certs/ca-bundle.crt")
        transfer.InitClientCertificates()
    end if
    transfer.EnableEncodings(true)
    transfer.RetainBodyOnError(true)
    if Util_IsAA(cache) then cache[host] = transfer
    return transfer
end function

' Synchronous request with a timeout. Returns {status, body, headers, reason}.
function Http_Request(cache as Object, method as String, url as String, headers as Object, body as String, timeoutMs as Integer) as Object
    transfer = Http_Transfer(cache, url)
    port = transfer.GetMessagePort()
    transfer.SetUrl(url)
    transfer.SetRequest(method)
    transfer.SetHeaders(headers)
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
    if Util_IsAA(cache) then cache.Delete(Http_Host(url))
    return { status: -28, body: "", headers: invalid, reason: "timed out after " + timeoutMs.ToStr() + " ms" }
end function

function Http_HeaderInt(headers as Object, name as String) as Integer
    if not Util_IsAA(headers) then return -1
    for each key in headers
        if LCase(key) = name then return Util_ToInt(headers[key], -1)
    end for
    return -1
end function

function Http_NowSeconds() as Integer
    dateTime = CreateObject("roDateTime")
    return dateTime.AsSeconds()
end function

function Http_UrlEncode(text as String) as String
    encoder = CreateObject("roUrlTransfer")
    return encoder.Escape(text)
end function
