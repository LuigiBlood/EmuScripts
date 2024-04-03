-- Virtual Robotic Operating Buddy (Mesen 2.0)
-- Code by LuigiBlood
if emu.getState().consoleType ~= "Nes" then
  emu.displayMessage("Script", "This script only works on the NES.")
  return
end

frameCount = 0
command = 0
currentCommand = 0

rob = {
	state = 0,
	led = 0,

	x = 2,
	y = 0,
	xnext = 2,
	ynext = 2,
	x_speed = 0.2,
	y_speed = 0.2,

	arms = 2,
	arms_speed = 0.2,
	arms_max = 2
}

phys = {
	accel = 0.1,
	accel_max = 1,

	y_base = 6.0,
	y_max = 7.5
}

hud = {
	x = 170,
	y = 170,
	x_scale = 16
}

config = {
	--mode for game specific stuff (nil, "gyro", "block")
	mode = nil,

	--amount of frames for a gyro to spin
	spin_max = 60*10,

	--remove rob communication flash (anti-epilepsy)
	remove_flash = true,

	--automatically move fallen gyros to a safe place
	automove_gyro = true,
}

objects = {}

prevScreenBuffer = {}

--Utility
function drawStringShadow(x, y, text, color)
	emu.drawString(x+1, y+1, text, 0x00000000, 0xFFFFFFFF)
	emu.drawString(x, y, text, color, 0xFFFFFFFF)
end

function detectGame()
	local hash = emu.getRomInfo().fileSha1Hash
	--emu.log(hash)

	if hash == "78393A45CD01C8C014FE77F1648DFCCA17FE2B51" then
		StartRobotGyro()
	elseif hash == "93FE36D485636210F8FDDFBAB5D157193ACFB86F" then
		StartRobotBlock()
	end
end

--Mouse
function GetMousePositionHUD()
	local mouse = emu.getMouseState()
	local ret = {}
	ret.x = (mouse.x - hud.x) / hud.x_scale + 0.25
	ret.y = (mouse.y - hud.y) / 8
	ret.left = mouse.left

	return ret
end

function DrawMouseDebug()
	local mouse = emu.getMouseState()
	emu.drawLine(mouse.x, mouse.y, mouse.x + 3, mouse.y, 0x00FFFFFF)
	emu.drawLine(mouse.x, mouse.y, mouse.x, mouse.y + 3, 0x00FFFFFF)
end

function IsMouseOverBox(x, y)
	local mouse = GetMousePositionHUD()
	if x <= mouse.x and x + 1.0 > mouse.x and y <= mouse.y and y + 1.0 > mouse.y then
		return true
	end
	return false
end

--Generic Objects
function FindAboveObject(x, y)
	for k,v in pairs(objects) do
		if v.mousegrab == 0 and v.x == x and v.y < y and v.y >= y - 1 then
			return v
		end
	end
	return nil
end

function FindBelowObject(x, y)
	for k,v in pairs(objects) do
		if v.mousegrab == 0 and v.x == x and v.y > y and v.y <= y + 1 then
			return v
		end
	end
	return nil
end

function FindIfObjectWasGrabbedByMouse()
	for k,v in pairs(objects) do
		if v.mousegrab == 1 then
			return true
		end
	end
	return false
end

function ClearObjects()
	objects = {}
end

function AddObject(_name, _x, _y, _locked, _color, _draw, _handle)
	objects[_name] = {
		name = _name,
		x = _x,
		y = _y,
		locked = _locked,

		gravity = 0,
		grabbed = 0,
		falling = 0,
		mousegrab = 0,

		color = _color,
		draw = _draw,
		handle = _handle
	}
end

function HandlePhysicsObject(self)
	--If Locked, don't apply physics
	if self.locked == 1 then return end

	--Manage Mousegrab
	if IsMouseOverBox(self.x, self.y) == true and emu.getMouseState().left == true then
		--Only manage one object grabbed by mouse at a time
		if FindIfObjectWasGrabbedByMouse() == false then
			self.mousegrab = 1
			self.grabbed = 0
		end
	end
	if self.mousegrab == 1 then
		local mouse = GetMousePositionHUD()
		self.x = math.min(math.max(math.floor(mouse.x), 0), 4)
		self.y = mouse.y - 0.7
		self.gravity = 0

		if mouse.left == false then self.mousegrab = 0 end
		return
	end

	--Object Grabbing
	if rob.state == 5 and self.grabbed == 1 then
		self.grabbed = 0
	elseif rob.state == 6 and rob.x == self.x and rob.y == self.y then
		self.grabbed = 1
	end

	--If Arms move to, or from the object horizontally, make it fall off
	local fall_above = 0
	local fall_below = 0
	local fall_object = 0
	if self.grabbed == 0 and (self.x >= rob.x - 0.2 and self.x <= rob.x + 0.2) and self.y == rob.y then
		if rob.state == 1 then
			fall_above = -1
			fall_below = -1
			fall_object = -1
		elseif rob.state == 2 then
			fall_above = 1
			fall_below = 1
			fall_object = 1
		end
	end

	--If Closed Arms move to the object from above, make it fall off
	if self.grabbed == 0 and rob.arms == 0 and (self.y >= rob.y - 0.2 and self.y <= rob.y + 0.2) and self.x == rob.x then
		if rob.state == 4 then
			self.x = self.x - rob.x_speed
		end
	end

	--Handle Fall
	if fall_above ~= 0 then
		local upobj = FindAboveObject(self.x, self.y)
		while (upobj ~= nil) do
			if upobj.locked ~= 1 then
				upobj.x = upobj.x + (rob.x_speed * fall_above)
			end
			upobj = FindAboveObject(self.x, upobj.y)
		end
	end

	if fall_below ~= 0 then
		local downobj = FindBelowObject(self.x, self.y)
		while (downobj ~= nil) do
			if downobj.locked ~= 1 then
				downobj.x = downobj.x + (rob.x_speed * fall_below)
			end
			downobj = FindBelowObject(self.x, downobj.y)
		end
	end

	if fall_object ~= 0 then
		self.x = self.x + (rob.x_speed * fall_object)
	end

	--Handle Physics
	local lowobj = FindBelowObject(self.x, self.y)
	if (lowobj == nil) then lowobj = { y = phys.y_max } end
	if lowobj.y > phys.y_base and self.x ~= math.floor(self.x) then lowobj = {y = phys.y_max} end

	if self.grabbed == 1 then
		local upobj = FindAboveObject(self.x, self.y)
		while (upobj ~= nil) do
			if upobj.locked ~= 1 then
				upobj.x = rob.x
			end
			upobj = FindAboveObject(self.x, upobj.y)
		end
		self.x = rob.x
		self.y = rob.y
		self.gravity = 0
	elseif self.y < lowobj.y - 1 then
		if self.gravity < phys.accel_max then
			self.gravity = self.gravity + phys.accel
		else
			self.gravity = phys.accel_max
		end
		self.y = self.y + self.gravity
	else
		self.y = lowobj.y - 1
		self.gravity = 0
	end
