-- ripoff of digilines_lcd


local chars_file = io.open(minetest.get_modpath("dronetest_display").."/characters", "r")
local charmap = {}
local max_chars = 12
if not chars_file then
	print("[dronetest_display] E: character map file not found")
else
	while true do
		local char = chars_file:read("*l")
		if char == nil then
			break
		end
		local img = chars_file:read("*l")
		chars_file:read("*l")
		charmap[char] = img
	end
end
local displays = {
	-- on ceiling
	--* [0] = {delta = {x = 0, y = 0.4, z = 0}, pitch = math.pi / -2},
	-- on ground
	--* [1] = {delta = {x = 0, y =-0.4, z = 0}, pitch = math.pi /  2},
	-- sides
	[2] = {delta = {x =  0.4, y = 0, z = 0}, yaw = math.pi / -2},
	[3] = {delta = {x = -0.4, y = 0, z = 0}, yaw = math.pi /  2},
	[4] = {delta = {x = 0, y = 0, z =  0.4}, yaw = 0},
	[5] = {delta = {x = 0, y = 0, z = -0.4}, yaw = math.pi},
}
local clearscreen = function(pos)
	local objects = minetest.get_objects_inside_radius(pos, 0.5)
	for _, o in ipairs(objects) do
		if o:get_entity_name() == "dronetest_display:text" then
			o:remove()
		end
	end
end

local prepare_writing = function(pos)
	local display_info = displays[minetest.get_node(pos).param2]
	if display_info == nil then return end
	local text = minetest.add_entity(
		{x = pos.x + display_info.delta.x,
		 y = pos.y + display_info.delta.y,
		 z = pos.z + display_info.delta.z}, "dronetest_display:text")
	--print("test:"..type(text))
	if type(text) ~= "userdata" then return nil end
	text:setyaw(display_info.yaw or 0)
	--* text:setpitch(display_info.yaw or 0)
	return text
end

local reset_meta = function(pos)
	minetest.get_meta(pos):set_string("formspec", "field[channel;Channel;${channel}]")
end
dronetest_display = {}
dronetest_display.actions = {
	get_size = { desc= "returns size in characters", func = function() return 80,33 end }
}

local on_digiline_receive = function(pos, node, channel, msg)
	local meta = minetest.get_meta(pos)
	local setchan = meta:get_string("channel")
	if setchan ~= channel then return end
	if type(msg) == "table" and type(msg.action) == "string" then
		if msg.action == "GET_CAPABILITIES"  and type(msg.msg_id) == "string" then
			local cap = {}
			for n,v in pairs(dronetest_display.actions) do
				cap[n] = v.desc
			end
			-- send capabilities
			digiline:receptor_send(pos, digiline.rules.default,channel, {action = "CAPABILITIES",msg_id = msg.msg_id,msg = cap })
		elseif dronetest_display.actions[msg.action] ~= nil then
			-- execute function
			local response = {dronetest_display.actions[msg.action].func(msg.argv[1],msg.argv[2],msg.argv[3],msg.argv[4],msg.argv[5])}
			
			-- send response
			digiline:receptor_send(pos, digiline.rules.default,channel, {action = msg.action ,msg_id = msg.msg_id,msg = response })
		end
		return
	end
	
	--print("display received "..dump(msg))
	meta:set_string("text", msg)
	clearscreen(pos)
	if msg ~= "" then
		prepare_writing(pos)
	end
end

local display_box = {
	type = "wallmounted",
	wall_top = {-8/16, 7/16, -8/16, 8/16, 8/16, 8/16}
}

minetest.register_node("dronetest_display:display", {
	drawtype = "nodebox",
	description = "Dronetest Digiline Display",
	inventory_image = "computerFront.png",
	wield_image = "computerFront.png",
	tiles = {"computerFront.png"},

	paramtype = "light",
	sunlight_propagates = true,
	paramtype2 = "wallmounted",
	node_box = display_box,
	selection_box = display_box,
	groups = {choppy = 3, dig_immediate = 2},

	after_place_node = function (pos, placer, itemstack)
		local param2 = minetest.get_node(pos).param2
		if param2 == 0 or param2 == 1 then
			minetest.add_node(pos, {name = "dronetest_display:display", param2 = 3})
		end
		prepare_writing(pos)
	end,

	on_construct = function(pos)
		reset_meta(pos)
	end,

	on_destruct = function(pos)
		clearscreen(pos)
	end,

	on_receive_fields = function(pos, formname, fields, sender)
		if (fields.channel) then
			minetest.get_meta(pos):set_string("channel", fields.channel)
		end
	end,

	digiline = 
	{
		receptor = {},
		effector = {
			action = on_digiline_receive
		},
	},

	light_source = 6,
})

