# Combat Recipes

Copy-paste starters. Swap the IDs for your clips, keep the priorities.

## 1. M1 swing (kept Single)

```luau
local AnimSignals = require(path.to.Libraries.AnimSignals)
local M1_ID = "rbxassetid://123456789"

AnimSignals.PlayCategoryTrack:Fire("M1", M1_ID, {
    FadeTime = 0.05,
    Speed = 1.1,
    Priority = Enum.AnimationPriority.Action2,
})
```

## 2. Skill with hitbox + shake markers

```luau
local SKILL_ID = "rbxassetid://123456789"

AnimSignals.BindMarker:Fire("Skill", SKILL_ID, "Hit", function()
    DamageService:CastHitbox()
end)

AnimSignals.BindMarker:Fire("Skill", SKILL_ID, "Impact", function()
    CameraShaker:Shake(CameraShaker.Presets.HeavyExplosion)
end)

AnimSignals.PlayCategoryTrack:Fire("Skill", SKILL_ID, {
    FadeTime = 0.1,
    Priority = Enum.AnimationPriority.Action3,
})
```

## 3. Feint / dodge cancel

```luau
-- kill one swing
AnimSignals.StopCategoryTrack:Fire("M1", M1_ID, 0.05)

-- or kill ALL M1s at once
AnimSignals.StopCategoryTrack:Fire("M1", nil, 0.05)
```

## 4. Guard-broken / stunned

```luau
local HIT_ID = "rbxassetid://123456789"

AnimSignals.StopAllInCategory:Fire({ Category = "M1", Fade = 0.05 })
AnimSignals.StopAllInCategory:Fire({ Category = "Skill", Fade = 0.05 })

AnimSignals.PlayCategoryTrack:Fire("Stun", HIT_ID, {
    FadeTime = 0.05,
    Priority = Enum.AnimationPriority.Action4,
})
```

## 5. Downslam finisher (auto-unload OneOff)

```luau
local SLAM_ID = "rbxassetid://123456789" -- needs a "hitreg" marker

AnimSignals.BindMarker:Fire("OneOff", SLAM_ID, "hitreg", function()
    SpawnGroundRubble()
end)

-- fire-and-forget: destroys itself the moment it stops
AnimSignals.PlayOneOff:Fire(SLAM_ID, { FadeTime = 0.05 })
```

## 6. Injured limp swap

```luau
-- below 25% HP ("Injured" loaded via LoadProfile or ExtraProfiles)
AnimSignals.SetCoreProfile:Fire({ Profile = "Injured" })

-- healed
AnimSignals.SetCoreProfile:Fire({ Profile = "__Default__" })
```

## 7. Custom core on demand, toggle with a key

Load lazily on first press — not at script top. Early fires vanish before the bus connects.

```luau
local FIST = {
    Idle = "rbxassetid://180435571",
    Walk = "rbxassetid://180426354",
    Run = "rbxassetid://180426354",
    Jump = "rbxassetid://125750702",
    Fall = "rbxassetid://180436148",
}

local fistLoaded, usingFist, db = false, false, false

uis.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode ~= Enum.KeyCode.X or db then return end
    db = true
    usingFist = not usingFist
    if usingFist then
        if not fistLoaded then
            AnimSignals.LoadProfile:Fire({ Profile = "Fist", Definition = FIST, SetActive = true })
            fistLoaded = true
        else
            AnimSignals.SetCoreProfile:Fire({ Profile = "Fist" })
        end
    else
        AnimSignals.SetCoreProfile:Fire({ Profile = "__Default__" })
    end
    task.delay(0.3, function() db = false end)
end)
```

Once the service is running, `LoadProfile`, `LoadOverlay` and `PreloadAnims` are remembered even between lives. Play/stop/marker with no rig are dropped. `SetCoreProfile` to an unknown name warns instead of freezing.

## 8. Arms-layer overlay (Deepwoken pattern)

`SetCoreProfile` *replaces* locomotion. An overlay plays *on top* — arms-only clips for dagger stance or weapon guard — while combat Singles still override everything above it:

```text
base core (__Default__) < overlay (arms, Action) < combat (M1/Skill, Action2+)
```

```luau
local DAGGER_ARMS = {
    Idle = "rbxassetid://123456789", -- arms-only, legs unkeyed!
    Walk = "rbxassetid://123456789",
    Run = "rbxassetid://123456789",
}

-- equip: load once, layer at Action so keyed joints win
AnimSignals.LoadOverlay:Fire({
    Profile = "DaggerArms",
    Definition = DAGGER_ARMS,
    SetActive = true,
    Priority = Enum.AnimationPriority.Action,
})

-- unequip: base shows through, nothing reloaded
AnimSignals.SetOverlayProfile:Fire({ Profile = nil })
```

Overlay follows the active core slot-by-slot and survives base swaps. Its definition is remembered across respawns but the *active* overlay isn't — re-arm each life (see [Death & Respawn](lifecycle.md)).
