' Screensaver entry points (Settings > Theme > Screensavers > FlightWall).
' Any key press ends the screensaver; the OS handles that.

sub RunScreenSaver(args as Object)
    FlightWall_ShowScene("MainScene", FlightWall_LaunchParams(args, true))
end sub

' "Change screensaver settings" in the screensaver detail screen.
sub RunScreenSaverSettings(args as Object)
    FlightWall_ShowScene("SettingsScene", FlightWall_LaunchParams(args, true))
end sub