minetest.register_entity("dronetest_display:text", {
	collisionbox = { 0, 0, 0, 0, 0, 0 },
	visual = "upright_sprite",
	textures = {},

	on_activate = function(self)
		local meta = minetest.get_meta(self.object:getpos())
		local text = meta:get_string("text")
		--print("TEXT: "..text)
		self.object:set_properties({textures={dronetest.generate_texture(dronetest.create_lines(text))}})
	end
})

-- CONSTANTS
local LCD_WITH = 640
local LCD_PADDING = 80

local LINE_LENGTH = 80
local NUMBER_OF_LINES = 33

local LINE_HEIGHT = 12
local CHAR_WIDTH = 5
--local CHAR_WIDTH = 36

local chars_file = io.open(minetest.get_modpath("dronetest_display").."/characters", "r")
local charmap = {}
local max_chars = 80
if not chars_file then
	print("[dronetest] E: character map file not found")
else
	while true do
		local char = chars_file:read("*l")
		if char == nil then
			break
		end
		local img = chars_file:read("*l")
		chars_file:read("*l")
		charmap[char] = img
	end
end

function dronetest.create_lines(text)
	--print("TEXT: "..text)
	local line = ""
	local line_num = 1
	local tab = {}
	local pre
	local post = ""
	local lines = {}
	for _,word in ipairs(text:split("\n")) do
	
		
		pre = word:sub(1,LINE_LENGTH)
		table.insert(lines,pre)
		post = word:sub(LINE_LENGTH+1)
		
		while post:len() > LINE_LENGTH do
			word = post:sub(1,LINE_LENGTH)
			table.insert(lines,word)
			post = post:sub(LINE_LENGTH+1)
		end
		if post ~= "" then
			table.insert(lines,post)
		end
		
	end
	for _,word in ipairs(lines) do
			line = word
			table.insert(tab, line)
			line_num = line_num+1
			if line_num > NUMBER_OF_LINES then
				return tab
			end
		--end
	end
	--table.insert(tab, line)
	return tab
end

function dronetest.generate_texture(lines)
	--local texture = "[combine:"..LCD_WITH.."x"..LCD_WITH..":0,0=screen.png"
	local texture = "[combine:"..LCD_WITH.."x"..LCD_WITH..""
	local ypos = LCD_PADDING
	for i = 1, #lines do
		texture = texture..dronetest.generate_line(lines[i], ypos)
		ypos = ypos + LINE_HEIGHT
	end
	--print(texture)
	return texture
end

function dronetest.generate_line(s, ypos)
	local i = 1
	local parsed = {}
	local width = 0
	local chars = 0
	while chars < max_chars and i <= #s do
		local file = nil
		if charmap[s:sub(i, i)] ~= nil then
			file = charmap[s:sub(i, i)]
			i = i + 1
		elseif i < #s and charmap[s:sub(i, i + 1)] ~= nil then
			file = charmap[s:sub(i, i + 1)]
			i = i + 2
		else
			print("[dronetest] W: unknown symbol in '"..s.."' at "..i)
			i = i + 1
		end
		if file ~= nil then
			width = width + CHAR_WIDTH
			table.insert(parsed, file)
			chars = chars + 1
		end
	end
	width = width - 1

	local texture = ""
	local xpos = math.floor((LCD_WITH - 2 * LCD_PADDING - width) / 2 + LCD_PADDING)
	xpos = LCD_PADDING --?
	for i = 1, #parsed do
		texture = texture..":"..xpos..","..ypos.."=dronetest"..parsed[i]..".png"
		xpos = xpos + CHAR_WIDTH + 1
	end
	
	return texture
end