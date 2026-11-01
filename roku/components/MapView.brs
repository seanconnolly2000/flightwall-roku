' The round map: pre-rendered land/water tiles, airports, city labels, aircraft,
' breadcrumb trails and a line pointing back toward where each flight came from.

sub init()
    m.root = m.top.findNode("root")
    m.tileLayer = m.top.findNode("tileLayer")
    m.cityLayer = m.top.findNode("cityLayer")
    m.airportLayer = m.top.findNode("airportLayer")
    m.trailLayer = m.top.findNode("trailLayer")
    m.lineLayer = m.top.findNode("lineLayer")
    m.planeLayer = m.top.findNode("planeLayer")
    m.radiusLabel = m.top.findNode("radiusLabel")
    m.radiusLabel.font = makeFont(false, 16)
    m.radiusPx = 340.0
    m.halfSizePx = 350.0
    m.root.clippingRect = [-m.halfSizePx, -m.halfSizePx, 2 * m.halfSizePx, 2 * m.halfSizePx]
    m.proj = invalid
    m.planes = {}
    m.trails = {}
    m.lines = {}
    m.options = { cityLabels: true, planeLabels: true, trails: true }
    m.fontLabel = makeFont(true, 16)
    m.fontSmall = makeFont(false, 14)
    m.fontCity = makeFont(false, 15)
    m.waterColor = "0x0A1A3AFF"
    m.landColor = "0x000000FF"
end sub

function makeFont(bold as Boolean, size as Integer) as Object
    font = CreateObject("roSGNode", "Font")
    if bold then
        font.uri = "font:BoldSystemFontFile"
    else
        font.uri = "font:SystemFontFile"
    end if
    font.size = size
    return font
end function

sub clearLayer(layer as Object)
    count = layer.getChildCount()
    if count > 0 then layer.removeChildrenIndex(count, 0)
end sub

sub onOptionsChanged()
    opts = m.top.options
    if Util_IsAA(opts) then
        showCities = (opts.cityLabels = true)
        showLabels = (opts.planeLabels = true)
        showTrails = (opts.trails = true)
        m.options = { cityLabels: showCities, planeLabels: showLabels, trails: showTrails }
    end if
    rebuildStatic()
    onAircraftChanged()
end sub

sub onCenterChanged()
    center = m.top.center
    if not Util_IsAA(center) then return
    radiusMiles = Util_ToFloat(center.radiusMiles, 50)
    m.proj = Geo_Projection(Util_ToFloat(center.lat), Util_ToFloat(center.lon), radiusMiles, m.radiusPx)
    m.planes = {}
    m.trails = {}
    m.lines = {}
    clearLayer(m.planeLayer)
    clearLayer(m.trailLayer)
    clearLayer(m.lineLayer)
    m.radiusLabel.text = Util_Round(radiusMiles).ToStr() + " mile radius"
    rebuildStatic()
    onAircraftChanged()
end sub

sub rebuildStatic()
    if m.proj = invalid then return
    clearLayer(m.tileLayer)
    clearLayer(m.airportLayer)
    clearLayer(m.cityLayer)
    drawTiles()
    drawAirports()
    drawCities()
end sub

sub drawTiles()
    index = m.top.tiles
    if not Util_IsAA(index) then return
    kinds = index.tiles
    if not Util_IsAA(kinds) then return
    tiles = Geo_TilesInView(m.proj, m.halfSizePx)
    for each tile in tiles
        kind = kinds[tile.key]
        if kind = "c" then
            poster = m.tileLayer.createChild("Poster")
            poster.uri = "pkg:/images/tiles/t_" + tile.key + ".png"
            poster.translation = [tile.x, tile.y]
            poster.width = tile.w + 1
            poster.height = tile.h + 1
            ' Decode at most 448 px per side: texture memory is a 100 MB pool shared with
            ' the Roku home screen, and the source tiles are only 512 px anyway.
            poster.loadWidth = Util_Min(tile.w + 1, 448)
            poster.loadHeight = Util_Min(tile.h + 1, 448)
            poster.loadDisplayMode = "scaleToFill"
            poster.observeField("loadStatus", "onTileLoadStatus")
        else if kind = "w" then
            rect = m.tileLayer.createChild("Rectangle")
            rect.color = m.waterColor
            rect.translation = [tile.x, tile.y]
            rect.width = tile.w + 1
            rect.height = tile.h + 1
        end if
    end for
end sub

' A tile that fails to load almost always means the device ran out of texture memory.
sub onTileLoadStatus(event as Object)
    if event.getData() = "failed" then
        m.top.warning = "map tile failed to load (texture memory low)"
    end if
end sub

function insideMap(pt as Object, margin as Float) as Boolean
    limit = m.halfSizePx - margin
    return Abs(pt.x) <= limit and Abs(pt.y) <= limit
