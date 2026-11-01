' Five-day forecast from Open-Meteo (free, keyless; attribution "Open-Meteo.com").

function Weather_Url(lat as Float, lon as Float) as String
    return "https://api.open-meteo.com/v1/forecast?latitude=" + Util_FloatStr(lat, 3) + "&longitude=" + Util_FloatStr(lon, 3) + "&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max&temperature_unit=fahrenheit&timezone=auto&forecast_days=5"
end function

' WMO weather interpretation code -> {icon, label}.
function Weather_CodeInfo(code as Integer) as Object
    if code = 0 then return { icon: "clear", label: "Clear" }
    if code = 1 then return { icon: "partly", label: "Mostly clear" }
    if code = 2 then return { icon: "partly", label: "Partly cloudy" }
    if code = 3 then return { icon: "cloudy", label: "Overcast" }
    if code = 45 or code = 48 then return { icon: "fog", label: "Fog" }
    if code >= 51 and code <= 57 then return { icon: "rain", label: "Drizzle" }
    if code >= 61 and code <= 67 then return { icon: "rain", label: "Rain" }
    if code >= 71 and code <= 77 then return { icon: "snow", label: "Snow" }
    if code >= 80 and code <= 82 then return { icon: "rain", label: "Showers" }
    if code = 85 or code = 86 then return { icon: "snow", label: "Snow showers" }
    if code >= 95 then return { icon: "storm", label: "Thunderstorms" }
    return { icon: "cloudy", label: "Cloudy" }
end function

' "Today" for the current date, otherwise a three-letter weekday ("Mon").
function Weather_ShortDay(isoDate as String, todayIso as String) as String
    if isoDate = todayIso then return "Today"
    if Len(isoDate) < 10 then return isoDate
    dateTime = CreateObject("roDateTime")
    dateTime.FromISO8601String(Left(isoDate, 10) + "T12:00:00")
    return Left(dateTime.GetWeekday(), 3)
end function

function Weather_TodayIso() as String
    dateTime = CreateObject("roDateTime")
    dateTime.ToLocalTime()
    return dateTime.GetYear().ToStr() + "-" + Util_PadLeft(dateTime.GetMonth().ToStr(), 2, "0") + "-" + Util_PadLeft(dateTime.GetDayOfMonth().ToStr(), 2, "0")
end function

function Weather_At(values as Object, index as Integer) as Dynamic
    if not Util_IsArray(values) then return invalid
    if index < 0 or index >= values.Count() then return invalid
    return values[index]
end function

' Parses the Open-Meteo daily response into {ok, days[], message}.
function Weather_Parse(body as String, todayIso as String) as Object
    result = { ok: false, days: [], message: "" }
    json = ParseJson(body)
    if not Util_IsAA(json) then
        result.message = "weather response was not JSON"
        return result
    end if
    if Util_IsString(json.reason) then
        result.message = json.reason
        return result
    end if
    daily = json.daily
    if not Util_IsAA(daily) or not Util_IsArray(daily.time) then
        result.message = "weather response had no daily data"
        return result
    end if
    times = daily.time
    for i = 0 to times.Count() - 1
        code = Util_ToInt(Weather_At(daily.weather_code, i), 3)
        info = Weather_CodeInfo(code)
        result.days.Push({
            date: Util_Str(times[i])
            day: Weather_ShortDay(Util_Str(times[i]), todayIso)
            code: code
            icon: info.icon
            label: info.label
            hi: Util_Round(Util_ToFloat(Weather_At(daily.temperature_2m_max, i), 0))
            lo: Util_Round(Util_ToFloat(Weather_At(daily.temperature_2m_min, i), 0))
            precip: Util_ToInt(Weather_At(daily.precipitation_probability_max, i), -1)
        })
    end for
    result.ok = result.days.Count() > 0
    if not result.ok then result.message = "weather response listed no days"
    return result
end function

' "63°/50°"
function Weather_TempRange(day as Object) as String
    return Util_ToInt(day.hi).ToStr() + Chr(176) + "/" + Util_ToInt(day.lo).ToStr() + Chr(176)
end function

' "Mon" or "Mon 50%" when rain is likely.
function Weather_DayLabel(day as Object) as String
    label = Util_Str(day.day)
    precip = Util_ToInt(day.precip, -1)
    if precip >= 30 then label = label + " " + precip.ToStr() + "%"
    return label
end function
