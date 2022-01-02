//CartMapper Module

const VERSION = 1.0;
var INIT = false;
var VERBOSE = 0;
const MAPPER = new Array();
var callbackDMAidWR = 0;

//Public
function init()
{
    //Must be called once
    console.log("CartMapper Module Initialized (v" + VERSION + ")");
    const DMARange = new AddressRange(PI_RD_LEN_REG, PI_WR_LEN_REG + 3);
    callbackDMAidWR = events.onwrite(DMARange, callbackDMA);

    INIT = true;
}

function verbose(set)
{
    //true or false
    if (INIT == false) return;

    VERBOSE = set;
    LogVerbose(1, "Set Verbose to " + VERBOSE);
}

function interrupt(set)
{
    //Set CART Interrupt
	if (set == true)
        cpu.cop0.cause |= 0x800;
    else if (set == false)
        cpu.cop0.cause &= ~0x800;
}

//Function add
//Arguments:
//- range:
//          Either an AddressRange object or a simple address
//- bind:
//          Either a Buffer object or a function
//- call:
//          Either null or a function
//          Called before a Read from Address, or called after a Write to Address
//          Is called similarly to the function for bind
//              call(direction, addr, length)
//          Does not require to return anything
//Returns:
//  0  = Added Without Error
//  <0 = Error
//-------------------------------------------------
//The function is used with the following argument:
//  - direction =   Either OS_READ (0) or OS_WRITE (1)
//  - type =        See Value Type IDs for expected valueType
//  - addr =        Address (K1BASE)
//  - value =       Written Value (OS_WRITE only)
// callback(direction, type, addr, value)
//Returns:
//  Read Value (OS_READ only)

function add(range, bind, call)
{
    if (INIT == false) return;

    //Convert to AddressRange or make sure it is one
    var newrange = range;
    if (typeof range === "number")
        newrange = new AddressRange(range, range+3);
    else if (typeof newrange.start !== "number" && typeof newrange.end !== "number")
    {
        LogVerbose(1, "Add Error: Range is not valid");
        return -1;
    }

    //Make sure bind is a Buffer object or a function
    if (Buffer.isBuffer(bind) == false && typeof bind !== "function")
    {
        LogVerbose(1, "Add Error: bind is not a Buffer or Function");
        return -2;
    }

    //Make sure call is null or a function
    if (call !== null && typeof call !== "function")
    {
        LogVerbose(1, "Add Error: call is not null or Function");
        return -3;
    }

    //Prepare Entry and make Events
    var entry = {
        addr: newrange,
        data: bind,
        call: call,
        idRD: events.onread(newrange, callbackRD),
        idWR: events.onwrite(newrange, callbackWR),
    }

    //Add to Mapper Array
    MAPPER.push(entry);

    LogVerbose(1, "Added " + entry.addr.start.hex(8) + ":" + entry.addr.end.hex(8) + " : " + typeof entry.data + " : " + typeof entry.call);

    return 0;
}

//Private
function callbackDMA(e)
{
    //Get DMA Information
    const dma = DMAInfo(e);
    for (var i = 0; i < MAPPER.length; i++)
    {
        //Search for the range being tapped
        if (dma.cartAddr >= MAPPER[i].addr.start && dma.cartAddr <= MAPPER[i].addr.end)
        {
            PretendDMA();
            if (Buffer.isBuffer(MAPPER[i].data) == true)
            {
                //Buffer
                const datastart = dma.cartAddr - MAPPER[i].addr.start;
                const dataend = datastart + dma.length;

                const datacart = MAPPER[i].data.slice(datastart, dataend);
                if (dma.direction == OS_READ)
                {
                    //RAM -> CART
                    const dataram = mem.getblock(dma.ramAddr, dma.length);
                    dataram.copy(datacart, 0, 0, dma.length);

                    //Call after Write to Address
                    if (typeof MAPPER[i].call === "function")
                        MAPPER[i].call(OS_WRITE, dma.cartAddr, dma.length);
                    
                    LogVerbose(2, "DMA BUF " + dma.ramAddr.hex(8) + " -> " + dma.cartAddr.hex(8) + " / Length:" + dma.length.hex());
                }
                else
                {
                    //CART -> RAM
                    
                    //Call before Read from Address
                    if (typeof MAPPER[i].call === "function")
                        MAPPER[i].call(OS_READ, dma.cartAddr, dma.length);
                    mem.setblock(dma.ramAddr, datacart);
                    LogVerbose(2, "DMA BUF " + dma.ramAddr.hex(8) + " <- " + dma.cartAddr.hex(8) + " / Length:" + dma.length.hex());
                }
            }
            else if (typeof MAPPER[i].data === "function")
            {
                //Function
                for (var j = 0; j < dma.length; j += 4)
                {
                    if (dma.direction == OS_READ)
                    {
                        //RAM -> CART
                        MAPPER[i].data(OS_WRITE, u32, dma.cartAddr, mem.u32[dma.ramAddr + j]);
                        if (j == 0)
                        {
                            //Call after Write to Address
                            if (typeof MAPPER[i].call === "function")
                                MAPPER[i].call(OS_WRITE, dma.cartAddr, dma.length);
                            LogVerbose(2, "DMA FUN " + dma.ramAddr.hex(8) + " -> " + dma.cartAddr.hex(8) + " / Length:" + dma.length.hex());
                        }
                    }
                    else
                    {
                        //CART -> RAM
                        if (j == 0)
                        {
                            //Call before Read from Address
                            if (typeof MAPPER[i].call === "function")
                                MAPPER[i].call(OS_READ, dma.cartAddr, dma.length);
                            LogVerbose(2, "DMA FUN " + dma.ramAddr.hex(8) + " <- " + dma.cartAddr.hex(8) + " / Length:" + dma.length.hex());
                        }
                        mem.u32[dma.ramAddr + j] = MAPPER[i].data(OS_READ, u32, dma.cartAddr, 0);
                    }
                }
            }
            return;
        }
    }
}

