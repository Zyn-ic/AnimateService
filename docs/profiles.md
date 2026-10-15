# Profiles & Overlays

Two layers, one rule: **core replaces, overlay stacks**.

```text
base core (__Default__) < overlay (arms, Action) < combat (M1/Skill, Action2+)
```

## Core profiles

Full locomotion suites (`Idle`, `Walk`, `Run`, …). Activate one at a time.

```luau
-- load + activate immediately
AnimSignals.LoadProfile:Fire({
    Profile = "Injured",
    Definition = {
        Idle = "rbxassetid://...",
        Walk = "rbxassetid://...",
        Run = "rbxassetid://...",
    },
    SetActive = true, -- default true; false = load only
})

-- swap later (must be loaded first)
AnimSignals.SetCoreProfile:Fire({ Profile = "Injured" })
AnimSignals.SetCoreProfile:Fire({ Profile = "__Default__" }) -- back to spawn suite
```

Module mode:

```luau
AnimateService:LoadProfile("Injured", INJURED_DEF, true)
AnimateService:SetCoreProfile("Injured")
AnimateService:ReplaceProfile("Injured", NEW_DEF) -- swap contents of an existing name
```

Preload suites so `SetCoreProfile` never waits:

```luau
AnimateService:Configure({
    ExtraProfiles = { Injured = INJURED_DEF, Ninja = NINJA_DEF },
})
```

Loaded profiles and the active core survive respawns (unless `PersistProfiles = false`).

## Overlays

Arms-only sets that play *on top* of whatever core is active. Legs fall through to core, keyed arm joints win at your priority.

```luau
local DAGGER_ARMS = {
    Idle = "rbxassetid://123456789",
    Walk = "rbxassetid://123456789",
    Run = "rbxassetid://123456789",
}

AnimSignals.LoadOverlay:Fire({
    Profile = "DaggerArms",
    Definition = DAGGER_ARMS,
    SetActive = true,
    Priority = Enum.AnimationPriority.Action, -- always pass this
})

-- unequip
AnimSignals.SetOverlayProfile:Fire({ Profile = nil })

-- re-arm by name (definition remembered, active isn't)
AnimSignals.SetOverlayProfile:Fire({
    Profile = "DaggerArms",
    Priority = Enum.AnimationPriority.Action,
})
```

!!! tip "Always pass Priority for overlays"
    Default comes from `DefaultOverlayPriority` (`Core`). Pass `Action` so keyed joints win and the rest falls through to core.

Overlay follows the active core slot-by-slot (run plays dagger-run, jump plays dagger-jump) and survives base profile swaps. Re-arm it each life via `OnRigReady` — see [Death & Respawn](lifecycle.md).

Test it with WASD: `AnimOverlayTest` leaves the overlay on so you can eyeball arms-hold + walking legs.
