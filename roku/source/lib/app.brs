' Main-thread helpers shared by the channel, screensaver and screensaver-settings entry points.

' Builds the scene's launch parameters from the OS launch args.
function FlightWall_LaunchParams(args as Object, screensaver as Boolean) as Object
    params = { screensaver: screensaver, zip: "", radius: "" }
    if Util_IsAA(args) then
        if Util_IsString(args.zip) then params.zip = args.zip
        if Util_IsString(args.radius) then params.radius = args.radius
    end if
    return params
end function

sub FlightWall_ShowScene(sceneName as String, params as Object)
    screen = CreateObject("roSGScreen")
    port = CreateObject("roMessagePort")
    screen.SetMessagePort(port)
    scene = screen.CreateScene(sceneName)
    screen.Show()
    scene.observeField("exitRequested", port)
    scene.launchParams = params
    closeScreen = false
    while true
        msg = wait(0, port)
        msgType = Type(msg)
        if msgType = "roSGScreenEvent" then
            if msg.isScreenClosed() then exit while
        else if msgType = "roSGNodeEvent" then
            if msg.getField() = "exitRequested" and msg.getData() = true then
                closeScreen = true
                exit while
            end if
        end if
    end while
    if closeScreen then screen.Close()
end sub
