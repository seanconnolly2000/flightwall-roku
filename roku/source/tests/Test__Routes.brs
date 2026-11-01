' On-device tests for source/lib/routes.brs.

function Routes_SampleBody() as String
    text = "{'response':{'flightroute':{'callsign':'UAL1','callsign_icao':'UAL1','callsign_iata':'UA1','airline':{'name':'United Airlines','icao':'UAL','iata':'UA','country':'United States','callsign':'UNITED'},'origin':{'country_iso_name':'US','iata_code':'SFO','icao_code':'KSFO','latitude':37.619,'longitude':-122.375,'municipality':'San Francisco','name':'San Francisco International Airport'},'destination':{'iata_code':'SIN','icao_code':'WSSS','latitude':1.35019,'longitude':103.994,'municipality':'Singapore','name':'Singapore Changi Airport'}}}}"
    return text.Replace("'", Chr(34))
end function

' @Test
sub Test_Routes_Callsigns()
    UTF_assertEqual(Routes_NormalizeCallsign("  ual1 "), "UAL1")
    UTF_assertTrue(Routes_IsLookupWorthy("UAL123"))
    UTF_assertTrue(Routes_IsLookupWorthy("SKW5592"))
    UTF_assertFalse(Routes_IsLookupWorthy("N616UX"))
    UTF_assertFalse(Routes_IsLookupWorthy("ABC"))
    UTF_assertFalse(Routes_IsLookupWorthy("ABCDEFGHI"))
    UTF_assertFalse(Routes_IsLookupWorthy("ABCD"))
    UTF_assertEqual(Routes_Url("UAL1"), "https://api.adsbdb.com/v0/callsign/UAL1")
end sub

' @Test
sub Test_Routes_ParseFound()
    route = Routes_Parse(Routes_SampleBody())
    UTF_assertTrue(route.found)
    UTF_assertEqual(route.airlineName, "United Airlines")
    UTF_assertEqual(route.airlineIata, "UA")
    UTF_assertEqual(route.airlineIcao, "UAL")
    UTF_assertEqual(route.originIata, "SFO")
    UTF_assertEqual(route.originCity, "San Francisco")
    UTF_assertTrue(Abs(route.originLat - 37.619) < 0.001)
    UTF_assertTrue(Abs(route.originLon + 122.375) < 0.001)
    UTF_assertEqual(route.destIata, "SIN")
    UTF_assertEqual(route.destCity, "Singapore")
    UTF_assertTrue(Routes_HasOrigin(route))
    UTF_assertEqual(Routes_Label(route), "SFO > SIN")
    UTF_assertEqual(Routes_CityLabel(route), "San Francisco to Singapore")
end sub

' @Test
sub Test_Routes_ParseUnknownAndGarbage()
    unknown = Routes_Parse("{" + Chr(34) + "response" + Chr(34) + ":" + Chr(34) + "unknown callsign" + Chr(34) + "}")
    UTF_assertFalse(unknown.found)
    UTF_assertEqual(unknown.originIata, "")
    UTF_assertFalse(Routes_Parse("not json").found)
    UTF_assertFalse(Routes_Parse("{}").found)
    UTF_assertFalse(Routes_HasOrigin(invalid))
    UTF_assertFalse(Routes_HasOrigin(Routes_Empty()))
    UTF_assertEqual(Routes_Label(invalid), "")
    UTF_assertEqual(Routes_CityLabel(Routes_Empty()), "")
end sub

' @Test
sub Test_Routes_PartialRoute()
    partial = Routes_Empty()
    partial.found = true
    partial.destIata = "LAX"
    UTF_assertEqual(Routes_Label(partial), "? > LAX")
    UTF_assertEqual(Routes_CityLabel(partial), "unknown to LAX")
end sub

' @Test
sub Test_Routes_LogoUrl()
    UTF_assertEqual(Routes_LogoUrl("UA"), "https://images.kiwi.com/airlines/64/UA.png")
    UTF_assertEqual(Routes_LogoUrl(""), "")
    UTF_assertEqual(Routes_LogoUrl("UAL"), "")
end sub

' @Test
sub Test_Routes_Pick()
    aircraft = [{ callsign: "UAL1" }, { callsign: "N123" }, { callsign: "DAL2" }, { callsign: "UAL1" }, { callsign: "AAL3" }]
    cache = { DAL2: Routes_Empty() }
    picks = Routes_Pick(aircraft, cache, 5)
    UTF_assertEqual(picks.Count(), 2)
    UTF_assertEqual(picks[0], "UAL1")
    UTF_assertEqual(picks[1], "AAL3")
    UTF_assertEqual(Routes_Pick(aircraft, cache, 1).Count(), 1)
    UTF_assertEqual(Routes_Pick(aircraft, cache, 0).Count(), 0)
    UTF_assertEqual(Routes_Pick([], cache, 3).Count(), 0)
end sub
