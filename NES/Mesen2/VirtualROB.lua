-- Virtual Robotic Operating Buddy
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

objects = {}

accel = 0.1
accel_max = 1
blue_press = 0
red_press = 0

y_base = 6.0
y_max = 7.5
x_scale = 10

hud_x = 200
hud_y = 172

--amount of frames for a gyro to spin
spin_max = 60*10

prev_buffer = {}

--Utility
function GetMousePositionHUD()
	local mouse = emu.getMouseState()
	local ret = {}
	ret.x = (mouse.x - hud_x) / x_scale
	ret.y = (mouse.y - hud_y) / 8
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
		if v.x == x and v.y < y and v.y >= y - 1 then
			return v
		end
	end
	return nil
end

function FindBelowObject(x, y)
	for k,v in pairs(objects) do
		if v.x == x and v.y > y and v.y <= y + 1 then
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
	if self.grabbed == 0 and (self.x >= rob.x - 0.2 and self.x <= rob.x + 0.2) and self.y == rob.y then
		if rob.state == 1 then
			local upobj = FindAboveObject(self.x, self.y)
			while (upobj ~= nil) do
				upobj.x = upobj.x - rob.x_speed
				upobj = FindAboveObject(self.x, upobj.y)
			end
			self.x = self.x - rob.x_speed
		elseif rob.state == 2 then
			local upobj = FindAboveObject(self.x, self.y)
			while (upobj ~= nil) do
				upobj.x = upobj.x + rob.x_speed
				upobj = FindAboveObject(self.x, upobj.y)
			end
			self.x = self.x + rob.x_speed
		end
	end

	--If Closed Arms move to the object from above, make it fall off
	if self.grabbed == 0 and rob.arms == 0 and (self.y >= rob.y - 0.2 and self.y <= rob.y + 0.2) and self.x == rob.x then
		if rob.state == 4 then
			self.x = self.x - rob.x_speed
		end
	end

	--Handle Physics
	local lowobj = FindBelowObject(self.x, self.y)
	if (lowobj == nil) then lowobj = { y = y_max } end
	if lowobj.y > y_base and self.x ~= math.floor(self.x) then lowobj = {y = y_max} end

	if self.grabbed == 1 then
		local upobj = FindAboveObject(self.x, self.y)
		while (upobj ~= nil) do
			upobj.x = rob.x
			upobj = FindAboveObject(self.x, upobj.y)
		end
		self.x = rob.x
		self.y = rob.y
		self.gravity = 0
	elseif self.y < lowobj.y - 1 then
		if self.gravity < accel_max then
			self.gravity = self.gravity + accel
		else
			self.gravity = accel_max
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
		if rob.ynext > y_base - 1 then rob.ynext = y_base - 1 end
		rob.state = 4
		rob.led = 1
	elseif currentCommand == 1101 then
		--Down + 2
		rob.ynext = math.floor(rob.y + 2 + 0.5)
		if rob.ynext > y_base - 1 then rob.ynext = y_base - 1 end
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
	emu.drawRectangle(x - 5, y - 4, x_scale*5 + 8, 8*(y_max+1) + 2, 0x003F3F00, 0)
	emu.drawRectangle(x - 4, y - 3, x_scale*5 + 6, 8*(y_max+1), 0x3F1F1F00, 1)

	--ROB face
	--emu.drawRectangle(x + 10, y + 3, 20, 10, 0x3FFFFFFF, 0)
	--emu.drawRectangle(x + 12, y + 5, 6, 6, 0x3FFFFFFF, 0)
	--emu.drawRectangle(x + 22, y + 5, 6, 6, 0x3FFFFFFF, 0)
	--emu.drawRectangle(x + 17, y + 13, 6, 20, 0x3FFFFFFF, 0)
	
	emu.drawRectangle(x + 1 + 2 * x_scale, y - 3, 6, 3, 0x3FFF7F7F, rob.led)

	--center of arms
	emu.drawPixel(x + 3 + (rob.x * x_scale), y + 3 + (rob.y * 8), 0x3F7FFF7F)
	emu.drawPixel(x + 4 + (rob.x * x_scale), y + 4 + (rob.y * 8), 0x3F7FFF7F)
	--emu.drawRectangle(x + (rob.x * 8), y + (rob.y * 8), 8, 8, 0x3F7FFF7F, 0)
	
	DrawObjects(x, y)

	--arms
	emu.drawRectangle(x + 0 + (rob.x * x_scale) - rob.arms, y + (rob.y * 8), 4, 8, 0x3F7FFF7F, 0)
	emu.drawRectangle(x + 4 + (rob.x * x_scale) + rob.arms, y + (rob.y * 8), 4, 8, 0x3F7FFF7F, 0)
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
		-- Else it's probably just the game screen so just return 0
		return 0;
	else
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
		--emu.drawString(120, 24, "bit3 = " .. color, 0xFFFFFF, 0xFF000000)
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
		--emu.drawString(120, 24, "bit2 = " .. color, 0xFFFFFF, 0xFF000000)
		if color == 1 then
			command = command + 0100
		end
	elseif frameCount == 6 and color == 1 then
		frameCount = frameCount + 1
	elseif frameCount == 7 then
		--bit1
		frameCount = frameCount + 1
		--emu.drawString(120, 24, "bit1 = " .. color, 0xFFFFFF, 0xFF000000)
		if color == 1 then
			command = command + 0010
		end
	elseif frameCount == 8 and color == 1 then
		frameCount = frameCount + 1
	elseif frameCount == 9 then
		--bit0
		frameCount = frameCount + 1
		--emu.drawString(120, 24, "bit0 = " .. color, 0xFFFFFF, 0xFF000000)
		if color == 1 then
			command = command + 0001
		end
		StartCommand(command)
	else
		frameCount = 0
	end

	--Anti-Flashing
	if frameCount > 0 or (frameCount == 0 and color == 0) then
		emu.setScreenBuffer(prev_buffer)
	elseif color == -1 then
		prev_buffer = emu.getScreenBuffer()
	end

	--Display
	--emu.drawRectangle(0, 0, 256, 50, 0x3F000000, 1)
	
	--emu.drawString(12, 12, "Frame: " .. frameCount, 0xFFFFFF, 0xFF000000)
	--emu.drawString(70, 12, "Color: " .. color, 0xFFFFFF, 0xFF000000)
	--emu.drawString(120, 12, "Command: " .. currentCommand, 0xFFFFFF, 0xFF000000)
	--emu.drawString(200, 12, "State: " .. rob.state, 0xFFFFFF, 0xFF000000)
	
	--emu.drawString(12, 12*2, "X Pos: " .. rob.x, 0xFFFFFF, 0xFF000000)
	--emu.drawString(12, 12*3, "Y Pos: " .. rob.y, 0xFFFFFF, 0xFF000000)
	
	--emu.drawString(10, 12*0, "Gyro1 X: " .. objects.gyro1.x, 0xFFFFFF, 0xFF000000)
	--emu.drawString(10, 12*1, "Gyro1 Y: " .. objects.gyro1.y, 0xFFFFFF, 0xFF000000)

	--emu.drawString(10, 12*2, "Gyro2 X: " .. objects.gyro2.x, 0xFFFFFF, 0xFF000000)
	--emu.drawString(10, 12*3, "Gyro2 Y: " .. objects.gyro2.y, 0xFFFFFF, 0xFF000000)

	DrawROB(hud_x, hud_y)
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

	if self.y <= y_base then
		emu.drawRectangle(x + 0 + (self.x * x_scale), y + 1 + (self.y * 8), 8, 2, color, 1)
		emu.drawRectangle(x + 1 + (self.x * x_scale), y + 3 + (self.y * 8), 6, 2, color, 1)
		emu.drawRectangle(x + 2 + (self.x * x_scale), y + 5 + (self.y * 8), 4, 2, color, 1)
		emu.drawRectangle(x + 3 + (self.x * x_scale), y + 7 + (self.y * 8), 2, 2, color, 1)
	else
		emu.drawRectangle(x + 1 + (self.x * x_scale), y + 0 + (self.y * 8), 2, 8, color, 1)
		emu.drawRectangle(x + 3 + (self.x * x_scale), y + 1 + (self.y * 8), 2, 6, color, 1)
		emu.drawRectangle(x + 5 + (self.x * x_scale), y + 2 + (self.y * 8), 2, 4, color, 1)
		emu.drawRectangle(x + 7 + (self.x * x_scale), y + 3 + (self.y * 8), 2, 2, color, 1)
	end

	if self.spin > 0 then
		local frames = 7 - emu.getState().frameCount % 8
		if (self.spin <= 60*5) then frames = 8 - emu.getState().frameCount % 16 / 2 end
		if (self.spin <= 60*2) then frames = 8 - emu.getState().frameCount % 32 / 4 end
		emu.drawPixel(x + 0 + (self.x * x_scale) + frames, y + 0 + (self.y * 8), 0x00FFFFFF)
	end
