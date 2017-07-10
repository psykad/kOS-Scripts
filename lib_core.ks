@LAZYGLOBAL OFF.

// Locks
LOCK surfaceRetrograde TO R(0,0,0) * V(0-VELOCITY:SURFACE:X, 0-VELOCITY:SURFACE:Y, 0-VELOCITY:SURFACE:Z).

// Ship profiles
GLOBAL profileAsc IS "Ascending".
GLOBAL profileDesc IS "Descending".
GLOBAL profileOrb IS "Orbiting".

FUNCTION GetProfile {
	IF STATUS = "PRELAUNCH" OR STATUS = "LANDED" OR STATUS = "SPLASHED" {
		RETURN "N/A".
	}
	
	IF APOAPSIS > 0 and PERIAPSIS > 0 {
		RETURN profileOrb.
	}
	
	IF ETA:APOAPSIS < ETA:PERIAPSIS {
		RETURN profileAsc.
	} ELSE {
		RETURN profileDesc.
	}	
}

FUNCTION GetTrueAltitude {
	LOCAL terrainHeight IS SHIP:GEOPOSITION:TERRAINHEIGHT.
	
	IF ALT:RADAR = ALTITUDE {
		RETURN ALTITUDE.
	} ELSE {
		IF terrainHeight <= 0 {
			SET terrainHeight TO 0.
		}
		
		RETURN ALTITUDE - terrainHeight.
	}
}

FUNCTION DrawLabelList { PARAMETER labelList, xPos, yPos.
	FOR label IN labelList {
		PRINT label AT (xPos, yPos).
		SET yPos TO yPos + 1.
	}
}

FUNCTION DrawDataList { PARAMETER dataList, xPos, yPos.
	LOCAL spaces IS "                              ".
	
	FOR data in dataList {
		PRINT data + spaces AT (xPos, yPos).
		SET yPos TO yPos + 1.
	}
}

FUNCTION GetCommStatus {	
	IF ADDONS:RT:HASKSCCONNECTION(SHIP) = TRUE {
		RETURN "Connected".
	} ELSE {
		RETURN "Not connection".
	}
}

FUNCTION GetCommDelay {
	IF ADDONS:RT:HASKSCCONNECTION(SHIP) {
		RETURN ROUND(ADDONS:RT:KSCDELAY(SHIP), 2).
	} ELSE {
		RETURN "Not connected".
	}
}

FUNCTION GetDeltaV {
	LOCAL totalIsp IS 0.
	LOCAL gravity IS 0.
	LIST ENGINES IN engineList.
	
	FOR engine in engineList {
		SET totalIsp TO totalIsp + ENGINE:ISP.
	}
	
	LOCAL Ve IS totalIsp * gravity.
}