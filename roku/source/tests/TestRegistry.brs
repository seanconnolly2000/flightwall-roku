' Registers every on-device test with Roku's Unit Testing Framework.
' Only present in the test build (`flightwall package --with-tests`).

sub FlightWall_RunTests(args as Object)
    runner = TestRunner()
    runner.SetFunctions([
        Test_Util_FloatStr
        Test_Util_ToFloatAndToInt
        Test_Util_Str
        Test_Util_Round
        Test_Util_TypeChecks
        Test_Util_PadAndCopy
        Test_Geo_HaversineSfoToLax
        Test_Geo_Bearing
        Test_Geo_Atan2Quadrants
        Test_Geo_AngleDiff
        Test_Geo_Compass
        Test_Geo_Projection
        Test_Geo_TileKeys
        Test_Geo_TilesInView
        Test_Geo_BBoxAndUnits
        Test_Settings_DefaultsAndLoad
        Test_Settings_SaveRoundTrip
        Test_Settings_NextValueCycles
        Test_Settings_Validation
        Test_Settings_Clamps
        Test_Settings_FlagsAndNames
        Test_Flights_ProviderUrls
        Test_Flights_ParseAdsbLol
        Test_Flights_ParseAdsbFiAndBadInput
        Test_Flights_ParseOpenSky
        Test_Flights_Classify
        Test_Flights_BackoffAndPrompt
        Test_Flights_Presentation
        Test_Flights_Airborne
        Test_Routes_Callsigns
        Test_Routes_ParseFound
        Test_Routes_ParseUnknownAndGarbage
        Test_Routes_PartialRoute
        Test_Routes_LogoUrl
        Test_Routes_ReconcileRejectsFarAwayLeg
        Test_Routes_ReconcileSwapsReversedLeg
        Test_Routes_ReconcileKeepsPlausibleRoutes
        Test_Routes_Pick
        Test_Format_Thousands
        Test_Format_Measurements
        Test_Format_Clock
        Test_Format_SummaryAndType
        Test_Zips_LookupSampleTable
        Test_Zips_LookupBundledTable
        Test_Zips_NearestCity
        Test_Audit_AppendTrims
        Test_Audit_EntryFormat
        Test_Audit_LoadReturnsArray
        Test_Weather_Url
        Test_Weather_CodeInfo
        Test_Weather_Days
        Test_Weather_ParseSample
        Test_Weather_ParseErrors
        Test_Http_Host
        Test_Operators_PrefixAndTable
        Test_Operators_OrganizationAndCase
        Test_Operators_MilitaryHex
        Test_Operators_ResolvePriority
        Test_Operators_Model
        Test_Operators_ParseLookups
        Test_Operators_PickAndTrim
    ])
    if args.IncludeFilter <> invalid then runner.SetIncludeFilter(args.IncludeFilter)
    if args.ExcludeFilter <> invalid then runner.SetExcludeFilter(args.ExcludeFilter)
    runner.Logger.SetVerbosity(3)
    runner.Logger.SetEcho(false)
    runner.Logger.SetJUnit(false)
    runner.Run()
end sub
