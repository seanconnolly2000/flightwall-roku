' Who operates an aircraft: the airline behind a callsign prefix, the registered owner
' from the registry (adsb.fi ownOp or an adsbdb lookup), or the military hex range.
' Also the display rule for private owners, which the viewer can toggle.

' Three-letter ICAO airline prefix of an airline-style callsign, or "".
function Operators_Prefix(callsign as String) as String
    if not Routes_IsLookupWorthy(callsign) then return ""
    return Left(callsign, 3)
end function

' Airline name from the bundled table ("\nCKK,China Cargo Airlines\n...").
function Operators_TableLookup(table as String, icao as String) as String
    if Len(icao) <> 3 or table = "" then return ""
    hit = Instr(1, table, Chr(10) + UCase(icao) + ",")
    if hit = 0 then return ""
    lineStart = hit + 5
    lineEnd = Instr(lineStart, table, Chr(10))
    if lineEnd = 0 then lineEnd = Len(table) + 1
    return Mid(table, lineStart, lineEnd - lineStart).Trim()
end function

function Operators_OrgWords() as Object
    return [
        "LLC", "INC", "CORP", "CO", "COMPANY", "LTD", "LP", "LLP"
        "PLC", "GMBH", "TRUST", "TRUSTEE", "BANK", "AIR", "AVIATION", "AIRLINES"
        "AIRWAYS", "AIRLINE", "LEASING", "HOLDINGS", "GROUP", "DEPARTMENT", "DEPT", "UNITED"
        "STATES", "US", "USA", "FEDERAL", "STATE", "COUNTY", "CITY", "UNIVERSITY"
        "COLLEGE", "POLICE", "SHERIFF", "FIRE", "FORCE", "NAVY", "ARMY", "COAST"
        "GUARD", "GOVERNMENT", "AGENCY", "ADMINISTRATION", "AUTHORITY", "PARTNERS", "ASSOCIATES", "ASSOCIATION"
        "CLUB", "SCHOOL", "FLIGHT", "FLYING", "JET", "JETS", "CHARTER", "SERVICES"
        "SERVICE", "ENTERPRISES", "INDUSTRIES", "SALES", "INTERNATIONAL", "NETWORK", "SYSTEMS", "MEDICAL"
        "HOSPITAL", "HEALTH", "EXPRESS", "CARGO", "FOUNDATION", "MINISTRY", "LIMITED", "INCORPORATED"
        "CORPORATION", "DBA", "HELICOPTER", "HELICOPTERS", "RESCUE", "PATROL", "TRANSPORT", "LOGISTICS"
        "AERO", "AIRCRAFT", "FLYERS", "RENTAL", "RENTALS", "LEASE", "FINANCE", "CAPITAL"
        "MANAGEMENT", "TECHNOLOGIES", "TECHNOLOGY", "ENERGY", "OIL", "RANCH", "FARMS", "CHURCH"
        "MISSION", "AMBULANCE", "MEDFLIGHT", "LIFE", "WINGS"
    ]
end function

' True when a registry owner string reads like an organization rather than a person.
function Operators_IsOrganization(name as String) as Boolean
    if name.Trim() = "" then return false
    padded = " " + UCase(name) + " "
    for each word in Operators_OrgWords()
        if Instr(1, padded, " " + word + " ") > 0 then return true
    end for
    return false
end function

function Operators_KeepUpper() as Object
    return {
        LLC: true, LP: true, LLP: true, PLC: true, USA: true, US: true, FAA: true, DHS: true
        NASA: true, CBP: true, FBI: true, DEA: true, USAF: true, USCG: true, USN: true, USMC: true
        NOAA: true, UPS: true, DHL: true, II: true, III: true, IV: true, JR: true, SR: true
        DBA: true, GMBH: true, SA: true, AG: true, BV: true, NV: true
    }
end function

' "HORIZON AIR INDUSTRIES INC" -> "Horizon Air Industries Inc" (acronyms kept).
function Operators_TitleCase(name as String) as String
    keep = Operators_KeepUpper()
    out = ""
    for each word in name.Trim().Split(" ")
        if word <> "" then
            piece = UCase(Left(word, 1))
            if Len(word) > 1 then piece = piece + LCase(Mid(word, 2))
            if keep.DoesExist(UCase(word)) then piece = UCase(word)
            if out <> "" then out = out + " "
            out = out + piece
        end if
    end for
    return out
end function

' ICAO 24-bit addresses AE0000-AFFFFF are allocated to the United States military.
function Operators_IsMilitaryHex(hex as String) as Boolean
    lower = LCase(hex.Trim())
    if Len(lower) <> 6 then return false
    prefix = Left(lower, 2)
    return prefix = "ae" or prefix = "af"
end function

' Picks the operator line for an aircraft. Airline names win over registry owners because
' airliners are often registered to leasing trusts.
' Returns {name, kind} with kind airline | owner | private | military | unknown.
function Operators_Resolve(ac as Object, route as Object, airline as String, owner as Object, showNames as Boolean) as Object
    if route <> invalid and Util_Str(route.airlineName) <> "" then return { name: route.airlineName, kind: "airline" }
    if Util_Str(ac.airlineName) <> "" then return { name: ac.airlineName, kind: "airline" }
    if airline <> "" then return { name: airline, kind: "airline" }
    ownerName = Util_Str(ac.ownOp).Trim()
    if ownerName = "" and owner <> invalid then ownerName = Util_Str(owner.owner).Trim()
    if ownerName <> "" then
        if Operators_IsOrganization(ownerName) then return { name: Operators_TitleCase(ownerName), kind: "owner" }
        if showNames then return { name: Operators_TitleCase(ownerName), kind: "private" }
        return { name: "Private owner", kind: "private" }
    end if
    if Operators_IsMilitaryHex(Util_Str(ac.hex)) then return { name: "US military", kind: "military" }
    return { name: "Unknown operator", kind: "unknown" }
