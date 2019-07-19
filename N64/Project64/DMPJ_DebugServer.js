//Mario Artist Paint Studio - Debug Print output by LuigiBlood
//This version uses this Node Package: https://github.com/MNGoldenEagle/DebugConsole

var debugServer = new Server({port:411});
var socket = null;

debugServer.on('connection', function(newSocket) {
	socket = newSocket;
	
	newSocket.on('close', function() {
		socket = null;
	});
});

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
        socket.write(currentone);
        socket.write('\n');
    }

    lastone = currentone;
});
