--@author: yyumchi
--@date: 2026-09-26
--[[@description:
	Proves stashed tracks die with the character while content stays cached,
	then demos a hands-only clip over walking legs at Action vs Core.
	Reset your character when told. The clip is TestKit.Ids.Arms; swap it for your own hands clip.
]]

-----------------------------
-- SERVICES --
-----------------------------

local Players = game:GetService("Players")

-----------------------------
-- DEPENDENCIES --
-----------------------------

local AnimSignals = require(script.Parent.Parent.Libraries.AnimSignals)
local TestKit = require(script.Parent.TestKit)

-----------------------------
-- VARIABLES --
-----------------------------

local LocalPlayer = Players.LocalPlayer

local BLOCK_ID = TestKit.Ids.Arms

local phase: string = "stash"
local stashed: AnimationTrack? = nil

-----------------------------
-- PRIVATE FUNCTIONS --
-----------------------------

local function getReady(): any
	for _ = 1, 300 do
		local fn = rawget(_G :: any, "__AnimateServiceDebug")
		if typeof(fn) == "function" then
			local ok, res = pcall(fn)
			if ok and typeof(res) == "table" and res.alive == true then
				return res
			end
		end
		task.wait(0.1)
	end
	return nil
end

local function stashRaw(): AnimationTrack?
	local character = LocalPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		return nil
	end
	local anim = Instance.new("Animation")
	anim.AnimationId = BLOCK_ID
	local track = animator:LoadAnimation(anim)
	anim:Destroy()
	return track
end

local function demoPartial()
	print("[PartialTest] ACTION priority: clip looped, WALK WITH WASD, legs should keep walking (8s)")
	AnimSignals.PlayCategoryTrack:Fire("Block", BLOCK_ID, { AutoPlay = true, FadeTime = 0.15, Looped = true, Priority = Enum.AnimationPriority.Action })
	task.wait(8.0)
	AnimSignals.StopCategoryTrack:Fire("Block", BLOCK_ID, 0.1)
	task.wait(1.0)
	print("[PartialTest] CORE priority: same clip at locomotion priority, walk again and compare (8s)")
	AnimSignals.PlayCategoryTrack:Fire("Block", BLOCK_ID, { AutoPlay = true, FadeTime = 0.15, Looped = true, Priority = Enum.AnimationPriority.Core })
	task.wait(8.0)
	AnimSignals.StopCategoryTrack:Fire("Block", BLOCK_ID, 0.1)
	print("[PartialTest] done: hands-only works at Action, not at Core")
end

-----------------------------
-- HANDLERS --
-----------------------------

local function onSpawned()
	if phase == "done" then
		return
	end
	if getReady() == nil then
		warn("[PartialTest] FAIL service never ready")
		return
	end
	if phase == "stash" then
		stashed = stashRaw()
		phase = "awaiting"
		print("[PartialTest] track stashed. NOW DIE (Esc > Reset Character)")
		return
	end
	if phase == "awaiting" then
		phase = "done"
		local old = stashed
		stashed = nil
		if old == nil then
			print("[PartialTest] no stashed ref, skipping death check")
		else
			local alive = (old :: Instance).Parent ~= nil
			local playOk = pcall(function()
				old:Play(0.1)
			end)
			print(`[PartialTest] CONFIRMED old track dead after respawn: parentNil={tostring(not alive)} replayOk={tostring(playOk)}`)
		end
		local t0 = os.clock()
		AnimSignals.PlayCategoryTrack:Fire("Single", BLOCK_ID, { AutoPlay = true, FadeTime = 0.1 })
		local ms = (os.clock() - t0) * 1000
		print(`[PartialTest] same id dispatches in {string.format("%.1f", ms)}ms after respawn (content cached, only the track is new)`)
		task.wait(1.5)
		AnimSignals.StopCategoryTrack:Fire("Single", BLOCK_ID, 0.05)
		demoPartial()
	end
end

-----------------------------
-- MAIN --
-----------------------------

if LocalPlayer.Character then
	task.spawn(function()
		if getReady() == nil then
			return
		end
		stashed = stashRaw()
		phase = "awaiting"
		print("[PartialTest] stashed. NOW DIE (Esc > Reset Character)")
	end)
end
LocalPlayer.CharacterAdded:Connect(function()
	task.delay(2.0, onSpawned)
end)
