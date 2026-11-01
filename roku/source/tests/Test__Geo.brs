' On-device tests for source/lib/geo.brs.

function Geo_Near(actual as Float, expected as Float, tolerance as Float) as Boolean
    return Abs(actual - expected) <= tolerance
end function

' @Test
sub Test_Geo_HaversineSfoToLax()
    miles = Geo_Haversine(37.619, -122.375, 33.9425, -118.4081)
    UTF_assertTrue(Geo_Near(miles, 337.0, 5.0), "SFO-LAX should be about 337 miles, got " + Str(miles))
    UTF_assertTrue(Geo_Near(Geo_Haversine(10, 10, 10, 10), 0.0, 0.001))
end sub

' @Test
sub Test_Geo_Bearing()
    UTF_assertTrue(Geo_Near(Geo_Bearing(0, 0, 1, 0), 0.0, 0.5))
    UTF_assertTrue(Geo_Near(Geo_Bearing(0, 0, 0, 1), 90.0, 0.5))
    UTF_assertTrue(Geo_Near(Geo_Bearing(0, 0, -1, 0), 180.0, 0.5))
    UTF_assertTrue(Geo_Near(Geo_Bearing(0, 0, 0, -1), 270.0, 0.5))
    sfoLax = Geo_Bearing(37.619, -122.375, 33.9425, -118.4081)
    UTF_assertTrue(Geo_Near(sfoLax, 137.0, 3.0), "SFO-LAX bearing about 137, got " + Str(sfoLax))
end sub

' @Test
sub Test_Geo_Atan2Quadrants()
    quarter = Geo_Pi() / 2
    UTF_assertTrue(Geo_Near(Geo_Atan2(1, 0), quarter, 0.0001))
    UTF_assertTrue(Geo_Near(Geo_Atan2(-1, 0), -quarter, 0.0001))
    UTF_assertTrue(Geo_Near(Geo_Atan2(0, 0), 0.0, 0.0001))
    UTF_assertTrue(Geo_Near(Geo_Atan2(1, -1), 3 * quarter / 2, 0.0001))
    UTF_assertTrue(Geo_Near(Geo_Atan2(-1, -1), -3 * quarter / 2, 0.0001))
end sub

' @Test
sub Test_Geo_Compass()
    UTF_assertEqual(Geo_Compass(0), "N")
    UTF_assertEqual(Geo_Compass(44), "NE")
    UTF_assertEqual(Geo_Compass(180), "S")
    UTF_assertEqual(Geo_Compass(270), "W")
    UTF_assertEqual(Geo_Compass(350), "N")
end sub

' @Test
sub Test_Geo_Projection()
    proj = Geo_Projection(37.75, -122.42, 50, 340)
    UTF_assertTrue(Geo_Near(proj.pxPerMile, 6.8, 0.001))
    center = Geo_Project(proj, 37.75, -122.42)
    UTF_assertTrue(Geo_Near(center.x, 0.0, 0.001))
    UTF_assertTrue(Geo_Near(center.y, 0.0, 0.001))
    north = Geo_Project(proj, 38.75, -122.42)
    UTF_assertTrue(Geo_Near(north.y, -469.8, 1.0), "one degree north should be about -470 px, got " + Str(north.y))
    east = Geo_Project(proj, 37.75, -121.42)
    UTF_assertTrue(Geo_Near(east.x, 371.4, 2.0), "one degree east should be about 371 px, got " + Str(east.x))
end sub

' @Test
sub Test_Geo_TileKeys()
    UTF_assertEqual(Geo_TileKey(37.7, -122.4), "37_-123")
    UTF_assertEqual(Geo_TileKey(-0.5, 0.5), "-1_0")
    UTF_assertEqual(Geo_TileKey(41.0, -88.0), "41_-88")
end sub

' @Test
sub Test_Geo_TilesInView()
    proj = Geo_Projection(37.75, -122.42, 50, 340)
    tiles = Geo_TilesInView(proj, 350)
    UTF_assertEqual(tiles.Count(), 6)
    UTF_assertEqual(tiles[0].key, "37_-124")
    found = invalid
    for each tile in tiles
        if tile.key = "37_-123" then found = tile
    end for
    UTF_assertNotInvalid(found)
    UTF_assertTrue(found.x < 0 and found.y < 0, "tile 37_-123 top-left should be up and left of centre")
    UTF_assertTrue(Geo_Near(found.w, 371.4, 2.0))
    UTF_assertTrue(Geo_Near(found.h, 469.8, 1.0))
end sub

' @Test
sub Test_Geo_BBoxAndUnits()
    bounds = Geo_BBox(37.75, -122.42, 50)
    UTF_assertTrue(Geo_Near(bounds.lamin, 37.026, 0.01))
    UTF_assertTrue(Geo_Near(bounds.lamax, 38.474, 0.01))
    UTF_assertTrue(bounds.lomin < -123.3 and bounds.lomax > -121.6)
    UTF_assertTrue(Geo_Near(Geo_NmFromMiles(100), 86.9, 0.1))
    UTF_assertTrue(Geo_Near(Geo_MilesFromKm(100), 62.1, 0.1))
end sub
