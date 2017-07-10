@LAZYGLOBAL OFF.

LOCAL CrashVec IS LIST().

clearscreen.
UNTIL FALSE {
	local futurePos is POSITIONAT(ship,TIME:SECONDS+1).
	
	SET CrashVec TO VECDRAWARGS(v(0,0,0),futurePos,RED,"", 1, TRUE).
	
	print futurePos:direction + "               " AT (0,0).
	
	WAIT 0.001.
}
