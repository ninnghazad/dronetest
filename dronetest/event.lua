dronetest.events = {}
dronetest.events.send_by_id = function(id,event)
	if dronetest.active_systems[id] ~= nil then
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

dronetest.events.receive = function(id,filter,channel,msg_id)
	if dronetest.active_systems[id] == nil or #dronetest.active_systems[id].events == 0 then
		return nil
	end
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
