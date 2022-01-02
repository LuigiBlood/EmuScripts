//Capture Pak Simple Emulation Script
//Does not actually emulate video or audio, it's for testing
console.clear();
console.log("- Capture Pak Simulation -")

const ADDR_CAPTURE_REG = new AddressRange(0xAFE00000, 0xAFE00200-1);
const ADDR_CAPTURE_BUF = new AddressRange(0xAFE00200, 0xAFE40000-1);

const CAPTURE_BUF = new Buffer(ADDR_CAPTURE_BUF.end - ADDR_CAPTURE_BUF.start + 1);

//Read
//0xAFE00000 - Status
var CAPTURE_REG_STATUS = 0x01FF0040;
//0xAFE00004 - Unknown
var CAPTURE_REG_R004 = 0xFFFF0000;
//0xAFE00008 - Unknown
var CAPTURE_REG_R008 = 0;
//0xAFE00100 - Unknown
var CAPTURE_REG_R100 = 0;
//0xAFE00180 - Unknown
var CAPTURE_REG_R180 = 0;

//Write
//0xAFE00000 - Command
var CAPTURE_REG_CMD = 0;
//0xAFE00004 - Unknown
var CAPTURE_REG_W004 = 0;
//0xAFE00100 - Unknown
var CAPTURE_REG_W100 = 0;


//Generate Video Buffer
function Buffer_VideoGen()
{
	for (var i = 0x4400; i < CAPTURE_BUF.length; i += 2)
    {
    	var defaultbyte = 0x38;
		
		var y = i / 0x400;
		var x = i % 0x400;
		
    	if ((i & 0x3FF) < 0x70)
    	{
			//Low Signal
			CAPTURE_BUF[i + 0] = defaultbyte;
    		CAPTURE_BUF[i + 1] = defaultbyte;
		}
		else
		{
			//All Values
			CAPTURE_BUF[i + 1] = ((y - 0x11) * 1.24);
			CAPTURE_BUF[i + 0] = ((x - 0xAE) * 0.405);
		}
    }
}

//Generate Audio Buffer
var sinvar = 0;
function Buffer_AudioGen(addr, size)
{
    //debug.breakhere();
	addr -= ADDR_CAPTURE_BUF.start;

    var data = 0;
    for (var i = 0; i < size; i += 1)
    {
    	data = Math.round((Math.sin(sinvar / 3.0) * 0x80) + 0x80);
    	if (data > 0xFF)
    	    data = 0xFF;
    	sinvar++;
    	
        CAPTURE_BUF[addr + i] = data;
    }
}

var audioID = 0;
function SetInterrupt()
{
	CartMapper.interrupt(true);
}

function CaptureReg_RW(direction, type, addr, value)
{
	if (direction == OS_READ)
	{
		switch (addr)
		{
			case 0xAFE00000:
				return CAPTURE_REG_STATUS;
			case 0xAFE00004:
				return CAPTURE_REG_R004;
			case 0xAFE00008:
				return CAPTURE_REG_R008;
			case 0xAFE00100:
				return CAPTURE_REG_R100;
			case 0xAFE00180:
				return CAPTURE_REG_R180;
			default:
				return 0;
		}
	}
	else
	{
		switch (addr)
		{
			case 0xAFE00000:
				CAPTURE_REG_CMD = value;
				break;
			case 0xAFE00004:
				CAPTURE_REG_W004 = value;
				break;
			case 0xAFE00100:
				CAPTURE_REG_W100 = value;
				break;
		}
	}
}

function CaptureReg_Mgr(direction, addr, length)
{
	if (direction == OS_READ)
	{
		if ((CAPTURE_REG_CMD & 0xFF) > 0xB0 && (CAPTURE_REG_CMD & 0xFF) < 0xC0 && addr == 0xAFE00000)
		{
			CartMapper.interrupt(false);
		}
		
		if ((CAPTURE_REG_CMD & 0xFF) > 0xB0 && (CAPTURE_REG_CMD & 0xFF) < 0xC0 && addr == 0xAFE00004)
		{
			CartMapper.interrupt(true);
		}
	}
	else
	{
		//console.log("WRITE " + addr.hex(8))
		if (addr == 0xAFE00000)
		{
			if ((CAPTURE_REG_CMD & 0xF0) == 0xB0)
			{
				//Request
				CartMapper.interrupt(true);
				if (((CAPTURE_REG_CMD & 0x0F) == 4) || ((CAPTURE_REG_CMD & 0x0F) == 8))
				{
					audioID = setTimeout(SetInterrupt, 500)
				}
			}
			else if ((CAPTURE_REG_CMD & 0xF0) == 0xA0)
			{
				//Stop?
				CartMapper.interrupt(false);
				if (((CAPTURE_REG_CMD & 0x0F) == 4) || ((CAPTURE_REG_CMD & 0x0F) == 8))
				{
					clearTimeout(audioID)
				}
			}
			else if ((CAPTURE_REG_CMD & 0xF0) == 0xF0)
			{
				//Acknowledge?
				CartMapper.interrupt(false);
			}
		}
	}
}

function CaptureBuf_Mgr(direction, addr, length)
{
	if (direction == OS_READ)
	{
		//console.log("DMA " + addr.hex(8))
		//CartMapper.interrupt(false);
		if ((CAPTURE_REG_CMD & 0xFF) == 0xF0)
		{
			//console.log("Test Video " + CAPTURE_REG_CMD.hex(8));
			Buffer_VideoGen();
		}
		else if ((CAPTURE_REG_CMD & 0xFF) == 0xB4)
		{
			//console.log("Test Video " + CAPTURE_REG_CMD.hex(8));
			Buffer_AudioGen(addr, length);
		}
		else if ((CAPTURE_REG_CMD & 0xFF) == 0xB8)
		{
			//console.log("Test Video " + CAPTURE_REG_CMD.hex(8));
			Buffer_AudioGen(addr, length);
		}
	}
	else
	{
		
	}
}

var CartMapper = require("CartMapper.js");
CartMapper.init();
CartMapper.verbose(0);

CartMapper.add(ADDR_CAPTURE_REG, CaptureReg_RW, CaptureReg_Mgr);
CartMapper.add(ADDR_CAPTURE_BUF, CAPTURE_BUF, CaptureBuf_Mgr);
