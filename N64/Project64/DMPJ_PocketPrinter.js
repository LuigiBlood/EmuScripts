//Mario Artist Paint Studio - Link Cable / Pocket Printer by LuigiBlood
console.clear();
console.log("- Paint Studio - Link Cable and Pocket Printer");

//0 = Pocket Printer - 1 = Pocket Printer Color
const PRINTER_TYPE = 1;

const RAM_PIF_SEND = 0x800BC5A0; 
var LINK_CRC = 0;

//Easy Access Hack, select Save & Load icon
//Disable this script to recover this functionality.
events.onexec(0x800BF654, function()
{
	gpr.pc = 0x800BF718;
});

//Send
//80284130 = Send 0x20 bytes to Link Cable function
//802842DC = take V0 value for Send response (PIF Data all right)
//80284300 = get response & check

events.onexec(0x80284130, function(addr)
{
	//Send Bytes
	GBCam_Send(gpr.a3);
	return;
	
	//Console Output
	var output = "Send: ";
	for (var i = 0; i < 0x20; i++)
	{
		output += mem.u8[gpr.a3 + i].hex()[6];
		output += mem.u8[gpr.a3 + i].hex()[7];
	}
	console.log(output);
});

events.onexec(0x802842DC, function(addr)
{
	//Get CRC
	LINK_CRC = gpr.v0 & 0xFF;
});

events.onexec(0x80284300, function(addr)
{
	//Remove PIF Command Error
	mem.u8[RAM_PIF_SEND + 2] = mem.u8[RAM_PIF_SEND + 2] & 0x2F;
	
	//Put some kind of CRC
	mem.u8[RAM_PIF_SEND + 0x26] = LINK_CRC;
});

//Recv
//802843E0 = Recv 0x20 bytes from Link Cable function
//80284560 = Recv response
//802845A0 = get reponse check
var RECV_ADDR = 0;
events.onexec(0x802843E0, function(addr)
{
	//Get Recv Buffer RAM Address
	RECV_ADDR = gpr.a3;
});

events.onexec(0x80284560, function(addr)
{
	//Remove PIF Command Error
	mem.u8[RAM_PIF_SEND + 2] = mem.u8[RAM_PIF_SEND + 2] & 0x2F;
});

events.onexec(0x802845A0, function(addr)
{
	//Put some kind of CRC
	LINK_CRC = gpr.v0 & 0xFF;
	mem.u8[RAM_PIF_SEND + 0x26] = LINK_CRC;
});

var sizep = 0;
events.onexec(0x80284658, function(addr)
{
	//Put Response to Buffer
	GBCam_Recv(RECV_ADDR);
	return;
	
	//Console Output
	var output = "Recv: ";
	for (var i = 0; i < 0x20; i++)
	{
		output += mem.u8[RECV_ADDR + i].hex()[6];
		output += mem.u8[RECV_ADDR + i].hex()[7];
	}
	console.log(output);
});

var check = 0;
var lengthdata = -1;
var lengthdatacheck = 0;
var byterecv = [];

var prevcmd = 0;
var cmd = 0;
var statusbyte = 0;
var intstatus = 0;

//Command Found for Transfer Pak Link (always 3 bytes?)
//C0 0A 28 - Transfer 0x20 bytes to Link Cable (Short Link)
//C0 1A 28 - Transfer 0x20 * 0x1A bytes to Link Cable (Long Link, used for Copy)
//40 0A 28 - ?

//Commands for Pocket Printer
const GBP_CMD_INIT = 0x1;
const GBP_CMD_PRINT = 0x2;
const GBP_CMD_COPY = 0x4;
const GBP_CMD_STOP = 0x8;
const GBP_CMD_NOP = 0xF;

//Commands for Pocket Printer Color
const GBPC_CMD_INIT = 0x1;
const GBPC_CMD_PREPRINT = 0x2;
const GBPC_CMD_COPY = 0x4;
const GBPC_CMD_POSTPRINT = 0x6;
const GBPC_CMD_STOP = 0x8;
const GBPC_CMD_NOP = 0xF;

function GBCam_Send(addr)
{
	//Do not respond to 83 dummy/init? command
	if (lengthdata < 0)
	{
		for (var i = 0; i < 0x20; i++)
		{
			if (mem.u8[addr + i] != 0x83)
			{
				break;
			}
			else if (i >= 0x1F)
				return;
		}
	}
	
	//Every byte sent has a response byte
	for (var i = 0; i < 0x20; i++)
	{
		var temp = 0;
		if (i == 0)
		{
			//This is probably just for the other kind of command which seems to be always 3 bytes.
			//Always leaving it in there no matter the command is fine.
			temp = 2;
		}
		
		if (lengthdata < 0)
		{
			//Deal with Pocket Printer Commands
			if (i == 0)
			{
				//Magic
				check = mem.u8[addr + i] << 8;
			}
			else if (i == 1)
			{
				check += mem.u8[addr + i];
			}
			else if (i == 2)
			{
				//CMD
				if (check == 0x8833)
				{
					prevcmd = cmd;
					cmd = mem.u8[addr + i];
					
					switch (cmd)
					{
						case GBP_CMD_INIT:
							statusbyte = 0;
							break;
						case GBP_CMD_PRINT:
							if (PRINTER_TYPE == 0)
								statusbyte = 0x04;
							else
								statusbyte = 0;
							break;
						case GBP_CMD_COPY:
							statusbyte = 0;
							break;
						case GBPC_CMD_POSTPRINT:
							statusbyte = 0x0C;
							break;
						case GBP_CMD_STOP:
							statusbyte = 0;
							break;
						case GBP_CMD_NOP:
							statusbyte = 0;
							if (prevcmd == GBP_CMD_COPY)
								statusbyte = 0x0C;
							break;
						default:
							console.log(cmd);
							break;
					}
				}
			}
			else if (i == 4)
			{
				//Get Data Packet Length
				lengthdatacheck = mem.u8[addr + i];
			}
			else if (i == 5)
			{
				lengthdatacheck += (mem.u8[addr + i] << 8);
				if (check == 0x8833 && lengthdata < 0)
				{
					//Data Packet Length ignores the first 6 bytes in every other 0x20 byte packet
					//So we add +6 for every single one for the sake of the script
					lengthdatacheck += (Math.floor(lengthdatacheck / 0x1A) * 6);
					
					//This is used for the proper response
					lengthdata = lengthdatacheck;
					lengthdata++;
				}
				else if (lengthdata < 0)
				{
					//Reset Data Length for response
					lengthdata = 1;
				}
			}
			else if (lengthdata == -2 && check == 0x8833)
			{
				//Keep Alive / Constant
				if (PRINTER_TYPE == 0)
					temp = 0x81;	//Pocket Printer
				else
					temp = 0x82;	//Pocket Printer Color
			}
			else if (lengthdata == -3 && check == 0x8833)
			{
				//Printer Status
				temp = statusbyte;
			}
			
		}
		
		lengthdata--;
		byterecv.push(temp);
	}
}

function GBCam_Recv(addr)
{
	//Put all response bytes in the buffer
	//The Transfer Pak Link Cable management probably contains a buffer big enough for most uses.
	for (var i = 0; i < 0x20; i++)
	{
		mem.u8[addr + i] = byterecv.shift();
	}
}