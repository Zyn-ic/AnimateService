# Markers & Fanout

Keyframes your whole game can hear. One native connection, N listeners.

## The problem with raw markers

Roblox's `:GetMarkerReachedSignal()` gives you one connection per track without manual plumbing — and it breaks when tracks reload. Two systems wanting `"Hit"` on the same swing step on each other.

## What the service does

`OnMarker()` creates **one** native connection per `(track, marker)` and fans out to every listener via `task.spawn`:

- Hit detection, screen shake, sound and particles all hook `"hitreg"` independently.
- Works on kept Singles *and* OneOffs.
- Listeners live on the track → die with the character. Rebind each life, ideally right before you play.

```luau
-- hitbox + shake on the same marker, no conflict
AnimSignals.BindMarker:Fire("Skill", SKILL_ID, "Hit", function()
    DamageService:CastHitbox()
end)

AnimSignals.BindMarker:Fire("Skill", SKILL_ID, "Hit", function()
    CameraShaker:Shake(CameraShaker.Presets.HeavyExplosion)
end)
```

Direct mode returns a handle:

```luau
local handle = AnimateService:OnMarker("Skill", SKILL_ID, "Hit", onHit)
-- later:
handle:Disconnect() -- removes just this listener
```

`OnMarker` lazy-loads: bind on a never-loaded ID and it loads (`AutoPlay = false`) then hooks. No throw.

## Clearing

```luau
-- drop every listener on one marker (e.g. swing cancelled)
AnimateService:ClearMarkers("M1", M1_ID, "Hit")

-- drop the whole clip's listeners
AnimateService:ClearMarkers("M1", M1_ID)

-- via signals
AnimSignals.ClearMarkers:Fire({ Category = "M1", AnimId = M1_ID, Marker = "Hit" })
AnimSignals.ClearMarkers:Fire({ Category = "M1", AnimId = M1_ID })
```

Use it when a move is feinted or interrupted.

## Shorthand during load

```luau
AnimSignals.PlayCategoryTrack:Fire("Skill", SKILL_ID, {
    FadeTime = 0.1,
    Priority = Enum.AnimationPriority.Action3,
    MarkerName = "Hit",
    MarkerCallback = function() DamageService:CastHitbox() end,
    OnLoaded = function(track)
        track:AdjustSpeed(1.2)
    end,
})
```

## You need a marked clip to test

Marker checks need a clip that *actually contains* a marker. Set `MarkerClip` (and `MarkerName`) in `Tests/TestKit.luau` — otherwise those checks print `SKIP` and the rubble demo stays quiet. `AnimMarkerTest` covers bookkeeping without any marked clip.
