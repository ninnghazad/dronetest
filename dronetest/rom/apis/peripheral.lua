-- PERI API

local peripheral = {}

function peripheral.wrap(channel)
	local pos = active_systems[sys.id].pos
	-- use a unique message-id so we are able to identify the response to our request easily.
	local msg_id = sys:getUniqueId()
	-- this should be wrapped in sys:sendDigilineMessage
	digiline:receptor_send(pos, digiline.rules.default,channel, {action="GET_CAPABILITIES",msg_id=msg_id})
	
	print("COMPUTER "..sys.id.." waiting for CAPABILITIES on channel: "..channel)
	
	-- wait for answer, this should be in a sys:function, with a timeout!
	local e = nil
	while e == nil do
		sleep(0.05)
		e = sys:receiveDigilineMessage(channel,msg_id)
	end
	print("COMPUTER "..sys.id.." received CAPABILITIES on channel: "..channel)
	-- check response
	--[[
	if type(e.action) ~= "string" or type(e.msg) ~= "table" or type(e.msg_id) ~= "string"
	or e.msg_id ~= msg_id or e.action ~= "CAPABILITIES" then
		--is it bug in this case?
		return nil
	end
	--]]
	
	-- create functions to execute actions the peripheral offered
	local newp = {}
	for name,desc in pairs(e.msg) do
		print("wrap peripheral's method "..name..": "..desc)
		newp[name] = function(a,b,c,d,e)
			local pos = active_systems[sys.id].pos
			local msg_id = sys:getUniqueId() 
			
			
			print("COMPUTER calling peripheral on channel "..channel.." to execute "..name)
			
			-- send action -- we attach a print() function, so the peripheral, when called from a computer, can print to its screen
			digiline:receptor_send(pos, digiline.rules.default,channel, {action=name,argv={a,b,c,d,e},msg_id=msg_id,print=function(msg) print(msg) end})
			print("COMPUTER waiting for peripheral to answer")
			-- receive answer, see above
			local e = nil
			while e == nil do
				sleep(0.05)
				e = sys:receiveDigilineMessage(channel,msg_id)
			end
			print("COMPUTER peripheral answered")
			
			return e.msg
		end
		
	end
	
	
	return newp
end

return peripheral
