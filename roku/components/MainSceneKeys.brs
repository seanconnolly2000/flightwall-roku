' Remote-control handling for the channel. Kept in its own file because Roku forbids
' key handlers in screensavers: the screensaver build omits every *Keys.brs script.

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false
    ? "[FlightWall] key " + key
    if m.screensaver then return false
    if m.settingsPanel.visible then return false
    if key = "options" or key = "OK" then
        openSettings("", "zip")
        return true
    end if
    if key = "play" then
        toggleDiagnostics()
        return true
    end if
    if key = "back" and m.diag.visible then
        m.diag.visible = false
        return true
    end if
    if key = "up" or key = "down" then
        delta = 1
        if key = "down" then delta = -1
        m.settings.radius = Settings_NextValue(Settings_RadiusOptions(), Util_Str(m.settings.radius), delta)
        Settings_Save(m.settings)
        logEvent("radius", m.settings.radius + " miles")
        applySettingsToViews()
        poll()
        return true
    end if
    return false
end function
