@LAZYGLOBAL OFF.

local offset is 0.001.
local aDraw is vecdraw().
local bDraw is vecdraw().
local nDraw is vecdraw().
local sDraw is vecdraw().
local eDraw is vecdraw().
local wDraw is vecdraw().
LOCK surfacePrograde TO R(0,0,0) * V(0-VELOCITY:SURFACE:X, 0-VELOCITY:SURFACE:Y, 0-VELOCITY:SURFACE:Z).

clearscreen.
UNTIL FALSE {
	local cPos is ship:geoposition.	
	local nPos is latlng(cPos:lat+offset, cPos:lng).
	local sPos is latlng(cPos:lat-offset, cPos:lng).
	local ePos is latlng(cPos:lat, cPos:lng+offset).
	local wPos is latlng(cPos:lat, cPos:lng-offset).

	// set nDraw to vecdrawargs(nPos:altitudeposition(nPos:terrainheight+100),
		// nPos:position - nPos:altitudeposition(nPos:terrainheight+100),
		// red,"",1,true
	// ).
	// set sDraw to vecdrawargs(sPos:altitudeposition(sPos:terrainheight+100),
		// sPos:position - sPos:altitudeposition(sPos:terrainheight+100),
		// red,"",1,true
	// ).
	// set eDraw to vecdrawargs(ePos:altitudeposition(ePos:terrainheight+100),
		// ePos:position - ePos:altitudeposition(ePos:terrainheight+100),
		// red,"",1,true
	// ).
	// set wDraw to vecdrawargs(wPos:altitudeposition(wPos:terrainheight+100),
		// wPos:position - wPos:altitudeposition(wPos:terrainheight+100),
		// red,"",1,true
	// ).
	
	// local vecCN is nPos:ALTITUDEPOSITION(nPos:TERRAINHEIGHT) - cPos:ALTITUDEPOSITION(cPos:TERRAINHEIGHT).
	// local vecCE is ePos:ALTITUDEPOSITION(ePos:TERRAINHEIGHT) - cPos:ALTITUDEPOSITION(cPos:TERRAINHEIGHT).

	local vecCN is nPos:POSITION - cPos:POSITION.
	local vecCS is sPos:POSITION - cPos:POSITION.
	local vecCE is ePos:POSITION - cPos:POSITION.
	local vecCW is wPos:POSITION - cPos:POSITION.	
	
	local vecCA is vcrs(vecCN, vecCE).
	local vecCB is vcrs(vecCS, vecCW).
	
	// set nDraw to vecdrawargs(V(0,0,0), vecCN, red, "", 1, true).
	// set sDraw to vecdrawargs(V(0,0,0), vecCS, red, "", 1, true).	
	set aDraw to vecdrawargs(V(0,0,0), vecCA, red, "", 5, true).	
	set bDraw to vecdrawargs(V(0,0,0), vecCB, blue, "", 5, true).	
	
	local angleA is round(vang(vecCA, UP:VECTOR), 2).
	local angleB is round(vang(vecCB, UP:VECTOR), 2).
	
	print ROUND(angleA,1) + "       " AT (5,0).
	print round(angleB,1) + "       " AT (5,1).
	print round(vang(up:vector, surfacePrograde)) + "            " AT (0,2).
	wait 0.1.
}

function cross { parameter vecA, vecB.
	return V(vecA:Y*vecB:Z-vecA:Z*vecB:Y, vecA:Z*vecB:X-vecA:X*vecB:Z, vecA:X*vecB:Y-vecA:Y*vecB:X).
}


