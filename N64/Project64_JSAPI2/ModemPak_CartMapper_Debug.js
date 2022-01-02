//Modem Pak Simple Emulation Script
//Does not emulate modem straight up
//Requires CartMapper Module and "modem.bin" Modem ROM dump file on PJ64's main directory.

console.clear();
console.log("- Modem Pak Simulation -")
if (!fs.exists("modem.bin"))
	console.log("Error: Couldn't find modem.bin")

//Modem Pak ROM
const ADDR_MODEM_PAK_ROM = new AddressRange(0xB8000000, 0xB8800000-1);

//Modem Pak I/O
const ADDR_MODEM_PAK_BUF = new AddressRange(0xAFFD0000, 0xAFFD00C0-1);
const ADDR_MODEM_PAK_REG = 0xAFFD00C0;

//Modem Register Variable
var MODEM_REG = 0;

//Buffers
const MODEM_ROM = fs.readfile("modem.bin");
const MODEM_BUF = new Buffer(0xC0);

//Modem Register Read/Write Function
function Modem_RegRW(direction, type, addr, value)
{
	if (direction == OS_READ)
	{
		console.log("READ  REG: " + addr.hex(8) + " : " + MODEM_REG.hex(8));
		return MODEM_REG;
	}
	else
	{
		MODEM_REG = value;
		console.log("WRITE REG: " + addr.hex(8) + " : " + MODEM_REG.hex(8));

		//Reset Register
		if (MODEM_REG & 0x08000000)
		{
			MODEM_REG &= 0x0000FFFF;
		}
	}
}

function Modem_DmaCall(direction, addr, length)
{
	if (direction == OS_READ)
	{
		console.log("Read Buf: " + addr.hex(8) + " : " + length.hex(8));
	}
	else
	{
		console.log("Write Buf: " + addr.hex(8) + " : " + length.hex(8));
	}
}

//Map Modem Pak to Cartridge Domains
var CartMapper = require("CartMapper.js");
CartMapper.init();
CartMapper.verbose(0);

CartMapper.add(ADDR_MODEM_PAK_ROM, MODEM_ROM, Modem_DmaCall);
CartMapper.add(ADDR_MODEM_PAK_BUF, MODEM_BUF, Modem_DmaCall);
CartMapper.add(ADDR_MODEM_PAK_REG, Modem_RegRW, null);
