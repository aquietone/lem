-- Persistent Data
local multiRefObjects = {

} -- multiRefObjects
local obj1 = {
	["categories"] = {
		[1] = "ToL";
		[2] = "CoV";
		[3] = "ToV";
		[4] = "TBL";
		[5] = "RoS";
		[6] = "EoK";
	};
	["condition_events"] = {
		["testevent1"] = {
			["name"] = "testevent1";
		};
		["sheiroot"] = {
			["name"] = "sheiroot";
			["category"] = "ToL";
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
		["atensilence"] = {
			["category"] = "ToL";
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
