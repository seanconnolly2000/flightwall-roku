' On-device tests for source/lib/settings.brs. The registry tests only write back
' what is already stored so they never disturb the viewer's configuration.

' @Test
sub Test_Settings_DefaultsAndLoad()
    defaults = Settings_Defaults()
    UTF_assertEqual(defaults.radius, "50")
    UTF_assertEqual(defaults.provider, "adsbfi")
    UTF_assertTrue(Settings_IsProvider("adsblol"))
    UTF_assertFalse(Settings_IsProvider("flightaware"))
    UTF_assertEqual(defaults.pollSeconds, "10")
    loaded = Settings_Load()
    UTF_assertAAHasKeys(loaded, ["zip", "lat", "lon", "radius", "provider", "pollSeconds", "openskyClientId", "openskyClientSecret"])
end sub

' @Test
sub Test_Settings_SaveRoundTrip()
    current = Settings_Load()
    Settings_Save(current)
    again = Settings_Load()
    UTF_assertEqual(again.zip, current.zip)
    UTF_assertEqual(again.radius, current.radius)
    UTF_assertEqual(again.provider, current.provider)
end sub

' @Test
sub Test_Settings_NextValueCycles()
    options = [10, 25, 50]
    UTF_assertEqual(Settings_NextValue(options, "25", 1), "50")
    UTF_assertEqual(Settings_NextValue(options, "50", 1), "10")
    UTF_assertEqual(Settings_NextValue(options, "10", -1), "50")
    UTF_assertEqual(Settings_NextValue(options, "7", 1), "10")
    UTF_assertEqual(Settings_NextValue([], "7", 1), "7")
    UTF_assertEqual(Settings_NextProvider("adsbfi", 1), "adsblol")
    UTF_assertEqual(Settings_NextProvider("opensky", 1), "adsbfi")
    UTF_assertEqual(Settings_NextProvider("adsbfi", -1), "opensky")
end sub

' @Test
sub Test_Settings_Validation()
    UTF_assertTrue(Settings_IsZipValid("94110"))
    UTF_assertFalse(Settings_IsZipValid("9411"))
    UTF_assertFalse(Settings_IsZipValid("9411a"))
    UTF_assertFalse(Settings_IsZipValid(""))
    UTF_assertTrue(Settings_IsConfigured({ lat: "1", lon: "2" }))
    UTF_assertFalse(Settings_IsConfigured({ lat: "", lon: "2" }))
    UTF_assertTrue(Settings_HasCredentials({ openskyClientId: "a", openskyClientSecret: "b" }))
    UTF_assertFalse(Settings_HasCredentials({ openskyClientId: "a", openskyClientSecret: "" }))
end sub

' @Test
sub Test_Settings_Clamps()
    UTF_assertEqual(Settings_Radius({ radius: "999" }), 250.0)
    UTF_assertEqual(Settings_Radius({ radius: "abc" }), 50.0)
    UTF_assertEqual(Settings_Radius({ radius: "1" }), 5.0)
    UTF_assertEqual(Settings_PollSeconds({ pollSeconds: "3" }), 5)
    UTF_assertEqual(Settings_PollSeconds({ pollSeconds: "" }), 10)
    UTF_assertEqual(Settings_PollSeconds({ pollSeconds: "30" }), 30)
end sub

' @Test
sub Test_Settings_FlagsAndNames()
    UTF_assertTrue(Settings_Flag({ trails: "1" }, "trails"))
    UTF_assertFalse(Settings_Flag({ trails: "0" }, "trails"))
    UTF_assertEqual(Settings_Toggle("1"), "0")
    UTF_assertEqual(Settings_Toggle("0"), "1")
    UTF_assertEqual(Settings_OnOff("1"), "on")
    UTF_assertEqual(Settings_OnOff("0"), "off")
    UTF_assertEqual(Settings_ProviderName("opensky"), "OpenSky Network")
    UTF_assertEqual(Settings_ProviderName("mystery"), "mystery")
end sub
