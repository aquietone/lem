-- Persistent Data
local multiRefObjects = {

} -- multiRefObjects
local obj1 = {
	["categories"] = {
		[1] = "NoS";
		[2] = "ToL";
		[3] = "CoV";
		[4] = "ToV";
		[5] = "TBL";
		[6] = "RoS";
		[7] = "EoK";
	};
	["condition_events"] = {
		["testevent1"] = {
			["name"] = "testevent1";
			["load"] = {
				["always"] = false;
				["zone"] = "";
				["class"] = "";
				["characters"] = "";
			};
		};
		["sheiroot"] = {
			["name"] = "sheiroot";
			["category"] = "ToL";
			["load"] = {
				["always"] = false;
				["zone"] = "";
				["class"] = "";
				["characters"] = "";
			};
		};
		["testevent2"] = {
			["name"] = "testevent2";
			["load"] = {
				["always"] = false;
				["zone"] = "";
				["class"] = "";
				["characters"] = "";
			};
		};
	};
	["text_events"] = {
		["testevent2"] = {
			["name"] = "testevent2";
			["pattern"] = "#*#say my class#*#";
			["load"] = {
				["always"] = false;
				["zone"] = "";
				["class"] = "";
				["characters"] = "";
			};
		};
		["atensilence"] = {
			["category"] = "ToL";
			["name"] = "atensilence";
			["pattern"] = "#*#Aten Ha Ra points at #1# with one arm#*#";
			["load"] = {
				["always"] = false;
				["zone"] = "";
				["class"] = "";
				["characters"] = "";
			};
		};
		["testevent1"] = {
			["name"] = "testevent1";
			["pattern"] = "#*#say my name#*#";
			["load"] = {
				["always"] = false;
				["zone"] = "";
				["class"] = "";
				["characters"] = "";
			};
		};
	};
	["settings"] = {
		["frequency"] = 250;
	};
}
return obj1
