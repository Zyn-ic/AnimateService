--!strict
--@author: yyumchi
--@date: 2026-09-28
--[[@description:
	Profile persistence: a core profile loaded at runtime must survive a
	respawn. Loads a profile whose Idle is the run clip, kills the character,
	and expects that clip to be the idle again after the rebuild.
	Runs once per session (didRun survives respawns; this script lives in
	PlayerScripts, the same mechanism under test).
]]

-----------------------------
-- SERVICES --
-----------------------------

local Players = game:GetService("Players")

-----------------------------
-- DEPENDENCIES --
-----------------------------

local AnimSignals = require("../Libraries/AnimSignals")
local TestKit = require("./TestKit")

-----------------------------
-- VARIABLES --
-----------------------------

local TAG = "PersistCheck"
local LocalPlayer = Players.LocalPlayer
local RUN_ID = TestKit.Ids.Run

local didRun = false

-----------------------------
-- HANDLERS --
-----------------------------

local function run()
	if didRun then
		return
	end
	didRun = true
	if TestKit.getDebug() == nil then
		warn(`[{TAG}] FAIL service never ready`)
		return
	end
	task.wait(1)
	AnimSignals.LoadProfile:Fire({
		Profile = "PersistA",
		Definition = { Idle = RUN_ID, Walk = RUN_ID, Run = RUN_ID },
		SetActive = true,
	})
	TestKit.check(TAG, "setup: PersistA active before reset", TestKit.waitTrack(RUN_ID, 10) ~= nil, RUN_ID)
	task.wait(1)
	local humanoid = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.Health = 0
	end
	print(`[{TAG}] killed, waiting for respawn...`)
	LocalPlayer.CharacterAdded:Wait()
	task.wait(5)
	TestKit.check(TAG, "respawn restores the last active profile", TestKit.findTrack(RUN_ID) ~= nil, RUN_ID)
	local info = TestKit.getDebug(20)
	TestKit.check(TAG, "profile was rebuilt on the new rig", info ~= nil and info.profiles >= 1, if info then `profiles={info.profiles}` else "no debug")
	print(`[{TAG}] done`)
end

-----------------------------
-- MAIN --
-----------------------------

TestKit.onEverySpawn(run, 2.5)
