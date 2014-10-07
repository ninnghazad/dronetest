-- PERI API

local peripheral = {}

function peripheral.wrap(channel)
	local pos = active_systems[sys.id].pos
	-- use a unique message-id so we are able to identify the response to our request easily.
	local msg_id = sys:getUniqueId()
	-- this should be wrapped in sys:sendDigilineMessage
	digiline:receptor_send(pos, digiline.rules.default,channel, {action="GET_CAPABILITIES",msg_id=msg_id})
	
	print("channel: "..channel)
	
	-- wait for answer, this should be in a function, with a timeout!
	local e = nil
	while e == nil do
		coroutine.yield()
		e = sys:receiveDigilineMessage(channel,msg_id)
	end
	
	-- check response
	if type(e.action) ~= "string" or type(e.msg) ~= "table" or type(e.msg_id) ~= "string"
	or e.msg_id ~= msg_id or e.action ~= "CAPABILITIES" then
		--is it bug in this case?
		return nil
	end
	
	
	-- create functions to execute actions the peripheral offered
	local newp = {}
	for name,desc in pairs(e.msg) do
		print("wrap peripheral's method "..name..": "..desc)
		newp[name] = function(a,b,c,d,e)
			local pos = active_systems[sys.id].pos
			local msg_id = sys:getUniqueId() 
			-- send action
			digiline:receptor_send(pos, digiline.rules.default,channel, {action=name,argv={a,b,c,d,e},msg_id = msg_id})
			
			-- receive answer, see above
			local e = nil
			while e == nil do
				coroutine.yield()
				e = sys:receiveDigilineMessage(channel,msg_id)
			end
			return e.msg
		end
		
	end
	
	
	return newp
end

return peripheral
