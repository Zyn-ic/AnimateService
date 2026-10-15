# Controller API

The LocalPlayer-facing service. All methods no-op / return `nil` between lives (no rig) — except preload/profile persistence, which are remembered.

## Readiness

| Method | Signature | Notes |
| :--- | :--- | :--- |
| `IsReady` | `() -> boolean` | `rig ~= nil` |
| `GetRig` | `() -> Rig?` | Never cache across respawn — ask again |
| `WaitForRig` | `(timeout?: number) -> Rig?` | Yields until spawn (or timeout → `nil`) |
| `OnRigReady` | `(cb: (Rig) -> ()) -> Connection` | Fires now if a rig exists + every respawn. SignalPlus `Connection` (`:Disconnect()`) |

```luau
local rig = AnimateService:WaitForRig(10)
local conn = AnimateService:OnRigReady(function(rig)
    -- re-arm overlays, rebind markers
end)
```

## Playback

| Method | Signals equivalent |
| :--- | :--- |
| `PlayCategory(category, animId, opts?: LoadOptions): AnimationTrack?` | `PlayCategoryTrack` (`AutoPlay` defaults `true`; `false` = load only) |
| `PlayOneOff(animId, opts?: PlayOpts): AnimationTrack?` | `PlayOneOff` (forces `Looped = false`, auto-destroys on `Stopped`) |
| `StopCategory(category, animId?: string, fade?: number)` | `StopCategoryTrack` |
| `StopAllCategory(category, fade?: number)` | `StopAllInCategory` |

## Markers

| Method | Signals equivalent |
| :--- | :--- |
| `OnMarker(category, animId, marker, cb): MarkerHandle?` | `BindMarker` |
| `ClearMarkers(category, animId, marker?)` | `ClearMarkers` (`nil` = whole clip) |

`MarkerHandle = { Connected: boolean, Disconnect: (self) -> () }`.

## Queries

- `GetTrack(category, animId): AnimationTrack?`
- `IsPlaying(category, animId): boolean`
- `GetLoadedCount(): number`
- `GetLoadedList(): { [cleanId]: "category/Kind" }`
- `GetDebugInfo(): { alive, count, bin, animatorPlaying, profiles }`
- `SetLocomotionWeight(mult, fade?)` — scale active locomotion weight.

Live inspect from any LocalScript:

```luau
local fn = rawget(_G :: any, "__AnimateServiceDebug")
local ok, info = pcall(fn)
if ok then
    print("[AnimDebug] alive=", info.alive, "count=", info.count)
    for id, where in info.bin do print("  ", id, "->", where) end
end
```

`Config.Debug = false` removes the global for release.

## Preload (works with no rig)

- `Preload(ids: { string })` — `ContentProvider` warmup. Call from a loading screen.
- `LoadBatch(ids, category?: string, keep?: boolean?)` — preload + `LoadCategory(category or "Single", id, { AutoPlay = false })`.

## Profiles

- `SetCoreProfile(name)` — activate (persists if `PersistProfiles`).
- `LoadProfile(name, def, setActive?: boolean)` — `setActive ~= false` also activates. Existing names ignored.
- `ReplaceProfile(name, def)` — swap contents of an existing profile.
- `LoadOverlay(name, def, setActive?, priority?)` — definition persisted, active overlay not.
- `SetOverlayProfile(name?, priority?)` — `nil` clears.
- `ClearOverlay()`.

## Lifecycle

- `Configure(opts: Config)` — shallow-merge. Call before `Start` for first life; later calls affect rigs built after.
- `Init()` — idempotent. Warns + disables on server (use `Rig.new` there).
- `Start()` — connects signals, exposes debug, hooks `CharacterAdded`, builds current rig.
- `Shutdown()` — test helper. Destroys rig, disconnects signals, forgets persisted profiles, removes `_G` hook.