end function

sub drawAirports()
    airports = m.top.airports
    if not Util_IsArray(airports) then return
    radiusMiles = m.proj.radiusMiles
    showMedium = radiusMiles <= 75
    labelMedium = radiusMiles <= 40
    for each airport in airports
        isLarge = (airport.s = "L")
        if isLarge or showMedium then
            pt = Geo_Project(m.proj, Util_ToFloat(airport.lat), Util_ToFloat(airport.lon))
            if insideMap(pt, 4) then
                size = 8
                if isLarge then size = 12
                icon = m.airportLayer.createChild("Poster")
                icon.uri = "pkg:/images/airport.png"
                icon.width = size
                icon.height = size
                icon.translation = [pt.x - size / 2, pt.y - size / 2]
                icon.blendColor = "0x8B949EFF"
                if isLarge or labelMedium then
                    label = m.airportLayer.createChild("Label")
                    label.text = Util_Str(airport.c)
                    label.font = m.fontSmall
                    label.color = "0x8B949EFF"
                    label.translation = [pt.x + size / 2 + 3, pt.y - 9]
                end if
            end if
        end if
    end for
end sub

sub drawCities()
    if not m.options.cityLabels then return
    cities = m.top.cities
    if not Util_IsArray(cities) then return
    placed = []
    for each city in cities
        if placed.Count() < 14 then
            pt = Geo_Project(m.proj, Util_ToFloat(city.lat), Util_ToFloat(city.lon))
            if insideMap(pt, 30) and not nearAny(pt, placed, 70) then
                dot = m.cityLayer.createChild("Poster")
                dot.uri = "pkg:/images/dot.png"
                dot.width = 6
                dot.height = 6
                dot.translation = [pt.x - 3, pt.y - 3]
                dot.blendColor = "0x5C6672FF"
                label = m.cityLayer.createChild("Label")
                label.text = Util_Str(city.n)
                label.font = m.fontCity
                label.color = "0x5C6672FF"
                label.translation = [pt.x + 6, pt.y - 10]
                placed.Push(pt)
            end if
        end if
    end for
end sub

function nearAny(pt as Object, points as Object, distance as Float) as Boolean
    for each other in points
        if Abs(other.x - pt.x) < distance * 2 and Abs(other.y - pt.y) < distance / 2 then return true
    end for
    return false
end function

sub onAircraftChanged()
    if m.proj = invalid then return
    list = m.top.aircraft
    if not Util_IsArray(list) then list = []
    routes = m.top.routes
    if not Util_IsAA(routes) then routes = {}
    seen = {}
    for each ac in list
        hex = Util_Str(ac.hex)
        if hex = "" then hex = Util_Str(ac.callsign)
        if hex <> "" then
            seen[hex] = true
            pt = Geo_Project(m.proj, Util_ToFloat(ac.lat), Util_ToFloat(ac.lon))
            route = routes[Util_Str(ac.callsign)]
            plane = m.planes[hex]
            if plane = invalid then
                plane = createPlane()
                m.planes[hex] = plane
            end if
            updatePlane(plane, ac, pt, route)
            updateTrail(hex, pt)
            updateLine(hex, ac, pt, route)
        end if
    end for
    for each hex in m.planes.Keys()
        if not seen.DoesExist(hex) then removePlane(hex)
    end for
end sub

function createPlane() as Object
    group = m.planeLayer.createChild("Group")
    icon = group.createChild("Poster")
    icon.width = 32
    icon.height = 32
    icon.translation = [-16, -16]
    logo = group.createChild("Poster")
    logo.width = 18
    logo.height = 18
    logo.translation = [-50, 17]
    logo.visible = false
    label = group.createChild("Label")
    label.translation = [-28, 16]
    label.font = m.fontLabel
    label.color = "0xE6EDF3FF"
    route = group.createChild("Label")
    route.translation = [-28, 34]
    route.font = m.fontSmall
    route.color = "0x8B949EFF"
    return { group: group, icon: icon, logo: logo, label: label, route: route, color: "" }
end function

' Only touch node fields when the value changed: every field write schedules a re-render.
sub setUri(poster as Object, uri as String)
    if poster.uri <> uri then poster.uri = uri
end sub

sub setText(label as Object, text as String)
    if label.text <> text then label.text = text
end sub

