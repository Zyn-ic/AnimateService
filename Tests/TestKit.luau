--!strict
--@author: yyumchi
--@date: 2026-09-28
--[[@description:
	Shared ids and helpers for the tests in this folder.

	Every id below is one of Roblox's own default R15 animations (taken from the
	stock Animate script), so any experience can load them. Nothing here belongs
	to a specific game. To test marker binding for real, upload a clip that has
	a marker, then set MarkerClip and MarkerName. Left empty, marker checks SKIP.
]]

-----------------------------
-- SERVICES --
-----------------------------

local Players = game:GetService("Players")

-----------------------------
-- VARIABLES --
-----------------------------

local LocalPlayer = Players.LocalPlayer

local TestKit = {}

TestKit.Ids = {
	ProbeA = "rbxassetid://507766388", -- default idle
	ProbeB = "rbxassetid://507765000", -- default jump
	Run = "rbxassetid://507767714", -- default run
	Arms = "rbxassetid://507768375", -- default toolnone: arm-only hold, good for overlays and partials
	OneShot = "rbxassetid://522635514", -- default toolslash: short, ends by itself
	StutterA = "rbxassetid://507770239", -- default wave: two ids nothing else loads
	StutterB = "rbxassetid://507770453", -- default point
	MarkerClip = "", -- optional: YOUR clip that contains a marker
	MarkerName = "hitreg", -- the marker inside MarkerClip
}

-----------------------------
-- PUBLIC FUNCTIONS --
-----------------------------

function TestKit.animator(): Animator?
	local character = LocalPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return humanoid and humanoid:FindFirstChildOfClass("Animator")
end

function TestKit.findTrack(id: string): AnimationTrack?
	local animator = TestKit.animator()
	if not animator then
		return nil
	end
	for _, track in animator:GetPlayingAnimationTracks() do
		local ok, animId = pcall(function()
			return (track :: AnimationTrack).Animation.AnimationId
		end)
		if ok and animId == id then
			return track
		end
	end
	return nil
end

function TestKit.waitTrack(id: string, timeout: number): AnimationTrack?
	local started = os.clock()
	while os.clock() - started < timeout do
		local track = TestKit.findTrack(id)
		if track then
			return track
		end
		task.wait(0.2)
	end
	return nil
end

function TestKit.check(tag: string, name: string, cond: boolean, extra: string?)
	local suffix = if extra then ` -- {extra}` else ""
	if cond then
		print(`[{tag}] PASS {name}{suffix}`)
	else
		warn(`[{tag}] FAIL {name}{suffix}`)
	end
end

function TestKit.skip(tag: string, name: string, why: string)
	print(`[{tag}] SKIP {name} -- {why}`)
end

-- Waits for the service's debug hook (Config.Debug, on by default) to report alive.
function TestKit.getDebug(attempts: number?): any
	for _ = 1, attempts or 200 do
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

-- Runs `run` for the current character (if any) and after every respawn.
function TestKit.onEverySpawn(run: () -> (), delaySeconds: number)
	if LocalPlayer.Character then
		task.spawn(run)
	end
	LocalPlayer.CharacterAdded:Connect(function()
		task.delay(delaySeconds, run)
	end)
end

return TestKit