end function

' Aircraft description: adsb.fi text, then the adsbdb model, then the ICAO type code.
' The registration is appended when known.
function Operators_Model(ac as Object, owner as Object) as String
    model = Util_Str(ac.desc).Trim()
    if model = "" and owner <> invalid then
        model = Util_Str(owner.model).Trim()
        manufacturer = Util_Str(owner.manufacturer).Trim()
        if model <> "" and manufacturer <> "" and Instr(1, UCase(model), UCase(manufacturer)) = 0 then model = manufacturer + " " + model
    end if
    if model = "" then model = Util_Str(ac.typeCode)
    model = Operators_FixCaps(model)
    registration = Util_Str(ac.registration)
    if registration <> "" and registration <> Util_Str(ac.callsign) then
        if model <> "" then model = model + " - "
        model = model + registration
    end if
    if model = "" then model = "ICAO " + UCase(Util_Str(ac.hex))
    return model
end function

' Registry descriptions shout the manufacturer ("CESSNA 182 Skylane"); calm the first word.
function Operators_FixCaps(text as String) as String
    words = text.Split(" ")
    if words.Count() = 0 then return text
    first = words[0]
    if Len(first) > 3 and first = UCase(first) and first <> Operators_TitleCase(first) then
        words[0] = Operators_TitleCase(first)
    end if
    out = ""
    for each word in words
        if word <> "" then
            if out <> "" then out = out + " "
            out = out + word
        end if
    end for
    return out
end function

function Operators_AircraftUrl(hex as String) as String
    return "https://api.adsbdb.com/v0/aircraft/" + hex
end function

function Operators_AirlineUrl(icao as String) as String
    return "https://api.adsbdb.com/v0/airline/" + icao
end function

' adsbdb /v0/aircraft/{hex}: registry owner and model. found=false for unknown aircraft.
function Operators_ParseAircraft(body as String) as Object
    out = { found: false, owner: "", country: "", model: "", manufacturer: "", typeCode: "", registration: "", operatorCode: "" }
    json = ParseJson(body)
    if not Util_IsAA(json) or not Util_IsAA(json.response) then return out
    aircraft = json.response.aircraft
    if not Util_IsAA(aircraft) then return out
    out.owner = Util_Str(aircraft.registered_owner)
    out.country = Util_Str(aircraft.registered_owner_country_name)
    out.model = Util_Str(aircraft.type)
    out.manufacturer = Util_Str(aircraft.manufacturer)
    out.typeCode = Util_Str(aircraft.icao_type)
    out.registration = Util_Str(aircraft.registration)
    out.operatorCode = Util_Str(aircraft.registered_owner_operator_flag_code)
    out.found = out.owner <> "" or out.model <> ""
    return out
end function

' adsbdb /v0/airline/{icao}: the first airline's name, or "".
function Operators_ParseAirline(body as String) as String
    json = ParseJson(body)
    if not Util_IsAA(json) then return ""
    list = json.response
    if not Util_IsArray(list) or list.Count() = 0 then return ""
    first = list[0]
    if not Util_IsAA(first) then return ""
    return Util_Str(first.name)
end function

' Hex codes that would otherwise read "Unknown operator" and are not cached yet.
function Operators_PickOwnerLookups(aircraft as Object, routes as Object, airlines as Object, owners as Object, maxCount as Integer) as Object
    picks = []
    for each ac in aircraft
        if picks.Count() < maxCount then
            hex = Util_Str(ac.hex)
            needs = Len(hex) = 6 and Util_Str(ac.ownOp) = "" and Util_Str(ac.airlineName) = "" and not owners.DoesExist(hex)
            if needs then
                route = routes[Util_Str(ac.callsign)]
                if route <> invalid and Util_Str(route.airlineName) <> "" then needs = false
                prefix = Operators_Prefix(Util_Str(ac.callsign))
                if prefix <> "" and Util_Str(airlines[prefix]) <> "" then needs = false
            end if
            if needs then picks.Push(hex)
        end if
    end for
    return picks
end function

' Airline prefixes the bundled table did not know, not cached yet (negative results cached as "").
function Operators_PickAirlineLookups(aircraft as Object, routes as Object, airlines as Object, maxCount as Integer) as Object
    picks = []
    seen = {}
    for each ac in aircraft
        if picks.Count() < maxCount then
            prefix = Operators_Prefix(Util_Str(ac.callsign))
            if prefix <> "" and Util_Str(ac.airlineName) = "" and not airlines.DoesExist(prefix) and not seen.DoesExist(prefix) then
                route = routes[Util_Str(ac.callsign)]
                if route = invalid or Util_Str(route.airlineName) = "" then
                    picks.Push(prefix)
                    seen[prefix] = true
                end if
            end if
        end if
    end for
    return picks
end function

' Keeps a lookup cache bounded. A wholesale clear is fine: entries refill one per poll.
function Operators_TrimCache(cache as Object, maxEntries as Integer) as Object
    if cache.Count() > maxEntries then cache.Clear()
    return cache
end function
