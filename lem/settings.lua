-- Persistent Data
local multiRefObjects = {

} -- multiRefObjects
local obj1 = {
	["settings"] = {
		["frequency"] = 250;
	};
	["condition_events"] = {
		[2] = {
			["name"] = "testevent2";
		};
		[1] = {
			["name"] = "testevent1";
		};
	};
	["characters"] = {
		["Character1"] = {
			["condition_events"] = {
			};
			["text_events"] = {
				["testevent2"] = 1;
				["testevent1"] = 1;
			};
		};
	};
	["text_events"] = {
		[2] = {
			["name"] = "testevent2";
			["pattern"] = "#*#say my class#*#";
		};
		[1] = {
			["name"] = "testevent1";
			["pattern"] = "#*#say my name#*#";
		};
	};
}
return obj1
