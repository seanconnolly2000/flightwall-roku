' On-device tests for source/lib/audit.brs (never writes the real audit section).

' @Test
sub Test_Audit_AppendTrims()
    entries = []
    for i = 1 to 45
        Audit_Append(entries, i.ToStr())
    end for
    UTF_assertEqual(entries.Count(), Audit_Max())
    UTF_assertEqual(entries[0], "6")
    UTF_assertEqual(entries[entries.Count() - 1], "45")
end sub

' @Test
sub Test_Audit_EntryFormat()
    UTF_assertEqual(Audit_Entry("12:00:00 PM", "poll", "ok"), "12:00:00 PM  poll  ok")
    UTF_assertEqual(Audit_Entry("12:00:00 PM", "start", ""), "12:00:00 PM  start")
    now = Audit_Now("poll", "detail")
    UTF_assertTrue(now.Instr("  poll  detail") > 0, now)
end sub

' @Test
sub Test_Audit_LoadReturnsArray()
    entries = Audit_Load()
    UTF_assertTrue(Util_IsArray(entries))
end sub
