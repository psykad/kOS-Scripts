@LAZYGLOBAL OFF.

local totalIsp is 0.
lock gravity to SHIP:SENSORS:GRAV:MAG.

list engines in engineList.
for engine in engineList {
	set totalIsp to totalIsp + engine:isp.
}

clearscreen.
until false {


	local Ve is totalIsp * gravity.
	local dV is Ve * ln(ship:wetmass/ship:drymass).

	print ROUND(dV, 2) + "       " AT (0,0).
}
