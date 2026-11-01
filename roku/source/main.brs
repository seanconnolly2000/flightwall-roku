' Channel entry point. Launching with ?RunTests=true runs the on-device unit tests
' when the test build (which includes source/tests) is side-loaded.
'
' Launch parameters (ECP: POST http://<roku>:8060/launch/dev?zip=94110&radius=50)
' can pre-set the ZIP code and radius, which is handy for setup from a PC.

sub Main(args as Object)
    if args <> invalid and args.RunTests = "true" and Type(FlightWall_RunTests) = "Function" then
        FlightWall_RunTests(args)
        return
    end if
    FlightWall_ShowScene("MainScene", FlightWall_LaunchParams(args, false))
end sub
