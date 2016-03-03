-- FS API
-- A save fs api, jailed to fsdir

function _realPath(path)
	local old = lfs.currentdir()
	lfs.chdir(path)
	path = lfs.currentdir()
	lfs.chdir(old)
	return path
end

local max_disk_space = dronetest.max_disk_space
local base_path = _realPath(mod_dir.."/"..sys.id)
-- This isn't the best spot for this, but make it so _makePath can see our current ID
-- needs to be before first use of the function!
function _makePath(path)
	p = _realPath(base_path.."/"..path)
	print(p:sub(1,#base_path).."\n"..base_path.."\n"..p)
	if p:sub(1,#base_path) ~= base_path then return base_path end
	return p
end

function _hidePath(path) 
	path = _realPath(path)
	base = _realPath(base_path)
	path = string.gsub(path,base,"/")
	path = path:gsub("//","/")
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
	return lfs.chdir(p)
end

fs.currentDir = function()
	
	return _hidePath(lfs.currentdir())
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
	io.input(p)
	return io.read("*all")
end

fs.writeFile = function(path,string)
	local p = _makePath(path)
	if p == "" then return false end
	if lfs.attributes(p,"mode") == "directory" then
		return false
	end
	io.output(p)
	return io.write(string)
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
	local old = lfs.currentdir()
	lfs.chdir(base_path)
	for filename in lfs.dir(p) do
		if p ~= base_path or filename ~= ".." then
			table.insert(list,filename)
		end
	end
	lfs.chdir(old)
	return list
end

fs.makeDir = function(path)
	local p = _makePath(path)
	if p == "" then return false,"illegal path '"..path.."'" end
	local r,err = lfs.mkdir(p)
	if not r then print(sys.id.." Could not create directory '"..path.."': "..err) return false,err end
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
