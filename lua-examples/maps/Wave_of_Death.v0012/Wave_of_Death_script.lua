--[[
	Want add something to the map ? ask me with the vault comment. It's better than trying to understand my bad code :)

--]]


--[[
Don't edit or remove this comment block! It is used by the editor to store information since i'm too lazy to write a good LUA parser... -Haz
SETTINGS
RestrictedEnhancements=
RestrictedCategories=
END
--]]

local ScenarioUtils = import('/lua/sim/ScenarioUtilities.lua')
local ScenarioFramework = import('/lua/ScenarioFramework.lua')
local SimUtil = import('/lua/SimUtils.lua')
--type renvoit table ou number

--Table contenant la liste des unit�s par vagues
local vague_unite =
{
	{	--Vague 1
		'ual0101', --1
		'uel0101', --2
		'url0101', --3
		'xsl0101', --4
	},
	{	--Vague 2
		'uel0201', --1
		'uel0103', --2
		'uel0106', --3
		'url0107', --4
	},
	{	--Vague 3
		'xel0209', --1 ingenieur militaire
		'uel0205', --2 anti air t2
	},
	{	--Vague 4
		'drl0204', --1
		'uel0202', --2 T2 sol
		'del0204', --3
		'xsl0202', --4
	},
	{	--Vague 5
		'uel0203', --1
		'xrl0302', --2
		'daa0206', --3 missile t�l�guid�
	},
	{	--Vague 6
		'uel0303', --1
		'xel0305', --2
		'url0306', --3
		'dal0310', --4
		'del0204', --5
		'uel0202', --6
		'uel0201', --7
	},
	{	--Vague 7
		'uaa0102', --1
		'xsa0103', --2
		'xra0105', --3
	},
	{	--Vague 8
		'uea0203', --1 vaisseau combat
		'xsa0203', --2 vaisseau combat
	},
	{	--Vague 9
		'dea0202', --1
		'xel0209', --2
	},
	{	--Vague 10
		'url0303', --1
		'xel0305', --2
		'uel0307', --3
		'xsl0201', --4
	},
	{	--Vague 11
		'xrl0302', --1
		'url0306', --2
		'url0205', --3 anti air t2
	},
	{	--Vague 12
		'xrl0305', --1
		'xel0305', --2
		'uel0307', --3
		'xsl0201', --4
	},
	{	--Vague 13
		'xrl0305', --1
		'xsl0307', --2
		'uel0307', --3
		'xsl0201', --4
	},
	{	--Vague 14
		'uel0304', --1 arti mobile t3
		'ual0205', --2 anti air t2
	},
	{	--Vague 15
		'uel0401', --1 usine mobile
		'url0203', --2 robot-sulfateur
	},
	{	--Vague 16
		'url0402', --1 araign�e
		'url0203', --2 char amphibie
	},
	{	--Vague 17
		'xsl0401', --1 robot seraphim
		'ual0304', --2 arti aeon
		'xsl0307', --3 bouclier seraphim
		'uaa0303', --4 avion suprematie aeon
	},
	{	--Vague 18
		'uaa0304', --1 bombardier t3
		'xsa0303', --2 anti air t3
		'ura0103', --3 bombardier t1
	},
	{	--Vague 19
		'ual0401', --1 robot t4 aeon
		'dal0310', --2 perturbateur bouclier aeon
	},
	{	--Vague 20
		'xsa0402', --1 ahwassa
		'xsa0303', --2 suprematie t3 seraphim
	},
	{	--Vague 21
		'xrl0403', --1 mega robot cybran
		'xrl0302', --2 bombe mobile
		'url0306', --3 furtivit�
	},
	{	--Vague 22
		'url0301', --1 commandeur soutien
		'xsl0305', --2 sniper seraphim
	},
	{	--Vague 23
		'uaa0310', --1 soucoupe
	},
	{	--Vague 24
		'xel0306', --1 anti bouclier t3
		'xsl0303', --2 char t3 seraphim
		'xrl0305', --3 brick
		'xal0305', --4 sniper aeon
	},
	{	--Vague 25
		'uel0401', --1 usine mobile
		'uel0303', --2 robot d'assaut t3 ftu
		'xaa0305', --3 avion anti aerien t3 aeon
	},
	{	--Vague 26
		'xra0305', --1 vaisseau de combat t3 cybran
	},
	{	--Vague 27
		'xel0305', --1 robot blind� ftu
		'ual0301', --2 commandeur soutien
		'url0203', --3 char amphibie
		'xsl0205', --4 anti air seraphim
	},
	{	--Vague 28
		'url0401', --1 arti t4 cybran
		'urs0201', --2 destroyer cybran

	},
	{	--Vague 29
		'ura0401', --1 vaisseau de combat t4 cybran
		'xrl0403', --2 mega robot
		'url0402', --3 araign�e t4
		'xsl0203', --4 aerochar
	},
	{	--Vague 30
		'ual0401', --1 colosse
		'uel0401', --2 usine mobile
		'url0402', --3 araign�e t4
		'xrl0403', --4 megarobot
		'xsl0401', --5 robot seraphim t4
		'ura0401', --6 vaisseau combat cybran
		'xsa0402', --7 ahwassa
		'uaa0310', --8 soucoupe
		'ura0303', --9 avion suprematie aerienne t3 cybran
	},
	{	--Vague 31
		'ual0401', --1 colosse
		'uel0401', --2 usine mobile
		'url0402', --3 araign�e t4
		'xrl0403', --4 megarobot
		'xsl0401', --5 robot seraphim t4
		'ura0401', --6 vaisseau combat cybran
		'uaa0310', --7 soucoupe
		'ura0303', --8 avion suprematie aerienne t3 cybran
		'url0401', --9 arti t4 cybran
		'ual0301', --10 commandeur soutien
		'xsa0402', --11 ahwassa
	}
}

--Table contenant le nombre d'unit�s
local vague_nombre =
{
	{ --Vague 1
		15, --1
		15, --2
		15, --3
		15, --4
	},
	{ --Vague 2
		15, --1
		15, --2
		15, --3
		15, --4
	},
	{ --Vague 3
		50, --1
		55, --2
	},
	{ --Vague 4
		15, --1
		15, --2
		15, --3
		15, --4
	},
	{ --Vague 5
		25, --1
		25, --2
		15, --3
	},
	{ --Vague 6
		5, --1
		2, --2
		5, --3
		5, --4
		5, --5
		15, --6
		30, --7
	},
	{ --Vague 7
		5, --1
		45, --2
		15, --3
	},
	{ --Vague 8
		15, --1
		15, --2
	},
	{ --Vague 9
		20, --1
		30, --2
	},
	{ --Vague 10
		10, --1
		10, --2
		5, --3
		30, --4
	},
	{ --Vague 11
		40, --1
		5, --2
		10, --3
	},
	{ --Vague 12
		10, --1
		10, --2
		5, --3
		30, --4
	},
	{ --Vague 13
		20, --1
		5, --2
		5, --3
		30, --4
	},
	{ --Vague 14
		20, --1
		10, --2
	},
	{ --Vague 15
		1, --1
		20, --2
	},
	{ --Vague 16
		3, --1
		20, --2
	},
	{ --Vague 17
		2, --1
		5, --2
		10, --3
		10, --4
	},
	{ --Vague 18
		5, --1
		10, --2
		60, --3
	},
	{ --Vague 19
		3, --1
		20, --2
	},
	{ --Vague 20
		2, --1
		15, --2
	},
	{ --Vague 21
		1, --1
		30, --2
		15, --3
	},
	{ --Vague 22
		10, --1
		15, --2
	},
	{ --Vague 23
		3, --1
	},
	{ --Vague 24
		20, --1
		30, --2
		10, --3
		20, --4
	},
	{ --Vague 25
		3, --1
		10, --2
		10, --3
	},
	{ --Vague 26
		30, --1
	},
	{ --Vague 27
		20, --1
		15, --2
		30, --3
		10, --4
	},
	{ --Vague 28
		1, --1
		15, --2
	},
	{ --Vague 29
		1, --1
		1, --2
		3, --3
		30, --4
	},
	{ --Vague 30
		2, --1
		2, --2
		2, --3
		2, --4
		2, --5
		2, --6
		2, --7
		2, --8
		40, --9
	},
	{ --Vague 31
		8, --1
		6, --2
		6, --3
		10, --4
		5, --5
		6, --6
		4, --7
		60, --8
		5, --9
		25, --10
		8, --11
	}
}

