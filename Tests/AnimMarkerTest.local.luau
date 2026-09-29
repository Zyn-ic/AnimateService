--!strict
--@author: yyumchi
--@date: 2026-09-28
--[[@description:
	Marker bookkeeping, no marker clip needed (we count listeners, we do not
	wait for a marker to fire). Covers the OnMarker handle that used to throw
	when its own call was the one that first loaded the track, multiple
	listeners, ClearMarkers by name and wholesale, and the ClearMarkers signal.
	The signal half needs an AnimSignals bus; it FAILs if the bus is not wired.
]]

-----------------------------
-- DEPENDENCIES --
-----------------------------

local AnimateService = require("../Module/AnimateService")
local AnimSignals = require("../Libraries/AnimSignals")
local TestKit = require("./TestKit")

-----------------------------
-- VARIABLES --
-----------------------------

local TAG = "MarkerTest"
local CATEGORY = "MarkerTest"
local ID = TestKit.Ids.ProbeA
local MARKER = "TestMarker"

local didRun = false

-----------------------------
-- PRIVATE FUNCTIONS --
-----------------------------

local function count(marker: string): number
	local rig = AnimateService:GetRig()
	return if rig then rig:GetMarkerListenerCount(CATEGORY, ID, marker) else -1
end

-----------------------------
-- HANDLERS --
-----------------------------

local function run()
	if didRun then
		return
	end
	didRun = true
	if AnimateService:WaitForRig(20) == nil then
		warn(`[{TAG}] FAIL no rig (is the service started?)`)
		return
	end

	local first = AnimateService:OnMarker(CATEGORY, ID, MARKER, function() end)
	TestKit.check(TAG, "binding on a never-loaded id returns a handle", first ~= nil)
	TestKit.check(TAG, "listener registered", count(MARKER) == 1, `count={count(MARKER)}`)
	local disconnectOk = pcall(function()
		(first :: AnimateService.MarkerHandle):Disconnect()
	end)
	TestKit.check(TAG, "Disconnect on a first-load handle does not throw", disconnectOk)
	TestKit.check(TAG, "Disconnect removes the listener", count(MARKER) == 0, `count={count(MARKER)}`)

	AnimateService:OnMarker(CATEGORY, ID, MARKER, function() end)
	AnimateService:OnMarker(CATEGORY, ID, MARKER, function() end)
	TestKit.check(TAG, "two listeners stack", count(MARKER) == 2, `count={count(MARKER)}`)
	AnimateService:ClearMarkers(CATEGORY, ID, MARKER)
	TestKit.check(TAG, "ClearMarkers(marker) empties it", count(MARKER) == 0, `count={count(MARKER)}`)

	AnimateService:OnMarker(CATEGORY, ID, MARKER, function() end)
	AnimateService:OnMarker(CATEGORY, ID, "Other", function() end)
	AnimateService:ClearMarkers(CATEGORY, ID)
	TestKit.check(TAG, "ClearMarkers(no marker) clears every marker", count(MARKER) == 0 and count("Other") == 0, `a={count(MARKER)} b={count("Other")}`)

	AnimSignals.BindMarker:Fire(CATEGORY, ID, MARKER, function() end)
	task.wait(0.2)
	TestKit.check(TAG, "BindMarker signal registers", count(MARKER) == 1, `count={count(MARKER)}`)
	AnimSignals.ClearMarkers:Fire({ Category = CATEGORY, AnimId = ID, Marker = nil })
	task.wait(0.2)
	TestKit.check(TAG, "ClearMarkers signal clears", count(MARKER) == 0, `count={count(MARKER)}`)
	print(`[{TAG}] done`)
end

-----------------------------
-- MAIN --
-----------------------------

TestKit.onEverySpawn(run, 2.5)
