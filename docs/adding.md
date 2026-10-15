# Adding Animations

Three places, three jobs. Don't mix them up.

## 1. Locomotion (under the launcher)

Add `R15Animations` / `R6Animations` folders — or stock-style `StringValue` slots — as children of `Services/AnimateService`. Discovered per spawn by rig type.

Slots: `Idle`, `Walk`, `Run`, `Sprint`, `Jump`, `Fall`, `Climb`, `Swim`, `SwimIdle`, `Sit`.

No source at all = combat-only mode. Legal.

Module mode alternatives (see [Config](api/config.md)):

- `CoreFolder` → any folder holding those structures.
- `CoreProfile = { Idle = "rbxassetid://…", Walk = … }` (wins over folders).
- `CoreResolver = function(humanoid) … end` (pick by rig type or player data).

## 2. Combat (just asset IDs)

Keep your own table of M1s, dashes and reactions (see `Tests/TestKit.luau` for the shape) and dispatch by ID:

```luau
local MOVES = {
    M1_1 = "rbxassetid://123456789",
    M1_2 = "rbxassetid://123456790",
    Dash = "rbxassetid://123456791",
}

AnimSignals.PlayCategoryTrack:Fire("M1", MOVES.M1_1, {
    FadeTime = 0.05,
    Priority = Enum.AnimationPriority.Action2,
})
```

Character-specific tables override per slot and fall back to shared defaults. Omitted `Priority` loads at `Core` — pass `Action2`+ for combat.

Partial-body rule: hands-only clips (upper torso + arms + head keyed, legs unkeyed) at `Action`+ give you walk-while-blocking. Full-body clips at `Core` fight locomotion. See [Priority](priority.md).

## 3. Preload before the fight

```luau
-- loading screen / round start / entering combat
AnimSignals.PreloadAnims:Fire({ Ids = { MOVES.M1_1, MOVES.M1_2, MOVES.Dash } })

-- equip a moveset without playing (registers into the bin)
AnimSignals.LoadBatch:Fire({ Ids = { MOVES.M1_1, MOVES.M1_2 }, Category = "M1" })
```

`LoadBatch` only takes flat ID lists — it can't name a profile. Use `LoadProfile` for that.

!!! tip "Assets are per-owner"
    Clips you upload only load in experiences you own (or that the asset is shared with). The tests use Roblox's public defaults so they run anywhere.
