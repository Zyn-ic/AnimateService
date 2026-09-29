--@author: yyumchi
--@date: 2026-09-26
--[[@description:
	Core integrity for any game: reuse stays flat, stops work, OneOffs
	unload, respawn rebuilds the same count. Probe ids live in TestKit.
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

local LocalPlayer = Players.LocalPlayer

local PROBE_A = TestKit.Ids.ProbeA
local PROBE_B = TestKit.Ids.ProbeB

local runToken = 0
local baseline: number? = nil

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

local function check(name: string, cond: boolean, extra: string?)
	if cond then
		print(`[Validator] PASS {name}` .. (if extra then ` -- {extra}` else ""))
	else
		warn(`[Validator] FAIL {name}` .. (if extra then ` -- {extra}` else ""))
	end
end

-----------------------------
-- HANDLERS --
-----------------------------

local function runOnce()
	runToken += 1
	local myRun = runToken
	print("[Validator] waiting for core ready...")
	local info: any = nil
	for _ = 1, 150 do
		if myRun ~= runToken then
			return
		end
		info = getDebug()
		if info then
			break
		end
		task.wait(0.2)
	end
	if myRun ~= runToken then
		return
	end
	if not info then
		warn("[Validator] FAIL no debug (service never registered)")
		return
	end
	if baseline == nil then
		task.wait(1.0)
		baseline = (getDebug() :: any).count
		print(`[Validator] baseline count={tostring(baseline)}`)
	end
	local before = (getDebug() :: any).count
	AnimSignals.PlayCategoryTrack:Fire("Single", PROBE_A, { AutoPlay = false })
	task.wait(0.3)
	local mid = (getDebug() :: any).count
	AnimSignals.PlayCategoryTrack:Fire("Single", PROBE_A, { AutoPlay = false })
	task.wait(0.3)
	local afterReuse = (getDebug() :: any).count
	check("single reuse second load flat", mid == afterReuse, `before {before} mid {mid} after {afterReuse}`)
	local boundOk = pcall(function()
		AnimSignals.BindMarker:Fire("Single", PROBE_A, "Hit", function() end)
	end)
	check("marker bind path alive", boundOk == true)
	local stopOk = pcall(function()
		AnimSignals.StopCategoryTrack:Fire("Single", PROBE_A, 0.05)
	end)
	check("stop path alive", stopOk == true)
	task.wait(0.2)
	local c0 = (getDebug() :: any).count
	AnimSignals.PlayOneOff:Fire(PROBE_B, { FadeTime = 0.05, Priority = Enum.AnimationPriority.Action3 })
	task.wait(1.0)
	local c1 = (getDebug() :: any).count
	check("oneoff no permanent leak", c1 <= c0 + 1, `c0 {c0} c1 {c1}`)
	print("[Validator] static checks done. Reset your character to verify the rebuild matches baseline.")
end

local function watchDeath()
	LocalPlayer.CharacterRemoving:Connect(function()
		print("[Validator] CharacterRemoving (old count holds until next spawn, this is correct)")
	end)
	LocalPlayer.CharacterAdded:Connect(function()
		task.delay(2.0, function()
			local want = baseline
			for _ = 1, 100 do
				local probe = getDebug()
				if probe and want ~= nil and probe.count == want then
					break
				end
				task.wait(0.2)
			end
			local current = getDebug()
			if current and want ~= nil then
				check("respawn rebuild == baseline", current.count == want, `got {tostring(current.count)} want {want}`)
				if current.count == want * 2 then
					warn("[Validator] LEAK: doubled (old tracks not destroyed)")
				end
			end
		end)
	end)
end

-----------------------------
-- MAIN --
-----------------------------

watchDeath()
if LocalPlayer.Character then
	task.spawn(runOnce)
end
LocalPlayer.CharacterAdded:Connect(function()
	task.delay(2.5, runOnce)
end)
