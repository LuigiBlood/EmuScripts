var laststring = "";

events.onexec(0x8002FD48, function() {
	//A1 = string
	var curstring = mem.getstring(gpr.a0, 256);
	if (laststring != curstring)
	{
		console.log(curstring);
	}
	laststring = curstring;
});