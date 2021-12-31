//64GB Cable / Pocket Printer Emulation Script by LuigiBlood
//Launch this script before booting a game or make sure to reset the game so the game can properly detect the hardware.
//This works in Recompiler and Interpreter Mode.

if (typeof PJ64_JSAPI_VERSION !== 'undefined') {
	console.clear();
	console.log("- 64GB Cable and Pocket Printer Emulator -");

	//Edit this: 0 = Pocket Printer - 1 = Pocket Printer Color
	const PRINTER_TYPE = 1;

	//Edit this: Controller to hijack (0 to 3)
	const CONTROLLER_ID = 3;

	//Edit this: Verbose
	const VERBOSE = 0;

	//----------------------------------------
	//N64 Controller Pak CRC
	function crc8(a) {
		//a = buffer(0x20)
		var addr = 0;
		var count = 0x20;
		var crc = 0;
		var calc = 0;

		do {
			calc = 0x80;

			do {
				crc <<= 1;
				if ((a[addr] & calc) == 0) {
					if ((crc & 0x100) != 0)
						crc ^= 0x85;
				} else {
					if ((crc & 0x100) == 0)
						crc++;
					else
						crc ^= 0x84;
				}
				calc >>= 1;
			} while (calc != 0);

			count--;
			addr++;
		} while (count != 0);

		do {
			crc <<= 1;
			if ((crc & 0x100) != 0)
				crc ^= 0x85;
			count++;
		} while (count < 8);

		return crc & 0xFF;
	}

	const cont_id = 0x0300;					//Controller ID
	const cont_ram = new Buffer(0x10000);	//Controller RAM
	var print_data = new Buffer(0x100000);	//Printer RAM
	var print_adr = 0x00;					//Current Printer RAM Address

	/*
		0x8000 = Init
		0xC000 = Status & Config
			0x00 = Status (0x02 = Acknowledged?)
			0x01 = Packet Size
		0xE000 = Link Send
		0xF000 = Link Recv
	*/

	//Printer ID (Regular / Color)
	var print_id = 0x81;
	if (PRINTER_TYPE != 0)
		print_id = 0x82;

	var print_count = -1;	//Status Delay
	var print_cmd = -1;		//Current Printer Command
	var print_len = -1;		//Printer Command Length
	var print_stat = 0;		//Current Printer Status
	var print_stat2 = 0;	//Delayed Printer Status
	var print_width = 0;	//Printer Image Width
	var print_height = 0;	//Printer Image Height

	/*
		Color Printer Status on Print Command:
		0x08 = Out of paper
		0x40 = Currently Printing
	*/

	function SaveColorImage()
	{
		//Save Image
		var filename = "print_";
		var num = 0;

		//Look for existing files to change file number to a non existing one
		const fileNames = fs.readdir('.');
		for(; fileNames.indexOf(filename + num + '.png') >= 0; num++);
		filename += num;

		//Get Height
		print_height = print_adr / 2 / print_width;
		console.log("Save Color Image to \"" + filename + ".png\" (" + print_width + "x" + print_height + ")");

		//Save RGBA5551 Image
		var image = new N64Image(print_width, print_height, IMG_RGBA16, print_data.slice(0, print_adr));
		
		//RAW
		//fs.writefile(filename + ".raw", print_data.slice(0, print_adr));

		//PNG
		fs.writefile(filename + ".png", image.toPNG());
	}

	function ConvertColorImage()
	{
		//Convert Color Data from ABGR1555 (LE) to N64 RGBA5551
		for (var i = 0; i < print_adr; i += 2)
		{
			var color = print_data.readUInt16LE(i);
			var r = color & 0x1F;
			var g = (color >> 5) & 0x1F;
			var b = (color >> 10) & 0x1F;
			var conv = (r << 11) | (g << 6) | (b << 1) | 1
			print_data.writeUInt16BE(conv, i);
		}
	}

	function ProcessGBPLink(cmd, addr)
	{
		//Output Link Data to console
		if (VERBOSE >= 2)
		{
			if (cmd == 0x13)
				console.print("CMD READ  0x" + cmd.hex(2) + " / ADDR: 0x" + addr.hex(4) + ": ");
			else
				console.print("CMD WRITE 0x" + cmd.hex(2) + " / ADDR: 0x" + addr.hex(4) + ": ");
			const test = cont_ram.slice(addr, addr + 0x20);
			for (var i = 0; i < 0x20; i++)
			{
				console.print(test[i].hex(2));
			}
			console.print("\n");
		}

		//Always output 0x02 (Acknowledge) to 0xC000
		if (cmd == 0x13 && addr == 0xC000)
		{
			cont_ram[addr] = 0x02;
		}


		if ((cmd != 0x14) || (addr != 0xE000))
			return;
		
		//Game Boy Printer Link Process
		const packet_size = cont_ram[0xC001];
		var data_start = 0;

		//If no command is processed, look for one
		if (print_cmd == -1)
		{
			//Magic
			if (cont_ram.readUInt16BE(0xE000) != 0x8833)
				return;
			print_cmd = cont_ram[0xE000 + 2];
			print_len = cont_ram.readUInt16LE(0xE000 + 4);

			data_start = 6;

			if (VERBOSE >= 1)
				console.print("GBP CMD: " + print_cmd.hex(1) + " - LEN: 0x" + print_len.hex(4) + " " + print_adr.hex(4));
		}

		//Process Command
		switch(print_cmd)
		{
			case 0x01:
				//Init
				print_stat = 0;
				print_adr = 0;
				break;
			case 0x02:
				if (PRINTER_TYPE == 0)
				{
					//Original Printer: Print
					print_stat = 0x06;	//Image Data Full + Currently Printing
					print_count = 50;
					print_stat2 = 0x04;	//Image Data Full
				}
				else
				{
					//Color Printer: Prepare Print (5 bytes)
					//Always receives 8009808080 / 8109808080
					//byte0.bit0 = 0 (Big)
					//             1 (Small)
					if ((cont_ram[0xE006] & 1) == 0)
					{
						print_width = 320;
					}
					else
					{
						print_width = 160;
					}
				}
				break;
			case 0x04:
				//Send Data
				print_stat = 0x08;	//Unprocessed Data Status

				var data_end = packet_size;
				if (packet_size > print_len)
					data_end = print_len + 6;

				for (var i = data_start; i < data_end; i++)
				{
					if ((print_adr + i) < print_data.length)
						print_data[print_adr + i - data_start] = cont_ram[0xE000 + i];
				}
				print_adr += data_end - data_start;
				break;
			case 0x06:
				//Color Printer (only): Print (4 bytes)
				//Always receives either 00000000 or 01000000
				//byte0.bit0 = 0 (?)
				//             1 (Print) (used when reprinting)
				print_stat = 0x40;	//Currently Printing
				print_count = 50;
				print_stat2 = 0x00;
				if (cont_ram[0xE006] != 0)
					SaveColorImage();
				else
					ConvertColorImage();
				break;
			case 0x08:
				//Stop
				print_stat = 0x00;
				break;
			case 0x0F:
				//Status / NOP
				if (print_stat == 0x08)
					print_stat = 0x0C;	//Unprocessed Data + Image Data Full
				break;
		}

		//Delay Counter
		if (print_count >= 0)
			print_count--;
		//Update Status when Delay Count is 0
		if (print_count == 0)
			print_stat = print_stat2;

		//Manage ID and Status at the end of the link packet
		print_len -= packet_size;
		if (print_len <= 0)
		{
			//Put ID and Status
			print_len += packet_size;
			cont_ram[0xF006 + 2 + print_len + 0] = print_id;
			cont_ram[0xF006 + 2 + print_len + 1] = print_stat;

			//Reset Command
			print_cmd = -1;
			print_len = -1;

			if (VERBOSE >= 1)
				console.print(" - ID:" + print_id.hex(2) + " - STAT: 0x" + print_stat.hex(2) + "\n");
		}
	}

	function ProcessController(id, cmdAddr)
	{
		//Process PIF Controller Command
		const send = mem.u8[PIF_RAM_START + cmdAddr + 0] & 0x3F;
		const recv = mem.u8[PIF_RAM_START + cmdAddr + 1] & 0x3F;
		const error = mem.u8[PIF_RAM_START + cmdAddr + 1] & 0xC0;

		const sendDataAddr = PIF_RAM_START + cmdAddr + 2;
		const recvDataAddr = PIF_RAM_START + cmdAddr + 2 + send;

		const cmd = mem.u8[sendDataAddr];

		//Strip Error Info
		mem.u8[PIF_RAM_START + cmdAddr + 1] &= 0x3F;

		if (cmd == 0x00 || cmd == 0xFF)
		{
			//Info / Reset
			if (send != 0x01 || recv != 0x03)
			{
				//Return Error if the send/recv info is wrong
				mem.u8[PIF_RAM_START + cmdAddr + 1] |= 0x40;
				return;
			}
			
			//Controller ID
			mem.u8[recvDataAddr + 0] = cont_id & 0xFF;
			mem.u8[recvDataAddr + 1] = (cont_id >> 8) & 0xFF;
			//Controller Status
			mem.u8[recvDataAddr + 2] = 0x00;

			console.log("64GB Cable ID has responded at Controller Port " + (id + 1));
		}
		else if (cmd == 0x13)
		{
			//MBC4 Read
			if (send != 0x03 || recv != 0x21)
			{
				//Return Error if the send/recv info is wrong
				mem.u8[PIF_RAM_START + cmdAddr + 1] |= 0x40;
				return;
			}

			//Works like the Controller Paks
			const contaddr = ((mem.u8[sendDataAddr + 1] << 8) + mem.u8[sendDataAddr + 2]) & 0xFFE0;
			const contcrca = mem.u8[sendDataAddr + 2] & 0x1F;

			//Slice Requested Data
			const contdata = cont_ram.slice(contaddr, contaddr + 0x20);

			//Copy Data to PIF RAM
			mem.setblock(recvDataAddr, contdata, 0x20);
			mem.u8[recvDataAddr + 0x20] = crc8(contdata);

			//Process Link
			ProcessGBPLink(cmd, contaddr);
		}
		else if (cmd == 0x14)
		{
			//MBC4 Write
			if (send != 0x23 || recv != 0x01)
			{
				//Return Error if the send/recv info is wrong
				mem.u8[PIF_RAM_START + cmdAddr + 1] |= 0x40;
				return;
			}

			//Works like the Controller Paks
			const contaddr = ((mem.u8[sendDataAddr + 1] << 8) + mem.u8[sendDataAddr + 2]) & 0xFFE0;
			const contcrca = mem.u8[sendDataAddr + 2] & 0x1F;

			//Copy Data from PIF RAM
			const contdata = mem.getblock(sendDataAddr + 3, 0x20);

			//Slice Requested Data
			var contdataslice = cont_ram.slice(contaddr, contaddr + 0x20);

			//Copy Data
			for (var i = 0; i < 0x20; i++)
				contdataslice[i] = contdata[i];

			mem.u8[recvDataAddr] = crc8(contdata);

			//Process Link
			ProcessGBPLink(cmd, contaddr);
		}
		else
		{
			//Return Error if invalid command
			mem.u8[PIF_RAM_START + cmdAddr + 1] |= 0x80;
			return;
		}
	}

	function BreakPIF()
	{
		//Show PIF RAM
		debug.showmemory(PIF_RAM_START);
	}

	events.onpifread(function() {
		//0xFF = padding
		//0xFE = end
		//0xFD = skip
		//0x00 = null, go to next channel

		//Find Controller
		var channel = -1;
		var cmdAddr = 0;

		for (cmdAddr = 0; cmdAddr < 0x40; cmdAddr++)
		{
			const value = mem.u8[PIF_RAM_START + cmdAddr];

			//If controller ID not found then don't bother
			if (value == 0xFE)
				return;
			
			//Skip Padding bytes
			if (value != 0xFF && value != 0xFD)
			{
				//Found Channel
				channel++;

				if (VERBOSE >= 3)
					console.log("PIF: Channel " + channel + " at 0x" + (PIF_RAM_START + cmdAddr).hex(8));
				
				if (channel == CONTROLLER_ID)
				{
					//Found Controller ID, stop loop and process
					break;
				}
				else
				{
					//If not Controller ID, then skip the data
					if (value != 0x00)
					{
						var skip = 2;
						skip += mem.u8[PIF_RAM_START + cmdAddr + 0];
						skip += mem.u8[PIF_RAM_START + cmdAddr + 1] & 0x3F;
						cmdAddr += skip - 1;
					}
				}
			}
		}

		//Make sure to not read further than the PIF RAM size
		if (cmdAddr >= 0x40)
			return;
		
		//Process Controller PIF Response
		ProcessController(channel, cmdAddr);
	});
}
else
{
	console.log("Requires Project64 4.0+ to use it.");
}
