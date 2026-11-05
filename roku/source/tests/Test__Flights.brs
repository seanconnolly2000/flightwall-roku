' On-device tests for source/lib/flights.brs using recorded provider responses.

' JSON literals are written with single quotes and converted, because BrightScript
' strings cannot escape double quotes.
function Flights_TestJson(text as String) as String
    return text.Replace("'", Chr(34))
end function

function Flights_SampleAdsb(listKey as String) as String
    return Flights_TestJson("{'now':1793493672,'" + listKey + "':[" + "{'hex':'A806E0','type':'adsb_icao','flight':'SKW5592 ','r':'N616UX','t':'E75L','alt_baro':19075,'alt_geom':19050,'gs':332.5,'track':169.60,'baro_rate':2560,'squawk':'6364','lat':37.449005,'lon':-122.661360}," + "{'hex':'b','flight':'GND1','alt_baro':'ground','lat':37.62,'lon':-122.39,'gs':0,'true_heading':43.7}," + "{'hex':'nolatlon','flight':'XX'}," + "{'hex':'far','flight':'FAR1','lat':45.0,'lon':-100.0,'alt_baro':30000}" + "]}")
end function

' @Test
sub Test_Flights_ProviderUrls()
    url = Flights_ProviderUrl("adsblol", 37.7749, -122.4194, 50)
    UTF_assertEqual(url, "https://api.adsb.lol/v2/lat/37.7749/lon/-122.4194/dist/43")
    UTF_assertEqual(Left(Flights_ProviderUrl("adsbfi", 37.7749, -122.4194, 50), 36), "https://opendata.adsb.fi/api/v2/lat/")
    UTF_assertEqual(Right(Flights_ProviderUrl("adsblol", 37.7749, -122.4194, 300), 8), "dist/250")
    openSky = Flights_ProviderUrl("opensky", 37.7749, -122.4194, 50)
    UTF_assertTrue(openSky.Instr("https://opensky-network.org/api/states/all?lamin=") = 0, openSky)
    UTF_assertTrue(openSky.Instr("&lomax=") > 0)
    UTF_assertTrue(openSky.Instr("&extended=1") > 0)
end sub

' @Test
sub Test_Flights_ParseAdsbLol()
    aircraft = Flights_Parse("adsblol", Flights_SampleAdsb("ac"), 37.7749, -122.4194, 50)
    UTF_assertEqual(aircraft.Count(), 2)
    ground = aircraft[0]
    UTF_assertEqual(ground.callsign, "GND1")
    UTF_assertTrue(ground.ground)
    UTF_assertEqual(ground.altFt, 0)
    UTF_assertTrue(Abs(ground.track - 43.7) < 0.01)
    flying = aircraft[1]
    UTF_assertEqual(flying.hex, "a806e0")
    UTF_assertEqual(flying.callsign, "SKW5592")
    UTF_assertEqual(flying.registration, "N616UX")
    UTF_assertEqual(flying.typeCode, "E75L")
    UTF_assertEqual(flying.altFt, 19075)
    UTF_assertEqual(flying.speedKts, 333)
    UTF_assertEqual(flying.vrate, 2560)
    UTF_assertEqual(flying.squawk, "6364")
    UTF_assertFalse(flying.ground)
    UTF_assertTrue(flying.distMi > 20 and flying.distMi < 30, "distance " + Str(flying.distMi))
    UTF_assertTrue(flying.bearing > 180 and flying.bearing < 270, "bearing " + Str(flying.bearing))
end sub

' @Test
sub Test_Flights_ParseAdsbFiAndBadInput()
    aircraft = Flights_Parse("adsbfi", Flights_SampleAdsb("aircraft"), 37.7749, -122.4194, 50)
    UTF_assertEqual(aircraft.Count(), 2)
    UTF_assertEqual(Flights_Parse("adsblol", "not json", 0, 0, 50).Count(), 0)
    UTF_assertEqual(Flights_Parse("adsblol", "{}", 0, 0, 50).Count(), 0)
    UTF_assertEqual(Flights_Parse("adsblol", Flights_TestJson("{'ac':'nope'}"), 0, 0, 50).Count(), 0)
    UTF_assertInvalid(Flights_FromAdsb("text"))
