console.log("SmartMedia Simulation");

var VERBOSE = 0;

function Verbose(id, out) {
	if (VERBOSE >= id) {
		console.log(out);
	}
}

function VerbosePrint(id, out) {
	if (VERBOSE >= id) {
		console.print(out);
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

var readaddr, readreg, readdata, callbackId;
function ReadCartRegSetup(_addr, _data) {
	readaddr = _addr;
	readreg = getStoreOp();
	readdata = _data;
	callbackId = events.onexec((gpr.pc + 4), ReadCartReg);
}

function ReadCartReg()
{
    //Verbose(3, "Read: " + readaddr.hex() + " (" + readdata.hex() + ")");
    gpr[readreg] = readdata;
    //debug.breakhere();
    events.remove(callbackId);
}

//Address Definitions
const PTP_ADDR_CRYPTO = new AddressRange(0xAFE70000, 0xAFE70013);
const PTP_ADDR_CARD1 = new AddressRange(0xAFE70100, 0xAFE7013F);
const PTP_ADDR_CARD2 = new AddressRange(0xAFE70140, 0xAFE7017F);

//Register Definitions
const PTP_CARD = {
	STAT:			0x00,
	CMD:			0x04,
	ADDR:			0x08,
	DATA:			0x0C,
	ECC_ADDR_HI:	0x10,
	ECC_ADDR_LO:	0x14,
	ECC_ERR_HI:		0x18,
	ECC_ERR_LO:		0x1C,
	MAGIC_LO:		0x20,
	MAGIC_HI:		0x24,
	UNLOCK:			0x3C,
}

const PTP_CARD_DEF = {
	RD: {
		STAT: {
			DEFAULT:		0x43,
			BIT0:			0x01,
			BIT1:			0x02,
			EMPTY:			0x04,
			READONLY:		0x08,
			BUSY_READ:		0x10,
			BUSY_WRITE:		0x10,
			BUSY_SERIAL:	0x20,
			BIT6:			0x40,
			BUSY_CMD:		0x80,
		},
		CMD: {
			CARD_PRESENT:	0x04,
			STATUS: {
				WRITE_FAIL:			0x01,
				READY:				0x40,
				WR_PROTECT_DISABLE:	0x80,
			},
		},
	},
	WR: {
		STAT: {
			UNKNOWN:		0x11,
			ECC_DISABLE:	0x20,
			NAND_ENABLE:	0x40,	//64MB and more
			HALFSIZE:		0x80,	//2MB and less
		},
		CMD: {
			READ:		0x00,
			READ_HI:	0x01,
			WRITE:		0x10,		//Write Buffer to Address
			READ_PAGE:	0x50,
			ERASE:		0x60,
			STATUS:		0x70,
			WR_BUF:		0x80,		//Write to Buffer
			READ_ID:	0x90,
			CONFIRM:	0xD0,		//To confirm Erase
			RESET:		0xFF,
		},
	},

}

//Object
var MGR_CARD_BASE = {
	//Definitions
	REG: {
		RD: {
			STAT: PTP_CARD_DEF.RD.STAT.DEFAULT | PTP_CARD_DEF.RD.STAT.EMPTY,
			CMD: 0,
			ECC_ADDR_HI: 0,
			ECC_ADDR_LO: 0,
			ECC_ERR_HI: 0,
			ECC_ERR_LO: 0,
			MAGIC_LO: 0,	//Seed
			MAGIC_HI: 0,	//Seed
		},
		WR: {
			STAT: 0,
			CMD: 0,
			ADDR: 0,
			MAGIC_LO: 0,	//Response
			MAGIC_HI: 0,	//Response
			UNLOCK: 0,
		},
	},
	PAGE_ADDRESS: 0,		//Offset to Page in File
	ADDRESS: 0,				//Offset IN Page
	COUNT: 0,
	ADDRESS_BASE: 0,
	LAST_RD: 0,				//Last Read Command
	ADDR_COUNT: 0,
	RANGE_START: 1,
	FILE_NAME: '',
	FILE_BUF: Buffer(0x210 * 16),
	FILE_ACS: false,
	FILE_RDONLY: false,

	//Functions
	SetUp: function(_filename, _range) {
		this.FILE_NAME = _filename;
		this.RANGE_START = _range;
		Verbose(2, "Set filename \"" + this.FILE_NAME + "\" and range " + this.RANGE_START.hex());
	},
	
	OpenFile: function() {
		if (this.IsFileOpen())
			return;

		this.FILE_ACS = fs.open(this.FILE_NAME, 'rb+');

		if (this.IsFileOpen()) {
			//Insert
			Verbose(0, "Slot " + this.GetCardSlot() + ": " + this.FILE_NAME + " is open.");
			this.FILE_RDONLY = false;
			this.REG.RD.STAT &= ~PTP_CARD_DEF.RD.STAT.EMPTY;
			this.REG.RD.STAT &= ~PTP_CARD_DEF.RD.STAT.READONLY;
			this.REG.RD.CMD |= PTP_CARD_DEF.RD.CMD.CARD_PRESENT;
		} else {
			//Try Read only
			this.OpenFileReadOnly();
		}
	},
	OpenFileReadOnly: function() {
		if (this.IsFileOpen())
			return;
		
		this.FILE_ACS = fs.open(this.FILE_NAME, 'rb');

		if (this.IsFileOpen()) {
			//Insert
			Verbose(0, "Slot " + this.GetCardSlot() + ": " + this.FILE_NAME + " is open. (Read Only)");
			this.FILE_RDONLY = true;
			this.REG.RD.STAT &= ~PTP_CARD_DEF.RD.STAT.EMPTY;
			this.REG.RD.STAT |= PTP_CARD_DEF.RD.STAT.READONLY;
			this.REG.RD.CMD |= PTP_CARD_DEF.RD.CMD.CARD_PRESENT;
		} else {
			//Remove
			Verbose(0, "Slot " + this.GetCardSlot() + ": " + this.FILE_NAME + " couldn't be opened.");
			this.REG.RD.STAT = PTP_CARD_DEF.RD.STAT.DEFAULT | PTP_CARD_DEF.RD.STAT.EMPTY;
			this.REG.RD.CMD &= ~PTP_CARD_DEF.RD.CMD.CARD_PRESENT;
		}
	},
	CloseFile: function() {
		if (!this.IsFileOpen())
			return;

		fs.close(this.FILE_ACS);
		this.FILE_ACS = false;
		//Remove
		Verbose(0, "Slot " + this.GetCardSlot() + ": " + this.FILE_NAME + " is closed.");
		this.REG.RD.STAT |= PTP_CARD_DEF.RD.STAT.EMPTY;
		this.REG.RD.STAT &= ~PTP_CARD_DEF.RD.STAT.READONLY;
		this.REG.RD.CMD &= ~PTP_CARD_DEF.RD.CMD.CARD_PRESENT;
	},
	ReadFile: function() {
		if (!this.IsFileOpen())
			return;
		fs.read(this.FILE_ACS, this.FILE_BUF, 0, 0x210 * 16, this.PAGE_ADDRESS);
	},
	WriteFile: function() {
		if (!this.IsFileOpen() && this.FILE_RDONLY)
			return;
		if (this.LAST_RD != PTP_CARD_DEF.WR.CMD.READ_PAGE)
			fs.write(this.FILE_ACS, this.FILE_BUF, 0, this.COUNT, this.PAGE_ADDRESS + this.ADDRESS_BASE);
		else {
			console.log("Stop.");
			debug.breakhere();
		}
	},
	EraseFile: function() {
		if (!this.IsFileOpen() && this.FILE_RDONLY)
			return;
		fs.write(this.FILE_ACS, this.FILE_BUF, 0, this.GetPageSize() * 16, this.PAGE_ADDRESS);
	},
	IsFileOpen: function() {
		return (this.FILE_ACS != false);
	},
	GetCardSlot: function() {
		return ((this.RANGE_START - 0xAFE70100) / 0x40);
	},
	GetPageSize: function() {
		if ((this.REG.WR.STAT & PTP_CARD_DEF.WR.STAT.HALFSIZE) != 0)
			return 0x108;
		else
			return 0x210;
	},

	SetMagic: function(magic) {
		this.REG.RD.MAGIC_LO = magic & 0xFF;
		this.REG.RD.MAGIC_HI = magic >> 8;
	},
	SetAddress: function() {
		const cmd = this.REG.WR.CMD;
		//Set Page / Block		
		if (cmd != PTP_CARD_DEF.WR.CMD.ERASE)
			this.PAGE_ADDRESS = (this.REG.WR.ADDR >> 8) * this.GetPageSize();
		else
			this.PAGE_ADDRESS = ((this.REG.WR.ADDR & 0xFFFFF000) >> 8) * this.GetPageSize();

		//Set Column
		this.ADDRESS = this.REG.WR.ADDR & 0xFF;
		//Set Offset
		switch (this.LAST_RD) {
			case PTP_CARD_DEF.WR.CMD.READ:
				break;
			case PTP_CARD_DEF.WR.CMD.READ_HI:
				this.ADDRESS += 0x100;
				break;
			case PTP_CARD_DEF.WR.CMD.READ_PAGE:
				this.ADDRESS &= 0xF;
				if ((this.REG.WR.STAT & PTP_CARD_DEF.WR.STAT.HALFSIZE) != 0)
					this.ADDRESS += 0x100;
				else
					this.ADDRESS += 0x200;
				break;
		}

		this.ADDRESS_BASE = this.ADDRESS;
		this.COUNT = 0;
	},
	ManageCommand: function() {
		const cmd = this.REG.WR.CMD;
		VerbosePrint(1, "\r\n" + "Slot " + this.GetCardSlot() + ": CMD: " + cmd.hex(2) + " ");
		//Verbose(2, "Issued Command " + cmd.hex());

		switch (cmd) {
			case PTP_CARD_DEF.WR.CMD.READ:
			case PTP_CARD_DEF.WR.CMD.READ_HI:
				this.LAST_RD = cmd;
			case PTP_CARD_DEF.WR.CMD.WR_BUF:
				this.REG.WR.ADDR = 0;
				this.ADDR_COUNT = 0;
				break;
			case PTP_CARD_DEF.WR.CMD.READ_PAGE:
				this.LAST_RD = cmd;
				this.REG.WR.ADDR = 0;
				this.ADDR_COUNT = 0;
				break;
			case PTP_CARD_DEF.WR.CMD.ERASE:
				for (var i = 0; i < 0x210; i++)
					this.FILE_BUF[i] = 0xFF;
				this.REG.WR.ADDR = 0;
				this.ADDR_COUNT = 1;
				break;
			case PTP_CARD_DEF.WR.CMD.STATUS:
				this.ADDRESS = 0;
				this.FILE_BUF[0] = PTP_CARD_DEF.RD.CMD.STATUS.READY;
				this.FILE_BUF[0] |= PTP_CARD_DEF.RD.CMD.STATUS.WR_PROTECT_DISABLE;
				break;
			case PTP_CARD_DEF.WR.CMD.READ_ID:
				this.ADDRESS = 0;
				this.FILE_BUF[0] = 0x98;
				this.FILE_BUF[1] = 0xEA;
				break;
			case PTP_CARD_DEF.WR.CMD.WRITE:
				this.WriteFile();
				break;
			case PTP_CARD_DEF.WR.CMD.CONFIRM:
				this.EraseFile();
				break;
			case PTP_CARD_DEF.WR.CMD.RESET:
				this.REG.WR.ADDR = 0;
				this.ADDRESS = 0;
				for (var i = 0; i < 0x210; i++)
					this.FILE_BUF[i] = 0xFF;
				break;
		}
	},
	ManageAddress: function() {
		const cmd = this.REG.WR.CMD;

		this.REG.WR.ADDR &= ~(0xFF << (8 * this.ADDR_COUNT));
		this.REG.WR.ADDR |= getStoreOpValue() << (8 * this.ADDR_COUNT);
		this.ADDR_COUNT++;

		VerbosePrint(1, " " + getStoreOpValue().hex(2));

		if (this.ADDR_COUNT >= 3)
		{
			this.SetAddress();
			//Verbose(2, "Issued Address " + this.REG.WR.ADDR.hex());
		}

		switch (cmd) {
			case PTP_CARD_DEF.WR.CMD.READ:
			case PTP_CARD_DEF.WR.CMD.READ_HI:
			case PTP_CARD_DEF.WR.CMD.READ_PAGE:
				this.ReadFile();
				break;
			case PTP_CARD_DEF.WR.CMD.WR_BUF:
			case PTP_CARD_DEF.WR.CMD.ERASE:
				break;
		}
	},

	//Events
	RegRead: function(addr) {
		var reg_addr = addr - this.RANGE_START;

		//Verbose(3, "Read: " + reg_addr.hex() + " (" + addr.hex() + ")" + this.RANGE_START.hex());

		switch (reg_addr) {
			case PTP_CARD.STAT:
				//Verbose(3, "Read: " + addr.hex() + " (" + this.REG.RD.STAT.hex(2) + ")");
				ReadCartRegSetup(addr, this.REG.RD.STAT);
				break;
			case PTP_CARD.CMD:
				ReadCartRegSetup(addr, this.REG.RD.CMD);
				break;
			case PTP_CARD.ADDR:
				ReadCartRegSetup(addr, 0xFF);
				break;
			case PTP_CARD.DATA:
				if ((this.ADDRESS & 0xF) == 0)
					VerbosePrint(3, "\r\n" + this.ADDRESS.hex(3) + ": ");
				VerbosePrint(3, this.FILE_BUF[this.ADDRESS].hex(2));
				ReadCartRegSetup(addr, this.FILE_BUF[this.ADDRESS]);
				this.ADDRESS++;
				if (this.ADDRESS_RD == 1) {
					if ((this.REG.WR.STAT & PTP_CARD_DEF.WR.STAT.HALFSIZE) != 0) {
						//256+8
						if (this.ADDRESS % (256+8) < 256)
							this.ADDRESS += 256 - (this.ADDRESS % (256+8));
					} else {
						//512+16
						if (this.ADDRESS % (512+16) < 512)
							this.ADDRESS += 512 - (this.ADDRESS % (512+16));
					}
				}
				break;
			case PTP_CARD.ECC_ADDR_HI:
				Verbose(3, "Read: " + addr.hex() + " (" + this.REG.RD.ECC_ADDR_HI.hex(2) + ")");
				ReadCartRegSetup(addr, this.REG.RD.ECC_ADDR_HI);
				break;
			case PTP_CARD.ECC_ADDR_LO:
				Verbose(3, "Read: " + addr.hex() + " (" + this.REG.RD.ECC_ADDR_LO.hex(2) + ")");
				ReadCartRegSetup(addr, this.REG.RD.ECC_ADDR_LO);
				break;
			case PTP_CARD.ECC_ERR_HI:
				Verbose(3, "Read: " + addr.hex() + " (" + this.REG.RD.ECC_ERR_HI.hex(2) + ")");
				ReadCartRegSetup(addr, this.REG.RD.ECC_ERR_HI);
				break;
			case PTP_CARD.ECC_ERR_LO:
				Verbose(3, "Read: " + addr.hex() + " (" + this.REG.RD.ECC_ERR_LO.hex(2) + ")");
				ReadCartRegSetup(addr, this.REG.RD.ECC_ERR_LO);
				break;
			case PTP_CARD.MAGIC_LO:
				Verbose(3, "Read: " + addr.hex() + " (" + this.REG.RD.MAGIC_LO.hex(2) + ")");
				ReadCartRegSetup(addr, this.REG.RD.MAGIC_LO);
				break;
			case PTP_CARD.MAGIC_HI:
				Verbose(3, "Read: " + addr.hex() + " (" + this.REG.RD.MAGIC_HI.hex(2) + ")");
				ReadCartRegSetup(addr, this.REG.RD.MAGIC_HI);
				break;
		}
	},
	RegWrite: function(addr) {
		var reg_addr = addr - this.RANGE_START;

		switch (reg_addr) {
			case PTP_CARD.STAT:
				Verbose(3, "Write: " + addr.hex() + " - " + getStoreOpValue().hex(2));
				this.REG.WR.STAT = getStoreOpValue();
				break;
			case PTP_CARD.CMD:
				this.REG.WR.CMD = getStoreOpValue();
				this.ManageCommand();
				break;
			case PTP_CARD.ADDR:
				this.ManageAddress();
				break;
			case PTP_CARD.DATA:
				this.FILE_BUF[this.ADDRESS] = getStoreOpValue();
				this.ADDRESS++;
				this.COUNT++;
				break;
			case PTP_CARD.MAGIC_LO:
				Verbose(3, "Write: " + addr.hex() + " - " + getStoreOpValue().hex(2));
				this.REG.WR.MAGIC_LO = getStoreOpValue();
				break;
			case PTP_CARD.MAGIC_HI:
				Verbose(3, "Write: " + addr.hex() + " - " + getStoreOpValue().hex(2));
				this.REG.WR.MAGIC_HI = getStoreOpValue();
				break;
			case PTP_CARD.UNLOCK:
				Verbose(3, "Write: " + addr.hex() + " - " + getStoreOpValue().hex(2));
				this.REG.WR.UNLOCK = getStoreOpValue();
				break;
		}
	},
}

var MGR_CARD1, MGR_CARD2;
MGR_CARD1 = Object.create(MGR_CARD_BASE);
MGR_CARD2 = Object.create(MGR_CARD_BASE);

MGR_CARD1.SetUp('card1.sm', 0xAFE70100);
MGR_CARD2.SetUp('card2.sm', 0xAFE70140);
MGR_CARD1.SetMagic(0xFFF0);
MGR_CARD2.SetMagic(0xC000);

events.onread(PTP_ADDR_CARD1, function(addr) { MGR_CARD1.RegRead(addr) });
events.onwrite(PTP_ADDR_CARD1, function(addr) { MGR_CARD1.RegWrite(addr) });
events.onread(PTP_ADDR_CARD2, function(addr) { MGR_CARD2.RegRead(addr) });
events.onwrite(PTP_ADDR_CARD2, function(addr) { MGR_CARD2.RegWrite(addr) });

function InsertCard(num) {
	if (num == 0)
		MGR_CARD1.OpenFile();
	else
		MGR_CARD2.OpenFile();
}

function RemoveCard(num) {
	if (num == 0)
		MGR_CARD1.CloseFile();
	else
		MGR_CARD2.CloseFile();
}
