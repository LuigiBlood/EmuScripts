console.clear();
console.log("- KMC Partner-N64 -");

const ADDR_KMC_CODE = new AddressRange(0xBFF00000, 0xBFF08000-1);
const ADDR_KMC_REG = new AddressRange(0xBFF08000, 0xC0000000-1);

const _KMC_REG_WPORT = ADDR_KMC_REG.start + 0x0;
const _KMC_REG_STAT = ADDR_KMC_REG.start + 0x4;

const KMC_CHK = 0x4B4D4300;	//"KMC "

var KMC_CODE = new Buffer(ADDR_KMC_CODE.end + 1 - ADDR_KMC_CODE.start);
KMC_CODE.writeUInt32BE(KMC_CHK, 0x00);
KMC_CODE.writeUInt32BE(0xB0FFB000, 0x10);

var KMC_COUNT = -1;
var KMC_STRING = [];

function KMC_RegRW(direction, type, addr, value)
{
	if (direction == OS_READ)
	{
		if (addr == _KMC_REG_STAT)
		{
			return 0x14;
		}
		return 0;
	}
	else
	{
		if (addr == _KMC_REG_WPORT)
		{
			if (KMC_COUNT < 0)
			{
				KMC_COUNT = value;
				console.print(String.fromCharCode.apply(null, KMC_STRING));
				KMC_STRING = [];
			}
			else
			{
				if (value == 0xA)
				{
					//Space (for Windows)
					KMC_STRING.push(0xD);
				}
				KMC_STRING.push(value);
				KMC_COUNT--;
			}
		}
	}
}

var CartMapper = require("CartMapper.js");
CartMapper.init();
CartMapper.verbose(0);

CartMapper.add(ADDR_KMC_CODE, KMC_CODE, null);
CartMapper.add(ADDR_KMC_REG, KMC_RegRW, null);