end

function HandleGyroObject(self)
	HandlePhysicsObject(self)
	if self.spin > 0 then self.spin = self.spin - 1 end
	if self.y > y_base then self.spin = 0 end
	if objects.bluebtn.x == self.x or objects.redbtn.x == self.x then
		if self.grabbed == 0 and self.spin <= 0 and self.y == y_base - 1 then self.x = self.x - 0.2 end
	end
end

function DrawGyroMotorObject(self, x, y)
	emu.drawRectangle(x + 2 + (self.x * x_scale), y + 0 + (self.y * 8), 4, 2, self.color, 1)
	emu.drawRectangle(x + 1 + (self.x * x_scale), y + 2 + (self.y * 8), 6, 2, self.color, 1)
end

function HandleGyroMotorObject(self)
	if objects.gyro1.x == self.x and objects.gyro1.y == (self.y - 1) then objects.gyro1.spin = spin_max end
	if objects.gyro2.x == self.x and objects.gyro2.y == (self.y - 1) then objects.gyro2.spin = spin_max end
end

function DrawGyroButtonObject(self, x, y)
	emu.drawRectangle(x + 1 + (self.x * x_scale), y + 0 + (self.y * 8) + self.pressed, 6, 2, self.color, 1)
end

function HandleGyroButtonObject(self)
	self.pressed = 0
	if FindAboveObject(self.x, self.y) ~= nil then self.pressed = 1 end