end

function HandleObjects()
	for k,v in pairs(objects) do
		v.handle(v)
	end
end

function DrawObjects(x, y)
	for k,v in pairs(objects) do
		v.draw(v, x, y)
	end
end

--ROB Specific functions
function StartCommand(command)
	if rob.state ~= 0 then return end
	currentCommand = command

	if currentCommand == 1001 then
		--LED ON
		rob.led = 1
		currentCommand = 0
		rob.state = 0
	elseif currentCommand == 0001 then
		--Reset
		rob.led = 0
		rob.x = 2
		rob.y = 2
		currentCommand = 0
		rob.state = 0
	elseif currentCommand == 0100 then
		--Left
		rob.xnext = math.floor(rob.x - 1 + 0.5)
		if rob.xnext < 0 then return end
		rob.state = 1
		rob.led = 1
	elseif currentCommand == 1000 then
		--Right
		rob.xnext = math.floor(rob.x + 1 + 0.5)
		if rob.xnext > 4 then return end
		rob.state = 2
		rob.led = 1
	elseif currentCommand == 1100 then
		--Up + 1
		rob.ynext = math.floor(rob.y - 1 + 0.5)
		if rob.ynext < 0 then rob.ynext = 0 end
		rob.state = 3
		rob.led = 1
	elseif currentCommand == 0101 then
		--Up + 2
		rob.ynext = math.floor(rob.y - 2 + 0.5)
		if rob.ynext < 0 then rob.ynext = 0 end
		rob.state = 3
		rob.led = 1
	elseif currentCommand == 0010 then
		--Down + 1
		rob.ynext = math.floor(rob.y + 1 + 0.5)
		if rob.ynext > phys.y_base - 1 then rob.ynext = phys.y_base - 1 end
		rob.state = 4
		rob.led = 1
	elseif currentCommand == 1101 then
		--Down + 2
		rob.ynext = math.floor(rob.y + 2 + 0.5)
		if rob.ynext > phys.y_base - 1 then rob.ynext = phys.y_base - 1 end
		rob.state = 4
		rob.led = 1
	elseif currentCommand == 1010 then
		--Open
		rob.state = 5
		rob.led = 1
	elseif currentCommand == 0110 then
		--Close
		rob.state = 6
		rob.led = 1
	end
end

function HandleROBState()
	if rob.state == 1 then
		--X Move (Left)
		if rob.xnext < rob.x then
			rob.x = rob.x - rob.x_speed
		else
			rob.x = rob.xnext
			rob.state = 0
			rob.led = 0
			currentCommand = 0
		end
	elseif rob.state == 2 then
		--X Move (Right)
		if rob.xnext > rob.x then
			rob.x = rob.x + rob.x_speed
		else
			rob.x = rob.xnext
			rob.state = 0
			rob.led = 0
			currentCommand = 0
		end
	elseif rob.state == 3 then
		--Y Move (Up)
		if rob.ynext < rob.y then
			rob.y = rob.y - rob.y_speed
		else
			rob.y = rob.ynext
			rob.state = 0
			rob.led = 0
			currentCommand = 0
		end
	elseif rob.state == 4 then
		--Y Move (Down)
		if rob.ynext > rob.y then
			rob.y = rob.y + rob.y_speed
		else
			rob.y = rob.ynext
			rob.state = 0
			rob.led = 0
			currentCommand = 0
		end
	elseif rob.state == 5 then
		--Open
		if rob.arms < rob.arms_max then
			rob.arms = rob.arms + rob.arms_speed
		else
			rob.arms = rob.arms_max
			rob.state = 0
			rob.led = 0
			currentCommand = 0
		end
	elseif rob.state == 6 then
		--Close
		if rob.arms > 0 then
			rob.arms = rob.arms - rob.arms_speed
		else
			rob.arms = 0
			rob.state = 0
			rob.led = 0
			currentCommand = 0
		end
	end
end

function DrawROB(x, y)
	emu.drawRectangle(x - 5, y - 4, hud.x_scale*5 + 10 - (hud.x_scale - 8), 8*(phys.y_max+1) + 2, 0x003F3F00, 0)
	emu.drawRectangle(x - 4, y - 3, hud.x_scale*5 + 8 - (hud.x_scale - 8), 8*(phys.y_max+1) + 0, 0x3F1F1F00, 1)

	--ROB face
	--emu.drawRectangle(x + 10, y + 3, 20, 10, 0x3FFFFFFF, 0)
	--emu.drawRectangle(x + 12, y + 5, 6, 6, 0x3FFFFFFF, 0)
	--emu.drawRectangle(x + 22, y + 5, 6, 6, 0x3FFFFFFF, 0)
	--emu.drawRectangle(x + 17, y + 13, 6, 20, 0x3FFFFFFF, 0)
	
	emu.drawRectangle(x + 1 + 2 * hud.x_scale, y - 3, 6, 3, 0x3FFF7F7F, rob.led)

	--center of arms
	emu.drawPixel(x + 3 + (rob.x * hud.x_scale), y + 3 + (rob.y * 8), 0x3F7FFF7F)
	emu.drawPixel(x + 4 + (rob.x * hud.x_scale), y + 4 + (rob.y * 8), 0x3F7FFF7F)
	--emu.drawRectangle(x + (rob.x * 8), y + (rob.y * 8), 8, 8, 0x3F7FFF7F, 0)
	
	DrawObjects(x, y)

	--arms
	emu.drawRectangle(x + 0 + (rob.x * hud.x_scale) - rob.arms, y + (rob.y * 8), 4, 8, 0x3F7FFF7F, 0)
	emu.drawRectangle(x + 4 + (rob.x * hud.x_scale) + rob.arms, y + (rob.y * 8), 4, 8, 0x3F7FFF7F, 0)
end

function CheckScreen()
	local buffer = emu.getScreenBuffer()
	-- Check how much green is present on screen
	local amount = 0;
	for i = 1, #buffer do
		amount = amount + ((buffer[i] >> 8) & 0xFF)
	end
	if amount >= 0x800000 then
		-- If that color is largely present on screen, then return 1
		return 1;
	elseif amount <= 0x1000 then
		-- If that color is almost never present on screen, then return 0
		return 0;
	else
		-- Else it's probably just the game screen so just return -1
		return -1;
	end
