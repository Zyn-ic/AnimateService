--!strict
--@author: yyumchi
--@date: 2026-09-28
--[[@description:
	Module mode: drives the service by requiring it, no signals fired. Covers
	readiness, PlayCategory autoplay, reuse, StopCategory, OneOff unload, static
	Preload, and that a profile loaded directly plus OnRigReady both survive a
	respawn. Kills the character near the end, so run it alone. Runs once.
]]

-----------------------------
-- SERVICES --
-----------------------------

local Players = game:GetService("Players")

-----------------------------
-- DEPENDENCIES --
-----------------------------

local AnimateService = require("../Module/AnimateService")
local TestKit = require("./TestKit")

-----------------------------
-- VARIABLES --
-----------------------------

local TAG = "ModuleTest"
local LocalPlayer = Players.LocalPlayer
local A = TestKit.Ids.ProbeA
local B = TestKit.Ids.ProbeB
local RUN = TestKit.Ids.Run

local didRun = false

-----------------------------
-- PRIVATE FUNCTIONS --
-----------------------------

local function clean(id: string): string
	return (id:gsub("rbxassetid://", ""))
end

local function waitForNewRig(old: AnimateService.Rig): AnimateService.Rig?
	for _ = 1, 100 do
		local current = AnimateService:GetRig()
		if current and not rawequal(current, old) then
			return current
		end
		task.wait(0.2)
	end
	return nil
end

-----------------------------
-- HANDLERS --
-----------------------------

local function run()
	if didRun then
		return
	end
	didRun = true
	local rig = AnimateService:WaitForRig(20)
	TestKit.check(TAG, "WaitForRig returns a rig", rig ~= nil)
	if not rig then
		return
	end
	TestKit.check(TAG, "IsReady", AnimateService:IsReady())

	local readyCount = 0
	AnimateService:OnRigReady(function()
		readyCount += 1
	end)
	task.wait(0.1)
	TestKit.check(TAG, "OnRigReady fires at once when a rig exists", readyCount == 1, `count={readyCount}`)

	local track = AnimateService:PlayCategory("Single", A, { FadeTime = 0.05, Priority = Enum.AnimationPriority.Action2 })
	TestKit.check(TAG, "PlayCategory autoplays by default", track ~= nil and track.IsPlaying)
	TestKit.check(TAG, "IsPlaying reports it", AnimateService:IsPlaying("Single", A))
	local loaded = AnimateService:GetLoadedCount()
	AnimateService:PlayCategory("Single", A)
	TestKit.check(TAG, "second PlayCategory reuses the track", AnimateService:GetLoadedCount() == loaded, `{loaded} -> {AnimateService:GetLoadedCount()}`)
	AnimateService:StopCategory("Single", A, 0.05)
	task.wait(0.3)
	TestKit.check(TAG, "StopCategory stops it", not AnimateService:IsPlaying("Single", A))
	TestKit.check(TAG, "kept single stays loaded after stop", AnimateService:GetLoadedList()[clean(A)] ~= nil)

	local loadOnly = AnimateService:PlayCategory("Single", B, { AutoPlay = false })
	TestKit.check(TAG, "AutoPlay=false loads without playing", loadOnly ~= nil and not loadOnly.IsPlaying)

	AnimateService:PlayOneOff(TestKit.Ids.OneShot, { FadeTime = 0.05 })
	local unloaded = false
	for _ = 1, 60 do
		task.wait(0.2)
		if AnimateService:GetLoadedList()[clean(TestKit.Ids.OneShot)] == nil then
			unloaded = true
			break
		end
	end
	TestKit.check(TAG, "PlayOneOff unloads itself", unloaded)

	local preloadOk = pcall(function()
		AnimateService:Preload({ TestKit.Ids.StutterA })
	end)
	TestKit.check(TAG, "Preload needs no rig and does not throw", preloadOk)

	AnimateService:LoadProfile("ModTest", { Idle = RUN, Walk = RUN, Run = RUN }, true)
	TestKit.check(TAG, "LoadProfile activates directly", TestKit.waitTrack(RUN, 10) ~= nil, RUN)
	task.wait(1)
	local humanoid = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.Health = 0
	end
	print(`[{TAG}] killed, waiting for the new rig...`)
	local newRig = waitForNewRig(rig)
	TestKit.check(TAG, "a new rig is built after respawn", newRig ~= nil)
	if newRig then
		TestKit.check(TAG, "profile persisted onto the new rig", newRig:HasProfile("ModTest"))
		TestKit.check(TAG, "persisted profile is the active one", TestKit.waitTrack(RUN, 10) ~= nil, RUN)
		TestKit.check(TAG, "OnRigReady fires again after respawn", readyCount >= 2, `count={readyCount}`)
	end
	print(`[{TAG}] done`)
end

-----------------------------
-- MAIN --
-----------------------------

TestKit.onEverySpawn(run, 2.5)
