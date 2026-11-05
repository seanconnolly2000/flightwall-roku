' Right-hand panel: clock, location, the nearest flight as a hero card, the next
' few flights, a five-day forecast, status and warnings.

sub init()
    m.clockLabel = m.top.findNode("clockLabel")
    m.dateLabel = m.top.findNode("dateLabel")
    m.locationLabel = m.top.findNode("locationLabel")
    m.radiusLabel = m.top.findNode("radiusLabel")
    m.heroCard = m.top.findNode("heroCard")
    m.heroLogo = m.top.findNode("heroLogo")
    m.heroCallsign = m.top.findNode("heroCallsign")
    m.heroAirline = m.top.findNode("heroAirline")
    m.heroType = m.top.findNode("heroType")
    m.overheadBadge = m.top.findNode("overheadBadge")
    m.heroRoute = m.top.findNode("heroRoute")
    m.heroCities = m.top.findNode("heroCities")
    m.heroStats1 = m.top.findNode("heroStats1")
    m.heroStats2 = m.top.findNode("heroStats2")
    m.listTitle = m.top.findNode("listTitle")
    m.listGroup = m.top.findNode("listGroup")
    m.weatherTitle = m.top.findNode("weatherTitle")
    m.weatherSource = m.top.findNode("weatherSource")
    m.weatherGroup = m.top.findNode("weatherGroup")
    m.bannerBox = m.top.findNode("bannerBox")
    m.bannerLabel = m.top.findNode("bannerLabel")
    m.statusLabel = m.top.findNode("statusLabel")
    m.hintLabel = m.top.findNode("hintLabel")

    m.clockLabel.font = panelFont(true, 46)
    m.dateLabel.font = panelFont(false, 18)
    m.locationLabel.font = panelFont(false, 18)
    m.radiusLabel.font = panelFont(false, 16)
    m.heroCallsign.font = panelFont(true, 32)
    m.heroAirline.font = panelFont(false, 19)
    m.heroType.font = panelFont(false, 16)
    m.top.findNode("overheadLabel").font = panelFont(true, 15)
    m.heroRoute.font = panelFont(true, 27)
    m.heroCities.font = panelFont(false, 17)
    m.heroStats1.font = panelFont(false, 19)
    m.heroStats2.font = panelFont(false, 17)
    m.listTitle.font = panelFont(true, 14)
    m.weatherTitle.font = panelFont(true, 14)
    m.weatherSource.font = panelFont(false, 13)
    m.bannerLabel.font = panelFont(false, 16)
    m.statusLabel.font = panelFont(false, 15)
    m.hintLabel.font = panelFont(false, 15)

    m.rows = []
    rowFontMain = panelFont(true, 19)
    rowFontDetail = panelFont(false, 16)
    for i = 0 to 3
        y = i * 28
        logo = m.listGroup.createChild("Poster")
        logo.translation = [0, y + 2]
        logo.width = 20
        logo.height = 20
        logo.loadDisplayMode = "scaleToFit"
        logo.visible = false
        name = m.listGroup.createChild("Label")
        name.translation = [28, y]
        name.width = 118
        name.font = rowFontMain
        name.color = "0xE6EDF3FF"
        detail = m.listGroup.createChild("Label")
        detail.translation = [150, y + 2]
        detail.width = 370
        detail.font = rowFontDetail
        detail.color = "0x8B949EFF"
        m.rows.Push({ logo: logo, name: name, detail: detail })
    end for

    m.weatherCols = []
    dayFont = panelFont(true, 15)
    tempFont = panelFont(false, 15)
    for i = 0 to 4
        x = i * 104
        day = m.weatherGroup.createChild("Label")
        day.translation = [x, 0]
        day.width = 104
        day.horizAlign = "center"
        day.font = dayFont
        day.color = "0xE6EDF3FF"
        icon = m.weatherGroup.createChild("Poster")
        icon.translation = [x + 34, 20]
        icon.width = 36
        icon.height = 36
        temps = m.weatherGroup.createChild("Label")
        temps.translation = [x, 58]
        temps.width = 104
        temps.horizAlign = "center"
        temps.font = tempFont
        temps.color = "0x8B949EFF"
        m.weatherCols.Push({ day: day, icon: icon, temps: temps })
    end for
    m.weatherGroup.visible = false

    showEmptyHero("Waiting for flight data")
    refreshHint()
end sub

function panelFont(bold as Boolean, size as Integer) as Object
    font = CreateObject("roSGNode", "Font")
    if bold then
        font.uri = "font:BoldSystemFontFile"
    else
        font.uri = "font:SystemFontFile"
    end if
    font.size = size
    return font
end function

sub setText(label as Object, text as String)
    if label.text <> text then label.text = text
end sub

sub setUri(poster as Object, uri as String)
    if poster.uri <> uri then poster.uri = uri
end sub

sub refreshClock()
    setText(m.clockLabel, m.top.clock)
    setText(m.dateLabel, Format_Today())
end sub

sub refreshLocation()
    loc = m.top.location
    if not Util_IsAA(loc) then return
    zip = Util_Str(loc.zip)
    place = Util_Str(loc.place)
    text = ""
    if zip <> "" then text = "ZIP " + zip
    if place <> "" then
        if text <> "" then text = text + "  -  "
        text = text + place
    end if
    if text = "" then text = "Location not set"
    setText(m.locationLabel, text)
    setText(m.radiusLabel, Util_Round(Util_ToFloat(loc.radius, 50)).ToStr() + " mile radius  -  " + Util_Str(loc.provider))
