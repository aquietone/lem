-- Persistent Data
local multiRefObjects = {

} -- multiRefObjects
local obj1 = {
	["settings"] = {
		["frequency"] = 1000;
	};
	["condition_events"] = {
		[1] = {
			["name"] = "testevent1";
			["enabled"] = false;
		};
		[2] = {
			["name"] = "testevent2";
			["enabled"] = false;
		};
	};
	["characters"] = {
		["Character1"] = {
			["condition_events"] = {
				["testevent1"] = 1;
			};
			["text_events"] = {
				["testevent2"] = 1;
				["testevent1"] = 1;
			};
		};
	};
	["text_events"] = {
		[1] = {
			["registered"] = true;
			["func"] = nil --[[functions with upvalue not supported]];
			["enabled"] = true;
			["name"] = "testevent1";
			["pattern"] = "#*#say my name#*#";
		};
		[2] = {
			["registered"] = true;
			["func"] = nil --[[functions with upvalue not supported]];
			["enabled"] = true;
			["name"] = "testevent2";
			["pattern"] = "#*#say my class#*#";
		};
	};
}
return obj1
