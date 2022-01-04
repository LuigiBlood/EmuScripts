//N64 Randnet Keyboard
console.clear();
console.log("- N64 Randnet Keyboard -");

//Edit this: Controller to hijack (0 to 3)
const CONTROLLER_ID = 3;

//Edit this: Verbose
const VERBOSE = 0;

const cont_id = 0x0200;					//Controller ID

var DONE = true;
var TEXT = "";
const TIMINGMAX = 1;
var TIMING = TIMINGMAX;

function ProcessPort(sent, recv)
{
	//Process PIF Controller Command
	const cmd = sent[0];

	if (cmd == 0x00 || cmd == 0xFF)
	{
		//Info / Reset
		if (sent.length != 1 || recv.length != 3)
		{
			//Return Error if the send/recv info is wrong
			return -1;
		}
		
		//Controller ID
		recv.writeUInt16LE(cont_id, 0);
		//Controller Status
		recv[2] = 0x00;
	}
	else if (cmd == 0x13)
	{
		//MBC4 Read
		if (sent.length != 2 || recv.length != 7)
		{
			//Return Error if the send/recv info is wrong
			return -1;
		}

		recv.fill(0);

		if (DONE == false && TEXT.length > 0)
		{
			if (TIMING >= 1)
			{
				if (BUTTONS[TEXT[0]] < 0x10000)
					recv.writeUInt16BE(BUTTONS[TEXT[0]], 0);
				else
					recv.writeUInt32BE(BUTTONS[TEXT[0]], 0);
			}

			if (TIMING > 0)
			{
				TIMING--;
			}
			else
			{
				TEXT = TEXT.slice(1);
				TIMING = TIMINGMAX;
			}
		}

		if (TEXT.length <= 0)
		{
			DONE = true;
		}
	}
	else
	{
		//Return Error if invalid command
		return -2;
	}
}

function BreakPIF()
{
	//Show PIF RAM
	debug.showmemory(PIF_RAM_START);
}

function ListenText(input)
{
	if (DONE == false) return;

	TEXT = input;
	DONE = false;
	TIMING = TIMINGMAX;
}

var PIFForward = require("PIFForward.js");
PIFForward.init();
PIFForward.verbose(0);

PIFForward.set(CONTROLLER_ID, ProcessPort);

const BUTTONS = {
	"1": 0x0C05,
	"2": 0x0505,
	"3": 0x0605,
	"4": 0x0705,
	"5": 0x0805,
	"6": 0x0905,
	"7": 0x0906,
	"8": 0x0806,
	"9": 0x0706,
	"0": 0x0606,

	"q": 0x0C01,
	"w": 0x0501,
	"e": 0x0601,
	"r": 0x0701,
	"t": 0x0801,
	"y": 0x0901,
	"u": 0x0904,
	"i": 0x0804,
	"o": 0x0704,
	"p": 0x0604,
	"a": 0x0D07,
	"s": 0x0C07,
	"d": 0x0507,
	"f": 0x0607,
	"g": 0x0707,
	"h": 0x0807,
	"j": 0x0907,
	"k": 0x0903,
	"l": 0x0803,
	"z": 0x0D08,
	"x": 0x0C08,
	"c": 0x0508,
	"v": 0x0608,
	"b": 0x0708,
	"n": 0x0808,
	"m": 0x0908,

	"Q": 0x0E010C01,
	"W": 0x0E010501,
	"E": 0x0E010601,
	"R": 0x0E010701,
	"T": 0x0E010801,
	"Y": 0x0E010901,
	"U": 0x0E010904,
	"I": 0x0E010804,
	"O": 0x0E010704,
	"P": 0x0E010604,
	"A": 0x0E010D07,
	"S": 0x0E010C07,
	"D": 0x0E010507,
	"F": 0x0E010607,
	"G": 0x0E010707,
	"H": 0x0E010807,
	"J": 0x0E010907,
	"K": 0x0E010903,
	"L": 0x0E010803,
	"Z": 0x0E010D08,
	"X": 0x0E010C08,
	"C": 0x0E010508,
	"V": 0x0E010608,
	"B": 0x0E010708,
	"N": 0x0E010808,
	"M": 0x0E010908,

	"@": 0x0504,
	"[": 0x0C04,
	"]": 0x0406,
	";": 0x0703,
	":": 0x0603,
	",": 0x0902,
	".": 0x0802,
	"?": 0x0702,
	" ": 0x0602,
	"<": 0x0E010902,
	">": 0x0E010802,
	"{": 0x0E010C04,
	"}": 0x0E010406,

}

console.log("Type on the console to type in the game:");
console.listen(ListenText);
