--@author: yyumchi
--@date: 2026-09-26
--[[@description:
	Cold raw LoadAnimation vs service Preload+Play on two ids you have never
	loaded. Raw hitches on first fetch, service dispatch does not.
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

local ID_A = TestKit.Ids.StutterA
local ID_B = TestKit.Ids.StutterB

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

local function msUntilLoaded(track: AnimationTrack): number
	local t0 = os.clock()
	for _ = 1, 600 do
		if track.Length > 0 then
			return (os.clock() - t0) * 1000
		end
		task.wait()
	end
	return -1
end

local function report(tag: string, id: string, ms: number)
	if ms < 0 then
		warn(`[StutterTest] TIMEOUT {tag} {id} content never arrived (check asset id / permissions)`)
	else
		print(`[StutterTest] {tag} {id} content ready in {string.format("%.1f", ms)}ms`)
	end
end

local function pickTwo(a: string, b: string): (string, string)
	if math.random(2) == 1 then
		return a, b
	end
	return b, a
end

-----------------------------
-- HANDLERS --
-----------------------------

local function run()
	if getReady() == nil then
		warn("[StutterTest] FAIL service never ready")
		return
	end
	local idRaw, idSvc = pickTwo(ID_A, ID_B)
	local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	local animator = humanoid:WaitForChild("Animator") :: Animator

	local coldAnim = Instance.new("Animation")
	coldAnim.AnimationId = idRaw
	local coldTrack = animator:LoadAnimation(coldAnim)
	coldTrack:Play(0.1)
	report("raw cold", idRaw, msUntilLoaded(coldTrack))
	coldTrack:Stop(0.1)
	coldTrack:Destroy()
	coldAnim:Destroy()

	AnimSignals.PreloadAnims:Fire({ Ids = { idSvc } })
	task.wait(0.5)
	local t0 = os.clock()
	AnimSignals.PlayCategoryTrack:Fire("Single", idSvc, { AutoPlay = true, FadeTime = 0.1, Priority = Enum.AnimationPriority.Action2 })
	local warmMs = (os.clock() - t0) * 1000
	print(`[StutterTest] service preloaded {idSvc} dispatch took {string.format("%.1f", warmMs)}ms`)
	task.wait(1.0)
	AnimSignals.StopCategoryTrack:Fire("Single", idSvc, 0.05)

	local warmAnim = Instance.new("Animation")
	warmAnim.AnimationId = idSvc
	local warmTrack = animator:LoadAnimation(warmAnim)
	warmTrack:Play(0.1)
	report("raw cached", idSvc, msUntilLoaded(warmTrack))
	warmTrack:Stop(0.1)
	warmTrack:Destroy()
	warmAnim:Destroy()
	print("[StutterTest] done: cold >> cached proves preload removes the hitch")
end

-----------------------------
-- MAIN --
-----------------------------

if LocalPlayer.Character then
	task.spawn(run)
end
LocalPlayer.CharacterAdded:Connect(function()
	task.delay(2.0, run)
end)
