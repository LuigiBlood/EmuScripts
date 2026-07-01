-----------------------
-- Name: SPC Helper (SNES)
-- Author: LuigiBlood
-----------------------

local consoleType = emu.getState()["consoleType"]
if consoleType ~= "Snes" then
  emu.displayMessage("Script", "This script only works on the SNES.")
  return
end

state = emu.getState()
emu.selectDrawSurface(emu.drawSurface.scriptHud, 1)

preMouseState = emu.getMouseState()
curMouseState = emu.getMouseState()
values = {0, 0, 0, 0}

--Style
--Normal, Hover, Click
bgPalette = {0x30C0C0C0, 0x30E0E0E0, 0x30C0C0C0, 0x302060FF, 0x30FFFFFF, 0x30000000}
--Top Left Shade
fgPalette1 = {0x30F0F0F0, 0x30F0F0F0, 0x30505050, 0x30FF4040, 0x30505050, 0xFF000000}
--Bottom Right Shade
fgPalette2 = {0x30505050, 0x30505050, 0x30F0F0F0, 0x30FF4040, 0x30505050, 0xFF000000}
txPalette = {0x00000000, 0x00000000, 0x00000000, 0x00FFFFFF, 0x00000000, 0x00FFFFFF}

--SPC Helper States
config = {
	starfox2 = false
}
flagSaveNextNote = false
flagSaveTimerStart = false
timerStart = false
timer = 0
jump = 0
callback_jumpcheck = nil
callback_endcheck = nil

--Util
function checkMouseBox(x, y, w, h)
	return (curMouseState.x >= x and curMouseState.x < x+w and curMouseState.y >= y and curMouseState.y < y+h)
end

function checkMouseLeftClick()
	return (preMouseState.left == false and curMouseState.left == true)
end

function checkMouseLeftHold()
	return (curMouseState.left == true)
end

function fileExists(name)
	-- why does it work when it's opposite..?
	local f = io.open(name, "rb")
	if (f) then
		f:close()
		return false
	end
	return true
end

--Immediate GUI
function rectangleUI(x, y, w, h, p)
	p = p or 1
	local curBgColor = bgPalette[p]
	local curFgColor1 = fgPalette1[p]
	local curFgColor2 = fgPalette2[p]
	
	emu.drawRectangle(x, y, w, h, curBgColor, true)
	emu.drawRectangle(x, y, w, 1, curFgColor1, false)
    emu.drawRectangle(x, y+1, 1, h-2, curFgColor1, false)
    
    emu.drawRectangle(x, y+h-1, w, 1, curFgColor2, false)
    emu.drawRectangle(x+w-1, y+1, 1, h-1, curFgColor2, false)
end

function textUI(x, y, txt, p)
	p = p or 1
	local curTxColor = txPalette[p]
	
	emu.drawString(x, y, txt, curTxColor, 0xFF000000)
end

function arrowUI(x, y, t, p)
	p = p or 1
	local curColorType = p + 0
	local click = false
	local held = 0
	if (checkMouseBox(x, y, 11, 7)) then
		curColorType = p + 1
		if checkMouseLeftHold() == true then
			curColorType = p + 2
			held = 1
		end
		if checkMouseLeftClick() == true then
			click = true
		end
	end
	
	local curTxColor = txPalette[curColorType]
	
	rectangleUI(x+held, y+held, 11, 7, curColorType)
	if t then
	    emu.drawRectangle(x+5+held, y+2+held, 1, 1, curTxColor, false)
	    emu.drawRectangle(x+4+held, y+3+held, 3, 1, curTxColor, false)
	    emu.drawRectangle(x+3+held, y+4+held, 5, 1, curTxColor, false)
    else
	    emu.drawRectangle(x+5+held, y+4+held, 1, 1, curTxColor, false)
	    emu.drawRectangle(x+4+held, y+3+held, 3, 1, curTxColor, false)
	    emu.drawRectangle(x+3+held, y+2+held, 5, 1, curTxColor, false)
    end
    
    return click
