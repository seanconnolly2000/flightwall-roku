' Channel entry point. Launching with ?RunTests=true runs the on-device unit tests
' when the test build (which includes source/tests) is side-loaded.
'
' Launch parameters (ECP: POST http://<roku>:8060/launch/dev?zip=94110&radius=50&poll=20&provider=adsbfi)
' can pre-set the ZIP code, radius, poll interval and data source (adsbfi, adsblol, opensky).

sub Main(args as Object)
    if args <> invalid and args.RunTests = "true" and Type(SkyTraffic_RunTests) = "Function" then
        SkyTraffic_RunTests(args)
        return
    end if
    SkyTraffic_ShowScene("MainScene", SkyTraffic_LaunchParams(args, false))
end sub