end

function StartRobotGyro()
	objects = {}
	objects.gyro1 = {
		x = 0,
		y = y_base - 1,
		gravity = 0,
		grabbed = 0,
		falling = 0,
		mousegrab = 0,
	
		spin = 0,
		color = 0x3F7F7F3F,
		colorgrab = 0x3FFFFF7F,
		draw = DrawGyroObject,
		handle = HandleGyroObject
	}
	
	objects.gyro2 = {
		x = 1,
		y = y_base - 1,
		gravity = 0,
		grabbed = 0,
		falling = 0,
		mousegrab = 0,
	
		spin = 0,
		color = 0x3F3F7F7F,
		colorgrab = 0x3F7FFFFF,
		draw = DrawGyroObject,
		handle = HandleGyroObject
	}
	
	objects.spinner = {
		x = 4,
		y = y_base,
		gravity = 0,
		grabbed = 0,
		falling = 0,
		locked = 1,
		mousegrab = 0,
	
		color = 0x3FFFFFFF,
		draw = DrawGyroMotorObject,
		handle = HandleGyroMotorObject
	}
	
	objects.bluebtn = {
		x = 2,
		y = y_base,
		gravity = 0,
		grabbed = 0,
		falling = 0,
		locked = 1,
		mousegrab = 0,
	
		pressed = 0,
		color = 0x3F7F7FFF,
		draw = DrawGyroButtonObject,
		handle = HandleGyroButtonObject
	}
	
	objects.redbtn = {
		x = 3,
		y = y_base,
		gravity = 0,
		grabbed = 0,
		falling = 0,
		locked = 1,
		mousegrab = 0,
	
		pressed = 0,
		color = 0x3FFF7F7F,
		draw = DrawGyroButtonObject,
		handle = HandleGyroButtonObject
	}

	objects.holder1 = {
		x = 0,
		y = y_base,
		gravity = 0,
		grabbed = 0,
		falling = 0,
		locked = 1,
		mousegrab = 0,

		color = 0x3F7F7F7F,
		draw = DrawHolderObject,
		handle = HandlePhysicsObject
	}

	objects.holder2 = {
		x = 1,
		y = y_base,
		gravity = 0,
		grabbed = 0,
		falling = 0,
		locked = 1,
		mousegrab = 0,

		color = 0x3F7F7F7F,
		draw = DrawHolderObject,
		handle = HandlePhysicsObject
	}
	emu.displayMessage("Script", "Virtual ROB - Robot Gyro")
end

--Stack-Up specific
function DrawBlockObject(self, x, y)
	local color = self.color
	if self.grabbed == 1 or self.mousegrab == 1 then color = self.colorgrab end
	emu.drawRectangle(x + (self.x * x_scale), y + (self.y * 8), 8, 8, color, 1)
	--highlight
	emu.drawLine(x + (self.x * x_scale), y + (self.y * 8), x + (self.x * x_scale) + 7, y + (self.y * 8), self.colorgrab)
	emu.drawLine(x + (self.x * x_scale), y + (self.y * 8), x + (self.x * x_scale), y + (self.y * 8) + 7, self.colorgrab)
	--shadow
	emu.drawLine(x + (self.x * x_scale) + 1, y + (self.y * 8) + 7, x + (self.x * x_scale) + 7, y + (self.y * 8) + 7, 0xAF000000)
	emu.drawLine(x + (self.x * x_scale) + 7, y + (self.y * 8) + 1, x + (self.x * x_scale) + 7, y + (self.y * 8) + 7, 0xAF000000)

