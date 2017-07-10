@LAZYGLOBAL OFF.

RUN lib_core.

local offset is 0.
local nDraw is vecdraw().
local sDraw is vecdraw().
local eDraw is vecdraw().
local wDraw is vecdraw().

local targetDistance = 2.625.

CLEARSCREEN.
UNTIL FALSE {
	local cPos is ship:geoposition.	
	local nPos is latlng(cPos:lat+offset, cPos:lng).
	local sPos is latlng(cPos:lat-offset, cPos:lng).
	local ePos is latlng(cPos:lat, cPos:lng+offset).
	local wPos is latlng(cPos:lat, cPos:lng-offset).
	
	if nPos:distance < targetDistance {		
		set offset to offset + 0.0000001.
	} else {
		break.
	}
	
	set nDraw to vecdrawargs(nPos:altitudeposition(nPos:terrainheight+10),
		nPos:position - nPos:altitudeposition(nPos:terrainheight+10),
		red,"N",1,true
	).
	set sDraw to vecdrawargs(sPos:altitudeposition(sPos:terrainheight+10),
		sPos:position - sPos:altitudeposition(sPos:terrainheight+10),
		red,"S",1,true
	).
	set eDraw to vecdrawargs(ePos:altitudeposition(ePos:terrainheight+10),
		ePos:position - ePos:altitudeposition(ePos:terrainheight+10),
		red,"E",1,true
	).
	set wDraw to vecdrawargs(wPos:altitudeposition(wPos:terrainheight+10),
		wPos:position - wPos:altitudeposition(wPos:terrainheight+10),
		red,"W",1,true
	).
	
	print round(eDis, 3) + " " + round(offset, 6) + "                       " AT (0,0).
	
	wait 0.001.	
}

unset nDraw.
unset sDraw.
unset eDraw.
unset wDraw.

print "Calibration complete.".