end

--Callbacks
function updateROB()
	local color = CheckScreen()
	HandleROBState()
	HandleObjects()
	HandleGUI()

	-- Recognition
	if frameCount == 0 and color == 1 then
		frameCount = frameCount + 1
	elseif frameCount == 1 and color == 0 then
		frameCount = frameCount + 1
	elseif frameCount == 2 and color == 1 then
		frameCount = frameCount + 1
	elseif frameCount == 3 then
		--bit3
		frameCount = frameCount + 1
		if color == 1 then
			command = 1000
		else
			command = 0000
		end
	elseif frameCount == 4 and color == 1 then
		frameCount = frameCount + 1
	elseif frameCount == 5 then
		--bit2
		frameCount = frameCount + 1
		if color == 1 then
			command = command + 0100
		end
	elseif frameCount == 6 and color == 1 then
		frameCount = frameCount + 1
	elseif frameCount == 7 then
		--bit1
		frameCount = frameCount + 1
		if color == 1 then
			command = command + 0010
		end
	elseif frameCount == 8 and color == 1 then
		frameCount = frameCount + 1
	elseif frameCount == 9 then
		--bit0
		frameCount = frameCount + 1
		if color == 1 then
			command = command + 0001
		end
		StartCommand(command)
	else
		frameCount = 0
	end

	--Anti-Flashing
	if config.remove_flash == true then
		if frameCount > 0 or (frameCount == 0 and color == 0) then
			emu.setScreenBuffer(prevScreenBuffer)
		elseif color == -1 then
			prevScreenBuffer = emu.getScreenBuffer()
		end
	end

	DrawROB(hud.x, hud.y)
	DrawGUI()
	DrawMouseDebug()
end

function inputPoll()
	if objects.bluebtn ~= nil and objects.redbtn ~= nil then
		emu.setInput({a = objects.bluebtn.pressed, b = objects.redbtn.pressed}, 1, 1)
	end
end

function startROB()
	detectGame()
	emu.addEventCallback(updateROB, emu.eventType.endFrame)
	emu.addEventCallback(inputPoll, emu.eventType.inputPolled)

	--Display a startup message
	emu.displayMessage("Script", "Virtual ROB loaded.")
end

--Gyromite specific
function DrawGyroObject(self, x, y)
	local color = self.color
	if self.grabbed == 1 or self.mousegrab == 1 then color = self.colorgrab end

	if self.y <= phys.y_base - 0.8 then
		emu.drawRectangle(x + 0 + (self.x * hud.x_scale), y + 1 + (self.y * 8), 8, 2, color, 1)
		emu.drawRectangle(x + 1 + (self.x * hud.x_scale), y + 3 + (self.y * 8), 6, 2, color, 1)
		emu.drawRectangle(x + 2 + (self.x * hud.x_scale), y + 5 + (self.y * 8), 4, 2, color, 1)
		emu.drawRectangle(x + 3 + (self.x * hud.x_scale), y + 7 + (self.y * 8), 2, 2, color, 1)
	else
		emu.drawRectangle(x + 1 + (self.x * hud.x_scale), y + 0 + (self.y * 8), 2, 8, color, 1)
		emu.drawRectangle(x + 3 + (self.x * hud.x_scale), y + 1 + (self.y * 8), 2, 6, color, 1)
		emu.drawRectangle(x + 5 + (self.x * hud.x_scale), y + 2 + (self.y * 8), 2, 4, color, 1)
		emu.drawRectangle(x + 7 + (self.x * hud.x_scale), y + 3 + (self.y * 8), 2, 2, color, 1)
	end

	if self.spin > 0 then
		local frames = 7 - emu.getState().frameCount % 8
		if (self.spin <= 60*5) then frames = 8 - emu.getState().frameCount % 16 / 2 end
		if (self.spin <= 60*2) then frames = 8 - emu.getState().frameCount % 32 / 4 end
		emu.drawPixel(x + 0 + (self.x * hud.x_scale) + frames, y + 0 + (self.y * 8), 0x00FFFFFF)
	end
end

function HandleGyroObject(self)
	HandlePhysicsObject(self)
	--Handle Spin
	if self.spin > 0 then self.spin = self.spin - 1 end
	--If the Gyro fell down then stop spinning
	if self.y > phys.y_base then self.spin = 0 end
	--If it's on a button and it stopped spinning while not grabbed then fall down
	if objects.bluebtn.x == self.x or objects.redbtn.x == self.x then
		if self.grabbed == 0 and self.spin <= 0 and self.y == phys.y_base - 1 then self.x = self.x - 0.2 end
	end
	--If it falls on another gyro then both should fall
	local upobj = FindAboveObject(self.x, self.y)
	if self.mousegrab == 0 and upobj ~= nil and (upobj.name == "gyro1" or upobj.name == "gyro2") then
		if objects.bluebtn.x == self.x or objects.redbtn.x == self.x then
			self.x = self.x - rob.x_speed
		end
		if upobj.grabbed == 0 and upobj.mousegrab == 0 then
			upobj.x = upobj.x + rob.x_speed
		end
	end
	--auto move gyro when fallen
	if self.mousegrab == 0 and config.automove_gyro == true and self.y >= (phys.y_base + 0.5) then
		local upobj = FindAboveObject(objects.holder1.x, objects.holder1.y)
		if upobj == nil then
			self.x = objects.holder1.x
			self.y = objects.holder1.y - 1
		else
			upobj = FindAboveObject(objects.holder2.x, objects.holder2.y)
			if upobj == nil then
				self.x = objects.holder2.x
				self.y = objects.holder2.y - 1
			end
		end
	end
end

function DrawGyroMotorObject(self, x, y)
	emu.drawRectangle(x + 2 + (self.x * hud.x_scale), y + 0 + (self.y * 8), 4, 2, self.color, 1)
	emu.drawRectangle(x + 1 + (self.x * hud.x_scale), y + 2 + (self.y * 8), 6, 2, self.color, 1)
end

function HandleGyroMotorObject(self)
	if objects.gyro1.x == self.x and objects.gyro1.y == (self.y - 1) then objects.gyro1.spin = config.spin_max end
	if objects.gyro2.x == self.x and objects.gyro2.y == (self.y - 1) then objects.gyro2.spin = config.spin_max end
end

function DrawGyroButtonObject(self, x, y)
	emu.drawRectangle(x + 1 + (self.x * hud.x_scale), y + 0 + (self.y * 8) + self.pressed, 6, 2, self.color, 1)
end

