-- Persistent Data
local multiRefObjects = {

} -- multiRefObjects
local obj1 = {
	["text_events"] = {
		[1] = {
			["enabled"] = true;
			["name"] = "testevent1";
			["pattern"] = "#*#say my name#*#";
		};
		[2] = {
			["enabled"] = true;
			["name"] = "testevent2";
			["pattern"] = "#*#say my class#*#";
		};
	};
	["condition_events"] = {
		[2] = {
			["name"] = "testevent2";
			["enabled"] = false;
		};
		[1] = {
			["enabled"] = false;
			["name"] = "testevent1";
		};
	};
	["characters"] = {
		["Character1"] = {
			["text_events"] = {
				["testevent1"] = 1;
				["testevent2"] = 1;
			};
			["condition_events"] = {
			};
		};
	};
	["settings"] = {
		["frequency"] = 250;
	};
}
return obj1