end

function arrowUpUI(x, y, p)
	p = p or 1
	return arrowUI(x, y, true, p)
end

function arrowDnUI(x, y, p)
	p = p or 1
	return arrowUI(x, y, false, p)
end

function textBoxUI(x, y, txt, p)
	p = p or 1
	local widthString = emu.measureString(txt)
	
	rectangleUI(x, y, 4+widthString.width, 4+widthString.height, p)
    textUI(x+2, y+3, txt, p)
end

function buttonUI(x, y, txt, p)
	p = p or 1
	
	local widthString = emu.measureString(txt)
	
	local curColorType = p + 0
	local click = false
	local held = 0
	--first Digit Up
	if (checkMouseBox(x, y, 4+widthString.width, 4+widthString.height)) then
		curColorType = p + 1
		if checkMouseLeftHold() == true then
			curColorType = p + 2
			held = 1
		end
		if checkMouseLeftClick() == true then
			click = true
		end
	end

	textBoxUI(x+held, y+held, txt, curColorType)
    
    return click
end

function checkBoxUI(x, y, txt, var, p)
	p = p or 1
	local widthString = emu.measureString(txt)
	
	local curColorType = p + 0
	local click = false
	
	if (checkMouseBox(x, y, 12+widthString.width, widthString.height)) then
		if checkMouseLeftClick() == true then
			click = true
		end
	end
	
	if click then
		config[var] = not config[var]
	end
	
	local check = config[var]

	emu.drawRectangle(x, y, 7, 7, 0xFFFFFF, check)
	textUI(x+12, y, txt, curColorType)
	
	return click
end

function numberBoxUI(x, y, v)
	rectangleUI(x,y,22,11)
    textUI(x+3, y+2, string.format('%1X', v >> 4))
    textUI(x+14, y+2, string.format('%1X', v & 0x0F))
end

function numberModUI(x, y, val)
	numberBoxUI(x, y+8, values[val])
	
	if arrowUpUI(x, y) == true then
		values[val] = (values[val] + 0x10) & 0xFF
	end
    if arrowDnUI(x, y+20) == true then
		values[val] = (values[val] - 0x10) & 0xFF
	end
	if arrowUpUI(x+11, y) == true then
		values[val] = ((values[val] + 0x01) & 0x0F) + (values[val] & 0xF0)
	end
    if arrowDnUI(x+11, y+20) == true then
		values[val] = ((values[val] - 0x01) & 0x0F) + (values[val] & 0xF0)
	end
end

--SPC Test
function makeSPC()
	--check if file exists
	SPCnumber = 1
	SPCpath = emu.getScriptDataFolder() .. "/" .. emu.getRomInfo()["name"] .. "_" .. SPCnumber .. ".spc"
	while (not fileExists(SPCpath)) do
		SPCnumber = SPCnumber + 1
		SPCpath = emu.getScriptDataFolder() .. "/" .. emu.getRomInfo()["name"] .. "_" .. SPCnumber .. ".spc"
	end
	state = emu.getState()
	local outSpc = io.open(SPCpath, "wb")
	
	outSpc:write("SNES-SPC700 Sound File Data v0.30")
	outSpc:write(string.pack("BBBB", 0x1A, 0x1A, 0x1B, 30))
	outSpc:write(string.pack("HBBBBB", state["spc.pc"], state["spc.a"], state["spc.x"], state["spc.y"], state["spc.ps"], state["spc.sp"]))	--APU State
	for i = -1, 210 do outSpc:write("\x00") end
	for i = 0, emu.getMemorySize(emu.memType.spcMemory)-1 do
		if (i == 0xF0 or i == 0xF1 or i == 0xFA or i == 0xFB or i == 0xFC) then
			outSpc:write(string.pack("B", emu.read(i, emu.memType.spcRam, false)))
		else
			outSpc:write(string.pack("B", emu.read(i, emu.memType.spcMemory, false)))
		end
	end
	for i = 0, emu.getMemorySize(emu.memType.spcDspRegisters)-1 do
		outSpc:write(string.pack("B", emu.read(i, emu.memType.spcDspRegisters, false)))
	end
	outSpc:write("\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00")
	outSpc:write("\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00")
	for i = 0x10000-64, emu.getMemorySize(emu.memType.spcRam)-1 do
		outSpc:write(string.pack("B", emu.read(i, emu.memType.spcRam, false)))
	end
	--outSpc:seek("set", 0x23); outSpc:write("\x1A") --Required for Timing
	--outSpc:seek("set", 0x2E); outSpc:write("Title")
	--outSpc:seek("set", 0x4E); outSpc:write("Game")
	--outSpc:seek("set", 0x6E); outSpc:write("LuigiBlood")
	--outSpc:seek("set", 0x7E); outSpc:write(1)
	--outSpc:seek("set", 0xA9); outSpc:write(40) --Required for Timing
	--outSpc:seek("set", 0xAC); outSpc:write(5000) --Required for Timing
	--outSpc:seek("set", 0xB1); outSpc:write("Artist")
	--outSpc:seek("set", 0xD2); outSpc:write(0) --Required for Timing
	outSpc:close()
	emu.displayMessage("SPC", SPCpath)
