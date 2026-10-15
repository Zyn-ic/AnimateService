# Tests & Studio Verification

Nine proofs. All IDs are Roblox's own R15 defaults — no uploads needed. Run them **one at a time** in Play Solo (they share the character's bin).

## Setup

1. `Tests/` next to `Services/` + `Module/` in `StarterPlayerScripts`.
2. Toggle `Disabled` — only your target enabled.
3. Play Solo, watch the **client** log.
4. Swap IDs in `Tests/TestKit.luau` for your own clips whenever you like.

Marker checks need a clip with a real marker: set `MarkerClip` (and `MarkerName`) in `TestKit`, or those checks print `SKIP`.

| # | Script | What it proves |
| :-: | :--- | :--- |
| 1 | `AnimValidator` | Baseline count, reuse flat `10→11→11`, marker path, stop path, OneOff no-leak, respawn rebuilds baseline |
| 2 | `AnimStutterTest` | Raw `LoadAnimation` (~100ms+ hitch) vs `PreloadAnims` dispatch (~0.1ms) |
| 3 | `AnimSingleTest` | Kept Singles persist across stop/replay, OneOff unloads, marker rubble (when `MarkerClip` set) |
| 4 | `AnimPartialTest` | Stashed tracks die on respawn, sub-ms replay, `Action` vs `Core` WASD eyeball for partial-body |
| 5 | `AnimOverlayTest` | Overlay layers at your priority, clearing stops it, re-arm by name works (leaves overlay on for WASD check) |
| 6 | `AnimPersistCheck` | Runtime profile survives reset. Self-killing, runs once per session |
| 7 | `AnimOneOffTest` | Warm OneOff dispatches without hitch and unloads itself |
| 8 | `AnimMarkerTest` | Marker bookkeeping without a marked clip: handles, stacking, `ClearMarkers` by name + wholesale, signal parity. Needs `Module/` + bus |
| 9 | `AnimModuleTest` | Module mode with no signals: readiness, autoplay + reuse, stop, OneOff unload, static `Preload`, profile + `OnRigReady` survive respawn. Resets you — run alone |

## Expected lines (spot-check)

```text
[Validator] PASS single reuse second load flat -- before 10 mid 11 after 11
[Validator] PASS respawn rebuild == baseline -- got 10 want 10

[StutterTest] raw cold rbxassetid://50777xxxx content ready in 125.9ms
[StutterTest] service preloaded rbxassetid://50777xxxx dispatch took 0.1ms

[SingleTest] PASS kept single stays after stop
[SingleTest] SKIP marker reached -- set TestKit.Ids.MarkerClip ...

[PartialTest] CONFIRMED old track dead after respawn: parentNil=true replayOk=true
[PartialTest] ACTION priority: clip looped, WALK WITH WASD ... (8s)

[OverlayTest] PASS overlay sits at the requested Action
[PersistCheck] PASS respawn restores the last active profile
[OneOffTest] PASS no hitch after Preload -- 0.1ms
[MarkerTest] PASS two listeners stack -- count=2
[ModuleTest] PASS second PlayCategory reuses the track
```

`AnimPartialTest`, `AnimPersistCheck` and `AnimModuleTest` need a manual or automatic reset mid-run — that's intentional, they're testing death.

## Live inspect

Studio's Command Bar is server/edit — `_G.__AnimateServiceDebug()` there returns `nil`. Call it from any LocalScript (client log, or a debug script):

```luau
local fn = rawget(_G :: any, "__AnimateServiceDebug")
if typeof(fn) == "function" then
    local ok, info = pcall(fn)
    if ok then
        print("[AnimDebug] alive=", info.alive, "count=", info.count)
        for id, where in info.bin do
            print("  ", id, "->", where)
        end
    end
end
```

Module mode: `AnimateService:GetDebugInfo()` returns the same table. `Config.Debug = false` removes the global for release.
