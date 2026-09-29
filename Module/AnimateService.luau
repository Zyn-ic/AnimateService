--!strict
--@author: yyumchi
--@date: 2026-09-28
--[[@description:
	AnimateService as a module. One implementation, two ways to drive it (mix freely):

	  1. Signals: fire Libraries/AnimSignals from anywhere. Optional.
	  2. Direct:  require this module and call it, e.g. AnimateService:PlayCategory(...)

	Lifecycle matches ModuleLoader-style services: :Init() then :Start().
	The controller is CLIENT-ONLY (it owns the LocalPlayer's character). The
	per-rig class is exported as AnimateService.Rig and works on any Humanoid rig.
	Needs Libraries/Signal (SignalPlus) for OnRigReady. AnimSignals is only used when UseSignals is on and it is found.
]]

-----------------------------
-- SERVICES --
-----------------------------

local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

-----------------------------
-- DEPENDENCIES --
-----------------------------

local Signal = require("../Libraries/Signal")

-----------------------------
-- TYPES --
-----------------------------

export type ProfileDefinition = { [string]: string }

export type PlayOpts = {
	FadeTime: number?,
	Speed: number?,
	Weight: number?,
	Priority: Enum.AnimationPriority?,
	Looped: boolean?,
}

export type LoadOptions = {
	AutoPlay: boolean?,
	FadeTime: number?,
	Speed: number?,
	Weight: number?,
	Priority: Enum.AnimationPriority?,
	Looped: boolean?,
	Keep: boolean?, -- reserved, nothing reads it yet
	PreloadOnly: boolean?,
	MarkerName: string?,
	MarkerCallback: ((...any) -> ())?,
	OnLoaded: ((AnimationTrack) -> ())?,
}

export type Connection = Signal.Connection

-- What OnMarker hands back: a small handle, not a Signal connection.
export type MarkerHandle = {
	Connected: boolean,
	Disconnect: (MarkerHandle) -> (),
}

export type RigSettings = {
	LocomotionPriority: Enum.AnimationPriority,
	ClampCombatPriority: boolean,
	MinCombatPriority: Enum.AnimationPriority,
	DefaultOverlayPriority: Enum.AnimationPriority,
	PlayingWarnThreshold: number,
	Verbose: boolean,
}

export type PartialRigSettings = {
	LocomotionPriority: Enum.AnimationPriority?,
	ClampCombatPriority: boolean?,
	MinCombatPriority: Enum.AnimationPriority?,
	DefaultOverlayPriority: Enum.AnimationPriority?,
	PlayingWarnThreshold: number?,
	Verbose: boolean?,
}

export type Config = {
	-- driving
	UseSignals: boolean?, -- default true. Needs an AnimSignals bus; skipped quietly if none is found
	Signals: any?, -- pass your AnimSignals table; default: look for AnimSignals beside/above this module
	Debug: boolean?, -- default true. Exposes _G.__AnimateServiceDebug (the tests use it)
	-- core locomotion source, first match wins: CoreProfile > CoreResolver > folders under CoreFolder
	CoreProfile: ProfileDefinition?,
	CoreResolver: ((Humanoid) -> ProfileDefinition?)?,
	CoreFolder: Instance?, -- holds R15Animations / R6Animations, or Animation objects directly. Default: this module
	ExtraProfiles: { [string]: ProfileDefinition }?, -- loaded (not activated) every life
	PersistProfiles: boolean?, -- default true. Profiles + active core survive respawns
	-- rig behaviour
	LocomotionPriority: Enum.AnimationPriority?, -- default Core
	ClampCombatPriority: boolean?, -- default false. true = category tracks forced to Action2..Action4
	MinCombatPriority: Enum.AnimationPriority?, -- default Action2
	DefaultOverlayPriority: Enum.AnimationPriority?, -- default Core
	PlayingWarnThreshold: number?, -- default 48
	Verbose: boolean?,
}

type ProfileTrackEntry = { Track: AnimationTrack, AnimId: string, CleanId: string }
type ProfileRecord = { Name: string, Definition: ProfileDefinition, Tracks: { [string]: ProfileTrackEntry } }
type CategoryTrackEntry = {
	Track: AnimationTrack,
	AnimId: string,
	CleanId: string,
	Kind: string,
	Refs: number,
	LastUsed: number,
	Keep: boolean,
	MarkerConns: { [string]: RBXScriptConnection },
	MarkerCallbacks: { [string]: { (...any) -> () } },
	EndStopConn: RBXScriptConnection?,
}
type CategoryBucket = { [string]: CategoryTrackEntry }
type HumanoidStateName = "Running" | "Jumping" | "FreeFalling" | "Climbing" | "Swimming" | "Seated" | "GettingUp" | "FallingDown" | "Dead" | "PlatformStanding" | "Physics" | "None"
type ProfilePlayOpts = { FadeTime: number?, Speed: number? }

type Self = {
	Character: Model,
	Humanoid: Humanoid,
	Animator: Animator,
	_settings: RigSettings,
	_initialised: boolean,
	_running: boolean,
	_destroyed: boolean,
	_connections: { RBXScriptConnection },
	_trackCount: number,
	_lastCrowdWarn: number,
	_profiles: { [string]: ProfileRecord },
	_activeProfile: string?,
	_lastLoadedProfile: string?,
	_activeTracks: { [string]: AnimationTrack },
	_overlayProfile: string?,
	_overlayPriority: Enum.AnimationPriority?,
	_overlayTracks: { [string]: AnimationTrack },
	_defaultProfileName: string,
	_categories: { [string]: CategoryBucket },
	_byId: { [string]: CategoryTrackEntry },
	_currentState: HumanoidStateName,
	_jumpActive: boolean,
	SprintThreshold: number,
	RunThreshold: number,
	WalkThreshold: number,
	SprintDividend: number,
	RunDividend: number,
	WalkDividend: number,
	ClimbDividend: number,
	SwimDividend: number,
	JumpDuration: number,
	ApplyRigScale: boolean,
}

-----------------------------
-- VARIABLES --
-----------------------------

local ENGINE_PLAYING_CAP = 64
local DEFAULT_PROFILE = "__Default__"

local COMBAT_LADDER: { Enum.AnimationPriority } = {
	Enum.AnimationPriority.Action,
	Enum.AnimationPriority.Action2,
	Enum.AnimationPriority.Action3,
	Enum.AnimationPriority.Action4,
}

local DEFAULT_SETTINGS: RigSettings = {
	LocomotionPriority = Enum.AnimationPriority.Core,
	ClampCombatPriority = false,
	MinCombatPriority = Enum.AnimationPriority.Action2,
	DefaultOverlayPriority = Enum.AnimationPriority.Core,
	PlayingWarnThreshold = 48,
	Verbose = false,
}

local _preloadedIds: { [string]: true } = {}

local Rig = {}
Rig.__index = Rig

export type Rig = typeof(setmetatable({} :: Self, Rig))

-----------------------------
-- PRIVATE FUNCTIONS --
-----------------------------

local function stripId(id: string): string
	return (id:gsub("rbxassetid://", ""))
end

local function normaliseId(id: string): string
	return "rbxassetid://" .. stripId(id)
end

local function loadTrack(animator: Animator, animId: string): AnimationTrack
	local anim = Instance.new("Animation")
	anim.AnimationId = normaliseId(animId)
	local track = animator:LoadAnimation(anim)
	anim:Destroy()
	return track
end

local function destroyTrack(track: AnimationTrack): ()
	pcall(function()
		if track.IsPlaying then
			track:Stop(0)
		end
	end);
	(track :: Instance):Destroy()
end

local function shouldLoop(animName: string): boolean
	return animName ~= "Jump"
end

local function toTitleCase(str: string): string
	return (str:gsub("^%l", string.upper))
end

local function mergeSettings(partial: PartialRigSettings?): RigSettings
	local merged = table.clone(DEFAULT_SETTINGS)
	if partial then
		merged.LocomotionPriority = partial.LocomotionPriority or merged.LocomotionPriority
		merged.MinCombatPriority = partial.MinCombatPriority or merged.MinCombatPriority
		merged.DefaultOverlayPriority = partial.DefaultOverlayPriority or merged.DefaultOverlayPriority
		merged.PlayingWarnThreshold = partial.PlayingWarnThreshold or merged.PlayingWarnThreshold
		if partial.ClampCombatPriority ~= nil then
			merged.ClampCombatPriority = partial.ClampCombatPriority
		end
		if partial.Verbose ~= nil then
			merged.Verbose = partial.Verbose
		end
	end
	return merged
end

local function folderToProfile(folder: Instance): ProfileDefinition
	local def: ProfileDefinition = {}
	for _, child in folder:GetChildren() do
		if child:IsA("Animation") then
			def[string.lower(child.Name)] = child.AnimationId
		elseif child:IsA("StringValue") then
			for _, grand in child:GetChildren() do
				if grand:IsA("Animation") then
					def[string.lower(child.Name)] = grand.AnimationId
					break
				end
			end
		end
	end
	return def
end

local function discoverCore(humanoid: Humanoid, root: Instance): ProfileDefinition?
	local rigFolder = root:FindFirstChild(if humanoid.RigType == Enum.HumanoidRigType.R15 then "R15Animations" else "R6Animations")
	if rigFolder then
		return folderToProfile(rigFolder)
	end
	local direct = folderToProfile(root)
	if next(direct) ~= nil then
		return direct
	end
	return nil
end

-- Content-only warmup. Needs no character, so loading screens can call it too.
local function preloadIds(ids: { string }): ()
	local toLoad: { Instance } = {}
	local marked: { string } = {}
	for _, id in ids do
		local clean = stripId(id)
		if clean == "" or _preloadedIds[clean] then
			continue
		end
		_preloadedIds[clean] = true
		table.insert(marked, clean)
		local anim = Instance.new("Animation")
		anim.AnimationId = normaliseId(id)
		table.insert(toLoad, anim)
	end
	if #toLoad == 0 then
		return
	end
	local ok, err = pcall(function()
		ContentProvider:PreloadAsync(toLoad)
	end)
	for _, anim in toLoad do
		pcall(function()
			anim:Destroy()
		end)
	end
	if not ok then
		for _, clean in marked do
			_preloadedIds[clean] = nil -- let a later call retry
		end
		warn("[AnimateService] Preload failed:", err)
	end
end

local function collectIds(definition: ProfileDefinition?, into: { string }): ()
	if not definition then
		return
	end
	for _, id in definition do
		if id ~= "" then
			table.insert(into, id)
		end
	end
end

-----------------------------
-- RIG (per character life) --
-----------------------------

function Rig.new(character: Model, settings: PartialRigSettings?): Rig
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	local animator = humanoid:WaitForChild("Animator") :: Animator

	for _, track in animator:GetPlayingAnimationTracks() do
		track:Stop(0)
		destroyTrack(track)
	end

	return setmetatable({
		Character = character,
		Humanoid = humanoid,
		Animator = animator,
		_settings = mergeSettings(settings),
		_initialised = false,
		_running = false,
		_destroyed = false,
		_connections = {},
		_trackCount = 0,
		_lastCrowdWarn = 0,
		_profiles = {},
		_activeProfile = nil,
		_lastLoadedProfile = nil,
		_activeTracks = {},
		_overlayProfile = nil,
		_overlayPriority = nil,
		_overlayTracks = {},
		_defaultProfileName = DEFAULT_PROFILE,
		_categories = {},
		_byId = {},
		_currentState = "None" :: HumanoidStateName,
		_jumpActive = false,
		SprintThreshold = 24,
		RunThreshold = 17,
		WalkThreshold = 0.01,
		SprintDividend = 22,
		RunDividend = 18,
		WalkDividend = 16,
		ClimbDividend = 12,
		SwimDividend = 16,
		JumpDuration = 0.31,
		ApplyRigScale = true,
	} :: Self, Rig)
end

function Rig._increment(self: Rig): ()
	self._trackCount += 1
end

function Rig._decrement(self: Rig): ()
	self._trackCount = math.max(0, self._trackCount - 1)
end

function Rig._warnIfCrowded(self: Rig): ()
	if os.clock() - self._lastCrowdWarn < 5 then
		return
	end
	local ok, tracks = pcall(function()
		return self.Animator:GetPlayingAnimationTracks()
	end)
	if ok and #tracks >= self._settings.PlayingWarnThreshold then
		self._lastCrowdWarn = os.clock()
		warn(string.format("[AnimateService] %d playing tracks (engine cap %d)", #tracks, ENGINE_PLAYING_CAP))
	end
end

-- Category tracks: with ClampCombatPriority on, only Action..Action4 at or above
-- MinCombatPriority survive; anything else (including Core/nil) becomes the minimum.
function Rig._resolvePriority(self: Rig, requested: Enum.AnimationPriority?): Enum.AnimationPriority
	local settings = self._settings
	if not settings.ClampCombatPriority then
		return requested or Enum.AnimationPriority.Core
	end
	if requested and table.find(COMBAT_LADDER, requested) and requested.Value >= settings.MinCombatPriority.Value then
		return requested
	end
	return settings.MinCombatPriority
end

function Rig._find(self: Rig, category: string, cleanId: string): CategoryTrackEntry?
	local bucket = self._categories[category]
	return (bucket and bucket[cleanId]) or self._byId[cleanId]
end

function Rig.Preload(self: Rig, ids: { string }): ()
	if self._destroyed then
		return
	end
	preloadIds(ids)
end

function Rig._destroyEntry(self: Rig, category: string, cleanId: string): ()
	local bucket = self._categories[category]
	if not bucket then
		return
	end
	local entry = bucket[cleanId]
	if not entry then
		return
	end
	bucket[cleanId] = nil
	for _, other in self._categories do
		if other[cleanId] then
			return -- another category still shares this track
		end
	end
	for _, conn in entry.MarkerConns do
		pcall(function()
			conn:Disconnect()
		end)
	end
	table.clear(entry.MarkerConns)
	table.clear(entry.MarkerCallbacks)
	if entry.EndStopConn ~= nil then
		local endConn = entry.EndStopConn
		entry.EndStopConn = nil
		pcall(function()
			endConn:Disconnect()
		end)
	end
	if self._byId[cleanId] == entry then
		self._byId[cleanId] = nil
	end
	destroyTrack(entry.Track)
	self:_decrement()
end

function Rig.HasProfile(self: Rig, name: string): boolean
	return self._profiles[name] ~= nil
end

function Rig.LoadProfile(self: Rig, name: string, definition: ProfileDefinition): Rig
	if self._destroyed or self._profiles[name] then
		return self
	end
	local record: ProfileRecord = { Name = name, Definition = {}, Tracks = {} }
	for rawAnimName, animId in definition do
		if animId == "" then
			continue
		end
		local animName = toTitleCase(rawAnimName)
		if animName == "Swimidle" then
			animName = "SwimIdle"
		end
		local track = loadTrack(self.Animator, animId)
		track.Priority = self._settings.LocomotionPriority
		track.Looped = shouldLoop(animName)
		record.Tracks[animName] = { Track = track, AnimId = normaliseId(animId), CleanId = stripId(animId) }
		record.Definition[animName] = normaliseId(animId)
		self:_increment()
	end
	self._profiles[name] = record
	self._lastLoadedProfile = name
	return self
end

function Rig.SetActiveProfile(self: Rig, name: string?): Rig
	local profileName = name or self._lastLoadedProfile
	if profileName ~= nil and not self._profiles[profileName] then
		warn("[AnimateService] unknown profile:", profileName)
		return self
	end
	for _, track in self._activeTracks do
		if track.IsPlaying then
			track:Stop(0.1)
		end
	end
	table.clear(self._activeTracks)
	self._activeProfile = profileName
	if self._running then
		self:_evaluateState()
	end
	return self
end

function Rig.ChangeAll(self: Rig, name: string, definition: ProfileDefinition): Rig
	if self._destroyed then
		return self
	end
	local old = self._profiles[name]
	if old then
		for _, entry in old.Tracks do
			pcall(function()
				if entry.Track.IsPlaying then
					entry.Track:Stop(0.05)
				end
			end)
			destroyTrack(entry.Track)
			self:_decrement()
		end
		self._profiles[name] = nil
	end
	return self:LoadProfile(name, definition)
end

function Rig.LoadCategory(self: Rig, category: string, animId: string, opts: LoadOptions?): AnimationTrack?
	if self._destroyed then
		return nil
	end
	local options: LoadOptions = opts or {}
	local cleanId = stripId(animId)
	if cleanId == "" then
		return nil
	end
	local bucket = self._categories[category]
	local entry = bucket and bucket[cleanId] or nil
	if entry then
		entry.LastUsed = os.clock()
		entry.Refs += 1
		if options.Priority then
			entry.Track.Priority = self:_resolvePriority(options.Priority)
		end
		if options.Looped ~= nil then
			entry.Track.Looped = options.Looped
		end
		if options.MarkerName and options.MarkerCallback then
			self:OnMarker(category, animId, options.MarkerName, options.MarkerCallback)
		end
		if options.AutoPlay and not entry.Track.IsPlaying then
			entry.Track:Play(options.FadeTime or 0.1, options.Weight, options.Speed)
			self:_warnIfCrowded()
		elseif options.AutoPlay and options.Speed then
			entry.Track:AdjustSpeed(options.Speed)
		end
		if options.OnLoaded then
			task.spawn(options.OnLoaded, entry.Track)
		end
		self:_ensureEndStop(entry)
		return entry.Track
	end
	local shared = self._byId[cleanId]
	if shared and (shared.Track :: Instance).Parent ~= nil then
		local target = self._categories[category]
		if not target then
			target = {}
			self._categories[category] = target
		end
		shared.Refs += 1
		shared.LastUsed = os.clock()
		target[cleanId] = shared
		if options.Priority then
			shared.Track.Priority = self:_resolvePriority(options.Priority)
		end
		if options.MarkerName and options.MarkerCallback then
			self:OnMarker(category, animId, options.MarkerName, options.MarkerCallback)
		end
		if options.AutoPlay and not shared.Track.IsPlaying then
			shared.Track:Play(options.FadeTime or 0.1, options.Weight, options.Speed)
			self:_warnIfCrowded()
		end
		if options.OnLoaded then
			task.spawn(options.OnLoaded, shared.Track)
		end
		self:_ensureEndStop(shared)
		return shared.Track
	end
	local track = loadTrack(self.Animator, animId)
	if options.Looped ~= nil then
		track.Looped = options.Looped
	end
	track.Priority = self:_resolvePriority(options.Priority)
	local newEntry: CategoryTrackEntry = {
		Track = track,
		AnimId = normaliseId(animId),
		CleanId = cleanId,
		Kind = if category == "OneOff" then "OneOff" else "Single",
		Refs = 1,
		LastUsed = os.clock(),
		Keep = options.Keep ~= false,
		MarkerConns = {},
		MarkerCallbacks = {},
		EndStopConn = nil,
	}
	local target = self._categories[category]
	if not target then
		target = {}
		self._categories[category] = target
	end
	target[cleanId] = newEntry
	self._byId[cleanId] = newEntry
	self:_increment()
	if options.MarkerName and options.MarkerCallback then
		self:OnMarker(category, animId, options.MarkerName, options.MarkerCallback)
	end
	if options.OnLoaded then
		task.spawn(options.OnLoaded, track)
	end
	if options.PreloadOnly then
		return track
	end
	if options.AutoPlay then
		track:Play(options.FadeTime or 0.1, options.Weight, options.Speed)
		self:_warnIfCrowded()
	end
	self:_ensureEndStop(newEntry)
	return track
end

function Rig.OnMarker(self: Rig, category: string, animId: string, marker: string, cb: (...any) -> ()): MarkerHandle?
	if self._destroyed then
		return nil
	end
	local cleanId = stripId(animId)
	local live = self:_find(category, cleanId)
	if live == nil then
		if not self:LoadCategory(category, animId, { AutoPlay = false }) then
			return nil
		end
		live = self:_find(category, cleanId)
	end
	if live == nil then
		return nil
	end
	local entry: CategoryTrackEntry = live
	local list = entry.MarkerCallbacks[marker]
	if not list then
		list = {}
		entry.MarkerCallbacks[marker] = list
	end
	table.insert(list, cb)
	if not entry.MarkerConns[marker] then
		entry.MarkerConns[marker] = entry.Track:GetMarkerReachedSignal(marker):Connect(function(...: any)
			local current = entry.MarkerCallbacks[marker]
			if current then
				for _, fn in table.clone(current) do
					task.spawn(fn, ...)
				end
			end
		end)
	end
	local conn: MarkerHandle
	conn = {
		Connected = true,
		Disconnect = function(_: MarkerHandle)
			if not conn.Connected then
				return
			end
			conn.Connected = false
			local current = entry.MarkerCallbacks[marker]
			if current then
				local index = table.find(current, cb)
				if index then
					table.remove(current, index)
				end
			end
		end,
	}
	return conn
end

function Rig.ClearMarkers(self: Rig, category: string, animId: string, marker: string?): ()
	if self._destroyed then
		return
	end
	local cleanId = stripId(animId)
	if cleanId == "" then
		return
	end
	local entry = self:_find(category, cleanId)
	if not entry then
		return
	end
	local names: { string } = {}
	if marker then
		table.insert(names, marker)
	else
		for name in entry.MarkerConns do
			table.insert(names, name)
		end
	end
	for _, name in names do
		local conn = entry.MarkerConns[name]
		if conn then
			pcall(function()
				conn:Disconnect()
			end)
		end
		entry.MarkerConns[name] = nil
		entry.MarkerCallbacks[name] = nil
	end
end

function Rig.GetMarkerListenerCount(self: Rig, category: string, animId: string, marker: string): number
	local entry = self:_find(category, stripId(animId))
	local list = if entry then entry.MarkerCallbacks[marker] else nil
	return if list then #list else 0
end

-- A non-looped track that ends naturally only ends locally; without an explicit
-- Stop, other clients stay frozen on its last frame. Hooking Ended (instead of
-- stopping early) keeps full playback (markers, hit windows, tail frames) and
-- THEN replicates the Stop. Connected once per entry.
function Rig._ensureEndStop(self: Rig, entry: CategoryTrackEntry): ()
	if entry.EndStopConn ~= nil or entry.Track.Looped then
		return
	end
	local liveTrack = entry.Track
	entry.EndStopConn = liveTrack.Ended:Connect(function()
		pcall(function()
			liveTrack:Stop(0.05)
		end)
	end)
end

function Rig.GetTrack(self: Rig, category: string, animId: string): AnimationTrack?
	local entry = self:_find(category, stripId(animId))
	return if entry then entry.Track else nil
end

function Rig.IsPlaying(self: Rig, category: string, animId: string): boolean
	local track = self:GetTrack(category, animId)
	return track ~= nil and track.IsPlaying
end

function Rig.GetLoadedCount(self: Rig): number
	return self._trackCount
end

function Rig.GetLoadedList(self: Rig): { [string]: string }
	local out: { [string]: string } = {}
	for cat, bucket in self._categories do
		for id, entry in bucket do
			out[id] = cat .. "/" .. entry.Kind
		end
	end
	return out
end

function Rig.GetProfileCount(self: Rig): number
	local n = 0
	for _ in self._profiles do
		n += 1
	end
	return n
end

function Rig.GetAnimatorPlayingCount(self: Rig): number
	local ok, tracks = pcall(function()
		return self.Animator:GetPlayingAnimationTracks()
	end)
	return if ok then #tracks else -1
end

function Rig.PlaySingle(self: Rig, category: string, animId: string, opts: PlayOpts?): AnimationTrack?
	return self:LoadCategory(category, animId, {
		AutoPlay = true,
		FadeTime = opts and opts.FadeTime or 0.1,
		Weight = opts and opts.Weight,
		Speed = opts and opts.Speed,
		Priority = opts and opts.Priority,
		Looped = opts and opts.Looped,
	})
end

function Rig.PlayOneOff(self: Rig, animId: string, opts: PlayOpts?): AnimationTrack?
	local track = self:LoadCategory("OneOff", animId, {
		AutoPlay = true,
		FadeTime = opts and opts.FadeTime or 0.1,
		Weight = opts and opts.Weight,
		Speed = opts and opts.Speed,
		Priority = opts and opts.Priority,
		Looped = false,
	})
	if track then
		local clean = stripId(animId)
		track.Stopped:Once(function()
			if not self._destroyed then
				self:_destroyEntry("OneOff", clean)
			end
		end)
	end
	return track
end

function Rig.StopCategory(self: Rig, category: string, animId: string?, fade: number?): ()
	local bucket = self._categories[category]
	if not bucket then
		return
	end
	if animId then
		local entry = bucket[stripId(animId)]
		if entry and entry.Track.IsPlaying then
			entry.Track:Stop(fade or 0.05)
		end
		return
	end
	for _, entry in bucket do
		if entry.Track.IsPlaying then
			entry.Track:Stop(fade or 0.05)
		end
	end
end

function Rig.StopAllCategory(self: Rig, category: string, fade: number?): ()
	self:StopCategory(category, nil, fade or 0.05)
end

function Rig.SetLocomotionWeight(self: Rig, mult: number, _fade: number?): ()
	for _, track in self._activeTracks do
		if track.IsPlaying then
			local base = 1
			pcall(function()
				base = (track :: any).WeightTarget or 1
			end)
			track:AdjustWeight(base * mult)
		end
	end
end

function Rig.ChangeAnimateParams(self: Rig, patch: { [string]: number | boolean }): ()
	for k, v in patch do
		(self :: any)[k] = v
	end
end

function Rig.Init(self: Rig): Rig
	self._initialised = true
	table.insert(self._connections, self.Humanoid.StateChanged:Connect(function(_old, new)
		local stateName = new.Name
		if stateName == "Freefall" then
			stateName = "FreeFalling"
		end
		if stateName == "Jumping" then
			self._jumpActive = true
			task.delay(self.JumpDuration, function()
				if self._destroyed then
					return
				end
				self._jumpActive = false
				if self._currentState == "FreeFalling" then
					self:_evaluateState()
				end
			end)
		end
		self._currentState = stateName :: HumanoidStateName
		self:_evaluateState()
	end))
	table.insert(self._connections, self.Humanoid.Running:Connect(function(speed)
		self:_evaluateState(speed)
	end))
	table.insert(self._connections, self.Humanoid.Climbing:Connect(function(speed)
		self:_evaluateState(speed)
	end))
	table.insert(self._connections, self.Humanoid.Swimming:Connect(function(speed)
		self:_evaluateState(speed)
	end))
	table.insert(self._connections, self.Humanoid.Died:Connect(function()
		self._currentState = "Dead"
		self:_evaluateState()
	end))
	return self
end

function Rig.Start(self: Rig): Rig
	if self._settings.Verbose then
		print("[AnimateService] Starting for", self.Character:GetFullName())
	end
	self._running = true
	self._currentState = self.Humanoid:GetState().Name :: any
	if self._currentState == ("Freefall" :: any) then
		self._currentState = "FreeFalling"
	end
	self:_evaluateState()
	return self
end

function Rig._evaluateState(self: Rig, passedSpeed: number?): ()
	if self._destroyed or not self._running then
		return
	end
	local state = self._currentState
	if state == "Dead" or state == "GettingUp" or state == "FallingDown" or state == "PlatformStanding" or state == "Physics" then
		self:_stopAllProfileTracks()
		self:_stopAllOverlayTracks()
		return
	end
	if state == "Seated" then
		self:_playProfileAnim("Sit", { FadeTime = 0.5 })
		return
	end
	if state == "FreeFalling" then
		if not self._jumpActive then
			self:_playProfileAnim("Fall", { FadeTime = 0.3 })
		end
		return
	end
	if state == "Climbing" then
		local speed = passedSpeed or self:_speed()
		self:_playProfileAnim("Climb", { FadeTime = 0.1, Speed = speed / self.ClimbDividend })
		return
	end
	if state == "Swimming" then
		local speed = passedSpeed or self:_speed()
		if speed < 5 then
			self:_playProfileAnim("SwimIdle", { FadeTime = 0.2 })
		else
			self:_playProfileAnim("Swim", { FadeTime = 0.3, Speed = speed / self.SwimDividend })
		end
		return
	end
	if state == "Jumping" then
		self:_playProfileAnim("Jump", { FadeTime = 0.1 })
		return
	end
	local speed = passedSpeed or self:_speed()
	if state == "Running" and speed <= self.WalkThreshold then
		self:_playProfileAnim("Idle", { FadeTime = 0.1 })
	elseif speed >= self.SprintThreshold then
		self:_playProfileAnim("Sprint", { FadeTime = 0.2, Speed = speed / self.SprintDividend })
	elseif speed >= self.RunThreshold then
		self:_playProfileAnim("Run", { FadeTime = 0.2, Speed = speed / self.RunDividend })
	elseif speed > self.WalkThreshold then
		self:_playProfileAnim("Walk", { FadeTime = 0.15, Speed = speed / self.WalkDividend })
	else
		self:_playProfileAnim("Idle", { FadeTime = 0.1 })
	end
end

function Rig._resolveEntry(self: Rig, animName: string): ProfileTrackEntry?
	local record = self._profiles[self._activeProfile or ""]
	if record and record.Tracks[animName] then
		return record.Tracks[animName]
	end
	local default = self._profiles[self._defaultProfileName]
	return if default then default.Tracks[animName] else nil
end

function Rig._playProfileAnim(self: Rig, animName: string, opts: ProfilePlayOpts): ()
	local entry = self:_resolveEntry(animName)
	if not entry then
		return
	end
	local newTrack = entry.Track
	local currentTrack = self._activeTracks[animName]
	for slot, track in self._activeTracks do
		if slot ~= animName and track.IsPlaying then
			track:Stop(opts.FadeTime or 0.15)
		end
	end
	table.clear(self._activeTracks)
	self._activeTracks[animName] = newTrack
	if currentTrack and currentTrack ~= newTrack and currentTrack.IsPlaying then
		currentTrack:Stop(opts.FadeTime or 0.1)
	end
	if not newTrack.IsPlaying then
		newTrack:Play(opts.FadeTime or 0.1, nil, opts.Speed)
		self:_warnIfCrowded()
	elseif opts.Speed then
		newTrack:AdjustSpeed(opts.Speed)
	end
	self:_playOverlayAnim(animName, opts)
end

function Rig.SetOverlayProfile(self: Rig, name: string?, priority: Enum.AnimationPriority?): Rig
	self._overlayProfile = name
	self._overlayPriority = priority
	if self._running then
		self:_evaluateState()
	end
	return self
end

function Rig.ClearOverlay(self: Rig): Rig
	return self:SetOverlayProfile(nil, nil)
end

function Rig._playOverlayAnim(self: Rig, animName: string, opts: ProfilePlayOpts): ()
	for _, track in self._overlayTracks do
		if track.IsPlaying then
			track:Stop(opts.FadeTime or 0.15)
		end
	end
	table.clear(self._overlayTracks)
	local overlayName = self._overlayProfile
	local record = if overlayName then self._profiles[overlayName] else nil
	local entry = record and record.Tracks[animName] or nil
	if not entry then
		return
	end
	local overlayTrack = entry.Track
	overlayTrack.Priority = self._overlayPriority or self._settings.DefaultOverlayPriority
	if not overlayTrack.IsPlaying then
		overlayTrack:Play(opts.FadeTime or 0.1, nil, opts.Speed)
		self:_warnIfCrowded()
	elseif opts.Speed then
		overlayTrack:AdjustSpeed(opts.Speed)
	end
	self._overlayTracks[animName] = overlayTrack
end

function Rig._stopAllOverlayTracks(self: Rig): ()
	for _, track in self._overlayTracks do
		if track.IsPlaying then
			track:Stop(0.2)
		end
	end
	table.clear(self._overlayTracks)
end

function Rig._stopAllProfileTracks(self: Rig): ()
	for _, track in self._activeTracks do
		if track.IsPlaying then
			track:Stop(0.2)
		end
	end
	table.clear(self._activeTracks)
end

function Rig._speed(self: Rig): number
	local root = self.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return 0
	end
	local vel = root.AssemblyLinearVelocity
	local flat = Vector3.new(vel.X, 0, vel.Z).Magnitude
	return if self.ApplyRigScale then flat / self.Character:GetScale() else flat
end

function Rig.Destroy(self: Rig): ()
	self._destroyed = true
	self._running = false
	for _, conn in self._connections do
		pcall(function()
			conn:Disconnect()
		end)
	end
	table.clear(self._connections)
	for _, track in self._activeTracks do
		destroyTrack(track)
	end
	table.clear(self._activeTracks)
	for _, track in self._overlayTracks do
		pcall(function()
			if track.IsPlaying then
				track:Stop(0)
			end
		end)
	end
	table.clear(self._overlayTracks)
	self._overlayProfile = nil
	for _, record in self._profiles do
		for _, entry in record.Tracks do
			destroyTrack(entry.Track)
		end
		table.clear(record.Tracks)
	end
	table.clear(self._profiles)
	for _, bucket in self._categories do
		for _, entry in bucket do
			for _, conn in entry.MarkerConns do
				pcall(function()
					conn:Disconnect()
				end)
			end
			if entry.EndStopConn ~= nil then
				pcall(function()
					(entry.EndStopConn :: RBXScriptConnection):Disconnect()
				end)
				entry.EndStopConn = nil
			end
			destroyTrack(entry.Track)
		end
		table.clear(bucket)
	end
	table.clear(self._categories)
	table.clear(self._byId)
	self._trackCount = 0
	self._activeProfile = nil
end

-----------------------------
-- CONTROLLER (LocalPlayer) --
-----------------------------

local AnimateService = {}
AnimateService.Rig = Rig

local config: Config = {}

local initialised = false
local started = false
local disabled = false
local rig: Rig? = nil
local spawnToken = 0
local characterConn: RBXScriptConnection? = nil
local signalConns: { Connection } = {}

-- Survive respawns: the Rig is rebuilt every life, these are replayed onto it.
local persistedCore: string? = nil
local persistedProfiles: { [string]: ProfileDefinition } = {}

local waiters: { thread } = {}
local rigReady: Signal.Signal<Rig> = Signal()

local function vlog(...: any)
	if config.Verbose then
		print("[AnimateService]", ...)
	end
end

local function persistEnabled(): boolean
	return config.PersistProfiles ~= false
end

local function findSignals(): any?
	local parent = script.Parent
	if not parent then
		return nil
	end
	local containers: { Instance } = { parent }
	local grand = parent.Parent
	if grand then
		table.insert(containers, grand)
		local libs = grand:FindFirstChild("Libraries")
		if libs then
			table.insert(containers, libs)
		end
	end
	for _, container in containers do
		local found = container:FindFirstChild("AnimSignals")
		if found and found:IsA("ModuleScript") then
			local ok, bus = pcall(require, found)
			if ok then
				return bus
			end
		end
	end
	return nil
end

local function resolveCore(humanoid: Humanoid): ProfileDefinition?
	if config.CoreProfile then
		return config.CoreProfile
	end
	if config.CoreResolver then
		return config.CoreResolver(humanoid)
	end
	return discoverCore(humanoid, config.CoreFolder or script)
end

local function fireRigReady(newRig: Rig)
	rigReady:Fire(newRig)
	local pending = table.clone(waiters)
	table.clear(waiters)
	for _, thread in pending do
		task.spawn(thread, newRig)
	end
end

local function onCharacterAdded(character: Model)
	spawnToken += 1
	local token = spawnToken
	if rig then
		rig:Destroy()
		rig = nil
	end
	local newRig = Rig.new(character, config)
	if token ~= spawnToken or not started then
		newRig:Destroy()
		return
	end
	local core = resolveCore(newRig.Humanoid)
	local ids: { string } = {}
	collectIds(core, ids)
	for _, def in persistedProfiles do
		collectIds(def, ids)
	end
	if config.ExtraProfiles then
		for _, def in config.ExtraProfiles do
			collectIds(def, ids)
		end
	end
	preloadIds(ids)
	if token ~= spawnToken or not started then
		newRig:Destroy()
		return
	end
	if core then
		newRig:LoadProfile(DEFAULT_PROFILE, core)
	end
	for name, def in persistedProfiles do
		if name ~= DEFAULT_PROFILE then
			newRig:LoadProfile(name, def)
		end
	end
	if config.ExtraProfiles then
		for name, def in config.ExtraProfiles do
			if name ~= DEFAULT_PROFILE then
				newRig:LoadProfile(name, def)
			end
		end
	end
	local want = persistedCore or DEFAULT_PROFILE
	if not newRig:HasProfile(want) then
		want = DEFAULT_PROFILE
	end
	if newRig:HasProfile(want) then
		newRig:SetActiveProfile(want)
	end
	newRig:Init()
	newRig:Start()
	rig = newRig
	vlog("Loaded for character:", character.Name, "tracks:", newRig:GetLoadedCount())
	fireRigReady(newRig)
end

local function debugInfo(): any
	local current = rig
	if not current then
		return { alive = false, count = -1 }
	end
	return {
		alive = true,
		count = current:GetLoadedCount(),
		bin = current:GetLoadedList(),
		animatorPlaying = current:GetAnimatorPlayingCount(),
		profiles = current:GetProfileCount(),
	}
end

local function connectSignals()
	if config.UseSignals == false then
		return
	end
	local bus: any = config.Signals or findSignals()
	if bus == nil then
		vlog("No AnimSignals found, running direct-only")
		return
	end
	local function on(name: string, handler: (...any) -> ())
		local signal = bus[name]
		if signal then
			local conn: Connection = signal:Connect(handler)
			table.insert(signalConns, conn)
		end
	end
	on("PlayCategoryTrack", function(category: string, animId: string, opts: any)
		AnimateService:PlayCategory(category, animId, opts)
	end)
	on("StopCategoryTrack", function(category: string, animId: string?, fade: number?)
		AnimateService:StopCategory(category, animId, fade)
	end)
	on("SetCoreProfile", function(payload: { Profile: string })
		AnimateService:SetCoreProfile(payload.Profile)
	end)
	on("LoadProfile", function(payload: { Profile: string, Definition: ProfileDefinition, SetActive: boolean? })
		AnimateService:LoadProfile(payload.Profile, payload.Definition, payload.SetActive)
	end)
	on("LoadOverlay", function(payload: { Profile: string, Definition: ProfileDefinition, SetActive: boolean?, Priority: Enum.AnimationPriority? })
		AnimateService:LoadOverlay(payload.Profile, payload.Definition, payload.SetActive, payload.Priority)
	end)
	on("SetOverlayProfile", function(payload: { Profile: string?, Priority: Enum.AnimationPriority? })
		AnimateService:SetOverlayProfile(payload.Profile, payload.Priority)
	end)
	on("PreloadAnims", function(payload: { Ids: { string } })
		AnimateService:Preload(payload.Ids)
	end)
	on("LoadBatch", function(payload: { Ids: { string }, Category: string?, Keep: boolean? })
		AnimateService:LoadBatch(payload.Ids, payload.Category, payload.Keep)
	end)
	on("PlayOneOff", function(animId: string, opts: any)
		AnimateService:PlayOneOff(animId, opts)
	end)
	on("StopAllInCategory", function(payload: { Category: string, Fade: number? })
		AnimateService:StopAllCategory(payload.Category, payload.Fade)
	end)
	on("BindMarker", function(category: string, animId: string, marker: string, callback: (...any) -> ())
		AnimateService:OnMarker(category, animId, marker, callback)
	end)
	on("ClearMarkers", function(payload: { Category: string, AnimId: string, Marker: string? })
		AnimateService:ClearMarkers(payload.Category, payload.AnimId, payload.Marker)
	end)
end

-----------------------------
-- PUBLIC: lifecycle --
-----------------------------

-- Call before :Start(). Later calls are allowed but only affect rigs built afterwards.
function AnimateService:Configure(opts: Config): ()
	for key, value in (opts :: any) do
		(config :: any)[key] = value
	end
end

function AnimateService:Init(): ()
	if initialised then
		return
	end
	initialised = true
	if not RunService:IsClient() then
		disabled = true
		warn("[AnimateService] the controller is client-only. On the server use AnimateService.Rig.new(model) for NPC rigs.")
	end
end

function AnimateService:Start(): ()
	if not initialised then
		AnimateService:Init()
	end
	if started or disabled then
		return
	end
	started = true
	connectSignals()
	if config.Debug ~= false then
		(_G :: any).__AnimateServiceDebug = debugInfo
	end
	local player = Players.LocalPlayer
	characterConn = player.CharacterAdded:Connect(onCharacterAdded)
	if player.Character then
		task.spawn(onCharacterAdded, player.Character)
	end
	vlog("Started")
end

-- Tears everything down and forgets persisted profiles. Mostly for tests.
function AnimateService:Shutdown(): ()
	started = false
	initialised = false
	spawnToken += 1
	if characterConn then
		characterConn:Disconnect()
		characterConn = nil
	end
	for _, conn in signalConns do
		pcall(function()
			conn:Disconnect()
		end)
	end
	table.clear(signalConns)
	rigReady:DisconnectAll()
	if rig then
		rig:Destroy()
		rig = nil
	end
	persistedCore = nil
	table.clear(persistedProfiles)
	if rawget(_G :: any, "__AnimateServiceDebug") == debugInfo then
		(_G :: any).__AnimateServiceDebug = nil
	end
end

-----------------------------
-- PUBLIC: readiness --
-----------------------------

function AnimateService:IsReady(): boolean
	return rig ~= nil
end

-- The live per-life Rig, or nil between lives. Never cache it across a respawn.
function AnimateService:GetRig(): Rig?
	return rig
end

function AnimateService:WaitForRig(timeout: number?): Rig?
	if rig then
		return rig
	end
	if disabled then
		return nil
	end
	local thread = coroutine.running()
	table.insert(waiters, thread)
	if timeout then
		task.delay(timeout, function()
			local index = table.find(waiters, thread)
			if index then
				table.remove(waiters, index)
				task.spawn(thread, nil)
			end
		end)
	end
	return coroutine.yield() :: any
end

-- Runs now if a rig exists, and again after every respawn.
function AnimateService:OnRigReady(callback: (Rig) -> ()): Connection
	if rig then
		task.spawn(callback, rig)
	end
	return rigReady:Connect(callback)
end

-----------------------------
-- PUBLIC: playback (dropped with no return while between lives) --
-----------------------------

-- Loads if needed and PLAYS unless opts.AutoPlay == false.
function AnimateService:PlayCategory(category: string, animId: string, opts: LoadOptions?): AnimationTrack?
	local current = rig
	if not current then
		return nil
	end
	local options: LoadOptions = if opts then table.clone(opts) else {}
	if options.AutoPlay == nil then
		options.AutoPlay = true
	end
	return current:LoadCategory(category, animId, options)
end

function AnimateService:PlayOneOff(animId: string, opts: PlayOpts?): AnimationTrack?
	local current = rig
	return if current then current:PlayOneOff(animId, opts) else nil
end

function AnimateService:StopCategory(category: string, animId: string?, fade: number?): ()
	if rig then
		rig:StopCategory(category, animId, fade)
	end
end

function AnimateService:StopAllCategory(category: string, fade: number?): ()
	if rig then
		rig:StopAllCategory(category, fade)
	end
end

function AnimateService:OnMarker(category: string, animId: string, marker: string, callback: (...any) -> ()): MarkerHandle?
	local current = rig
	return if current then current:OnMarker(category, animId, marker, callback) else nil
end

function AnimateService:ClearMarkers(category: string, animId: string, marker: string?): ()
	if rig then
		rig:ClearMarkers(category, animId, marker)
	end
end

function AnimateService:GetTrack(category: string, animId: string): AnimationTrack?
	local current = rig
	return if current then current:GetTrack(category, animId) else nil
end

function AnimateService:IsPlaying(category: string, animId: string): boolean
	local current = rig
	return current ~= nil and current:IsPlaying(category, animId)
end

function AnimateService:SetLocomotionWeight(mult: number, fade: number?): ()
	if rig then
		rig:SetLocomotionWeight(mult, fade)
	end
end

function AnimateService:GetLoadedCount(): number
	local current = rig
	return if current then current:GetLoadedCount() else 0
end

function AnimateService:GetLoadedList(): { [string]: string }
	local current = rig
	return if current then current:GetLoadedList() else {}
end

function AnimateService:GetDebugInfo(): any
	return debugInfo()
end

-----------------------------
-- PUBLIC: preload and profiles (remembered, so they work before a rig exists) --
-----------------------------

-- Content warmup only. Safe to call from a loading screen, before any character.
function AnimateService:Preload(ids: { string }): ()
	preloadIds(ids)
end

function AnimateService:LoadBatch(ids: { string }, category: string?, keep: boolean?): ()
	local current = rig

	if not current then
		return
	end

	preloadIds(ids)

	for _, id in ids do
		current:LoadCategory(category or "Single", id, { AutoPlay = false, Keep = keep })
	end
end

function AnimateService:SetCoreProfile(name: string): ()
	if persistEnabled() then
		persistedCore = name
	end
	if rig then
		rig:SetActiveProfile(name)
	end
end

-- Loads a locomotion profile. Existing names are ignored; use ReplaceProfile to swap one.
function AnimateService:LoadProfile(name: string, definition: ProfileDefinition, setActive: boolean?): ()
	if persistEnabled() then
		persistedProfiles[name] = table.clone(definition)
	end
	if setActive ~= false and persistEnabled() then
		persistedCore = name
	end
	if rig then
		rig:LoadProfile(name, definition)
		if setActive ~= false then
			rig:SetActiveProfile(name)
		end
	end
end

function AnimateService:ReplaceProfile(name: string, definition: ProfileDefinition): ()
	if persistEnabled() then
		persistedProfiles[name] = table.clone(definition)
	end
	if rig then
		rig:ChangeAll(name, definition)
	end
end

-- Overlays layer a partial profile (say, arms) over the core one. The definition
-- is remembered across respawns; the ACTIVE overlay is not, re-arm it per life.
function AnimateService:LoadOverlay(name: string, definition: ProfileDefinition, setActive: boolean?, priority: Enum.AnimationPriority?): ()
	if persistEnabled() then
		persistedProfiles[name] = table.clone(definition)
	end
	local current = rig
	if not current then
		return
	end
	current:LoadProfile(name, definition)
	if setActive ~= false then
		current:SetOverlayProfile(name, priority)
	end
end

function AnimateService:SetOverlayProfile(name: string?, priority: Enum.AnimationPriority?): ()
	if rig then
		rig:SetOverlayProfile(name, priority)
	end
end

function AnimateService:ClearOverlay(): ()
	if rig then
		rig:ClearOverlay()
	end
end

return AnimateService
