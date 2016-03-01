dronetest.events = {}
dronetest.events.callbacks = {}
dronetest.events.listeners = {}
dronetest.events.send_by_id = function(id,event)
	if dronetest.active_systems[id] ~= nil then
		if type(dronetest.events.callbacks[id]) == "table" then
			local sent = false
			for filter,callbacks in pairs(dronetest.events.callbacks[id]) do
				for _i,f in pairs(filter) do
					if event.type ~= nil and event.type == f then
						if type(event.msg) ~= table and callbacks[0] ~= nil then
							callbacks[0](event)
							sent = true
						elseif event.msg.msg_id ~= nil and callbacks[event.msg.msg_id] ~= nil then
							callbacks[event.msg.msg_id](event)
							callbacks[event.msg.msg_id] = nil
							sent = true
						elseif callbacks[0] ~= nil then
							callbacks[0](event)
							sent = true
						end
						
					
					end
				end
			end
			if sent then return true end
		end
		if type(dronetest.events.listeners[id]) == "table" then
			local sent = false
			for filter,listeners in pairs(dronetest.events.listeners[id]) do
				for _i,f in pairs(filter) do
					if event.type ~= nil and event.type == f then
						for _j,listener in pairs(listeners) do
							listener(event)
							sent = true
						end
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

dronetest.events.register_listener = function(id,filter,func)
	if type(dronetest.events.listeners[id]) ~= "table" then dronetest.events.listeners[id] = {} end
	if type(dronetest.events.listeners[id][filter]) ~= "table" then dronetest.events.listeners[id][filter] = {} end
	table.insert(dronetest.events.listeners[id][filter],func)
	return #dronetest.events.listeners[id][filter]
end
dronetest.events.unregister_listener = function(id,filter,listener)
	dronetest.events.listeners[id][filter][listener] = nil
end

dronetest.events.unregister_listeners = function(id)
	dronetest.events.listeners[id] = nil
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
	timeout = timeout or 4
	msg_id = msg_id or 0
	
	--print("WAIT FOR DIGILINE #"..id)
	--print("waiting, events left: "..dronetest.count(dronetest.active_systems[id].events))
	if dronetest.active_systems[id] == nil then
		dronetest.log("BUG: dronetest.events.wait_for_receive on inactive system.")
		return nil
	end
	
	if type(filter) ~= "table" then filter = {} end
	if type(timeout) ~= "number" or timeout < 0 or timeout > 120 then
		timeout = 4 -- default timeout
	end
	local event = nil
	local result = dronetest.events.receive(id,filter,channel,msg_id)
	if result ~= nil then 
		--print("nowait: "..dump(result))
		return result 
	end
	
	local function callback(event) 
		print("callback, events left: "..dronetest.count(dronetest.active_systems[id].events))
	
	--	print("callback 0: "..msg_id)
		if (msg_id == nil or (type(event.msg)=="table" and type(event.msg.msg_id) ~= "string" and event.msg.msg_id == msg_id)) then
	--		print("callback "..msg_id)
			result = event 
		end
	--	result = event
		return event
	end
	--print("#$#######################################################################################")
	if type(dronetest.events.callbacks[id]) ~= "table" then dronetest.events.callbacks[id] = {} end
	if type(dronetest.events.callbacks[id][filter]) ~= "table" then dronetest.events.callbacks[id][filter]= {} end
	dronetest.events.callbacks[id][filter][msg_id] = callback
	local s = 0.05
	local time = minetest.get_gametime()
	while result == nil and ((minetest.get_gametime() - time) <= timeout or timeout == 0) do
		
		dronetest.sleep(0.01)
		--print("waiting for event: "..tostring(minetest.get_gametime() - time).." "..msg_id)
	--	s = s * 2
	--	if s > timeout / 10 then s = 0.05 end
	end
	
	dronetest.events.callbacks[id][filter][msg_id] = nil
	
--	if dronetest.count(dronetest.events.callbacks[id][filter]) <= 0 then dronetest.events.callbacks[id][filter] = {} end
--	if dronetest.count(dronetest.events.callbacks[id]) <= 0 then dronetest.events.callbacks[id] = {} end
	print("finished waiting, events left: "..dronetest.count(dronetest.active_systems[id].events))
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
					--if e.type == "digiline" and channel ~= nil and type(e.channel) == "string" and channel ~= e.channel 
					if channel ~= nil and type(e.channel) == "string" and channel ~= e.channel 
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
