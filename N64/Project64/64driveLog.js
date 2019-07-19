//64drive Console Log - Only supports DPRINTF (by LuigiBlood)
//Only emulates the bare minimum for output.

//Disable Project64's breakpoints when it DMAs/writes to regular cart ROM.

const CART_BASE_UNCACHED = 0xB0000000;
const CI_REG_BASE = CART_BASE_UNCACHED + 0x08000000;

const CI_REG_STATUS = CI_REG_BASE + 0x200;
const CI_REG_COMMAND = CI_REG_BASE + 0x208;

const CI_REG_USB_CMDSTAT = CI_REG_BASE + 0x400;
const CI_REG_USB_PARAM0 = CI_REG_BASE + 0x404;
const CI_REG_USB_PARAM1 = CI_REG_BASE + 0x408;

const CI_REG_RANGE = new AddressRange(CI_REG_BASE, CI_REG_BASE + 0x1C00);

const CART_BASE_DMA_START = 0x10000000;
const CART_BASE_DMA_END = 0x14000000;

var CI_STAT = 0;
var USB_STAT = 0;
var USB_CMD = 0;
var USB_ADDR = 0;
var USB_SIZE = 0;
var USB_CHAN = 0;

var CI_DATA_ARRAY = [];

console.log("-- 64drive Console --");

events.onread(CI_REG_RANGE, function(addr) {
	return_reg = getStoreOp();
	return_data = 0;
	
	if (addr == CI_REG_STATUS)
	{
		return_data = CI_STAT;
	}
	else if (addr == CI_REG_USB_CMDSTAT)
	{
		return_data = USB_STAT;
	}
	
	//console.log("READ -", addr.hex(), "-", return_data.hex());
	
	callbackId = events.onexec((gpr.pc + 4), ReadCartReg);
});

events.onwrite(CI_REG_RANGE, function(addr) {
	return_reg = getStoreOp();
	
	if (addr == CI_REG_USB_CMDSTAT)
	{
		USB_CMD = getStoreOpValue();
		if (USB_CMD == 8)
		{
			//Write
			USB_CMD = 0;
			//console.log("USB WRITE");
			for (var i = 0; i < CI_DATA_ARRAY.length; i++)
			{
				//console.log(i, ":", CI_DATA_ARRAY[i].base_addr.hex());
				if (CI_DATA_ARRAY[i].base_addr == (USB_ADDR + 0x10000000))
				{
					if (USB_CHAN == 1)
						console.print(CI_DATA_ARRAY[i].data);
					CI_DATA_ARRAY.splice(i, 1);
				}
			}
		}
	}
	else if (addr == CI_REG_USB_PARAM0)
	{
		USB_ADDR = getStoreOpValue() << 1;
	}
	else if (addr == CI_REG_USB_PARAM1)
	{
		USB_SIZE = getStoreOpValue() & 0xFFFFFF;
		USB_CHAN = (getStoreOpValue() >> 24) & 0xFF;
	}
	
	//console.log("WRITE-", addr.hex(), "-", getStoreOpValue().hex());
});

function ReadCartReg()
{
    gpr[return_reg] = return_data;
    events.remove(callbackId);
}

//DMA Stuff
const PI_DRAM_ADDR_REG = 0xA4600000;
const PI_CART_ADDR_REG = 0xA4600004;
const PI_RD_LEN_REG = 0xA4600008;
const PI_WR_LEN_REG = 0xA460000C;

function onCartRead()
{
	var dma = DMAInfo();
	console.log("cart -> ram:", dma.length.hex(), dma.ramAddr.hex(), dma.cartAddr.hex());
}

function onCartWrite()
{
	var dma = DMAInfo();
	//console.log("ram -> cart", dma.length.hex(), dma.ramAddr.hex(), dma.cartAddr.hex());
	
	var ci_dat = CI_DATA();
	//console.log("ram -> cart", ci_dat.length.hex(), ci_dat.base_addr.hex());
	CI_DATA_ARRAY.push(ci_dat);
}

//events.onwrite(PI_WR_LEN_REG, onCartRead);
events.onwrite(PI_RD_LEN_REG, onCartWrite);

function DMAInfo()
{
	return {
		length: getStoreOpValue() + 1,
		ramAddr: mem.u32[PI_DRAM_ADDR_REG],
		cartAddr: mem.u32[PI_CART_ADDR_REG]
	}
}

function getStoreOp()
{
	// hacky way to get value that SW will write
	var pcOpcode = mem.u32[gpr.pc];
	var tReg = (pcOpcode >> 16) & 0x1F;
	return tReg;
}

function getStoreOpValue()
{
	// hacky way to get value that SW will write
	var pcOpcode = mem.u32[gpr.pc];
	var tReg = (pcOpcode >> 16) & 0x1F;
	return gpr[tReg];
}

function CI_DATA () {
	return {
		base_addr: mem.u32[PI_CART_ADDR_REG],
		length: getStoreOpValue() + 1,
		data: mem.getblock(mem.u32[PI_DRAM_ADDR_REG] + 0x80000000, getStoreOpValue() + 1)
	}
}