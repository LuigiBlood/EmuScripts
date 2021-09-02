events.onexec(0x8001DD90, function() {
	console.print("\r\n");
});

events.onexec(0x8001DD98, function() {
	//String
	var curstring = mem.getstring(gpr.a1, 256);
	console.print(curstring);
});

events.onexec(0x8001DDA4, function() {
	//Decimal
	console.print(" " + gpr.a1);
});

events.onexec(0x8001DDBC, function() {
	//Float
	console.print(" " + HexToFloat32(gpr.a1).toString());
});

events.onexec(0x8001DDD8, function() {
	//Hex
	var str = gpr.a1.hex();
	if (gpr.a1 < 0x100)
		str = gpr.a1.hex()[6] + gpr.a1.hex()[7];
	console.print(" " + str);
});

function HexToFloat32(val) {
    if (val > 0 || val < 0) {
        var sign = (val >>> 31) ? -1 : 1;
        var exp = (val >>> 23 & 0xff) - 127;
        var mantissa = ((val & 0x7fffff) + 0x800000).toString(2);
        var float32 = 0
        for (i = 0; i < mantissa.length; i += 1) { float32 += parseInt(mantissa[i]) ? Math.pow(2, exp) : 0; exp-- }
        return float32 * sign;
    } else return 0
}