end

function DrawHolderObject(self, x, y)
	emu.drawRectangle(x + 1 + (self.x * x_scale), y + (self.y * 8), 6, 4, self.color, 1)
	--shadow
	emu.drawLine(x + (self.x * x_scale) + 1, y + (self.y * 8) + 3, x + (self.x * x_scale) + 6, y + (self.y * 8) + 3, 0xAF000000)
	emu.drawLine(x + (self.x * x_scale) + 1, y + (self.y * 8) + 0, x + (self.x * x_scale) + 6, y + (self.y * 8) + 0, 0xAF000000)
end

function StartRobotBlock()
	objects = {}

	objects.blockred = {
		x = 0,
		y = y_base - 1,
		gravity = 0,
		grabbed = 0,
		falling = 0,
		mousegrab = 0,

		spin = 0,
		color = 0x1FAF0F0F,
		colorgrab = 0x1FFF3F3F,
		draw = DrawBlockObject,
		handle = HandlePhysicsObject
	}

	objects.blockwhite = {
		x = 1,
		y = y_base - 1,
		gravity = 0,
		grabbed = 0,
		falling = 0,
		mousegrab = 0,

		spin = 0,
		color = 0x1FAFAFAF,
		colorgrab = 0x1FFFFFFF,
		draw = DrawBlockObject,
		handle = HandlePhysicsObject
	}

	objects.blockblue = {
		x = 2,
		y = y_base - 1,
		gravity = 0,
		grabbed = 0,
		falling = 0,
		mousegrab = 0,

		spin = 0,
		color = 0x1F0F4FAF,
		colorgrab = 0x1F8F8FFF,
		draw = DrawBlockObject,
		handle = HandlePhysicsObject
	}

	objects.blockyellow = {
		x = 3,
		y = y_base - 1,
		gravity = 0,
		grabbed = 0,
		falling = 0,
		mousegrab = 0,

		spin = 0,
		color = 0x1FCFCF00,
		colorgrab = 0x1FFFFF3F,
		draw = DrawBlockObject,
		handle = HandlePhysicsObject
	}

	objects.blockgreen = {
		x = 4,
		y = y_base - 1,
		gravity = 0,
		grabbed = 0,
		falling = 0,
		mousegrab = 0,

		spin = 0,
		color = 0x1F0FAF0F,
		colorgrab = 0x1F3FFF3F,
		draw = DrawBlockObject,
		handle = HandlePhysicsObject
	}



	objects.holder1 = {
		x = 0,
		y = y_base,
		gravity = 0,
		grabbed = 0,
		falling = 0,
		locked = 1,
		mousegrab = 0,

		color = 0x3F7F7F7F,
		draw = DrawHolderObject,
		handle = HandlePhysicsObject
	}

	objects.holder2 = {
		x = 1,
		y = y_base,
		gravity = 0,
		grabbed = 0,
		falling = 0,
		locked = 1,
		mousegrab = 0,

		color = 0x3F7F7F7F,
		draw = DrawHolderObject,
		handle = HandlePhysicsObject
	}

	objects.holder3 = {
		x = 2,
		y = y_base,
		gravity = 0,
		grabbed = 0,
		falling = 0,
		locked = 1,
		mousegrab = 0,

		color = 0x3F7F7F7F,
		draw = DrawHolderObject,
		handle = HandlePhysicsObject
	}

	objects.holder4 = {
		x = 3,
		y = y_base,
		gravity = 0,
		grabbed = 0,
		falling = 0,
		locked = 1,
		mousegrab = 0,

		color = 0x3F7F7F7F,
		draw = DrawHolderObject,
		handle = HandlePhysicsObject
	}

	objects.holder5 = {
		x = 4,
		y = y_base,
		gravity = 0,
		grabbed = 0,
		falling = 0,
		locked = 1,
		mousegrab = 0,

		color = 0x3F7F7F7F,
		draw = DrawHolderObject,
		handle = HandlePhysicsObject
	}

	emu.displayMessage("Script", "Virtual ROB - Robot Block")
end

startROB()
StartRobotGyro()
--StartRobotBlock()
