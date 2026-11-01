' Settings editor: a list of rows; OK edits a row (text entry opens the Roku
' keyboard dialog, choices cycle), Save writes the result, Back cancels.

sub init()
    m.list = m.top.findNode("list")
    m.messageLabel = m.top.findNode("messageLabel")
    m.title = m.top.findNode("title")
    m.help = m.top.findNode("help")
    m.title.font = settingsFont(true, 28)
    m.messageLabel.font = settingsFont(false, 18)
    m.help.font = settingsFont(false, 16)
    m.list.font = settingsFont(false, 22)
    m.list.focusedFont = settingsFont(true, 22)
    m.working = Settings_Defaults()
    m.rows = []
    m.dialog = invalid
    m.dialogRow = ""
    m.list.observeField("itemSelected", "onItemSelected")
    m.top.observeField("focusedChild", "onFocusChanged")
    rebuildRows(0)
end sub

function settingsFont(bold as Boolean, size as Integer) as Object
    font = CreateObject("roSGNode", "Font")
    if bold then
        font.uri = "font:BoldSystemFontFile"
    else
        font.uri = "font:SystemFontFile"
    end if
    font.size = size
    return font
end function

sub onFocusChanged()
    if m.top.hasFocus() then m.list.setFocus(true)
end sub

sub onMessageChanged()
    m.messageLabel.text = m.top.message
end sub

sub onSettingsChanged()
    m.working = Settings_Defaults()
    m.working.Append(Util_CopyAA(m.top.settings))
    focusIndex = 0
    wanted = m.top.focusRow
    rows = buildRows()
    for i = 0 to rows.Count() - 1
        if rows[i].key = wanted then focusIndex = i
    end for
    rebuildRows(focusIndex)
end sub

function valueOrNotSet(value as String) as String
    if value = "" then return "not set"
    return value
end function

function buildRows() as Object
    s = m.working
    secretState = "not set"
    if Util_Str(s.openskyClientSecret) <> "" then secretState = "set"
    return [
        { key: "zip", label: "ZIP code", value: valueOrNotSet(Util_Str(s.zip)) }
        { key: "radius", label: "Radius", value: Util_Str(s.radius) + " miles" }
        { key: "provider", label: "Data source", value: Settings_ProviderName(Util_Str(s.provider)) }
        { key: "openskyClientId", label: "OpenSky client ID (optional, raises the free limit)", value: valueOrNotSet(Util_Str(s.openskyClientId)) }
        { key: "openskyClientSecret", label: "OpenSky client secret", value: secretState }
        { key: "pollSeconds", label: "Poll every", value: Util_Str(s.pollSeconds) + " seconds" }
        { key: "routes", label: "Route and airline lookups (adsbdb.com)", value: Settings_OnOff(Util_Str(s.routes)) }
        { key: "cityLabels", label: "City labels", value: Settings_OnOff(Util_Str(s.cityLabels)) }
        { key: "planeLabels", label: "Flight labels and airline logos", value: Settings_OnOff(Util_Str(s.planeLabels)) }
        { key: "trails", label: "Trails and origin lines", value: Settings_OnOff(Util_Str(s.trails)) }
        { key: "hideGround", label: "Hide aircraft on the ground", value: Settings_OnOff(Util_Str(s.hideGround)) }
        { key: "save", label: "Save and apply", value: "" }
        { key: "cancel", label: "Cancel", value: "" }
    ]
end function

sub rebuildRows(focusIndex as Integer)
    m.rows = buildRows()
    content = CreateObject("roSGNode", "ContentNode")
    for each row in m.rows
        item = content.createChild("ContentNode")
        if row.value = "" then
            item.title = row.label
        else
            item.title = row.label + ":  " + row.value
        end if
    end for
    m.list.content = content
    m.list.jumpToItem = focusIndex
end sub

sub onItemSelected()
    index = m.list.itemSelected
    if index < 0 or index >= m.rows.Count() then return
    key = m.rows[index].key
    if key = "zip" then
        openTextDialog("ZIP code", "Enter the 5-digit ZIP code to centre the map on.", Util_Str(m.working.zip), "numeric", key)
    else if key = "openskyClientId" then
        openTextDialog("OpenSky client ID", "From opensky-network.org > Account > API client. Leave blank for keyless access.", Util_Str(m.working.openskyClientId), "", key)
    else if key = "openskyClientSecret" then
        openTextDialog("OpenSky client secret", "The client secret that goes with the client ID above.", Util_Str(m.working.openskyClientSecret), "", key)
    else if key = "radius" then
        m.working.radius = Settings_NextValue(Settings_RadiusOptions(), Util_Str(m.working.radius), 1)
    else if key = "pollSeconds" then
        m.working.pollSeconds = Settings_NextValue(Settings_PollOptions(), Util_Str(m.working.pollSeconds), 1)
    else if key = "provider" then
        m.working.provider = Settings_NextProvider(Util_Str(m.working.provider), 1)
    else if key = "routes" or key = "cityLabels" or key = "planeLabels" or key = "trails" or key = "hideGround" then
        m.working[key] = Settings_Toggle(Util_Str(m.working[key]))
    else if key = "save" then
        save()
        return
    else if key = "cancel" then
        m.top.result = { saved: false, settings: m.working }
        return
    end if
    rebuildRows(index)
end sub

sub save()
    if not Settings_IsZipValid(Util_Str(m.working.zip)) then
        m.top.message = "Please enter a valid 5-digit ZIP code before saving."
        rebuildRows(0)
        return
    end if
    m.top.result = { saved: true, settings: m.working }
end sub

sub openTextDialog(title as String, hint as String, initial as String, domain as String, rowKey as String)
    dialog = CreateObject("roSGNode", "StandardKeyboardDialog")
    dialog.title = title
    dialog.message = [hint]
    dialog.text = initial
    dialog.buttons = ["OK", "Cancel"]
    if domain <> "" then dialog.keyboardDomain = domain
    m.dialogRow = rowKey
    m.dialog = dialog
    dialog.observeField("buttonSelected", "onDialogButton")
    dialog.observeField("wasClosed", "onDialogClosed")
    m.top.getScene().dialog = dialog
end sub

sub onDialogButton()
    if m.dialog = invalid then return
    if m.dialog.buttonSelected = 0 then
        value = Util_Str(m.dialog.text).Trim()
        if m.dialogRow = "zip" then
            m.working.zip = value
        else if m.dialogRow = "openskyClientId" then
            m.working.openskyClientId = value
        else if m.dialogRow = "openskyClientSecret" then
            m.working.openskyClientSecret = value
        end if
    end if
    m.dialog.close = true
end sub

sub onDialogClosed()
    m.dialog = invalid
    focusIndex = 0
    for i = 0 to m.rows.Count() - 1
        if m.rows[i].key = m.dialogRow then focusIndex = i
    end for
    rebuildRows(focusIndex)
    m.list.setFocus(true)
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false
    if key = "back" then
        m.top.result = { saved: false, settings: m.working }
        return true
    end if
    return false
end function
