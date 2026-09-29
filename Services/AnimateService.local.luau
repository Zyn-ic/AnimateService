--!strict
--@author: yyumchi
--@date: 2026-09-28
--[[@description:
	Script mode: drop-in replacement for the default Animate script.
	All logic lives in Module/AnimateService. This only starts it.

	Core locomotion comes from Animation objects parented to THIS script
	(R15Animations / R6Animations folders, or stock-style slots), because the
	folder below points the module here. Everything else loads by asset id.
	Needs Module/AnimateService beside Services/, and Libraries/AnimSignals
	for the signal bus (optional if you only call the module directly).
]]

local AnimateService = require("../Module/AnimateService")

AnimateService:Configure({ CoreFolder = script })
AnimateService:Init()
AnimateService:Start()
