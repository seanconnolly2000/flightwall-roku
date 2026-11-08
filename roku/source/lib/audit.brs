' Audit trail: who (this device), what (API calls, settings changes), when.
' Kept in its own registry section, separate from application settings.

function Audit_Section() as String
    return "skytraffic_audit"
end function

function Audit_Max() as Integer
    return 40
end function

function Audit_Load() as Object
    section = CreateObject("roRegistrySection", Audit_Section())
    if section.Exists("entries") then
        parsed = ParseJson(section.Read("entries"))
        if Util_IsArray(parsed) then return parsed
    end if
    return []
end function

sub Audit_Save(entries as Object)
    section = CreateObject("roRegistrySection", Audit_Section())
    section.Write("entries", FormatJson(entries))
    section.Flush()
end sub

' Appends in place and trims the oldest entries beyond the cap.
function Audit_Append(entries as Object, entry as String) as Object
    entries.Push(entry)
    while entries.Count() > Audit_Max()
        entries.Shift()
    end while
    return entries
end function

function Audit_Entry(timestamp as String, event as String, detail as String) as String
    out = timestamp + "  " + event
    if detail <> "" then out = out + "  " + detail
    return out
end function

function Audit_Now(event as String, detail as String) as String
    return Audit_Entry(Format_Now(true), event, detail)
end function
