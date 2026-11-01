' On-device tests for source/lib/weather.brs and source/lib/http.brs helpers.

function Weather_SampleBody() as String
    text = "{'latitude':37.76,'longitude':-122.41,'timezone':'America/Los_Angeles','daily_units':{'time':'iso8601'},'daily':{'time':['2026-11-01','2026-11-02','2026-11-03','2026-11-04','2026-11-05'],'weather_code':[61,3,51,3,0],'temperature_2m_max':[63.4,64.2,64.3,63.7,70.1],'temperature_2m_min':[49.7,49.9,51.8,53.5,56.2],'precipitation_probability_max':[50,3,78,12,null]}}"
    return text.Replace("'", Chr(34))
end function

' @Test
sub Test_Weather_Url()
    url = Weather_Url(37.7749, -122.4194)
    UTF_assertTrue(url.Instr("https://api.open-meteo.com/v1/forecast?latitude=37.775&longitude=-122.419") = 0, url)
    UTF_assertTrue(url.Instr("forecast_days=5") > 0)
    UTF_assertTrue(url.Instr("temperature_unit=fahrenheit") > 0)
end sub

' @Test
sub Test_Weather_CodeInfo()
    UTF_assertEqual(Weather_CodeInfo(0).icon, "clear")
    UTF_assertEqual(Weather_CodeInfo(2).icon, "partly")
    UTF_assertEqual(Weather_CodeInfo(3).label, "Overcast")
    UTF_assertEqual(Weather_CodeInfo(45).icon, "fog")
    UTF_assertEqual(Weather_CodeInfo(55).label, "Drizzle")
    UTF_assertEqual(Weather_CodeInfo(63).label, "Rain")
    UTF_assertEqual(Weather_CodeInfo(73).icon, "snow")
    UTF_assertEqual(Weather_CodeInfo(81).label, "Showers")
    UTF_assertEqual(Weather_CodeInfo(86).label, "Snow showers")
    UTF_assertEqual(Weather_CodeInfo(95).icon, "storm")
    UTF_assertEqual(Weather_CodeInfo(99).icon, "storm")
    UTF_assertEqual(Weather_CodeInfo(40).label, "Cloudy")
end sub

' @Test
sub Test_Weather_Days()
    UTF_assertEqual(Weather_ShortDay("2026-11-01", "2026-11-01"), "Today")
    UTF_assertEqual(Weather_ShortDay("2026-11-02", "2026-11-01"), "Mon")
    UTF_assertEqual(Weather_ShortDay("2026-11-07", "2026-11-01"), "Sat")
    UTF_assertEqual(Weather_ShortDay("bad", "2026-11-01"), "bad")
    today = Weather_TodayIso()
    UTF_assertEqual(Len(today), 10)
    UTF_assertEqual(Mid(today, 5, 1), "-")
    UTF_assertEqual(Mid(today, 8, 1), "-")
end sub

' @Test
sub Test_Weather_ParseSample()
    parsed = Weather_Parse(Weather_SampleBody(), "2026-11-01")
    UTF_assertTrue(parsed.ok, parsed.message)
    UTF_assertEqual(parsed.days.Count(), 5)
    first = parsed.days[0]
    UTF_assertEqual(first.day, "Today")
    UTF_assertEqual(first.icon, "rain")
    UTF_assertEqual(first.hi, 63)
    UTF_assertEqual(first.lo, 50)
    UTF_assertEqual(first.precip, 50)
    UTF_assertEqual(parsed.days[1].day, "Mon")
    UTF_assertEqual(parsed.days[4].icon, "clear")
    UTF_assertEqual(parsed.days[4].precip, -1)
    UTF_assertEqual(Weather_TempRange(first), "63" + Chr(176) + "/50" + Chr(176))
    UTF_assertEqual(Weather_DayLabel(first), "Today 50%")
    UTF_assertEqual(Weather_DayLabel(parsed.days[1]), "Mon")
    UTF_assertEqual(Weather_DayLabel(parsed.days[4]), "Thu")
end sub

' @Test
sub Test_Weather_ParseErrors()
    UTF_assertFalse(Weather_Parse("nope", "2026-11-01").ok)
    quoted = "{'reason':'Latitude must be in range','error':true}".Replace("'", Chr(34))
    failed = Weather_Parse(quoted, "2026-11-01")
    UTF_assertFalse(failed.ok)
    UTF_assertEqual(failed.message, "Latitude must be in range")
    UTF_assertEqual(Weather_Parse("{" + Chr(34) + "daily" + Chr(34) + ":{}}", "x").message, "weather response had no daily data")
    empty = "{'daily':{'time':[]}}".Replace("'", Chr(34))
    UTF_assertEqual(Weather_Parse(empty, "x").message, "weather response listed no days")
    UTF_assertInvalid(Weather_At(invalid, 0))
    UTF_assertInvalid(Weather_At([1], 5))
    UTF_assertEqual(Weather_At([7], 0), 7)
end sub

' @Test
sub Test_Http_Host()
    UTF_assertEqual(Http_Host("https://api.adsb.lol/v2/lat/1/lon/2/dist/3"), "api.adsb.lol")
    UTF_assertEqual(Http_Host("http://Example.com"), "example.com")
    UTF_assertEqual(Http_Host("nohost"), "nohost")
    UTF_assertEqual(Http_HeaderInt({ "X-Rate-Limit-Remaining": "398" }, "x-rate-limit-remaining"), 398)
    UTF_assertEqual(Http_HeaderInt({ other: "1" }, "x-rate-limit-remaining"), -1)
    UTF_assertEqual(Http_HeaderInt(invalid, "x"), -1)
    UTF_assertEqual(Http_UrlEncode("a b&c"), "a%20b%26c")
end sub
