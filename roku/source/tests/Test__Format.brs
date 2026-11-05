' On-device tests for source/lib/format.brs.

' @Test
sub Test_Format_Thousands()
    UTF_assertEqual(Format_Thousands(35000), "35,000")
    UTF_assertEqual(Format_Thousands(999), "999")
    UTF_assertEqual(Format_Thousands(1234567), "1,234,567")
    UTF_assertEqual(Format_Thousands(-1500), "-1,500")
    UTF_assertEqual(Format_Thousands(0), "0")
end sub

' @Test
sub Test_Format_Measurements()
    UTF_assertEqual(Format_Altitude(0, true), "on ground")
    UTF_assertEqual(Format_Altitude(35000, false), "35,000 ft")
    UTF_assertEqual(Format_Speed(0), "")
    UTF_assertEqual(Format_Speed(450), "450 kt")
    UTF_assertEqual(Format_Distance(2.345), "2.3 mi")
    UTF_assertEqual(Format_Distance(12.6), "13 mi")
    UTF_assertEqual(Format_Trend(500), "climbing")
    UTF_assertEqual(Format_Trend(-500), "descending")
    UTF_assertEqual(Format_Trend(0), "level")
end sub

' @Test
sub Test_Format_Clock()
    dateTime = CreateObject("roDateTime")
    dateTime.FromISO8601String("2026-10-31T13:05:09")
    UTF_assertEqual(Format_Clock(dateTime, false), "1:05 PM")
    UTF_assertEqual(Format_Clock(dateTime, true), "1:05:09 PM")
    UTF_assertEqual(Format_DateLine(dateTime), "Saturday, October 31")
    dateTime.FromISO8601String("2026-10-31T00:30:00")
    UTF_assertEqual(Format_Clock(dateTime, false), "12:30 AM")
    dateTime.FromISO8601String("2026-10-31T12:00:00")
    UTF_assertEqual(Format_Clock(dateTime, false), "12:00 PM")
    UTF_assertTrue(Len(Format_Now(true)) >= 10)
    UTF_assertTrue(Len(Format_Today()) > 8)
end sub

' @Test
sub Test_Format_SummaryAndType()
    ac = Flights_Blank()
    ac.altFt = 35000
    ac.distMi = 12.3
    ac.bearing = 45
    UTF_assertEqual(Format_Summary(ac, invalid), "35,000 ft   12 mi NE")
    route = Routes_Empty()
    route.found = true
    route.originIata = "SFO"
    route.destIata = "SIN"
    UTF_assertEqual(Format_Summary(ac, route), "35,000 ft   12 mi NE   SFO > SIN")
    ac.typeCode = "B738"
    ac.registration = "N1"
    UTF_assertEqual(Format_AircraftType(ac), "B738 - N1")
    ac.typeCode = ""
    UTF_assertEqual(Format_AircraftType(ac), "N1")
    ac.registration = ""
    ac.hex = "abc"
    UTF_assertEqual(Format_AircraftType(ac), "ICAO ABC")
end sub

' The hint label is 520 px wide with no wrapping, so a long hint is silently cut off with
' an ellipsis on the TV. Measure both hints with the system font at the label size.
' @Test
sub Test_Format_HintsFitThePanel()
    registry = CreateObject("roFontRegistry")
    font = registry.GetDefaultFont(15, false, false)
    UTF_assertNotInvalid(font)
    for each screensaver in [true, false]
        text = Format_Hint(screensaver)
        width = font.GetOneLineWidth(text, 4000)
        print "hint width "; width; " px: "; text
        UTF_assertTrue(width <= 520, "hint wider than the panel (" + width.ToStr() + " px): " + text)
    end for
    UTF_assertTrue(Instr(1, Format_Hint(true), "*") = 0, "the screensaver hint must not mention remote keys")
    UTF_assertTrue(Instr(1, Format_Hint(false), "*") > 0)
end sub