end sub

' @Test
sub Test_Flights_ParseOpenSky()
    body = Flights_TestJson("{'time':1,'states':[['a1bfac','UAL930  ','United States',1,1,-122.39,37.617,3048.0,false,250.0,90.0,5.0,null,3100.0,'3365',false,0,3],['short'],['x','y','z',1,1,null,null],['heli1','MEDIC1 ','US',1,1,-122.0,37.3,300.0,false,60.0,180.0,0.0,null,320.0,'1200',false,0,8]]}")
    aircraft = Flights_Parse("opensky", body, 37.7749, -122.4194, 50)
    UTF_assertEqual(aircraft.Count(), 2)
    ac = aircraft[0]
    UTF_assertEqual(ac.hex, "a1bfac")
    UTF_assertEqual(ac.callsign, "UAL930")
    UTF_assertTrue(ac.altFt > 9990 and ac.altFt < 10010, "altitude " + Str(ac.altFt))
    UTF_assertEqual(ac.speedKts, 486)
    UTF_assertTrue(Abs(ac.track - 90) < 0.01)
    UTF_assertEqual(ac.vrate, 984)
    UTF_assertEqual(ac.squawk, "3365")
    UTF_assertFalse(ac.ground)
    UTF_assertFalse(ac.helicopter)
    heli = aircraft[1]
    UTF_assertEqual(heli.callsign, "MEDIC1")
    UTF_assertEqual(heli.category, "A7")
    UTF_assertTrue(heli.helicopter)
end sub

' @Test
sub Test_Flights_Helicopters()
    blank = Flights_Blank()
    UTF_assertFalse(Flights_IsHelicopter(blank))
    byCategory = Flights_Blank()
    byCategory.category = "A7"
    UTF_assertTrue(Flights_IsHelicopter(byCategory))
    byType = Flights_Blank()
    byType.typeCode = "ec35"
    UTF_assertTrue(Flights_IsHelicopter(byType))
    byDesc = Flights_Blank()
    byDesc.desc = "Eurocopter MH-65D Dolphin"
    UTF_assertTrue(Flights_IsHelicopter(byDesc))
    byModel = Flights_Blank()
    byModel.modelName = "Airbus Helicopters EC-135 - N123AB"
    UTF_assertTrue(Flights_IsHelicopter(byModel))
    glider = Flights_Blank()
    glider.typeCode = "SGS"
    glider.desc = "SCHWEIZER SGS 2-33A"
    UTF_assertFalse(Flights_IsHelicopter(glider))
    plane = Flights_Blank()
    plane.typeCode = "C172"
    plane.desc = "CESSNA 172 Skyhawk"
    plane.category = "A1"
    UTF_assertFalse(Flights_IsHelicopter(plane))
    raw = ParseJson(Flights_TestJson("{'hex':'c6525','flight':'C6525','t':'AS65','category':'A7','desc':'Eurocopter MH-65D Dolphin','alt_baro':800,'lat':37.8,'lon':-122.4,'track':270}"))
    parsed = Flights_FromAdsb(raw)
    UTF_assertTrue(parsed.helicopter)
    UTF_assertEqual(Flights_SpriteName(94, true), "heli_090")
    UTF_assertEqual(Flights_SpriteName(94, false), "plane_090")
    UTF_assertEqual(Flights_SpriteName(355, true), "heli_000")
    UTF_assertEqual(Flights_IconColor(parsed), "0xFF8A2BFF")
    parsed.ground = true
    UTF_assertEqual(Flights_IconColor(parsed), "0x8B949EFF")
    plane.altFt = 35000
    UTF_assertEqual(Flights_IconColor(plane), "0x7CC4FFFF")
    plane.altFt = 5000
    UTF_assertEqual(Flights_IconColor(plane), "0xFFC857FF")
