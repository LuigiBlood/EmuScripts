//Modem Pak Simulation script by LuigiBlood
//This requires the Modem Pak ROM dump file (modem.bin) in the root folder of the emulator.
//This does NOT emulate the modem registers.

console.log("Modem Pak Simulation");

const PI_DRAM_ADDR_REG = 0xA4600000;
const PI_CART_ADDR_REG = 0xA4600004;
const PI_RD_LEN_REG = 0xA4600008;
const PI_WR_LEN_REG = 0xA460000C;

const ADDR_MODEM_PAK_ROM_PHYS = new AddressRange(0x18000000, 0x18800000);
const ADDR_MODEM_PAK_ROM = new AddressRange(0xB8000000, 0xB8800000);
const ADDR_MODEM_PAK_REG_PHYS = 0x0FFD00C0;
const ADDR_MODEM_PAK_REG = 0xAFFD00C0;
const ADDR_MODEM_PAK_DMA_PHYS = new AddressRange(0x0FFD0000, 0x0FFD00BF);
const ADDR_MODEM_PAK_DMA = new AddressRange(0xAFFD0000, 0xAFFD00BF);


var modem_reg = 0;

//Modem ROM Loading
var modem_rom = Buffer(0x800000);
var modem_rom_fs = fs.open('modem.bin', 'rb');

fs.read(modem_rom_fs, modem_rom, 0, 0x800000, 0);
fs.close(modem_rom_fs);

//console.log(modem_rom[0].hex());

//Simulate Reads
var readreg;
var readdata;
var callbackId;

var j = 0;

//Keep Capture Options
var command = 0;

//Events

events.onwrite(PI_WR_LEN_REG, onCartRead);
events.onwrite(PI_RD_LEN_REG, onCartWrite);

events.onread(ADDR_MODEM_PAK_ROM, function(addr)
{
    console.log('CPU is reading',addr.hex(),'at', gpr.pc.hex());
    //debug.breakhere();
    readreg = getStoreOp();
    readdata = 0x7F454C46;
    
    
    callbackId = events.onexec((gpr.pc + 4), ReadCartReg);
})

events.onwrite(ADDR_MODEM_PAK_ROM, function(addr)
{
    console.log('CPU is writing to', addr.hex(), ':', gpr[getStoreOp()].hex());
});

events.onread(ADDR_MODEM_PAK_REG, function(addr) {
    console.log('CPU is reading',addr.hex(),'at', gpr.pc.hex());
    readdata = modem_reg;
    callbackId = events.onexec((gpr.pc + 4), ReadCartReg);
});

events.onwrite(ADDR_MODEM_PAK_REG, function(addr) {
    modem_reg = gpr[getStoreOp()];
    console.log('CPU is writing to', addr.hex(), ':', gpr[getStoreOp()].hex());
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
    if ((dma.cartAddr & 0x10000000) == 0x10000000)
    {
        //console.log("cart -> ram:", dma.length.hex(), dma.ramAddr.hex(), dma.cartAddr.hex());
    }

    if ((dma.cartAddr >= ADDR_MODEM_PAK_ROM_PHYS.start) && (dma.cartAddr < ADDR_MODEM_PAK_ROM_PHYS.end))
    {
        console.log("DMA from Modem ROM - ", (dma.cartAddr - ADDR_MODEM_PAK_ROM_PHYS.start).hex());
        for (var i = 0; i < dma.length; i++)
        {
            mem.u8[ADDR_ANY_RDRAM.start + dma.ramAddr + i] = modem_rom[dma.cartAddr - ADDR_MODEM_PAK_ROM_PHYS.start + i];
        }
        mem.u32[PI_CART_ADDR_REG] = 0;	//Prevent DMA Error
        //debug.breakhere();
    }
    else if ((dma.cartAddr >= ADDR_MODEM_PAK_DMA_PHYS.start) && (dma.cartAddr < ADDR_MODEM_PAK_DMA_PHYS.end))
    {
        console.log("DMA from Modem Data - ", (dma.cartAddr - ADDR_MODEM_PAK_DMA_PHYS.start).hex());
        for (var i = 0; i < dma.length; i++)
        {
            mem.u8[ADDR_ANY_RDRAM.start + dma.ramAddr + i] = 0;
        }
        mem.u32[PI_CART_ADDR_REG] = 0;	//Prevent DMA Error
        //debug.breakhere();
    }
}

function onCartWrite()
{
    var dma = DMAInfo();
    if ((dma.cartAddr & 0x10000000) == 0x10000000)
    {
        console.log("ram -> cart", dma.length.hex(), dma.ramAddr.hex(), dma.cartAddr.hex());
    }
    
    if ((dma.cartAddr >= ADDR_MODEM_PAK_DMA_PHYS.start) && (dma.cartAddr < ADDR_MODEM_PAK_DMA_PHYS.end))
    {
        console.log("DMA to Modem Data - ", (dma.cartAddr - ADDR_MODEM_PAK_DMA_PHYS.start).hex(), (dma.ramAddr + ADDR_ANY_RDRAM.start).hex());
        for (var i = 0; i < dma.length; i++)
        {
		var byt = mem.u8[ADDR_ANY_RDRAM.start + dma.ramAddr + i].hex();
		console.print(byt[6], byt[7]);
		if ((i & 0x1F) == 0x1F)
			console.print("\r\n");
        }
        console.print("\r\n");
        mem.u32[PI_CART_ADDR_REG] = 0x08000000;	//Prevent DMA Error
        //debug.breakhere();
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
