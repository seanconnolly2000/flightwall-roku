' Overlay that shows the audit trail: polls, errors, settings changes.

sub init()
    m.body = m.top.findNode("body")
    title = m.top.findNode("title")
    titleFont = CreateObject("roSGNode", "Font")
    titleFont.uri = "font:BoldSystemFontFile"
    titleFont.size = 22
    title.font = titleFont
    bodyFont = CreateObject("roSGNode", "Font")
    bodyFont.uri = "font:SystemFontFile"
    bodyFont.size = 17
    m.body.font = bodyFont
    m.body.lineSpacing = 2
end sub

sub onLinesChanged()
    lines = m.top.lines
    if not Util_IsArray(lines) then
        m.body.text = ""
        return
    end if
    start = 0
    if lines.Count() > 26 then start = lines.Count() - 26
    text = ""
    for i = start to lines.Count() - 1
        if text <> "" then text = text + Chr(10)
        text = text + Util_Str(lines[i])
    end for
    if text = "" then text = "Nothing logged yet."
    m.body.text = text
end sub