end sub

' @Test
sub Test_Flights_Classify()
    UTF_assertEqual(Flights_Classify(200).kind, "ok")
    UTF_assertEqual(Flights_Classify(429).kind, "ratelimited")
    UTF_assertEqual(Flights_Classify(401).kind, "auth")
    UTF_assertEqual(Flights_Classify(403).kind, "auth")
    UTF_assertEqual(Flights_Classify(0).kind, "network")
    UTF_assertEqual(Flights_Classify(-28).kind, "network")
    UTF_assertEqual(Flights_Classify(503).kind, "server")
    UTF_assertEqual(Flights_Classify(404).kind, "http")
    UTF_assertEqual(Flights_Classify(404).message, "HTTP 404")
end sub

' @Test
sub Test_Flights_BackoffAndPrompt()
    UTF_assertEqual(Flights_Backoff(10, 0), 10)
    UTF_assertEqual(Flights_Backoff(10, 1), 20)
    UTF_assertEqual(Flights_Backoff(10, 3), 80)
    UTF_assertEqual(Flights_Backoff(10, 10), 300)
    UTF_assertTrue(Flights_NeedsKeyPrompt("auth", 1, "adsblol", false))
    UTF_assertFalse(Flights_NeedsKeyPrompt("ratelimited", 1, "adsblol", false))
    UTF_assertTrue(Flights_NeedsKeyPrompt("ratelimited", 2, "adsblol", false))
    UTF_assertFalse(Flights_NeedsKeyPrompt("ratelimited", 5, "opensky", true))
    UTF_assertFalse(Flights_NeedsKeyPrompt("network", 9, "adsblol", false))
end sub

' @Test
sub Test_Flights_Presentation()
    UTF_assertEqual(Flights_AltitudeColor(0, true), "0x8B949EFF")
    UTF_assertEqual(Flights_AltitudeColor(5000, false), "0xFFC857FF")
    UTF_assertEqual(Flights_AltitudeColor(20000, false), "0xFFFFFFFF")
    UTF_assertEqual(Flights_AltitudeColor(35000, false), "0x7CC4FFFF")
    UTF_assertEqual(Flights_SpriteName(94), "plane_090")
    UTF_assertEqual(Flights_SpriteName(355), "plane_000")
    UTF_assertEqual(Flights_SpriteName(-1), "plane_000")
    UTF_assertEqual(Flights_SpriteName(5), "plane_010")
    UTF_assertEqual(Flights_SpriteName(0), "plane_000")
    blank = Flights_Blank()
    blank.hex = "abc"
    UTF_assertEqual(Flights_DisplayName(blank), "ABC")
    blank.registration = "N1"
    UTF_assertEqual(Flights_DisplayName(blank), "N1")
    blank.callsign = "UAL1"
    UTF_assertEqual(Flights_DisplayName(blank), "UAL1")
    blank.distMi = 1.5
    UTF_assertTrue(Flights_IsOverhead(blank))
    blank.ground = true
    UTF_assertFalse(Flights_IsOverhead(blank))
end sub

' @Test
sub Test_Flights_Airborne()
    flying = Flights_Blank()
    flying.hex = "fly"
    parked = Flights_Blank()
    parked.hex = "park"
    parked.ground = true
    kept = Flights_Airborne([parked, flying, parked])
    UTF_assertEqual(kept.Count(), 1)
    UTF_assertEqual(kept[0].hex, "fly")
    UTF_assertEqual(Flights_Airborne([]).Count(), 0)
    nearest = Flights_Nearest([flying, parked, flying], 2)
    UTF_assertEqual(nearest.Count(), 2)
    UTF_assertEqual(nearest[1].hex, "park")
    UTF_assertEqual(Flights_Nearest([flying], 5).Count(), 1)
    UTF_assertEqual(Flights_Nearest([], 5).Count(), 0)
end sub
