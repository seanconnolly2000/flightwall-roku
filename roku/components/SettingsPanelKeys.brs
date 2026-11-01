' Back cancels the settings editor. Lives in a *Keys.brs file so the screensaver build,
' which may not contain key handlers, can leave it out (Back then exits the settings
' screen through the OS, which is the same as Cancel).

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false
    if key = "back" then
        m.top.result = { saved: false, settings: m.working }
        return true
    end if
    return false
end function
