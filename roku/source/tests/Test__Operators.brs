' On-device tests for source/lib/operators.brs.

function Operators_SampleTable() as String
    return Chr(10) + "CKK,China Cargo Airlines" + Chr(10) + "CSG,China Southern Cargo" + Chr(10) + "QXE,Horizon Air" + Chr(10)
end function

function Operators_SampleAircraftBody() as String
    text = "{'response':{'aircraft':{'type':'C-17A Globemaster III','icao_type':'C17','manufacturer':'Boeing','mode_s':'AE1234','registration':'03-3123','registered_owner_country_iso_name':'US','registered_owner_country_name':'United States','registered_owner_operator_flag_code':'C17','registered_owner':'United States Air Force','url_photo':'https://x/y.jpg'}}}"
    return text.Replace("'", Chr(34))
end function

function Operators_TestAircraft(callsign as String, hex as String, ownOp as String) as Object
    ac = Flights_Blank()
    ac.callsign = callsign
    ac.hex = hex
    ac.ownOp = ownOp
    return ac
end function

' @Test
sub Test_Operators_PrefixAndTable()
    UTF_assertEqual(Operators_Prefix("CSG2537"), "CSG")
    UTF_assertEqual(Operators_Prefix("N242DT"), "")
    UTF_assertEqual(Operators_Prefix(""), "")
    table = Operators_SampleTable()
    UTF_assertEqual(Operators_TableLookup(table, "CSG"), "China Southern Cargo")
    UTF_assertEqual(Operators_TableLookup(table, "ckk"), "China Cargo Airlines")
    UTF_assertEqual(Operators_TableLookup(table, "ZZZ"), "")
    UTF_assertEqual(Operators_TableLookup(table, "CS"), "")
    UTF_assertEqual(Operators_TableLookup("", "CSG"), "")
    UTF_assertEqual(Operators_TableLookup(Chr(10) + "QXE,Horizon Air", "QXE"), "Horizon Air")
end sub

' @Test
sub Test_Operators_OrganizationAndCase()
    UTF_assertTrue(Operators_IsOrganization("KANGAREW AIR LLC"))
    UTF_assertTrue(Operators_IsOrganization("BANK OF UTAH TRUSTEE"))
    UTF_assertTrue(Operators_IsOrganization("US DEPT OF HOMELAND SECURITY"))
    UTF_assertTrue(Operators_IsOrganization("United States Air Force"))
    UTF_assertFalse(Operators_IsOrganization("SHERLOCK WILLIAM H"))
    UTF_assertFalse(Operators_IsOrganization("MOWERY STEVEN, MOWERY SARAH"))
    UTF_assertFalse(Operators_IsOrganization("FIRESTONE JOHN"))
    UTF_assertFalse(Operators_IsOrganization(""))
    UTF_assertEqual(Operators_TitleCase("HORIZON AIR INDUSTRIES INC"), "Horizon Air Industries Inc")
    UTF_assertEqual(Operators_TitleCase("N3766H LLC"), "N3766h LLC")
    UTF_assertEqual(Operators_TitleCase("  us dept of homeland security "), "US Dept Of Homeland Security")
    UTF_assertEqual(Operators_TitleCase("A B"), "A B")
end sub

' @Test
sub Test_Operators_MilitaryHex()
    UTF_assertTrue(Operators_IsMilitaryHex("ae1234"))
    UTF_assertTrue(Operators_IsMilitaryHex("AFFFFF"))
    UTF_assertFalse(Operators_IsMilitaryHex("a91556"))
    UTF_assertFalse(Operators_IsMilitaryHex("~ae1234"))
    UTF_assertFalse(Operators_IsMilitaryHex(""))
end sub

' @Test
sub Test_Operators_ResolvePriority()
    route = Routes_Empty()
    route.found = true
    route.airlineName = "United Airlines"
    ac = Operators_TestAircraft("UAL1", "a00001", "BANK OF UTAH TRUSTEE")
    UTF_assertEqual(Operators_Resolve(ac, route, "", invalid, false).name, "United Airlines")
    ac.airlineName = "Horizon Air"
    UTF_assertEqual(Operators_Resolve(ac, invalid, "", invalid, false).name, "Horizon Air")
    ac.airlineName = ""
    UTF_assertEqual(Operators_Resolve(ac, invalid, "NetJets Europe", invalid, false).name, "NetJets Europe")
    resolved = Operators_Resolve(ac, invalid, "", invalid, false)
    UTF_assertEqual(resolved.name, "Bank Of Utah Trustee")
    UTF_assertEqual(resolved.kind, "owner")
    person = Operators_TestAircraft("N242DT", "a237ca", "SHERLOCK WILLIAM H")
    hidden = Operators_Resolve(person, invalid, "", invalid, false)
    UTF_assertEqual(hidden.name, "Private owner")
    UTF_assertEqual(hidden.kind, "private")
    shown = Operators_Resolve(person, invalid, "", invalid, true)
    UTF_assertEqual(shown.name, "Sherlock William H")
    UTF_assertEqual(shown.kind, "private")
    lookedUp = Operators_TestAircraft("", "a87cf9", "")
    owner = { found: true, owner: "Alaska Airlines", model: "EMB-175 LR", manufacturer: "Embraer" }
    UTF_assertEqual(Operators_Resolve(lookedUp, invalid, "", owner, false).name, "Alaska Airlines")
    military = Operators_Resolve(Operators_TestAircraft("RCH123", "ae1234", ""), invalid, "", invalid, false)
    UTF_assertEqual(military.name, "US military")
    UTF_assertEqual(military.kind, "military")
    unknown = Operators_Resolve(Operators_TestAircraft("", "a91556", ""), invalid, "", invalid, false)
    UTF_assertEqual(unknown.name, "Unknown operator")
    UTF_assertEqual(unknown.kind, "unknown")
