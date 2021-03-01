events.onread(0xBC000000, function(addr) {
	return_reg = getStoreOp();
	return_data = 0x4C53;
	callbackId = events.onexec((gpr.pc + 4), ReadCartReg);
});

events.onread(0xBC000002, function(addr) {
	return_reg = getStoreOp();
	return_data = 0x4653;
	callbackId = events.onexec((gpr.pc + 4), ReadCartReg);
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
//events.onwrite(PI_RD_LEN_REG, onCartWrite);

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
