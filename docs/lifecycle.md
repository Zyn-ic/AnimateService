# Death & Respawn

Death is a feature. Here's exactly what survives and what doesn't.

## What happens

1. `Humanoid.Died` → state `Dead` → all core + overlay tracks stop.
2. New character spawns → old `Rig:Destroy()` (disconnect all, `Stop(0) + Destroy` every track).
3. New `Rig.new(character)` → preload core + persisted + extra IDs → `LoadProfile("__Default__")` → replay persisted profiles → activate remembered core → `Init()` + `Start()`.

Because `ContentProvider` still holds the bytes, the rebuild is warm:

```text
[PartialTest] same id dispatches in 0.1ms after respawn (content cached, only the track is new)
```

## Remembered vs forgotten

| Remembered across lives | Forgotten (rebuild it) |
| :--- | :--- |
| Loaded profiles + active core (unless `PersistProfiles = false`) | Tracks (`Parent == nil` now) |
| Overlay *definitions* | *Active* overlay (re-arm by name) |
| Preload cache (`ContentProvider`) | Marker listeners |
| `ExtraProfiles` (reloaded every life) | Raw `AnimationTrack` references in your code |

## The stale-reference trap

```luau
-- DON'T do this:
local track = AnimService:GetTrack("M1", M1_ID)
-- ... player dies ...
track:Play() -- no error, silent nothing. You're animating a corpse.
```

Always dispatch by ID:

```luau
-- DO this:
AnimSignals.PlayCategoryTrack:Fire("M1", M1_ID, { Priority = Enum.AnimationPriority.Action2 })
```

## Between lives

There is no rig between lives. Play, stop and marker calls made then are **dropped** (return `nil`). Profiles, overlay definitions and `Preload` are remembered.

Use readiness helpers to act once a rig exists:

```luau
local AnimateService = require(path.to.Module.AnimateService)

-- yield until spawn (optional timeout)
local rig = AnimateService:WaitForRig(10)

-- or subscribe (fires now if a rig exists, again every respawn)
local conn = AnimateService:OnRigReady(function(rig)
    AnimSignals.LoadOverlay:Fire({
        Profile = "DaggerArms",
        Definition = DAGGER_ARMS,
        SetActive = true,
        Priority = Enum.AnimationPriority.Action,
    })
end)
-- conn:Disconnect() when done
```

!!! tip "Re-arm overlays per life"
    Overlay *definitions* survive, but the *active* overlay doesn't. `OnRigReady` is the perfect place to re-arm it.

## Never cache

- Never cache the rig across respawn — ask `GetRig()` again.
- Never cache a track across respawn — ask by `(category, id)` again.
- `LoadProfile` with an existing name is ignored — use `ReplaceProfile` to swap contents.
