' Text formatting for the on-screen panel.

function Format_Thousands(value as Integer) as String
    negative = value < 0
    if negative then value = -value
    digits = value.ToStr()
    out = ""
    while Len(digits) > 3
        out = "," + Right(digits, 3) + out
        digits = Left(digits, Len(digits) - 3)
    end while
    out = digits + out
    if negative then out = "-" + out
    return out
end function

function Format_Altitude(altFt as Integer, ground as Boolean) as String
    if ground then return "on ground"
    return Format_Thousands(altFt) + " ft"
end function

function Format_Speed(speedKts as Integer) as String
    if speedKts <= 0 then return ""
    return speedKts.ToStr() + " kt"
end function

function Format_Distance(miles as Float) as String
    if miles < 10 then return Util_FloatStr(miles, 1) + " mi"
    return Util_Round(miles).ToStr() + " mi"
end function

function Format_Trend(vrate as Integer) as String
    if vrate > 300 then return "climbing"
    if vrate < -300 then return "descending"
    return "level"
end function

function Format_Pad2(value as Integer) as String
    return Util_PadLeft(value.ToStr(), 2, "0")
end function

' 12-hour clock from an roDateTime that is already in local time.
function Format_Clock(dateTime as Object, withSeconds as Boolean) as String
    hours = dateTime.GetHours()
    suffix = "AM"
    if hours >= 12 then suffix = "PM"
    hour12 = hours MOD 12
    if hour12 = 0 then hour12 = 12
    out = hour12.ToStr() + ":" + Format_Pad2(dateTime.GetMinutes())
    if withSeconds then out = out + ":" + Format_Pad2(dateTime.GetSeconds())
    return out + " " + suffix
end function

function Format_DateLine(dateTime as Object) as String
    months = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
    monthIndex = dateTime.GetMonth() - 1
    if monthIndex < 0 or monthIndex > 11 then monthIndex = 0
    return dateTime.GetWeekday() + ", " + months[monthIndex] + " " + dateTime.GetDayOfMonth().ToStr()
end function

function Format_Now(withSeconds as Boolean) as String
    dateTime = CreateObject("roDateTime")
    dateTime.ToLocalTime()
    return Format_Clock(dateTime, withSeconds)
end function

function Format_Today() as String
    dateTime = CreateObject("roDateTime")
    dateTime.ToLocalTime()
    return Format_DateLine(dateTime)
end function

' One-line summary used in the nearby list: "35,000 ft  12 mi NE  SFO > SIN"
function Format_Summary(ac as Object, route as Object) as String
    parts = Format_Altitude(ac.altFt, ac.ground) + "   " + Format_Distance(ac.distMi) + " " + Geo_Compass(ac.bearing)
    label = Routes_Label(route)
    if label <> "" then parts = parts + "   " + label
    return parts
end function

function Format_AircraftType(ac as Object) as String
    out = ac.typeCode
    if ac.registration <> "" then
        if out <> "" then out = out + " - "
        out = out + ac.registration
    end if
    if out = "" then out = "ICAO " + UCase(ac.hex)
    return out
end function

' The one-line hint under the panel. Screensavers take no remote input, so theirs points at
' the Roku menu whose SkyTraffic entry offers "Change screensaver settings". Both strings
' must fit the 520 px panel at 15 px; Test__Format measures them with the system font.
function Format_Hint(screensaver as Boolean) as String
    if screensaver then return "ZIP, radius and options: Settings > Theme > Screensavers > SkyTraffic"
    return "Press * for settings    Play: activity log    Up/Down: radius"
end function
