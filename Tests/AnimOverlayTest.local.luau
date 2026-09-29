--!strict
--@author: yyumchi
--@date: 2026-09-28
--[[@description:
	Overlay layer via signals: an arms-only profile layers over the core
	locomotion at the priority you ask for, and clearing it stops it. Always
	pass Priority explicitly; the default comes from Config.DefaultOverlayPriority.
	Leaves the overlay ON so you can walk with WASD and eyeball arms vs legs.
]]

-----------------------------
-- DEPENDENCIES --
-----------------------------

local AnimSignals = require("../Libraries/AnimSignals")
local TestKit = require("./TestKit")

-----------------------------
-- VARIABLES --
-----------------------------

local TAG = "OverlayTest"
local ARMS_ID = TestKit.Ids.Arms

local runToken = 0

-----------------------------
-- HANDLERS --
-----------------------------

local function run()
	runToken += 1
	local myRun = runToken
	if TestKit.getDebug() == nil then
		warn(`[{TAG}] FAIL service never ready`)
		return
	end
	if myRun ~= runToken then
		return
	end
	AnimSignals.LoadOverlay:Fire({
		Profile = "TestArms",
		Definition = { Idle = ARMS_ID, Walk = ARMS_ID, Run = ARMS_ID, Jump = ARMS_ID, Fall = ARMS_ID },
		SetActive = true,
		Priority = Enum.AnimationPriority.Action,
	})
	local overlay = TestKit.waitTrack(ARMS_ID, 10)
	TestKit.check(TAG, "overlay layers over core", overlay ~= nil, ARMS_ID)
	if overlay then
		TestKit.check(TAG, "overlay sits at the requested Action", overlay.Priority == Enum.AnimationPriority.Action, overlay.Priority.Name)
	end
	AnimSignals.SetOverlayProfile:Fire({ Profile = nil })
	task.wait(0.6)
	local after = TestKit.findTrack(ARMS_ID)
	TestKit.check(TAG, "clearing the overlay stops the arms", after == nil or not after.IsPlaying, ARMS_ID)
	AnimSignals.SetOverlayProfile:Fire({ Profile = "TestArms", Priority = Enum.AnimationPriority.Action })
	local looped = TestKit.waitTrack(ARMS_ID, 10)
	TestKit.check(TAG, "overlay re-armed by name", looped ~= nil, ARMS_ID)
	print(`[{TAG}] done: OVERLAY LEFT ON -- walk with WASD, arms stay in the hold while legs walk`)
end

-----------------------------
-- MAIN --
-----------------------------

TestKit.onEverySpawn(run, 2.5)
