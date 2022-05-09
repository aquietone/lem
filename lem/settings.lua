-- Persistent Data
local multiRefObjects = {

} -- multiRefObjects
local obj1 = {
	["condition_events"] = {
		["testevent2"] = {
			["name"] = "testevent2";
		};
		["testevent1"] = {
			["name"] = "testevent1";
		};
		["sheiroot"] = {
			["name"] = "sheiroot";
		};
	};
	["text_events"] = {
		["testevent2"] = {
			["name"] = "testevent2";
			["pattern"] = "#*#say my class#*#";
		};
		["atensilence"] = {
			["name"] = "atensilence";
			["pattern"] = "#*#Aten Ha Ra points at #1# with one arm#*#";
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
