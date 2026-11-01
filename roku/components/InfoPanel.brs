' Right-hand panel: clock, location, the nearest flight as a hero card, the next
' few flights, status and warnings.

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
    m.bannerBox = m.top.findNode("bannerBox")
    m.bannerLabel = m.top.findNode("bannerLabel")
    m.statusLabel = m.top.findNode("statusLabel")
    m.hintLabel = m.top.findNode("hintLabel")

    m.clockLabel.font = panelFont(true, 52)
    m.dateLabel.font = panelFont(false, 20)
    m.locationLabel.font = panelFont(false, 20)
    m.radiusLabel.font = panelFont(false, 18)
    m.heroCallsign.font = panelFont(true, 36)
    m.heroAirline.font = panelFont(false, 20)
    m.heroType.font = panelFont(false, 17)
    m.top.findNode("overheadLabel").font = panelFont(true, 15)
    m.heroRoute.font = panelFont(true, 30)
    m.heroCities.font = panelFont(false, 18)
    m.heroStats1.font = panelFont(false, 20)
    m.heroStats2.font = panelFont(false, 18)
    m.listTitle.font = panelFont(true, 14)
    m.bannerLabel.font = panelFont(false, 16)
    m.statusLabel.font = panelFont(false, 15)
    m.hintLabel.font = panelFont(false, 14)

    m.rows = []
    rowFontMain = panelFont(true, 19)
    rowFontDetail = panelFont(false, 16)
    for i = 0 to 3
        y = i * 32
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

sub refreshClock()
    m.clockLabel.text = m.top.clock
    m.dateLabel.text = Format_Today()
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
    m.locationLabel.text = text
    m.radiusLabel.text = Util_Round(Util_ToFloat(loc.radius, 50)).ToStr() + " mile radius  -  " + Util_Str(loc.provider)
end sub

sub refreshBanner()
    text = m.top.banner
    m.bannerBox.visible = text <> ""
    m.bannerLabel.text = text
end sub

sub refreshHint()
    if m.top.screensaver then
        m.hintLabel.text = "FlightWall screensaver  -  press any button to exit"
    else
        m.hintLabel.text = "* or OK: settings    Play: activity log    Up/Down: radius"
    end if
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
    m.statusLabel.text = text
end sub

sub showEmptyHero(message as String)
    m.heroLogo.uri = ""
    m.heroLogo.visible = false
    m.heroCallsign.text = message
    m.heroAirline.text = ""
    m.heroType.text = ""
    m.heroRoute.text = ""
    m.heroCities.text = ""
    m.heroStats1.text = ""
    m.heroStats2.text = ""
    m.overheadBadge.visible = false
    m.listTitle.visible = false
    for each row in m.rows
        row.logo.visible = false
        row.name.text = ""
        row.detail.text = ""
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
    m.heroCallsign.text = Flights_DisplayName(nearest)
    airline = ""
    if route <> invalid then airline = Util_Str(route.airlineName)
    if airline = "" then airline = "Unknown operator"
    m.heroAirline.text = airline
    m.heroType.text = Format_AircraftType(nearest)
    logoUrl = ""
    if route <> invalid and route.found then logoUrl = Routes_LogoUrl(route.airlineIata)
    if logoUrl <> "" then
        if m.heroLogo.uri <> logoUrl then m.heroLogo.uri = logoUrl
        m.heroLogo.visible = true
    else
        m.heroLogo.visible = false
    end if
    routeLabel = Routes_Label(route)
    if routeLabel = "" then routeLabel = "Route unavailable"
    m.heroRoute.text = routeLabel
    m.heroCities.text = Routes_CityLabel(route)
    stats = Format_Altitude(Util_ToInt(nearest.altFt), nearest.ground = true)
    speed = Format_Speed(Util_ToInt(nearest.speedKts))
    if speed <> "" then stats = stats + "  -  " + speed
    if nearest.ground <> true then stats = stats + "  -  " + Format_Trend(Util_ToInt(nearest.vrate))
    m.heroStats1.text = stats
    stats2 = Format_Distance(Util_ToFloat(nearest.distMi)) + " " + Geo_Compass(Util_ToFloat(nearest.bearing)) + " of you"
    if Util_Str(nearest.squawk) <> "" then stats2 = stats2 + "  -  squawk " + Util_Str(nearest.squawk)
    m.heroStats2.text = stats2
    m.overheadBadge.visible = Flights_IsOverhead(nearest)

    m.listTitle.visible = aircraft.Count() > 1
    for i = 0 to m.rows.Count() - 1
        row = m.rows[i]
        index = i + 1
        if index < aircraft.Count() then
            ac = aircraft[index]
            acRoute = routes[Util_Str(ac.callsign)]
            row.name.text = Flights_DisplayName(ac)
            row.detail.text = Format_Summary(ac, acRoute)
            rowLogo = ""
            if acRoute <> invalid and acRoute.found then rowLogo = Routes_LogoUrl(acRoute.airlineIata)
            if rowLogo <> "" then
                if row.logo.uri <> rowLogo then row.logo.uri = rowLogo
                row.logo.visible = true
            else
                row.logo.visible = false
            end if
        else
            row.name.text = ""
            row.detail.text = ""
            row.logo.visible = false
        end if
    end for
end sub
