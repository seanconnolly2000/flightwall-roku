' On-device tests for source/lib/zips.brs, including the bundled data file.

function Zips_SampleTable() as String
    return Chr(10) + "00601,18.1806,-66.7500" + Chr(10) + "94110,37.7485,-122.4153" + Chr(10)
end function

function Zips_SampleCities() as Object
    return [
        { n: "San Francisco", a: "California", lat: 37.7749, lon: -122.4194, p: 800000 }
        { n: "Oakland", a: "California", lat: 37.8044, lon: -122.2712, p: 400000 }
        { n: "Broken", a: "", lat: "x", lon: invalid, p: 1 }
    ]
end function

' @Test
sub Test_Zips_LookupSampleTable()
    hit = Zips_Lookup("94110", Zips_SampleTable())
    UTF_assertTrue(hit.found)
    UTF_assertTrue(Abs(hit.lat - 37.7485) < 0.0001)
    UTF_assertTrue(Abs(hit.lon + 122.4153) < 0.0001)
    UTF_assertFalse(Zips_Lookup("00000", Zips_SampleTable()).found)
    UTF_assertFalse(Zips_Lookup("9411", Zips_SampleTable()).found)
    UTF_assertFalse(Zips_Lookup("94110", "").found)
    noTrailingNewline = Chr(10) + "94110,37.7,-122.4"
    UTF_assertTrue(Zips_Lookup("94110", noTrailingNewline).found)
    UTF_assertFalse(Zips_Lookup("94110", Chr(10) + "94110" + Chr(10)).found)
end sub

' @Test
sub Test_Zips_LookupBundledTable()
    table = ReadAsciiFile("pkg:/data/zips.txt")
    UTF_assertTrue(Len(table) > 100000, "bundled zips.txt should be present")
    hit = Zips_Lookup("94110", table)
    UTF_assertTrue(hit.found)
    UTF_assertTrue(hit.lat > 37 and hit.lat < 38)
    UTF_assertTrue(hit.lon > -123 and hit.lon < -122)
    UTF_assertTrue(Zips_Lookup("10001", table).found)
end sub

' @Test
sub Test_Zips_NearestCity()
    nearest = Zips_NearestCity(37.76, -122.43, Zips_SampleCities())
    UTF_assertEqual(nearest.name, "San Francisco")
    UTF_assertEqual(nearest.state, "California")
    UTF_assertTrue(nearest.distMi < 3)
    UTF_assertEqual(Zips_PlaceLabel(nearest), "San Francisco")
    farther = Zips_NearestCity(37.9, -122.2, Zips_SampleCities())
    UTF_assertEqual(farther.name, "Oakland")
    label = Zips_PlaceLabel(farther)
    UTF_assertTrue(label.Instr(" of Oakland") > 0, label)
    UTF_assertInvalid(Zips_NearestCity(0, 0, []))
    UTF_assertInvalid(Zips_NearestCity(0, 0, invalid))
    UTF_assertEqual(Zips_PlaceLabel(invalid), "")
end sub
