' Main-thread helpers shared by the channel, screensaver and screensaver-settings entry points.

' Builds the scene's launch parameters from the OS launch args.
function FlightWall_LaunchParams(args as Object, screensaver as Boolean) as Object
    params = { screensaver: screensaver, zip: "", radius: "", poll: "" }
    if Util_IsAA(args) then
        if Util_IsString(args.zip) then params.zip = args.zip
        if Util_IsString(args.radius) then params.radius = args.radius
        if Util_IsString(args.poll) then params.poll = args.poll
    end if
    return params
end function

' Shows a scene and runs the main event loop until the scene asks to exit or the
' OS closes the screen. Also subscribes to the OS memory monitors and forwards
' snapshots to the scene's memoryStatus field (once a minute and on every warning).
sub FlightWall_ShowScene(sceneName as String, params as Object)
    screen = CreateObject("roSGScreen")
    port = CreateObject("roMessagePort")
    screen.SetMessagePort(port)
    scene = screen.CreateScene(sceneName)
    screen.Show()
    scene.observeField("exitRequested", port)
    scene.launchParams = params
    memory = FlightWall_StartMemoryMonitor(port)
    scene.memoryStatus = FlightWall_MemorySnapshot(memory, "start")
    closeScreen = false
    while true
        msg = wait(60000, port)
        if msg = invalid then
            scene.memoryStatus = FlightWall_MemorySnapshot(memory, "periodic")
        else
            msgType = Type(msg)
            if msgType = "roSGScreenEvent" then
                if msg.isScreenClosed() then exit while
            else if msgType = "roSGNodeEvent" then
                if msg.getField() = "exitRequested" and msg.getData() = true then
                    closeScreen = true
                    exit while
                end if
            else if msgType = "roAppMemoryNotificationEvent" then
                scene.memoryStatus = FlightWall_MemorySnapshot(memory, "warning")
            else if msgType = "roDeviceInfoEvent" then
                info = msg.GetInfo()
                if Util_IsAA(info) and info.generalMemoryLevel <> invalid then
                    scene.memoryStatus = FlightWall_MemorySnapshot(memory, "general memory " + Util_Str(info.generalMemoryLevel))
                end if
            end if
        end if
    end while
    if closeScreen then screen.Close()
end sub

' Subscribes to per-app memory warnings (roAppMemoryMonitor) and device-wide low-memory
' events (roDeviceInfo). Methods are probed so older OS versions still run.
function FlightWall_StartMemoryMonitor(port as Object) as Object
    state = { monitor: invalid, deviceInfo: invalid }
    monitor = CreateObject("roAppMemoryMonitor")
    if monitor <> invalid then
        monitor.SetMessagePort(port)
        if FindMemberFunction(monitor, "EnableMemoryWarningEvent") <> invalid then monitor.EnableMemoryWarningEvent(true)
        state.monitor = monitor
    end if
    deviceInfo = CreateObject("roDeviceInfo")
    if deviceInfo <> invalid then
        deviceInfo.SetMessagePort(port)
        if FindMemberFunction(deviceInfo, "EnableLowGeneralMemoryEvent") <> invalid then deviceInfo.EnableLowGeneralMemoryEvent(true)
        state.deviceInfo = deviceInfo
    end if
    return state
end function

' {reason, percent (of the per-app limit), availableKb, limit}; -1 / invalid when unknown.
' GetChannelMemoryLimit (OS 13+) returns an associative array, kept as-is for the log.
function FlightWall_MemorySnapshot(state as Object, reason as String) as Object
    snapshot = { reason: reason, percent: -1, availableKb: -1, limit: invalid }
    monitor = state.monitor
    if monitor <> invalid then
        if FindMemberFunction(monitor, "GetMemoryLimitPercent") <> invalid then snapshot.percent = monitor.GetMemoryLimitPercent()
        if FindMemberFunction(monitor, "GetChannelAvailableMemory") <> invalid then snapshot.availableKb = monitor.GetChannelAvailableMemory()
        if FindMemberFunction(monitor, "GetChannelMemoryLimit") <> invalid then snapshot.limit = monitor.GetChannelMemoryLimit()
    end if
    return snapshot
end function
