' User settings: defaults, validation, option lists and registry persistence.
' Every value is stored as a string because roRegistrySection only stores strings.

function Settings_Section() as String
    return "flightwall"
end function

function Settings_Defaults() as Object
    return {
        zip: ""
        lat: ""
        lon: ""
        place: ""
        radius: "50"
        provider: "adsblol"
        pollSeconds: "10"
        openskyClientId: ""
        openskyClientSecret: ""
        routes: "1"
        cityLabels: "1"
        planeLabels: "1"
        trails: "1"
        hideGround: "1"
    }
end function

function Settings_Load() as Object
    settings = Settings_Defaults()
    section = CreateObject("roRegistrySection", Settings_Section())
    for each key in settings
        if section.Exists(key) then settings[key] = section.Read(key)
    end for
    return settings
end function

sub Settings_Save(settings as Object)
    section = CreateObject("roRegistrySection", Settings_Section())
    for each key in Settings_Defaults()
        if settings.DoesExist(key) then section.Write(key, Util_Str(settings[key]))
    end for
    section.Flush()
end sub

function Settings_RadiusOptions() as Object
    return [10, 25, 50, 75, 100, 150, 200, 250]
end function

function Settings_PollOptions() as Object
    return [10, 15, 20, 30, 60]
end function

function Settings_Providers() as Object
    return [
        { id: "adsblol", name: "adsb.lol (free, no key)" }
        { id: "adsbfi", name: "adsb.fi (free, no key)" }
        { id: "opensky", name: "OpenSky Network" }
    ]
end function

function Settings_ProviderName(id as String) as String
    for each provider in Settings_Providers()
        if provider.id = id then return provider.name
    end for
    return id
end function

' Steps through a list of options; delta is +1 or -1 and wraps around.
function Settings_NextValue(options as Object, current as String, delta as Integer) as String
    count = options.Count()
    if count = 0 then return current
    index = -1
    for i = 0 to count - 1
        if Util_Str(options[i]) = current then index = i
    end for
    index = index + delta
    if index < 0 then index = count - 1
    if index >= count then index = 0
    return Util_Str(options[index])
end function

function Settings_NextProvider(current as String, delta as Integer) as String
    ids = []
    for each provider in Settings_Providers()
        ids.Push(provider.id)
    end for
    return Settings_NextValue(ids, current, delta)
end function

function Settings_IsZipValid(zip as String) as Boolean
    if Len(zip) <> 5 then return false
    for i = 1 to 5
        ch = Mid(zip, i, 1)
        if ch < "0" or ch > "9" then return false
    end for
    return true
end function

function Settings_IsConfigured(settings as Object) as Boolean
    return Util_Str(settings.lat) <> "" and Util_Str(settings.lon) <> ""
end function

function Settings_HasCredentials(settings as Object) as Boolean
    return Util_Str(settings.openskyClientId) <> "" and Util_Str(settings.openskyClientSecret) <> ""
end function

function Settings_Radius(settings as Object) as Float
    value = Util_ToFloat(settings.radius, 50)
    if value < 5 then value = 5
    if value > 250 then value = 250
    return value
end function

function Settings_PollSeconds(settings as Object) as Integer
    value = Util_ToInt(settings.pollSeconds, 10)
    if value < 5 then value = 5
    if value > 600 then value = 600
    return value
end function

function Settings_Flag(settings as Object, key as String) as Boolean
    return Util_Str(settings[key]) = "1"
end function

function Settings_Toggle(value as String) as String
    if value = "1" then return "0"
    return "1"
end function

function Settings_OnOff(value as String) as String
    if value = "1" then return "on"
    return "off"
end function