function callbackRD(e)
{
    callbackRDWR(e, OS_READ);
}

function callbackWR(e)
{
    callbackRDWR(e, OS_WRITE);
}

function callbackRDWR(e, direction)
{
    for (var i = 0; i < MAPPER.length; i++)
    {
        //Search for the range being tapped
        if (e.address >= MAPPER[i].addr.start && e.address <= MAPPER[i].addr.end)
        {
            if (Buffer.isBuffer(MAPPER[i].data) == true)
            {
                //Buffer
                const datastart = e.address - MAPPER[i].addr.start;
                if (direction == OS_READ)
                {
                    //CART -> REG
                    debug.skip();

                    //Call before Read from Address
                    if (typeof MAPPER[i].call === "function")
                        MAPPER[i].call(OS_READ, e.address, TypeToLength(e.valueType));

                    cpu.gpr[e.reg] = ReadBuffer(e.valueType, MAPPER[i].data, datastart);
                    
                    LogVerbose(2, "RW  BUF " + " <- " + e.address.hex(8));
                }
                else
                {
                    //REG -> CART
                    WriteBuffer(e.valueType, MAPPER[i].data, datastart, e.value);

                    //Call after Write to Address
                    if (typeof MAPPER[i].call === "function")
                        MAPPER[i].call(OS_WRITE, e.address, TypeToLength(e.valueType));
                    
                    LogVerbose(2, "RW  BUF " + " -> " + e.address.hex(8));
                }
            }
            else if (typeof MAPPER[i].data === "function")
            {
                //Function
                if (direction == OS_READ)
                {
                    //CART -> REG
                    debug.skip();

                    //Call before Read from Address
                    if (typeof MAPPER[i].call === "function")
                        MAPPER[i].call(OS_READ, e.address, TypeToLength(e.valueType));
                    
                    cpu.gpr[e.reg] = MAPPER[i].data(OS_READ, e.valueType, e.address, 0);
                    LogVerbose(2, "RW  BUF " + " <- " + e.address.hex(8));
                }
                else
                {
                    //REG -> CART
                    MAPPER[i].data(OS_WRITE, e.valueType, e.address, e.value);

                    //Call after Write to Address
                    if (typeof MAPPER[i].call === "function")
                        MAPPER[i].call(OS_WRITE, e.address, TypeToLength(e.valueType));
                    
                    LogVerbose(2, "RW  BUF " + " -> " + e.address.hex(8));
                }
            }
            return;
        }
    }
}

//--Util
//Read from Buffer based on data type
function ReadBuffer(type, buf, addr)
{
    switch (type)
    {
        case s8:
        case u8:
            return buf[addr];
        case s16:
        case u16:
            return buf.readUInt16BE(addr);
        case s32:
        case u32:
        default:
            return buf.readUInt32BE(addr);
    }
}

//Write to Buffer based on data type
function WriteBuffer(type, buf, addr, data)
{
    switch (type)
    {
        case s8:
        case u8:
            buf[addr] = data;
            return;
        case s16:
        case u16:
            buf.writeUInt16BE(data, addr);
            return;
        case s32:
        case u32:
        default:
            buf.writeUInt32BE(data, addr);
            return;
    }
}

function TypeToLength(type)
{
    switch (type)
    {
        case s8:
        case u8:
            return 1;
        case s16:
        case u16:
            return 2;
        case s32:
        case u32:
        case f32:
        default:
            return 4;
        case f64:
        case u64:
        case s64:
            return 8;
    }
}

function DMAInfo(e)
{
    //Uses CPUReadWriteEvent
    return {
        length: e.value + 1,
        ramAddr: (mem.u32[PI_DRAM_ADDR_REG] + K0BASE),
        cartAddr: (mem.u32[PI_CART_ADDR_REG] + K1BASE),
        direction: e.address == PI_RD_LEN_REG ? OS_READ : OS_WRITE
    }
}

function PretendDMA()
{
    //Skip Write to DMA Length Register
    debug.skip();

    //Inject PI Interrupt
    const MI_INTR_PI = 0x10;
    mem.u32[MI_INTR_REG] |= MI_INTR_PI;
    cpu.cop0.cause;

    //Step CPU
    debug.step();
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
    add: add,
    interrupt: interrupt,
};