end

function setTimeSPC(fade)
	local outSpc = io.open(SPCpath, "r+b")
	outSpc:seek("set", 0x23); outSpc:write("\x1A")
	outSpc:seek("set", 0xA9); outSpc:write(math.ceil(timer / 60))
	outSpc:seek("set", 0xAC); outSpc:write(fade)
	outSpc:seek("set", 0xD2); outSpc:write(0)
	outSpc:close()
	emu.displayMessage("SPC", string.format("(Set Time: %d:%02d)", math.floor(timer / 60 / 60), math.floor(timer / 60 % 60)) .. SPCpath)
	timerStart = false
end

function callbackEndDetection()
	--if song just ends
	if timerStart then
		emu.displayMessage("SPC", "Song has ended.")
		setTimeSPC(0)
	end
end

function callbackJumpDetection()
	--if song jumps/loops, keep track of loops until save
	if timerStart then
		jump = jump + 1
		emu.displayMessage("SPC", "Song has jumped " .. jump .. " time(s).")
		if jump == 2 then
			setTimeSPC(5000)
			jump = 0
		end
	end
end

function callbackNextNoteCheck(address, value)
	--thanks Nova
	local dspreg = emu.read(0xF2, emu.memType.spcMemory)
	local dspdata = emu.read(dspreg, emu.memType.spcDspRegisters)
	
	if (dspreg == 0x4C) and (value ~= 0) and ((value ~ dspdata) ~= 0) and flagSaveNextNote then
		emu.write(dspreg, value, emu.memType.spcDspRegisters)
		makeSPC()
		flagSaveNextNote = false
		if flagSaveTimerStart then
			flagSaveTimerStart = false
			timerStart = true
			timer = 0
		end
	end
end

emu.addMemoryCallback(callbackNextNoteCheck, emu.callbackType.write, 0xF3, 0xF3, emu.cpuType.spc, emu.memType.spcMemory)

