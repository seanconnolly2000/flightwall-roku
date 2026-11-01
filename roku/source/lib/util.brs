' Small type and formatting helpers that are safe in every thread.

function Util_IsString(value as Dynamic) as Boolean
    if value = invalid then return false
    return GetInterface(value, "ifString") <> invalid
end function

function Util_IsNumber(value as Dynamic) as Boolean
    if value = invalid then return false
    if GetInterface(value, "ifInt") <> invalid then return true
    if GetInterface(value, "ifFloat") <> invalid then return true
    if GetInterface(value, "ifDouble") <> invalid then return true
    if GetInterface(value, "ifLongInt") <> invalid then return true
    return false
end function

function Util_IsArray(value as Dynamic) as Boolean
    if value = invalid then return false
    return GetInterface(value, "ifArray") <> invalid
end function

function Util_IsAA(value as Dynamic) as Boolean
    if value = invalid then return false
    return GetInterface(value, "ifAssociativeArray") <> invalid
end function

' Converts numbers and numeric strings to a float; anything else yields the fallback.
function Util_ToFloat(value as Dynamic, fallback = 0.0 as Float) as Float
    if Util_IsNumber(value) then return value
    if Util_IsString(value) then
        trimmed = value.Trim()
        if trimmed = "" then return fallback
        first = Left(trimmed, 1)
        if (first < "0" or first > "9") and first <> "-" and first <> "." then return fallback
        return Val(trimmed)
    end if
    return fallback
end function

function Util_ToInt(value as Dynamic, fallback = 0 as Integer) as Integer
    return Int(Util_ToFloat(value, fallback))
end function

' Rounds to the nearest integer (halves round away from zero).
function Util_Round(value as Float) as Integer
    if value < 0 then return -Int(-value + 0.5)
    return Int(value + 0.5)
end function

' Formats a float with a fixed number of decimals, e.g. Util_FloatStr(-122.41529, 4) = "-122.4153".
function Util_FloatStr(value as Float, decimals as Integer) as String
    negative = value < 0
    if negative then value = -value
    scale = 1
    for i = 1 to decimals
        scale = scale * 10
    end for
    total = Int(value * scale + 0.5)
    whole = total \ scale
    frac = total - whole * scale
    out = whole.ToStr()
    if decimals > 0 then
        fracText = frac.ToStr()
        while Len(fracText) < decimals
            fracText = "0" + fracText
        end while
        out = out + "." + fracText
    end if
    if negative and total > 0 then out = "-" + out
    return out
end function

' Safe conversion of any scalar to text ("" for invalid).
function Util_Str(value as Dynamic) as String
    if value = invalid then return ""
    if Util_IsString(value) then return value
    if GetInterface(value, "ifInt") <> invalid then return value.ToStr()
    if Util_IsNumber(value) then return Str(value).Trim()
    if GetInterface(value, "ifBoolean") <> invalid then
        if value then return "true"
        return "false"
    end if
    return ""
end function

function Util_Min(a as Float, b as Float) as Float
    if a < b then return a
    return b
end function

function Util_Max(a as Float, b as Float) as Float
    if a > b then return a
    return b
end function

' Returns a shallow copy of an associative array.
function Util_CopyAA(source as Object) as Object
    copy = {}
    if Util_IsAA(source) then copy.Append(source)
    return copy
end function

function Util_PadLeft(text as String, width as Integer, padChar as String) as String
    out = text
    while Len(out) < width
        out = padChar + out
    end while
    return out
end function
