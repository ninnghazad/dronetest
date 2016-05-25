
dronetest.events = {}
dronetest.events.callbacks = {}
dronetest.events.listeners = {}
dronetest.events.send_by_id = function(id,event)
	if dronetest.active_systems[id] ~= nil then
		----print("send event for #"..id.." "..dump(event))
		if event.msg_id == nil then
			event.msg_id = 0
		end

		if type(event.msg) ~= table then
			--print("send event for #"..id.." "..dump(event))
--			local tmp = event.msg
--			event.msg = {}
--			event.msg.msg_id = 0
--			event.msg.msg = tmp
		end
		if event.channel == "rtc" then
			--print("NNNNNNNNNYYYYYYYYAAAAAAAAANNNNNNNN")
			--print(dump(dronetest.events.callbacks[id]))
			--print(dump(dronetest.events.listeners[id]))
		end
		if type(dronetest.events.callbacks[id]) == "table" then
			local sent = false
			for _j,callback in pairs(dronetest.events.callbacks[id]) do
				for _i,f in pairs(callback.filter) do
					if event.type ~= nil and event.type == f then
						--print("call callback")
						if type(event.msg) ~= table and callback.func ~= nil then --and callback.msg_id ~= event.msg.msg_id then
							sent = callback.func(event)

						elseif event.msg_id ~= nil and callback.msg_id == event.msg_id then
							sent = callback.func(event)
						else
							sent = callback.func(event)
						end
						if sent == nil or sent then 
							dronetest.events.callbacks[id][_i] = nil
							return true 
						end
						
					
					end
				end
			end
		end
		
		if type(dronetest.events.listeners[id]) == "table" then
			local sent = false
			for _f,listener in pairs(dronetest.events.listeners[id]) do
				for _i,f in pairs(listener.filter) do
					if event.type ~= nil and event.type == f then
						sent = listener.func(event)
						if sent == nil or sent then return true end
					end
				end
			end
		end
		--print("keep event around, now "..#dronetest.active_systems[id].events.." events")
		table.insert(dronetest.active_systems[id].events,table.copy(event))
	else
		return false
	end
	return true
end

dronetest.events.register_listener = function(id,filter,func,channel)
	if channel == nil then
		channel = minetest.get_meta(dronetest.active_systems[id].pos):get_string("channel")
	end
	local f = function(event) 
		if event.channel ~= channel then
			return false
		end
		return func(event)
	end
	local listener = {filter=filter,func = f}
	--print(id.." listens on channel "..channel.." for filter "..dump(filter))
	if type(dronetest.events.listeners[id]) ~= "table" then 
		dronetest.events.listeners[id] = {}
	end
	--if type(dronetest.events.listeners[id][filter]) ~= "table" then dronetest.events.listeners[id][filter] = {} end
	table.insert(dronetest.events.listeners[id],listener)
	return #dronetest.events.listeners[id]
end
dronetest.events.unregister_listener = function(id,listenerId)
	if dronetest.events.listeners[id] ~= nil then
		dronetest.events.listeners[id][listenerId] = nil
		--print("removed listener "..id.." "..listenerId)
	end
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
	
--	--print("WAIT FOR DIGILINE #"..id.." f: "..dump(filter).." c: "..dump(channel).." mid: "..dump(msg_id).." t: "..timeout)
--	if channel == "011" then
--		--print(dump(dronetest.active_systems[id].events))
--	end
	----print("waiting, events left: "..dronetest.count(dronetest.active_systems[id].events))
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
		--print("no need to wait,instant receive: "..dump(result))
		return result 
	end
	
	local function callback(event) 
		--print("callback, events left: "..dronetest.count(dronetest.active_systems[id].events))
		if channel ~= nil and event.channel ~= channel then
			return false
		end
	--	--print("callback 0: "..msg_id)
	--	if (msg_id == nil or (type(event.msg)=="table" and type(event.msg.msg_id) ~= "string" and event.msg.msg_id == msg_id)) then
	--		--print("callback "..msg_id)
			result = event 
	--	end
	--	result = event
		return true
	end
	----print("#$#######################################################################################")
	if type(dronetest.events.callbacks[id]) ~= "table" then dronetest.events.callbacks[id] = {} end
	--if type(dronetest.events.callbacks[id][msg_id]) ~= "table" then dronetest.events.callbacks[id][msg_id]= {} end
	
	table.insert(dronetest.events.callbacks[id],{filter=filter,func=callback,msg_id=msg_id,channel=channel})
	--print("inserted callback")
	local callbackId = #dronetest.events.callbacks[id]
	local s = 0.05
	local time = minetest.get_gametime()
	while result == nil and ((minetest.get_gametime() - time) <= timeout or timeout == 0) do
		
		dronetest.sleep(0.01)
		----print("waiting for event: "..tostring(minetest.get_gametime() - time).." "..msg_id)
	--	s = s * 2
	--	if s > timeout / 10 then s = 0.05 end
	end
	
	dronetest.events.callbacks[id][callbackId] = nil
	
--	if dronetest.count(dronetest.events.callbacks[id][filter]) <= 0 then dronetest.events.callbacks[id][filter] = {} end
--	if dronetest.count(dronetest.events.callbacks[id]) <= 0 then dronetest.events.callbacks[id] = {} end
	--print("finished "..dump(id).." waiting, events left: "..dronetest.count(dronetest.active_systems[id].events))
	return result
end

dronetest.events.receive = function(id,filter,channel,msg_id)
	if dronetest.active_systems[id] == nil or dronetest.count(dronetest.active_systems[id].events) == 0 then
		return nil
	end
	--print("receive: "..id.." "..dump(channel).." "..dump(msg_id).." "..dump(filter).." "..dump(dronetest.active_systems[id].events))
	if type(filter) ~= "table" then filter = {} end
	if #filter > 0 then
		for i,e in pairs(dronetest.active_systems[id].events) do
			for j,f in pairs(filter) do
	
				if e.type ~= nil and e.type == f then
					--print("check: "..e.type)
					--print(type(e.msg_id).." "..type(msg_id))
					--print(type(e.channel).." "..type(channel))
					--if e.type == "digiline" and channel ~= nil and type(e.channel) == "string" and channel ~= e.channel 
					if (channel ~= nil and type(e.channel) == "string" and channel ~= e.channel)
					or (type(e)=="table" and type(e.msg_id) == "string" and e.msg_id ~= msg_id) then
						--print("nope, filtered out")
					else
						local event = table.copy(e)
						table.remove(dronetest.active_systems[id].events,i)
						--print("receive will return event "..dump(event))
						return event
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
