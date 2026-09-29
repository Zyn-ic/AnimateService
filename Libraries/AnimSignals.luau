--@author: yyumchi
--@date: 2026-09-29
--[[@description:
	Typed signal bus for AnimateService, built on ./Signal (SignalPlus, MIT).
	Fire and Connect like any Roblox signal; functions can travel through Fire.
	The only file you need next to it is Signal.luau.
]]

-----------------------------
-- DEPENDENCIES --
-----------------------------

local SignalPlus = require("./Signal")

-----------------------------
-- TYPES --
-----------------------------

export type Signal<Parameters...> = SignalPlus.Signal<Parameters...>
export type Connection = SignalPlus.Connection

export type PlayOpts = {
	FadeTime: number?,
	Weight: number?,
	Speed: number?,
	Priority: Enum.AnimationPriority?,
	Looped: boolean?,
}

export type MarkerCallback = (...any) -> ()

-----------------------------
-- MAIN --
-----------------------------

local AnimSignals = {
	PlayCategoryTrack = SignalPlus() :: Signal<string, string, any>,
	StopCategoryTrack = SignalPlus() :: Signal<string, string?, number?>,
	SetCoreProfile = SignalPlus() :: Signal<{ Profile: string }>,
	LoadProfile = SignalPlus() :: Signal<{ Profile: string, Definition: { [string]: string }, SetActive: boolean? }>,
	LoadOverlay = SignalPlus() :: Signal<{ Profile: string, Definition: { [string]: string }, SetActive: boolean?, Priority: Enum.AnimationPriority? }>,
	SetOverlayProfile = SignalPlus() :: Signal<{ Profile: string?, Priority: Enum.AnimationPriority? }>,
	PreloadAnims = SignalPlus() :: Signal<{ Ids: { string } }>,
	LoadBatch = SignalPlus() :: Signal<{ Ids: { string }, Category: string?, Keep: boolean? }>,
	PlayOneOff = SignalPlus() :: Signal<string, any>,
	StopAllInCategory = SignalPlus() :: Signal<{ Category: string, Fade: number? }>,
	BindMarker = SignalPlus() :: Signal<string, string, string, MarkerCallback>,
	ClearMarkers = SignalPlus() :: Signal<{ Category: string, AnimId: string, Marker: string? }>,
}

return AnimSignals
