' Screensaver entry points (Settings > Theme > Screensavers > SkyTraffic).
' Any key press ends the screensaver; the OS handles that.

sub RunScreenSaver(args as Object)
    SkyTraffic_ShowScene("MainScene", SkyTraffic_LaunchParams(args, true))
end sub

' "Change screensaver settings" in the screensaver detail screen.
sub RunScreenSaverSettings(args as Object)
    SkyTraffic_ShowScene("SettingsScene", SkyTraffic_LaunchParams(args, true))
end sub
