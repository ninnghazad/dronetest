-- TERM API
-- APIs have minetest and so on available in scope

local term = {}
term.cursorPos = {1,1}
function term.clear()
	dronetest.console_histories[sys.id] = ""
end

function term.write(msg)
	dronetest.print(sys.id,msg,true)
	return string.len(msg)
end

term.keyNames = {
      "Left Button",
      "Right Button",
      "Cancel",
      "Middle Button",
      "X Button 1",
      "X Button 2",
      "-",
      "Back",
      "Tab",
      "-",
      "-",
      "Clear",
      "Return",
      "-",
      "-",
      "Shift",
      "Control",
      "Menu",
      "Pause",
      "Capital",
      "Kana",
      "-",      
      "Junja",
      "Final",
      "Kanji",
      "-",
      "Escape",
      "Convert",
      "Nonconvert",
      "Accept",
      "Mode Change",
      "Space",
      "Priot",
      "Next",
      "End",
      "Home",
      "Left",
      "Up",
      "Right",
      "Down",
      "Select",
      "Print",
      "Execute",
      "Snapshot",
      "Insert",
      "Delete",
      "Help",
      "0",
      "1",
      "2",
      "3",
      "4",
      "5",
      "6",
      "7",
      "8",
      "9",
      "-",
      "-",
      "-",
      "-",
      "-",
      "-",
      "-",
      "A",
      "B",
      "C",
      "D",
      "E",
      "F",
      "G",
      "H",
      "I",
      "J",
      "K",
      "L",
      "M",
      "N",
      "O",
      "P",
      "Q",
      "R",
      "S",
      "T",
      "U",
      "V",
      "W",
      "X",
      "Y",
      "Z",
      "Left Windows",
      "Right Windows",
      "Apps",
      "-",
      "Sleep",
      "Numpad 0",
      "Numpad 1",
      "Numpad 2",
      "Numpad 3",
      "Numpad 4",
      "Numpad 5",
      "Numpad 6",
      "Numpad 7",
      "Numpad 8",
      "Numpad 9",
      "Numpad *",
      "Numpad +",
      "Numpad /",
      "Numpad -",
      "Numpad .",
      "Numpad /",
      "F1",
      "F2",
      "F3",
      "F4",
      "F5",
      "F6",
      "F7",
      "F8",
      "F9",
      "F10",
      "F11",
      "F12",
      "F13",
      "F14",
      "F15",
      "F16",
      "F17",
      "F18",
      "F19",
      "F20",
      "F21",
      "F22",
      "F23",
      "F24",
      "-",
      "-",
      "-",
      "-",
      "-",
      "-",
      "-",
      "-",
      "Num Lock",
      "Scroll Lock",
      "-",
      "-",
      "-",
      "-",
      "-",
      "-",
      "-",
      "-",
      "-",
      "-",
      "-",
      "-",
      "-",
      "-",
      "Left Shift",
      "Right Shift",
      "Left Control",
      "Right Control",
      "Left Menu",
      "Right Menu",
      "-",
      "-",
      "-",
      "-",
      "-",
      "-",
      "-",
      "-",
      "-",
      "-",
      "-",
      "-",
      "-",
      "-",
      "-",
      "-",
      "-",
      "-",
      "-",
      "-",
      "-",
      "Plus",
      "Comma",
      "Minus",
      "Period",
      "-",
      "-",
      "-",
      "-",
      "-",
      "-",
      "-",
      "-",
      "-",
      "-",
      "-",
      "-",
      "-",
      "-",
      "-",
      "-",
      "-",
      "-",
      "-",
      "-",
      "-",
      "-",
      "-",
      "-",
      "-",
      "-",
      "-",
      "-",
      "-",
      "-",
      "-",
      "-",
      "-",
      "-",
      "-",
      "-",
      "-",
      "-",
      "-",
      "-",
      "-",
      "-",
      "-",
      "-",
      "-",
      "-",
      "-",
      "-",
      "-",
      "-",
      "-",
      "-",
      "-",
      "-",
      "-",
      "Attn",
      "CrSel",
      "ExSel",
      "Erase OEF",
      "Play",
      "Zoom",
      "PA1",
      "OEM Clear",
      "-"
}
term.keyChars = {
	["13:0:0"] = "\n",
	["13:0:1"] = "\n",
	
	["32:0:0"] = " ",
	["32:0:1"] = " ",
	
	["8:0:0"] = "\b",
	["8:0:1"] = "\b",
	
	["49:0:0"] = "1",
	["50:0:0"] = "2",
	["51:0:0"] = "3",
	["52:0:0"] = "4",
	["53:0:0"] = "5",
	["54:0:0"] = "6",
	["55:0:0"] = "7",
	["56:0:0"] = "8",
	["57:0:0"] = "9",
	["58:0:0"] = "0",
	
	["65:0:0"] = "a",
	["66:0:0"] = "b",
	["67:0:0"] = "c",
	["68:0:0"] = "d",
	["69:0:0"] = "e",
	["70:0:0"] = "f",
	["71:0:0"] = "g",
	["72:0:0"] = "h",
	["73:0:0"] = "i",
	["74:0:0"] = "j",
	["75:0:0"] = "k",
	["76:0:0"] = "l",
	["77:0:0"] = "m",
	["78:0:0"] = "n",
	["79:0:0"] = "o",
	["80:0:0"] = "p",
	["81:0:0"] = "q",
	["82:0:0"] = "r",
	["83:0:0"] = "s",
	["84:0:0"] = "t",
	["85:0:0"] = "u",
	["86:0:0"] = "v",
	["87:0:0"] = "w",
	["88:0:0"] = "x",
	["89:0:0"] = "y",
	["90:0:0"] = "z",
	
	["65:0:1"] = "A",
	["66:0:1"] = "B",
	["67:0:1"] = "C",
	["68:0:1"] = "D",
	["69:0:1"] = "E",
	["70:0:1"] = "F",
	["71:0:1"] = "G",
	["72:0:1"] = "H",
	["73:0:1"] = "I",
	["74:0:1"] = "J",
	["75:0:1"] = "K",
	["76:0:1"] = "L",
	["77:0:1"] = "M",
	["78:0:1"] = "N",
	["79:0:1"] = "O",
	["80:0:1"] = "P",
	["81:0:1"] = "Q",
	["82:0:1"] = "R",
	["83:0:1"] = "S",
	["84:0:1"] = "T",
	["85:0:1"] = "U",
	["86:0:1"] = "V",
	["87:0:1"] = "W",
	["88:0:1"] = "X",
	["89:0:1"] = "Y",
	["90:0:1"] = "Z",
	
	["191:0:0"] = "/",
	
}
function term.getChar()
	
	local e = dronetest.events.wait_for_receive(sys.id,{"key"},minetest.get_meta(dronetest.active_systems[sys.id].pos):get_string("channel"),0,0)
--	print("ASD: "..string.sub(e.msg.msg,1,string.find(e.msg.msg,":")-1))
	if term.keyChars[e.msg.msg] then
--		print("Char: " .. term.keyChars[e.msg.msg])
		return term.keyChars[e.msg.msg]
	end
--	print("Key: "..term.keyNames[tonumber(string.sub(e.msg.msg,1,string.find(e.msg.msg,":")-1))])
	return ""
	--return string.char(tonumber(string.sub(e.msg.msg,1,string.find(e.msg.msg,":")-1)))
end

return term
