-- FS API
-- A save fs api, jailed to fsdir

local fs = {}

fs.isDir = function(path)
	local p = _makePath(path)
	if p == "" then return false end
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
fs.isFile = function(path)
	local p = _makePath(path)
	if p == "" then return false end
	if lfs.attributes(p,"mode") == "file" then
		return true
	end
	return false
end
	
fs.list = function(path)
	local p = _makePath(path)
	if not fs.isDir(path) then return {} end
	local list = {}
	lfs.chdir(mod_dir.."/"..sys.id)
	for filename in lfs.dir(p) do
		table.insert(list,filename)
	end
	return list
end
fs.makeDir = function(path)
	local p = _makePath(path)
	if p == "" then return false,"illegal path '"..path.."'" end
	return lfs.mkdir(p)
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
