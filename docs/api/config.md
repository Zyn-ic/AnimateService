# Config Reference

Pass to `AnimateService:Configure()` before `Start()`. Later calls only affect rigs built afterwards. `UseSignals` / `Signals` / `Debug` are read once at `Start()`.

| Key | Default | What it does |
| :--- | :--- | :--- |
| `UseSignals` | `true` | Connect the `AnimSignals` bus. If none is found it's skipped quietly (direct-only). |
| `Signals` | auto | Your `AnimSignals` table. Default searches `script.Parent` → grandparent → grandparent `Libraries` for an `AnimSignals` ModuleScript. |
| `Debug` | `true` | Expose `_G.__AnimateServiceDebug`. Set `false` for release. |
| `CoreProfile` | `nil` | Locomotion id table `{ Idle = "rbxassetid://…", Walk = … }`. Wins over the next two. |
| `CoreResolver` | `nil` | `(Humanoid) -> ProfileDefinition?` — pick by rig type or player data. |
| `CoreFolder` | the module | Holds `R15Animations` / `R6Animations` or `Animation` objects. The launcher points it at itself. |
| `ExtraProfiles` | `nil` | `{ [name]: ProfileDefinition }` — loaded (not activated) every life so `SetCoreProfile(name)` works without `LoadProfile` first. |
| `PersistProfiles` | `true` | Loaded profiles + active core survive respawns. |
| `LocomotionPriority` | `Core` | Priority of locomotion tracks. `Movement` beats stray `Core` clips. |
| `ClampCombatPriority` | `false` | Category tracks may only be `Action2`–`Action4`; anything lower (incl. `Core`/none) becomes `MinCombatPriority`. |
| `MinCombatPriority` | `Action2` | Clamp floor. |
| `DefaultOverlayPriority` | `Core` | Overlay priority when the caller passes none. |
| `PlayingWarnThreshold` | `48` | Warn past this many concurrent playing tracks (engine cap 64). |
| `Verbose` | `false` | Lifecycle logging. |

A combat game that keeps combat above locomotion:

```luau
AnimateService:Configure({
    CoreProfile = MyLocomotion,
    ExtraProfiles = { Injured = MyInjured },
    LocomotionPriority = Enum.AnimationPriority.Movement,
    ClampCombatPriority = true,
    DefaultOverlayPriority = Enum.AnimationPriority.Action,
})
```

Launcher default (`Services/AnimateService`):

```luau
AnimateService:Configure({ CoreFolder = script })
AnimateService:Init()
AnimateService:Start()
```
