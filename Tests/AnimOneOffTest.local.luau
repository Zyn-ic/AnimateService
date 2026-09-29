--!strict
--@author: yyumchi
--@date: 2026-09-28
--[[@description:
	OneOff lifecycle after a Preload: dispatch is warm (no fetch hitch) and the
	track unloads itself when it ends. A natural end also goes through the
	end-of-one-shot Stop that keeps other clients from freezing on the last frame.
	Run alone: a shared session warms ContentProvider for every test after it.
]]

-----------------------------
-- DEPENDENCIES --
-----------------------------

local AnimSignals = require("../Libraries/AnimSignals")
local TestKit = require("./TestKit")

-----------------------------
-- VARIABLES --
-----------------------------

local TAG = "OneOffTest"
local ONESHOT_ID = TestKit.Ids.OneShot

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
	AnimSignals.PreloadAnims:Fire({ Ids = { ONESHOT_ID } })
	task.wait(1)

	local t0 = os.clock()
	AnimSignals.PlayOneOff:Fire(ONESHOT_ID, { FadeTime = 0.05 })
	local track: AnimationTrack? = nil
	local ms: number? = nil
	while os.clock() - t0 < 30 do
		track = TestKit.findTrack(ONESHOT_ID)
		if track then
			local ok, length = pcall(function()
				return (track :: AnimationTrack).Length
			end)
			if ok and length > 0 then
				ms = (os.clock() - t0) * 1000
				break
			end
		end
		task.wait()
	end
	if not ms or not track then
		warn(`[{TAG}] TIMEOUT content never arrived (check the asset id / permissions)`)
		return
	end
	TestKit.check(TAG, "no hitch after Preload", ms < 100, `{string.format("%.1f", ms)}ms`)

	local live = track :: AnimationTrack
	pcall(function()
		live.Stopped:Wait()
	end)
	task.wait(0.5)
	local gone = (live :: Instance).Parent == nil
	TestKit.check(TAG, "oneoff auto-unloads (not saved)", gone and TestKit.findTrack(ONESHOT_ID) == nil, `destroyed={gone}`)
	print(`[{TAG}] done`)
end

-----------------------------
-- MAIN --
-----------------------------

TestKit.onEverySpawn(run, 2.5)
