' Resolves a ZIP code to coordinates and a place name from the bundled data files.

sub init()
    m.top.functionName = "runTask"
end sub

sub runTask()
    zip = m.top.zip
    result = { ok: false, zip: zip, lat: 0.0, lon: 0.0, place: "", message: "" }
    table = ReadAsciiFile("pkg:/data/zips.txt")
    if table = "" then
        result.message = "ZIP table is missing from the package"
        m.top.result = result
        return
    end if
    hit = Zips_Lookup(zip, table)
    if not hit.found then
        result.message = "ZIP code " + zip + " was not found"
        m.top.result = result
        return
    end if
    result.ok = true
    result.lat = hit.lat
    result.lon = hit.lon
    citiesJson = ParseJson(ReadAsciiFile("pkg:/data/cities.json"))
    if Util_IsAA(citiesJson) then
        result.place = Zips_PlaceLabel(Zips_NearestCity(hit.lat, hit.lon, citiesJson.cities))
    end if
    m.top.result = result
end sub
