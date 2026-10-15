# Signal Catalog (`AnimSignals`)

All communication happens through `Libraries/AnimSignals.luau`. Fire signals — never touch `Animator:LoadAnimation()` yourself.

| Signal | Payload | When to fire |
| :--- | :--- | :--- |
| `PlayCategoryTrack` | `(category: string, animId: string, opts?: PlayOpts)` | Attack, dash, block, skill. `AutoPlay` defaults `true`; `false` = load only. |
| `StopCategoryTrack` | `(category: string, animId?: string, fade?: number)` | Feint, cancel, dodge windup. Omit `animId` = whole category. |
| `StopAllInCategory` | `{ Category: string, Fade?: number }` | Parried, stunned. Nuke a bucket. |
| `PlayOneOff` | `(animId: string, opts?: PlayOpts)` | Finisher, execution, downslam. Self-destructs. |
| `BindMarker` | `(category: string, animId: string, marker: string, cb)` | Hook hitbox / SFX / shake to a keyframe. |
| `ClearMarkers` | `{ Category: string, AnimId: string, Marker?: string }` | Drop listeners on cancel. Omit `Marker` = whole clip. |
| `SetCoreProfile` | `{ Profile: string }` | Stance / limp / class swap. Warns on unknown, never freezes. |
| `LoadProfile` | `{ Profile: string, Definition: { [string]: string }, SetActive?: boolean }` | Load a locomotion set from an id table. |
| `LoadOverlay` | `{ Profile: string, Definition: { [string]: string }, SetActive?: boolean, Priority?: Enum.AnimationPriority }` | Arms-layer set on top of core. |
| `SetOverlayProfile` | `{ Profile: string?, Priority?: Enum.AnimationPriority }` | Activate/clear overlay (`nil` clears). Pass `Action`. |
| `PreloadAnims` | `{ Ids: { string } }` | Pre-warm via `ContentProvider` pre-round. |
| `LoadBatch` | `{ Ids: { string }, Category?: string, Keep?: boolean }` | Equip moveset: preload + register without playing. |

## Play options

```luau
type PlayOpts = {
    FadeTime: number?,  -- default 0.1
    Weight: number?,    -- default 1.0
    Speed: number?,     -- default 1.0
    Priority: Enum.AnimationPriority?, -- omitted = Core
    Looped: boolean?,
}

type LoadOptions = PlayOpts & {
    AutoPlay: boolean?, -- default true for PlayCategoryTrack/PlaySingle, false for LoadBatch
    Keep: boolean?,     -- reserved: stored, nothing reads it yet (no eviction)
    PreloadOnly: boolean?, -- register without Play()
    MarkerName: string?,
    MarkerCallback: ((...any) -> ())?,
    OnLoaded: ((AnimationTrack) -> ())?, -- cached or fresh: AdjustSpeed, TimePosition, etc.
}
```

!!! warning "Signals aren't queued"
    A fire before the bus connects — or between lives — vanishes. Load lazily once the service is up (see [Recipes](recipes.md) #7). Profiles, overlay defs and `Preload` are remembered; play/stop/marker with no rig are dropped.

## Quick fires

```luau
local AnimSignals = require(path.to.Libraries.AnimSignals)

-- play (loads if missing, reuses if present)
AnimSignals.PlayCategoryTrack:Fire("M1", M1_ID, {
    FadeTime = 0.05,
    Priority = Enum.AnimationPriority.Action2,
})

-- load only
AnimSignals.PlayCategoryTrack:Fire("M1", M1_ID, { AutoPlay = false })

-- stop one swing / whole bucket / nuke + fade
AnimSignals.StopCategoryTrack:Fire("M1", M1_ID, 0.05)
AnimSignals.StopCategoryTrack:Fire("M1", nil, 0.05)
AnimSignals.StopAllInCategory:Fire({ Category = "M1", Fade = 0.05 })

-- one-off finisher (auto-destroys)
AnimSignals.PlayOneOff:Fire(SLAM_ID, { FadeTime = 0.05 })

-- markers
AnimSignals.BindMarker:Fire("Skill", SKILL_ID, "Hit", function()
    DamageService:CastHitbox()
end)
AnimSignals.ClearMarkers:Fire({ Category = "Skill", AnimId = SKILL_ID, Marker = "Hit" })

-- profiles & overlays
AnimSignals.LoadProfile:Fire({ Profile = "Injured", Definition = INJURED, SetActive = false })
AnimSignals.SetCoreProfile:Fire({ Profile = "Injured" })
AnimSignals.LoadOverlay:Fire({ Profile = "DaggerArms", Definition = ARMS, SetActive = true, Priority = Enum.AnimationPriority.Action })
AnimSignals.SetOverlayProfile:Fire({ Profile = nil })

-- warmup
AnimSignals.PreloadAnims:Fire({ Ids = { M1_ID, SKILL_ID } })
AnimSignals.LoadBatch:Fire({ Ids = { M1_ID, SKILL_ID }, Category = "M1" })
```
