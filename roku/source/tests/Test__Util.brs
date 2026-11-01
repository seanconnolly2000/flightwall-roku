' On-device tests for source/lib/util.brs (Roku Unit Testing Framework).

' @Test
sub Test_Util_FloatStr()
    UTF_assertEqual(Util_FloatStr(-122.41529, 4), "-122.4153")
    UTF_assertEqual(Util_FloatStr(37.5, 0), "38")
    UTF_assertEqual(Util_FloatStr(0.05, 1), "0.1")
    UTF_assertEqual(Util_FloatStr(-0.001, 2), "0.00")
    UTF_assertEqual(Util_FloatStr(5.0, 2), "5.00")
end sub

' @Test
sub Test_Util_ToFloatAndToInt()
    UTF_assertEqual(Util_ToFloat("12.5"), 12.5)
    UTF_assertEqual(Util_ToFloat("ground", 7), 7.0)
    UTF_assertEqual(Util_ToFloat(invalid, 3), 3.0)
    UTF_assertEqual(Util_ToFloat(4), 4.0)
    UTF_assertEqual(Util_ToInt(9.9), 9)
    UTF_assertEqual(Util_ToInt("", 4), 4)
    UTF_assertEqual(Util_ToInt("-3"), -3)
end sub

' @Test
sub Test_Util_Str()
    UTF_assertEqual(Util_Str(5), "5")
    UTF_assertEqual(Util_Str(invalid), "")
    UTF_assertEqual(Util_Str(true), "true")
    UTF_assertEqual(Util_Str("x"), "x")
    UTF_assertEqual(Util_Str(1.5), "1.5")
end sub

' @Test
sub Test_Util_Round()
    UTF_assertEqual(Util_Round(2.5), 3)
    UTF_assertEqual(Util_Round(-2.5), -3)
    UTF_assertEqual(Util_Round(2.4), 2)
    UTF_assertEqual(Util_Round(0.0), 0)
end sub

' @Test
sub Test_Util_TypeChecks()
    UTF_assertTrue(Util_IsString("a"))
    UTF_assertFalse(Util_IsString(1))
    UTF_assertTrue(Util_IsNumber(1))
    UTF_assertTrue(Util_IsNumber(1.5))
    UTF_assertFalse(Util_IsNumber("1"))
    UTF_assertFalse(Util_IsNumber(invalid))
    UTF_assertTrue(Util_IsArray([]))
    UTF_assertFalse(Util_IsArray({}))
    UTF_assertTrue(Util_IsAA({}))
    UTF_assertFalse(Util_IsAA(invalid))
end sub

' @Test
sub Test_Util_PadAndCopy()
    UTF_assertEqual(Util_PadLeft("7", 3, "0"), "007")
    UTF_assertEqual(Util_PadLeft("1234", 3, "0"), "1234")
    copy = Util_CopyAA({ a: 1 })
    copy.a = 2
    UTF_assertEqual(copy.a, 2)
    UTF_assertEqual(Util_CopyAA(invalid).Count(), 0)
end sub
