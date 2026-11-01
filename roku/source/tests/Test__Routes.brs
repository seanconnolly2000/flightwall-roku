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

function Routes_TestRoute(oIata as String, oLat as Float, oLon as Float, dIata as String, dLat as Float, dLon as Float) as Object
    route = Routes_Empty()
    route.found = true
    route.airlineIata = "UA"
    route.originIata = oIata
    route.originLat = oLat
    route.originLon = oLon
    route.destIata = dIata
    route.destLat = dLat
    route.destLon = dLon
    return route
end function

function Routes_TestAircraft(lat as Float, lon as Float, track as Float, vrate as Integer) as Object
    ac = Flights_Blank()
    ac.callsign = "UAL1"
    ac.lat = lat
    ac.lon = lon
    ac.track = track
    ac.vrate = vrate
    return ac
end function

' @Test
sub Test_Routes_ReconcileRejectsFarAwayLeg()
    bosJfk = Routes_TestRoute("BOS", 42.3656, -71.0096, "JFK", 40.6413, -73.7781)
    overSanFrancisco = Routes_TestAircraft(37.8, -122.4, 270, 0)
    out = Routes_Reconcile(bosJfk, overSanFrancisco)
    UTF_assertFalse(out.found)
    UTF_assertTrue(out.rejected)
    UTF_assertEqual(out.airlineIata, "UA")
    UTF_assertTrue(bosJfk.found, "the cached route must not be mutated")
    UTF_assertEqual(Routes_Label(out), "")
end sub

' @Test
sub Test_Routes_ReconcileSwapsReversedLeg()
    koaOak = Routes_TestRoute("KOA", 19.7388, -156.0456, "OAK", 37.7213, -122.2208)
    climbingOutOfOakland = Routes_TestAircraft(37.6, -122.5, 240, 2000)
    out = Routes_Reconcile(koaOak, climbingOutOfOakland)
    UTF_assertEqual(out.originIata, "OAK")
    UTF_assertEqual(out.destIata, "KOA")
    UTF_assertTrue(Abs(out.destLat - 19.7388) < 0.001)
    UTF_assertEqual(Routes_Label(out), "OAK > KOA")
    cruisingWest = Routes_TestAircraft(36.0, -126.0, 245, 0)
    out2 = Routes_Reconcile(koaOak, cruisingWest)
    UTF_assertEqual(out2.originIata, "OAK")
    descendingIntoOrigin = Routes_TestAircraft(37.9, -122.0, 200, -1500)
    out3 = Routes_Reconcile(Routes_TestRoute("OAK", 37.7213, -122.2208, "KOA", 19.7388, -156.0456), descendingIntoOrigin)
    UTF_assertEqual(out3.originIata, "KOA")
    UTF_assertEqual(out3.destIata, "OAK")
end sub

' @Test
sub Test_Routes_ReconcileKeepsPlausibleRoutes()
    sfoLax = Routes_TestRoute("SFO", 37.619, -122.375, "LAX", 33.9425, -118.4081)
    enRoute = Routes_TestAircraft(36.0, -120.5, 140, 0)
    UTF_assertEqual(Routes_Reconcile(sfoLax, enRoute).originIata, "SFO")
    onApproach = Routes_TestAircraft(34.2, -118.6, 60, -800)
    UTF_assertEqual(Routes_Reconcile(sfoLax, onApproach).destIata, "LAX")
    noTrack = Routes_TestAircraft(36.0, -120.5, -1, 0)
    UTF_assertTrue(Routes_Reconcile(sfoLax, noTrack).found)
    towardOrigin = Routes_TestAircraft(36.0, -120.5, 320, 0)
    UTF_assertEqual(Routes_Reconcile(sfoLax, towardOrigin).originIata, "LAX")
    headingNowhere = Routes_TestAircraft(38.5, -120.0, 20, 0)
    UTF_assertFalse(Routes_Reconcile(sfoLax, headingNowhere).found)
    noCoords = Routes_Empty()
    noCoords.found = true
    noCoords.originIata = "SFO"
    UTF_assertTrue(Routes_Reconcile(noCoords, enRoute).found)
    UTF_assertFalse(Routes_HasBothEnds(invalid))
    UTF_assertFalse(Routes_HasBothEnds(Routes_Empty()))
    UTF_assertTrue(Routes_HasBothEnds(sfoLax))
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
