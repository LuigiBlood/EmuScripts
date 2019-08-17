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
	GBT_Send(gpr.a3);
	return;
	
	//Console Output
	if (prevcmd == GBP_CMD_COPY && lengthdata > 0)
		return;
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
	GBT_Recv(RECV_ADDR);
	return;
	
	//Console Output
	if (prevcmd == GBP_CMD_COPY && lengthdata > 0)
		return;
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
var bytesizerecv = [];
var sizedata = 0x20;
var transfermode = 0;

var prevcmd = 0;
var cmd = 0;
var statusbyte = 0;
var intstatus = 0;

var fileBuffer = new Buffer(0x100000);
var fileBufferOffset = 0;
var fileBufferOffset2 = 0;
var file;

//Transfer Pak Link Commands (always 3 bytes)

//Wake Up / Init = Send 0x20 bytes of 0x83

//Transfer Command Packet = Send XX YY ZZ
//XX = 0xC0 (First Transfer after Wake Up)
//     0x40 (All subsequent transfers)
//YY = Data Packet Size in bytes
//ZZ = 0x28 (First Transfer after Wake Up)
//     0x12 (All subsequent transfers)

//Then Send a Data Packet
//All packets sent have their response (always begins with 0x02, else retry), including the Transfer Pak Command Packet.
//Which means the packets response is shifted by one packet so you have to receive one another for the actual response.


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

function GBT_Send(addr)
{
	//Deal with Transfer Pak Link Commands

	//Wake Up
	for (var i = 0; i < 0x20; i++)
	{
		if (mem.u8[addr + i] != 0x83)
		{
			break;
		}
		else if (i >= 0x1F)
			return;
	}
	
	//Deal with Transfer Pak Link Command
	if (mem.u8[addr + 0] == 0xC0 || mem.u8[addr + 0] == 0x40)
	{
		if (mem.u8[addr + 2] == 0x28 || mem.u8[addr + 2] == 0x12)
		{
			//Get Size Data
			sizedata = mem.u8[addr + 1];
			
			if (transfermode == 0)
			{
				//Add Response
				for (var i = 0; i < sizedata; i++)
				{
					byterecv.push(0);
				}
				bytesizerecv.push(sizedata);
			}
			
			transfermode = 1;
			return;
		}
	}
	
	//Every byte sent has a response byte
	for (var i = 0; i < sizedata; i++)
	{
		var temp = 0;
		if (transfermode == 1)
		{
			//Transfer Image Data to Buffer
			if ((cmd == GBP_CMD_COPY) && (lengthdata > 0))
			{
				fileBuffer[fileBufferOffset] = mem.u8[addr + i];
				fileBufferOffset++;
			}
			if (lengthdata <= 0)
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
								//fileBuffer = [];
								fileBufferOffset = 0;
								fileBufferOffset2 = 0;
								break;
							case GBP_CMD_PRINT:
								if (PRINTER_TYPE == 0)
								{
									statusbyte = 0x04;
									GBPrinter_OutputImage(160);
								}
								else
								{
									statusbyte = 0;
								}
								break;
							case GBP_CMD_COPY:
								statusbyte = 0;
								break;
							case GBPC_CMD_POSTPRINT:
								statusbyte = 0x0C;
								if (prevcmd != GBPC_CMD_POSTPRINT)
								{
									GBPrinter_OutputImage(lengthdatacheck / 2);
								}
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
					if (check == 0x8833 && lengthdata <= 0)
					{
						//Deal with Data
						lengthdata = lengthdatacheck + 1;
					}
					else if (lengthdata <= 0)
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
		}
		byterecv.push(temp);
	}
	bytesizerecv.push(sizedata);
}

function GBT_Recv(addr)
{
	//Put all response bytes in the buffer
	//The Transfer Pak Link Cable management probably contains a buffer big enough for most uses.
	var sizecur = bytesizerecv.shift();
	
	for (var i = 0; i < 0x20; i++)
	{
		if (i < sizecur)
			mem.u8[addr + i] = byterecv.shift();
		else
			mem.u8[addr + i] = 0;
		
		if (i == 0)
			mem.u8[addr + i] = 2;
	}
	
	if (byterecv.length <= 0)
		transfermode = 0;
}

function GBPrinter_OutputImage(_width)
{
	//Output RAW Image
	var filename = "test_";
	var num = 0;
	for (; fs.stat(filename + num + ".bin"); num++);
	
	file = fs.open(filename + num + ".bin", 'wb+');
	fs.write(file, fileBuffer, 0, fileBufferOffset);
	fs.close(file);
	console.log("Written \"" + filename + num + ".bin" + "\" - w:" + _width);
}