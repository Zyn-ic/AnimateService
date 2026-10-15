# Module Mode

Same engine, driven by `require` instead of signals. `Module/AnimateService` is the single implementation; `Services/AnimateService` only calls `Configure`, `Init`, `Start` on it.

Mix both styles freely — a signal fire and a direct call reach the same code.

## Lifecycle

```luau
local AnimateService = require(path.to.Module.AnimateService)

AnimateService:Configure({ ClampCombatPriority = true })
AnimateService:Init()
AnimateService:Start()
```

`Init` then `Start` matches ModuleLoader-style services. With a loader, put `Module/AnimateService` in a client Services folder and let the loader run it.

`Configure` can run any time, but the first life reads it during `Start`, and `UseSignals` / `Signals` / `Debug` are read once at `Start`. With a loader, call it from another module's `Init`, or edit the defaults in the file.

## API

Same verbs as the signals — call with a colon:

| Group | Methods |
| :--- | :--- |
| Playback | `PlayCategory(category, animId, opts?)` loads + plays (`AutoPlay = false` = load only), returns track. `PlayOneOff(animId, opts?)`, `StopCategory(category, animId?, fade?)`, `StopAllCategory(category, fade?)` |
| Markers | `OnMarker(category, animId, marker, cb)` → `MarkerHandle` with `Disconnect()`. `ClearMarkers(category, animId, marker?)` |
| Queries | `GetTrack`, `IsPlaying`, `GetLoadedCount`, `GetLoadedList`, `GetDebugInfo`, `SetLocomotionWeight(mult)` |
| Profiles | `SetCoreProfile(name)`, `LoadProfile(name, def, setActive?)`, `ReplaceProfile(name, def)`, `LoadOverlay(name, def, setActive?, priority?)`, `SetOverlayProfile(name?, priority?)`, `ClearOverlay()` |
| Preload | `Preload(ids)` needs no character — call from a loading screen. `LoadBatch(ids, category?, keep?)` |
| Readiness | `IsReady()`, `GetRig()`, `WaitForRig(timeout?)`, `OnRigReady(cb)` (fires now if a rig exists + every respawn, returns SignalPlus `Connection`) |
| Lifecycle | `Configure`, `Init`, `Start`, `Shutdown` |

## Rules of thumb

- Between lives there is no rig. Play/stop/marker calls are dropped (`nil`). Profiles, overlay defs and `Preload` are remembered. Use `WaitForRig()` or `OnRigReady(cb)`.
- Never cache the rig or a track across respawn — ask `GetRig()` again.
- `LoadProfile` with an existing name is ignored. Use `ReplaceProfile` to swap contents.

## Client only, rigs anywhere

The controller owns the LocalPlayer's character, so on the server `Init` warns and does nothing. The per-rig class it wraps works on any Humanoid rig:

```luau
local rig = AnimateService.Rig.new(model)
rig:LoadProfile("__Default__", def)
rig:SetActiveProfile("__Default__")
rig:Init()
rig:Start()
-- later: rig:Destroy()
```

Driving server-side NPC rigs this way should work but is untested.

Full reference: [Controller API](api/controller.md) · [Rig API](api/rig.md) · [Config](api/config.md)
