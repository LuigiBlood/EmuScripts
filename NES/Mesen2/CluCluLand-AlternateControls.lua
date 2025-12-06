-- Alternate Controls for Clu Clu Land (Mesen 2.0)
-- Changes Left & Right Hand based on the direction of the player (only uses Left & Right on the D-pad instead of 4 directions)
-- Code by LuigiBlood

--$0006 = Temp Direction for current player
--  0 = Down
--  1 = Up
--  2 = Right
--  3 = Left
--$000A = Current Player
--$0046/47 = Controls for Player 1 & 2
--  1 = Right, 2 = Left, 4 = Down, 8 = Up

function testDirection()
	local player = emu.read(0x000A, emu.memType.nesMemory, false)
	local direction = emu.read(0x0006, emu.memType.nesMemory, false)
	local input = emu.getInput(player)
	
	local inputChange = emu.read(0x0046 + player, emu.memType.nesMemory, false)
	inputChange = inputChange & 0xF0
	
	--change Input here
	if input.left == true then
		if direction == 0 then inputChange = inputChange | 1 end
		if direction == 1 then inputChange = inputChange | 2 end
		if direction == 2 then inputChange = inputChange | 8 end
		if direction == 3 then inputChange = inputChange | 4 end
	end
	if input.right == true then
		if direction == 0 then inputChange = inputChange | 2 end
		if direction == 1 then inputChange = inputChange | 1 end
		if direction == 2 then inputChange = inputChange | 4 end
		if direction == 3 then inputChange = inputChange | 8 end
	end

	emu.write(0x0046 + player, inputChange, emu.memType.nesMemory)
end

emu.addMemoryCallback(testDirection, emu.callbackType.exec, 0xCCCD)