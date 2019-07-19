//Mario Artist Paint Studio - Debug Print output by LuigiBlood

console.log("- Paint Studio - Debug Printf");
var lastone = "";
var currentone = "";
var start = 0;
var size = 0;

events.onexec(0x800D8CEC, function(addr)
{
    currentone = mem.getstring(gpr.a1, gpr.a2);
    if (lastone != currentone)
    {
        console.log(currentone);
    }

    lastone = currentone;
});