local defense =
{
	{"uab2101", 0, 315.5}, --Tourelle level 1
	{"uab2101", 1, 315.5}, --Tourelle level 1
	{"uab2101", -1, 315.5}, --Tourelle level 1
	{"uab2301", -2, 225.5}, --Tourelle level 2
	{"uab2301", 0, 225.5}, --Tourelle level 2
	{"uab2301", 2, 225.5}, --Tourelle level 2
	{"uab4201", -2, 223.5}, --anti missile 2
	{"uab4201", 0, 223.5}, --anti missile 2
	{"uab4201", 2, 223.5}, --anti missile 2
	{"xsb2301", -4, 148.5}, --Tourelle level 2
	{"xsb2301", -2, 148.5}, --Tourelle level 2
	{"xsb2301", 0, 148.5}, --Tourelle level 2
	{"xsb2301", 2, 148.5}, --Tourelle level 2
	{"xsb2301", 4, 148.5}, --Tourelle level 2
	{"xsb4201", -4, 146.5}, --anti missile 2
	{"xsb4201", -2, 146.5}, --anti missile 2
	{"xsb4201", 0, 146.5}, --anti missile 2
	{"xsb4201", 2, 146.5}, --anti missile 2
	{"xsb4201", 4, 146.5}, --anti missile 2
	{"xeb2306", 6, 146.5}, --Heavy Point Defense level 3
	{"xeb2306", 8, 146.5}, --Heavy Point Defense level 3
	{"xeb2306", 10, 146.5}, --Heavy Point Defense level 3
	{"xeb2306", 12, 146.5}, --Heavy Point Defense level 3
	{"xeb2306", 14, 146.5}, --Heavy Point Defense level 3
	{"xeb2306", 16, 146.5}, --Heavy Point Defense level 3
	{"xeb2306", 18, 146.5}, --Heavy Point Defense level 3
	{"xeb2306", 20, 146.5}, --Heavy Point Defense level 3
	{"xeb2306", 22, 146.5}, --Heavy Point Defense level 3
	{"xeb2306", 24, 146.5}, --Heavy Point Defense level 3
	{"xeb2306", 26, 146.5}, --Heavy Point Defense level 3
	{"xeb2306", 28, 146.5}, --Heavy Point Defense level 3
	{"xeb2306", 30, 146.5}, --Heavy Point Defense level 3
	{"xeb2306", 32, 146.5}, --Heavy Point Defense level 3
	{"xeb2306", 34, 146.5}, --Heavy Point Defense level 3
	{"xeb2306", 36, 146.5}, --Heavy Point Defense level 3
	{"xeb2306", 38, 146.5}, --Heavy Point Defense level 3
	{"xeb2306", 40, 146.5}, --Heavy Point Defense level 3
	{"xeb2306", -6, 146.5}, --Heavy Point Defense level 3
	{"xeb2306", -8, 146.5}, --Heavy Point Defense level 3
	{"xeb2306", -10, 146.5}, --Heavy Point Defense level 3
	{"xeb2306", -12, 146.5}, --Heavy Point Defense level 3
	{"xeb2306", -14, 146.5}, --Heavy Point Defense level 3
	{"xeb2306", -16, 146.5}, --Heavy Point Defense level 3
	{"xeb2306", -18, 146.5}, --Heavy Point Defense level 3
	{"xeb2306", -20, 146.5}, --Heavy Point Defense level 3
	{"xeb2306", -22, 146.5}, --Heavy Point Defense level 3
	{"xeb2306", -24, 146.5}, --Heavy Point Defense level 3
	{"xeb2306", -26, 146.5}, --Heavy Point Defense level 3
	{"xeb2306", -28, 146.5}, --Heavy Point Defense level 3
	{"xeb2306", -30, 146.5}, --Heavy Point Defense level 3
	{"xeb2306", -32, 146.5}, --Heavy Point Defense level 3
	{"xeb2306", -34, 146.5}, --Heavy Point Defense level 3
	{"xeb2306", -36, 146.5}, --Heavy Point Defense level 3
	{"xeb2306", -38, 146.5}, --Heavy Point Defense level 3
	{"xeb2306", -40, 146.5}, --Heavy Point Defense level 3
	{"xeb2306", -42, 146.5}, --Heavy Point Defense level 3
	{"xeb2306", 6, 148.5}, --Heavy Point Defense level 3
	{"xeb2306", 8, 148.5}, --Heavy Point Defense level 3
	{"xeb2306", 10, 148.5}, --Heavy Point Defense level 3
	{"xeb2306", 12, 148.5}, --Heavy Point Defense level 3
	{"xeb2306", 14, 148.5}, --Heavy Point Defense level 3
	{"xeb2306", 16, 148.5}, --Heavy Point Defense level 3
	{"xeb2306", 18, 148.5}, --Heavy Point Defense level 3
	{"xeb2306", 20, 148.5}, --Heavy Point Defense level 3
	{"xeb2306", 22, 148.5}, --Heavy Point Defense level 3
	{"xeb2306", 24, 148.5}, --Heavy Point Defense level 3
	{"xeb2306", 26, 148.5}, --Heavy Point Defense level 3
	{"xeb2306", 28, 148.5}, --Heavy Point Defense level 3
	{"xeb2306", 30, 148.5}, --Heavy Point Defense level 3
	{"xeb2306", 32, 148.5}, --Heavy Point Defense level 3
	{"xeb2306", 34, 148.5}, --Heavy Point Defense level 3
	{"xeb2306", 36, 148.5}, --Heavy Point Defense level 3
	{"xeb2306", 38, 148.5}, --Heavy Point Defense level 3
	{"xeb2306", 40, 148.5}, --Heavy Point Defense level 3
	{"xeb2306", -6, 148.5}, --Heavy Point Defense level 3
	{"xeb2306", -8, 148.5}, --Heavy Point Defense level 3
	{"xeb2306", -10, 148.5}, --Heavy Point Defense level 3
	{"xeb2306", -12, 148.5}, --Heavy Point Defense level 3
	{"xeb2306", -14, 148.5}, --Heavy Point Defense level 3
	{"xeb2306", -16, 148.5}, --Heavy Point Defense level 3
	{"xeb2306", -18, 148.5}, --Heavy Point Defense level 3
	{"xeb2306", -20, 148.5}, --Heavy Point Defense level 3
	{"xeb2306", -22, 148.5}, --Heavy Point Defense level 3
	{"xeb2306", -24, 148.5}, --Heavy Point Defense level 3
	{"xeb2306", -26, 148.5}, --Heavy Point Defense level 3
	{"xeb2306", -28, 148.5}, --Heavy Point Defense level 3
	{"xeb2306", -30, 148.5}, --Heavy Point Defense level 3
	{"xeb2306", -32, 148.5}, --Heavy Point Defense level 3
	{"xeb2306", -34, 148.5}, --Heavy Point Defense level 3
	{"xeb2306", -36, 148.5}, --Heavy Point Defense level 3
	{"xeb2306", -38, 148.5}, --Heavy Point Defense level 3
	{"xeb2306", -40, 148.5}, --Heavy Point Defense level 3
	{"xeb2306", -42, 148.5}, --Heavy Point Defense level 3
	{"xeb2306", 0, 150.5}, --Heavy Point Defense level 3
	{"xeb2306", 2, 150.5}, --Heavy Point Defense level 3
	{"xeb2306", 4, 150.5}, --Heavy Point Defense level 3
	{"xeb2306", 6, 150.5}, --Heavy Point Defense level 3
	{"xeb2306", 8, 150.5}, --Heavy Point Defense level 3
	{"xeb2306", 10, 150.5}, --Heavy Point Defense level 3
	{"xeb2306", 12, 150.5}, --Heavy Point Defense level 3
	{"xeb2306", 14, 150.5}, --Heavy Point Defense level 3
	{"xeb2306", 16, 150.5}, --Heavy Point Defense level 3
	{"xeb2306", 18, 150.5}, --Heavy Point Defense level 3
	{"xeb2306", 20, 150.5}, --Heavy Point Defense level 3
	{"xeb2306", 22, 150.5}, --Heavy Point Defense level 3
	{"xeb2306", 24, 150.5}, --Heavy Point Defense level 3
	{"xeb2306", 26, 150.5}, --Heavy Point Defense level 3
	{"xeb2306", 28, 150.5}, --Heavy Point Defense level 3
	{"xeb2306", 30, 150.5}, --Heavy Point Defense level 3
	{"xeb2306", 32, 150.5}, --Heavy Point Defense level 3
	{"xeb2306", 34, 150.5}, --Heavy Point Defense level 3
	{"xeb2306", 36, 150.5}, --Heavy Point Defense level 3
	{"xeb2306", 38, 150.5}, --Heavy Point Defense level 3
	{"xeb2306", 40, 150.5}, --Heavy Point Defense level 3
	{"xeb2306", -2, 150.5}, --Heavy Point Defense level 3
	{"xeb2306", -4, 150.5}, --Heavy Point Defense level 3
	{"xeb2306", -6, 150.5}, --Heavy Point Defense level 3
	{"xeb2306", -8, 150.5}, --Heavy Point Defense level 3
	{"xeb2306", -10, 150.5}, --Heavy Point Defense level 3
	{"xeb2306", -12, 150.5}, --Heavy Point Defense level 3
	{"xeb2306", -14, 150.5}, --Heavy Point Defense level 3
	{"xeb2306", -16, 150.5}, --Heavy Point Defense level 3
	{"xeb2306", -18, 150.5}, --Heavy Point Defense level 3
	{"xeb2306", -20, 150.5}, --Heavy Point Defense level 3
	{"xeb2306", -22, 150.5}, --Heavy Point Defense level 3
	{"xeb2306", -24, 150.5}, --Heavy Point Defense level 3
	{"xeb2306", -26, 150.5}, --Heavy Point Defense level 3
	{"xeb2306", -28, 150.5}, --Heavy Point Defense level 3
	{"xeb2306", -30, 150.5}, --Heavy Point Defense level 3
	{"xeb2306", -32, 150.5}, --Heavy Point Defense level 3
	{"xeb2306", -34, 150.5}, --Heavy Point Defense level 3
	{"xeb2306", -36, 150.5}, --Heavy Point Defense level 3
	{"xeb2306", -38, 150.5}, --Heavy Point Defense level 3
	{"xeb2306", -40, 150.5}, --Heavy Point Defense level 3
	{"xeb2306", -42, 150.5}, --Heavy Point Defense level 3
	{"ueb2304", 0, 144.5}, -- Anti-Air SAM Launcher level 3
	{"ueb2304", 2, 144.5}, -- Anti-Air SAM Launcher level 3
	{"ueb2304", 4, 144.5}, -- Anti-Air SAM Launcher level 3
	{"ueb2304", 6, 144.5}, -- Anti-Air SAM Launcher level 3
	{"ueb2304", 8, 144.5}, -- Anti-Air SAM Launcher level 3
	{"ueb2304", 10, 144.5}, -- Anti-Air SAM Launcher level 3
	{"ueb2304", 12, 144.5}, -- Anti-Air SAM Launcher level 3
	{"ueb2304", 14, 144.5}, -- Anti-Air SAM Launcher level 3
	{"ueb2304", 16, 144.5}, -- Anti-Air SAM Launcher level 3
	{"ueb2304", 18, 144.5}, -- Anti-Air SAM Launcher level 3
	{"ueb2304", 20, 144.5}, -- Anti-Air SAM Launcher level 3
	{"ueb2304", 22, 144.5}, -- Anti-Air SAM Launcher level 3
	{"ueb2304", 24, 144.5}, -- Anti-Air SAM Launcher level 3
	{"ueb2304", 26, 144.5}, -- Anti-Air SAM Launcher level 3
	{"ueb2304", 28, 144.5}, -- Anti-Air SAM Launcher level 3
	{"ueb2304", 30, 144.5}, -- Anti-Air SAM Launcher level 3
	{"ueb2304", 32, 144.5}, -- Anti-Air SAM Launcher level 3
	{"ueb2304", 34, 144.5}, -- Anti-Air SAM Launcher level 3
	{"ueb2304", 36, 144.5}, -- Anti-Air SAM Launcher level 3
	{"ueb2304", 38, 144.5}, -- Anti-Air SAM Launcher level 3
	{"ueb2304", 40, 144.5}, -- Anti-Air SAM Launcher level 3
	{"ueb2304", -2, 144.5}, -- Anti-Air SAM Launcher level 3
	{"ueb2304", -4, 144.5}, -- Anti-Air SAM Launcher level 3
	{"ueb2304", -6, 144.5}, -- Anti-Air SAM Launcher level 3
	{"ueb2304", -8, 144.5}, -- Anti-Air SAM Launcher level 3
	{"ueb2304", -10, 144.5}, -- Anti-Air SAM Launcher level 3
	{"ueb2304", -12, 144.5}, -- Anti-Air SAM Launcher level 3
	{"ueb2304", -14, 144.5}, -- Anti-Air SAM Launcher level 3
	{"ueb2304", -16, 144.5}, -- Anti-Air SAM Launcher level 3
	{"ueb2304", -18, 144.5}, -- Anti-Air SAM Launcher level 3
	{"ueb2304", -20, 144.5}, -- Anti-Air SAM Launcher level 3
	{"ueb2304", -22, 144.5}, -- Anti-Air SAM Launcher level 3
	{"ueb2304", -24, 144.5}, -- Anti-Air SAM Launcher level 3
	{"ueb2304", -26, 144.5}, -- Anti-Air SAM Launcher level 3
	{"ueb2304", -28, 144.5}, -- Anti-Air SAM Launcher level 3
	{"ueb2304", -30, 144.5}, -- Anti-Air SAM Launcher level 3
	{"ueb2304", -32, 144.5}, -- Anti-Air SAM Launcher level 3
	{"ueb2304", -34, 144.5}, -- Anti-Air SAM Launcher level 3
	{"ueb2304", -36, 144.5}, -- Anti-Air SAM Launcher level 3
	{"ueb2304", -38, 144.5}, -- Anti-Air SAM Launcher level 3
	{"ueb2304", -40, 144.5}, -- Anti-Air SAM Launcher level 3
	{"ueb2304", -42, 144.5}, -- Anti-Air SAM Launcher level 3
	{"ueb2304", 0, 142.5}, -- Anti-Air SAM Launcher level 3
	{"ueb2304", 2, 142.5}, -- Anti-Air SAM Launcher level 3
	{"ueb2304", 4, 142.5}, -- Anti-Air SAM Launcher level 3
	{"ueb2304", 6, 142.5}, -- Anti-Air SAM Launcher level 3
	{"ueb2304", 8, 142.5}, -- Anti-Air SAM Launcher level 3
	{"ueb2304", 10, 142.5}, -- Anti-Air SAM Launcher level 3
	{"ueb2304", 12, 142.5}, -- Anti-Air SAM Launcher level 3
	{"ueb2304", 14, 142.5}, -- Anti-Air SAM Launcher level 3
	{"ueb2304", 16, 142.5}, -- Anti-Air SAM Launcher level 3
	{"ueb2304", 18, 142.5}, -- Anti-Air SAM Launcher level 3
	{"ueb2304", 20, 142.5}, -- Anti-Air SAM Launcher level 3
	{"ueb2304", 22, 142.5}, -- Anti-Air SAM Launcher level 3
	{"ueb2304", 24, 142.5}, -- Anti-Air SAM Launcher level 3
	{"ueb2304", 26, 142.5}, -- Anti-Air SAM Launcher level 3
	{"ueb2304", 28, 142.5}, -- Anti-Air SAM Launcher level 3
	{"ueb2304", 30, 142.5}, -- Anti-Air SAM Launcher level 3
	{"ueb2304", 32, 142.5}, -- Anti-Air SAM Launcher level 3
	{"ueb2304", 34, 142.5}, -- Anti-Air SAM Launcher level 3
	{"ueb2304", 36, 142.5}, -- Anti-Air SAM Launcher level 3
	{"ueb2304", 38, 142.5}, -- Anti-Air SAM Launcher level 3
	{"ueb2304", 40, 142.5}, -- Anti-Air SAM Launcher level 3
	{"ueb2304", -2, 142.5}, -- Anti-Air SAM Launcher level 3
	{"ueb2304", -4, 142.5}, -- Anti-Air SAM Launcher level 3
	{"ueb2304", -6, 142.5}, -- Anti-Air SAM Launcher level 3
	{"ueb2304", -8, 142.5}, -- Anti-Air SAM Launcher level 3
	{"ueb2304", -10, 142.5}, -- Anti-Air SAM Launcher level 3
	{"ueb2304", -12, 142.5}, -- Anti-Air SAM Launcher level 3
	{"ueb2304", -14, 142.5}, -- Anti-Air SAM Launcher level 3
	{"ueb2304", -16, 142.5}, -- Anti-Air SAM Launcher level 3
	{"ueb2304", -18, 142.5}, -- Anti-Air SAM Launcher level 3
	{"ueb2304", -20, 142.5}, -- Anti-Air SAM Launcher level 3
	{"ueb2304", -22, 142.5}, -- Anti-Air SAM Launcher level 3
	{"ueb2304", -24, 142.5}, -- Anti-Air SAM Launcher level 3
	{"ueb2304", -26, 142.5}, -- Anti-Air SAM Launcher level 3
	{"ueb2304", -28, 142.5}, -- Anti-Air SAM Launcher level 3
	{"ueb2304", -30, 142.5}, -- Anti-Air SAM Launcher level 3
	{"ueb2304", -32, 142.5}, -- Anti-Air SAM Launcher level 3
	{"ueb2304", -34, 142.5}, -- Anti-Air SAM Launcher level 3
	{"ueb2304", -36, 142.5}, -- Anti-Air SAM Launcher level 3
	{"ueb2304", -38, 142.5}, -- Anti-Air SAM Launcher level 3
	{"ueb2304", -40, 142.5}, -- Anti-Air SAM Launcher level 3
	{"ueb2304", -42, 142.5}, -- Anti-Air SAM Launcher level 3
	{"ual0401", 0, 153.5}, -- Colossus level 4
	{"xrl0403", 26, 155.5}, -- Megarobot level 4
	{"xrl0403", -26, 155.5}, -- Megarobot level 4
	{"xab1401", 0, 800.5}, -- parangorn
}

