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
bgColor = 0x302060FF
bgColorHover = 0x305090FF
bgColorClick = 0x301010FF
fgColor = 0x30FF4040
txColor = 0xFFFFFF
preMouseState = emu.getMouseState()
curMouseState = emu.getMouseState()
values = {0, 0, 0, 0}
flagSaveNextNote = false

--Util
function checkMouseBox(x, y, w, h)
	return (curMouseState.x >= x and curMouseState.x < x+w and curMouseState.y >= y and curMouseState.y < y+h)
end

function checkMouseLeftClick()
	return (preMouseState.left == false and curMouseState.left == true)
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
function arrowUpUI(x, y)
	local testColor = 0
	local click = false
	testColor = bgColor
	if (checkMouseBox(x, y, 11, 7)) then
		testColor = bgColorHover
		if checkMouseLeftClick() == true then
			testColor = bgColorClick
			click = true
		end
	end
	
	emu.drawRectangle(x, y, 11, 7, testColor, true)
    emu.drawRectangle(x, y, 11, 7, fgColor, false)
    emu.drawRectangle(x+5, y+2, 1, 1, txColor, false)
    emu.drawRectangle(x+4, y+3, 3, 1, txColor, false)
    emu.drawRectangle(x+3, y+4, 5, 1, txColor, false)
    
    return click
end

function arrowDnUI(x, y)
	local testColor = 0
	local click = false
	testColor = bgColor
	if (checkMouseBox(x, y, 11, 7)) then
		testColor = bgColorHover
		if checkMouseLeftClick() == true then
			testColor = bgColorClick
			click = true
		end
	end
	
	emu.drawRectangle(x, y, 11, 7, testColor, true)
    emu.drawRectangle(x, y, 11, 7, fgColor, false)
    emu.drawRectangle(x+5, y+4, 1, 1, txColor, false)
    emu.drawRectangle(x+4, y+3, 3, 1, txColor, false)
    emu.drawRectangle(x+3, y+2, 5, 1, txColor, false)
    
    return click
end

function textBoxUI(x, y, txt, color)
	color = color or bgColor
	local widthString = emu.measureString(txt)
	
	emu.drawRectangle(x, y, 4+widthString.width, 4+widthString.height, color, true)
    emu.drawRectangle(x, y, 4+widthString.width, 4+widthString.height, fgColor, false)
    emu.drawString(x+2, y+3, txt, txColor, 0xFF000000)
end

function buttonUI(x, y, txt)
	local widthString = emu.measureString(txt)
	
	local testColor = 0
	local click = false
	--first Digit Up
	testColor = bgColor
	if (checkMouseBox(x, y, 4+widthString.width, 4+widthString.height)) then
		testColor = bgColorHover
		if checkMouseLeftClick() == true then
			testColor = bgColorClick
			click = true
		end
	end
	
	textBoxUI(x, y, txt, testColor)
    
    return click
end

function numberBoxUI(x, y, v)
	emu.drawRectangle(x, y, 22, 11, bgColor, true)
    emu.drawRectangle(x, y, 22, 11, fgColor, false)
    emu.drawString(x+3, y+2, string.format('%1X', v >> 4), txColor, 0xFF000000)
    emu.drawString(x+14, y+2, string.format('%1X', v & 0x0F), txColor, 0xFF000000)
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
	local number = 1
	local path = emu.getScriptDataFolder() .. "/" .. emu.getRomInfo()["name"] .. "_" .. number .. ".spc"
	while (not fileExists(path)) do
		number = number + 1
		path = emu.getScriptDataFolder() .. "/" .. emu.getRomInfo()["name"] .. "_" .. number .. ".spc"
	end
	state = emu.getState()
	local outSpc = io.open(path, "wb")
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
	--outSpc:seek("set", 0x23); outSpc:write("\x1A")
	--outSpc:seek("set", 0x2E); outSpc:write("Title")
	--outSpc:seek("set", 0x4E); outSpc:write("Game")
	--outSpc:seek("set", 0x6E); outSpc:write("LuigiBlood")
	--outSpc:seek("set", 0x7E); outSpc:write(1)
	--outSpc:seek("set", 0xA9); outSpc:write(40)
	--outSpc:seek("set", 0xAC); outSpc:write(5000)
	--outSpc:seek("set", 0xB1); outSpc:write("Artist")
	--outSpc:seek("set", 0xD2); outSpc:write(0)
	outSpc:close()
	emu.displayMessage("SPC", path)
end

function firstNoteCheck(address, value)
	--thanks Nova
	local dspreg = emu.read(0xF2, emu.memType.spcMemory)
	local dspdata = emu.read(0xF3, emu.memType.spcMemory)
	
	if (dspreg == 0x4C) and (value ~= 0) and ((value ^ dspdata) ~= 0) and flagSaveNextNote then
		makeSPC()
		flagSaveNextNote = false
	end
end

emu.addMemoryCallback(firstNoteCheck, emu.callbackType.write, 0xF3, 0xF3, emu.cpuType.spc, emu.memType.spcMemory)

function manageScreen()
	state = emu.getState()
	preMouseState = curMouseState
	curMouseState = emu.getMouseState()
	
	local x = 0
	local y = 0
    
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
    
    x = 8; y = 8
    if buttonUI(x,y,"Create SPC") then
    	makeSPC()
    end
    
    if buttonUI(x,y+28,"Create SPC (Next Note)") then
    	flagSaveNextNote = true
    end
    
    x = 90; y = 8
    emu.drawRectangle(x, y, 158, 22, bgColor, true)
    emu.drawRectangle(x, y, 158, 22, fgColor, false)
    emu.drawString(x+2+2, y+2, "CPU -> APU:", txColor, 0xFF000000)
    numberBoxUI(x+70+(22*0), y, state["spc.cpuRegs[0]"])
    numberBoxUI(x+70+(22*1), y, state["spc.cpuRegs[1]"])
    numberBoxUI(x+70+(22*2), y, state["spc.cpuRegs[2]"])
    numberBoxUI(x+70+(22*3), y, state["spc.cpuRegs[3]"])
    emu.drawString(x+2+2, y+2+11, "CPU <- APU:", txColor, 0xFF000000)
    numberBoxUI(x+70+(22*0), y+11, state["spc.outputReg[0]"])
    numberBoxUI(x+70+(22*1), y+11, state["spc.outputReg[1]"])
    numberBoxUI(x+70+(22*2), y+11, state["spc.outputReg[2]"])
    numberBoxUI(x+70+(22*3), y+11, state["spc.outputReg[3]"])
    
    emu.drawRectangle(curMouseState.x, curMouseState.y, 4, 1, 0xFFFFFF)
	emu.drawRectangle(curMouseState.x, curMouseState.y, 1, 4, 0xFFFFFF)
end

emu.addEventCallback(manageScreen, emu.eventType.endFrame)