
dronetest.get_menu_formspec = function()
	local p = -0.5
	local formspec = "label[0,-0.3;Settings:]"
	for i,v in pairs(dronetest) do
		local t = type(v)
		if dronetest.doc[i] ~= nil then
		if t == "string" or t == "number" then
			p = p + 1.5
			formspec = formspec.."field[0.3,"..p..";4,1;dronetest:"..i..";"..i.." ("..dronetest.doc[i]..")"..";"..v.."]"
		elseif t == "boolean" then
			p = p + 0.5
			formspec = formspec.."checkbox[0,"..p..";dronetest:"..i..";"..i.." ("..dronetest.doc[i]..")"..";"..tostring(v).."]"
		end
		end
	end
	p = p + 1
	formspec = "size[4,"..p..";]\n"..formspec
	return formspec
end
minetest.register_on_player_receive_fields(function(player, formname, fields)
	dronetest.log("minetest.register_on_player_receive_fields received '"..formname.."'")
	local key = {formname:match("([^:]+):([^:]+):([^:]+)")}
		
	-- Handle a drone's menu
	if #key==3 and key[1] == "dronetest" and key[2] == "drone" then --
		local id = tonumber(key[3])
		if (fields["quit"] == true and fields["input"] == "") or fields["exit"] ~= nil then
			return false
		elseif fields["channel"] ~= nil then
			dronetest.drones[id].channel = fields.channel
		end
		return true
	-- handle computer's menu in node's handler
	elseif formname == "dronetest:computer" then -- apply config changes from menu
		dronetest.log("skipping handler for computer")
		return false -- return false to allow next handler to take this
		
	-- apply config changes from config-menu
	elseif formname == "dronetest:menu" then 
		for i,v in pairs(dronetest) do
			local t = type(v)
			if t == "string" or t == "number" or t == "boolean" then
				if fields["dronetest:"..i] then
					if t == "string" then 
						dronetest[i] = fields["dronetest:"..i] 
					elseif t == "number" then 
						dronetest[i] = tonumber(fields["dronetest:"..i]) 
					elseif t == "boolean" then 
						if fields["dronetest:"..i] == "true" then dronetest[i] = true end
						if fields["dronetest:"..i] == "false" then dronetest[i] = false end
					end
				end	
			end
		end
		dronetest.save()
	end
	return false
end)