function HandleGyroButtonObject(self)
	self.pressed = 0
	if FindAboveObject(self.x, self.y) ~= nil then self.pressed = 1 end
end

function StartRobotGyro()
	ClearObjects()

	AddObject("gyro1", 0, phys.y_base - 1, 0, 0x3F7F7F3F, DrawGyroObject, HandleGyroObject)
	objects.gyro1.colorgrab = 0x3FFFFF7F
	objects.gyro1.spin = 0

	AddObject("gyro2", 1, phys.y_base - 1, 0, 0x3F3F7F7F, DrawGyroObject, HandleGyroObject)
	objects.gyro2.colorgrab = 0x3F7FFFFF
	objects.gyro2.spin = 0

	AddObject("spinner", 4, phys.y_base, 1, 0x3FFFFFFF, DrawGyroMotorObject, HandleGyroMotorObject)
	
	AddObject("bluebtn", 2, phys.y_base, 1, 0x3F7F7FFF, DrawGyroButtonObject, HandleGyroButtonObject)
	objects.bluebtn.pressed = 0

	AddObject("redbtn", 3, phys.y_base, 1, 0x3FFF7F7F, DrawGyroButtonObject, HandleGyroButtonObject)
	objects.redbtn.pressed = 0

	AddObject("holder1", 0, phys.y_base, 1, 0x3F7F7F7F, DrawHolderObject, HandlePhysicsObject)

	AddObject("holder2", 1, phys.y_base, 1, 0x3F7F7F7F, DrawHolderObject, HandlePhysicsObject)

	config.mode = "gyro"
	emu.displayMessage("Script", "Virtual ROB - Robot Gyro")
end

--Stack-Up specific
function DrawBlockObject(self, x, y)
	local color = self.color
	if self.grabbed == 1 or self.mousegrab == 1 then color = self.colorgrab end
	emu.drawRectangle(x + (self.x * hud.x_scale), y + (self.y * 8), 8, 8, color, 1)
	--highlight
	emu.drawLine(x + (self.x * hud.x_scale), y + (self.y * 8), x + (self.x * hud.x_scale) + 7, y + (self.y * 8), self.colorgrab)
	emu.drawLine(x + (self.x * hud.x_scale), y + (self.y * 8), x + (self.x * hud.x_scale), y + (self.y * 8) + 7, self.colorgrab)
	--shadow
	emu.drawLine(x + (self.x * hud.x_scale) + 1, y + (self.y * 8) + 7, x + (self.x * hud.x_scale) + 7, y + (self.y * 8) + 7, 0xAF000000)
	emu.drawLine(x + (self.x * hud.x_scale) + 7, y + (self.y * 8) + 1, x + (self.x * hud.x_scale) + 7, y + (self.y * 8) + 7, 0xAF000000)

end

function DrawHolderObject(self, x, y)
	emu.drawRectangle(x + 1 + (self.x * hud.x_scale), y + (self.y * 8), 6, 4, self.color, 1)
	--shadow
	emu.drawLine(x + (self.x * hud.x_scale) + 1, y + (self.y * 8) + 3, x + (self.x * hud.x_scale) + 6, y + (self.y * 8) + 3, 0xAF000000)
	emu.drawLine(x + (self.x * hud.x_scale) + 1, y + (self.y * 8) + 0, x + (self.x * hud.x_scale) + 6, y + (self.y * 8) + 0, 0xAF000000)
end

function StartRobotBlock()
	ClearObjects()

	AddObject("blockred", 0, phys.y_base - 1, 0, 0x1FAF0F0F, DrawBlockObject, HandlePhysicsObject)
	objects.blockred.colorgrab = 0x1FFF3F3F

	AddObject("blockwhite", 1, phys.y_base - 1, 0, 0x1FAFAFAF, DrawBlockObject, HandlePhysicsObject)
	objects.blockwhite.colorgrab = 0x1FFFFFFF

	AddObject("blockblue", 2, phys.y_base - 1, 0, 0x1F0F4FAF, DrawBlockObject, HandlePhysicsObject)
	objects.blockblue.colorgrab = 0x1F8F8FFF

	AddObject("blockyellow", 3, phys.y_base - 1, 0, 0x1FCFCF00, DrawBlockObject, HandlePhysicsObject)
	objects.blockyellow.colorgrab = 0x1FFFFF3F

	AddObject("blockgreen", 4, phys.y_base - 1, 0, 0x1F0FAF0F, DrawBlockObject, HandlePhysicsObject)
	objects.blockgreen.colorgrab = 0x1F3FFF3F

	AddObject("holder1", 0, phys.y_base, 1, 0x3F7F7F7F, DrawHolderObject, HandlePhysicsObject)
	AddObject("holder2", 1, phys.y_base, 1, 0x3F7F7F7F, DrawHolderObject, HandlePhysicsObject)
	AddObject("holder3", 2, phys.y_base, 1, 0x3F7F7F7F, DrawHolderObject, HandlePhysicsObject)
	AddObject("holder4", 3, phys.y_base, 1, 0x3F7F7F7F, DrawHolderObject, HandlePhysicsObject)
	AddObject("holder5", 4, phys.y_base, 1, 0x3F7F7F7F, DrawHolderObject, HandlePhysicsObject)

	config.mode = "block"
	emu.displayMessage("Script", "Virtual ROB - Robot Block")
end

--GUI
function DrawGUIMain(self)
	--Options
	emu.drawRectangle(self.x, self.y, self.w, self.h, 0xCFFFFFFF, 1)
	emu.drawRectangle(self.x, self.y, self.w, self.h, 0x00FFFFFF, 0)
	emu.drawLine(self.x + 10, self.y + 6, self.x + 6, self.y + 10, 0x00FFFFFF)
	emu.drawLine(self.x + 10, self.y + 5, self.x + 5, self.y + 10, 0x00FFFFFF)
	emu.drawLine(self.x + 09, self.y + 5, self.x + 5, self.y + 09, 0x00FFFFFF)
	emu.drawRectangle(self.x + 09, self.y + 3, 2, 3, 0x00FFFFFF)
	emu.drawRectangle(self.x + 10, self.y + 2, 2, 1, 0x00FFFFFF)
	emu.drawRectangle(self.x + 10, self.y + 5, 3, 2, 0x00FFFFFF)
	emu.drawRectangle(self.x + 13, self.y + 4, 1, 2, 0x00FFFFFF)
	emu.drawRectangle(self.x + 05, self.y + 10, 2, 3, 0x00FFFFFF)
	emu.drawRectangle(self.x + 04, self.y + 13, 2, 1, 0x00FFFFFF)
	emu.drawRectangle(self.x + 03, self.y + 09, 3, 2, 0x00FFFFFF)
	emu.drawRectangle(self.x + 02, self.y + 10, 1, 2, 0x00FFFFFF)

	if self.hover then
		emu.drawRectangle(self.x, self.y, self.w, self.h, 0x8F0FFF0F, 1)

		drawStringShadow(self.x + self.w + 25, self.y + (self.h / 4), self.text, 0x00FFFFFF, 0xFFFFFFFF)
	end

	if self.open then
		emu.drawRectangle(self.x, self.y, self.w, self.h, 0xCFFFFFFF, 1)
		emu.drawRectangle(self.x + 1, self.y + 1, self.w - 2, self.h - 2, 0x8F000000, 0)
	end

	if self.hover and self.clicked then
		emu.drawRectangle(self.x, self.y, self.w, self.h, 0x8FFFFFFF, 1)
	end
