//PIFForward Module

const VERSION = "1.0"
var INIT = false;
var callbackPifId = 0;
var ARRAY = new Array();
var VERBOSE = 0;

function init()
{
	callbackPifId = events.onpifread(PIFRead);
	INIT = true;
	console.log("PIFForward Module Initialized (v" + VERSION + ")");
}

function verbose(set)
{
	if (INIT == false) return;

	VERBOSE = set;
	LogVerbose(1, "Set Verbose to " + VERBOSE);
}

//func will be called like this func(sent, recv)
// sent = Buffer of every byte sent (including command)
// recv = Buffer of every byte to recv (should be written to)
//Returns:
// >0 = Normal
// -1 = Error (0x40)
// <-2 = Error (0x80)
function set(id, func)
{
	if (INIT == false) return;

	if (typeof ARRAY[id] === "function")
	{
		LogVerbose(1, "PIF Channel " + id +  " is already set up.");
		return -1;
	}
	else if (id >= 6 && id < 0)
	{
		LogVerbose(1, "PIF Channel " + id +  " does not exist.");
		return -1;
	}
	
	ARRAY[id] = func;
	LogVerbose(1, "PIF Channel " + id +  " is now set.");
	return 0;
}

function unset(id)
{
	if (INIT == false) return;

	if (id >= 6 && id < 0)
	{
		LogVerbose(1, "PIF Channel " + id +  " does not exist.");
		return -1;
	}

	ARRAY[id] = null;
	LogVerbose(1, "PIF Channel " + id +  " is now unset.");
	return 0;
}

//N64 Controller Pak CRC
function crc8(a) {
	//a = buffer(0x20)
	var addr = 0;
	var count = 0x20;
	var crc = 0;
	var calc = 0;

	do {
		calc = 0x80;

		do {
			crc <<= 1;
			if ((a[addr] & calc) == 0) {
				if ((crc & 0x100) != 0)
					crc ^= 0x85;
			} else {
				if ((crc & 0x100) == 0)
					crc++;
				else
					crc ^= 0x84;
			}
			calc >>= 1;
		} while (calc != 0);

		count--;
		addr++;
	} while (count != 0);

	do {
		crc <<= 1;
		if ((crc & 0x100) != 0)
			crc ^= 0x85;
		count++;
	} while (count < 8);

	return crc & 0xFF;
}

function PIFRead(e)
{
	var buf = mem.getblock(PIF_RAM_START, 0x40);
	//0xFF = padding
	//0xFE = end
	//0xFD = skip
	//0x00 = null, go to next channel

	//Find Controller
	var channel = -1;
	var cmdAddr = 0;

	for (cmdAddr = 0; cmdAddr < 0x40; cmdAddr++)
	{
		const value = buf[cmdAddr];

		//If End then stop
		if (value == 0xFE)
			break;
		
		//Skip Padding bytes
		if (value != 0xFF)
		{
			//Found Channel
			channel++;
			LogVerbose(2, "PIF: Channel " + channel + " at 0x" + (PIF_RAM_START + cmdAddr).hex(8));
			
			//Skip the data
			if (value != 0x00 && value != 0xFD)
			{
				if (typeof ARRAY[channel] === "function")
				{
					var sendBytes = buf[cmdAddr + 0] & 0x3F;
					var recvBytes = buf[cmdAddr + 1] & 0x3F;
	
					var sent = buf.slice(cmdAddr + 2, cmdAddr + 2 + sendBytes);
					var recv = buf.slice(cmdAddr + 2 + sendBytes, cmdAddr + 2 + sendBytes + recvBytes);
	
					//Run routine
					var result = ARRAY[channel](sent, recv);

					//Manage Error
					buf[cmdAddr + 1] &= 0x3F;
					if (result == -1)
					{
						//Unable to send/recv amount for command
						buf[cmdAddr + 1] |= 0x40;
					}
					else if (result < -1)
					{
						//Device not present for command
						buf[cmdAddr + 1] |= 0x80;
					}
				}

				var skip = 2;
				skip += buf[cmdAddr + 0] & 0x3F;
				skip += buf[cmdAddr + 1] & 0x3F;
				cmdAddr += skip - 1;
			}
		}
	}

	//Copy PIF RAM back
	mem.setblock(PIF_RAM_START, buf);
}

function LogVerbose(id, text)
{
    if (VERBOSE < id)
        return;
    console.log(text);
}

module.exports = {
    init: init,
    verbose: verbose,
    set: set,
	unset: unset,
	crc8: crc8,
};