local army_radar_structures =
{
	{"ueb1301", 69, 670.5}, --energie
	{"ueb1301", 69, 670.5}, --energie
	{"uab3104", 69, 670.5}, --radar
}

--Table contenant la liste des �quipe, chaque �quipe est une table contenant une liste d'ARMY
local teamTable = {}
--Exemple :
--[[
	{
		{
			couloir="6",
			enemy="1",
			origineX={	699,709,688,677,720,731},
			team={ "ARMY_1", "ARMY_2", "ARMY_3", "ARMY_4", "ARMY_5", "ARMY_6" }
			wave={ "next"="4", "list"={ "1", "2", {"3", {unit1, unit2...}}}, "propagation"={} }
		},
		{
			couloir="7",
			enemy="2",
			origineX={ 832.5 },
			team={ "ARMY_7" }
			wave={ "next"="5", "list"={ "1", "2", {"3", {unit1, unit2...}}, {"4", {unit1, unit2....}}}, "propagation"={} }
		}
	}
--]]

local joueurTable = {
--[[
	{
		ARMY_1,
		PENALITERESTANTES,
		MORT(true,false),
		COMMANDER,
	},

]]


}
local joueurVagueCourante = {}

local joueurVague = --Table contenant les propri�t� des vagues d'un joueur
{
}
--[[
{ --Architecture de la table "joueurVague"
	{ --Pour un joueur
		ARMY_1, id du joueur
		1,      vague en attente d'�tre envoy�e
		{				liste des vagues (chaque case de ce tableau (0 en d�but de partie) peut contenir un seul nombre type=number (dans le cas ou la vague est vaincue), ou bien un tableau type=table contenant 2 cases la premi�re est le numero de la vague et la 2eme un autre tableau, qui est le platoon
			1, -- num�ro d'une la vague vaincue
			2, -- num�ro d'une la vague vaincue
			{
				3, -- num�ro de la vague ci dessous non termin�e
				{  --Liste des bps de la vague
					unit1,
					unit2,
				}
			},
		},
		{ --Liste des vagues qui sont des vagues venant d'autre joueurs
			{
				unit1,
				unit2,
			}
			{
				unit1,
				unit2,
				unit3,
			}
		}
	},
}
]]
local launcherTable = {}
local launcherBaseTable = {}

local numeroGagnant = 1
local numeroPerdant = 0 --A initialiser
local maxPerdant = 0 --A initialiser

local turretGonzalesTable = {}

local currentMassSpot = 1

local language = "english" --french or english

local languageText =
{
	["english"] =
	{
		["cheat1"] = " is trying to cheat by hiding his acu with a carrier,fucking bastard !",
		["cheat2"] = " is trying to cheat by hiding his acu by teleporting it, fucking bastard !",
		["cheat3"] = " fucking asshole ! die !!!",
		["launch1"] = " are launching wave number ",
		["launch2"] = " is launching wave number ",
		["destroy1"] = " have destroyed wave ",
		["destroy2"] = " has destroyed wave ",
		["position1"] = "st",
		["position2"] = "last",
		["position3"] = "th",
		["position4"] = " finished ",
		["unitname1"] = "Launcher",
		["unitname2"] = "No more waves to send",
		["unitname3"] = "Next : ",
		["basename1"] = "Approach the launcher here",
		["basename2"] = "Killed : ",
	},
	["francais"] =
	{
		["cheat1"] = " essaye de tricher en cachant son commander avec un transporteur, quel connard !",
		["cheat2"] = " essaye de tricher en cachant son commander en se teleportant, quel connard !",
		["launch1"] = " lancent la vague ",
		["launch2"] = " lance la vague ",
		["destroy1"] = " ont detruit la vague ",
		["destroy2"] = " lance la vague ",
		["position1"] = "er",
		["position2"] = "dernier",
		["position3"] = "eme",
		["position4"] = " a termine ",
		["unitname1"] = "Lanceur",
		["unitname2"] = "Plus aucune vague a envoyer",
		["unitname3"] = "Suivante : ",
		["basename1"] = "Approcher le lanceur ici",
		["basename2"] = "Vaincues : ",
	},
}


function OnPopulate()




  ScenarioUtils.InitializeArmies()
  ScenarioFramework.SetPlayableArea('AREA_1' , false)
end

function OnStart(self)
	--Initialisation du langage
	if(ScenarioInfo.Options.opt_language!=nil) then
		if( ScenarioInfo.Options.opt_language == 2 ) then
			language = "francais"
		end
	end

	--Initialisation des tableaux de vague
	for j, army in ListArmies() do
		if (army == "ARMY_1" or army == "ARMY_2" or army == "ARMY_3" or army == "ARMY_4" or army == "ARMY_5" or army == "ARMY_6" or army == "ARMY_7" or army == "ARMY_8") then
			t = {army, 3,false}
			table.insert(joueurTable,t)
			content = {army,1,{},{}}
			table.insert(joueurVague,content)
			brain = GetArmyBrain(army)
			brain:SetResourceSharing(false)
		end
	end

	--Initialisation des tableaux de teams
	local armyOk = {} --Liste des joueurs plac�
	local currentEnemyIndex = 1
	for i, army in ListArmies() do
		if (army == "ARMY_1" or army == "ARMY_2" or army == "ARMY_3" or army == "ARMY_4" or army == "ARMY_5" or army == "ARMY_6" or army == "ARMY_7" or army == "ARMY_8") then
			--On regarde si le joueur n'a pas d�j� �t� assign�e � une �quipe
			local found = false
			for j, ar in armyOk do --Le joueur a t'il d�j� �t� plac� ?
				if(ar==army)then
					found = true
				end
			end
			if (not found) then --Il n'a pas �t� plac� alors on va le placer
				local aTeam = { army }
				table.insert(armyOk, army)
				for i2, army2 in ListArmies() do
					if (army2 == "ARMY_1" or army2 == "ARMY_2" or army2 == "ARMY_3" or army2 == "ARMY_4" or army2 == "ARMY_5" or army2 == "ARMY_6" or army2 == "ARMY_7" or army2 == "ARMY_8") then
						if ( i < i2 ) then --Pas le m�me joueur et pas un joueur d�j� parcouru
							local armySetup = ScenarioInfo.ArmySetup[army]
							local army2Setup = ScenarioInfo.ArmySetup[army2]
							if(armySetup.Team == army2Setup.Team and armySetup.Team ~= 1)then
								table.insert( aTeam, army2 ) --On ajoute le nouveau joueur dans l'�quipe
								table.insert( armyOk, army2 ) --On dit que le joueur a �t� plac�
							end
						end
					end
				end
				table.insert(teamTable, {['team'] = aTeam, ['couloir'] = 1, ['origineX'] = {}, ['enemy'] = currentEnemyIndex, ['wave'] = { ['next'] = 1, ['list'] = {}, ['propagation'] = {}}, } )
				currentEnemyIndex = currentEnemyIndex + 1
			end
		end
	end


	--Choix du couloir pour chacunes des teams
	--On va choisir un couloir au hasard en fonction des couloirs poss�d�s par les joueurs de la team
	for i, team in teamTable do --Pour chacune des teams
		local nbCouloirs = table.getn(team.team) --Nombre total de couloir poss�d�s
		local couloirDeLaTeam = Random(1,nbCouloirs) --R�cup�ration du num�ro du couloir de la team choisit (pas le couloir de la map)
		for j, army in team.team do
			if (couloirDeLaTeam == 1) then --Si on est arriv� au couloir choisit on r�cup�re le num�ro de couloir sur la map
				number = explode("_",army)
				number = number[2] --Num�ro du couloir
				team.couloir = number
				break
			else
				couloirDeLaTeam = couloirDeLaTeam - 1
			end
		end
	end


	--Pour chacunes des �quipes --> r�cup�ration origineX --> pour chacun des joueurs --> d�calage origineX --> t�l�portage commander --> placement spots

	for i, team in teamTable do -- Pour chacunes des �quipes
		local origineX = 64.5 + ( (tonumber(team.couloir) - 1) * 128 )
		local offSet = 0
		local origineXJoueur = 0
		local invers = false
		local xMin = origineX
		local xMax = origineX
		for j, army in team.team do -- Pour chacun des joueurs
			--DECALAGE ORIGINEX
			origineXJoueur = origineX + offSet
			team.origineX[j] = origineXJoueur
			if (xMin > origineXJoueur) then
				xMin = origineXJoueur
			end

			if (xMax < origineXJoueur) then
				xMax = origineXJoueur
			end

			if(invers)then -- On inverse l'offset
				offSet = offSet *-1
				invers = false
			else -- On augmente l'offset dans le bon sens
				if(offSet<0)then
					offSet = offSet - (64 / table.getn(team.team))
				else
					offSet = offSet + (64 / table.getn(team.team))
				end
				invers = true
			end
		end

		if(origineX - xMin ~= xMax - origineX) then --Si il y a une diff�rence, il faut tout recentrer
			local ecartDroite = xMax - origineX
			local ecartGauche = origineX - xMin
			local difference = (ecartDroite - ecartGauche) / 2
			for j, army in team.team do -- Pour chacun des joueurs
				team.origineX[j] = team.origineX[j] - difference
			end
		end




		for j, army in team.team do -- Pour chacun des joueurs
			local origineXJoueur = team.origineX[j]
			--TELEPORTAGE COMMANDER


			--PLACEMENT SPOTS
				GenerateResourcesMarker(origineXJoueur, 125.50)
				GenerateResourcesMarker(origineXJoueur, 129.50)
				GenerateResourcesMarker(origineXJoueur, 133.50)
				GenerateResourcesMarker(origineXJoueur, 137.50)

				GenerateResourcesMarker(origineXJoueur, 207.50)
				GenerateResourcesMarker(origineXJoueur, 211.50)
				GenerateResourcesMarker(origineXJoueur, 215.50)
				GenerateResourcesMarker(origineXJoueur, 219.50)

				GenerateResourcesMarker(origineXJoueur, 295.50)
				GenerateResourcesMarker(origineXJoueur, 299.50)
				GenerateResourcesMarker(origineXJoueur, 303.50)
				GenerateResourcesMarker(origineXJoueur, 307.50)

				GenerateResourcesMarker(origineXJoueur, 440.50)
				GenerateResourcesMarker((origineXJoueur - 2), 442.50)
				GenerateResourcesMarker((origineXJoueur + 2), 442.50)
				GenerateResourcesMarker(origineXJoueur, 444.50)
				GenerateResourcesMarker((origineXJoueur - 2), 446.50)
				GenerateResourcesMarker((origineXJoueur + 2), 446.50)
				GenerateResourcesMarker(origineXJoueur, 448.50)

				GenerateGasResourcesMarker(origineXJoueur)

		end
	end


	numeroPerdant = table.getn(teamTable)
	maxPerdant = table.getn(teamTable)
	ScenarioInfo.Options.Victory = 'sandbox';
	modeAssassina()


	--Parcours des joueurs -> pour chacun alliance avec tous les survival puis enemi avec un survival pr�cis
	--Parcours des survival -> pour chacun alliance avec tous les joueurs puis enemi avec un joueur pr�cis

	-- configuration des alliances



	for i, army in ListArmies() do
		if (army == "ARMY_1" or army == "ARMY_2" or army == "ARMY_3" or army == "ARMY_4" or army == "ARMY_5" or army == "ARMY_6" or army == "ARMY_7" or army == "ARMY_8") then


			--faces aux survival
			SetAlliance(army, "ARMY_SURVIVAL_ENEMY_1", 'Ally');
			SetAlliance(army, "ARMY_SURVIVAL_ENEMY_2", 'Ally');
			SetAlliance(army, "ARMY_SURVIVAL_ENEMY_3", 'Ally');
			SetAlliance(army, "ARMY_SURVIVAL_ENEMY_4", 'Ally');
			SetAlliance(army, "ARMY_SURVIVAL_ENEMY_5", 'Ally');
			SetAlliance(army, "ARMY_SURVIVAL_ENEMY_6", 'Ally');
			SetAlliance(army, "ARMY_SURVIVAL_ENEMY_7", 'Ally');
			SetAlliance(army, "ARMY_SURVIVAL_ENEMY_8", 'Ally');


			SetAlliance(army, getArmySurvivalVersusAPlayer(army), 'Enemy')
			-- alliance des joueurs entre eux
			for j, army2 in ListArmies() do
				if (army2 == "ARMY_1" or army2 == "ARMY_2" or army2 == "ARMY_3" or army2 == "ARMY_4" or army2 == "ARMY_5" or army2 == "ARMY_6" or army2 == "ARMY_7" or army2 == "ARMY_8") then
					SetAlliance(army, army2, 'Ally');
				end
			end
		else
			-- alliance des survival entre eux
			for j, army2 in ListArmies() do
				if (army2 == "ARMY_SURVIVAL_ENEMY_1" or army2 == "ARMY_SURVIVAL_ENEMY_2" or army2 == "ARMY_SURVIVAL_ENEMY_3" or army2 == "ARMY_SURVIVAL_ENEMY_4" or army2 == "ARMY_SURVIVAL_ENEMY_5" or army2 == "ARMY_SURVIVAL_ENEMY_6" or army2 == "ARMY_SURVIVAL_ENEMY_7" or army2 == "ARMY_SURVIVAL_ENEMY_8" or army2 == "ARMY_RADAR") then
					SetIgnoreArmyUnitCap(army2, true)
					SetAlliance(army, army2, 'Ally');
					brain = GetArmyBrain(army)
					brain:SetResourceSharing(false)
				end
			end
		end
	end

	for index, brain in ArmyBrains do --On calcule le score
		brain.CalculateScore = function(thisBrain)
			army = indexToArmy(thisBrain:GetArmyIndex())
			local totalDetruit = 0
			totalVague = table.getn(vague_unite)

			local wave = getWaveByArmy( army )
			if(wave ~= nil ) then
				for j, vague in wave.list do
					if type(vague)!="table" then
						totalDetruit = totalDetruit + 1
					end
				end
			end
			return (totalVague-totalDetruit)
		end
	end


	spawnUnitDepart()
	changeColor()
	refreshPlatoon() --relance les platoon endormis
	verificateurZone() --V�rifie que tout le monde est chez soi, regarde si on veut envoyer une vague
end


spawnUnitDepart = function()
	for j, army in ListArmies() do
		if (army == "ARMY_1" or army == "ARMY_2" or army == "ARMY_3" or army == "ARMY_4" or army == "ARMY_5" or army == "ARMY_6" or army == "ARMY_7" or army == "ARMY_8") then
			decalage = 0
			for z, team in teamTable do
				for indexAr, ar in team.team do
					if(ar == army)then
						decalage = team.origineX[indexAr]
					end
				end
			end

			enemyArmy = getEnemyOfArmy(army)

			number = explode("_",army)
			--decalage  = (tonumber(number[2])-1)*128

			tmp = CreateUnitHPR("uel0101",army, (decalage), 156.055, 529.5,0,0,0) --Cr�ation du launcher
			tmp:SetCustomName(languageText[language]["unitname1"]);
			makeInvincible(tmp)

			aiBrain = GetArmyBrain(army);
			plat = aiBrain:MakePlatoon('','');
			aiBrain:AssignUnitsToPlatoon(plat, {tmp}, 'Scout', "AttackFormation");




			t = {army,tmp,plat}
			table.insert(launcherTable,t)

			tmp = CreateUnitHPR("xrc1502",army, (decalage), 156.055, 519.5,0,0,0) --Cr�ation de la cible du launcher
			tmp:SetCustomName(languageText[language]["basename1"]);
			makeInvincible(tmp)
			t = {army,tmp}
			table.insert(launcherBaseTable,t)


			if(ScenarioInfo.Options.opt_faction==nil or (ScenarioInfo.Options.opt_faction != nil and ScenarioInfo.Options.opt_faction == 1)) then
				--Cr�ation des 4 ing�nieurs
				CreateUnitHPR("ual0105",army, (decalage - 2), 156.055, 425.5,0,0,0)
				CreateUnitHPR("uel0105",army, (decalage - 1), 156.055, 425.5,0,0,0)
				CreateUnitHPR("url0105",army, (decalage + 1), 156.055, 425.5,0,0,0)
				CreateUnitHPR("xsl0105",army, (decalage + 2), 156.055, 425.5,0,0,0)
			end

			for i=532.5,517.5,-1 do --murs verticaux du bas vers le haut
				obj = "uab5101"
				if i==524.5 then
					obj = "urb5101"
				end

				tmp = CreateUnitHPR(obj,army, (decalage - 2), 156.055, i,0,0,0)
				makeInvincible(tmp)
				tmp = CreateUnitHPR(obj,army, (decalage + 2), 156.055, i,0,0,0)
				makeInvincible(tmp)
			end
			for i=-2,2,1 do --murs horizontaux de gauche a droite
				tmp = CreateUnitHPR("uab5101",army, (i + decalage), 156.055, 532.5,0,0,0)
				makeInvincible(tmp)
				tmp = CreateUnitHPR("uab5101",army, (i + decalage), 156.055, 517.5,0,0,0)
				makeInvincible(tmp)
			end

			--CREATION DES BASES DE DEFENSE
			for defN, defInfo in defense do
				CreateUnitHPR(defInfo[1],"ARMY_SURVIVAL_ENEMY_"..enemyArmy, (defInfo[2] + decalage), 156.055, defInfo[3],0,0,0)
			end
			--CREATION DES RADAR
			for defN, defInfo in army_radar_structures do
				CreateUnitHPR(defInfo[1],"ARMY_RADAR", (defInfo[2] + decalage), 156.055, defInfo[3],0,0,0)
			end
		end
	end
end


modeAssassina = function()
	for i, army in ListArmies() do
		if (army == "ARMY_1" or army == "ARMY_2" or army == "ARMY_3" or army == "ARMY_4" or army == "ARMY_5" or army == "ARMY_6" or army == "ARMY_7" or army == "ARMY_8") then
			local aiBrain = GetArmyBrain(army);
			local units = aiBrain:GetListOfUnits(categories.ALLUNITS - categories.WALL, false)
			for j,unit in units do
				local bp = unit:GetBlueprint()
				if(isACU(bp.BlueprintId))then
					unit.OldOnKilled = unit.OnKilled
					unit.OnKilled = commander_destruction
					for k,t in joueurTable do
						if t[1]==army then
							table.insert(t,unit);
							for indexTeam, team in teamTable do
								for indexJoueur, joueurArmy in team.team do
									if( joueurArmy == army ) then
										Warp(unit,{team.origineX[indexJoueur],150,433.50,0,0,0})
										break
									end
								end
							end
							break
						end
					end
				end
			end
		end
	end
end

commander_destruction = function(self, instigator, type_, overkillRatio) --Lorsque un des commander a �t� p�t�


	for i, joueur in joueurTable do --On met � jour l'info du joueur pour dire qu'il est mort
		if joueur[1]==indexToArmy(self:GetArmy()) then
			joueur[3]=true
		end
	end
	--for i, joueur in joueurVague do
	--	if joueur[1]==indexToArmy(self:GetArmy()) then --On d�truit toutes les unit�s de chacun de ses platoons


			--Si l'�quipe enti�re a perdu :
	----On nettoie le couloir en faisant p�ter des nukes (ou plutot des commanders ^^)
	----On dit que l'�quipe "ensemble de noms" a perdu

	--Compte le nombre de joueurs dans l'�quipe et compte le nombre de morts
	local totalJoueurs = 0
	local totalMorts = 0
	local number = 0
	local decalage = 0
	for teamIndex, team in teamTable do
		local teamTrouve = false
		for joueurIndex, joueurArmy in team.team do
			if(joueurArmy==indexToArmy(self:GetArmy()))then --On a trouv� l'�quipe du joueur
				totalJoueurs = table.getn(team.team)
				teamTrouve = true
				break
			end
		end
		if(teamTrouve)then
			number = tonumber(team.couloir)
			decalage = (number-1)*128
			for joueurIndex, joueurArmy in team.team do --On reparcours � nouveau cette team car en faite le joueur qui vient de mourir est compris dedans
				for joueurTableIndex, joueurTableInfo in joueurTable do
					if(joueurTableInfo[1]==joueurArmy and joueurTableInfo[3])then --On a trouv� un nouveau mort dans l'�quipe
						totalMorts = totalMorts + 1
					end
				end
			end
		end
	end


	if(totalJoueurs==totalMorts)then --L'�QUIPE ENTI�RE EST MORTE
		local army = indexToArmy(self:GetArmy())
		doDefaite(army)
		local wave = getWaveByArmy(army)
		local listPlatoon = wave.list
		local taillePlatoon = table.getn(listPlatoon)
		for i=1,taillePlatoon,1 do
			if type(listPlatoon[i])=="table" then
				local units = listPlatoon[i][2]:GetPlatoonUnits()
				for i, unit in units do
					if not IsDestroyed(unit) then
						unit:Kill()
					end
				end
			end
		end

		local listPlatoonPropagation = wave.propagation
		if(listPlatoonPropagation ~= nil)then
			local taillePlatoon = table.getn(listPlatoonPropagation)
			for i=1,taillePlatoon,1 do
				local units = listPlatoonPropagation[i]:GetPlatoonUnits()
				for i, unit in units do
					if not IsDestroyed(unit) then
						unit:Kill()
					end
				end
			end
		end



		ForkThread( function()
			for y=30,450,30 do
				WaitSeconds(0.5);
				local acu = CreateUnitHPR( "xab1401", "ARMY_SURVIVAL_ENEMY_1", 64+decalage, 119.5, y, 0,0,0);
				acu:Kill()
			end
			for y=45,465,30 do
				WaitSeconds(0.5);
				local acu = CreateUnitHPR( "ual0001", "ARMY_SURVIVAL_ENEMY_1", 84+decalage, 119.5, y, 0,0,0);
				acu:Kill()
				local acu = CreateUnitHPR( "ual0001", "ARMY_SURVIVAL_ENEMY_1", 44+decalage, 119.5, y, 0,0,0);
				acu:Kill()
			end
		end)


	end


	self.OldOnKilled(self, instigator, type_, overkillRatio)
	local aiBrain = GetArmyBrain(self:GetArmy());

	aiBrain:AbandonedByPlayer(aiBrain)
end

unit_damage = function(self, instigator, amount, vector, damageType )
	local tueurArmy = indexToArmy(instigator:GetArmy())
	local victime = indexToArmy(self:GetArmy())

	if( (tueurArmy ~= "ARMY_1" and tueurArmy ~= "ARMY_2" and tueurArmy ~= "ARMY_3" and tueurArmy ~= "ARMY_4" and tueurArmy ~= "ARMY_5" and tueurArmy ~= "ARMY_6" and tueurArmy ~= "ARMY_7" and tueurArmy ~= "ARMY_8") or (victime==tueurArmy) )then
		self.OldOnDamage(self, instigator, amount, vector, damageType)
	end
	if(victime == "ARMY_SURVIVAL_ENEMY_1" or victime == "ARMY_SURVIVAL_ENEMY_2" or victime == "ARMY_SURVIVAL_ENEMY_3" or victime == "ARMY_SURVIVAL_ENEMY_4" or victime == "ARMY_SURVIVAL_ENEMY_5" or victime == "ARMY_SURVIVAL_ENEMY_6" or victime == "ARMY_SURVIVAL_ENEMY_7" or victime == "ARMY_SURVIVAL_ENEMY_8" ) then
		self.OldOnDamage(self, instigator, amount, vector, damageType)
	end
end


function explode(div,str)
  if (div=='') then return false end
  local pos,arr = 0,{}
  -- for each divider found
  for st,sp in function() return string.find(str,div,pos,true) end do
    table.insert(arr,string.sub(str,pos,st-1)) -- Attach chars left of current divider
    pos = sp + 1 -- Jump past current divider
  end
  table.insert(arr,string.sub(str,pos)) -- Attach chars right of last divider
  return arr
end

spawnEffect = function(unit)
	ForkThread( function()
		unit:PlayUnitSound('TeleportStart')
		unit:PlayUnitAmbientSound('TeleportLoop')
		WaitSeconds( 0.1 )
		unit:PlayTeleportInEffects()
		unit:StopUnitAmbientSound('TeleportLoop')
		unit:PlayUnitSound('TeleportEnd')
	end)
end

makeInvincible = function(unit)
   unit:SetDoNotTarget(true)
   unit:SetCanBeKilled(false)
   unit:SetCapturable(false)
   unit:SetReclaimable(false)
   unit:SetRegenRate(1)
   unit:SetMaxHealth(1)
   unit:SetHealth(nil,1)
end

verificateurZone = function()
	ForkThread( function()
		local SecondLeftUnitProtection = 5
		while true do
			WaitSeconds(1);
			for indJoueur, joueur in joueurTable do   -- -->joueur[1]=ARMY_X joueur[2]=Penalit� joueur[3]=Mort? joueur[4]=commander
				if not joueur[3] then --Si le joueur n'est pas mort alors on va faire 2-3 v�rifications
					army = joueur[1]

					number = getCouloirOfArmy(army)
					local decalageDeCouloir = (number-1)*128
					local origineXJoueur = getOrigineXOfArmy(army)
					posx = joueur[4]:GetPosition()[1]
					posy = joueur[4]:GetPosition()[3]
					if posx < (0 + decalageDeCouloir) or posx > (128 + decalageDeCouloir) or posy > 500 then --LE COMMANDER VEUT S'�CHAPER
						joueur[2] = joueur[2]-1 --On ajoute un malus de p�nalit�
						if joueur[4]:IsUnitState('Attached') then
							Warp(joueur[4]:GetParent(),{(65 + decalageDeCouloir),150,20,0,0,0})
							if joueur[2] != 0 then
								PrintText(GetArmyBrain(army).Nickname..languageText[language]["cheat1"], 20, 'ffff8800', 10, 'center')
							else
								PrintText(GetArmyBrain(army).Nickname..languageText[language]["cheat3"], 20, 'ffff8800', 10, 'center')
								WaitSeconds( 0.5 )
								joueur[4]:Kill()
							end
						else
							Warp(joueur[4],{(65 + decalageDeCouloir),150,20,0,0,0})
							if joueur[2] != 0 then
								PrintText(GetArmyBrain(army).Nickname..languageText[language]["cheat2"], 20, 'ffff8800', 10, 'center')
							else
								PrintText(GetArmyBrain(army).Nickname..languageText[language]["cheat3"], 20, 'ffff8800', 10, 'center')
								WaitSeconds( 0.5 )

								joueur[4]:Kill()
							end
						end
					end
					for i,lau in launcherTable do --LANCEMENT D'UNE VAGUE
						if lau[2]~=nil and not IsDestroyed(lau[2])  then
							if lau[1]==army then
								posx = lau[2]:GetPosition()[1]
								posy = lau[2]:GetPosition()[3]
								if posx > (origineXJoueur - 2) and posx < (origineXJoueur + 2) and posy > 517.5 and posy < 524 then --Bonne position
									local wave = getWaveByArmy(army)

									if (wave.next-1)!=table.getn(vague_unite) then --SI ce n'est pas la derniere vague
										wave.next = wave.next + 1

										--Pour chacun des joueurs de l'�quipe
										for indexLau, valueLau in launcherTable do
											if(sameTeam(army, valueLau[1]))then
												if not IsDestroyed(valueLau[2]) and valueLau[2]~= nil then
													Warp(valueLau[2],{(getOrigineXOfArmy(valueLau[1])), 156.055, 529.5,0,0,0})
													--valueLau[2]:Kill()
													--valueLau[2] = CreateUnitHPR("uel0101",valueLau[1], getOrigineXOfArmy(valueLau[1]), 156.055, 529.5,0,0,0) --Cr�ation du launcher
													valueLau[3]:Stop()
													if wave.next-1==table.getn(vague_unite) then
														valueLau[2]:SetCustomName(languageText[language]["unitname2"]);
													else
														valueLau[2]:SetCustomName(languageText[language]["unitname3"]..wave.next.."/"..table.getn(vague_unite));
													end
												end
											end
										end

										local aliasStr = ""
										local plusieurs = false
										for teamIndex, team in teamTable do
											for armyIndex, armyName in team.team do
												if(sameTeam(army, armyName))then
													alias = string.lower(GetArmyBrain(armyName).Nickname)
													if string.find(alias,"1664") then
														alias = "1664 ou sa soeur"
													end
													if string.find(alias,"kuon") then
														alias = "Kuon le gros connard"
													end
													if string.find(alias,"remuald") then
														alias = "Remuald la tortue"
													end
													if(string.len(aliasStr)>0)then
														aliasStr = aliasStr.." + "
														plusieurs = true
													end
													aliasStr = aliasStr..alias
												end
											end
										end
										if(plusieurs)then
											PrintText(aliasStr..languageText[language]["launch1"]..(wave.next - 1).."/"..table.getn(vague_unite), 20, 'ffff8800', 10, 'leftcenter')
										else
											PrintText(aliasStr..languageText[language]["launch2"]..(wave.next - 1).."/"..table.getn(vague_unite), 20, 'ffff8800', 10, 'leftcenter')
										end
										for l,lauBase in launcherBaseTable do --On cherche la base pour lui changer son nom
											if not IsDestroyed(lauBase[2]) and lauBase[2]~= nil then
												if(sameTeam(lauBase[1],army)) then
													spawnEffect(lauBase[2]);
													vaincue = 0
													if(wave.next - 1)==1 then --On regarde si le joueur lance la premiere vague, si c'est le cas on renome la base
														lauBase[2]:SetCustomName(languageText[language]["basename2"].."0/"..table.getn(vague_unite));
													end
												end
											end
										end
										lancerAttaque(army)
									end
								else
									if posx < (origineXJoueur - 2) or posx > (origineXJoueur + 2) or posy < 517.5 or posy > 532.5 then --Toujours dans le carr� ?
										Warp(lau[2],{(origineXJoueur), 156.055, 529.5,0,0,0})
									end
								end
							end
						end
					end
				end
			end
			--Vague de tourelles
			for i, aTurret in turretGonzalesTable do
				if not IsDestroyed(aTurret) then
					turretPosX = aTurret:GetPosition()[1]
					turretPosZ = aTurret:GetPosition()[3]

					Warp(aTurret,{(turretPosX), 119.48, (turretPosZ+1),0,0,0})
					if(turretPosZ>490)then
						aTurret:Kill()
					end
				end
			end

			local unitAtBottom = GetUnitsInRect({x0 = 0, x1 = 1024, y0 = 500, y1 = 1024})

			if(unitAtBottom~=nil)then
				for i,unit in unitAtBottom do --On r�cup toutes les unit�s dans la zone du joueur
					if indexToArmy(unit:GetArmy()) != "ARMY_SURVIVAL_ENEMY_"..getEnemyOfArmy(army) then
						bp = unit:GetBlueprint()
						if(not isACU(bp.BlueprintId))then
							if EntityCategoryContains(categories.LAND,unit) and not unit:IsUnitState('Attached')then --Si c'est un drone ou une unit� au sol
								unit:Kill()
							end
						end
					end
				end
			end

			SecondLeftUnitProtection = SecondLeftUnitProtection - 1
			if(SecondLeftUnitProtection==0)then
				for couloirCourant = 1, 8, 1 do
					decalage = (couloirCourant - 1)*128
					local zoneCouloir = {x0 = (2+decalage), x1 = (126+decalage), y0 = 0, y1 = 600}
					local unitsInRect = GetUnitsInRect(zoneCouloir)

					if(unitsInRect~=nil)then --Si on a au moins une unit� dans la zone

						for i,unit in unitsInRect do --On r�cup toutes les unit�s dans la zone du joueur
							if(unit.OldOnDamage==nil)then
								unit.OldOnDamage = unit.OnDamage
								unit.OnDamage = unit_damage
							end
						end

						for teamIndex, team in teamTable do
							if(team.couloir~=tostring(couloirCourant))then
								--On r�cup le premier joueur de la team, si l'army n'est pas alli�e � ce premier joueur alors on d�truit toutes les unit�s au sol
								local firstArmy = team.team[1]

								for i,unit in unitsInRect do --On r�cup toutes les unit�s dans la zone du joueur
									if( sameTeam(indexToArmy(unit:GetArmy()), firstArmy)) then --Si les unit�s ne sont pas � cette �quipe
										if indexToArmy(unit:GetArmy()) != "ARMY_SURVIVAL_ENEMY_"..getEnemyOfArmy(army) then
											bp = unit:GetBlueprint()
											if(not isACU(bp.BlueprintId))then
												if EntityCategoryContains(categories.LAND,unit) or bp.BlueprintId=="uea0001" or bp.BlueprintId=="uea0003" or bp.BlueprintId=="xea3204" then --Si c'est un drone ou une unit� au sol
													unit:Kill()
												end
											end
										end
									end
								end
							end
						end
					end
					SecondLeftUnitProtection = 5
				end
			end
		end
	end)
end

lancerAttaque = function(army)
		vagueALancer = 1

		local wave = getWaveByArmy(army)
		vagueALancer = wave.next-1
		if vagueALancer==26 then --On lance une arm�e de tourelle
			turretGonzales(army)
		end
		spawnwave(vague_unite[vagueALancer], vague_nombre[vagueALancer], army, vagueALancer, false)
end



spawnwave = function(spawnTable, multiplicateurTable, army, vagueALancer, propagation)
		platoonUnits = spawnPlatton(spawnTable, multiplicateurTable, army, propagation)
		if propagation and table.getn(platoonUnits)==0 then
			return false
		end
		local wave = getWaveByArmy(army)
		attackPlatoon = startAttackMove(platoonUnits, army);
		if not propagation then
			tab = {vagueALancer, attackPlatoon}
			table.insert(wave.list,tab)
		else
			table.insert(wave.propagation,attackPlatoon)
		end
end

spawnPlatton = function(spawnTable, multiplicateurTable, army, propagation)
	number = getCouloirOfArmy(army)
	decalage = (number-1)*128
  -- cr�ation d'un platoon pour r�cup�rer l'arm�e g�n�r�e
  local platoonUnits = {};
  -- on parcour autant de fois que n�cessaire selon le multiplicateur choisit dans le lobby
	total = 1
	if(ScenarioInfo.Options.opt_nombre!=nil) then
		total = ScenarioInfo.Options.opt_nombre
	end


	local typeEquilibrage = 1
	if(ScenarioInfo.Options.opt_multiplicateur!=nil)then
		typeEquilibrage = ScenarioInfo.Options.opt_multiplicateur
	end
	if(typeEquilibrage==3)then
		--On cherche l'�quipe ciblee et on multiplie le nombre d'unit� lanc�es de la vague par le nombre de joueurs dans l'�quipe
		local teamFound = false
		for teamIndex, teamData in teamTable do
			for playerIndex, playerArmy in teamData.team do
				if (playerArmy==army)then
					total = total * table.getn(teamData.team)
					break
				end
			end
			if(teamFound)then
				break
			end
		end
	end


	invers = false --quand c'est vrai on inverse la posx du prochaine spawn sinon on �carte la pos
	posx = 64
	finalx = 0
	ecartementx = 0
	posy = 10

	courant = 0 --Pour la propagation
	inc = 50
	if(ScenarioInfo.Options.opt_propagation!=nil) then
		inc = ScenarioInfo.Options.opt_propagation
	end

	for i=1,total do --Mutliplicateur du lobby
		for index, bp in spawnTable do --Pour chaque bp
			for j=1,multiplicateurTable[index] do --Multiplicateur du bp
				if not propagation or (propagation and courant>=100) then
					if invers then
						finalx = posx - ecartementx
						invers = false
					else
						finalx = posx + ecartementx
						ecartementx = ecartementx + 2
						invers = true
					end
					pos = {(finalx+decalage),119.5,posy,0,0,0}
					doSpawnUnit(bp, pos, platoonUnits,army);
					if ecartementx > 37 then
						ecartementx = 0
						posy = posy +2
					end
					courant = 0
				end
				if propagation and courant<100 then
					courant = courant + inc
				end
			end
		end
	end
  return platoonUnits
end

-- does the actual spawning of a unit
doSpawnUnit = function(bp, pos, platoon,army)
	armyNumber = getEnemyOfArmy(army)
	-- spawn unit
	local unit = CreateUnitHPR( bp, "ARMY_SURVIVAL_ENEMY_"..armyNumber, pos[1], pos[2], pos[3], 0,0,0);
	if (unit == nil) then
		return;
	end

	local bp = unit:GetBlueprint();

	local HealthBuff = 1
	if(ScenarioInfo.Options.opt_solidite!=nil) then
		HealthBuff = ScenarioInfo.Options.opt_solidite
	end


	local typeEquilibrage = 1
	if(ScenarioInfo.Options.opt_multiplicateur!=nil)then
		typeEquilibrage = ScenarioInfo.Options.opt_multiplicateur
	end
	if(typeEquilibrage==2)then
		--On cherche l'�quipe ciblee et on multiplie la vie des unit�s lanc�es de la vague par le nombre de joueurs dans l'�quipe
		local teamFound = false
		for teamIndex, teamData in teamTable do
			for playerIndex, playerArmy in teamData.team do
				if (playerArmy==army)then
					HealthBuff = HealthBuff * table.getn(teamData.team)
					break
				end
			end
			if(teamFound)then
				break
			end
		end
	end



	--rajout de la vie
	unit:SetMaxHealth(unit:GetHealth() * HealthBuff);
	unit:SetHealth(nil, unit:GetHealth() * HealthBuff);
	table.insert(platoon, unit)
end

startAttackMove = function(units, army)
	number = getCouloirOfArmy(army)
	decalage = (number-1)*128
	attackPlatoon = ""
	if (table.getn(units) > 0) then
		local aiBrain = GetArmyBrain("ARMY_SURVIVAL_ENEMY_"..number);
		attackPlatoon = aiBrain:MakePlatoon('','');
		aiBrain:AssignUnitsToPlatoon(attackPlatoon, units, 'Attack', "AttackFormationd");


		--Bon d�placement des unit�s :
		attackPlatoon:AggressiveMoveToLocation(ScenarioUtils.MarkerToPosition("Pos_joueur_"..number)) --On dit de tout p�ter sur le passage en allant tout droit en bas
		for i,joueur in joueurTable do
			if sameTeam(joueur[1],army) then
				attackPlatoon:AggressiveMoveToLocation(joueur[4]:GetPosition()); --On dit ensuite de continuer la route vers les commanders de la team
			end
		end
	end
	return attackPlatoon
end

refreshPlatoon = function() --Fonction qui donne un nouvel ordre � chaque platoon qui ne fait rien
	ForkThread(function()
		while(true)do
			WaitSeconds(5)

			for teamNumber, teamData in teamTable do --Pour chacunes des teams
				if(not isDeadTeam(teamData.team[1]))then
					local wave  = teamData.wave
					--GESTION DES PLATOON DE VAGUE
					listPlatoon = wave.list
					for num_platton, platoon in listPlatoon do --Pour chacun des platoon restant de l'�quipe
						if type(platoon)=="table" then --On v�rifie que c'est bien un platoon
							units = platoon[2]:GetPlatoonUnits()
							if(table.getn(units)==0)then --Si le platoon est vide on le supprime
								local strListNom = ""
								for joueurNumber, joueurArmy in teamData.team do
									if(joueurNumber>1)then
										strListNom = strListNom.." + "
									end
									strListNom = strListNom..GetArmyBrain(joueurArmy).Nickname
								end
								if(table.getn(teamData.team)>1)then
									PrintText(strListNom..languageText[language]["destroy1"]..platoon[1], 15, 'ffff0000', 10, 'leftcenter')
								else
									PrintText(strListNom..languageText[language]["destroy2"]..platoon[1], 15, 'ffff0000', 10, 'leftcenter')
								end

								numVague = platoon[1]
								listPlatoon[num_platton] = numVague
								doVictoire(teamData.team[1])
								for ind, base in launcherBaseTable do --On renome la base pour afficher le nombre de vagues termin�es
									if base[2]~=nil and not IsDestroyed(base[2]) then
										if sameTeam(base[1],teamData.team[1]) then
											totalDetruit = 0
											for indP, plaTmp in listPlatoon do
												if type(plaTmp)=="number" then
													totalDetruit = totalDetruit + 1
												end
											end
											base[2]:SetCustomName(languageText[language]["basename2"]..totalDetruit.."/"..table.getn(vague_unite));


											--Lancement des vagues de propagation
											if(ScenarioInfo.Options.opt_propagation!=nil) then
												total = ScenarioInfo.Options.opt_propagation
											end


											for ti, td in teamTable do --On va spawnner des vagues dans les �quipes vivantes adverses
												if(not sameTeam(td.team[1], teamData.team[1]) and not isDeadTeam(td.team[1]))then
													spawnwave(vague_unite[numVague], vague_nombre[numVague], td.team[1], nil, true)
												end
											end
										end
									end
								end
							else --Si le platoon ne se d�place pas ou n'attaque pas alors on lui donne un nouvel ordre
								if(not platoonOccupe(platoon[2]))then
									for jti,jt in joueurTable do
										if sameTeam(jt[1],teamData.team[1]) and not jt[3] then
											platoon[2]:AggressiveMoveToLocation(jt[4]:GetPosition());
										end
									end
								end
							end
						end
					end
					--GESTION DES PLATOON PROPAG�S
					local listPlatoonPropagation = wave.propagation
					offset = 0
					if(listPlatoonPropagation ~= nil)then
						for num_platton, platoon in listPlatoonPropagation do --Pour chacun des platoon des vagues propag�es
							units = listPlatoonPropagation[num_platton-offset]:GetPlatoonUnits()
							if(table.getn(units)==0)then --Si le platoon est vide on le supprime
								table.remove(listPlatoonPropagation,(num_platton-offset))
								offset = offset + 1
								doVictoire(teamData.team[1])
							else --Si le platoon ne se d�place pas ou n'attaque pas alors on lui donne un nouvel ordre
								if(not platoonOccupe(listPlatoonPropagation[num_platton-offset]))then
									for jti,jt in joueurTable do
										if (sameTeam(jt[1],teamData.team[1]) and not jt[3] ) then
											listPlatoonPropagation[num_platton-offset]:AggressiveMoveToLocation(jt[4]:GetPosition());
										end
									end
								end
							end
						end
					end
				end
			end
		end
	end)
end

platoonOccupe = function(platoon)

	local units = platoon:GetPlatoonUnits()
	local nbUnitOccupe = 0
	for i, unit in units do --Pour chaque unit� du platoon :
		if(not unit:IsDead())then
			if(unit:IsMoving() or (unit:GetWeaponCount() > 0 and unit:GetWeapon(1):GetCurrentTarget() or unit:GetWeaponCount() == 0)) then
				nbUnitOccupe = nbUnitOccupe + 1
			end
		end
	end

	if(nbUnitOccupe < (table.getn(units)/3))then
		return false
	else
		return true
	end
end


isVictoire = function(army)
	wave = getWaveByArmy(army)
	waveList = wave.list;

	if table.getn(waveList)!=table.getn(vague_unite) then --Aucune vague d�truite ?
		return false
	end

	for i, platoon in waveList do --Au moins une vague restante ?
		if type(platoon)=="table" then
			return false
		end
	end



	--[[
	if table.getn(joueur[4])!=0 then --Au moins quelques unit�s de vague de propagation restantes ?
		return false
	end
	]]
	return true
end

doVictoire = function(army)
	if isVictoire(army) then
		place = numeroGagnant
		numeroGagnant = numeroGagnant + 1
		if place==1 then
			place = place..languageText[language]["position1"]
		else
			if place==maxPerdant then
				place = languageText[language]["position2"]
			else
				place = place..languageText[language]["position3"]
			end
		end

		for i=1,8,1 do
			if(sameTeam("ARMY_"..i, army))then
				PrintText(place.." : "..GetArmyBrain("ARMY_"..i).Nickname.."                     ", 15, 'ff00ff00', 360000, 'rightcenter')
				PrintText(GetArmyBrain("ARMY_"..i).Nickname..languageText[language]["position4"]..place, 25, 'ff00ff00', 8, 'center')
			end
		end


		for teamIndex, team in teamTable do
			for armyIndex, armyName in team.team do
				if( sameTeam(army, armyName) )then
					for i,com in joueurTable do
						if com[1] == armyName then
							com[4]:Kill()
						end
					end
				end
			end
		end
	end
end

doDefaite = function(army)
	if not isVictoire(army) then
		place = numeroPerdant
		numeroPerdant = numeroPerdant - 1
		if place==maxPerdant then
			place = languageText[language]["position2"]
		else
			if place==1 then
				place = place..languageText[language]["position1"]
			else
				place = place..languageText[language]["position3"]
			end
		end

		for i=1,8,1 do
			if(sameTeam("ARMY_"..i, army))then
				PrintText(place.." : "..GetArmyBrain("ARMY_"..i).Nickname.."                     ", 15, 'ff00ff00', 360000, 'rightcenter')
				PrintText(GetArmyBrain("ARMY_"..i).Nickname..languageText[language]["position4"]..place, 25, 'ff00ff00', 8, 'center')
			end
		end
	end
	return true
end

turretGonzales = function(army)
	ForkThread(function()
		local number = getEnemyOfArmy(army)
		local decalage = (getCouloirOfArmy(army)-1)*128
		local joueurTotal = 0
		for i, team in teamTable do
			if(sameTeam(team.team[1], army))then
				joueurTotal = table.getn(team.team)
			end
		end

		WaitSeconds(120)

		for i=1,joueurTotal,1 do
			for i=24,104,2 do
				local unit = CreateUnitHPR( "ueb2101", "ARMY_SURVIVAL_ENEMY_"..number, (i+decalage), 119.48, 1, 0,0,0);
				table.insert(turretGonzalesTable, unit)
			end

			WaitSeconds(10)
			for i=24,104,2 do
				local unit = CreateUnitHPR( "ueb2104", "ARMY_SURVIVAL_ENEMY_"..number, (i+decalage), 119.48, 1, 0,0,0);
				table.insert(turretGonzalesTable, unit)
			end

			WaitSeconds(10)
			for i=24,104,2 do
				local unit = CreateUnitHPR( "ueb2204", "ARMY_SURVIVAL_ENEMY_"..number, (i+decalage), 119.48, 1, 0,0,0);
				table.insert(turretGonzalesTable, unit)
			end

			WaitSeconds(10)
			for i=24,104,2 do
				local unit = CreateUnitHPR( "ueb2301", "ARMY_SURVIVAL_ENEMY_"..number, (i+decalage), 119.48, 1, 0,0,0);
				table.insert(turretGonzalesTable, unit)
			end

			WaitSeconds(10)
			for i=24,104,2 do
				local unit = CreateUnitHPR( "xeb2306", "ARMY_SURVIVAL_ENEMY_"..number, (i+decalage), 119.48, 1, 0,0,0);
				table.insert(turretGonzalesTable, unit)
			end

			WaitSeconds(10)
			for i=24,104,2 do
				local unit = CreateUnitHPR( "ueb2304", "ARMY_SURVIVAL_ENEMY_"..number, (i+decalage), 119.48, 1, 0,0,0);
				table.insert(turretGonzalesTable, unit)
			end
		end
	end)
end


function GenerateResourcesMarker(x, y)
	marker =
	{
		['Mass '..(100 + currentMassSpot)] =
		{
			['type'] = STRING( 'Mass' ),
			['position'] = VECTOR3( x, 119.4844, y ),
			['orientation'] = VECTOR3( 0.00, 0.00, 0.00 ),
			['size'] = FLOAT( 1.00 ),
			['resource'] = BOOLEAN( true ),
			['amount'] = FLOAT( 100.00 ),
			['color'] = STRING( 'ff808080' ),
			['editorIcon'] = STRING( '/textures/editor/marker_mass.bmp' ),
			['prop'] = STRING( '/env/common/props/markers/M_Mass_prop.bp' ),
		},
	}
	currentMassSpot = currentMassSpot + 1
	CreateResources(marker)
end


function GenerateGasResourcesMarker(x)
	marker =
	{
		['Hydrocarbon '..(100 + currentMassSpot)] =
		{
          ['type'] = STRING( 'Hydrocarbon' ),
          ['position'] = VECTOR3( x, 119.4844, 462.50 ),
          ['orientation'] = VECTOR3( 0.00, 0.00, 0.00 ),
          ['size'] = FLOAT( 3.00 ),
          ['amount'] = FLOAT( 100.00 ),
          ['color'] = STRING( 'ff008000' ),
          ['resource'] = BOOLEAN( true ),
          ['prop'] = STRING( '/env/common/props/markers/M_Hydrocarbon_prop.bp' ),
    },
	}
	currentMassSpot = currentMassSpot + 1
	CreateResources(marker)
end



function CreateResources(markers)
    --local markers = GetMarkers()

    for i, tblData in pairs(markers) do
        if tblData.resource then
            CreateResourceDeposit(
                tblData.type,
                tblData.position[1], tblData.position[2], tblData.position[3],
                tblData.size
            )

            # fixme: texture names should come from editor
            local albedo, sx, sz, lod
            if tblData.type == "Mass" then
                albedo = "/env/common/splats/mass_marker.dds"
                sx = 2
                sz = 2
                lod = 100
                CreatePropHPR(
                    '/env/common/props/massDeposit01_prop.bp',
                    tblData.position[1], tblData.position[2], tblData.position[3],
                    Random(0,360), 0, 0
                )
            else
                albedo = "/env/common/splats/hydrocarbon_marker.dds"
                sx = 6
                sz = 6
                lod = 200
                CreatePropHPR(
                    '/env/common/props/hydrocarbonDeposit01_prop.bp',
                    tblData.position[1], tblData.position[2], tblData.position[3],
                    Random(0,360), 0, 0
                )
            end
            # Decal - (position, heading, textureName1, textureName2, type, sizeX, sizeZ, lodParam, duration, army)
            # Splat - (position, heading, textureName1, textureName2, type, sizeX, sizeZ, lodParam, duration, army)
#            if not ScenarioInfo.MapData.Decals then
#                ScenarioInfo.MapData.Decals = {}
#            end
#            table.insert( ScenarioInfo.MapData.Decals, CreateDecal(
#                tblData.position, # position
#                0, # heading
#                albedo, "", # TEX1, TEX2
#                "Albedo", # TYPE
#                sx, sz, # SIZE
#                lod, # LOD
#                0, # DURACTION
#                -1 # ARMY
#            ) )
            CreateSplat(
                tblData.position,           # Position
                0,                          # Heading (rotation)
                albedo,                     # Texture name for albedo
                sx, sz,                     # SizeX/Z
                lod,                        # LOD
                0,                          # Duration (0 == does not expire)
                -1 ,                         # army (-1 == not owned by any single army)
                0
            )
        end
    end
end

function getCouloirOfArmy(army)
	for i, team in teamTable do
		for j, teamArmy in team.team do
			if (teamArmy==army)then
				return tonumber(team.couloir)
			end
		end
	end
	return 1
end

function getEnemyOfArmy(army)
	for i, team in teamTable do
		for j, teamArmy in team.team do
			if (teamArmy==army)then
				return tonumber(team.enemy)
			end
		end
	end
	return 1
end

function getOrigineXOfArmy(army)
	for i, team in teamTable do
		for j, teamArmy in team.team do
			if (teamArmy==army)then
				return tonumber(team.origineX[j])
			end
		end
	end
	return 1
end

function sameTeam(army1, army2)
	for i, team in teamTable do
		army1Found = false
		army2Found = false
		for j, teamArmy in team.team do
			if(army1 == teamArmy)then
				army1Found = true
			end
			if(army2 == teamArmy)then
				army2Found = true
			end
		end
		if(army1Found and army2Found)then --Les 2 joueurs on �t� trouv� dans cette �quipe
			return true
		end
		if(army1Found or army2Found)then --Un des joueur a �t� trouv� dans cette �quipe
			return false
		end
	end

end

function getArmySurvivalVersusAPlayer( army )
	for i, team in teamTable do
		for playerIndex, playerArmy in team.team do
			if( playerArmy==army )then
				return "ARMY_SURVIVAL_ENEMY_"..team.enemy
			end
		end
	end
end

function getWaveByArmy( army )
	for i, team in teamTable do
		for playerIndex, playerArmy in team.team do
			if( playerArmy==army )then
				return team.wave
			end
		end
	end
end

function isDeadTeam( army )
 for teamIndex, teamData in teamTable do
	for playerIndex, playerArmy  in teamData.team do
		if(playerArmy==army)then  --On a trouv� la bonne �quipe
			local totalPlayerInTeam = table.getn(teamData.team)
			local totalDeadInTeam = 0
			for i,j in teamData.team do
				for joueurTableIndex, joueurTableData in joueurTable do
					if(joueurTableData[1]==j and joueurTableData[3])then --Ce joueur est mort
						totalDeadInTeam = totalDeadInTeam + 1
					end
				end
			end
			if(totalDeadInTeam==totalPlayerInTeam)then
				return true
			end
		end
	end
 end
 return false
end

function isACU( bpId )
  --Blackops ACU compatibility
	if(bpId=="ual0001" or bpId=="uel0001" or bpId=="url0001" or bpId=="xsl0001" or bpId=="eal0001" or bpId=="eel0001" or bpId=="erl0001" or bpId=="esl0001") then
		return true
	else
		return false
	end
end


local r = 0
local g = 100
local b = 200
local rb = true
local gb = true
local bb = true

local index = 0

changeColor = function()
	ForkThread(function()
		while true do
			WaitSeconds(0.04)
			for i=1,8 do
				if rb then
					r = r + 2
				else
					r = r - 2
				end
				if gb then
					g = g + 1
				else
					g = g - 1
				end
				if bb then
					b = b + 3
				else
					b = b - 3
				end
				if r > 252 then
					rb = false
				end
				if r < 3 then
					rb = true
				end
				if g > 252 then
					gb = false
				end
				if g < 3 then
					gb = true
				end
				if b > 252 then
					bb = false
				end
				if b < 3 then
					bb = true
				end
				if i==1 then
					SetArmyColor("ARMY_SURVIVAL_ENEMY_"..i,r,g,b)
				end
				if i==2 then
					SetArmyColor("ARMY_SURVIVAL_ENEMY_"..i,b,r,g)
				end
				if i==3 then
					SetArmyColor("ARMY_SURVIVAL_ENEMY_"..i,g,b,r)
				end
				if i==4 then
					SetArmyColor("ARMY_SURVIVAL_ENEMY_"..i,b,g,r)
				end
				if i==5 then
					SetArmyColor("ARMY_SURVIVAL_ENEMY_"..i,g,r,b)
				end
				if i==6 then
					SetArmyColor("ARMY_SURVIVAL_ENEMY_"..i,r,b,g)
				end
				if i==7 then
					SetArmyColor("ARMY_SURVIVAL_ENEMY_"..i,255-g,b,r)
				end
				if i==8 then
					SetArmyColor("ARMY_SURVIVAL_ENEMY_"..i,b,255-g,r)
				end
			end

		end
	end)
end

indexToArmy = function(armyIndex)
   local army = ListArmies()[armyIndex]
   return army
end