end sub

sub refreshBanner()
    text = m.top.banner
    m.bannerBox.visible = text <> ""
    setText(m.bannerLabel, text)
end sub

sub refreshHint()
    setText(m.hintLabel, Format_Hint(m.top.screensaver = true))
end sub

sub refreshStatus()
    status = m.top.status
    if not Util_IsAA(status) then return
    text = "Updated " + Util_Str(status.updated) + "  -  " + Util_Str(status.count) + " aircraft"
    nextSeconds = Util_ToInt(status.nextSeconds, 0)
    if nextSeconds > 0 then text = text + "  -  next poll " + nextSeconds.ToStr() + "s"
    credits = Util_ToInt(status.credits, -1)
    if credits >= 0 then text = text + "  -  " + credits.ToStr() + " OpenSky credits left"
    if Util_Str(status.kind) <> "ok" and Util_Str(status.message) <> "" then text = Util_Str(status.message) + "  -  " + text
    setText(m.statusLabel, text)
end sub

sub refreshWeather()
    weather = m.top.weather
    show = Util_IsAA(weather) and weather.ok = true and Util_IsArray(weather.days)
    m.weatherTitle.visible = show
    m.weatherSource.visible = show
    m.weatherGroup.visible = show
    if not show then return
    days = weather.days
    for i = 0 to m.weatherCols.Count() - 1
        col = m.weatherCols[i]
        if i < days.Count() then
            day = days[i]
            setText(col.day, Weather_DayLabel(day))
            setUri(col.icon, "pkg:/images/weather/" + Util_Str(day.icon) + ".png")
            setText(col.temps, Weather_TempRange(day))
            col.day.visible = true
            col.icon.visible = true
            col.temps.visible = true
        else
            col.day.visible = false
            col.icon.visible = false
            col.temps.visible = false
        end if
    end for
end sub

sub showEmptyHero(message as String)
    m.heroLogo.visible = false
    setText(m.heroCallsign, message)
    setText(m.heroAirline, "")
    setText(m.heroType, "")
    setText(m.heroRoute, "")
    setText(m.heroCities, "")
    setText(m.heroStats1, "")
    setText(m.heroStats2, "")
    m.overheadBadge.visible = false
    m.listTitle.visible = false
    for each row in m.rows
        row.logo.visible = false
        setText(row.name, "")
        setText(row.detail, "")
    end for
end sub

sub refresh()
    aircraft = m.top.aircraft
    routes = m.top.routes
    if not Util_IsAA(routes) then routes = {}
    if not Util_IsArray(aircraft) or aircraft.Count() = 0 then
        showEmptyHero("No aircraft in range")
        return
    end if
    nearest = aircraft[0]
    route = routes[Util_Str(nearest.callsign)]
    setText(m.heroCallsign, Flights_DisplayName(nearest))
    operator = Util_Str(nearest.operatorName)
    if operator = "" and route <> invalid then operator = Util_Str(route.airlineName)
    if operator = "" then operator = "Unknown operator"
    setText(m.heroAirline, operator)
    model = Util_Str(nearest.modelName)
    if model = "" then model = Format_AircraftType(nearest)
    setText(m.heroType, model)
    logoUrl = ""
    if route <> invalid then logoUrl = Routes_LogoUrl(Util_Str(route.airlineIata))
    if logoUrl <> "" then
        setUri(m.heroLogo, logoUrl)
        m.heroLogo.visible = true
    else
        m.heroLogo.visible = false
    end if
    routeLabel = Routes_Label(route)
    cities = Routes_CityLabel(route)
    if routeLabel = "" then
        routeLabel = "Route unavailable"
        if route <> invalid and route.rejected = true then
            routeLabel = "Route unknown"
            cities = "listed leg for this flight number does not match its position"
        end if
    end if
    setText(m.heroRoute, routeLabel)
    setText(m.heroCities, cities)
    stats = Format_Altitude(Util_ToInt(nearest.altFt), nearest.ground = true)
    speed = Format_Speed(Util_ToInt(nearest.speedKts))
    if speed <> "" then stats = stats + "  -  " + speed
    if nearest.ground <> true then stats = stats + "  -  " + Format_Trend(Util_ToInt(nearest.vrate))
    setText(m.heroStats1, stats)
    stats2 = Format_Distance(Util_ToFloat(nearest.distMi)) + " " + Geo_Compass(Util_ToFloat(nearest.bearing)) + " of you"
    if Util_Str(nearest.squawk) <> "" then stats2 = stats2 + "  -  squawk " + Util_Str(nearest.squawk)
    setText(m.heroStats2, stats2)
    m.overheadBadge.visible = Flights_IsOverhead(nearest)

    m.listTitle.visible = aircraft.Count() > 1
    for i = 0 to m.rows.Count() - 1
        row = m.rows[i]
        index = i + 1
        if index < aircraft.Count() then
            ac = aircraft[index]
            acRoute = routes[Util_Str(ac.callsign)]
            setText(row.name, Flights_DisplayName(ac))
            setText(row.detail, Format_Summary(ac, acRoute))
            rowLogo = ""
            if acRoute <> invalid then rowLogo = Routes_LogoUrl(Util_Str(acRoute.airlineIata))
            if rowLogo <> "" then
                setUri(row.logo, rowLogo)
                row.logo.visible = true
            else
                row.logo.visible = false
            end if
        else
            setText(row.name, "")
            setText(row.detail, "")
            row.logo.visible = false
        end if
    end for
end sub
