# Architecture & Data Flow

Everything funnels through one door. Your game never touches the `Animator` directly.

```mermaid
flowchart TD
    subgraph Gameplay ["Game Systems (Combat, Skills, Emotes, Cutscenes)"]
        CB["CombatController / SkillService"]
        FX["VFX / SFX Listeners"]
    end

    subgraph Bus ["AnimSignals (Typed Signal Bus)"]
        S1["PlayCategoryTrack"]
        S2["StopCategoryTrack / StopAllInCategory"]
        S3["BindMarker"]
        S4["PlayOneOff"]
        S5["PreloadAnims / LoadBatch"]
        S6["SetCoreProfile"]
    end

    subgraph Core ["AnimateService (Local Client Service)"]
        BIN["LoadedBin & Deduplicator (_byId)"]
        WATCH["Playing-count watchdog (engine cap 64)"]
        FAN["Marker Fanout Engine"]
        LOCO["Locomotion State Machine (Speed & Rig Scale)"]
    end

    subgraph Engine ["Roblox Engine"]
        AN["Character Animator"]
        CP["ContentProvider (Persistent Asset Cache)"]
    end

    CB --> Bus
    CB -.->|"direct calls (module mode)"| Core
    FX -.->|Listen to markers| Bus
    Bus --> Core
    Core --> AN
    Core --> CP
```

## The four boxes

**1. LoadedBin & Deduplicator (`_byId`)** — every combat track indexed by clean ID. Same ID under two categories shares one track. Never loaded twice per life. See [Core Concepts](concepts.md).

**2. Playing-count watchdog** — loading is free (200/200 `LoadAnimation` calls succeed). Playing is budgeted: the engine refuses past **64 active tracks** per `Animator`. The service warns past **48** (5s throttle) — headroom for anything else on the rig. OneOffs auto-destroy, death wipes the bin.

**3. Marker fanout** — one native connection per `(track, marker)`, N listeners via `task.spawn`. Hitbox + shake + SFX all hear `"hitreg"`.

**4. Locomotion state machine** — `Humanoid` state + speed → exactly one core track (`Idle`, `Walk`, `Run`, `Sprint`, `Jump`, `Fall`, `Climb`, `Swim`, `SwimIdle`, `Sit`). Speed dividends (`Walk/16`, `Run/18`, `Sprint/22`, `Climb/12`, `Swim/16`) and rig-scale normalisation included.

## Combat signal & marker flow

```mermaid
sequenceDiagram
    autonumber
    actor Combat as Combat System
    actor VFX as Effects Listener
    participant Bus as AnimSignals
    participant Svc as AnimateService
    participant Track as AnimationTrack

    VFX->>Bus: BindMarker("OneOff", downslamId, "hitreg", spawnRubble)
    Combat->>Bus: PlayOneOff(downslamId, { FadeTime = 0.05 })
    Bus->>Svc: LoadCategory("OneOff", downslamId)
    Svc->>Track: Play(0.05)
    Note over Track: Animation reaches "hitreg" keyframe
    Track-->>Svc: GetMarkerReachedSignal("hitreg")
    Svc->>VFX: spawnRubble(coords) [task.spawn fanout]
    Note over Track: Clip ends
    Track-->>Svc: Stopped event
    Svc->>Track: Destroy() & unregister from LoadedBin
```

## Files

```text
Module/AnimateService       -- the engine (single implementation)
Services/AnimateService     -- launcher: Configure + Init + Start
Libraries/AnimSignals       -- 12 typed signals (the bus)
Libraries/Signal            -- SignalPlus v3.7.2, vendored
Tests/                      -- 9 proofs, run one at a time
```

`Module/AnimateService` *is* the implementation. `Services/AnimateService` only calls `Configure`, `Init`, `Start` on it. Mix signal fires and direct `require` calls freely — same code either way.