sub updatePlane(plane as Object, ac as Object, pt as Object, route as Object)
    plane.group.translation = [pt.x, pt.y]
    setUri(plane.icon, "pkg:/images/planes/" + Flights_SpriteName(Util_ToFloat(ac.track, -1)) + ".png")
    ' Color fields read back as integers, so remember the last string we set instead of comparing.
    color = Flights_AltitudeColor(Util_ToInt(ac.altFt), ac.ground = true)
    if plane.color <> color then
        plane.icon.blendColor = color
        plane.color = color
    end if
    showLabels = m.options.planeLabels
    plane.label.visible = showLabels
    if showLabels then
        setText(plane.label, Flights_DisplayName(ac))
        routeText = Routes_Label(route)
        setText(plane.route, routeText)
        plane.route.visible = routeText <> ""
        logoUrl = ""
        if route <> invalid then logoUrl = Routes_LogoUrl(Util_Str(route.airlineIata))
        if logoUrl <> "" then
            setUri(plane.logo, logoUrl)
            plane.logo.visible = true
        else
            plane.logo.visible = false
        end if
    else
        plane.route.visible = false
        plane.logo.visible = false
    end if
end sub

' Breadcrumb trail: one dot is added per poll at the previous position; nothing is rebuilt.
sub updateTrail(hex as String, pt as Object)
    if not m.options.trails then
        if m.trails.DoesExist(hex) then
            m.trailLayer.removeChild(m.trails[hex].group)
            m.trails.Delete(hex)
        end if
        return
    end if
    trail = m.trails[hex]
    if trail = invalid then
        trail = { group: m.trailLayer.createChild("Group"), dots: [], last: invalid }
        m.trails[hex] = trail
    end if
    last = trail.last
    if last <> invalid then
        if Abs(last.x - pt.x) <= 2 and Abs(last.y - pt.y) <= 2 then return
        dot = trail.group.createChild("Poster")
        dot.uri = "pkg:/images/trail.png"
        dot.width = 4
        dot.height = 4
        dot.translation = [last.x - 2, last.y - 2]
        dot.blendColor = "0x9CDCFEFF"
        trail.dots.Push(dot)
        while trail.dots.Count() > 6
            trail.group.removeChild(trail.dots[0])
            trail.dots.Shift()
        end while
        count = trail.dots.Count()
        for i = 0 to count - 1
            trail.dots[i].opacity = 0.15 + 0.6 * (i + 1) / count
        end for
    end if
    trail.last = { x: pt.x, y: pt.y }
end sub

' A faint line from the aircraft back toward its origin airport (or, when the
' route is unknown, back along its track) so you can see where it came from.
sub updateLine(hex as String, ac as Object, pt as Object, route as Object)
    line = m.lines[hex]
    if line = invalid then
        line = m.lineLayer.createChild("Poster")
        line.uri = "pkg:/images/line.png"
        line.height = 2
        line.scaleRotateCenter = [0, 1]
        line.opacity = 0.5
        line.blendColor = "0x58A6FFFF"
        m.lines[hex] = line
    end if
    dx = 0.0
    dy = 0.0
    length = 0.0
    if ac.ground = true then
        length = 0.0
    else if Routes_HasOrigin(route) then
        originPt = Geo_Project(m.proj, route.originLat, route.originLon)
        dx = originPt.x - pt.x
        dy = originPt.y - pt.y
        length = Sqr(dx * dx + dy * dy)
        line.opacity = 0.5
    else if m.options.trails and Util_ToFloat(ac.track, -1) >= 0 then
        rad = Geo_Rad(Util_ToFloat(ac.track, 0))
        dx = -Sin(rad)
        dy = Cos(rad)
        length = 40
        line.opacity = 0.25
    end if
    if length < 4 then
        line.visible = false
        return
    end if
    length = Util_Min(length, lengthToCircleEdge(pt, dx, dy))
    if length < 4 then
        line.visible = false
        return
    end if
    line.visible = true
    line.translation = [pt.x, pt.y]
    line.width = length
    line.rotation = -Geo_Atan2(dy, dx)
end sub

' Longest line from pt in direction (dx, dy) that stays inside the map circle.
function lengthToCircleEdge(pt as Object, dx as Float, dy as Float) as Float
    size = Sqr(dx * dx + dy * dy)
    if size = 0 then return 0.0
    ux = dx / size
    uy = dy / size
    along = pt.x * ux + pt.y * uy
    outside = pt.x * pt.x + pt.y * pt.y - m.radiusPx * m.radiusPx
    discriminant = along * along - outside
    if discriminant < 0 then return 0.0
    reach = -along + Sqr(discriminant)
    if reach < 0 then return 0.0
    return reach
end function

sub removePlane(hex as String)
    plane = m.planes[hex]
    if plane <> invalid then
        m.planeLayer.removeChild(plane.group)
        m.planes.Delete(hex)
    end if
    if m.trails.DoesExist(hex) then
        m.trailLayer.removeChild(m.trails[hex].group)
        m.trails.Delete(hex)
    end if
    if m.lines.DoesExist(hex) then
        m.lineLayer.removeChild(m.lines[hex])
        m.lines.Delete(hex)
    end if
end sub
