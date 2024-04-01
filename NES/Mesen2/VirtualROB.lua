-- Virtual Robotic Operating Buddy (Mesen 2.0)
-- Code by LuigiBlood
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
	x = 200,
	y = 172,
	x_scale = 10
}

config = {
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
	DrawMouseDebug()
end

function inputPoll()
	if objects.bluebtn ~= nil and objects.redbtn ~= nil then
		emu.setInput({a = objects.bluebtn.pressed, b = objects.redbtn.pressed}, 1, 1)
	end
end

function startROB()
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

	emu.displayMessage("Script", "Virtual ROB - Robot Block")
end

startROB()
StartRobotGyro()
--StartRobotBlock()
