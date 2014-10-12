

--Manage config.
--Saves contents of config to file.
local function saveConfig(path, config, doc)
	local file = io.open(path,"w")
	if file then
		for i,v in pairs(config) do
			
			local t = type(v)
			if (t == "string" or t == "number" or t == "boolean") then
				if doc and doc[i] then -- save only those with a description!
					file:write("# "..doc[i].."\n")
					file:write(i.." = "..tostring(v).."\n")
				end
				
			end
		end
	end
end
--Loads config and returns config values inside table.
local function loadConfig(path)
	local config = {}
	local file = io.open(path,"r")
  	if file then
  		io.close(file)
		for line in io.lines(path) do
			if line:sub(1,1) ~= "#" then
				i, v = line:match("^(%S*) = (%S*)")
				if i and v then
					if v == "true" then v = true end
					if v == "false" then v = false end
					if tonumber(v) then v = tonumber(v) end
					config[i] = v
				end
			end
		end
		return config
	else
		--Create config file.
		return nil
	end
end


dronetest.save = function ()
	saveConfig(dronetest.mod_dir.."/config.txt", dronetest, doc)
end

minetest.register_on_shutdown(dronetest.save)

dronetest.config = loadConfig(dronetest.mod_dir.."/config.txt")
if dronetest.config then
	for i,v in pairs(dronetest.config) do
		if type(dronetest[i]) == type(v) then
			dronetest[i] = v
		end
	end
else
	dronetest.save()
end