end

function DrawGUIHelp(self)
	--Options
	emu.drawRectangle(self.x, self.y, self.w, self.h, 0xCFFFFFFF, 1)
	emu.drawRectangle(self.x, self.y, self.w, self.h, 0x00FFFFFF, 0)

	emu.drawRectangle(self.x + 4, self.y + 4, 2, 3, 0x00FFFFFF)
	emu.drawRectangle(self.x + 5, self.y + 3, 6, 1, 0x00FFFFFF)
	emu.drawRectangle(self.x + 10, self.y + 4, 2, 3, 0x00FFFFFF)
	emu.drawRectangle(self.x + 8, self.y + 7, 3, 1, 0x00FFFFFF)
	emu.drawRectangle(self.x + 7, self.y + 8, 2, 2, 0x00FFFFFF)

	emu.drawRectangle(self.x + 7, self.y + 11, 2, 2, 0x00FFFFFF)

	if self.hover then
		emu.drawRectangle(self.x, self.y, self.w, self.h, 0x8F0FFF0F, 1)

		drawStringShadow(self.x + self.w + 8, self.y + (self.h / 4), self.text, 0x00FFFFFF, 0xFFFFFFFF)
	end

	if self.open then
		emu.drawRectangle(self.x, self.y, self.w, self.h, 0xCFFFFFFF, 1)
		emu.drawRectangle(self.x + 1, self.y + 1, self.w - 2, self.h - 2, 0x8F000000, 0)
	end

	if self.hover and self.clicked then
		emu.drawRectangle(self.x, self.y, self.w, self.h, 0x8FFFFFFF, 1)
	end
end

function DrawGUICheckbox(self)
	--Checkbox
	emu.drawRectangle(self.x, self.y, self.w, self.h, 0x8F000000, 1)
	emu.drawRectangle(self.x, self.y, self.w, self.h, 0x00FFFFFF, 0)

	if self.open then
		emu.drawLine(self.x + 12, self.y + 2, self.x + 2, self.y + 12, 0x00FFFFFF)
		emu.drawLine(self.x + 13, self.y + 2, self.x + 2, self.y + 13, 0x00FFFFFF)
		emu.drawLine(self.x + 13, self.y + 3, self.x + 3, self.y + 13, 0x00FFFFFF)


		emu.drawLine(self.x + 3, self.y + 2, self.x + 13, self.y + 12, 0x00FFFFFF)
		emu.drawLine(self.x + 2, self.y + 2, self.x + 13, self.y + 13, 0x00FFFFFF)
		emu.drawLine(self.x + 2, self.y + 3, self.x + 12, self.y + 13, 0x00FFFFFF)
	end

	if self.hover then
		emu.drawRectangle(self.x, self.y, self.w, self.h, 0x8F0FFF0F, 1)
	end

	if self.hover and self.clicked then
		emu.drawRectangle(self.x, self.y, self.w, self.h, 0x8FFFFFFF, 1)
	end

	if self.text ~= nil then
		drawStringShadow(self.x + self.w + 8, self.y + (self.h / 4), self.text, 0x00FFFFFF, 0xFFFFFFFF)
	end
end

function HandleGUICheckbox(self)
	local mouse = emu.getMouseState()
	if mouse.x >= self.x and mouse.x < (self.x + self.w) and mouse.y >= self.y and mouse.y < (self.y + self.h) then
		self.hover = true
	else
		self.hover = false
	end

	if self.hover and mouse.left then
		if self.clicked == false then
			if self.open then
				self.open = false
			else
				self.open = true
			end
			self.clicked = true
		end
	end

	if mouse.left == false then
		self.clicked = false
	end

	if self.var_handle ~= nil then
		self.var_handle(self)
	end
end

function DrawGUIButton(self)
	--Button
	emu.drawRectangle(self.x, self.y, self.w, self.h, 0x008F8F8F, 0)
	emu.drawRectangle(self.x + 1, self.y + 1, self.w - 1, self.h - 1, 0x004F4F4F, 0)
	emu.drawRectangle(self.x + 1, self.y + 1, self.w - 2, self.h - 2, 0x00CFCFCF, 1)

	if self.hover then
		emu.drawRectangle(self.x, self.y, self.w, self.h, 0x8F0FFF0F, 1)
	end

	if self.clicked then
		emu.drawRectangle(self.x, self.y, self.w, self.h, 0x004F4F4F, 0)
		emu.drawRectangle(self.x + 1, self.y + 1, self.w - 1, self.h - 1, 0x008F8F8F, 0)
		emu.drawRectangle(self.x + 1, self.y + 1, self.w - 2, self.h - 2, 0x005F5F5F, 1)
	end

	if self.text ~= nil then
		drawStringShadow(self.x + self.w + 8, self.y + (self.h / 4), self.text, 0x00FFFFFF, 0xFFFFFFFF)
	end
end

function HandleGUIButton(self)
	local mouse = emu.getMouseState()
	if mouse.x >= self.x and mouse.x < (self.x + self.w) and mouse.y >= self.y and mouse.y < (self.y + self.h) then
		self.hover = true
	else
		self.hover = false
	end

	if self.hover and mouse.left then
		if self.clicked == false then
			if self.var_handle ~= nil then
				self.var_handle(self)
			end
			self.clicked = true
		end
	end

	if mouse.left == false then
		self.clicked = false
	end
end

function HandleGUIFlashButton(self)
	config.remove_flash = self.open
end

function HandleGUIGyroMoveButton(self)
	config.automove_gyro = self.open
end

function HandleGUIMainBar(self)
	if gui_button_main.clicked then
		gui_button_help.open = false
	elseif gui_button_help.clicked then
		gui_button_main.open = false
	end
end

