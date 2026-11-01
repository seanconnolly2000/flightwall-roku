' ZIP code centroid lookup in the bundled table and nearest-city naming.
'
' The table is "\nZIP,lat,lon\n..." so a single Instr() finds a ZIP without parsing
' thirty thousand lines in BrightScript.

function Zips_Lookup(zip as String, table as String) as Object
    result = { found: false, lat: 0.0, lon: 0.0 }
    if Len(zip) <> 5 or table = "" then return result
    hit = Instr(1, table, Chr(10) + zip + ",")
    if hit = 0 then return result
    lineStart = hit + 1
    lineEnd = Instr(lineStart, table, Chr(10))
    if lineEnd = 0 then lineEnd = Len(table) + 1
    line = Mid(table, lineStart, lineEnd - lineStart)
    parts = line.Split(",")
    if parts.Count() < 3 then return result
    result.found = true
    result.lat = Val(parts[1])
    result.lon = Val(parts[2])
    return result
end function

' Nearest entry of the bundled city list: {name, state, distMi, bearing} or invalid.
function Zips_NearestCity(lat as Float, lon as Float, cities as Object) as Object
    best = invalid
    bestDist = 1.0e9
    if not Util_IsArray(cities) then return invalid
    for each city in cities
        if Util_IsNumber(city.lat) and Util_IsNumber(city.lon) then
            dist = Geo_Haversine(lat, lon, city.lat, city.lon)
            if dist < bestDist then
                bestDist = dist
                best = city
            end if
        end if
    end for
    if best = invalid then return invalid
    return {
        name: Util_Str(best.n)
        state: Util_Str(best.a)
        distMi: bestDist
        bearing: Geo_Bearing(best.lat, best.lon, lat, lon)
    }
end function

' "San Francisco" when close, otherwise "12 mi NE of San Francisco".
function Zips_PlaceLabel(nearest as Object) as String
    if nearest = invalid then return ""
    if nearest.distMi < 3 then return nearest.name
    return Util_Round(nearest.distMi).ToStr() + " mi " + Geo_Compass(nearest.bearing) + " of " + nearest.name
end function
