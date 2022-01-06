console.clear();
console.log("- 64Drive (UNFLoader) -");

const DEBUG_ADDRESS_SIZE = (8*1024*1024);

const ADDR_CI_BUF = new AddressRange(0xB4000000 - DEBUG_ADDRESS_SIZE, 0xB4000000-1);
const ADDR_CI_REG = new AddressRange(0xB8000000, 0xB8001C00-1);

const ADDR_CI_REG_STATUS = ADDR_CI_REG.start + 0x200;
const ADDR_CI_REG_COMMAND = ADDR_CI_REG.start + 0x208;
const ADDR_CI_REG_MAGIC = ADDR_CI_REG.start + 0x2EC;
const ADDR_CI_REG_USB_CMDSTAT = ADDR_CI_REG.start + 0x400;
const ADDR_CI_REG_USB_PARAM0 = ADDR_CI_REG.start + 0x404;
const ADDR_CI_REG_USB_PARAM1 = ADDR_CI_REG.start + 0x408;

const CI_MAGIC = 0x55444556;
var CI_USB_ADDR = 0;
var CI_USB_SIZE = 0;
var CI_USB_TYPE = 0;
var CI_USB_STAT = 0;

var CI_BUF = new Buffer(ADDR_CI_BUF.end + 1 - ADDR_CI_BUF.start);

function CI_RegRW(direction, type, addr, value)
{
	if (direction == OS_READ)
	{
		//Read
		if (addr == ADDR_CI_REG_USB_CMDSTAT)
		{
			return CI_USB_STAT;
		}
		else if (addr == ADDR_CI_REG_MAGIC)
		{
			return CI_MAGIC;
		}
		return 0;
	}
	else
	{
		//Write
		if (addr == ADDR_CI_REG_USB_CMDSTAT)
		{
			//Command
			if (value == 0x08)
			{
				//USB Write
				if (CI_USB_TYPE == 0x01)
				{
					//Text
					const start = CI_USB_ADDR - (ADDR_CI_BUF.start & 0x3FFFFFF);
					const end = start + CI_USB_SIZE;
					console.print(CI_BUF.toString("utf8", start, end));
				}
			}
		}
		else if (addr == ADDR_CI_REG_USB_PARAM0)
		{
			CI_USB_ADDR = (value << 1);
		}
		else if (addr == ADDR_CI_REG_USB_PARAM1)
		{
			CI_USB_SIZE = value & 0x00FFFFFF;
			CI_USB_TYPE = value >> 24;
		}
	}
}

var CartMapper = require("CartMapper.js");
CartMapper.init();
CartMapper.verbose(0);

CartMapper.add(ADDR_CI_BUF, CI_BUF, null);
CartMapper.add(ADDR_CI_REG, CI_RegRW, null);
