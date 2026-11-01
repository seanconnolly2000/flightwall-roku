' Geodesy and map projection helpers (statute miles, decimal degrees, HD pixels).

function Geo_Pi() as Float
    return 3.14159265
end function

function Geo_Rad(degrees as Float) as Float
    return degrees * Geo_Pi() / 180.0
end function

function Geo_Deg(radians as Float) as Float
    return radians * 180.0 / Geo_Pi()
end function

' BrightScript has Atn() but no Atan2(); this adds the quadrant handling.
function Geo_Atan2(y as Float, x as Float) as Float
    if x > 0 then return Atn(y / x)
    if x < 0 then
        if y >= 0 then return Atn(y / x) + Geo_Pi()
        return Atn(y / x) - Geo_Pi()
    end if
    if y > 0 then return Geo_Pi() / 2
    if y < 0 then return -Geo_Pi() / 2
    return 0.0
end function

' Great-circle distance in statute miles.
function Geo_Haversine(lat1 as Float, lon1 as Float, lat2 as Float, lon2 as Float) as Float
    earthMiles = 3958.8
    dLat = Geo_Rad(lat2 - lat1)
    dLon = Geo_Rad(lon2 - lon1)
    a = Sin(dLat / 2) * Sin(dLat / 2) + Cos(Geo_Rad(lat1)) * Cos(Geo_Rad(lat2)) * Sin(dLon / 2) * Sin(dLon / 2)
    if a > 1 then a = 1
    if a < 0 then a = 0
    c = 2 * Geo_Atan2(Sqr(a), Sqr(1 - a))
    return earthMiles * c
end function

' Initial bearing from point 1 to point 2 in degrees clockwise from north (0..360).
function Geo_Bearing(lat1 as Float, lon1 as Float, lat2 as Float, lon2 as Float) as Float
    dLon = Geo_Rad(lon2 - lon1)
    l1 = Geo_Rad(lat1)
    l2 = Geo_Rad(lat2)
    x = Sin(dLon) * Cos(l2)
    y = Cos(l1) * Sin(l2) - Sin(l1) * Cos(l2) * Cos(dLon)
    bearing = Geo_Deg(Geo_Atan2(x, y))
    while bearing < 0
        bearing = bearing + 360
    end while
    while bearing >= 360
        bearing = bearing - 360
    end while
    return bearing
end function

function Geo_Compass(bearing as Float) as String
    names = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
    index = Int((bearing + 22.5) / 45.0) MOD 8
    return names[index]
end function

function Geo_MilesPerDegreeLat() as Float
    return 69.0931
end function

' Equirectangular projection centred on the viewer with the radius mapped to radiusPx pixels.
function Geo_Projection(centerLat as Float, centerLon as Float, radiusMiles as Float, radiusPx as Float) as Object
    if radiusMiles <= 0 then radiusMiles = 1
    pxPerMile = radiusPx / radiusMiles
    pxPerDegLat = pxPerMile * Geo_MilesPerDegreeLat()
    pxPerDegLon = pxPerDegLat * Cos(Geo_Rad(centerLat))
    return {
        lat: centerLat
        lon: centerLon
        radiusMiles: radiusMiles
        radiusPx: radiusPx
        pxPerMile: pxPerMile
        pxPerDegLat: pxPerDegLat
        pxPerDegLon: pxPerDegLon
    }
end function

' Screen offset from the map centre (x right, y down) for a coordinate.
function Geo_Project(proj as Object, lat as Float, lon as Float) as Object
    return {
        x: (lon - proj.lon) * proj.pxPerDegLon
        y: -(lat - proj.lat) * proj.pxPerDegLat
    }
end function

' Tile key for the one-degree cell containing a coordinate, matching the tile index.
function Geo_TileKey(lat as Float, lon as Float) as String
    return Int(lat).ToStr() + "_" + Int(lon).ToStr()
end function

' Every one-degree tile that intersects the square of +-halfSizePx around the centre.
function Geo_TilesInView(proj as Object, halfSizePx as Float) as Object
    tiles = []
    degLat = halfSizePx / proj.pxPerDegLat
    degLon = halfSizePx / proj.pxPerDegLon
    latMin = Int(proj.lat - degLat)
    latMax = Int(proj.lat + degLat)
    lonMin = Int(proj.lon - degLon)
    lonMax = Int(proj.lon + degLon)
    if latMax - latMin > 40 or lonMax - lonMin > 40 then return tiles
    for lat = latMin to latMax
        for lon = lonMin to lonMax
            topLeft = Geo_Project(proj, lat + 1.0, lon + 0.0)
            tiles.Push({
                lat: lat
                lon: lon
                key: Geo_TileKey(lat + 0.0, lon + 0.0)
                x: topLeft.x
                y: topLeft.y
                w: proj.pxPerDegLon
                h: proj.pxPerDegLat
            })
        end for
    end for
    return tiles
end function

' Bounding box (OpenSky style) around a point.
function Geo_BBox(lat as Float, lon as Float, radiusMiles as Float) as Object
    dLat = radiusMiles / Geo_MilesPerDegreeLat()
    cosLat = Cos(Geo_Rad(lat))
    if cosLat < 0.05 then cosLat = 0.05
    dLon = dLat / cosLat
    return {
        lamin: lat - dLat
        lamax: lat + dLat
        lomin: lon - dLon
        lomax: lon + dLon
    }
end function

function Geo_NmFromMiles(miles as Float) as Float
    return miles * 0.868976
end function

function Geo_MilesFromKm(km as Float) as Float
    return km * 0.621371
end function
