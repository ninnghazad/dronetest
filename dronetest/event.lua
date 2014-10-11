dronetest.events = {}
dronetest.events.callbacks = {}
dronetest.events.send_by_id = function(id,event)
	if dronetest.active_systems[id] ~= nil then
		
		if type(dronetest.events.callbacks[id]) == "table" then
			local sent = false
			for filter,callbacks in pairs(dronetest.events.callbacks[id]) do
				for _i,f in pairs(filter) do
					if event.type ~= nil and event.type == f then
						for _j,callback in ipairs(callbacks) do
							print("CALLCALL")
							callback(event)
						end
						sent = true
					end
				end
			end
			if sent then return true end
		end
		table.insert(dronetest.active_systems[id].events,table.copy(event))
	else
		return false
	end
	return true
end

dronetest.events.send = function(pos,event)
	local meta = minetest.get_meta(pos)
	local id = meta:get_int("id")
	return send_by_id(id,event)
end

dronetest.events.send_all = function(event)
	local count = 0
	for id,s in pairs(dronetest.active_systems) do
		if send_by_id(id,event) then
			count = count + 1
		end
	end
	return count
end
dronetest.events.wait_for_receive = function(id,filter,channel,msg_id,timeout)
	--print("WAIT FOR DIGILINE #"..id)
	if dronetest.active_systems[id] == nil then
		dronetest.log("BUG: dronetest.events.wait_for_receive on inactive system.")
		return nil
	end
	
	if type(filter) ~= "table" then filter = {} end
	if type(timeout) ~= "number" or timeout <= 0 or timeout > 120 then
		timeout = 4 -- default timeout
	end
	local event = nil
	local result = dronetest.events.receive(id,filter,channel,msg_id)
	if result ~= nil then 
		--print("nowait: "..dump(result))
		return result 
	end
	
	local function callback(event) 
		if (msg_id == nil or (type(e.msg)=="table" and type(e.msg.msg_id) == "string" and e.msg.msg_id ~= msg_id)) then
			print("callback "..msg_id)
			result = event 
		end
		return 
	end
	--print("#$#######################################################################################")
	if type(dronetest.events.callbacks[id]) ~= "table" then dronetest.events.callbacks[id] = {} end
	if type(dronetest.events.callbacks[id][filter]) ~= "table" then dronetest.events.callbacks[id][filter]= {} end
	dronetest.events.callbacks[id][filter][msg_id] = callback
	local s = 0.05
	local time = minetest.get_gametime()
	while result == nil and (minetest.get_gametime() - time) <= timeout do
		print("waiting for event: "..tostring(minetest.get_gametime() - time).." "..msg_id)
		dronetest.sleep(s)
		s = s * 2
		if s > timeout / 10 then s = 0.05 end
	end
	--print("finished waiting: "..dump(result))
	dronetest.events.callbacks[id][filter][msg_id] = nil
	if dronetest.count(dronetest.events.callbacks[id][filter]) <= 0 then dronetest.events.callbacks[id][filter] = nil end
	if dronetest.count(dronetest.events.callbacks[id]) <= 0 then dronetest.events.callbacks[id] = nil end
	return result
end

dronetest.events.receive = function(id,filter,channel,msg_id)
	if dronetest.active_systems[id] == nil or #dronetest.active_systems[id].events == 0 then
		return nil
	end
	if type(filter) ~= "table" then filter = {} end
	if #filter > 0 then
		for i,e in pairs(dronetest.active_systems[id].events) do
			for j,f in pairs(filter) do
				if e.type ~= nil and e.type == f then
					if e.type == "digiline" and channel ~= nil and type(e.channel) == "string" and channel ~= e.channel 
					and (msg_id == nil or (type(e.msg)=="table" and type(e.msg.msg_id) == "string" and e.msg.msg_id ~= msg_id)) then
					else
						table.remove(dronetest.active_systems[id].events,i)
						return e
					end
				end
			end
		end
		return nil
	end
	local event = dronetest.active_systems[id].events[1]
	table.remove(dronetest.active_systems[id].events,1)
	return event
end