gui_button_main = {
	x = 8,
	y = 8,
	w = 16,
	h = 16,

	hover = false,
	clicked = false,
	open = false,
	
	draw = DrawGUIMain,
	handle = HandleGUICheckbox,
	text = "Options",
	var_handle = HandleGUIMainBar,
}

gui_button_help = {
	x = 25,
	y = 8,
	w = 16,
	h = 16,

	hover = false,
	clicked = false,
	open = true,
	
	draw = DrawGUIHelp,
	handle = HandleGUICheckbox,
	text = "Help",
	var_handle = HandleGUIMainBar,
}

gui_button_opt_flash = {
	x = 8,
	y = 32,
	w = 16,
	h = 16,

	hover = false,
	clicked = false,
	open = config.remove_flash,
	
	draw = DrawGUICheckbox,
	handle = HandleGUICheckbox,
	text = "Hide R.O.B. Screen Flashing",
	var_handle = HandleGUIFlashButton,
}

gui_button_opt_autogyro = {
	x = 8,
	y = 50,
	w = 16,
	h = 16,

	hover = false,
	clicked = false,
	open = config.automove_gyro,
	
	draw = DrawGUICheckbox,
	handle = HandleGUICheckbox,
	text = "Automatically place fallen Gyros back",
	var_handle = HandleGUIGyroMoveButton,
}

gui_button_startgyro = {
	x = 8,
	y = 78,
	w = 16,
	h = 16,

	hover = false,
	clicked = false,
	
	draw = DrawGUIButton,
	handle = HandleGUIButton,
	text = "Setup Robot Gyro / Gyromite",
	var_handle = StartRobotGyro,
}

gui_button_startblock = {
	x = 8,
	y = 96,
	w = 16,
	h = 16,

	hover = false,
	clicked = false,
	
	draw = DrawGUIButton,
	handle = HandleGUIButton,
	text = "Setup Robot Block / Stack-Up",
	var_handle = StartRobotBlock,
}

function DrawController(x, y)
	--Main shape (x = 79, y = 79)
	emu.drawRectangle(x+1, y+1, 52, 22, 0x00000000, 1)
	emu.drawRectangle(x, y, 52, 22, 0x008F8F8F, 1)
	emu.drawRectangle(x+1, y+1, 50, 20, 0x00CFCFCF, 1)
	emu.drawRectangle(x+3, y+5, 46, 15, 0x002F2F2F, 1)
	
	--Middle part
	emu.drawRectangle(x+18, y+5, 14, 2, 0x00AFAFAF, 1)
	emu.drawRectangle(x+18, y+8, 14, 2, 0x00AFAFAF, 1)
	emu.drawRectangle(x+18, y+12, 14, 4, 0x00CFCFCF, 1)
	emu.drawRectangle(x+18, y+18, 14, 2, 0x00AFAFAF, 1)

	emu.drawRectangle(x+19, y+13, 5, 2, 0x001F1F1F, 1)	--Select
	emu.drawRectangle(x+26, y+13, 5, 2, 0x001F1F1F, 1)	--Start

	emu.drawRectangle(x+34, y+11, 6, 6, 0x00CFCFCF, 1)
	emu.drawRectangle(x+36, y+12, 2, 4, 0x00CF0000, 1)	--B
	emu.drawRectangle(x+35, y+13, 4, 2, 0x00CF0000, 1)
	emu.drawRectangle(x+41, y+11, 6, 6, 0x00CFCFCF, 1)
	emu.drawRectangle(x+43, y+12, 2, 4, 0x00CF0000, 1)	--A
	emu.drawRectangle(x+42, y+13, 4, 2, 0x00CF0000, 1)

	emu.drawRectangle(x+5, y+11, 10, 4, 0x00CFCFCF, 1)
	emu.drawRectangle(x+8, y+8, 4, 10, 0x00CFCFCF, 1)
	emu.drawRectangle(x+6, y+12, 8, 2, 0x001F1F1F, 1)	--D-Pad
	emu.drawRectangle(x+9, y+9, 2, 8, 0x001F1F1F, 1)
end

