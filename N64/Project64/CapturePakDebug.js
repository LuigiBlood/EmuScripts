//Capture Pak Debug Script - by LuigiBlood
//This does not emulate the Capture Pak correctly, it is merely used only for reverse enginnering purposes.

const PI_DRAM_ADDR_REG = 0xA4600000;
const PI_CART_ADDR_REG = 0xA4600004;
const PI_RD_LEN_REG = 0xA4600008;
const PI_WR_LEN_REG = 0xA460000C;

const ADDR_CAPTURE_CART = new AddressRange(0xAFE00000, 0xAFE80000);
//Simulate Reads
var readreg;
var readdata;
var callbackId;

var imagedataRAM;
var imagedataCall;

var j = 0;

//Keep Capture Options
var command = 0;


console.log("Capture Pak Simulation");

events.onwrite(PI_WR_LEN_REG, onCartRead);

events.onread(ADDR_CAPTURE_CART, function(addr)
{
    console.log('CPU is reading',addr.hex(),'at', gpr.pc.hex());
    //debug.breakhere();
    readreg = getStoreOp();
    readdata = 0;
    
    if (addr == 0xAFE00000)
    {
    	readdata = 0x01FF0040;
    	if (((command & 0xFF) == 0xB4) || ((command & 0xFF) == 0xB8) || ((command & 0xFF) == 0xBC))
    	{
    	    readdata = readdata | 0x0000;
    	    StopIntCART();
    	}
    }
    else if (addr == 0xAFE00004)
    {
    	readdata = 0xFFFF0000;
    	if (((command & 0xFF) == 0xB4) || ((command & 0xFF) == 0xB8) || ((command & 0xFF) == 0xBC))
    	{
    	    readdata = readdata | 0x0000;
    	    DoIntCART();
    	}
    }
    callbackId = events.onexec((gpr.pc + 4), ReadCartReg);
})

events.onwrite(ADDR_CAPTURE_CART, function(addr)
{
    console.log('CPU is writing to', addr.hex(), ':', gpr[getStoreOp()].hex());
    if (addr == 0xAFE00000)
    {
        command = gpr[getStoreOp()];
        if ((gpr[getStoreOp()] & 0xF0) == 0xB0)
        {
    	    DoIntCART();
        }
        else if ((gpr[getStoreOp()] & 0xF0) == 0xF0)
        {
    	    StopIntCART();
        }
    }
});

//Interrupt
function DoIntCART()
{
    console.log('Interrupt!');
    cop0.cause = cop0.cause | 0x800;
}

function StopIntCART()
{
    console.log('Stop Interrupt!');
    cop0.cause = cop0.cause & ~0x800;
}

//DMA Stuff
function onCartRead()
{
    var dma = DMAInfo();
    imagedataRAM = (dma.ramAddr | 0x80000000);
    if ((dma.cartAddr & 0x0FE00000) == 0x0FE00000)
    {
        console.log("cart -> ram:", dma.length.hex(), imagedataRAM.hex(), dma.cartAddr.hex());
    }
    
    if (dma.cartAddr == 0x0FE00200)
    {
        //console.log("cart -> ram:", dma.length.hex(), imagedataRAM.hex(), dma.cartAddr.hex());
        if ((command & 0x0F) == 0x00)
        {
            ImageDataAccess(imagedataRAM, dma.length);
        }
    }
    
    if ((dma.cartAddr == 0x0FE00400) || (dma.cartAddr == 0x0FE00600) || (dma.cartAddr == 0x0FE00800))
    {
        //console.log("cart -> ram:", dma.length.hex(), imagedataRAM.hex(), dma.cartAddr.hex());
        if ((command & 0x0F) != 0x00)
        {
            AudioDataAccess(imagedataRAM, dma.length);
        }
    }
}

function DMAInfo()
{
	return {
		length: getStoreOpValue() + 1,
		ramAddr: mem.u32[PI_DRAM_ADDR_REG],
		cartAddr: mem.u32[PI_CART_ADDR_REG]
	}
}

function getStoreOpValue()
{
	// hacky way to get value that SW will write
	var pcOpcode = mem.u32[gpr.pc];
	var tReg = (pcOpcode >> 16) & 0x1F;
	return gpr[tReg];
}

function getStoreOp()
{
	// hacky way to get value that SW will write
	var pcOpcode = mem.u32[gpr.pc];
	var tReg = (pcOpcode >> 16) & 0x1F;
	return tReg;
}

//Callbacks
function ReadCartReg()
{
    //console.log(readreg, '-', readdata.hex());
    gpr[readreg] = readdata;
    //debug.breakhere();
    events.remove(callbackId);
}

var image2 = 0x80;

//80366440 - 8036A880
// 0x4440 (=18 lines?)
// 1 line = 0x3CA?

//Communication Kit: 408 pixels per line, but technically 485.
function ImageDataAccess(addr, size)
{
    //console.log("Read Image Data: ", addr.hex());
    //debug.breakhere();
    var image = 0;
    //for (var i = 0x4440; i < size; i += 4)
    //for (var i = 0x4440; i < (0x4440 + ((500 * 2) * 8)); i += 2)
    //for (var i = (0x4440 + ((512 * 2) * 21)); i <= (0x4440 + ((512 * 2) * 21)); i += 2)
    //for (var i = 0x4040; i < (0x4040 + ((512 * 2) * 208)); i += 4)
    for (var i = 0; i < size; i += 4)
    {
    	//mem.u16[addr + i + 0] = 0xFFFF;
    	//mem.u16[addr + i + 0] = ((image & 0xFF00) >> 8) | ((image & 0xFF) << 8);
    	//mem.u16[addr + i + 0] = 0xFF | ((image & 0xFF) << 8);
    	//mem.u16[addr + i + 2] = 0xFF | (image & 0xFF00);
    	mem.u16[addr + i + 0] = (image2 & 0xFF) | ((image & 0xFF) << 8);
    	mem.u16[addr + i + 2] = (image2 & 0xFF) | (image & 0xFF00);
    	
    	image += 1;
    }
    image2 += 1;
}

var sinvar = 0;

function AudioDataAccess(addr, size)
{
    //debug.breakhere();
    var data = 0;
    for (var i = 0; i < size; i += 1)
    {
    	//data = Math.sin(i / 100.0) * 32768.0;
    	if ((i & 0x200) != 0x200)
    	{
    	    //
    	    data = 0xFF;
    	}
    	else
    	{
    	    data = 0xFF;
    	}
    	
    	data = Math.round((Math.sin(sinvar / 3.0) * 0x80) + 0x80);
    	if (data > 0xFF)
    	{
    	    data = 0xFF;
    	}
    	//console.log("Sin[i]:", data.hex());
    	sinvar++;
    	
        mem.u8[addr + i] = data;
    }
}