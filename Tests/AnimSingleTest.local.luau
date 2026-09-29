--@author: yyumchi
--@date: 2026-09-26
--[[@description:
	Kept Singles persist after stop, OneOffs unload after Ended. If TestKit has
	a MarkerClip, also binds its marker to throw rubble; otherwise that part skips.
]]

-----------------------------
-- SERVICES --
-----------------------------

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

-----------------------------
-- DEPENDENCIES --
-----------------------------

local AnimSignals = require(script.Parent.Parent.Libraries.AnimSignals)
local TestKit = require(script.Parent.TestKit)

-----------------------------
-- VARIABLES --
-----------------------------

local LocalPlayer = Players.LocalPlayer

local HAS_MARKER_CLIP = TestKit.Ids.MarkerClip ~= ""
local SINGLE_ID = TestKit.Ids.ProbeA
local ONEOFF_ID = if HAS_MARKER_CLIP then TestKit.Ids.MarkerClip else TestKit.Ids.OneShot
local ONEOFF_MARKER = TestKit.Ids.MarkerName

local runToken = 0

-----------------------------
-- PRIVATE FUNCTIONS --
-----------------------------

local function getDebug(): any
	for _ = 1, 200 do
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

local function inBin(id: string): boolean
	local info = getDebug()
	if not info or typeof(info.bin) ~= "table" then
		return false
	end
	local clean = (id:gsub("rbxassetid://", ""))
	return info.bin[clean] ~= nil
end

local function check(name: string, cond: boolean, extra: string?)
	if cond then
		print(`[SingleTest] PASS {name}` .. (if extra then ` -- {extra}` else ""))
	else
		warn(`[SingleTest] FAIL {name}` .. (if extra then ` -- {extra}` else ""))
	end
end

local function rubble(at: Vector3)
	for _ = 1, 6 do
		local chunk = Instance.new("Part")
		chunk.Size = Vector3.new(0.6, 0.6, 0.6)
		chunk.Position = at + Vector3.new(math.random(-30, 30) / 10, 1, math.random(-30, 30) / 10)
		chunk.AssemblyLinearVelocity = Vector3.new(math.random(-20, 20), math.random(20, 40), math.random(-20, 20))
		chunk.CanCollide = false
		chunk.Parent = Workspace
		Debris:AddItem(chunk, 1.5)
	end
end

-----------------------------
-- HANDLERS --
-----------------------------

local function run()
	runToken += 1
	local myRun = runToken
	if getDebug() == nil then
		warn("[SingleTest] FAIL service never ready")
		return
	end
	if myRun ~= runToken then
		return
	end
	AnimSignals.PlayCategoryTrack:Fire("Single", SINGLE_ID, { AutoPlay = false })
	task.wait(0.4)
	check("kept single loads into bin", inBin(SINGLE_ID), SINGLE_ID)
	AnimSignals.PlayCategoryTrack:Fire("Single", SINGLE_ID, { AutoPlay = true, FadeTime = 0.1, Priority = Enum.AnimationPriority.Action2 })
	task.wait(1.0)
	AnimSignals.StopCategoryTrack:Fire("Single", SINGLE_ID, 0.05)
	task.wait(0.4)
	check("kept single stays after stop", inBin(SINGLE_ID), SINGLE_ID)
	local hitregFired = false
	AnimSignals.BindMarker:Fire("OneOff", ONEOFF_ID, ONEOFF_MARKER, function()
		hitregFired = true
		print(`[SingleTest] {ONEOFF_MARKER} reached on {ONEOFF_ID}, throwing rubble`)
		local character = LocalPlayer.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			rubble(root.Position)
		end
	end)
	AnimSignals.PlayOneOff:Fire(ONEOFF_ID, { FadeTime = 0.05, Priority = Enum.AnimationPriority.Action3 })
	task.wait(0.1)
	local loadedOnce = inBin(ONEOFF_ID)
	if HAS_MARKER_CLIP then
		for _ = 1, 120 do
			if hitregFired or myRun ~= runToken then
				break
			end
			task.wait(0.1)
		end
		check("marker reached", hitregFired, ONEOFF_ID)
	else
		print("[SingleTest] SKIP marker reached -- set TestKit.Ids.MarkerClip to a clip with a marker")
	end
	task.wait(4.0)
	check("oneoff loads then unloads", loadedOnce and not inBin(ONEOFF_ID), ONEOFF_ID)
	print("[SingleTest] done")
end

-----------------------------
-- MAIN --
-----------------------------

if LocalPlayer.Character then
	task.spawn(run)
end
LocalPlayer.CharacterAdded:Connect(function()
	task.delay(2.5, run)
end)
