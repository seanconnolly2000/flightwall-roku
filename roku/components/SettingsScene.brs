' Stand-alone settings screen used by "Change screensaver settings".
' Saves to the same registry the channel and screensaver read.

sub init()
    m.top.backgroundColor = "0x000000FF"
    m.panel = m.top.findNode("settingsPanel")
    m.panel.observeField("result", "onResult")
    m.lookupTask = CreateObject("roSGNode", "LookupTask")
    m.lookupTask.observeField("result", "onLookupResult")
    m.audit = Audit_Load()
    m.panel.message = "FlightWall screensaver settings. Choose Save and apply when done."
    m.panel.focusRow = "zip"
    m.panel.settings = Settings_Load()
    m.panel.setFocus(true)
end sub

sub onResult()
    result = m.panel.result
    if not Util_IsAA(result) then return
    if result.saved <> true then
        m.top.exitRequested = true
        return
    end if
    previous = Settings_Load()
    settings = Settings_Defaults()
    settings.Append(result.settings)
    if Util_Str(previous.zip) <> Util_Str(settings.zip) then
        settings.lat = ""
        settings.lon = ""
        settings.place = ""
    end if
    Settings_Save(settings)
    Audit_Append(m.audit, Audit_Now("settings", "saved from screensaver settings: zip=" + Util_Str(settings.zip) + " radius=" + Util_Str(settings.radius) + " source=" + Util_Str(settings.provider)))
    Audit_Save(m.audit)
    if not Settings_IsConfigured(settings) then
        m.panel.message = "Looking up ZIP " + Util_Str(settings.zip) + "..."
        m.lookupTask.zip = Util_Str(settings.zip)
        m.lookupTask.control = "RUN"
        return
    end if
    m.top.exitRequested = true
end sub

sub onLookupResult()
    result = m.lookupTask.result
    if not Util_IsAA(result) then return
    settings = Settings_Load()
    if result.ok then
        settings.lat = Util_FloatStr(result.lat, 5)
        settings.lon = Util_FloatStr(result.lon, 5)
        settings.place = Util_Str(result.place)
        Settings_Save(settings)
        m.top.exitRequested = true
        return
    end if
    m.panel.message = Util_Str(result.message) + ". Please check the ZIP code."
    m.panel.focusRow = "zip"
    m.panel.settings = settings
    m.panel.setFocus(true)
end sub