function DrawGUI()
	gui_button_main.draw(gui_button_main)
	if gui_button_main.open then
		emu.drawRectangle(5, 27, 224, 90, 0x00000000, 0)
		emu.drawRectangle(4, 26, 224, 90, 0x2F0F6F8F, 1)
		emu.drawRectangle(4, 26, 224, 90, 0x00FFFFFF, 0)

		gui_button_opt_flash.draw(gui_button_opt_flash)
		gui_button_opt_autogyro.draw(gui_button_opt_autogyro)
		emu.drawRectangle(9, 73, 216, 1, 0x00000000, 0)
		emu.drawRectangle(8, 72, 216, 1, 0x00FFFFFF, 0)
		gui_button_startgyro.draw(gui_button_startgyro)
		gui_button_startblock.draw(gui_button_startblock)
	end
	gui_button_help.draw(gui_button_help)
	if gui_button_help.open then
		emu.drawRectangle(5, 27, 246, 176, 0x00000000, 0)
		emu.drawRectangle(4, 26, 246, 176, 0x2F8F6F0F, 1)
		emu.drawRectangle(4, 26, 246, 176, 0x00FFFFFF, 0)
		drawStringShadow(8, 30, "General Information:\nYou can grab and hold R.O.B. accessories with\nthe mouse cursor and the left button.", 0x00FFFFFF)
		emu.drawRectangle(9, 62, 237, 1, 0x00000000, 0)
		emu.drawRectangle(8, 61, 237, 1, 0x00FFFFFF, 0)

		--Help
		if config.mode == "gyro" then
			local game_mode = emu.read(0x5B, emu.memType.nesInternalRam, 0)
			drawStringShadow(8, 68, "Robot Gyro / Gyromite Instructions:", 0x00FFFFFF, 0xFFFFFFFF)

			if game_mode == 0 then
				drawStringShadow(8, 80, "Test Mode:\nThis sends a signal so you can focus\nR.O.B.'s eyes to the T.V. screen.", 0x00FFFFFF, 0xFFFFFFFF)
			elseif game_mode == 1 then
				drawStringShadow(8, 80, "Direct Mode:\nDirectly send commands to R.O.B. for testing.\nA good way to get familiar with the controls.", 0x00FFFFFF, 0xFFFFFFFF)
			elseif game_mode == 2 or game_mode == 3 then
				drawStringShadow(8, 80, "Game A Mode:\nControl Professor Hector and defuse all the\nbombs while avoiding Smicks. Use R.O.B. and\nthe gyros to move gates up and down.\nYou can use turnips with the A or B button\nto keep Smicks busy and pass through them.", 0x00FFFFFF, 0xFFFFFFFF)
			else
				drawStringShadow(8, 80, "Game B Mode:\nProfessor Hector is walking in his sleep.\nUse R.O.B. and the gyros to move gates\nup and down and let him walk safely to the end.", 0x00FFFFFF, 0xFFFFFFFF)
			end

			local rob_controls_x = 88
			local rob_controls_y = 155
			drawStringShadow(8, rob_controls_y-13, "R.O.B. Controls:", 0x00FFFFFF, 0xFFFFFFFF)
			--NES controller
			DrawController(rob_controls_x, rob_controls_y)

			drawStringShadow(rob_controls_x-71, rob_controls_y+8, "Move Arms", 0x00FFFFFF, 0xFFFFFFFF)
			emu.drawLine(rob_controls_x+5, rob_controls_y+12, rob_controls_x-19, rob_controls_y+12, 0x00FFFFFF)
			emu.drawLine(rob_controls_x+5, rob_controls_y+13, rob_controls_x-18, rob_controls_y+13, 0x00000000)

			if game_mode == 0 or game_mode == 1 then
				drawStringShadow(rob_controls_x-40, rob_controls_y+26, "Exit", 0x00FFFFFF, 0xFFFFFFFF)
			else
				drawStringShadow(rob_controls_x-48, rob_controls_y+26, "Pause", 0x00FFFFFF, 0xFFFFFFFF)
			end
			emu.drawLine(rob_controls_x+20, rob_controls_y+14, rob_controls_x+4, rob_controls_y+30, 0x00FFFFFF)
			emu.drawLine(rob_controls_x+3, rob_controls_y+30, rob_controls_x-19, rob_controls_y+30, 0x00FFFFFF)
			emu.drawLine(rob_controls_x+20, rob_controls_y+15, rob_controls_x+4, rob_controls_y+31, 0x00000000)
			emu.drawLine(rob_controls_x+3, rob_controls_y+31, rob_controls_x-18, rob_controls_y+31, 0x00000000)

			if game_mode == 2 or game_mode == 3 then
				drawStringShadow(rob_controls_x+54, rob_controls_y+26, "R.O.B. Mode (Game A)\n(When Paused) Exit", 0x00FFFFFF, 0xFFFFFFFF)
				emu.drawLine(rob_controls_x+29, rob_controls_y+14, rob_controls_x+45, rob_controls_y+30, 0x00FFFFFF)
				emu.drawLine(rob_controls_x+45, rob_controls_y+30, rob_controls_x+49, rob_controls_y+30, 0x00FFFFFF)
				emu.drawLine(rob_controls_x+29, rob_controls_y+15, rob_controls_x+45, rob_controls_y+31, 0x00000000)
				emu.drawLine(rob_controls_x+45, rob_controls_y+31, rob_controls_x+50, rob_controls_y+31, 0x00000000)
			elseif game_mode == 4 then
				drawStringShadow(rob_controls_x+54, rob_controls_y+26, "(When Paused) Exit", 0x00FFFFFF, 0xFFFFFFFF)
				emu.drawLine(rob_controls_x+29, rob_controls_y+14, rob_controls_x+45, rob_controls_y+30, 0x00FFFFFF)
				emu.drawLine(rob_controls_x+45, rob_controls_y+30, rob_controls_x+49, rob_controls_y+30, 0x00FFFFFF)
				emu.drawLine(rob_controls_x+29, rob_controls_y+15, rob_controls_x+45, rob_controls_y+31, 0x00000000)
				emu.drawLine(rob_controls_x+45, rob_controls_y+31, rob_controls_x+50, rob_controls_y+31, 0x00000000)
			end

			drawStringShadow(rob_controls_x+76, rob_controls_y-4, "(B) Close Arms", 0x00FFFFFF, 0xFFFFFFFF)
			emu.drawLine(rob_controls_x+37, rob_controls_y+13, rob_controls_x+51, rob_controls_y-1, 0x00FFFFFF)
			emu.drawLine(rob_controls_x+51, rob_controls_y-1, rob_controls_x+71, rob_controls_y-1, 0x00FFFFFF)
			emu.drawLine(rob_controls_x+38, rob_controls_y+13, rob_controls_x+51, rob_controls_y+0, 0x00000000)
			emu.drawLine(rob_controls_x+52, rob_controls_y+0, rob_controls_x+72, rob_controls_y+0, 0x00000000)

			drawStringShadow(rob_controls_x+76, rob_controls_y+10, "(A) Open Arms", 0x00FFFFFF, 0xFFFFFFFF)
			emu.drawLine(rob_controls_x+44, rob_controls_y+13, rob_controls_x+71, rob_controls_y+13, 0x00FFFFFF)
			emu.drawLine(rob_controls_x+45, rob_controls_y+14, rob_controls_x+72, rob_controls_y+14, 0x00000000)
		elseif config.mode == "block" then
			local game_mode = emu.read(0x38, emu.memType.nesInternalRam, 0)
			drawStringShadow(8, 68, "Robot Block / Stack-Up Instructions:", 0x00FFFFFF, 0xFFFFFFFF)

			if game_mode == 0 then
				drawStringShadow(8, 80, "Test Mode:\nThis sends a signal so you can focus\nR.O.B.'s eyes to the T.V. screen.", 0x00FFFFFF, 0xFFFFFFFF)
			elseif game_mode == 1 then
				drawStringShadow(8, 80, "Direct Mode:\nDirectly send commands to R.O.B. and move\nthe colored blocks from a starting configuration\nto another with as few commands as possible.", 0x00FFFFFF, 0xFFFFFFFF)
			elseif game_mode == 2 then
				drawStringShadow(8, 80, "Memory Mode:\nSet up a list of commands for R.O.B.\nto memorize and move the colored blocks from a\nstarting configuration to another with as\nfew commands as possible.", 0x00FFFFFF, 0xFFFFFFFF)
			elseif game_mode == 3 then
				drawStringShadow(8, 80, "Bingo (1P) Mode:\nPress down a complete row or column of keys to\nsend a command to R.O.B. and move blocks from\na starting configuration to another with as\nfew commands as possible. Enemies will get in your\nway and may also send commands to R.O.B. too!", 0x00FFFFFF, 0xFFFFFFFF)
			elseif game_mode == 4 then
				drawStringShadow(8, 80, "Bingo (2P) Mode:\nPress down a complete row or column of keys to\nsend a command to R.O.B. and move blocks from\nthe stack and compete to put the most blocks\nin their designated trays!", 0x00FFFFFF, 0xFFFFFFFF)
			end

			local rob_controls_x = 52
			local rob_controls_y = 155
			drawStringShadow(8, rob_controls_y-13, "Controls:", 0x00FFFFFF, 0xFFFFFFFF)
			--NES controller
			DrawController(rob_controls_x, rob_controls_y)

			drawStringShadow(rob_controls_x-44, rob_controls_y+8, "Move", 0x00FFFFFF, 0xFFFFFFFF)
			emu.drawLine(rob_controls_x+5, rob_controls_y+12, rob_controls_x-19, rob_controls_y+12, 0x00FFFFFF)
			emu.drawLine(rob_controls_x+5, rob_controls_y+13, rob_controls_x-18, rob_controls_y+13, 0x00000000)

			drawStringShadow(rob_controls_x-40, rob_controls_y+26, "Exit", 0x00FFFFFF, 0xFFFFFFFF)
			emu.drawLine(rob_controls_x+20, rob_controls_y+14, rob_controls_x+4, rob_controls_y+30, 0x00FFFFFF)
			emu.drawLine(rob_controls_x+3, rob_controls_y+30, rob_controls_x-19, rob_controls_y+30, 0x00FFFFFF)
			emu.drawLine(rob_controls_x+20, rob_controls_y+15, rob_controls_x+4, rob_controls_y+31, 0x00000000)
			emu.drawLine(rob_controls_x+3, rob_controls_y+31, rob_controls_x-18, rob_controls_y+31, 0x00000000)

			if game_mode == 1 then
				drawStringShadow(rob_controls_x+54, rob_controls_y+26, "Go To Next Phase", 0x00FFFFFF, 0xFFFFFFFF)
				emu.drawLine(rob_controls_x+29, rob_controls_y+14, rob_controls_x+45, rob_controls_y+30, 0x00FFFFFF)
				emu.drawLine(rob_controls_x+45, rob_controls_y+30, rob_controls_x+49, rob_controls_y+30, 0x00FFFFFF)
				emu.drawLine(rob_controls_x+29, rob_controls_y+15, rob_controls_x+45, rob_controls_y+31, 0x00000000)
				emu.drawLine(rob_controls_x+45, rob_controls_y+31, rob_controls_x+50, rob_controls_y+31, 0x00000000)
			elseif game_mode == 2 then
				drawStringShadow(rob_controls_x+54, rob_controls_y+26, "Confirm / Go To Next Phase", 0x00FFFFFF, 0xFFFFFFFF)
				emu.drawLine(rob_controls_x+29, rob_controls_y+14, rob_controls_x+45, rob_controls_y+30, 0x00FFFFFF)
				emu.drawLine(rob_controls_x+45, rob_controls_y+30, rob_controls_x+49, rob_controls_y+30, 0x00FFFFFF)
				emu.drawLine(rob_controls_x+29, rob_controls_y+15, rob_controls_x+45, rob_controls_y+31, 0x00000000)
				emu.drawLine(rob_controls_x+45, rob_controls_y+31, rob_controls_x+50, rob_controls_y+31, 0x00000000)
			
				drawStringShadow(rob_controls_x+76, rob_controls_y-4, "(B) Select Command Left", 0x00FFFFFF, 0xFFFFFFFF)
				emu.drawLine(rob_controls_x+37, rob_controls_y+13, rob_controls_x+51, rob_controls_y-1, 0x00FFFFFF)
				emu.drawLine(rob_controls_x+51, rob_controls_y-1, rob_controls_x+71, rob_controls_y-1, 0x00FFFFFF)
				emu.drawLine(rob_controls_x+38, rob_controls_y+13, rob_controls_x+51, rob_controls_y+0, 0x00000000)
				emu.drawLine(rob_controls_x+52, rob_controls_y+0, rob_controls_x+72, rob_controls_y+0, 0x00000000)

				drawStringShadow(rob_controls_x+76, rob_controls_y+10, "(A) Select Command Right", 0x00FFFFFF, 0xFFFFFFFF)
				emu.drawLine(rob_controls_x+44, rob_controls_y+13, rob_controls_x+71, rob_controls_y+13, 0x00FFFFFF)
				emu.drawLine(rob_controls_x+45, rob_controls_y+14, rob_controls_x+72, rob_controls_y+14, 0x00000000)
			elseif game_mode == 3 or game_mode == 4 then
				drawStringShadow(rob_controls_x+54, rob_controls_y+26, "(When Paused)\nGo To Next Phase", 0x00FFFFFF, 0xFFFFFFFF)
				emu.drawLine(rob_controls_x+29, rob_controls_y+14, rob_controls_x+45, rob_controls_y+30, 0x00FFFFFF)
				emu.drawLine(rob_controls_x+45, rob_controls_y+30, rob_controls_x+49, rob_controls_y+30, 0x00FFFFFF)
				emu.drawLine(rob_controls_x+29, rob_controls_y+15, rob_controls_x+45, rob_controls_y+31, 0x00000000)
				emu.drawLine(rob_controls_x+45, rob_controls_y+31, rob_controls_x+50, rob_controls_y+31, 0x00000000)
			
				drawStringShadow(rob_controls_x+76, rob_controls_y-4, "(B) Pause", 0x00FFFFFF, 0xFFFFFFFF)
				emu.drawLine(rob_controls_x+37, rob_controls_y+13, rob_controls_x+51, rob_controls_y-1, 0x00FFFFFF)
				emu.drawLine(rob_controls_x+51, rob_controls_y-1, rob_controls_x+71, rob_controls_y-1, 0x00FFFFFF)
				emu.drawLine(rob_controls_x+38, rob_controls_y+13, rob_controls_x+51, rob_controls_y+0, 0x00000000)
				emu.drawLine(rob_controls_x+52, rob_controls_y+0, rob_controls_x+72, rob_controls_y+0, 0x00000000)

				drawStringShadow(rob_controls_x+76, rob_controls_y+10, "(A) Pause", 0x00FFFFFF, 0xFFFFFFFF)
				emu.drawLine(rob_controls_x+44, rob_controls_y+13, rob_controls_x+71, rob_controls_y+13, 0x00FFFFFF)
				emu.drawLine(rob_controls_x+45, rob_controls_y+14, rob_controls_x+72, rob_controls_y+14, 0x00000000)
			end
		end
	end
end

function HandleGUI()
	gui_button_main.handle(gui_button_main)
	if gui_button_main.open then
		gui_button_opt_flash.handle(gui_button_opt_flash)
		gui_button_opt_autogyro.handle(gui_button_opt_autogyro)
		gui_button_startgyro.handle(gui_button_startgyro)
		gui_button_startblock.handle(gui_button_startblock)
	end
	gui_button_help.handle(gui_button_help)
end

startROB()