function manageScreen()
	if timerStart then
		timer = timer + 1
	end

	state = emu.getState()
	preMouseState = curMouseState
	curMouseState = emu.getMouseState()
	
	local x = 8
	local y = 8
	
	textUI(x, y, "SPC Helper", 4)
    
    --emu.drawRectangle(8, 8, 128, 24, bgColor, true, 1)
    --emu.drawRectangle(8, 8, 128, 24, fgColor, false, 1)
    --emu.drawString(12, 12, "Frame: " .. state["frameCount"], txColor, 0xFF000000)
    x = 130; y = 40
    numberModUI(x+(30*0), y, 1)
    numberModUI(x+(30*1), y, 2)
    numberModUI(x+(30*2), y, 3)
    numberModUI(x+(30*3), y, 4)
    
    x = x-1; y = y+30
    if buttonUI(x+(30*0),y,"Send") then
    	emu.write(0x2140, values[1], emu.memType.snesMemory)
    end
    if buttonUI(x+(30*1),y,"Send") then
    	emu.write(0x2141, values[2], emu.memType.snesMemory)
    end
    if buttonUI(x+(30*2),y,"Send") then
    	emu.write(0x2142, values[3], emu.memType.snesMemory)
    end
    if buttonUI(x+(30*3),y,"Send") then
    	emu.write(0x2143, values[4], emu.memType.snesMemory)
    end
    
    x = 8; y = 29
    if buttonUI(x,y,"Save SPC") then
    	makeSPC()
    end
    if buttonUI(x,y+16,"Save SPC (Next Note)") then
    	flagSaveNextNote = true
    end
    if buttonUI(x,y+32,"Save SPC (Next Note)\n+ Start Timer") then
    	flagSaveNextNote = true
    	flagSaveTimerStart = true
    end
    if flagSaveNextNote then
    	textUI(x, y+60, "Pending Next Note...", 4)
    end
    x = 8; y = 100
    textBoxUI(x, y,string.format("Time: %d:%02d", math.floor(timer / 60 / 60), math.floor(timer / 60 % 60)), 5)
    if timerStart then
    	if buttonUI(x,y+15,"Cancel") then
	    	timerStart = false
	    end
    	if buttonUI(x+45,y+15,"Stop & Save\n(5s Fade)") then
	    	setTimeSPC(5000)
	    end
	    if buttonUI(x+120,y+15,"Stop & Save\n(No Fade)") then
	    	setTimeSPC(0)
	    end
    end
    
    x = 90; y = 8
    rectangleUI(x, y, 158, 22)
    textUI(x+2+2, y+2, "CPU -> APU:")
    numberBoxUI(x+70+(22*0), y, state["spc.cpuRegs[0]"])
    numberBoxUI(x+70+(22*1), y, state["spc.cpuRegs[1]"])
    numberBoxUI(x+70+(22*2), y, state["spc.cpuRegs[2]"])
    numberBoxUI(x+70+(22*3), y, state["spc.cpuRegs[3]"])
    textUI(x+2+2, y+2+11, "CPU <- APU:")
    numberBoxUI(x+70+(22*0), y+11, state["spc.outputReg[0]"])
    numberBoxUI(x+70+(22*1), y+11, state["spc.outputReg[1]"])
    numberBoxUI(x+70+(22*2), y+11, state["spc.outputReg[2]"])
    numberBoxUI(x+70+(22*3), y+11, state["spc.outputReg[3]"])
    
    x = 8; y = 150
    rectangleUI(x, y, 200, 11*2, 6)
    textUI(x+2, y+2+(11*0), "Configuration:", 6)
    if checkBoxUI(x+2, y+2+(11*1), "Star Fox 2 Auto Timer", "starfox2", 6) then
    	--Star Fox 2 Final Specific
    	if config.starfox2 then
    		callback_endcheck = emu.addMemoryCallback(callbackEndDetection, emu.callbackType.exec, 0x0888, 0x0888, emu.cpuType.spc, emu.memType.spcMemory)
			callback_jumpcheck = emu.addMemoryCallback(callbackJumpDetection, emu.callbackType.exec, 0x088B, 0x088B, emu.cpuType.spc, emu.memType.spcMemory)
		else
			emu.removeMemoryCallback(callback_endcheck, emu.callbackType.exec, 0x0888, 0x0888, emu.cpuType.spc, emu.memType.spcMemory)
			emu.removeMemoryCallback(callback_jumpcheck, emu.callbackType.exec, 0x088B, 0x088B, emu.cpuType.spc, emu.memType.spcMemory)
    	end
    end
    
    emu.drawRectangle(curMouseState.x, curMouseState.y, 4, 1, 0xFFFFFF)
	emu.drawRectangle(curMouseState.x, curMouseState.y, 1, 4, 0xFFFFFF)
end

emu.addEventCallback(manageScreen, emu.eventType.endFrame)
