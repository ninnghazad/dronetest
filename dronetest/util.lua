
-- convert a path into a table, ignoring ..
local function parse_filename(filename)
	local path = {}
	for s in filename:gmatch("[^/]*") do
		if s == ".." then
			if #path == 0 then
				return nil
			end
			table.remove(path)
		elseif s ~= "." then
			table.insert(path, s)
		end
	end
	return path
end

function is_filename_in_sandbox(filename, sandbox)
	if not sandbox then
		--dronetest.log("is_filename_in_sandbox("..dump(filename)..", "..dump(sandbox)..") == true")
		return true
	end
	local path, base= parse_filename(filename), parse_filename(sandbox)
	if not path or not base then
		--dronetest.log("is_filename_in_sandbox("..dump(filename)..", "..dump(sandbox)..") == false")
		return false
	end
	for i,v in ipairs(base) do
		if path[i] ~= v then
			--dronetest.log("is_filename_in_sandbox("..dump(filename)..", "..dump(sandbox)..") == false")
			return false
		end
	end
	--dronetest.log("is_filename_in_sandbox("..dump(filename)..", "..dump(sandbox)..") == true")
	return true
end
function readFile(file, sandbox)
	if not is_filename_in_sandbox(file, sandbox) then
		dronetest.log("readFile: "..dump(file).." is not a legal filename.")
		return
	end
	local f = io.open(file, "rb")
	if not f then
		dronetest.log("readFile: failed to open "..dump(file))
		return
	end
	local content = f:read("*all")
	f:close()
	return content
end

function writeFile(file,str)
	if not is_filename_in_sandbox(file, sandbox) then
		dronetest.log("writeFile: "..dump(file).." is not a legal filename.")
		return
	end
	local f,err = io.open(file,"wb") 
	if not f then minetest.log("error",err) return false end
	f:write(string)
	f:close()
	return true
end

function mkdir(dir)
	os.execute("mkdir -p '"..dir.."'")
end


function count(t)
	local n = 0
	for k,v in pairs(t) do
		n = n + 1
	end
	return n
end
dronetest.count = count

local function sandbox(x, env)
	if type(x) == "table" then
		for k,v in pairs(x) do
			x[k] = sandbox(v, env)
		end
	elseif type(x) == "function" then
		return setfenv(function(...) return x(...) end, env)
	else
		return x
	end
end
function table.copy(t, deep, safeenv, seen)
    seen = seen or {}
    if t == nil then return nil end
    if seen[t] then return seen[t] end

    local nt = {}
    for k, v in pairs(t) do
        if deep and type(v) == 'table' then
            nt[k] = table.copy(v, deep, safeenv, seen)
        elseif safeenv and type(v) == 'function' then
        	nt[k] = setfenv(function(...) return v(...) end, safeenv)
        else
            nt[k] = v
        end
    end
    setmetatable(nt, table.copy(getmetatable(t), deep, safeenv, seen))
    seen[t] = nt
    return nt
end
function string:split(sep) 
        if sep == nil then
                sep = "%s"
        end
        local t={} ; i=1
        for str in string.gmatch(self, "([^"..sep.."]+)") do
                t[i] = str
                i = i + 1
        end
        return t
end
function math.round(x)
	return math.floor(x+0.5)
end
round = math.round


function sleep(seconds)
	local start = minetest.get_gametime()
	while minetest.get_gametime() - start < seconds do
		coroutine.yield()
	end
end
dronetest.sleep = sleep