end sub

' @Test
sub Test_Operators_Model()
    ac = Operators_TestAircraft("N182DK", "a00002", "")
    ac.registration = "N182DK"
    ac.desc = "CESSNA 182 Skylane"
    UTF_assertEqual(Operators_Model(ac, invalid), "Cessna 182 Skylane")
    ac.callsign = "SKW123"
    UTF_assertEqual(Operators_Model(ac, invalid), "Cessna 182 Skylane - N182DK")
    ac.desc = ""
    owner = { found: true, owner: "", model: "EMB-175 LR", manufacturer: "Embraer" }
    UTF_assertEqual(Operators_Model(ac, owner), "Embraer EMB-175 LR - N182DK")
    owner.model = "Boeing 737-800"
    owner.manufacturer = "Boeing"
    UTF_assertEqual(Operators_Model(ac, owner), "Boeing 737-800 - N182DK")
    ac.typeCode = "B738"
    UTF_assertEqual(Operators_Model(ac, invalid), "B738 - N182DK")
    ac.typeCode = ""
    ac.registration = ""
    UTF_assertEqual(Operators_Model(ac, invalid), "ICAO A00002")
    UTF_assertEqual(Operators_FixCaps("BOEING 787-9 Dreamliner"), "Boeing 787-9 Dreamliner")
    UTF_assertEqual(Operators_FixCaps("RV6"), "RV6")
    UTF_assertEqual(Operators_FixCaps(""), "")
end sub

' @Test
sub Test_Operators_ParseLookups()
    owner = Operators_ParseAircraft(Operators_SampleAircraftBody())
    UTF_assertTrue(owner.found)
    UTF_assertEqual(owner.owner, "United States Air Force")
    UTF_assertEqual(owner.model, "C-17A Globemaster III")
    UTF_assertEqual(owner.typeCode, "C17")
    UTF_assertEqual(owner.registration, "03-3123")
    unknown = Operators_ParseAircraft("{" + Chr(34) + "response" + Chr(34) + ":" + Chr(34) + "unknown aircraft" + Chr(34) + "}")
    UTF_assertFalse(unknown.found)
    UTF_assertFalse(Operators_ParseAircraft("nope").found)
    airlines = "{'response':[{'name':'China Cargo Airlines','icao':'CKK'}]}".Replace("'", Chr(34))
    UTF_assertEqual(Operators_ParseAirline(airlines), "China Cargo Airlines")
    UTF_assertEqual(Operators_ParseAirline("{'response':'unknown airline'}".Replace("'", Chr(34))), "")
    UTF_assertEqual(Operators_ParseAirline("{'response':[]}".Replace("'", Chr(34))), "")
    UTF_assertEqual(Operators_ParseAirline("garbage"), "")
    UTF_assertEqual(Operators_AircraftUrl("ae1234"), "https://api.adsbdb.com/v0/aircraft/ae1234")
    UTF_assertEqual(Operators_AirlineUrl("CSG"), "https://api.adsbdb.com/v0/airline/CSG")
end sub

' @Test
sub Test_Operators_PickAndTrim()
    known = Operators_TestAircraft("UAL1", "a00001", "")
    known.airlineName = "United Airlines"
    withOwner = Operators_TestAircraft("N1", "a00002", "SOMEONE")
    routed = Operators_TestAircraft("DAL2", "a00003", "")
    route = Routes_Empty()
    route.found = true
    route.airlineName = "Delta Air Lines"
    routes = { DAL2: route }
    cached = Operators_TestAircraft("", "a00004", "")
    owners = { a00004: { found: false } }
    unknown1 = Operators_TestAircraft("XYZ9", "a00005", "")
    unknown2 = Operators_TestAircraft("", "a00006", "")
    tisb = Operators_TestAircraft("", "~a00007", "")
    aircraft = [known, withOwner, routed, cached, unknown1, unknown2, tisb]
    picks = Operators_PickOwnerLookups(aircraft, routes, {}, owners, 5)
    UTF_assertEqual(picks.Count(), 2)
    UTF_assertEqual(picks[0], "a00005")
    UTF_assertEqual(picks[1], "a00006")
    UTF_assertEqual(Operators_PickOwnerLookups(aircraft, routes, {}, owners, 1).Count(), 1)
    UTF_assertEqual(Operators_PickOwnerLookups(aircraft, routes, { XYZ: "Xyz Air" }, owners, 5).Count(), 1)
    airlinePicks = Operators_PickAirlineLookups([known, routed, unknown1, unknown1, Operators_TestAircraft("ABC1", "a1", "")], routes, { ABC: "" }, 5)
    UTF_assertEqual(airlinePicks.Count(), 1)
    UTF_assertEqual(airlinePicks[0], "XYZ")
    cache = { a: 1, b: 2, c: 3 }
    Operators_TrimCache(cache, 5)
    UTF_assertEqual(cache.Count(), 3)
    Operators_TrimCache(cache, 2)
    UTF_assertEqual(cache.Count(), 0)
end sub
