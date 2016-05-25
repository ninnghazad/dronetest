-- FS API
-- A save fs api, jailed to fsdir
--[[
function _realPath(path)
	local old = lfs.currentdir()
	lfs.chdir(path)
	path = lfs.currentdir()
	lfs.chdir(old)
	return path
end
--]]

local max_disk_space = dronetest.max_disk_space
local baseDir = minetest.get_worldpath().."/"..dronetest.current_id

-- This isn't the best spot for this, but make it so _makePath can see our current ID
-- needs to be before first use of the function!
function _makePath(path)
	p = _canonicalizePath(baseDir.."/"..path)
--	print("_makePath: "..p:sub(1,#baseDir).."\n"..baseDir.."\n"..p)
	if p:sub(1,#baseDir) ~= baseDir then return baseDir end
	return p
end

function _isAbs(path)
	if path:len() == 0 then return false end
	if path:sub(1,1) == "/" then return true end
	return false
end

function _canonicalizePath(path)
	if not _isAbs(path) then path = sys.currentDir.."/"..path end
	r = {}
	for p in path:gmatch("[^/]+") do
		if p:len() < 1 then 
		elseif p == "." then 
		elseif p == ".." and #r > 0 then 
			r[#r] = nil 
		else
			r[#r+1] = p
		end
	end
	return "/"..table.concat(r,"/")
end

function _hidePath(path) 
	path = _canonicalizePath(path)
	base = _canonicalizePath(baseDir)
--	print("_hidePath: base="..base.." path="..path)
	path = string.gsub(path,base,"/")
	path = string.gsub(path,"//","/")
	return path
end

local fs = {}
fs.getAbsolutePath = function(path)
	return _hidePath(path)
end

fs.isDir = function(path)
	local p = _makePath(path)
	if p == "" then return false end
	if lfs.attributes(p,"mode") ~= nil then
		print(path.." "..p.." "..lfs.attributes(p,"mode"))
	end
	if lfs.attributes(p,"mode") == "directory" then
		return true
	end
	return false
end

fs.exists = function(path)
	local p = _makePath(path)
	if p == "" then return false end
	local mode = lfs.attributes(p,"mode")
	if mode == "file" or mode == "directory" then
		return true
	end
	return false
end

fs.chDir = function(path)
	local p = _makePath(path)
	if p == "" then return false end
	if fs.isDir(p) then
		sys.currentDir = p
		return true
	end
	return false
end

fs.currentDir = function()
	return _hidePath(sys.currentDir)
end

fs.isFile = function(path)
	local p = _makePath(path)
	if p == "" then return false end
--	if lfs.attributes(p,"mode") ~= nil then
--	print(path.." "..lfs.attributes(p,"mode"))
--	end
	if lfs.attributes(p,"mode") == "file" then
		return true
	end
	return false
end

fs.size = function(path)
	local p = _makePath(path)
	if p == "" then return false end
	return lfs.attributes(p,"size")
end

fs.readFile = function(path)
	local p = _makePath(path)
	if p == "" then return false end
	if lfs.attributes(p,"mode") ~= "file" then
		return false
	end
	local f = io.open(p,"rb")
	local data = f:read("*all")
	f:close()
	return data
end

fs.writeFile = function(path,string)
	local p = _makePath(path)
	if p == "" then return false end
	if lfs.attributes(p,"mode") == "directory" then
		return false
	end
	local f = io.open(p,"w+b")
	local r,err f:write(string)
	if r == nil then
		print(err)
	end
	f:close()
	return true
end
fs.touch = function(path)
	local p = _makePath(path)
	if p == "" then return false end
	return lfs.touch(p)
end
	
fs.list = function(path)
	if path == nil then path = "./" end
	local p = _makePath(path)
	if not fs.isDir(path) then return {} end
	--print("LS: "..p.." || "..path)
	local list = {}
	for filename in lfs.dir(p) do
		if p ~= baseDir or filename ~= ".." then
			table.insert(list,filename)
		end
	end
	return list
end

fs.makeDir = function(path)
	print("fs.makeDir: arg="..path.." canon=".._canonicalizePath(path))
	local p = _makePath(path)
	path = _hidePath(_canonicalizePath(path))
	if p == "" then return false,"illegal path '"..path.."'" end
	local r,err = lfs.mkdir(p)
	if not r then print(dronetest.current_id.." Could not create directory '"..path.."': "..err) return false,err end
	return fs.isDir(p)
end

--[[
# fs.list
# fs.exists
# fs.isDir
fs.isReadOnly
fs.getName
fs.getDrive
fs.getSize
fs.getFreeSpace
# fs.makeDir
fs.move 2
fs.copy 2
fs.delete
fs.combine 2
fs.open
fs.find
fs.getDir
--]]
return fs
