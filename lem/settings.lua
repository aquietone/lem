-- Persistent Data
local multiRefObjects = {

} -- multiRefObjects
local obj1 = {
	["condition_events"] = {
		["testevent1"] = {
			["name"] = "testevent1";
		};
		["testevent2"] = {
			["name"] = "testevent2";
		};
	};
	["text_events"] = {
		["testevent2"] = {
			["name"] = "testevent2";
			["pattern"] = "#*#say my class#*#";
		};
		["testevent1"] = {
			["name"] = "testevent1";
			["pattern"] = "#*#say my name#*#";
		};
	};
	["settings"] = {
		["frequency"] = 250;
	};
}
return obj1
